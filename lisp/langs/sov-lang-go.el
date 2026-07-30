;;; sov-lang-go.el --- Go Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'go
 '((:language go
    :url "https://github.com/tree-sitter/tree-sitter-go"
    :fallback go-mode
    :ts-mode go-ts-mode
    :patterns ("\\.go\\'"))))

(provide 'sov-lang-go)
;;; sov-lang-go.el ends here
