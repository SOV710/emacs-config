;;; sov-valign-test.el --- Tests for valign compatibility -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'visual-wrap)
(require 'valign)
(require 'sov-valign)

(defun sov-valign-test--rule-overlays ()
  "Return separator-rule overlays in buffer order."
  (sort
   (seq-filter
    (lambda (overlay)
      (equal (overlay-get overlay 'face) '(:strike-through t)))
    (overlays-in (point-min) (point-max)))
   (lambda (left right)
     (< (overlay-start left) (overlay-start right)))))

(defmacro sov-valign-test--with-pixel-stubs (&rest body)
  "Evaluate BODY with deterministic glyph and range pixel widths."
  (declare (indent 0) (debug t))
  `(cl-letf (((symbol-function 'valign--glyph-width-of)
              (lambda (_string _point) 4))
             ((symbol-function 'valign--pixel-width-from-to)
              (lambda (from to) (* 2 (- to from)))))
     ,@body))

(ert-deftest sov-valign-installs-one-reversible-separator-advice ()
  "Install one named override that can be removed and restored."
  (skip-unless (and (>= emacs-major-version 31) (featurep 'pgtk)))
  (sov-valign-install-separator-advice)
  (should (advice-member-p #'sov-valign--align-separator-row
                           'valign--align-separator-row))
  ;; Reinstallation must not stack another copy of the same advice.
  (sov-valign-install-separator-advice)
  (let ((count 0))
    (advice-mapc
     (lambda (advice _properties)
       (when (eq advice #'sov-valign--align-separator-row)
         (cl-incf count)))
     'valign--align-separator-row)
    (should (= count 1)))
  (unwind-protect
      (progn
        (advice-remove 'valign--align-separator-row
                       #'sov-valign--align-separator-row)
        (should-not (advice-member-p #'sov-valign--align-separator-row
                                     'valign--align-separator-row)))
    (sov-valign-install-separator-advice)))

(ert-deftest sov-valign-installs-one-reversible-visual-wrap-advice ()
  "Install one named visual-wrap advice that can be removed and restored."
  (skip-unless (and (>= emacs-major-version 31) (featurep 'pgtk)))
  (sov-valign-install-visual-wrap-advice)
  (should
   (advice-member-p #'sov-valign--around-visual-wrap-prefix-function
                    'visual-wrap-prefix-function))
  (sov-valign-install-visual-wrap-advice)
  (let ((count 0))
    (advice-mapc
     (lambda (advice _properties)
       (when (eq advice #'sov-valign--around-visual-wrap-prefix-function)
         (cl-incf count)))
     'visual-wrap-prefix-function)
    (should (= count 1)))
  (unwind-protect
      (progn
        (advice-remove 'visual-wrap-prefix-function
                       #'sov-valign--around-visual-wrap-prefix-function)
        (should-not
         (advice-member-p #'sov-valign--around-visual-wrap-prefix-function
                          'visual-wrap-prefix-function)))
    (sov-valign-install-visual-wrap-advice)))

(ert-deftest sov-valign-separator-uses-local-pixel-widths ()
  "Render each Markdown separator cell with `:width', not `:align-to'."
  (with-temp-buffer
    (insert "|-----|-----|-----|")
    (goto-char (1+ (point-min)))
    (let ((valign-fancy-bar nil))
      (sov-valign-test--with-pixel-stubs
        (sov-valign--align-separator-row '(10 20 30))))
    (let* ((overlays (sov-valign-test--rule-overlays))
           (displays (mapcar (lambda (overlay)
                               (overlay-get overlay 'display))
                             overlays)))
      (should (equal displays
                     '((space :width (14))
                       (space :width (24))
                       (space :width (34)))))
      (dolist (display displays)
        (should-not (memq :align-to display))))))

(ert-deftest sov-valign-separator-removes-visual-wrap-min-width ()
  "Prevent a whole-line wrap prefix from expanding every table boundary."
  (with-temp-buffer
    (insert "|---|---|---|")
    ;; Simulate stale properties left by an earlier visual-wrap pass.
    (add-display-text-property
     (point-min) (point-max) 'min-width '((13 . width)))
    (put-text-property
     (point-min) (point-max) 'wrap-prefix
     '(space :align-to (13 . width)))
    (goto-char (1+ (point-min)))
    (let ((valign-fancy-bar nil))
      (sov-valign-test--with-pixel-stubs
        (sov-valign--align-separator-row '(10 20 30))))
    (let ((position (point-min)))
      (while (< position (point-max))
        (should-not (get-text-property position 'display))
        (should-not (get-text-property position 'wrap-prefix))
        (setq position (1+ position))))
    (should
     (equal (mapcar (lambda (overlay)
                      (overlay-get overlay 'display))
                    (sov-valign-test--rule-overlays))
            '((space :width (14))
              (space :width (24))
              (space :width (34)))))))

(ert-deftest sov-valign-visual-wrap-does-not-restore-separator-min-width ()
  "Clean separator properties after a delayed visual-wrap JIT pass."
  (skip-unless (and (>= emacs-major-version 31) (featurep 'pgtk)))
  (with-temp-buffer
    (insert "|---|---|---|")
    (let ((valign-mode t))
      (visual-wrap-prefix-function (point-min) (point-max)))
    (let ((position (point-min)))
      (while (< position (point-max))
        (should-not (get-text-property position 'display))
        (should-not (get-text-property position 'wrap-prefix))
        (setq position (1+ position))))))

(ert-deftest sov-valign-visual-wrap-keeps-normal-prose-prefixes ()
  "Leave visual-wrap behavior unchanged outside table separator rows."
  (skip-unless (and (>= emacs-major-version 31) (featurep 'pgtk)))
  (with-temp-buffer
    (insert "- wrapped prose")
    (visual-wrap-prefix-function (point-min) (point-max))
    (should (get-text-property (point-min) 'display))
    (should (get-text-property (point-min) 'wrap-prefix))))

(ert-deftest sov-valign-visual-wrap-leaves-other-buffers-unchanged ()
  "Do not special-case separator-like text when valign mode is disabled."
  (skip-unless (and (>= emacs-major-version 31) (featurep 'pgtk)))
  (with-temp-buffer
    (insert "|---|---|---|")
    (let ((valign-mode nil))
      (visual-wrap-prefix-function (point-min) (point-max)))
    (should (get-text-property (point-min) 'display))
    (should (get-text-property (point-min) 'wrap-prefix))))

(ert-deftest sov-valign-provides-an-interactive-reset-command ()
  "Expose the non-interactive upstream reset through an M-x command."
  (should (commandp #'sov-valign-reset-buffer)))

(ert-deftest sov-valign-separator-preserves-markdown-alignment-colons ()
  "Keep Markdown alignment markers and deduct their rendered pixel widths."
  (with-temp-buffer
    (insert "|:---|---:|:---:|")
    (goto-char (1+ (point-min)))
    (let ((source (buffer-string))
          (valign-fancy-bar nil))
      (sov-valign-test--with-pixel-stubs
        (sov-valign--align-separator-row '(10 20 30)))
      (should (equal (buffer-string) source)))
    (should
     (equal (mapcar (lambda (overlay)
                      (overlay-get overlay 'display))
                    (sov-valign-test--rule-overlays))
            '((space :width (12))
              (space :width (22))
              (space :width (30)))))))

(ert-deftest sov-valign-separator-preserves-org-intersections ()
  "Display Org separator plus signs as valign boundary bars."
  (with-temp-buffer
    (insert "|-----+-----|")
    (goto-char (1+ (point-min)))
    (let ((valign-fancy-bar nil))
      (sov-valign-test--with-pixel-stubs
        (sov-valign--align-separator-row '(10 20))))
    (should
     (equal (mapcar (lambda (overlay)
                      (overlay-get overlay 'display))
                    (sov-valign-test--rule-overlays))
            '((space :width (14))
              (space :width (24)))))
    (let ((intersection
           (seq-find
            (lambda (overlay)
              (equal (overlay-get overlay 'display) "|"))
            (overlays-in (point-min) (point-max)))))
      (should intersection)
      (should (eq (char-after (overlay-start intersection)) ?+)))))

(ert-deftest sov-valign-leaves-normal-cell-renderer-unadvised ()
  "Restrict the compatibility override to separator rows."
  (should-not (advice-member-p #'sov-valign--align-separator-row
                               'valign--cell)))

(provide 'sov-valign-test)
;;; sov-valign-test.el ends here
