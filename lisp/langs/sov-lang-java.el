;;; sov-lang-java.el --- Java Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'java
 '((:language java
    :url "https://github.com/tree-sitter/tree-sitter-java"
    :fallback java-mode
    :ts-mode java-ts-mode
    :patterns ("\\.java\\'"))))

(provide 'sov-lang-java)
;;; sov-lang-java.el ends here
