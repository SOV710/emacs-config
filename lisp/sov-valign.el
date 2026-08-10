;;; sov-valign.el --- Valign display compatibility -*- lexical-binding: t; -*-

;; Keep valign's pixel measurement and normal-cell alignment, but render
;; separator cells with a local pixel width.  The upstream implementation
;; uses successive absolute `:align-to' positions; Emacs 31 PGTK can display
;; those strike-through stretch overlays beyond their intended columns.

(require 'cl-lib)
(require 'subr-x)

(declare-function valign--glyph-width-of "valign" (string point))
(declare-function valign--maybe-render-bar "valign" (point))
(declare-function valign--pixel-width-from-to "valign" (from to))
(declare-function valign--put-overlay "valign" (beg end &rest props))
(declare-function valign--render-bar "valign" (point))
(declare-function valign--separator-line-p "valign" (&optional charset))
(declare-function valign-reset-buffer "valign" ())

(defvar valign-fancy-bar)
(defvar valign-mode)

(defun sov-valign--clear-separator-wrap-properties ()
  "Remove wrapping display properties from the current separator row.

`visual-wrap-prefix-mode' can classify a punctuation-only Markdown separator
such as `|---|---|' as one adaptive fill prefix.  It then puts a `min-width'
display specification and a `wrap-prefix' property across the whole line.
Valign's per-cell replacement overlays split that range, causing the minimum
width to be applied again at every cell boundary."
  (let ((line-beginning (line-beginning-position))
        (line-end (line-end-position)))
    (with-silent-modifications
      ;; Remove only the conflicting display specification; preserve any
      ;; unrelated display specifications another mode put on the line.
      (remove-display-text-property line-beginning line-end 'min-width)
      (remove-text-properties line-beginning line-end '(wrap-prefix nil)))))

(defun sov-valign--clear-separator-wrap-properties-in-region (begin end)
  "Remove conflicting wrap properties from separator rows in BEGIN to END."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (max (point-min) begin))
      (beginning-of-line)
      (let ((limit (min (point-max) end)))
        (while (< (point) limit)
          (when (and (bound-and-true-p valign-mode)
                     (fboundp 'valign--separator-line-p)
                     (valign--separator-line-p))
            (sov-valign--clear-separator-wrap-properties))
          (forward-line 1))))))

(defun sov-valign--around-visual-wrap-prefix-function
    (original-function begin end)
  "Run ORIGINAL-FUNCTION, then clean separator rows between BEGIN and END.

The cleanup must happen after visual-wrap's JIT function because fontification
can run asynchronously after valign has already rendered the table."
  (let ((result (funcall original-function begin end)))
    (sov-valign--clear-separator-wrap-properties-in-region begin end)
    result))

(defun sov-valign--separator-row-add-overlay (beg end pixel-width)
  "Render a separator cell from BEG to END with PIXEL-WIDTH.

Unlike valign's upstream separator renderer, use a local `:width' display
specification instead of an absolute `:align-to' position.  Preserve Markdown
alignment colons and Org's plus-sign intersections."
  ;; Render the right boundary before narrowing BEG and END around Markdown
  ;; alignment colons.  This mirrors valign's upstream boundary handling.
  (if valign-fancy-bar
      (valign--render-bar end)
    (when (eq (char-after end) ?+)
      (valign--put-overlay end (1+ end) 'display "|")))

  ;; A visible Markdown alignment colon consumes part of the separator cell's
  ;; total width, so subtract its actual glyph width from the stretch space.
  (when (eq (char-after beg) ?:)
    (setq pixel-width
          (- pixel-width (valign--pixel-width-from-to beg (1+ beg)))
          beg (1+ beg)))
  (when (eq (char-before end) ?:)
    (setq pixel-width
          (- pixel-width (valign--pixel-width-from-to (1- end) end))
          end (1- end)))

  (valign--put-overlay
   beg end
   'display `(space :width (,(max 0 pixel-width)))
   'face '(:strike-through t)))

(defun sov-valign--align-separator-row (column-width-list)
  "Align a separator row using COLUMN-WIDTH-LIST.

This is a width-local replacement for `valign--align-separator-row'.  Normal
table cells continue to use valign's original alignment implementation."
  (sov-valign--clear-separator-wrap-properties)
  (let ((space-width (valign--glyph-width-of " " (point)))
        (column-start (point))
        (column-index 0))
    ;; Point is immediately after the table's first left boundary.
    (valign--maybe-render-bar (1- (point)))
    (while (re-search-forward "[|\\+]" (line-end-position) t)
      (let ((column-width (nth column-index column-width-list)))
        ;; Match the upstream failure mode for malformed/ragged tables instead
        ;; of silently inventing a width for a missing column.
        (unless column-width
          (signal 'valign-parse-error
                  '("The separator row has more columns than the table")))
        (sov-valign--separator-row-add-overlay
         column-start (1- (point)) (+ column-width space-width))
        (setq column-start (point))
        (cl-incf column-index)))))

(defun sov-valign-install-separator-advice ()
  "Install the local-width separator renderer for Emacs 31 PGTK.

Removing the named advice first makes repeated configuration loads
idempotent."
  (when (and (>= emacs-major-version 31)
             (featurep 'pgtk)
             (fboundp 'valign--align-separator-row))
    (advice-remove 'valign--align-separator-row
                   #'sov-valign--align-separator-row)
    (advice-add 'valign--align-separator-row
                :override #'sov-valign--align-separator-row)))

(defun sov-valign-install-visual-wrap-advice ()
  "Prevent delayed visual-wrap fontification from expanding separator rows."
  (when (and (>= emacs-major-version 31)
             (featurep 'pgtk)
             (fboundp 'visual-wrap-prefix-function))
    (advice-remove 'visual-wrap-prefix-function
                   #'sov-valign--around-visual-wrap-prefix-function)
    (advice-add 'visual-wrap-prefix-function
                :around #'sov-valign--around-visual-wrap-prefix-function)))

(defun sov-valign-reset-buffer ()
  "Synchronously rebuild valign display properties in the current buffer."
  (interactive)
  (valign-reset-buffer)
  (font-lock-ensure))

(with-eval-after-load 'valign
  (sov-valign-install-separator-advice))

(with-eval-after-load 'visual-wrap
  (sov-valign-install-visual-wrap-advice))

(provide 'sov-valign)
;;; sov-valign.el ends here
