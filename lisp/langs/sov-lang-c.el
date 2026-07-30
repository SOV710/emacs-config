;;; sov-lang-c.el --- C Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'c
 '((:language c
    :url "https://github.com/tree-sitter/tree-sitter-c"
    :fallback c-mode
    :ts-mode c-ts-mode
    :patterns ("\\.c\\'"))))

(provide 'sov-lang-c)
;;; sov-lang-c.el ends here
