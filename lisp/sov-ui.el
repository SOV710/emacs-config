;;; sov-ui.el --- UI configuration -*- lexical-binding: t; -*-

;; color scheme
(use-package tokyo-night
  :ensure (:host github
           :repo "bbatsov/tokyo-night-emacs"
           :ref "main")
  :config
  (load-theme 'tokyo-night t))

(use-package nerd-icons
  :ensure t)

(require 'sov-ui-dashboard)
(require 'sov-ui-modeline)

(use-package indent-bars
  :ensure (:host github
           :repo "jdtsmith/indent-bars"
           :wait t)
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-color '(highlight :face-bg t :blend 0.15))
  (indent-bars-pattern ".")
  (indent-bars-width-frac 0.1)
  (indent-bars-pad-frac 0.1)
  (indent-bars-zigzag nil)
  (indent-bars-color-by-depth
   '(:regexp "outline-\\([0-9]+\\)" :blend 1))
  (indent-bars-highlight-current-depth '(:blend 0.5))
  (indent-bars-display-on-blank-lines t)
  (indent-bars-treesit-support t))


(provide 'sov-ui)
;;; sov-ui.el ends here
