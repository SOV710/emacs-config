;;; sov-lang-task.el --- Taskwarrior Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(sov-treesit-register-language
 'task
 '((:language taskwarrior
    :url "https://github.com/SOV710/tree-sitter-taskwarrior"
    :revision "main"
    :fallback conf-mode
    :ts-mode taskwarrior-ts-mode
    :patterns ("/\\.taskrc\\'" "taskrc\\'"))))

(provide 'sov-lang-task)
;;; sov-lang-task.el ends here
