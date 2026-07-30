;;; sov-lang-css.el --- CSS Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'css
 '((:language css
    :url "https://github.com/tree-sitter/tree-sitter-css"
    :fallback css-mode
    :ts-mode css-ts-mode
    :patterns ("\\.css\\'"))))

(provide 'sov-lang-css)
;;; sov-lang-css.el ends here
