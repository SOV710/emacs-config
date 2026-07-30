;;; sov-lang-racket.el --- Racket Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'racket
 '((:language racket
    :url "https://github.com/6cdh/tree-sitter-racket"
    :fallback racket-mode
    :ts-mode racket-ts-mode
    :patterns ("\\.\\(?:rkt\\|scrbl\\)\\'"))))

(provide 'sov-lang-racket)
;;; sov-lang-racket.el ends here
