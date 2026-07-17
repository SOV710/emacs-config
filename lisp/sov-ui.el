;;; sov-ui.el --- UI configuration -*- lexical-binding: t; -*-

;; color scheme
(use-package tokyo-night
  :ensure (:host github
           :repo "bbatsov/tokyo-night-emacs"
           :ref "main")
  :config
  (load-theme 'tokyo-night t))

(use-package nerd-icons
  :ensure t)

(require 'sov-ui-dashboard)
(require 'sov-ui-modeline)

;; Reuse the modeline state color for the current line.  The remap is
;; buffer-local, so different buffers can safely be in different Evil states.
(require 'face-remap)
(require 'color)

(defcustom sov-ui-hl-line-state-color-strength 0.16
  "Strength of the modeline state color mixed into the current line.
A value of 0 uses the normal buffer background; 1 uses the full modeline
state color."
  :type 'float
  :group 'faces)

(defvar-local sov-ui--hl-line-state-remap nil
  "Face-remap cookie for the current buffer's state-colored `hl-line'.")

(defun sov-ui--blend-hl-line-state-color (state-color)
  "Blend STATE-COLOR into the default buffer background."
  (let* ((background (sov-ui--face-color
                      'default :background "#000000"))
         (state-rgb (color-name-to-rgb state-color))
         (background-rgb (color-name-to-rgb background))
         (strength (max 0.0 (min 1.0
                                 sov-ui-hl-line-state-color-strength))))
    (if (and state-rgb background-rgb)
        (apply #'color-rgb-to-hex
               (append
                (cl-mapcar
                 (lambda (state base)
                   (+ (* strength state)
                      (* (- 1.0 strength) base)))
                 state-rgb background-rgb)
                '(2)))
      background)))

(defun sov-ui--refresh-hl-line-state (&optional state)
  "Refresh the current line color for Evil STATE in the current buffer."
  (when sov-ui--hl-line-state-remap
    (face-remap-remove-relative sov-ui--hl-line-state-remap))
  (setq sov-ui--hl-line-state-remap
        (face-remap-add-relative
         'hl-line
         `(:foreground unspecified
           :background
           ,(sov-ui--blend-hl-line-state-color
             (sov-ui--face-background
              (cadr (sov-ui--evil-info
                     (or state (and (boundp 'evil-state) evil-state)
                         'emacs)
                     t)))))))
  (when (bound-and-true-p hl-line-mode)
    (force-mode-line-update)))

;; Evil's state entry hooks run after each transition, including operator and
;; temporary visual states.  Apply the initial color to buffers created later.
(dolist (hook '(evil-normal-state-entry-hook
                evil-motion-state-entry-hook
                evil-insert-state-entry-hook
                evil-visual-state-entry-hook
                evil-replace-state-entry-hook
                evil-operator-state-entry-hook
                evil-emacs-state-entry-hook))
  (add-hook hook #'sov-ui--refresh-hl-line-state))
(add-hook 'after-change-major-mode-hook #'sov-ui--refresh-hl-line-state)
(sov-ui--refresh-hl-line-state)

(use-package indent-bars
  :ensure (:host github
           :repo "jdtsmith/indent-bars"
           :wait t)
  :hook (prog-mode . indent-bars-mode)
  :custom
  (indent-bars-color '(highlight :face-bg t :blend 0.15))
  (indent-bars-pattern ".")
  (indent-bars-width-frac 0.1)
  (indent-bars-pad-frac 0.1)
  (indent-bars-zigzag nil)
  (indent-bars-color-by-depth
   '(:regexp "outline-\\([0-9]+\\)" :blend 1))
  (indent-bars-highlight-current-depth '(:blend 0.5))
  (indent-bars-display-on-blank-lines t)
  (indent-bars-treesit-support t))

;; Preview color literals in programming and markup buffers, without making
;; the color indicators interactive.
(use-package colorful-mode
  :ensure (:host github
           :repo "DevelopmentCool2449/colorful-mode"
           :wait t)
  :custom
  (colorful-allow-mouse-clicks nil)
  (colorful-use-prefix nil)
  :hook ((prog-mode . colorful-mode)
         (org-mode . colorful-mode)
         (markdown-mode . colorful-mode)
         (markdown-ts-mode . colorful-mode)
         (tex-mode . colorful-mode)
         (latex-mode . colorful-mode)
         (typst-mode . colorful-mode)
         (typst-ts-mode . colorful-mode)
         (html-mode . colorful-mode)
         (mhtml-mode . colorful-mode)
         (css-mode . colorful-mode)
         (scss-mode . colorful-mode)
         (web-mode . colorful-mode)))

;; Pulse the destination line after jumps, including Flash and Consult jumps.
(use-package pulsar
  :ensure (:host github
           :repo "protesilaos/pulsar"
           :wait t)
  :custom
  (pulsar-pulse-on-window-change nil)
  :config
  (dolist (function '(flash-evil-jump
                      flash-action
                      flash-char-find
                      flash-char-find-to
                      flash-char-find-backward
                      flash-char-find-to-backward))
    (add-to-list 'pulsar-pulse-functions function))
  (pulsar-global-mode 1)
  ;; Flash exposes a dedicated hook for jumps that land in another buffer or
  ;; window; defer registration until Flash itself is loaded.
  (with-eval-after-load 'flash
    (add-hook 'flash-after-jump-hook #'pulsar-pulse-line))
  ;; Consult runs this hook after selecting a candidate and moving point.
  (with-eval-after-load 'consult
    (add-hook 'consult-after-jump-hook #'pulsar-pulse-line)
    (add-hook 'consult-after-jump-hook #'pulsar-reveal-entry)))


(provide 'sov-ui)
;;; sov-ui.el ends here
