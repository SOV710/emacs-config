;;; sov-lang-markdown-test.el --- Tests for wrapped Markdown tables -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'markdown-table-wrap)

;; The language module's package declarations are irrelevant in isolated tests.
(unless (fboundp 'use-package)
  (defmacro use-package (&rest _args) nil))

(require 'sov-lang-markdown)

(defconst sov-lang-markdown-test--table
  (concat "| Feature | Notes |\n"
          "| --- | --- |\n"
          "| **Auth** | [OAuth docs](https://example.com) and `refresh token` |\n"
          "| 国际化 🚀 | 支持粗体、链接和 Emoji 内容 |"))

(defmacro sov-lang-markdown-test--with-buffer (text &rest body)
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (insert ,text)
     (goto-char (point-min))
     ,@body))

(defun sov-lang-markdown-test--wrap-first-table (width)
  (goto-char (point-min))
  (search-forward "Feature")
  (sov-markdown-table-wrap-at-point width))

(ert-deftest sov-markdown-table-projection-writer-is-installed-by-mode-hooks ()
  (should (memq #'sov-markdown-table-projection-setup markdown-mode-hook))
  (should (memq #'sov-markdown-table-projection-setup markdown-ts-mode-hook))
  (with-temp-buffer
    (sov-markdown-table-projection-setup)
    (should (local-variable-p 'write-contents-functions))
    (should (memq #'sov-markdown-table-projection-write-contents
                  write-contents-functions))))

(ert-deftest sov-markdown-table-projection-writer-defers-without-markers ()
  (sov-lang-markdown-test--with-buffer sov-lang-markdown-test--table
    (should-not (sov-markdown-table-projection-write-contents))))

(ert-deftest sov-markdown-table-wrap-round-trips-rich-content ()
  (sov-lang-markdown-test--with-buffer sov-lang-markdown-test--table
    (sov-lang-markdown-test--wrap-first-table 34)
    (should (string-match-p
             "<!-- sov-markdown-table-wrap width:34 -->"
             (buffer-string)))
    (should (string-match-p "国际化" (buffer-string)))
    (should (string-match-p "🚀" (buffer-string)))
    (should (string-match-p "`refresh" (buffer-string)))
    (sov-markdown-table-unwrap-at-point)
    (should-not (string-match-p "sov-markdown-table-wrap" (buffer-string)))
    (should (equal (buffer-string)
                   (markdown-table-wrap-unwrap
                    (markdown-table-wrap sov-lang-markdown-test--table 34))))))

(ert-deftest sov-markdown-table-wrap-rewraps-an-existing-marked-table ()
  (sov-lang-markdown-test--with-buffer sov-lang-markdown-test--table
    (sov-lang-markdown-test--wrap-first-table 34)
    (goto-char (point-min))
    (search-forward "Feature")
    (sov-markdown-table-wrap-at-point 30)
    (should (= 1 (how-many "<!-- sov-markdown-table-wrap width:30 -->")))
    (should (= 1 (how-many "<!-- /sov-markdown-table-wrap -->")))))

(ert-deftest sov-markdown-table-wrap-refuses-fenced-code ()
  (sov-lang-markdown-test--with-buffer
      (concat "```markdown\n" sov-lang-markdown-test--table "\n```\n")
    (search-forward "Feature")
    (should-error (sov-markdown-table-wrap-at-point 34)
                  :type 'user-error)
    (should-not (string-match-p "sov-markdown-table-wrap"
                                (buffer-string)))))

(ert-deftest sov-markdown-table-unwrap-buffer-leaves-unmarked-tables-alone ()
  (sov-lang-markdown-test--with-buffer
      (concat sov-lang-markdown-test--table "\n\n" sov-lang-markdown-test--table)
    (sov-lang-markdown-test--wrap-first-table 34)
    (let ((second-table (buffer-substring-no-properties
                         (save-excursion
                           (goto-char (point-min))
                           (search-forward "<!-- /sov-markdown-table-wrap -->")
                           (search-forward "| Feature")
                           (line-beginning-position))
                         (point-max))))
      (sov-markdown-table-unwrap-buffer)
      (should-not (string-match-p "sov-markdown-table-wrap" (buffer-string)))
      (should (string-suffix-p second-table (buffer-string))))))

(ert-deftest sov-markdown-table-project-content-handles-multiple-ranges ()
  (sov-lang-markdown-test--with-buffer
      (concat sov-lang-markdown-test--table "\n\nPlain text\n\n"
              sov-lang-markdown-test--table "\n")
    (sov-lang-markdown-test--wrap-first-table 34)
    (goto-char (point-max))
    (search-backward "Feature")
    (sov-markdown-table-wrap-at-point 38)
    (let ((projected (sov-markdown-table--project-content)))
      (should-not (string-match-p "sov-markdown-table-wrap" projected))
      (should (string-match-p "Plain text" projected))
      (should (= 2 (with-temp-buffer
                     (insert projected)
                     (goto-char (point-min))
                     (how-many "| Feature | Notes |")))))))

(ert-deftest sov-markdown-table-project-content-rejects-malformed-markers ()
  (dolist (text
           '("<!-- sov-markdown-table-wrap width:40 -->\n| A |\n|---|\n| x |\n"
             "<!-- sov-markdown-table-wrap width:40\n| A |\n|---|\n| x |\n"
             "<!-- /sov-markdown-table-wrap -->\n"
             "<!-- sov-markdown-table-wrap width:40 -->\n<!-- sov-markdown-table-wrap width:20 -->\n<!-- /sov-markdown-table-wrap -->\n<!-- /sov-markdown-table-wrap -->\n"))
    (sov-lang-markdown-test--with-buffer text
      (should-error (sov-markdown-table--project-content)
                    :type 'user-error))))

(ert-deftest sov-markdown-table-projection-save-keeps-buffer-wrapped ()
  (let ((file (make-temp-file "sov-markdown-save-" nil ".md"
                              (concat sov-lang-markdown-test--table "\n"))))
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (let ((original-path buffer-file-name))
            (sov-markdown-table-projection-setup)
            (sov-lang-markdown-test--wrap-first-table 34)
            (let ((wrapped (buffer-string)))
              (save-buffer)
              (should (equal buffer-file-name original-path))
              (should (equal (buffer-string) wrapped))
              (should-not (buffer-modified-p))
              (with-temp-buffer
                (insert-file-contents file)
                (should-not (string-match-p "sov-markdown-table-wrap"
                                            (buffer-string)))
                (should (string-match-p "国际化 🚀" (buffer-string)))))
            (kill-buffer (current-buffer))
            (with-current-buffer (find-file-noselect original-path)
              (should-not (string-match-p "sov-markdown-table-wrap"
                                          (buffer-string)))
              (kill-buffer (current-buffer)))))
      (delete-file file))))

(ert-deftest sov-markdown-table-projection-save-preserves-modes-and-backup ()
  (let* ((file (make-temp-file "sov-markdown-metadata-" nil ".md"
                               (concat sov-lang-markdown-test--table "\n")))
         (backup (concat file "~")))
    (set-file-modes file #o640)
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (let ((make-backup-files t)
                (backup-inhibited nil)
                (backup-directory-alist nil)
                (version-control 'never))
            (sov-markdown-table-projection-setup)
            (sov-lang-markdown-test--wrap-first-table 34)
            (save-buffer)
            (should (= (logand (file-modes file) #o777) #o640))
            (should (file-exists-p backup)))
          (kill-buffer (current-buffer)))
      (when (file-exists-p backup)
        (delete-file backup))
      (delete-file file))))

(ert-deftest sov-markdown-table-projection-save-failure-is-atomic ()
  (let* ((file (make-temp-file "sov-markdown-fail-" nil ".md"
                               (concat sov-lang-markdown-test--table "\n")))
         (disk-before (with-temp-buffer
                        (insert-file-contents-literally file)
                        (buffer-string))))
    (unwind-protect
        (with-current-buffer (find-file-noselect file)
          (sov-markdown-table-projection-setup)
          (sov-lang-markdown-test--wrap-first-table 34)
          (goto-char (point-max))
          (search-backward "<!-- /sov-markdown-table-wrap -->")
          (delete-region (line-beginning-position) (line-end-position))
          (let ((buffer-before (buffer-string)))
            (should-error (save-buffer) :type 'user-error)
            (should (equal (buffer-string) buffer-before))
            (should (buffer-modified-p))
            (should (equal disk-before
                           (with-temp-buffer
                             (insert-file-contents-literally file)
                             (buffer-string)))))
          (set-buffer-modified-p nil)
          (kill-buffer (current-buffer)))
      (delete-file file))))

(provide 'sov-lang-markdown-test)
;;; sov-lang-markdown-test.el ends here
