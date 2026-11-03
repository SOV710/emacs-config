;;; sov-redisplay.el --- Avoid unnecessary full redisplays -*- lexical-binding: t; -*-

;; PGTK updates the same named faces for every input-method preedit event.
;; Reapplying an unchanged spec invalidates the frame's realized faces and
;; redraws unrelated images.  Keep the upstream handler and its attributes.

(defvar sov-redisplay--pgtk-preedit-active nil)

(defun sov-redisplay--pgtk-preedit (function &rest arguments)
  "Call FUNCTION with ARGUMENTS, deduplicating PGTK preedit face specs."
  (let ((sov-redisplay--pgtk-preedit-active t))
    (apply function arguments)))

(defun sov-redisplay--preedit-face-declaration (function face spec doc &rest args)
  "Reuse an unchanged private preedit FACE declaration.
PGTK's nil default spec makes `custom-declare-face' repeat the declaration,
including appending to `current-load-list', on every preedit event."
  (if (and sov-redisplay--pgtk-preedit-active
           (symbolp face)
           (string-prefix-p "pgtk-im-" (symbol-name face))
           (facep face)
           (null spec)
           (null (get face 'face-defface-spec))
           (equal doc (face-documentation face))
           (null args))
      face
    (apply function face spec doc args)))

(defun sov-redisplay--preedit-face-spec (function face spec &optional spec-type)
  "Call FUNCTION unless FACE already has the requested preedit SPEC.
Only intercept the PGTK handler's private specs; all other face updates,
including theme changes and new preedit attributes, are preserved."
  (unless (and sov-redisplay--pgtk-preedit-active
               (symbolp face)
               (string-prefix-p "pgtk-im-" (symbol-name face))
               (facep face)
               ;; PGTK also evaluates (defface ... nil) on every event.
               ;; Its nil default spec would otherwise reset the face before
               ;; the handler reapplies its unchanged override spec.
               (memq spec-type '(nil face-override-spec face-defface-spec))
               (equal spec (get face (or spec-type 'face-override-spec))))
    (funcall function face spec spec-type)))

(with-eval-after-load 'pgtk-win
  (advice-add 'pgtk-preedit-text :around #'sov-redisplay--pgtk-preedit)
  (advice-add 'custom-declare-face :around
              #'sov-redisplay--preedit-face-declaration)
  (advice-add 'face-spec-set :around #'sov-redisplay--preedit-face-spec))

(provide 'sov-redisplay)
;;; sov-redisplay.el ends here
