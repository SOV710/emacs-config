;;; sov-editor-test.el --- Tests for sov-editor -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'sov-editor)

(ert-deftest sov-dirvish-create-kind-file ()
  (should (eq (sov-dirvish-create-kind "notes.txt") 'file)))

(ert-deftest sov-dirvish-create-kind-directory ()
  (should (eq (sov-dirvish-create-kind "src/") 'directory)))

(ert-deftest sov-dirvish-create-kind-empty ()
  (should-not (sov-dirvish-create-kind "")))

(ert-deftest sov-dirvish-create-entry-uses-directory-at-point ()
  (require 'dired-aux)
  (let (created-file created-directory)
    (cl-letf (((symbol-function 'dired-current-directory)
               (lambda () "/tmp/root/dir/"))
              ((symbol-function 'read-string)
               (lambda (&rest _) "new"))
              ((symbol-function 'dired-create-empty-file)
               (lambda (path) (setq created-file path)))
              ((symbol-function 'dired-create-directory)
               (lambda (path) (setq created-directory path))))
      (sov-dirvish-create-entry))
    (should (equal created-file "/tmp/root/dir/new"))
    (should-not created-directory)))
