;;; sov-ui-dashboard.el --- Dashboard configuration -*- lexical-binding: t; -*-

;; This module configures the startup dashboard that appears after Emacs
;; initializes.  It shows recent files, bookmarks, and projects with icons.


;;; Dependencies

;; `page-break-lines' improves the rendering of the dashboard banner lines by
;; turning page breaks into clean horizontal rules.
(use-package page-break-lines
  :ensure (:host github
           :repo "purcell/page-break-lines"
           :wait t))

;; The dashboard uses Projectile as the project backend so it can list projects
;; from the Projectile cache.
(use-package projectile
  :ensure (:host github
           :repo "bbatsov/projectile"
           :wait t))

;; `all-the-icons' is required by the original dashboard implementation for
;; some icon fallbacks; the active icon set below is `nerd-icons'.
(use-package all-the-icons
  :ensure (:host github
           :repo "domtronn/all-the-icons.el"
           :wait t))


;;; Dashboard

;; Show the Emacs logo, recent files, bookmarks, and projects at startup.
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
