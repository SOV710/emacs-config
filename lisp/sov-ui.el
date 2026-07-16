;;; sov-ui.el --- UI Configuration -*- lexical-binding: t; -*-

;; color scheme
(use-package tokyo-night
  :ensure (:host github
           :repo "bbatsov/tokyo-night-emacs"
           :ref "main")
  :config
  (load-theme 'tokyo-night t))

(provide 'sov-ui)
