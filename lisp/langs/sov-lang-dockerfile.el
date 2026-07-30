;;; sov-lang-dockerfile.el --- Dockerfile Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'dockerfile
 '((:language dockerfile
    :url "https://github.com/camdencheek/tree-sitter-dockerfile"
    :fallback dockerfile-mode
    :ts-mode dockerfile-ts-mode
    :patterns ("\\(?:Dockerfile\\(?:\\..*\\)?\\|\\.[Dd]ockerfile\\)\\'"))))

(provide 'sov-lang-dockerfile)
;;; sov-lang-dockerfile.el ends here
