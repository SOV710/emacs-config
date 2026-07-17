;;; sov-ui-dashboard.el --- Dashboard configuration -*- lexical-binding: t; -*-

(use-package page-break-lines
  :ensure (:host github
           :repo "purcell/page-break-lines"
           :wait t))

(use-package projectile
  :ensure (:host github
           :repo "bbatsov/projectile"
           :wait t))

(use-package all-the-icons
  :ensure (:host github
           :repo "domtronn/all-the-icons.el"
           :wait t))

(use-package dashboard
  :ensure (:host github
           :repo "emacs-dashboard/emacs-dashboard"
           :wait t)
  :custom
  (dashboard-startup-banner 'logo)
  (dashboard-items '((recents . 5)
                     (bookmarks . 5)
                     (projects . 5)))
  (dashboard-projects-backend 'projectile)
  (dashboard-display-icons-p t)
  (dashboard-icon-type 'nerd-icons)
  (dashboard-set-heading-icons t)
  (dashboard-set-file-icons t)
  :config
  (dashboard-setup-startup-hook))

(provide 'sov-ui-dashboard)
;;; sov-ui-dashboard.el ends here
