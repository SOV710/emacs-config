;;; sov-lang-fish.el --- Fish Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'fish
 '((:language fish
    :url "https://github.com/ram02z/tree-sitter-fish"
    :fallback fish-mode
    :ts-mode fish-ts-mode
    :patterns ("\\.fish\\'"))))

(provide 'sov-lang-fish)
;;; sov-lang-fish.el ends here
