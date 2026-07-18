;;; sov-lang-org.el --- Org language configuration -*- lexical-binding: t; -*-

;; Configure Org mode.  Org is bundled with Emacs, so this file only adjusts
;; its display options and registers the optional Tree-sitter grammar.

;; Org is bundled with Emacs.  Keep its language setup here so the language
;; module can grow independently from the general editor configuration.
(require 'org)

;; The grammar is optional and is not downloaded during startup.  Install it
;; interactively with `treesit-install-language-grammar' when desired.
(when (require 'treesit nil t)
  (add-to-list 'treesit-language-source-alist
               '(org . "https://github.com/tree-sitter-grammars/tree-sitter-org")))

;; Make Org outlines look cleaner: indented headings, hidden emphasis markers,
;; pretty entities, and an ellipsis for folded sections.
(setq org-startup-indented t
      org-hide-emphasis-markers t
      org-pretty-entities t
      org-ellipsis " ...")

(add-hook 'org-mode-hook #'org-indent-mode)
(add-hook 'org-mode-hook #'visual-line-mode)


(provide 'sov-lang-org)

;;; sov-lang-org.el ends here
