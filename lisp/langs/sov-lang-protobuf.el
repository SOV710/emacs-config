;;; sov-lang-protobuf.el --- Protocol Buffers Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'protobuf
 '((:language proto
    :url "https://github.com/treywood/tree-sitter-proto"
    :fallback protobuf-mode
    :ts-mode protobuf-ts-mode
    :patterns ("\\.proto\\'"))))

(provide 'sov-lang-protobuf)
;;; sov-lang-protobuf.el ends here
