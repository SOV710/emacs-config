;;; sov-lang-assembly.el --- Assembly Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'assembly
 '((:language asm
    :url "https://github.com/RubixDev/tree-sitter-asm"
    :fallback asm-mode
    :ts-mode asm-ts-mode
    :patterns ("\\.\\(?:s\\|S\\|asm\\)\\'"))))

(provide 'sov-lang-assembly)
;;; sov-lang-assembly.el ends here
