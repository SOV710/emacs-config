;;; sov-lang-ghostty.el --- Ghostty Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'ghostty
 '((:language ghostty
    :url "https://github.com/bezhermoso/tree-sitter-ghostty"
    :fallback conf-mode
    :ts-mode ghostty-ts-mode
    :patterns ("/ghostty/config\\'" "ghostty\\.config\\'"))))

(provide 'sov-lang-ghostty)
;;; sov-lang-ghostty.el ends here
