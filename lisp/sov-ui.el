;;; sov-ui.el --- UI configuration -*- lexical-binding: t; -*-

;; color scheme
(use-package tokyo-night
  :ensure (:host github
           :repo "bbatsov/tokyo-night-emacs"
           :ref "main")
  :config
  (load-theme 'tokyo-night t))

(require 'sov-ui-modeline)

(provide 'sov-ui)
;;; sov-ui.el ends here
