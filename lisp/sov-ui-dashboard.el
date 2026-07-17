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
  :config
  (dashboard-setup-startup-hook))

(provide 'sov-ui-dashboard)
;;; sov-ui-dashboard.el ends here
