;;; sov-lang-rust.el --- Rust Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'rust
 '((:language rust
    :url "https://github.com/tree-sitter/tree-sitter-rust"
    :fallback rust-mode
    :ts-mode rust-ts-mode
    :patterns ("\\.rs\\'"))))

(provide 'sov-lang-rust)
;;; sov-lang-rust.el ends here
