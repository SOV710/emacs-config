;;; sov-lang-makefile.el --- Makefile Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'makefile
 '((:language make
    :url "https://github.com/alemuller/tree-sitter-make"
    :fallback makefile-mode
    :ts-mode makefile-ts-mode
    :patterns ("\\(?:[Mm]akefile\\|\\.\\(?:mk\\|make\\)\\)\\'"))))

(provide 'sov-lang-makefile)
;;; sov-lang-makefile.el ends here
