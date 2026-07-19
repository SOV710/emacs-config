;;; sov-lang-markdown.el --- Markdown language configuration -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)

(declare-function markdown-table-wrap "markdown-table-wrap"
                  (text width &optional max-cell-height strip-markup compact))
(declare-function markdown-table-wrap-inside-code-fence-p
                  "markdown-table-wrap" (pos))
(declare-function markdown-table-wrap-unwrap "markdown-table-wrap" (text))
(declare-function markdown-code-block-at-point-p "markdown-mode" ())

(defconst sov-markdown-table--start-marker-regexp
  "^<!-- sov-markdown-table-wrap width:\\([1-9][0-9]*\\) -->[ \t]*$")

(defconst sov-markdown-table--end-marker-regexp
  "^<!-- /sov-markdown-table-wrap -->[ \t]*$")

(defconst sov-markdown-table--marker-line-regexp
  "^<!--[ \t]+\\(?:/\\)?sov-markdown-table-wrap.*$")

(defconst sov-markdown-table--pipe-line-regexp
  "^[ \t]*|.*|[ \t]*$")

(defconst sov-markdown-table--separator-line-regexp
  "^[ \t]*|[-:| \t]*-[-:| \t]*|[ \t]*$")

(defun sov-markdown-table--marker-ranges ()
  "Return validated wrapped-table marker ranges in the current buffer.
Each result is a plist containing the marker, content, and width fields.
Signal `user-error' for malformed, unmatched, or nested markers."
  (save-excursion
    (goto-char (point-min))
    (let (open ranges)
      (while (re-search-forward sov-markdown-table--marker-line-regexp nil t)
        (let* ((line-beg (line-beginning-position))
               (line-end (line-end-position))
               (line (buffer-substring-no-properties line-beg line-end)))
          (cond
           ((string-match sov-markdown-table--start-marker-regexp line)
            (when open
              (user-error "Nested Markdown table wrap markers are invalid"))
            (unless (< line-end (point-max))
              (user-error "Markdown table wrap start marker has no content"))
            (setq open
                  (list :whole-beg line-beg
                        :content-beg (1+ line-end)
                        :width (string-to-number (match-string 1 line)))))
           ((string-match-p sov-markdown-table--end-marker-regexp line)
            (unless open
              (user-error "Markdown table wrap end marker has no start"))
            (let ((content-end line-beg))
              (when (and (> content-end (point-min))
                         (eq (char-before content-end) ?\n))
                (setq content-end (1- content-end)))
              (push (append open
                            (list :content-end content-end
                                  :whole-end line-end))
                    ranges)
              (setq open nil)))
           (t
            (user-error "Malformed Markdown table wrap marker: %s" line)))))
      (when open
        (user-error "Markdown table wrap start marker has no end"))
      (nreverse ranges))))

(defun sov-markdown-table--range-at-point (ranges)
  "Return the member of RANGES containing point, or nil."
  (let ((pos (point)))
    (cl-find-if (lambda (range)
                  (and (<= (plist-get range :whole-beg) pos)
                       (<= pos (plist-get range :whole-end))))
                ranges)))

(defun sov-markdown-table--line-count (text)
  "Return the number of nonempty lines in TEXT."
  (length (split-string text "\n" t)))

(defun sov-markdown-table--table-region-at-point ()
  "Return bounds of the pipe table at point, or signal `user-error'."
  (save-excursion
    (beginning-of-line)
    (unless (looking-at-p sov-markdown-table--pipe-line-regexp)
      (user-error "Point is not in a Markdown pipe table"))
    (while (and (> (line-beginning-position) (point-min))
                (progn
                  (forward-line -1)
                  (looking-at-p sov-markdown-table--pipe-line-regexp))))
    (unless (looking-at-p sov-markdown-table--pipe-line-regexp)
      (forward-line 1))
    (let ((beg (line-beginning-position)))
      (while (and (looking-at-p sov-markdown-table--pipe-line-regexp)
                  (= (forward-line 1) 0)))
      (let ((end (if (bolp) (1- (point)) (line-end-position))))
        (cons beg end)))))

(defun sov-markdown-table--valid-table-p (text &optional wrapped)
  "Return non-nil when TEXT is a structurally valid pipe table.
When WRAPPED is non-nil, allow multiple visual header lines."
  (let* ((lines (split-string text "\n" t))
         (separator-index
          (cl-position-if
           (lambda (line)
             (string-match-p sov-markdown-table--separator-line-regexp line))
           lines))
         (separator-count
          (cl-count-if
           (lambda (line)
             (string-match-p sov-markdown-table--separator-line-regexp line))
           lines)))
    (and (>= (length lines) 2)
         (cl-every (lambda (line)
                     (string-match-p sov-markdown-table--pipe-line-regexp line))
                   lines)
         (= separator-count 1)
         separator-index
         (> separator-index 0)
         (or wrapped (= separator-index 1)))))

(defun sov-markdown-table--unwrap-marked-text (text width)
  "Validate and unwrap marked table TEXT produced for WIDTH."
  (require 'markdown-table-wrap)
  (unless (sov-markdown-table--valid-table-p text t)
    (user-error "Wrapped Markdown table is structurally invalid"))
  (let ((unwrapped (markdown-table-wrap-unwrap text)))
    (unless (sov-markdown-table--valid-table-p unwrapped)
      (user-error "Wrapped Markdown table could not be unwrapped reliably"))
    (unless (equal unwrapped
                   (markdown-table-wrap-unwrap
                    (markdown-table-wrap unwrapped width)))
      (user-error "Wrapped Markdown table has ambiguous row boundaries"))
    unwrapped))

(defun sov-markdown-table--replace-range (beg end text)
  "Replace BEG through END with TEXT without disturbing surrounding newlines."
  (goto-char beg)
  (delete-region beg end)
  (insert text))

(defun sov-markdown-table-wrap-at-point (&optional width)
  "Wrap the Markdown pipe table at point for WIDTH columns.
With a numeric prefix argument, use that width.  Otherwise use the current
window body width with a two-column margin.  An already marked table is first
unwrapped, then rendered again at the new width."
  (interactive "P")
  (require 'markdown-table-wrap)
  (let* ((target-width (if width
                           (prefix-numeric-value width)
                         (max 20 (- (window-body-width) 2))))
         (ranges (sov-markdown-table--marker-ranges))
         (range (sov-markdown-table--range-at-point ranges))
         bounds raw beg end)
    (when (< target-width 1)
      (user-error "Markdown table width must be positive"))
    (if range
        (setq beg (plist-get range :whole-beg)
              end (plist-get range :whole-end)
              raw (sov-markdown-table--unwrap-marked-text
                   (buffer-substring-no-properties
                    (plist-get range :content-beg)
                    (plist-get range :content-end))
                   (plist-get range :width)))
      (setq bounds (sov-markdown-table--table-region-at-point)
            beg (car bounds)
            end (cdr bounds)
            raw (buffer-substring-no-properties beg end)))
    (when (markdown-table-wrap-inside-code-fence-p beg)
      (user-error "Markdown tables inside fenced code blocks are not wrapped"))
    (unless (sov-markdown-table--valid-table-p raw)
      (user-error "Point is not in a valid GFM pipe table"))
    (let* ((wrapped (markdown-table-wrap raw target-width))
           (needs-projection (> (sov-markdown-table--line-count wrapped)
                                (sov-markdown-table--line-count raw)))
           (replacement
            (if needs-projection
                (format "<!-- sov-markdown-table-wrap width:%d -->\n%s\n<!-- /sov-markdown-table-wrap -->"
                        target-width wrapped)
              wrapped)))
      (atomic-change-group
        (save-excursion
          (sov-markdown-table--replace-range beg end replacement))))))

(defun sov-markdown-table-unwrap-at-point ()
  "Unwrap the marked Markdown table at point and remove its markers."
  (interactive)
  (let* ((range (sov-markdown-table--range-at-point
                 (sov-markdown-table--marker-ranges))))
    (unless range
      (user-error "Point is not in a marked wrapped Markdown table"))
    (let ((unwrapped
           (sov-markdown-table--unwrap-marked-text
            (buffer-substring-no-properties
             (plist-get range :content-beg)
             (plist-get range :content-end))
            (plist-get range :width))))
      (atomic-change-group
        (save-excursion
          (sov-markdown-table--replace-range
           (plist-get range :whole-beg)
           (plist-get range :whole-end)
           unwrapped))))))

(defun sov-markdown-table-unwrap-buffer ()
  "Unwrap every marked Markdown table in the current buffer."
  (interactive)
  (let ((ranges (reverse (sov-markdown-table--marker-ranges))))
    (atomic-change-group
      (save-excursion
        (dolist (range ranges)
          (sov-markdown-table--replace-range
           (plist-get range :whole-beg)
           (plist-get range :whole-end)
           (sov-markdown-table--unwrap-marked-text
            (buffer-substring-no-properties
             (plist-get range :content-beg)
             (plist-get range :content-end))
            (plist-get range :width))))))))

(defun sov-markdown-table--project-content ()
  "Return current buffer contents with all marked tables unwrapped.
Signal `user-error' without modifying the current buffer when markers or
wrapped tables are invalid."
  (let ((source (current-buffer)))
    (with-temp-buffer
      (insert-buffer-substring source)
      (dolist (range (reverse (sov-markdown-table--marker-ranges)))
        (sov-markdown-table--replace-range
         (plist-get range :whole-beg)
         (plist-get range :whole-end)
         (sov-markdown-table--unwrap-marked-text
          (buffer-substring-no-properties
           (plist-get range :content-beg)
           (plist-get range :content-end))
          (plist-get range :width))))
      (buffer-string))))

(defun sov-markdown-table--apply-saved-file-modes (setmodes)
  "Restore file modes and extended attributes described by SETMODES."
  (when setmodes
    (condition-case nil
        (unless (with-demoted-errors "Error setting file modes: %S"
                  (set-file-modes buffer-file-name (car setmodes)))
          (set-file-extended-attributes buffer-file-name (nth 1 setmodes)))
      (error nil))))

(defun sov-markdown-table--write-projection (content)
  "Write CONTENT to the current visited file using standard save semantics.
Return a cons of the resulting `buffer-backed-up' value and SETMODES data."
  (let ((source (current-buffer))
        result)
    (with-temp-buffer
      (insert content)
      (setq buffer-file-name (buffer-local-value 'buffer-file-name source)
            buffer-file-truename
            (buffer-local-value 'buffer-file-truename source)
            buffer-file-coding-system
            (buffer-local-value 'buffer-file-coding-system source)
            save-buffer-coding-system
            (buffer-local-value 'save-buffer-coding-system source)
            buffer-backed-up (buffer-local-value 'buffer-backed-up source)
            write-region-annotate-functions
            (buffer-local-value 'write-region-annotate-functions source)
            write-region-post-annotation-function
            (buffer-local-value 'write-region-post-annotation-function source)
            file-precious-flag t
            default-directory (buffer-local-value 'default-directory source))
      (set-buffer-modified-p t)
      (let ((setmodes (basic-save-buffer-2)))
        (setq result (cons buffer-backed-up setmodes))))
    result))

(defun sov-markdown-table-projection-write-contents ()
  "Write an unwrapped projection when the current buffer has wrap markers."
  (let ((ranges (sov-markdown-table--marker-ranges)))
    (when ranges
      ;; Validate before invoking VC, then project again in case VC updated text.
      (sov-markdown-table--project-content)
      (vc-before-save)
      (let* ((projection (sov-markdown-table--project-content))
             (save-result (sov-markdown-table--write-projection projection)))
        (setq buffer-backed-up (car save-result))
        (sov-markdown-table--apply-saved-file-modes (cdr save-result))
        (set-buffer-modified-p nil)
        (set-visited-file-modtime)
        t))))

(defun sov-markdown-table-projection-setup ()
  "Install the wrapped-table projection writer in the current buffer."
  (add-hook 'write-contents-functions
            #'sov-markdown-table-projection-write-contents nil t))

(add-hook 'markdown-mode-hook #'sov-markdown-table-projection-setup)
(add-hook 'markdown-ts-mode-hook #'sov-markdown-table-projection-setup)

(use-package markdown-table-wrap
  :ensure (:host github
           :repo "dnouri/markdown-table-wrap"
           :wait t)
  :commands (markdown-table-wrap markdown-table-wrap-unwrap))

(defun sov-lang-markdown-mode ()
  "Use Tree-sitter Markdown when both grammars are ready, otherwise fall back."
  (interactive)
  (if (and (fboundp 'treesit-ready-p)
           (treesit-ready-p 'markdown t)
           (treesit-ready-p 'markdown-inline t)
           (fboundp 'markdown-ts-mode))
      (markdown-ts-mode)
    (markdown-mode)))

(defun sov-lang-markdown--protect-code-blocks-from-fill ()
  "Prevent `auto-fill-mode' from wrapping fenced code blocks."
  (add-hook 'fill-nobreak-predicate
            #'markdown-code-block-at-point-p nil t))

;; Render LaTeX math expressions as image overlays while editing Markdown.
;; `math-preview-auto-mode' refreshes previews after buffer changes; the
;; external LaTeX and image-conversion tools are discovered automatically.
(use-package math-preview
  :ensure (:host gitlab
           :repo "matsievskiysv/math-preview"
           :wait t)
  :hook ((markdown-mode . math-preview-auto-mode)
         (markdown-ts-mode . math-preview-auto-mode)))

;; Markdown mode supplies editing commands and font-locking; its optional
;; Tree-sitter mode is used when the installed version provides it.  Long
;; paragraphs wrap visually without inserting newlines while typing.
(use-package markdown-mode
  :ensure (:host github
           :repo "jrblevin/markdown-mode"
           :wait t)
  :mode (("\\.md\\'" . sov-lang-markdown-mode)
         ("\\.markdown\\'" . sov-lang-markdown-mode)
         ("\\.mdown\\'" . sov-lang-markdown-mode)
         ("\\.mkdn\\'" . sov-lang-markdown-mode))
  :custom
  (markdown-italic-underscore t)
  (markdown-fontify-code-blocks-natively t)
  (markdown-fontify-whole-heading-line t)
  (markdown-enable-math t)
  (markdown-enable-highlighting-syntax t)
  (markdown-hide-urls nil)
  (markdown-mouse-follow-link nil)
  :hook ((markdown-mode . visual-line-mode)
         (markdown-mode . sov-lang-markdown--protect-code-blocks-from-fill))
  :config
  (evil-define-key 'normal markdown-mode-map
    (kbd "<localleader>tw") #'sov-markdown-table-wrap-at-point
    (kbd "<localleader>tu") #'sov-markdown-table-unwrap-at-point
    (kbd "<localleader>tU") #'sov-markdown-table-unwrap-buffer))

;; Doom uses GFM mode for README files because repositories commonly rely on
;; GitHub-specific tables, task lists, and fenced-code conventions.
(add-to-list 'auto-mode-alist '("/README\\(?:\\.md\\)?\\'" . gfm-mode))

;; Emacs 31 provides this mode itself.  On Emacs 30, install the same focused
;; compatibility package Doom uses rather than pretending `markdown-mode'
;; consumes Tree-sitter grammars directly.
(use-package markdown-ts-mode
  :ensure (:host github
           :repo "LionyxML/markdown-ts-mode"
           :wait t)
  :commands markdown-ts-mode
  :hook (markdown-ts-mode . visual-line-mode)
  :config
  (evil-define-key 'normal markdown-ts-mode-map
    (kbd "<localleader>tw") #'sov-markdown-table-wrap-at-point
    (kbd "<localleader>tu") #'sov-markdown-table-unwrap-at-point
    (kbd "<localleader>tU") #'sov-markdown-table-unwrap-buffer))

;; `valign' is installed by the Org language module and shared here.  It only
;; adds display properties; Markdown table source and semantics stay intact.
(use-package valign
  :ensure nil
  :custom
  (valign-max-table-size 10000)
  :hook ((markdown-mode . valign-mode)
         (gfm-mode . valign-mode)
         (markdown-ts-mode . valign-mode)))

;; Register Markdown Tree-sitter grammars when the built-in `treesit' package
;; is available.  Install them interactively with `treesit-install-language-grammar'.
(when (require 'treesit nil t)
  (let* ((url "https://github.com/tree-sitter-grammars/tree-sitter-markdown")
         ;; Grammar v0.5 requires Tree-sitter ABI 15 or newer.
         (revision (if (< (treesit-library-abi-version) 15)
                       "v0.4.1"
                     "v0.5.1")))
    (add-to-list 'treesit-language-source-alist
                 `(markdown ,url ,revision "tree-sitter-markdown/src"))
    (add-to-list 'treesit-language-source-alist
                 `(markdown-inline ,url ,revision
                                   "tree-sitter-markdown-inline/src"))))


(provide 'sov-lang-markdown)
;;; sov-lang-markdown.el ends here
