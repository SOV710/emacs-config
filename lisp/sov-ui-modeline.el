;;; sov-ui-modeline.el --- Custom mode line -*- lexical-binding: t; -*-

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
(declare-function nerd-icons-powerline-family "nerd-icons" ())

(defconst sov-ui--separator-lower-left "\ue0b8")
(defconst sov-ui--separator-lower-right "\ue0ba")
(defconst sov-ui--separator-upper-left "\ue0bc")
(defconst sov-ui--separator-upper-right "\ue0be")

(defface sov-ui-mode-line-normal
  '((t (:inherit mode-line :weight bold)))
  "Normal state.")

(defface sov-ui-mode-line-insert
  '((t (:inherit mode-line :weight bold)))
  "Insert state.")

(defface sov-ui-mode-line-visual
  '((t (:inherit mode-line :weight bold)))
  "Visual state.")

(defface sov-ui-mode-line-replace
  '((t (:inherit mode-line :weight bold)))
  "Replace state.")

(defface sov-ui-mode-line-operator
  '((t (:inherit mode-line :weight bold)))
  "Operator state.")

(defface sov-ui-mode-line-emacs
  '((t (:inherit mode-line :weight bold)))
  "Emacs state.")

(defconst sov-ui--evil-state-table
  '((normal "NORMAL" sov-ui-mode-line-normal)
    (motion "MOTION" sov-ui-mode-line-normal)
    (insert "INSERT" sov-ui-mode-line-insert)
    (visual "VISUAL" sov-ui-mode-line-visual)
    (replace "REPLACE" sov-ui-mode-line-replace)
    (operator "OPERATOR" sov-ui-mode-line-operator)
    (emacs "EMACS" sov-ui-mode-line-emacs)))

(defun sov-ui--evil-info (state compact)
  (let* ((entry (or (assq state sov-ui--evil-state-table)
                    (list state (upcase (symbol-name state))
                          'sov-ui-mode-line-normal)))
         (label (nth 1 entry)))
    (list (if compact (substring label 0 1) label)
          (nth 2 entry))))

(defun sov-ui--shorten-path (path)
  (let ((parts (split-string path "/" t)))
    (mapconcat
     #'identity
     (append (mapcar (lambda (part) (substring part 0 1))
                     (butlast parts))
             (last parts))
     "/")))

(defun sov-ui--path-variants (file root)
  (let* ((full (if root
                   (file-relative-name file root)
                 (abbreviate-file-name file)))
         (base (file-name-nondirectory file)))
    (list full (sov-ui--shorten-path full) base)))

(defun sov-ui--count-diff-hunks (changes)
  (let ((added 0)
        (changed 0)
        (removed 0))
    (dolist (change changes)
      (pcase (nth 2 change)
        ('insert (cl-incf added))
        ('change (cl-incf changed))
        ('delete (cl-incf removed))))
    (list added changed removed)))

(defun sov-ui--line-number-at (position)
  (line-number-at-pos position t))

(defun sov-ui--column-at (position)
  (save-excursion
    (goto-char position)
    (current-column)))

(defun sov-ui--region-metrics (begin end kind)
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
  (pcase (and (boundp 'evil-visual-selection)
              evil-visual-selection)
    ('line 'line)
    ('block 'block)
    (_ 'character)))

(defun sov-ui--flymake-counts ()
  (let ((errors 0)
        (warnings 0))
    (when (bound-and-true-p flymake-mode)
      (dolist (diagnostic (flymake-diagnostics))
        (pcase (flymake-diagnostic-type diagnostic)
          (:error (cl-incf errors))
          (:warning (cl-incf warnings)))))
    (list errors warnings)))

(defun sov-ui--condition-items ()
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

(use-package nerd-icons
  :ensure t)

(defvar-local sov-ui--diff-hunks '(0 0 0))

(defun sov-ui--cache-diff-hunks (changes)
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

(defface sov-ui-mode-line-branch
  '((t (:inherit mode-line)))
  "Git branch block.")

(defface sov-ui-mode-line-directory
  '((t (:inherit shadow)))
  "Path directories.")

(defface sov-ui-mode-line-file
  '((t (:inherit mode-line :weight bold)))
  "File name.")

(defface sov-ui-mode-line-modified
  '((t (:inherit warning :weight bold)))
  "Modified flag.")

(defface sov-ui-mode-line-read-only
  '((t (:inherit warning)))
  "Read-only flag.")

(defface sov-ui-mode-line-error
  '((t (:inherit error)))
  "Flymake errors.")

(defface sov-ui-mode-line-warning
  '((t (:inherit warning)))
  "Flymake warnings.")

(defface sov-ui-mode-line-added
  '((t (:inherit diff-added)))
  "Added hunks.")

(defface sov-ui-mode-line-changed
  '((t (:inherit diff-changed)))
  "Changed hunks.")

(defface sov-ui-mode-line-removed
  '((t (:inherit diff-removed)))
  "Removed hunks.")

(defface sov-ui-mode-line-condition
  '((t (:inherit font-lock-constant-face)))
  "Conditional state.")

(defface sov-ui-mode-line-major
  '((t (:inherit font-lock-type-face :weight bold)))
  "Major mode.")

(defface sov-ui-mode-line-ruler
  '((t (:inherit mode-line :weight bold)))
  "Ruler block.")

(defface sov-ui-mode-line-percent
  '((t (:inherit mode-line :weight bold)))
  "Percentage block.")

(defface sov-ui-mode-line-inactive
  '((t (:inherit mode-line-inactive)))
  "Inactive content.")

(defun sov-ui--face-color (face attribute fallback)
  (let ((value (face-attribute face attribute nil 'default)))
    (if (or (null value)
            (eq value 'unspecified))
        fallback
      value)))

(defun sov-ui--refresh-faces (&optional _theme)
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
                        :foreground (cdar states)
                        :background secondary)
    (set-face-attribute 'sov-ui-mode-line-percent nil
                        :foreground dark
                        :background (cdar states)))
  (force-mode-line-update t))

(add-hook 'enable-theme-functions #'sov-ui--refresh-faces)
(sov-ui--refresh-faces)

(defvar-local sov-ui--file-icon-cache nil)
(defvar-local sov-ui--major-icon-cache nil)
(defvar-local sov-ui--path-cache nil)

(defun sov-ui--clear-buffer-cache ()
  (setq sov-ui--file-icon-cache nil
        sov-ui--major-icon-cache nil
        sov-ui--path-cache nil)
  (force-mode-line-update))

(defun sov-ui--safe-icon (function argument fallback face)
  (let ((fallback (propertize fallback 'face face)))
    (condition-case nil
        (or (funcall function argument :face face) fallback)
      (error fallback))))

(defun sov-ui--file-icon ()
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
  (or sov-ui--major-icon-cache
      (setq sov-ui--major-icon-cache
            (sov-ui--safe-icon
             #'nerd-icons-icon-for-mode major-mode
             "M" 'sov-ui-mode-line-major))))

(defun sov-ui--current-paths ()
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

(defun sov-ui--buffer-flags ()
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

(defun sov-ui--git-branch ()
  (when vc-mode
    (let ((text (string-trim
                 (substring-no-properties
                  (if (stringp vc-mode)
                      vc-mode
                    (format-mode-line vc-mode))))))
      (when (string-match "\\`Git[:@-]\\(.+\\)\\'" text)
        (match-string 1 text)))))

(defun sov-ui--diff-segment ()
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

(defun sov-ui--face-background (face)
  (sov-ui--face-color
   face :background
   (sov-ui--face-color 'mode-line :background "black")))

(defun sov-ui--powerline-glyph (glyph foreground background)
  (propertize
   glyph
   'face `(:family ,(nerd-icons-powerline-family)
           :foreground ,foreground
           :background ,background)))

(defun sov-ui--separator (glyph foreground-face background-face)
  (sov-ui--powerline-glyph
   glyph
   (sov-ui--face-background foreground-face)
   (sov-ui--face-background background-face)))

(defun sov-ui--state-segment (compact branch-visible)
  (pcase-let* ((`(,label ,face)
                (sov-ui--evil-info
                 (if (boundp 'evil-state) evil-state 'emacs)
                 compact))
               (next-face (if branch-visible
                              'sov-ui-mode-line-branch
                            'mode-line)))
    (concat
     (propertize " " 'face face)
     (sov-ui--safe-icon
      #'nerd-icons-flicon "nf-linux-gentoo" "E" face)
     (propertize (format " %s " label) 'face face)
     (sov-ui--separator
      (if branch-visible
          sov-ui--separator-lower-left
        sov-ui--separator-upper-left)
      face next-face))))

(defun sov-ui--branch-segment (branch)
  (if branch
      (concat
       (propertize " " 'face 'sov-ui-mode-line-branch)
       (sov-ui--safe-icon
        #'nerd-icons-powerline "nf-pl-branch"
        "G" 'sov-ui-mode-line-branch)
       (propertize (format " %s " branch)
                   'face 'sov-ui-mode-line-branch)
       (sov-ui--separator
        sov-ui--separator-upper-left
        'sov-ui-mode-line-branch 'mode-line))
    ""))

(defun sov-ui--flymake-segment ()
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

(defun sov-ui--major-segment (compact)
  (concat
   " "
   (sov-ui--major-icon)
   (if compact
       " "
     (format " %s "
             (substring-no-properties
              (format-mode-line mode-name))))))

(defun sov-ui--ruler-segments ()
  (pcase-let* ((`(,_label ,state-face)
                (sov-ui--evil-info
                 (if (boundp 'evil-state) evil-state 'emacs)
                 nil))
               (state-color (sov-ui--face-background state-face))
               (secondary
                (sov-ui--face-background 'sov-ui-mode-line-branch))
               (base (sov-ui--face-background 'mode-line))
               (dark (sov-ui--face-color
                      'default :background "black"))
               (ruler (if (use-region-p)
                          (sov-ui--region-metrics
                           (region-beginning)
                           (region-end)
                           (sov-ui--selection-kind))
                        (format-mode-line "%l:%c")))
               (percent (format-mode-line "%p")))
    (list
     (sov-ui--powerline-glyph
      sov-ui--separator-lower-right secondary base)
     (propertize (format " %s " ruler)
                 'face `(:inherit sov-ui-mode-line-ruler
                         :foreground ,state-color
                         :background ,secondary))
     (sov-ui--powerline-glyph
      sov-ui--separator-upper-right state-color secondary)
     (propertize (format " %s " percent)
                 'face `(:inherit sov-ui-mode-line-percent
                         :foreground ,dark
                         :background ,state-color)))))

(add-hook 'after-set-visited-file-name-hook
          #'sov-ui--clear-buffer-cache)
(add-hook 'after-change-major-mode-hook
          #'sov-ui--clear-buffer-cache)

(cl-defstruct sov-ui--layout
  tier
  left
  right)

(defun sov-ui--strings-width (strings)
  (seq-reduce #'+ (mapcar #'string-width strings) 0))

(defun sov-ui--layout-width (layout)
  (1+ (+ (sov-ui--strings-width (sov-ui--layout-left layout))
         (sov-ui--strings-width (sov-ui--layout-right layout)))))

(defun sov-ui--choose-layout (width layouts)
  (or (seq-find
       (lambda (layout)
         (<= (sov-ui--layout-width layout) width))
      layouts)
      (car (last layouts))))

(defun sov-ui--tier-settings (tier)
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
                 (sov-ui--state-segment state-compact branch)
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
  (let* ((left (copy-sequence (sov-ui--layout-left layout)))
         (file (car (last left)))
         (overage (max 0 (- (sov-ui--layout-width layout) width)))
         (target (max 4 (- (string-width file) overage))))
    (setcar (last left)
            (sov-ui--file-segment 2 nil target))
    (setf (sov-ui--layout-left layout) left)
    layout))

(defun sov-ui--build-active-layout (width)
  (let* ((layouts (mapcar #'sov-ui--build-active-tier
                          (number-sequence 0 8)))
         (fallback (sov-ui--truncate-file-in-layout
                    (sov-ui--build-active-tier 9)
                    width)))
    (sov-ui--choose-layout width
                           (append layouts (list fallback)))))

(defun sov-ui--build-inactive-layout (width)
  (make-sov-ui--layout
   :tier 'inactive
   :left (list
          (sov-ui--file-segment 2 t (max 1 (1- width))))
   :right nil))

(defun sov-ui--mode-line-left ()
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
  (when-let ((layout
              (window-parameter
               (selected-window)
               'sov-ui--mode-line-layout)))
    (sov-ui--layout-right layout)))

(setq-default mode-line-format
              '((:eval (sov-ui--mode-line-left))
                mode-line-format-right-align
                (:eval (sov-ui--mode-line-right))))

(provide 'sov-ui-modeline)
;;; sov-ui-modeline.el ends here
