;;; sov-lang-bash.el --- Bash Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'bash
 '((:language bash
    :url "https://github.com/tree-sitter/tree-sitter-bash"
    :fallback sh-mode
    :ts-mode bash-ts-mode
    :patterns ("\\.\\(?:ba\\)?sh\\'"
               "/\\.bash\\(?:rc\\|_profile\\)?\\'"))))

(provide 'sov-lang-bash)
;;; sov-lang-bash.el ends here
