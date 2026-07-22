;;; sov-evil.el --- Evil configuration -*- lexical-binding: t; -*-

;; This module sets up Evil, the Vim emulation layer, and loads the companion
;; `evil-collection' package which provides Vim-friendly bindings for many of
;; Emacs' built-in modes.


;;; Evil core

;; `evil-want-keybinding' is set to nil so that `evil-collection' can handle
;; keybindings consistently across modes.  `C-u' scrolling is enabled to
;; preserve the Vim page-up habit.  `undo-redo' is the modern Emacs 28+ undo
;; system that works well with Evil.  `evil-respect-visual-line-mode' makes
;; motion commands respect the visual lines created by soft wrapping.
(use-package evil
  :ensure (:host github
           :repo "emacs-evil/evil"
           :wait t)
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-want-C-u-scroll t
        evil-undo-system 'undo-redo
        evil-respect-visual-line-mode t)
  :config
  (evil-mode 1)
  ;; Keep Vim-style page-up behavior in normal state instead of falling back
  ;; to Emacs' universal-argument prefix.
  (evil-global-set-key 'normal (kbd "C-u") #'evil-scroll-up)
  ;; Space is the primary leader key for the custom key maps; comma is set as
  ;; an additional leader used by the `flash' motion package.
  (evil-set-leader '(normal visual motion) (kbd "SPC"))
  (evil-set-leader '(normal visual motion) (kbd ",") t))


;;; Han word boundaries

;; `emt' integrates jieba-rs with Emacs's native word-boundary table.  Evil
;; delegates word motions and word text objects through that table, so this
;; makes Chinese `w', `b', `e', `iw', and `aw' segmentation-aware without
;; replacing their key bindings.  Install the native module once with
;; `M-x emt-download-module'; the README records the first-run procedure.
(use-package emt
  :after evil
  :ensure (:host github
           :repo "LuciusChen/emt"
           :files ("*.el")
           :wait t)
  :config
  (global-emt-mode 1))


;;; Evil Collection

;; Provides Evil bindings for many built-in and third-party modes (dired,
;; ibuffer, magit, etc.).  It must be loaded after Evil is activated.
(use-package evil-collection
  :after evil
  :ensure (:host github
           :repo "emacs-evil/evil-collection"
           :wait t)
  :config
  (evil-collection-init))


(provide 'sov-evil)

;;; sov-evil.el ends here
