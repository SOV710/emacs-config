;;; sov-ui-modeline.el --- Custom mode line -*- lexical-binding: t; -*-

;; This module builds a custom mode line from scratch.  It is designed to be
;; responsive: as the window becomes narrower, the layout progressively hides
;; and compresses segments (path, major mode, conditions, state, flymake,
;; diff, branch) until only the file name and ruler remain.


;;; Requirements

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'project)
(require 'vc)
(require 'flymake)

(declare-function nerd-icons-icon-for-file "nerd-icons" (file &rest args))
(declare-function nerd-icons-icon-for-mode "nerd-icons" (mode &rest args))
(declare-function nerd-icons-flicon "nerd-icons" (icon-name &rest args))
(declare-function nerd-icons-mdicon "nerd-icons" (icon-name &rest args))
(declare-function nerd-icons-powerline "nerd-icons" (icon-name &rest args))


;;; State faces

;; Each Evil state gets a distinct face used by both the mode line and the
;; state-aware current-line highlight.  The colors are filled dynamically by
;; `sov-ui--refresh-faces' after the theme is loaded.
(defface sov-ui-mode-line-normal
  '((t (:inherit mode-line :weight bold)))
  "Face used for the Normal Evil state in the mode line.
The background color is set by `sov-ui--refresh-faces'.")

(defface sov-ui-mode-line-insert
  '((t (:inherit mode-line :weight bold)))
  "Face used for the Insert Evil state in the mode line.
The background color is set by `sov-ui--refresh-faces'.")

(defface sov-ui-mode-line-visual
  '((t (:inherit mode-line :weight bold)))
  "Face used for the Visual Evil state in the mode line.
The background color is set by `sov-ui--refresh-faces'.")

(defface sov-ui-mode-line-replace
  '((t (:inherit mode-line :weight bold)))
  "Face used for the Replace Evil state in the mode line.
The background color is set by `sov-ui--refresh-faces'.")

(defface sov-ui-mode-line-operator
  '((t (:inherit mode-line :weight bold)))
  "Face used for the Operator Evil state in the mode line.
The background color is set by `sov-ui--refresh-faces'.")

(defface sov-ui-mode-line-emacs
  '((t (:inherit mode-line :weight bold)))
  "Face used for the Emacs state (non-Evil buffers) in the mode line.
The background color is set by `sov-ui--refresh-faces'.")


;;; State lookup

(defconst sov-ui--evil-state-table
  '((normal "NORMAL" sov-ui-mode-line-normal)
    (motion "MOTION" sov-ui-mode-line-normal)
    (insert "INSERT" sov-ui-mode-line-insert)
    (visual "VISUAL" sov-ui-mode-line-visual)
    (replace "REPLACE" sov-ui-mode-line-replace)
    (operator "OPERATOR" sov-ui-mode-line-operator)
    (emacs "EMACS" sov-ui-mode-line-emacs))
  "Mapping from Evil state symbols to labels and faces.
Motion state is treated as Normal for visual consistency.")

(defun sov-ui--evil-info (state compact)
  "Return information for Evil STATE.
Return a list (LABEL FACE).  When COMPACT is non-nil, LABEL is the first
character of the state name; otherwise it is the full name.  Unknown states
fall back to a Normal-styled label so the mode line never breaks."
  (let* ((entry (or (assq state sov-ui--evil-state-table)
                    (list state (upcase (symbol-name state))
                          'sov-ui-mode-line-normal)))
         (label (nth 1 entry)))
    (list (if compact (substring label 0 1) label)
          (nth 2 entry))))


;;; Path helpers

(defun sov-ui--shorten-path (path)
  "Return a shortened version of PATH.
All directory components except the last are reduced to a single character,
which keeps long paths readable in narrow windows."
  (let ((parts (split-string path "/" t)))
    (mapconcat
     #'identity
     (append (mapcar (lambda (part) (substring part 0 1))
                     (butlast parts))
             (last parts))
     "/")))

(defun sov-ui--path-variants (file root)
  "Return three variants of FILE for display.
ROOT is an optional project root.  The variants are, in order:
1. The path relative to ROOT, or abbreviated when ROOT is nil.
2. The shortened relative path.
3. The file name only.
These indices are used by `sov-ui--current-paths' and the layout logic."
  (let* ((full (if root
                   (file-relative-name file root)
                 (abbreviate-file-name file)))
         (base (file-name-nondirectory file)))
    (list full (sov-ui--shorten-path full) base)))


;;; Diff-hunk counters

(defun sov-ui--count-diff-hunks (changes)
  "Count added, changed, and removed hunks from `diff-hl' CHANGE list.
Return a list (ADDED CHANGED REMOVED)."
  (let ((added 0)
        (changed 0)
        (removed 0))
    (dolist (change changes)
      (pcase (nth 2 change)
        ('insert (cl-incf added))
        ('change (cl-incf changed))
        ('delete (cl-incf removed))))
    (list added changed removed)))


;;; Position and selection helpers

(defun sov-ui--line-number-at (position)
  "Return the absolute line number at POSITION."
  (line-number-at-pos position t))

(defun sov-ui--column-at (position)
  "Return the current column after moving to POSITION."
  (save-excursion
    (goto-char position)
    (current-column)))

(defun sov-ui--region-metrics (begin end kind)
  "Return a human-readable string for the region between BEGIN and END.
KIND is one of `line', `block', or `character' and determines the format:
`line' and `character' return \"LINES:CHARS\"; `block' returns
\"LINES:COLUMNS\"."
  (let* ((low (min begin end))
         (high (max begin end))
         (last (max low (1- high)))
         (lines (1+ (- (sov-ui--line-number-at last)
                       (sov-ui--line-number-at low))))
         (chars (- high low)))
    (if (eq kind 'block)
        (format "%d:%d" lines
                (1+ (abs (- (sov-ui--column-at begin)
                            (sov-ui--column-at end)))))
      (format "%d:%d" lines chars))))

(defun sov-ui--selection-kind ()
  "Return the current Evil visual selection kind.
Possible values are `line', `block', or `character'."
  (pcase (and (boundp 'evil-visual-selection)
              evil-visual-selection)
    ('line 'line)
    ('block 'block)
    (_ 'character)))


;;; Flymake diagnostics

(defun sov-ui--flymake-counts ()
  "Return the current buffer's Flymake error and warning counts.
Return a list (ERRORS WARNINGS)."
  (let ((errors 0)
        (warnings 0))
    (when (bound-and-true-p flymake-mode)
      (dolist (diagnostic (flymake-diagnostics))
        (pcase (flymake-diagnostic-type diagnostic)
          (:error (cl-incf errors))
          (:warning (cl-incf warnings)))))
    (list errors warnings)))


;;; Condition indicators

(defun sov-ui--condition-items ()
  "Return a list of active buffer/window state indicators.
Each element is a list (KEY ICON LABEL) for conditions such as narrowing,
remote files, keyboard macro recording, and running processes.  Only
active conditions are included."
  (delq nil
        (list
         (when (buffer-narrowed-p)
           (list 'narrow
                 (sov-ui--safe-icon
                  #'nerd-icons-mdicon "nf-md-arrow_collapse"
                  "N" 'sov-ui-mode-line-condition)
                 "Narrow"))
         (when (file-remote-p default-directory)
           (list 'remote
                 (sov-ui--safe-icon
                  #'nerd-icons-mdicon "nf-md-ssh"
                  "R" 'sov-ui-mode-line-condition)
                 "Remote"))
         (when defining-kbd-macro
           (list 'macro
                 (sov-ui--safe-icon
                  #'nerd-icons-mdicon "nf-md-record_rec"
                  "K" 'sov-ui-mode-line-condition)
                 "REC"))
         (when (get-buffer-process (current-buffer))
           (list 'process
                 (sov-ui--safe-icon
                  #'nerd-icons-mdicon "nf-md-map"
                  "P" 'sov-ui-mode-line-condition)
                 "Proc")))))


;;; Diff-hl integration

(defvar-local sov-ui--diff-hunks '(0 0 0)
  "Cached diff hunk counts for the current buffer.
Updated via `sov-ui--cache-diff-hunks' whenever `diff-hl-changes' runs.")

(defun sov-ui--cache-diff-hunks (changes)
  "Cache diff hunk counts from CHANGES and refresh the mode line.
Return CHANGES unchanged so the advice behaves transparently."
  (setq sov-ui--diff-hunks (sov-ui--count-diff-hunks changes))
  (force-mode-line-update)
  changes)

(use-package diff-hl
  :ensure t
  :init
  (setq diff-hl-disable-on-remote t
        diff-hl-update-async t)
  :config
  (unless (advice-member-p #'sov-ui--cache-diff-hunks
                           #'diff-hl-changes)
    (advice-add #'diff-hl-changes :filter-return
                #'sov-ui--cache-diff-hunks))
  (global-diff-hl-mode 1)
  (diff-hl-flydiff-mode 1))


;;; Mode-line faces

(defface sov-ui-mode-line-branch
  '((t (:inherit mode-line)))
  "Face for the Git branch segment in the mode line.")

(defface sov-ui-mode-line-directory
  '((t (:inherit shadow)))
  "Face for the directory part of the file path segment.")

(defface sov-ui-mode-line-file
  '((t (:inherit mode-line :weight bold)))
  "Face for the file name segment in the mode line.")

(defface sov-ui-mode-line-modified
  '((t (:inherit warning :weight bold)))
  "Face for the modified buffer indicator.")

(defface sov-ui-mode-line-read-only
  '((t (:inherit warning)))
  "Face for the read-only buffer indicator.")

(defface sov-ui-mode-line-error
  '((t (:inherit error)))
  "Face for Flymake error counts in the mode line.")

(defface sov-ui-mode-line-warning
  '((t (:inherit warning)))
  "Face for Flymake warning counts in the mode line.")

(defface sov-ui-mode-line-added
  '((t (:inherit diff-added)))
  "Face for added diff hunks in the mode line.")

(defface sov-ui-mode-line-changed
  '((t (:inherit diff-changed)))
  "Face for changed diff hunks in the mode line.")

(defface sov-ui-mode-line-removed
  '((t (:inherit diff-removed)))
  "Face for removed diff hunks in the mode line.")

(defface sov-ui-mode-line-condition
  '((t (:inherit font-lock-constant-face)))
  "Face for condition indicators in the mode line.")

(defface sov-ui-mode-line-major
  '((t (:inherit font-lock-type-face :weight bold)))
  "Face for the major mode segment in the mode line.")

(defface sov-ui-mode-line-ruler
  '((t (:inherit mode-line :weight bold)))
  "Face for the ruler (line/column) segment in the mode line.")

(defface sov-ui-mode-line-inactive
  '((t (:inherit mode-line-inactive)))
  "Face for the inactive mode line.")


;;; Face color helpers

(defun sov-ui--face-color (face attribute fallback)
  "Return the value of ATTRIBUTE for FACE, or FALLBACK if unspecified.
This is used to read colors from the active theme so the mode line can
blend with it dynamically."
  (let ((value (face-attribute face attribute nil 'default)))
    (if (or (null value)
            (eq value 'unspecified))
        fallback
      value)))

(defun sov-ui--refresh-faces (&optional _theme)
  "Refresh state and segment face colors from the current theme.
This is called on `enable-theme-functions' so the mode line colors adapt
after loading or switching themes."
  (let* ((dark (sov-ui--face-color 'default :background "black"))
         (base (sov-ui--face-color 'mode-line :background dark))
         (secondary (sov-ui--face-color
                     'mode-line-inactive :background base))
         (states
          `((sov-ui-mode-line-normal
             . ,(sov-ui--face-color
                 'font-lock-function-name-face :foreground "blue"))
            (sov-ui-mode-line-insert
             . ,(sov-ui--face-color
                 'font-lock-string-face :foreground "green"))
            (sov-ui-mode-line-visual
             . ,(sov-ui--face-color
                 'font-lock-keyword-face :foreground "purple"))
            (sov-ui-mode-line-replace
             . ,(sov-ui--face-color 'error :foreground "red"))
            (sov-ui-mode-line-operator
             . ,(sov-ui--face-color 'warning :foreground "yellow"))
            (sov-ui-mode-line-emacs
             . ,(sov-ui--face-color
                 'font-lock-builtin-face :foreground "cyan")))))
    (dolist (entry states)
      (set-face-attribute (car entry) nil
                          :foreground dark
                          :background (cdr entry)
                          :weight 'bold))
    (set-face-attribute 'sov-ui-mode-line-branch nil
                        :foreground 'unspecified
                        :background secondary)
    (set-face-attribute 'sov-ui-mode-line-ruler nil
                        :foreground dark
                        :background (cdar states)))
  (force-mode-line-update t))

(add-hook 'enable-theme-functions #'sov-ui--refresh-faces)
(sov-ui--refresh-faces)


;;; Buffer-local caches

(defvar-local sov-ui--file-icon-cache nil
  "Cache for the file/major-mode icon used in the mode line.
Cleared when the visited file or major mode changes.")

(defvar-local sov-ui--major-icon-cache nil
  "Cache for the major mode icon used in the mode line.
Cleared when the major mode changes.")

(defvar-local sov-ui--path-cache nil
  "Cache for the path variants used in the mode line.
Cleared when the visited file or major mode changes.")

(defun sov-ui--clear-buffer-cache ()
  "Clear the buffer-local mode line caches and refresh the mode line."
  (setq sov-ui--file-icon-cache nil
        sov-ui--major-icon-cache nil
        sov-ui--path-cache nil)
  (force-mode-line-update))


;;; Icon helpers

(defun sov-ui--safe-icon (function argument fallback face)
  "Return an icon from FUNCTION applied to ARGUMENT, or FALLBACK text.
The icon is propertized with FACE.  If the icon library signals an error
or returns nil, FALLBACK is returned instead so the mode line never loses
its segment."
  (let ((fallback (propertize fallback 'face face)))
    (condition-case nil
        (or (funcall function argument :face face) fallback)
      (error fallback))))

(defun sov-ui--file-icon ()
  "Return the icon for the current buffer's file or major mode."
  (or sov-ui--file-icon-cache
      (setq sov-ui--file-icon-cache
            (if buffer-file-name
                (sov-ui--safe-icon
                 #'nerd-icons-icon-for-file buffer-file-name
                 "F" 'sov-ui-mode-line-file)
              (sov-ui--safe-icon
               #'nerd-icons-icon-for-mode major-mode
               "B" 'sov-ui-mode-line-file)))))

(defun sov-ui--major-icon ()
  "Return the icon for the current buffer's major mode."
  (or sov-ui--major-icon-cache
      (setq sov-ui--major-icon-cache
            (sov-ui--safe-icon
             #'nerd-icons-icon-for-mode major-mode
             "M" 'sov-ui-mode-line-major))))

(defun sov-ui--current-paths ()
  "Return the cached path variants for the current buffer.
See `sov-ui--path-variants' for the list format."
  (or sov-ui--path-cache
      (setq sov-ui--path-cache
            (if buffer-file-name
                (sov-ui--path-variants
                 buffer-file-name
                 (when-let ((project (project-current nil)))
                   (project-root project)))
              (list (buffer-name)
                    (buffer-name)
                    (buffer-name))))))


;;; Buffer flag and file segments

(defun sov-ui--buffer-flags ()
  "Return propertized text for modified and read-only buffer states."
  (concat
   (if (buffer-modified-p)
       (propertize " *" 'face 'sov-ui-mode-line-modified)
     "")
   (if buffer-read-only
       (concat
        " "
        (sov-ui--safe-icon
         #'nerd-icons-mdicon "nf-md-lock"
         "RO" 'sov-ui-mode-line-read-only))
     "")))

(defun sov-ui--file-segment (path-index inactive &optional max-width)
  "Build the file-path segment for the mode line.
PATH-INDEX selects which path variant from `sov-ui--current-paths' to use:
0 = full project-relative path, 1 = shortened path, 2 = file name only.
When INACTIVE is non-nil, the segment is dimmed and the directory is hidden.
Optional MAX-WIDTH truncates the file name to fit."
  (let* ((path (nth path-index (sov-ui--current-paths)))
         (directory (file-name-directory path))
         (name (file-name-nondirectory path))
         (face (if inactive
                   'sov-ui-mode-line-inactive
                 'sov-ui-mode-line-file))
         (prefix (concat " " (sov-ui--file-icon) " "))
         (directory-text (if (and directory (not inactive))
                             directory
                           ""))
         (flags (sov-ui--buffer-flags))
         (fixed-width (+ (string-width prefix)
                         (string-width directory-text)
                         (string-width flags)
                         1))
         (name-width (and max-width
                          (max 1 (- max-width fixed-width))))
         (display-name (if name-width
                           (truncate-string-to-width
                            name name-width nil nil "…")
                         name)))
    (concat
     prefix
     (if (string-empty-p directory-text)
         ""
       (propertize directory-text
                   'face 'sov-ui-mode-line-directory))
     (propertize display-name 'face face)
     flags
     " ")))


;;; Git branch

(defun sov-ui--git-branch ()
  "Return the current Git branch name, or nil if not in a Git buffer.
This parses `vc-mode' rather than shelling out, so it is cheap."
  (when vc-mode
    (let ((text (string-trim
                 (substring-no-properties
                  (if (stringp vc-mode)
                      vc-mode
                    (format-mode-line vc-mode))))))
      (when (string-match "\\`Git[:@-]\\(.+\\)\\'" text)
        (match-string 1 text)))))


;;; Diff segment

(defun sov-ui--diff-segment ()
  "Return a propertized diff hunk summary from the cached counts.
Only non-zero counts are shown, in the form +ADDED ~CHANGED -REMOVED."
  (pcase-let ((`(,added ,changed ,removed) sov-ui--diff-hunks))
    (concat
     (if (> added 0)
         (propertize (format " +%d" added)
                     'face 'sov-ui-mode-line-added)
       "")
     (if (> changed 0)
         (propertize (format " ~%d" changed)
                     'face 'sov-ui-mode-line-changed)
       "")
     (if (> removed 0)
         (propertize (format " -%d" removed)
                     'face 'sov-ui-mode-line-removed)
       "")
     (if (> (+ added changed removed) 0) " " ""))))


;;; State and branch segments

(defun sov-ui--face-background (face)
  "Return the background color of FACE, falling back to the mode-line color."
  (sov-ui--face-color
   face :background
   (sov-ui--face-color 'mode-line :background "black")))

(defun sov-ui--state-segment (compact)
  "Return the Evil state segment.
When COMPACT is non-nil, only the first letter of the state name is shown."
  (pcase-let ((`(,label ,face)
               (sov-ui--evil-info
                (if (boundp 'evil-state) evil-state 'emacs)
                compact)))
    (concat
     (propertize " " 'face face)
     (sov-ui--safe-icon
      #'nerd-icons-flicon "nf-linux-gentoo" "E" face)
     (propertize (format " %s " label) 'face face))))

(defun sov-ui--branch-segment (branch)
  "Return the Git branch segment, or an empty string if BRANCH is nil."
  (if branch
      (concat
       (propertize " " 'face 'sov-ui-mode-line-branch)
       (sov-ui--safe-icon
        #'nerd-icons-powerline "nf-pl-branch"
        "G" 'sov-ui-mode-line-branch)
       (propertize (format " %s " branch)
                   'face 'sov-ui-mode-line-branch))
    ""))


;;; Flymake and condition segments

(defun sov-ui--flymake-segment ()
  "Return the Flymake error and warning segment.
Only non-zero counts are rendered."
  (pcase-let ((`(,errors ,warnings) (sov-ui--flymake-counts)))
    (concat
     (if (> errors 0)
         (concat
          (propertize " " 'face 'sov-ui-mode-line-error)
          (sov-ui--safe-icon
           #'nerd-icons-mdicon "nf-md-close_circle_outline"
           "E" 'sov-ui-mode-line-error)
          (propertize (format " %d" errors)
                      'face 'sov-ui-mode-line-error))
       "")
     (if (> warnings 0)
         (concat
          (propertize " " 'face 'sov-ui-mode-line-warning)
          (sov-ui--safe-icon
           #'nerd-icons-mdicon "nf-md-alert_outline"
           "W" 'sov-ui-mode-line-warning)
          (propertize (format " %d" warnings)
                      'face 'sov-ui-mode-line-warning))
       ""))))

(defun sov-ui--conditions-segment (compact)
  "Return the buffer condition indicators.
When COMPACT is non-nil, only icons are shown; otherwise the label follows
each icon."
  (mapconcat
   (lambda (item)
     (concat
      (propertize " " 'face 'sov-ui-mode-line-condition)
      (nth 1 item)
      (if compact
          ""
        (propertize (concat " " (nth 2 item))
                    'face 'sov-ui-mode-line-condition))))
   (sov-ui--condition-items)
   ""))


;;; Major mode and ruler segments

(defun sov-ui--major-segment (compact)
  "Return the major mode segment.
When COMPACT is non-nil, only the icon is shown; otherwise the mode name
is included."
  (concat
   " "
   (sov-ui--major-icon)
   (if compact
       " "
     (format " %s "
             (substring-no-properties
              (format-mode-line mode-name))))))

(defun sov-ui--ruler-segments ()
  "Return the ruler segment (line/column or selection metrics).
The ruler face uses the current Evil state color as its background."
  (pcase-let* ((`(,_label ,state-face)
                (sov-ui--evil-info
                 (if (boundp 'evil-state) evil-state 'emacs)
                 nil))
               (state-color (sov-ui--face-background state-face))
               (dark (sov-ui--face-color
                      'default :background "black"))
               (ruler (if (use-region-p)
                          (sov-ui--region-metrics
                           (region-beginning)
                           (region-end)
                           (sov-ui--selection-kind))
                        (format-mode-line "%l:%c"))))
    (list
     (propertize (format " %s  " ruler)
                 'face `(:inherit sov-ui-mode-line-ruler
                         :foreground ,dark
                         :background ,state-color)))))


;;; Cache invalidation hooks

;; Recompute path and icon information when the file name or major mode
;; changes.  This keeps the mode line accurate without rebuilding on every
;; refresh.
(add-hook 'after-set-visited-file-name-hook
          #'sov-ui--clear-buffer-cache)
(add-hook 'after-change-major-mode-hook
          #'sov-ui--clear-buffer-cache)


;;; Layout engine

;; The layout is built as a collection of `tier' layouts.  Each tier is a
;; candidate that may or may not fit in the available width.  Lower tiers are
;; richer; higher tiers are progressively more compact.  The first tier that
;; fits is chosen, with a final truncated layout as a fallback.

(cl-defstruct sov-ui--layout
  "A candidate mode line layout for a given window width."
  tier
  left
  right)

(defun sov-ui--strings-width (strings)
  "Return the total display width of STRINGS."
  (seq-reduce #'+ (mapcar #'string-width strings) 0))

(defun sov-ui--layout-width (layout)
  "Return the estimated width of LAYOUT in columns.
This includes one extra column for spacing between the left and right sides."
  (1+ (+ (sov-ui--strings-width (sov-ui--layout-left layout))
         (sov-ui--strings-width (sov-ui--layout-right layout)))))

(defun sov-ui--choose-layout (width layouts)
  "Return the first layout in LAYOUTS that fits within WIDTH.
If none fit, return the last layout."
  (or (seq-find
       (lambda (layout)
         (<= (sov-ui--layout-width layout) width))
       layouts)
      (car (last layouts))))

(defun sov-ui--tier-settings (tier)
  "Return a list of booleans describing how to render layout TIER.
The values are, in order:
  path-index, major-compact, conditions-compact, state-compact,
  show-flymake, show-diff, show-branch.
This function is also exercised by the test suite."
  (list
   (cond
    ((= tier 0) 0)
    ((= tier 1) 1)
    (t 2))
   (>= tier 3)
   (>= tier 4)
   (>= tier 5)
   (< tier 6)
   (< tier 7)
   (< tier 8)))

(defun sov-ui--build-active-tier (tier)
  "Build the left and right segments for active-window tier TIER."
  (pcase-let* ((`(,path-index
                  ,major-compact
                  ,conditions-compact
                  ,state-compact
                  ,show-flymake
                  ,show-diff
                  ,show-branch)
                (sov-ui--tier-settings tier))
               (branch (and show-branch
                            (sov-ui--git-branch)))
               (left
                (list
                 (sov-ui--state-segment state-compact)
                 (sov-ui--branch-segment branch)
                 (if show-flymake
                     (sov-ui--flymake-segment)
                   "")
                 (sov-ui--file-segment path-index nil)))
               (right
                (append
                 (list
                  (if show-diff
                      (sov-ui--diff-segment)
                    "")
                  (sov-ui--conditions-segment conditions-compact)
                  (sov-ui--major-segment major-compact))
                 (sov-ui--ruler-segments))))
    (make-sov-ui--layout
     :tier tier
     :left left
     :right right)))

(defun sov-ui--truncate-file-in-layout (layout width)
  "Truncate the file segment in LAYOUT so the whole layout fits in WIDTH.
This is used as the final fallback when even the most compressed tier is
wider than the window."
  (let* ((left (copy-sequence (sov-ui--layout-left layout)))
         (file (car (last left)))
         (overage (max 0 (- (sov-ui--layout-width layout) width)))
         (target (max 4 (- (string-width file) overage))))
    (setcar (last left)
            (sov-ui--file-segment 2 nil target))
    (setf (sov-ui--layout-left layout) left)
    layout))

(defun sov-ui--build-active-layout (width)
  "Build the best active-window layout for the given window WIDTH.
Generate all tiers from 0 to 8 and pick the first one that fits, falling
back to a truncated file-name-only layout if necessary."
  (let* ((layouts (mapcar #'sov-ui--build-active-tier
                          (number-sequence 0 8)))
         (fallback (sov-ui--truncate-file-in-layout
                    (sov-ui--build-active-tier 9)
                    width)))
    (sov-ui--choose-layout width
                           (append layouts (list fallback)))))

(defun sov-ui--build-inactive-layout (width)
  "Build the minimal layout for an inactive window.
Only the file name (or buffer name) is shown, and the right side is empty."
  (make-sov-ui--layout
   :tier 'inactive
   :left (list
          (sov-ui--file-segment 2 t (max 1 (1- width))))
   :right nil))


;;; Mode line format hooks

(defun sov-ui--mode-line-left ()
  "Return the left side of the mode line for the selected window.
The chosen layout is cached in the window parameter
`sov-ui--mode-line-layout' so `sov-ui--mode-line-right' can reuse it.
If the layout computation fails, return a safe fallback showing the buffer
name so the mode line never becomes completely blank."
  (condition-case nil
      (let* ((window (selected-window))
             (layout
              (if (mode-line-window-selected-p)
                  (sov-ui--build-active-layout
                   (window-total-width window))
                (sov-ui--build-inactive-layout
                 (window-total-width window)))))
        (set-window-parameter window
                              'sov-ui--mode-line-layout
                              layout)
        (sov-ui--layout-left layout))
    (error
     (set-window-parameter (selected-window)
                           'sov-ui--mode-line-layout
                           nil)
     (list
      (propertize (format " %s " (buffer-name))
                  'face 'sov-ui-mode-line-inactive)))))

(defun sov-ui--mode-line-right ()
  "Return the right side of the mode line for the selected window.
This reuses the layout stored by `sov-ui--mode-line-left' in the window
parameter."
  (when-let ((layout
              (window-parameter
               (selected-window)
               'sov-ui--mode-line-layout)))
    (sov-ui--layout-right layout)))


;;; Mode line format installation

;; Align the right side of the mode line against the right fringe.  This is
;; more predictable than the default right-margin alignment and avoids the
;; right segment drifting with the window body.
(setq mode-line-right-align-edge 'right-fringe)

(setq-default mode-line-format
              '((:eval (sov-ui--mode-line-left))
                mode-line-format-right-align
                (:eval (sov-ui--mode-line-right))))


(provide 'sov-ui-modeline)

;;; sov-ui-modeline.el ends here
