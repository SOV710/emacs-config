;;; sov-core.el --- Core Emacs behavior -*- lexical-binding: t; -*-

;; This module holds the baseline Emacs settings that affect startup,
;; performance, persistence, display, editing, search, completion, windows,
;; backups, diagnostics, and project support.  Most settings here do not
;; depend on any third-party package.


;;; Startup and performance

;; Raise the garbage-collection threshold during normal use.  The default is
;; very low, which causes frequent GC and can make long editing sessions feel
;; sluggish.  The percentage is kept conservative so GC still runs when the
;; heap grows meaningfully.
(setq gc-cons-threshold (* 64 1024 1024)
      gc-cons-percentage 0.2
      ;; Increase the maximum amount of output read from external processes in
      ;; a single batch.  This reduces fragmentation for large language-server
      ;; messages at the cost of slightly higher transient memory use.
      read-process-output-max (* 1024 1024)
      ;; Disable adaptive buffering so process output is handled as soon as it
      ;; arrives, which usually improves responsiveness for LSP and terminal
      ;; integrations.
      process-adaptive-read-buffering nil
      ;; Skip the startup splash screen and the default scratch-buffer text.
      inhibit-startup-screen t
      initial-scratch-message nil)


;;; Customization file isolation

;; Redirect customizations written by `customize' to a separate file so that
;; auto-generated settings never clutter the version-controlled init files.
;; If the file does not exist yet, `load' silently skips it.
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror)


;;; Files, persistence, and history

;; Keep the recent-files, minibuffer histories, and cursor positions across
;; sessions.  `global-auto-revert-mode' makes Emacs notice external changes
;; to files on disk without prompting.
(setq recentf-max-saved-items 200
      history-length 1000
      history-delete-duplicates t
      auto-revert-verbose nil
      delete-by-moving-to-trash t)

(recentf-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(global-auto-revert-mode 1)


;;; Display and interface chrome

;; Use relative line numbers, a bar cursor, and disable the audible bell.  The
;; menu bar, tool bar, and scroll bar are hidden for a cleaner look.
(setq-default display-line-numbers-type 'relative
              cursor-type 'bar
              ring-bell-function #'ignore)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode t)
(global-hl-line-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(blink-cursor-mode -1)


;;; Soft wrapping and CJK line breaking

;; `kinsoku' improves line wrapping for East Asian scripts by avoiding certain
;; characters at the beginning or end of a line.  `visual-wrap' provides the
;; `visual-wrap-prefix-mode' used below.
(require 'kinsoku)
(setq-default truncate-lines nil
              word-wrap t
              word-wrap-by-category t)

(require 'visual-wrap)
(setq visual-wrap-extra-indent 0)
(global-visual-line-mode 1)
(global-visual-wrap-prefix-mode 1)


;;; Editing, indentation, and whitespace

;; Indent with spaces, not tabs, and use a default tab width of 4 for files
;; that still contain tabs.  `fill-column' is set to 100 for prose wrapping
;; and fill commands.
(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 100)

;; Single space after sentence punctuation is enough; enable tab completion;
;; enlarge the kill ring; and always end files with a newline.
(setq sentence-end-double-space nil
      tab-always-indent 'complete
      kill-ring-max 1000
      require-final-newline t)

(electric-pair-mode 1)
(electric-indent-mode 1)
(delete-selection-mode 1)


;;; Search, replace, and navigation

;; Case-insensitive search by default, keep some context above and below the
;; cursor, and avoid aggressive recentering when scrolling long distances.
(setq-default case-fold-search t)

(setq scroll-margin 5
      scroll-conservatively 101
      recenter-positions '(middle top bottom))

;; `repeat-mode' allows commands that define a repeat map to be re-executed by
;; pressing a single key without repeating the full key sequence.
(repeat-mode 1)


;;; Completion and minibuffer

;; Cycle completion candidates when there are at most 3, and ignore case in
;; completion, file names, and buffer names.  The prompt properties make the
;; prompt read-only and keep the cursor from moving into it.
(setq completion-cycle-threshold 3
      completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t
      minibuffer-prompt-properties '(read-only t
                                      cursor-intangible t
                                      face minibuffer-prompt))


;;; Windows, frames, and buffers

;; `uniquify' is required for `uniquify-buffer-name-style'.  Windows are
;; resized as a combination, frames are resized pixel-by-pixel, and dialog
;; boxes are avoided in favor of the minibuffer.
(require 'uniquify)
(setq window-combination-resize t
      frame-resize-pixelwise t
      use-dialog-box nil
      use-file-dialog nil
      use-short-answers t
      uniquify-buffer-name-style 'forward)


;;; Undo, backup, and auto-save

;; Keep backup and auto-save files under `user-emacs-directory' so they do
;; not pollute the working tree.  Numbered backups keep a small history of
;; saved versions.
(make-directory (locate-user-emacs-file "backups/") t)
(make-directory (locate-user-emacs-file "auto-save/") t)

(setq make-backup-files t
      backup-directory-alist
      `(("." . ,(locate-user-emacs-file "backups/")))
      backup-by-copying t
      version-control t
      kept-new-versions 6
      kept-old-versions 2
      delete-old-versions t
      auto-save-default t
      auto-save-file-name-transforms
      `((".*" ,(locate-user-emacs-file "auto-save/") t)))


;;; Processes, compilation, and diagnostics

;; Stop compilation buffers from scrolling once the first error is found; make
;; comint prompts read-only; and center the error line when jumping to it.
(setq compilation-scroll-output 'first-error
      comint-prompt-read-only t
      next-error-recenter '(4))

;; Enable `flymake' in all programming modes for on-the-fly diagnostics.
(add-hook 'prog-mode-hook #'flymake-mode)


;;; Projects, languages, and Tree-sitter

;; Treat `.project.el' as a project root marker in addition to version-control
;; roots.  Use the maximum level of Tree-sitter font-locking when available.
(setq project-vc-extra-root-markers '(".project.el"))
(setopt treesit-font-lock-level 4)


;;; Safety prompts

;; Ask for explicit confirmation before quitting Emacs.
(setq confirm-kill-emacs #'yes-or-no-p)


(provide 'sov-core)

;;; sov-core.el ends here
