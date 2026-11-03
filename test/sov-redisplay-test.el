;;; sov-redisplay-test.el --- Preedit redisplay regression tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'sov-redisplay)

(ert-deftest sov-redisplay-preedit-reuses-spec-but-applies-new-attributes ()
  (let ((face (make-symbol "pgtk-im-test"))
        (updates 0))
    (make-empty-face face)
    (let ((setter (lambda (face spec type)
                    (cl-incf updates)
                    (face-spec-set face spec type))))
      (sov-redisplay--pgtk-preedit
       (lambda ()
         (dotimes (_ 20)
           (sov-redisplay--preedit-face-spec setter face '((t :underline t))))
         (should (= updates 1))
         (should (eq (face-attribute face :underline) t))
         (sov-redisplay--preedit-face-spec
          setter face '((t :underline t :foreground "red")))
         (should (= updates 2))
         (should (equal (face-attribute face :foreground) "red"))
         ;; Ending/changing a segment must also clear the old attributes.
         (sov-redisplay--preedit-face-spec setter face '((t)))
         (should (= updates 3))
         (should (eq (face-attribute face :underline) 'unspecified)))))))

(ert-deftest sov-redisplay-does-not-deduplicate-theme-or-other-face-updates ()
  (dolist (context '(outside-preedit other-face other-spec-type))
    (let ((face (make-symbol (if (eq context 'other-face)
                                "other-face" "pgtk-im-test")))
          (updates 0)
          (sov-redisplay--pgtk-preedit-active
           (not (eq context 'outside-preedit))))
      (make-empty-face face)
      (let ((setter (lambda (face spec type)
                      (cl-incf updates)
                      (face-spec-set face spec type))))
        (dotimes (_ 2)
          (sov-redisplay--preedit-face-spec
           setter face '((t :underline t))
           (when (eq context 'other-spec-type) 'customized-face)))
        (should (= updates 2))))))

(ert-deftest sov-redisplay-preedit-does-not-reset-an-existing-empty-default-spec ()
  (let ((face (make-symbol "pgtk-im-test"))
        (sov-redisplay--pgtk-preedit-active t)
        (updates 0))
    (make-empty-face face)
    (face-spec-set face '((t :underline t)))
    (sov-redisplay--preedit-face-spec
     (lambda (&rest _) (cl-incf updates)) face nil 'face-defface-spec)
    (should (= updates 0))
    (should (eq (face-attribute face :underline) t))))

(ert-deftest sov-redisplay-preedit-scope-unwinds-after-errors ()
  (should-error (sov-redisplay--pgtk-preedit (lambda () (error "preedit error"))))
  (should-not sov-redisplay--pgtk-preedit-active))

(ert-deftest sov-redisplay-preedit-declares-faces-once-and-preserves-changes ()
  (let* ((face (make-symbol "pgtk-im-test"))
         (sov-redisplay--pgtk-preedit-active t)
         (current-load-list nil)
         (custom-define-hook nil)
         (declarations 0)
         (declare (lambda (&rest args)
                    (cl-incf declarations)
                    (apply #'custom-declare-face args))))
    (should (eq (sov-redisplay--preedit-face-declaration
                 declare face nil "Preedit face") face))
    (should (= declarations 1))
    (should (equal (face-documentation face) "Preedit face"))
    (dotimes (_ 20)
      (should (eq (sov-redisplay--preedit-face-declaration
                   declare face nil "Preedit face") face)))
    (should (= declarations 1))
    (should (= (length current-load-list) 1))
    (sov-redisplay--preedit-face-declaration
     declare face nil "Updated documentation")
    (should (= declarations 2))
    (should (equal (face-documentation face) "Updated documentation"))
    (sov-redisplay--preedit-face-declaration
     declare face nil "Updated documentation" :group 'faces)
    (should (= declarations 3))
    (sov-redisplay--preedit-face-declaration
     declare face '((t :underline t)) "Updated documentation")
    (should (= declarations 4))
    (should (eq (face-attribute face :underline) t))))

(ert-deftest sov-redisplay-face-declaration-deduplication-is-scoped ()
  (dolist (context '(outside-preedit other-face))
    (let ((face (make-symbol (if (eq context 'other-face)
                                "other-face" "pgtk-im-test")))
          (sov-redisplay--pgtk-preedit-active
           (not (eq context 'outside-preedit)))
          (current-load-list nil)
          (custom-define-hook nil))
      (custom-declare-face face nil "Test face")
      (let ((before (length current-load-list)))
        (sov-redisplay--preedit-face-declaration
         #'custom-declare-face face nil "Test face")
        (should (= (length current-load-list) (1+ before)))))))

(ert-deftest sov-redisplay-real-pgtk-handler-does-not-accumulate-face-records ()
  (skip-unless (featurep 'pgtk))
  (require 'pgtk-win)
  (with-temp-buffer
    (let ((pgtk-preedit-overlay nil)
          (current-load-list nil)
          (event '(preedit-text (("ni" (ul . t)) ("hao" (fg . "red"))))))
      (unwind-protect
          (progn
            (pgtk-preedit-text event)
            (let ((before current-load-list))
              (dotimes (_ 10000)
                (pgtk-preedit-text event))
              (garbage-collect)
              (should (eq current-load-list before))))
        (when pgtk-preedit-overlay (delete-overlay pgtk-preedit-overlay))))))

(ert-deftest sov-redisplay-real-pgtk-handler-updates-text-without-resetting-faces ()
  (skip-unless (featurep 'pgtk))
  (require 'pgtk-win)
  (with-temp-buffer
    (let* ((pgtk-preedit-overlay nil)
           (recalculations 0)
           (counter (lambda (&rest _) (cl-incf recalculations))))
      (advice-add 'face-spec-recalc :before counter)
      (unwind-protect
          (progn
            (pgtk-preedit-text '(preedit-text (("n" (ul . t)))))
            (setq recalculations 0)
            (dotimes (_ 20)
              (pgtk-preedit-text '(preedit-text (("ni" (ul . t))))))
            (should (= recalculations 0))
            (should (equal (substring-no-properties
                            (overlay-get pgtk-preedit-overlay 'before-string)) "ni"))
            ;; Different attributes and multiple segments must still work.
            (pgtk-preedit-text
             '(preedit-text (("你" (fg . "red") (bg . "blue") (ul . t))
                             ("hao" (ul . t)))))
            (should (> recalculations 0))
            (let* ((text (overlay-get pgtk-preedit-overlay 'before-string))
                   (face (get-text-property 0 'face text)))
              (should (equal (substring-no-properties text) "你hao"))
              (should (equal (face-attribute face :foreground) "red"))
              (should (equal (face-attribute face :background) "blue"))
              (should (eq (face-attribute face :underline) t)))
            (setq recalculations 0)
            (pgtk-preedit-text
             '(preedit-text (("拟" (fg . "red") (bg . "blue") (ul . t))
                             ("hao" (ul . t)))))
            (should (= recalculations 0))
            (pgtk-preedit-text '(preedit-text nil))
            (should (equal (overlay-get pgtk-preedit-overlay 'before-string) "")))
        (advice-remove 'face-spec-recalc counter)
        (when pgtk-preedit-overlay (delete-overlay pgtk-preedit-overlay))))))

(provide 'sov-redisplay-test)
;;; sov-redisplay-test.el ends here
