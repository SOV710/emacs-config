;;; sov-lang-qml.el --- QML Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'qml
 '((:language qmljs
    :url "https://github.com/yuja/tree-sitter-qmljs"
    :fallback qml-mode
    :ts-mode qml-ts-mode
    :patterns ("\\.qml\\'"))))

(provide 'sov-lang-qml)
;;; sov-lang-qml.el ends here
