;;; sov-lang-kdl.el --- KDL Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'kdl
 '((:language kdl
    :url "https://github.com/amaanq/tree-sitter-kdl"
    :fallback kdl-mode
    :ts-mode kdl-ts-mode
    :patterns ("\\.kdl\\'"))))

(provide 'sov-lang-kdl)
;;; sov-lang-kdl.el ends here
