;;; sov-lang-powershell.el --- PowerShell Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'powershell
 '((:language powershell
    :url "https://github.com/airbus-cert/tree-sitter-powershell"
    :fallback powershell-mode
    :ts-mode powershell-ts-mode
    :patterns ("\\.\\(?:ps1\\|psm1\\|psd1\\)\\'"))))

(provide 'sov-lang-powershell)
;;; sov-lang-powershell.el ends here
