;;; sov-core.el --- Core Emacs behavior -*- lexical-binding: t; -*-

;; startup and performance
(setq gc-cons-threshold (* 64 1024 1024) ; set bytes allowed to allocate before triggering GC
      gc-cons-percentage 0.2 ; set relative heap growth allowed before GC
      read-process-output-max (* 1024 1024) ; limit max bytes Emacs reads from a subprocess at once; higher reduces fragmentation of large messages but increases transient allocation
      process-adaptive-read-buffering nil ; when disabled, Emacs usually handles arrived process output more promptly
      inhibit-startup-screen t ; skip the Emacs startup screen and show the initial buffer directly
      initial-scratch-message nil ; disable initial text in the *scratch* buffer
      )

;; customize
(setq custom-file (locate-user-emacs-file "custom.el")) ; by default, Customize may write directly into your init.el; isolate such auto-generated code
(load custom-file 'noerror)


;; file, persistence and history
(setq recentf-max-saved-items 200 ; limit number of recent files persisted by recentf
      history-length 1000 ; set maximum length kept for most minibuffer histories
      history-delete-duplicates t ; delete old duplicates when adding new history entries
      auto-revert-verbose nil ; suppress auto-revert-mode reload messages
      delete-by-moving-to-trash t ; make delete-file commands move to system trash first
      )

(recentf-mode 1) ; keep a list of recently visited files and persist it
(savehist-mode 1) ; save minibuffer history and specified variables across sessions
(save-place-mode 1) ; roughly restore cursor position like ShaDa
(global-auto-revert-mode 1) ; auto-reload the latest file content from disk when changed externally, without manual confirmation


;; display and interface
(setq-default display-line-numbers-type 'relative ; relative line numbers
              cursor-type 'bar ; cursor shape
              ring-bell-function #'ignore ; disable audible bell
              )

(menu-bar-mode -1) ; hide the top GUI menu bar
(tool-bar-mode -1) ; hide the top GUI tool bar
(scroll-bar-mode -1) ; hide the left graphical scroll bar
(global-display-line-numbers-mode t) ; enable line numbers globally
(global-hl-line-mode 1) ; highlight current visual line globally
(column-number-mode 1) ; show column number in mode-line
(show-paren-mode 1) ; enable paren matching highlight
(blink-cursor-mode -1) ; disable cursor blinking globally

;; soft wraping
(require 'kinsoku)
(setq-default truncate-lines nil ; soft wrap; refuse forced truncation
              word-wrap t ; soft wrap breaks at word boundaries, not window edges
              word-wrap-by-category t ; improve CJK word soft-wrapping experience
              )

(require 'visual-wrap)
(setq visual-wrap-extra-indent 0) ; do not add extra indentation to continuation lines
(global-visual-line-mode 1) ; use visual lines globally instead of logical lines
(global-visual-wrap-prefix-mode 1) ; make continuation lines after soft wrap inherit the original logical line indentation


;; editing indentation and whitespace
(setq-default indent-tabs-mode nil
              tab-width 4
              fill-column 100)

(setq sentence-end-double-space nil ; do not require two spaces after sentence punctuation
      tab-always-indent 'complete ; tab tries completion first, then indentation
      kill-ring-max 1000 ; kill ring size
      require-final-newline t ; auto-add final newline when saving files
      )

(electric-pair-mode 1) ; autopair
(electric-indent-mode 1) ; autoindent
(delete-selection-mode 1) ; typing replaces the selected region; minimal impact on evil users


;; search, replace and navigation
(setq-default case-fold-search t
              ); search and match ignore case by default

(setq scroll-margin 5 ; keep 5 lines above and below the cursor
      scroll-conservatively 101 ; do not auto-recenter after cursor moves past the boundary
      recenter-positions '(middle top bottom) ; recenter-top-bottom cycle order
      )

(repeat-mode 1) ; let commands supporting repeat-map be repeated with short keys


;; completion and minibuffer
(setq completion-styles '(basic substring partial-completion) ; search matching algorithm order
      completion-category-defaults nil ; all categories use your completion-styles directly
      completion-cycle-threshold 3 ; cycle when there are no more than 3 candidates
      completion-ignore-case t ; completion ignores case
      read-buffer-completion-ignore-case t ; reading buffer names ignores case
      read-file-name-completion-ignore-case t ; file name completion ignores case
      minibuffer-prompt-properties '(read-only t cursor-intangible t face minibuffer-prompt) ; minibuffer properties
      )


;; windows, frames and buffers
(require 'uniquify)
(setq window-combination-resize t ; when resizing one window, redistribute other windows in the same combination as a whole
      frame-resize-pixelwise t ; resize frame pixel-wise
      use-dialog-box nil ; never use graphical dialog boxes
      use-file-dialog nil ; forbid using system file selection dialogs
      use-short-answers t ; allow y/n short answers for yes-or-no questions
      uniquify-buffer-name-style 'forward ; when opening files with the same name, Emacs prefixes the path to distinguish them
      )


;; undo backup and auto save
(make-directory (locate-user-emacs-file "backups/") t)
(make-directory (locate-user-emacs-file "auto-save/") t)

(setq make-backup-files t ; Emacs creates backup files when saving, i.e., *~ files
      backup-directory-alist `(("." . ,(locate-user-emacs-file "backups/"))) ; put all Emacs backup files under the user-managed backups/
      backup-by-copying t ; make backups by copying instead of renaming the original file
      version-control t ; create numbered backups each time to keep historical versions
      kept-new-versions 6 ; keep 6 newer versions
      kept-old-versions 2 ; keep 2 older versions
      delete-old-versions t ; auto-delete old numbered backups when exceeding kept count
      auto-save-default t ; enable auto-save for ordinary files
      auto-save-file-name-transforms `((".*" ,(locate-user-emacs-file "auto-save/") t))
      )


;; processes, compilation and diagnostics
(setq compilation-scroll-output 'first-error ; stop auto-scrolling compilation after the first error
      comint-prompt-read-only t ; effect: cannot delete or modify prompts like user@host:~$, >>>
      next-error-recenter '(4) ; show the error line in the center of the window
      )

(add-hook 'prog-mode-hook #'flymake-mode) ; enable diagnostics for programming modes


;; projects languages, and treesit
(setq project-vc-extra-root-markers '(".project.el")) ; add root directory markers for projects
(setopt treesit-font-lock-level 4) ; maximum treesitter highlighting


;; others
(setq confirm-kill-emacs #'yes-or-no-p)


(provide 'sov-core)
