;;; sov-lang-dart.el --- Dart Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'dart
 '((:language dart
    :url "https://github.com/UserNobody14/tree-sitter-dart"
    :fallback dart-mode
    :ts-mode dart-ts-mode
    :patterns ("\\.dart\\'"))))

(provide 'sov-lang-dart)
;;; sov-lang-dart.el ends here
