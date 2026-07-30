;;; sov-lang-lua.el --- Lua Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'lua
 '((:language lua
    :url "https://github.com/MunifTanjim/tree-sitter-lua"
    :fallback lua-mode
    :ts-mode lua-ts-mode
    :patterns ("\\.lua\\'"))))

(provide 'sov-lang-lua)
;;; sov-lang-lua.el ends here
