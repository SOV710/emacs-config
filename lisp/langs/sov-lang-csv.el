;;; sov-lang-csv.el --- CSV Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'csv
 '((:language csv
    :url "https://github.com/amaanq/tree-sitter-csv"
    :source-dir "csv/src"
    :fallback csv-mode
    :ts-mode csv-ts-mode
    :patterns ("\\.csv\\'"))))

(provide 'sov-lang-csv)
;;; sov-lang-csv.el ends here
