;;; sov-lang-astro.el --- Astro Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'astro
 '((:language astro
    :url "https://github.com/virchau13/tree-sitter-astro"
    :fallback astro-mode
    :ts-mode astro-ts-mode
    :patterns ("\\.astro\\'"))))

(provide 'sov-lang-astro)
;;; sov-lang-astro.el ends here
