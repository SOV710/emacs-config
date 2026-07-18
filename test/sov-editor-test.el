;;; sov-editor-test.el --- Tests for sov-editor -*- lexical-binding: t; -*-

(require 'ert)
(require 'sov-editor)

(ert-deftest sov-dirvish-side-create-kind-file ()
  (should (eq (sov-dirvish-side-create-kind "notes.txt") 'file)))

(ert-deftest sov-dirvish-side-create-kind-directory ()
  (should (eq (sov-dirvish-side-create-kind "src/") 'directory)))

(ert-deftest sov-dirvish-side-create-kind-empty ()
  (should-not (sov-dirvish-side-create-kind "")))

(ert-deftest sov-dirvish-side-create-entry-rejects-non-side ()
  (cl-letf (((symbol-function 'dirvish-curr) (lambda () nil)))
    (should-error (sov-dirvish-side-create-entry) :type 'user-error)))
