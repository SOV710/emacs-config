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

(defun sov-dirvish-side-toggle-or-open ()
  "Expand directories in Dirvish Side, otherwise open the current entry."
  (interactive)
  (let ((session (dirvish-curr))
        (file (dired-get-filename nil t)))
    (if (and session
             (eq (dv-type session) 'side)
             file
             (file-directory-p file))
        (dirvish-subtree-toggle)
      (dired-find-file))))

(defun sov-dirvish-side-toggle ()
  "Open Dirvish Side, or close it whenever it is already visible."
  (interactive)
  (let ((window (dirvish-side--session-visible-p)))
    (if window
        (with-selected-window window
          (dirvish-quit))
      (dirvish-side))))

(use-package dirvish
  :ensure (:host github
           :repo "alexluigit/dirvish"
           :wait t)
  :init
  (dirvish-override-dired-mode)
  :custom
  (dirvish-side-width 32)
  (dirvish-side-auto-expand t)
  (dirvish-side-window-parameters
   '((no-delete-other-windows . t)))
  :config
  (require 'dirvish-side)
  (setq dirvish-attributes           ; The order *MATTERS* for some attributes
      '(vc-state subtree-state nerd-icons collapse git-msg file-time file-size)
      dirvish-side-attributes
      '(vc-state nerd-icons collapse file-size))
  (evil-define-key '(normal visual motion) 'global
    (kbd "<leader>o") #'dirvish-dwim
    (kbd "<leader>e") #'sov-dirvish-side-toggle)
  (evil-define-key 'normal dirvish-mode-map
    (kbd "h") #'dired-up-directory
    (kbd "l") #'sov-dirvish-side-toggle-or-open
    (kbd "RET") #'sov-dirvish-side-toggle-or-open
    (kbd "SPC e") #'sov-dirvish-side-toggle))

;; smarter navigate/search motion
(use-package flash
  :ensure (:host github
           :repo "Prgebish/flash"
           :wait t)
  :after evil
  :custom
  (flash-labels "asdfghjklqwertyuiopzxcvbnm")
  (flash-label-uppercase t)
  (flash-multi-char-labels nil)
  (flash-multi-window t)
  (flash-autojump nil)
  (flash-backdrop nil)
  (flash-rainbow t)
  (flash-rainbow-shade 2)
  (flash-highlight-matches t)
  (flash-label-position 'after)
  (flash-char-jump-labels t)
  (flash-char-multi-line t)
  (flash-char-reserved-labels "hjkliardcHJKLIARDC;,")
  (flash-nohlsearch t)
  (flash-search-history nil)
  :config
  (require 'flash-evil)
  (flash-evil-setup t)
  (evil-global-set-key 'normal (kbd "s") #'flash-evil-jump)
  (evil-global-set-key 'visual (kbd "s") #'flash-evil-jump)
  (evil-global-set-key 'motion (kbd "s") #'flash-evil-jump)
  (evil-global-set-key 'operator (kbd "s") #'flash-evil-jump)
  (evil-set-leader '(normal visual motion) (kbd ",") t))

(provide 'sov-editor)
