;;; sov-editor.el --- Editor Flow -*- lexical-binding: t; -*-

(use-package which-key
  :ensure nil
  :init
  (which-key-mode 1))

;; Surround editing
;; Evil-surround provides operator-style add/delete/change operations.  Keep
;; the custom prefix under `ga` so normal-state `gaa` composes naturally with
;; motions, e.g. `gaaiw` followed by a double-quote; visual state uses the
;; selected region directly.
(use-package evil-surround
  :ensure (:host github
           :repo "emacs-evil/evil-surround"
           :wait t)
  :after evil
  :config
  (global-evil-surround-mode 1)
  (evil-define-key 'normal evil-surround-mode-map
    (kbd "gaa") #'evil-surround-edit
    (kbd "gad") #'evil-surround-delete
    (kbd "gar") #'evil-surround-change)
  (evil-define-key 'visual evil-surround-mode-map
    (kbd "gaa") #'evil-surround-region))

;; minibuffer completion and search
(use-package project
  :ensure nil)

;; Match space-separated components independently in completion candidates.
(use-package orderless
  :ensure (:host github
           :repo "oantolin/orderless"
           :wait t)
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  ;; Keep native path-component completion for literal file paths.
  (completion-category-overrides
   '((file (styles partial-completion)))))

;; Render the completion candidate list in the minibuffer.
(use-package vertico
  :ensure (:host github
           :repo "minad/vertico"
           :wait t)
  :bind (:map vertico-map
              ("C-j" . vertico-next)
              ("C-k" . vertico-previous))
  :init
  (vertico-mode 1)
  :custom
  (vertico-cycle t)
  (vertico-count 15))

;; Add contextual annotations such as mode, path, size, and documentation.
(use-package marginalia
  :ensure (:host github
           :repo "minad/marginalia"
           :wait t)
  :init
  (marginalia-mode 1))

;; Provide searchable buffer, project, navigation, and history commands with preview.
(use-package consult
  :ensure (:host github
           :repo "minad/consult"
           :wait t)
  :after project
  :bind (([remap switch-to-buffer] . consult-buffer)
         ([remap project-switch-to-buffer] . consult-project-buffer)
         ([remap goto-line] . consult-goto-line)
         ([remap imenu] . consult-imenu)
         ("M-p" . consult-yank-pop))
  :init
  (evil-define-key '(normal visual motion) 'global
    (kbd "<leader>sb") #'consult-project-buffer
    (kbd "<leader>sf") #'project-find-file
    (kbd "<leader>sg") #'consult-ripgrep)
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format
        xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  (advice-add #'register-preview :override #'consult-register-window))

;; Offer context-sensitive actions for the current candidate or point target.
(use-package embark
  :ensure (:host github
           :repo "oantolin/embark"
           :wait t)
  :bind (("C-." . embark-act)
         ("C-;" . embark-dwim)
         ("C-h B" . embark-bindings))
  :init
  (setq prefix-help-command #'embark-prefix-help-command))

;; Preserve Consult previews in exported or collected Embark candidate buffers.
(use-package embark-consult
  :ensure (:host github
           :repo "oantolin/embark"
           :files ("embark-consult.el")
           :wait t)
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-at-point-mode))

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
