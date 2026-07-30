;;; sov-lang-emacs-lisp.el --- Emacs Lisp Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'emacs-lisp
 '((:language elisp
    :url "https://github.com/Wilfred/tree-sitter-elisp"
    ;; Newer revisions generate parser.c during npm installation, which the
    ;; built-in Emacs installer intentionally does not perform.
    :revision "1.6.1"
    :fallback emacs-lisp-mode
    :ts-mode elisp-ts-mode
    :patterns ("\\.el\\'"))))

(provide 'sov-lang-emacs-lisp)
;;; sov-lang-emacs-lisp.el ends here
