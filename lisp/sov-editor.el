;;; sov-editor.el --- Editor Flow -*- lexical-binding: t; -*-

(use-package which-key
  :ensure nil
  :init
  (which-key-mode 1))

;; file tree
(use-package dired
  :ensure nil
  :config
  (setq dired-listing-switches
        "-l --almost-all --human-readable --group-directories-first --no-group")
  (put 'dired-find-alternate-file 'disabled nil))

(use-package dirvish
  :ensure (:host github
           :repo "alexluigit/dirvish"
           :wait t)
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-side-width 24)
  (dirvish-side-auto-expand t)
  (dirvish-side-window-parameters
   '((no-delete-other-windows . t)))
  :config
  (require 'dirvish-side)
  (evil-define-key '(normal visual motion) 'global
    (kbd "<leader>o") #'dirvish-dwim
    (kbd "<leader>e") #'dirvish-side)
  (evil-define-key 'normal dirvish-mode-map
    (kbd "h") #'dired-up-directory
    (kbd "l") #'dired-find-file
    (kbd "SPC e") #'dirvish-side))

(provide 'sov-editor)
