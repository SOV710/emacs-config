;;; sov-lang-toml.el --- TOML Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'toml
 '((:language toml
    :url "https://github.com/tree-sitter-grammars/tree-sitter-toml"
    :fallback toml-mode
    :ts-mode toml-ts-mode
    :patterns ("\\.toml\\'"))))

(provide 'sov-lang-toml)
;;; sov-lang-toml.el ends here
