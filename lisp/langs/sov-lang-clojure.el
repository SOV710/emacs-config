;;; sov-lang-clojure.el --- Clojure Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'clojure
 '((:language clojure
    :url "https://github.com/sogaiu/tree-sitter-clojure"
    :fallback clojure-mode
    :ts-mode clojure-ts-mode
    :patterns ("\\.clj\\(?:c\\|s\\|d\\)?\\'"))))

(provide 'sov-lang-clojure)
;;; sov-lang-clojure.el ends here
