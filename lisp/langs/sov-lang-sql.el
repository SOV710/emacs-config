;;; sov-lang-sql.el --- SQL Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'sql
 '((:language sql
    :url "https://github.com/derekstride/tree-sitter-sql"
    :revision "gh-pages"
    :fallback sql-mode
    :ts-mode sql-ts-mode
    :patterns ("\\.sql\\'"))))

(provide 'sov-lang-sql)
;;; sov-lang-sql.el ends here
