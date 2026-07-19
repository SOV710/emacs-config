;;; sov-keymaps.el --- Custom Keymaps Configuration -*- lexical-binding: t; -*-

;; This module holds custom key bindings that are not tied to a specific
;; package.  Bindings that depend on a particular package are defined inside
;; that package's `use-package' form instead.


;;; Window management

;; The space leader is used for window commands, while the standard Ctrl + h/j/k/l
;; chord is used for moving between adjacent windows.  Shifted variants resize the
;; currently selected window.
(evil-define-key '(normal visual motion) 'global
  (kbd "<leader>wh") #'split-window-below
  (kbd "<leader>wv") #'split-window-right
  (kbd "<leader>wd") #'delete-window
  (kbd "C-h") #'windmove-left
  (kbd "C-j") #'windmove-down
  (kbd "C-k") #'windmove-up
  (kbd "C-l") #'windmove-right
  (kbd "C-S-h") #'shrink-window-horizontally
  (kbd "C-S-l") #'enlarge-window-horizontally
  (kbd "C-S-k") #'enlarge-window
  (kbd "C-S-j") #'shrink-window)


;;; Session

;; Save modified buffers as needed, kill every buffer, and then terminate the
;; Emacs daemon or graphical session.  `confirm-kill-emacs' in `sov-core.el'
;; keeps a final confirmation before Emacs exits.
(evil-define-key '(normal visual motion) 'global
  (kbd "<leader>qq") #'save-buffers-kill-emacs)


;;; Bookmarks

;; Keep bookmark commands in normal state so these single-key bindings do not
;; interfere with insertion and minibuffer workflows.  `m' sets a bookmark at
;; point, `'' jumps to a bookmark, and `C-'' opens the bookmark list.
(evil-define-key '(normal) 'global
  (kbd "m") #'bookmark-set
  (kbd "C-'") #'bookmark-jump
  (kbd "'") #'list-bookmarks)


;;; Selection

(defun sov-evil-select-whole-buffer ()
  "Select the accessible buffer in Evil visual-line state."
  (interactive)
  (evil-visual-select (point-min) (point-max) 'line))

(evil-define-key 'normal 'global
  (kbd "C-a") #'sov-evil-select-whole-buffer)


;;; Paste

;; Use the native yank command so the binding follows Emacs' kill-ring rules.
(global-set-key (kbd "C-S-v") #'yank)


(provide 'sov-keymaps)

;;; sov-keymaps.el ends here
