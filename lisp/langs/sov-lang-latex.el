;;; sov-lang-latex.el --- LaTeX Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'latex
 '((:language latex
    :url "https://github.com/latex-lsp/tree-sitter-latex"
    ;; Later upstream releases no longer commit the generated parser.c.
    :revision "v0.3.0"
    :fallback latex-mode
    :ts-mode latex-ts-mode
    :patterns ("\\.\\(?:tex\\|ltx\\)\\'"))))

(provide 'sov-lang-latex)
;;; sov-lang-latex.el ends here
