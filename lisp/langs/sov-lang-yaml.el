;;; sov-lang-yaml.el --- YAML Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'yaml
 '((:language yaml
    :url "https://github.com/tree-sitter-grammars/tree-sitter-yaml"
    :fallback yaml-mode
    :ts-mode yaml-ts-mode
    :patterns ("\\.ya?ml\\'"))))

(provide 'sov-lang-yaml)
;;; sov-lang-yaml.el ends here
