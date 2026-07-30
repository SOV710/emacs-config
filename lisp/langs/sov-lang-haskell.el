;;; sov-lang-haskell.el --- Haskell Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'haskell
 '((:language haskell
    :url "https://github.com/tree-sitter/tree-sitter-haskell"
    :fallback haskell-mode
    :ts-mode haskell-ts-mode
    :patterns ("\\.\\(?:l?hs\\)\\'"))))

(provide 'sov-lang-haskell)
;;; sov-lang-haskell.el ends here
