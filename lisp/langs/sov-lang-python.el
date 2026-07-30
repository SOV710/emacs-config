;;; sov-lang-python.el --- Python Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'python
 '((:language python
    :url "https://github.com/tree-sitter/tree-sitter-python"
    :fallback python-mode
    :ts-mode python-ts-mode
    :patterns ("\\.py[iw]?\\'"))))

(provide 'sov-lang-python)
;;; sov-lang-python.el ends here
