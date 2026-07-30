;;; sov-lang-json.el --- JSON Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'json
 '((:language json
    :url "https://github.com/tree-sitter/tree-sitter-json"
    :fallback js-json-mode
    :ts-mode json-ts-mode
    :patterns ("\\.json\\'"))))

(provide 'sov-lang-json)
;;; sov-lang-json.el ends here
