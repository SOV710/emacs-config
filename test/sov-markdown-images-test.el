;;; sov-markdown-images-test.el --- Clipboard image integration tests -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'evil)
(require 'markdown-mode)
(require 'projectile)

;; Exercise the module without starting Elpaca or unrelated package hooks.
(defmacro use-package (&rest _args) nil)

(require 'sov-lang-markdown)

(defconst sov-markdown-images-test--png
  (base64-decode-string
   "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII="))

(defmacro sov-markdown-images-test--with-note (&rest body)
  (declare (indent 0) (debug t))
  `(let ((directory (make-temp-file "sov-markdown-images-" t))
         (sov-markdown-image-directory "assets/")
         (sov-markdown-image-scale 1.0)
         ;; Detect real .projectile markers inside each fixture, independently
         ;; of Git metadata or other project markers in the test machine's /tmp.
         (projectile-project-root-functions '(projectile-root-marked))
         (projectile-project-root-cache (make-hash-table :test 'equal)))
     (unwind-protect
         (with-temp-buffer
           (setq buffer-file-name (expand-file-name "note.md" directory)
                 default-directory directory)
           (let ((markdown-mode-hook nil))
             (markdown-mode))
           ,@body)
       (delete-directory directory t))))

(ert-deftest sov-markdown-images-paste-preserves-bytes-and-renders-relative-link ()
  (sov-markdown-images-test--with-note
    (let ((prompts 0)
          rendered-file rendered-scale)
      (cl-letf (((symbol-function 'read-string)
                 (lambda (&rest _args) (cl-incf prompts) "图片 (v1.2)"))
                ((symbol-function 'gui-get-selection)
                 (lambda (_selection target &rest _args)
                   (if (eq target 'TARGETS)
                       [image/png]
                     sov-markdown-images-test--png)))
                ((symbol-function 'image-type-available-p) (lambda (_) t))
                ((symbol-function 'display-images-p) (lambda (&rest _) t))
                ((symbol-function 'clear-image-cache) #'ignore)
                ((symbol-function 'create-image)
                 (lambda (file &rest _args)
                   (setq rendered-file file
                         rendered-scale image-scaling-factor)
                   `(image :type png :file ,file))))
        ;; The note location, rather than a changed default-directory, wins.
        (let ((default-directory temporary-file-directory))
          (call-interactively #'sov-markdown-paste-image)))
      (should (= prompts 1))
      (should (equal (buffer-string) "![](assets/图片%20%28v1.2%29.png)"))
      (should (equal rendered-file
                     (expand-file-name "assets/图片 (v1.2).png" directory)))
      (should (equal rendered-scale 1.0))
      (should (= (length markdown-inline-image-overlays) 1))
      (should (overlay-get (car markdown-inline-image-overlays) 'evaporate))
      (with-temp-buffer
        (set-buffer-multibyte nil)
        (insert-file-contents-literally rendered-file)
        (should (equal (buffer-string) sov-markdown-images-test--png))))))

(ert-deftest sov-markdown-images-save-to-projectile-root-assets ()
  (sov-markdown-images-test--with-note
    (with-temp-file (expand-file-name ".projectile" directory))
    (let* ((note-directory (expand-file-name "docs/notes/" directory))
           (image (expand-file-name "assets/diagram.png" directory)))
      (make-directory note-directory t)
      (setq buffer-file-name (expand-file-name "note.md" note-directory))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "diagram")))
        ;; A changed working directory must not select a different project.
        (let ((default-directory temporary-file-directory))
          (sov-markdown--yank-image 'image/png sov-markdown-images-test--png)))
      (should (file-exists-p image))
      (should-not (file-exists-p (expand-file-name "assets/" note-directory)))
      (should (equal (buffer-string) "![](../../assets/diagram.png)"))
      (with-temp-buffer
        (set-buffer-multibyte nil)
        (insert-file-contents-literally image)
        (should (equal (buffer-string) sov-markdown-images-test--png))))))

(ert-deftest sov-markdown-images-outside-project-use-note-directory-assets ()
  (sov-markdown-images-test--with-note
    (let ((note-directory (expand-file-name "notes/" directory)))
      (make-directory note-directory t)
      (should-not (projectile-project-root note-directory))
      (setq buffer-file-name (expand-file-name "note.md" note-directory))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "diagram")))
        (sov-markdown--yank-image 'image/png sov-markdown-images-test--png))
      (should (file-exists-p
               (expand-file-name "assets/diagram.png" note-directory)))
      (should-not (file-exists-p (expand-file-name "assets/" directory)))
      (should (equal (buffer-string) "![](assets/diagram.png)")))))

(ert-deftest sov-markdown-images-empty-name-uses-time-format ()
  (sov-markdown-images-test--with-note
    (let ((sov-markdown-image-name-format "test-%Y%m%d-%H%M%S"))
      (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "")))
        (sov-markdown--yank-image 'image/png sov-markdown-images-test--png))
      (should (string-match-p
               "!\\[\\](assets/test-[0-9]\\{8\\}-[0-9]\\{6\\}\\.png)"
               (buffer-string))))))

(ert-deftest sov-markdown-images-format-comes-from-binary-data ()
  (sov-markdown-images-test--with-note
    (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "diagram.jpeg")))
      ;; Even a conflicting MIME label must not change the detected format.
      (sov-markdown--yank-image 'image/jpeg sov-markdown-images-test--png))
    (should (equal (buffer-string) "![](assets/diagram.jpeg.png)"))))

(ert-deftest sov-markdown-images-refuse-overwrite-and-directory-names ()
  (sov-markdown-images-test--with-note
    (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "diagram")))
      (sov-markdown--yank-image 'image/png sov-markdown-images-test--png)
      (let ((text (buffer-string)))
        (should-error
         (sov-markdown--yank-image 'image/png sov-markdown-images-test--png)
         :type 'file-already-exists)
        (should (equal text (buffer-string)))))
    (cl-letf (((symbol-function 'read-string) (lambda (&rest _) "../escape")))
      (should-error
       (sov-markdown--yank-image 'image/png sov-markdown-images-test--png)
       :type 'user-error))))

(ert-deftest sov-markdown-images-evil-binding-works-in-both-modes-and-states ()
  (let ((evil-mode-hook nil))
    (evil-mode 1))
  (dolist (mode '(markdown-mode gfm-mode markdown-ts-mode))
    (when (or (not (eq mode 'markdown-ts-mode))
              (and (fboundp mode) (treesit-ready-p 'markdown t)
                   (treesit-ready-p 'markdown-inline t)))
      (with-temp-buffer
        (let ((markdown-mode-hook nil)
              (gfm-mode-hook nil)
              (markdown-ts-mode-hook nil))
          (funcall mode))
        (evil-local-mode 1)
        (sov-markdown-image-setup)
        (dolist (state '(normal insert))
          (evil-change-state state)
          (should (eq (key-binding (kbd "C-c y"))
                      #'sov-markdown-paste-image))
          (should-not (eq (key-binding (kbd "C-S-v"))
                          #'sov-markdown-paste-image)))))))

(ert-deftest sov-markdown-images-unsaved-or-read-only-note-does-not-read-clipboard ()
  (with-temp-buffer
    (should-error (sov-markdown-paste-image) :type 'user-error)
    (setq buffer-file-name "/tmp/read-only-note.md"
          buffer-read-only t)
    (should-error (sov-markdown-paste-image) :type 'buffer-read-only)))

(provide 'sov-markdown-images-test)
;;; sov-markdown-images-test.el ends here
