;;; sov-editor.el --- Editor Flow -*- lexical-binding: t; -*-

;; This module collects packages that improve the editing flow: key discovery,
;; delimiter colorization, undo navigation, surrounding text objects, minibuffer
;; completion, file navigation, and fast jump motions.


;;; Key discovery

;; `which-key' displays the available keys after a prefix is pressed, making it
;; easier to remember and discover new bindings.
(use-package which-key
  :ensure nil
  :init
  (which-key-mode 1))


;;; Delimiter colorization

;; Colorize nested delimiters only in Lisp-family buffers.  The hook list is
;; explicit so it does not run in unrelated modes and avoids pulling the mode
;; into non-Lisp editing buffers.
(use-package rainbow-delimiters
  :ensure (:host github
           :repo "Fanael/rainbow-delimiters"
           :wait t)
  :hook ((emacs-lisp-mode . rainbow-delimiters-mode)
         (lisp-interaction-mode . rainbow-delimiters-mode)
         (lisp-mode . rainbow-delimiters-mode)
         (common-lisp-mode . rainbow-delimiters-mode)
         (scheme-mode . rainbow-delimiters-mode)
         (clojure-mode . rainbow-delimiters-mode)
         (clojurec-mode . rainbow-delimiters-mode)
         (clojurescript-mode . rainbow-delimiters-mode)
         (racket-mode . rainbow-delimiters-mode)
         (hy-mode . rainbow-delimiters-mode)
         (fennel-mode . rainbow-delimiters-mode)))


;;; Undo tree

;; Visualize and navigate the undo tree.  The leader binding is registered
;; before the package is loaded; the command itself is autoloaded on demand.
(use-package vundo
  :ensure (:host github
           :repo "casouri/vundo"
           :wait t)
  :commands (vundo vundo-mode)
  :init
  (evil-define-key '(normal visual motion) 'global
    (kbd "<leader>us") #'vundo)
  :config
  ;; Keep vundo's tree navigation close to Evil/Vim's hjkl convention.  The
  ;; original f/b bindings remain available as aliases for forward/backward.
  ;; Use Evil's state-aware definition so normal-state motion bindings do not
  ;; shadow the vundo local map (notably `j'/`k').
  (evil-define-key 'normal vundo-mode-map
    (kbd "h") #'vundo-backward
    (kbd "l") #'vundo-forward
    (kbd "j") #'vundo-next
    (kbd "k") #'vundo-previous
    (kbd "G") #'vundo-goto-last-saved
    (kbd "n") #'vundo-goto-next-saved
    (kbd "r") #'vundo-stem-root))


;;; Surround editing

;; Evil-surround provides operator-style add/delete/change operations.  Keep
;; the custom prefix under `ga' so normal-state `gaa' composes naturally with
;; motions, e.g. `gaaiw' followed by a double-quote; visual state uses the
;; selected region directly.
(defvar sov-evil-surround-normal-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a") #'evil-surround-edit)
    (define-key map (kbd "A") #'evil-Surround-edit)
    (define-key map (kbd "d") #'evil-surround-delete)
    (define-key map (kbd "r") #'evil-surround-change)
    map)
  "Normal-state prefix map for surround editing commands.

\=`a' adds a surrounding pair, `A' adds a pair on a whole line, `d' deletes
a surrounding pair, and `r' replaces an existing pair.")

(defvar sov-evil-surround-visual-prefix-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "a") #'evil-surround-region)
    (define-key map (kbd "A") #'evil-Surround-region)
    map)
  "Visual-state prefix map for surround editing commands.")

(use-package evil-surround
  :ensure (:host github
           :repo "emacs-evil/evil-surround"
           :wait t)
  :after evil
  :config
  (global-evil-surround-mode 1)
  ;; Evil normally assigns `ga' to `what-cursor-position'; `C-x =' remains
  ;; available for that command after replacing `ga' with this prefix.
  (evil-global-set-key 'normal (kbd "ga")
                       sov-evil-surround-normal-prefix-map)
  (evil-global-set-key 'visual (kbd "ga")
                       sov-evil-surround-visual-prefix-map))


;;; Minibuffer completion and search

;; `project' is built into Emacs; require it so later consult/projectile
;; integration finds it without relying on autoloads.
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

;; Render the completion candidate list in the minibuffer with vertical layout.
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

;; Provide searchable buffer, project, navigation, and history commands with
;; preview and integration with other packages.
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
    (kbd "<leader>sd") #'consult-fd
    (kbd "<leader>sg") #'consult-ripgrep)
  (setq register-preview-delay 0.5
        register-preview-function #'consult-register-format
        xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)
  (advice-add #'register-preview :override #'consult-register-window)
  :config
  ;; Include files excluded by Git ignore rules in `consult-fd' results.
  (add-to-list 'consult-fd-args "--no-ignore-vcs" t))

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


;;; File tree

;; Dired is built in; tune its listing format and re-enable the alternate-file
;; command that is disabled by default for safety.
(use-package dired
  :ensure nil
  :config
  (setq dired-listing-switches
        "-l --almost-all --human-readable --group-directories-first --no-group")
  (put 'dired-find-alternate-file 'disabled nil))

(defun sov-dirvish-side-toggle-or-open ()
  "Expand directories in Dirvish Side, otherwise open the current entry.

When the cursor is on a directory in a Dirvish Side window, toggle its
subtree; otherwise visit the file or directory at point normally."
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

(defun sov-dirvish-side-create-kind (name)
  "Classify NAME as a file, directory, or empty input."
  (cond ((string= name "") nil)
        ((string-suffix-p "/" name) 'directory)
        (t 'file)))

(defun sov-dirvish-side-create-entry ()
  "Create a file or directory in the current Dirvish Side directory."
  (interactive)
  (let ((session (dirvish-curr)))
    (unless (and session (eq (dv-type session) 'side))
      (user-error "This command is only available in Dirvish Side")))
  (let* ((name (read-string "Create file/directory: "))
         (kind (sov-dirvish-side-create-kind name)))
    (when kind
      (require 'dired-aux)
      (let ((path (expand-file-name (directory-file-name name)
                                    default-directory)))
        (if (eq kind 'directory)
            (dired-create-directory path)
          (dired-create-empty-file path))
        (revert-buffer nil t)))))

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
  ;; The order of some attributes matters (e.g. `subtree-state' must be placed
  ;; before `collapse' to render correctly).  The full dirvish view uses the
  ;; full set; the side panel uses a smaller subset to save horizontal space.
  (setq dirvish-attributes
        '(vc-state subtree-state nerd-icons collapse git-msg file-time file-size)
        dirvish-side-attributes
        '(vc-state nerd-icons collapse file-size))
  (evil-define-key '(normal visual motion) 'global
    (kbd "<leader>o") #'dirvish-dwim
    (kbd "<leader>e") #'sov-dirvish-side-toggle)
  (evil-define-key 'normal dirvish-mode-map
    (kbd "a") #'sov-dirvish-side-create-entry
    (kbd "h") #'dired-up-directory
    (kbd "l") #'sov-dirvish-side-toggle-or-open
    (kbd "RET") #'sov-dirvish-side-toggle-or-open
    (kbd "SPC e") #'sov-dirvish-side-toggle))


;;; Smarter navigate/search motion

;; Flash is an `avy'-like jump package that supports operator-pending motion,
;; multi-window jumps, and tree-sitter aware targets.  It also suppresses
;; built-in `hlsearch' and integrates with `pulsar' for visual feedback.
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
  ;; Bind `s' to Flash in all relevant Evil states so it works as a motion,
  ;; operator target, and visual jump.
  (evil-global-set-key 'normal (kbd "s") #'flash-evil-jump)
  (evil-global-set-key 'visual (kbd "s") #'flash-evil-jump)
  (evil-global-set-key 'motion (kbd "s") #'flash-evil-jump)
  (evil-global-set-key 'operator (kbd "s") #'flash-evil-jump)
  ;; Comma is a secondary leader reserved for Flash-related commands.
  (evil-set-leader '(normal visual motion) (kbd ",") t))


(provide 'sov-editor)

;;; sov-editor.el ends here
