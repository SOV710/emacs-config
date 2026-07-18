;;; sov-lang-markdown.el --- Markdown language configuration -*- lexical-binding: t; -*-

(defun sov-lang-markdown-mode ()
  "Use Tree-sitter Markdown when both grammars are ready, otherwise fall back."
  (interactive)
  (if (and (fboundp 'treesit-ready-p)
           (treesit-ready-p 'markdown t)
           (treesit-ready-p 'markdown-inline t)
           (fboundp 'markdown-ts-mode))
      (markdown-ts-mode)
    (markdown-mode)))

(defun sov-lang-markdown--protect-code-blocks-from-fill ()
  "Prevent `auto-fill-mode' from wrapping fenced code blocks."
  (add-hook 'fill-nobreak-predicate
            #'markdown-code-block-at-point-p nil t))

;; Markdown mode supplies editing commands and font-locking; its optional
;; Tree-sitter mode is used when the installed version provides it.
(use-package markdown-mode
  :ensure (:host github
           :repo "jrblevin/markdown-mode"
           :wait t)
  :mode (("\\.md\\'" . sov-lang-markdown-mode)
         ("\\.markdown\\'" . sov-lang-markdown-mode)
         ("\\.mdown\\'" . sov-lang-markdown-mode)
         ("\\.mkdn\\'" . sov-lang-markdown-mode))
  :custom
  (markdown-italic-underscore t)
  (markdown-fontify-code-blocks-natively t)
  (markdown-fontify-whole-heading-line t)
  (markdown-enable-math t)
  (markdown-enable-highlighting-syntax t)
  (markdown-hide-urls nil)
  (markdown-mouse-follow-link nil)
  :hook ((markdown-mode . visual-line-mode)
         (markdown-mode . turn-on-auto-fill)
         (markdown-mode . sov-lang-markdown--protect-code-blocks-from-fill)))

;; Doom uses GFM mode for README files because repositories commonly rely on
;; GitHub-specific tables, task lists, and fenced-code conventions.
(add-to-list 'auto-mode-alist '("/README\\(?:\\.md\\)?\\'" . gfm-mode))

;; Emacs 31 provides this mode itself.  On Emacs 30, install the same focused
;; compatibility package Doom uses rather than pretending `markdown-mode'
;; consumes Tree-sitter grammars directly.
(use-package markdown-ts-mode
  :ensure (:host github
           :repo "LionyxML/markdown-ts-mode"
           :wait t)
  :commands markdown-ts-mode
  :hook ((markdown-ts-mode . visual-line-mode)
         (markdown-ts-mode . turn-on-auto-fill)))

;; Register Markdown Tree-sitter grammars when the built-in `treesit' package
;; is available.  Install them interactively with `treesit-install-language-grammar'.
(when (require 'treesit nil t)
  (let* ((url "https://github.com/tree-sitter-grammars/tree-sitter-markdown")
         ;; Grammar v0.5 requires Tree-sitter ABI 15 or newer.
         (revision (if (< (treesit-library-abi-version) 15)
                       "v0.4.1"
                     "v0.5.1")))
    (add-to-list 'treesit-language-source-alist
                 `(markdown ,url ,revision "tree-sitter-markdown/src"))
    (add-to-list 'treesit-language-source-alist
                 `(markdown-inline ,url ,revision
                                   "tree-sitter-markdown-inline/src"))))


(provide 'sov-lang-markdown)
;;; sov-lang-markdown.el ends here
