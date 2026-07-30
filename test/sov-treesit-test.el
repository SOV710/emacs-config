;;; sov-treesit-test.el --- Tests for native Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;; Package declarations in the Markdown module are not relevant to registry
;; tests and should not require the user's Elpaca bootstrap in batch mode.
(defmacro use-package (&rest _args) nil)

(require 'sov-treesit)

(defvar evil-called-from-ex-p)
(defvar evil-ex-argument)

(mapc #'require
      '(sov-lang-assembly
        sov-lang-astro
        sov-lang-bash
        sov-lang-c
        sov-lang-clojure
        sov-lang-cmake
        sov-lang-css
        sov-lang-csv
        sov-lang-dart
        sov-lang-dockerfile
        sov-lang-emacs-lisp
        sov-lang-fish
        sov-lang-ghostty
        sov-lang-go
        sov-lang-haskell
        sov-lang-html
        sov-lang-json
        sov-lang-kdl
        sov-lang-latex
        sov-lang-lua
        sov-lang-makefile
        sov-lang-markdown
        sov-lang-powershell
        sov-lang-protobuf
        sov-lang-python
        sov-lang-qml
        sov-lang-racket
        sov-lang-rust
        sov-lang-sql
        sov-lang-task
        sov-lang-toml
        sov-lang-typescript
        sov-lang-typst
        sov-lang-vue
        sov-lang-yaml))

(defconst sov-treesit-test--groups
  '(assembly astro bash c clojure cmake css csv dart dockerfile emacs-lisp
             fish ghostty go haskell html json kdl latex lua makefile markdown
             powershell protobuf python qml racket rust sql task toml typescript
             typst vue yaml))

(defconst sov-treesit-test--grammars
  '(asm astro bash c clojure cmake css csv dart dockerfile elisp fish ghostty
        go haskell html json kdl latex lua make markdown markdown-inline
        powershell proto python qmljs racket rust sql taskwarrior toml tsx
        typescript typst vue yaml))

(ert-deftest sov-treesit-registers-every-configured-language-group ()
  (should (equal (sov-treesit-language-groups)
                 sov-treesit-test--groups)))

(ert-deftest sov-treesit-registers-every-grammar-source ()
  (should (equal (sov-treesit-grammar-languages)
                 sov-treesit-test--grammars))
  (dolist (language sov-treesit-test--grammars)
    (should (assoc language treesit-language-source-alist))))

(ert-deftest sov-treesit-keeps-special-source-layouts-and-revisions ()
  (should (equal (nth 3 (assoc 'csv treesit-language-source-alist))
                 "csv/src"))
  (should (equal (nth 3 (assoc 'typescript treesit-language-source-alist))
                 "typescript/src"))
  (should (equal (nth 3 (assoc 'tsx treesit-language-source-alist))
                 "tsx/src"))
  (should (equal (nth 2 (assoc 'sql treesit-language-source-alist))
                 "gh-pages"))
  (should (equal (nth 2 (assoc 'elisp treesit-language-source-alist))
                 "1.6.1"))
  (should (equal (nth 2 (assoc 'latex treesit-language-source-alist))
                 "v0.3.0"))
  (should (equal (nth 2 (assoc 'markdown treesit-language-source-alist))
                 "v0.5.1")))

(ert-deftest sov-treesit-selection-expands-a-language-group ()
  (should (equal (mapcar (lambda (spec) (plist-get spec :language))
                         (sov-treesit--parse-selection '(typescript)))
                 '(typescript tsx)))
  (should (= (length (sov-treesit--parse-selection nil))
             (length sov-treesit-test--grammars))))

(ert-deftest sov-treesit-empty-ex-selection-expands-to-all ()
  (dolist (argument '("" nil))
    (let ((evil-called-from-ex-p t)
          (evil-ex-argument argument))
      (should-not (sov-treesit--read-selection))
      (should (= (length
                  (sov-treesit--parse-selection
                   (sov-treesit--read-selection)))
                 (length sov-treesit-test--grammars))))))

(ert-deftest sov-treesit-registers-lazy-auto-mode-dispatchers ()
  (should (eq (cdr (assoc "\\.py[iw]?\\'" auto-mode-alist))
              'sov-treesit-python-mode))
  (should (eq (cdr (assoc "\\.tsx\\'" auto-mode-alist))
              'sov-treesit-tsx-mode))
  (should (eq (cdr (assoc "\\.astro\\'" auto-mode-alist))
              'sov-treesit-astro-mode)))

(ert-deftest sov-treesit-falls-back-without-an-installed-grammar ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/example.py")
    (sov-treesit-python-mode)
    (should (eq major-mode 'python-mode))))

(ert-deftest sov-treesit-uses-a-parser-only-mode-when-no-major-mode-exists ()
  (let (created)
    (cl-letf (((symbol-function 'treesit-ready-p)
               (lambda (&rest _) t))
              ((symbol-function 'treesit-parser-create)
               (lambda (language &rest _)
                 (setq created language))))
      (with-temp-buffer
        (sov-treesit--activate-spec
         '(:language fictional :url "https://example.invalid/fictional"))
        (should (eq major-mode 'sov-treesit-generic-mode))
        (should (eq created 'fictional))))))

(ert-deftest sov-treesit-update-rebuilds-every-grammar-in-a-group ()
  (let (installed)
    (cl-letf (((symbol-function 'treesit-install-language-grammar)
               (lambda (language &rest _)
                 (push language installed)))
              ((symbol-function 'sov-treesit--grammar-available-p)
               (lambda (_language) t)))
      (sov-treesit--install-selection '(typescript) t)
      (should (equal (nreverse installed) '(typescript tsx))))))

(ert-deftest sov-treesit-clear-removes-only-managed-grammar-libraries ()
  (let ((directory (make-temp-file "sov-treesit-test-" t)))
    (unwind-protect
        (let ((sov-treesit-grammar-directory directory))
          (let ((library (sov-treesit--library-path 'rust)))
            (with-temp-file library
              (insert "test"))
            (sov-treesit-clear '(rust) t)
            (should-not (file-exists-p library))))
      (delete-directory directory t))))

(ert-deftest sov-treesit-defines-evil-ex-lifecycle-commands ()
  (let (commands)
    (cl-letf (((symbol-function 'evil-ex-define-cmd)
               (lambda (name function)
                 (push (cons name function) commands))))
      (sov-treesit--define-evil-ex-commands)
      (should (equal (cdr (assoc "TSInstall" commands))
                     #'sov-treesit-install))
      (should (equal (cdr (assoc "TSUpdate" commands))
                     #'sov-treesit-update))
      (should (equal (cdr (assoc "TSClear" commands))
                     #'sov-treesit-clear))
      (should (equal (cdr (assoc "TSStatus" commands))
                     #'sov-treesit-status)))))

(provide 'sov-treesit-test)
;;; sov-treesit-test.el ends here
