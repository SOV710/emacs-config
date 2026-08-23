;;; sov-lang-nix.el --- Nix Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(use-package nix-ts-mode
  :ensure t
  :commands nix-ts-mode)

(sov-treesit-register-language
 'nix
 '((:language nix
    :url "https://github.com/nix-community/tree-sitter-nix"
    :fallback nix-mode
    :ts-mode nix-ts-mode
    :patterns ("\\.nix\\'"))))

(provide 'sov-lang-nix)
;;; sov-lang-nix.el ends here
