;;; sov-evil.el --- Evil configuration -*- lexical-binding: t; -*-

;; evil config
(use-package evil
  :ensure t
  :init
  (setq evil-want-integration t
        evil-want-keybinding nil
        evil-undo-system 'undo-redo
        evil-respect-visual-line-mode t)
  :config
  (evil-mode 1))

(use-package evil-collection
  :after evil
  :ensure (:host github
           :repo "emacs-evil/evil-collection"
           :wait t)
  :config
  (evil-collection-init))


(provide 'sov-evil)
