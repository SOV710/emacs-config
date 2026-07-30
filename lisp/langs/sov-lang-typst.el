;;; sov-lang-typst.el --- Typst Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'typst
 '((:language typst
    :url "https://github.com/uben0/tree-sitter-typst"
    :fallback typst-mode
    :ts-mode typst-ts-mode
    :patterns ("\\.typ\\'"))))

(provide 'sov-lang-typst)
;;; sov-lang-typst.el ends here
