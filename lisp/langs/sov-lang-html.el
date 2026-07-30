;;; sov-lang-html.el --- HTML Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'html
 '((:language html
    :url "https://github.com/tree-sitter/tree-sitter-html"
    :fallback html-mode
    :ts-mode html-ts-mode
    :patterns ("\\.\\(?:html?\\|xhtml\\)\\'"))))

(provide 'sov-lang-html)
;;; sov-lang-html.el ends here
