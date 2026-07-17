;;; sov-keymaps.el --- Custom Keymaps Configuration -*- lexical-binding: t; -*-

;; window management
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

;; bookmarks
;; Keep bookmark commands in normal state so these single-key bindings do not
;; interfere with insertion and minibuffer workflows.
(evil-define-key '(normal) 'global
  (kbd "m") #'bookmark-set
  (kbd "C-'") #'bookmark-jump
  (kbd "'") #'list-bookmarks)

;; selection
(defun sov-evil-select-whole-buffer ()
  "Select the accessible buffer in Evil visual-line state."
  (interactive)
  (evil-visual-select (point-min) (point-max) 'line))

(evil-define-key 'normal 'global
  (kbd "C-a") #'sov-evil-select-whole-buffer)

;; paste
;; Use the native yank command so the binding follows Emacs' kill-ring rules.
(global-set-key (kbd "C-S-v") #'yank)

(provide 'sov-keymaps)
;;; sov-keymaps.el ends here
