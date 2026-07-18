;;; sov-lang-org.el --- Org language configuration -*- lexical-binding: t; -*-

;; Org is bundled with Emacs.  Keep its language setup here so the language
;; module can grow independently from the general editor configuration.
(require 'org)

;; Org already has its own structural parser; Emacs 30 does not provide an
;; `org-ts-mode', so registering an unused Tree-sitter grammar adds no value.
(setq org-startup-indented t
      org-hide-emphasis-markers t
      org-pretty-entities t
      org-ellipsis " ..."
      org-fontify-done-headline t
      org-fontify-quote-and-verse-blocks t
      org-fontify-whole-heading-line t
      org-hide-leading-stars t
      org-image-actual-width nil
      org-imenu-depth 6
      org-list-indent-offset 4
      org-tags-column 0
      ;; Only braces trigger sub/superscripts, avoiding surprises in prose.
      org-use-sub-superscripts '{}
      ;; Preserve the source language's indentation in edit buffers.
      org-src-preserve-indentation t
      org-src-tab-acts-natively t
      org-src-window-setup 'other-window)

(add-hook 'org-mode-hook #'org-indent-mode)
(add-hook 'org-mode-hook #'visual-line-mode)


(provide 'sov-lang-org)
;;; sov-lang-org.el ends here
