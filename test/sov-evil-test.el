;;; sov-evil-test.el --- Tests for Evil word-boundary integration -*- lexical-binding: t; -*-

(require 'ert)
(require 'evil)

;; EMT installs a handler in `find-word-boundary-function-table'.  Keep this
;; contract under test so an Evil upgrade cannot silently bypass EMT's layer.
(defun sov-evil-test--han-boundary (pos limit)
  "Return two-character Han word boundaries between POS and LIMIT."
  (if (< pos limit)
      (min limit (+ pos 2))
    (max limit (- pos 2))))

(defmacro sov-evil-test--with-han-word-boundaries (&rest body)
  "Evaluate BODY with deterministic Han word boundaries."
  (declare (indent 0) (debug t))
  `(let ((table (make-char-table nil)))
     (set-char-table-range table (cons #x4E00 #x9FFF)
                           #'sov-evil-test--han-boundary)
     (let ((find-word-boundary-function-table table))
       ,@body)))

(ert-deftest sov-evil-test-word-motion-uses-native-han-boundaries ()
  (with-temp-buffer
    (insert "中华人民共和国")
    (goto-char (point-min))
    (sov-evil-test--with-han-word-boundaries
      (evil-forward-word-begin 1)
      (should (= (point) 3)))))

(ert-deftest sov-evil-test-inner-word-uses-native-han-boundaries ()
  (with-temp-buffer
    (insert "中华人民共和国")
    (goto-char (point-min))
    (sov-evil-test--with-han-word-boundaries
      (should (equal (evil-inner-word 1) '(1 3 inclusive))))))
