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

(provide 'sov-keymaps)
;;; sov-keymaps.el ends here
