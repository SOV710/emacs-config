;;; sov-lang-typescript.el --- TypeScript Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'typescript
 '((:language javascript
    :url "https://github.com/tree-sitter/tree-sitter-javascript"
    :fallback js-mode
    :ts-mode js-ts-mode
    :patterns ("\\.\\(?:[cm]?js\\|jsx\\)\\'"))
   (:language typescript
    :url "https://github.com/tree-sitter/tree-sitter-typescript"
    :source-dir "typescript/src"
    :fallback typescript-mode
    :ts-mode typescript-ts-mode
    :patterns ("\\.ts\\'"))
   (:language tsx
    :url "https://github.com/tree-sitter/tree-sitter-typescript"
    :source-dir "tsx/src"
    :fallback typescript-tsx-mode
    :ts-mode tsx-ts-mode
    :patterns ("\\.tsx\\'"))
   (:language jsdoc
    :url "https://github.com/tree-sitter/tree-sitter-jsdoc")))

(provide 'sov-lang-typescript)
;;; sov-lang-typescript.el ends here
