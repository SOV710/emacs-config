;;; sov-ui-dashboard.el --- Dashboard configuration -*- lexical-binding: t; -*-

(use-package dashboard
  :ensure (:host github
           :repo "emacs-dashboard/emacs-dashboard"
           :wait t)
  :config
  (dashboard-setup-startup-hook))

(provide 'sov-ui-dashboard)
;;; sov-ui-dashboard.el ends here
