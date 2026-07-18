;;; sov-lang-markdown.el --- Markdown language configuration -*- lexical-binding: t; -*-

;; Configure Markdown editing with both the classic `markdown-mode' and the
;; optional Tree-sitter grammar for Markdown.  The Tree-sitter grammar is
;; registered but not downloaded automatically.

;; Markdown mode supplies editing commands and font-locking; its optional
;; Tree-sitter mode is used when the installed version provides it.
(use-package markdown-mode
  :ensure (:host github
           :repo "jrblevin/markdown-mode"
           :wait t)
  :mode (("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode)
         ("\\.mdown\\'" . markdown-mode)
         ("\\.mkdn\\'" . markdown-mode))
  :custom
  (markdown-fontify-code-blocks-natively t)
  (markdown-enable-math t)
  (markdown-hide-urls nil)
  :hook ((markdown-mode . visual-line-mode)
         (markdown-mode . turn-on-auto-fill)))

;; Register Markdown Tree-sitter grammars when the built-in `treesit' package
;; is available.  Install them interactively with `treesit-install-language-grammar'.
(when (require 'treesit nil t)
  (add-to-list 'treesit-language-source-alist
               '(markdown . "https://github.com/tree-sitter-grammars/tree-sitter-markdown"))
  (add-to-list 'treesit-language-source-alist
               '(markdown-inline . "https://github.com/tree-sitter-grammars/tree-sitter-markdown")))


(provide 'sov-lang-markdown)

;;; sov-lang-markdown.el ends here
