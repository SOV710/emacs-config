;;; init.el --- Emacs configuration -*- lexical-binding: t; -*-

;; This file is the main entry point of the configuration.  It sets up the
;; package manager, loads the font, and then requires the modular feature
;; files under `lisp/' and `lisp/langs/'.


;;; Load paths

;; Make the custom Lisp modules discoverable by `require'.  `user-emacs-directory'
;; points to the directory containing this `init.el' file.
(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "lisp/langs" user-emacs-directory))


;;; Elpaca bootstrap

;; Elpaca is a package manager that clones and byte-compiles packages from
;; their source repositories.  The block below is the standard self-installing
;; bootstrap snippet; it fetches Elpaca if it is not already present, sets up
;; autoloads, and arranges for queued package installations to be processed
;; after the normal init phase.
(defvar elpaca-installer-version 0.12)
(defvar elpaca-directory
  (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory
  (expand-file-name "builds/" elpaca-directory))
(defvar elpaca-sources-directory
  (expand-file-name "sources/" elpaca-directory))
(defvar elpaca-order
  '(elpaca
    :repo "https://github.com/progfolio/elpaca.git"
    :ref nil
    :depth 1
    :inherit ignore
    :files (:defaults "elpaca-test.el" (:exclude "extensions"))
    :build (:not elpaca-activate)))

(let* ((repo (expand-file-name "elpaca/" elpaca-sources-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  ;; Prefer the already-built copy when available; otherwise use the raw clone.
  (add-to-list 'load-path
               (if (file-exists-p build)
                   build
                 repo))

  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28)
      (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer
                   (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop
                    (apply
                     #'call-process
                     `("git" nil ,buffer t
                       "clone"
                       ,@(when-let* ((depth
                                     (plist-get order :depth)))
                           (list
                            (format "--depth=%d" depth)
                            "--no-single-branch"))
                       ,(plist-get order :repo)
                       ,repo))))
                  ((zerop
                    (call-process
                     "git" nil buffer t
                     "checkout"
                     (or (plist-get order :ref) "--"))))
                  (emacs
                   (concat invocation-directory invocation-name))
                  ((zerop
                    (call-process
                     emacs nil buffer nil
                     "-Q"
                     "-L" "."
                     "--batch"
                     "--eval"
                     "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn
              (message "%s" (buffer-string))
              (kill-buffer buffer))
          (error "%s"
                 (with-current-buffer buffer
                   (buffer-string))))
      ((error)
       (warn "%s" err)
       (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil))
      (load "./elpaca-autoloads"))))

(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))


;;; use-package integration

;; Elpaca provides a `use-package' integration that teaches `use-package'
;; to use `:ensure' with Elpaca recipes.  `elpaca-wait' pauses the init
;; sequence until the package is installed and loaded so that subsequent
;; `use-package' forms work as expected.
(elpaca elpaca-use-package
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))
(elpaca-wait)


;;; Font and default frame size

;; Set the default font family and size.  These constants are used by the
;; helper below and are kept in one place so they are easy to change.
(defconst sov-default-font-family "Smile Nerd Font Mono")
(defconst sov-default-font-height 180)

(defun sov-apply-font (&optional frame)
  "Apply the configured font to FRAME.
If FRAME is omitted, apply the font to the currently selected frame."
  (with-selected-frame (or frame (selected-frame))
    (set-face-attribute 'default frame
                        :family sov-default-font-family
                        :height sov-default-font-height)))

;; Give new frames a comfortable default size.
(setq default-frame-alist
      '((width . 110)
        (height . 38)))


;;; Core modules

;; Load the modular configuration in a deliberate order: core behavior first,
;; then Evil and key bindings, then UI, then editor enhancements, and finally
;; language-specific modules.  UI is loaded before `sov-apply-font' so that
;; the font is applied after any theme that might have changed face defaults.
(require 'sov-core)
(require 'sov-evil)
(require 'sov-keymaps)
(require 'sov-ui)
(sov-apply-font)
(add-hook 'after-make-frame-functions #'sov-apply-font)

(require 'sov-editor)
(require 'sov-lang-org)
(require 'sov-lang-markdown)
