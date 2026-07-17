;;; sov-evil.el --- Evil configuration -*- lexical-binding: t; -*-

;; evil config
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
  (evil-set-leader '(normal visual motion) (kbd "SPC"))
  (evil-set-leader '(normal visual motion) (kbd ",") t))

(use-package evil-collection
  :after evil
  :ensure (:host github
           :repo "emacs-evil/evil-collection"
           :wait t)
  :config
  (evil-collection-init))


(provide 'sov-evil)
