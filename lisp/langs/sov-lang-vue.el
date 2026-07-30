;;; sov-lang-vue.el --- Vue Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'vue
 '((:language vue
    :url "https://github.com/tree-sitter-grammars/tree-sitter-vue"
    :revision "main"
    :fallback vue-mode
    :ts-mode vue-ts-mode
    :patterns ("\\.vue\\'"))))

(provide 'sov-lang-vue)
;;; sov-lang-vue.el ends here
