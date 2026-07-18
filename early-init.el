;;; early-init.el --- Early initialization -*- lexical-binding: t; -*-

;; This file is loaded before the package system is initialized.  Use it
;; for settings that must take effect very early in startup, such as disabling
;; the built-in package manager and adjusting startup-time performance options.

;; Disable the default `package.el' package manager.  Elpaca is used instead,
;; and leaving `package.el' enabled would cause it to try to initialize at the
;; same time as Elpaca, leading to conflicts and duplicated work.
(setq package-enable-at-startup nil)

;;; early-init.el ends here
