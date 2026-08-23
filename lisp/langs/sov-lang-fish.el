;;; sov-lang-fish.el --- Fish Tree-sitter configuration -*- lexical-binding: t; -*-

(require 'sov-treesit)

(defgroup fish-ts nil
  "Fish shell support powered by Tree-sitter."
  :group 'languages)

(defcustom fish-ts-mode-indent-offset 4
  "Number of spaces for each Fish indentation step."
  :type 'integer
  :safe #'integerp
  :group 'fish-ts)

(defvar fish-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?# "< b" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)
    table)
  "Syntax table used by `fish-ts-mode'.")

(defvar fish-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'fish
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'fish
   :feature 'string
   '([(double_quote_string) (single_quote_string)] @font-lock-string-face)

   :language 'fish
   :feature 'escape
   :override t
   '((escape_sequence) @font-lock-escape-face)

   :language 'fish
   :feature 'number
   '([(integer) (float)] @font-lock-number-face)

   :language 'fish
   :feature 'keyword
   '(["switch" "case" "in" "begin" "function" "if" "else" "end"
      "while" "for" "not" "!" "and" "or" "return"
      (break) (continue)] @font-lock-keyword-face)

   :language 'fish
   :feature 'function
   '((function_definition
      name: [(word) (concatenation)] @font-lock-function-name-face)
     (command name: (word) @font-lock-function-call-face))

   :language 'fish
   :feature 'variable
   :override t
   '((for_statement
      variable: (variable_name) @font-lock-variable-name-face)
     (variable_expansion) @font-lock-variable-use-face)

   :language 'fish
   :feature 'operator
   '(["&&" "||" "|" "&|" "2>|" "&" ".."
      (direction) (stream_redirect)] @font-lock-operator-face)

   :language 'fish
   :feature 'bracket
   '(["(" ")" "[" "]" "{" "}"] @font-lock-bracket-face)

   :language 'fish
   :feature 'delimiter
   '(["," ";"] @font-lock-delimiter-face))
  "Tree-sitter font-lock settings used by `fish-ts-mode'.")

(defvar fish-ts-mode--indent-rules
  `((fish
     ((node-is "end") parent-bol 0)
     ((match "else" "else_clause") grand-parent 0)
     ((match "else" "else_if_clause") grand-parent 0)
     ((match "case" "case_clause") grand-parent fish-ts-mode-indent-offset)
     ((parent-is "case_clause") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "else_clause") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "else_if_clause") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "begin_statement") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "for_statement") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "function_definition") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "if_statement") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "switch_statement") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "while_statement") parent-bol fish-ts-mode-indent-offset)
     ((parent-is "command_substitution") parent-bol fish-ts-mode-indent-offset)))
  "Tree-sitter indentation rules used by `fish-ts-mode'.")

(defun fish-ts-mode--defun-name (node)
  "Return the function name belonging to Fish NODE."
  (when-let* ((name (treesit-node-child-by-field-name node "name")))
    (treesit-node-text name t)))

;;;###autoload
(define-derived-mode fish-ts-mode prog-mode "Fish"
  "Major mode for Fish shell scripts, powered by Tree-sitter."
  :group 'fish-ts
  :syntax-table fish-ts-mode--syntax-table
  (setq-local comment-start "# ")
  (setq-local comment-start-skip "#+[ \t]*")
  (setq-local comment-end "")
  ;; Direct activation remains harmless before `:TSInstall fish'.
  (when (treesit-ready-p 'fish t)
    (setq-local treesit-primary-parser (treesit-parser-create 'fish))
    (setq-local treesit-simple-indent-rules fish-ts-mode--indent-rules)
    (setq-local treesit-font-lock-settings fish-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment string)
                  (keyword function variable)
                  (escape number operator)
                  (bracket delimiter)))
    (setq-local treesit-defun-type-regexp "\\`function_definition\\'")
    (setq-local treesit-defun-name-function #'fish-ts-mode--defun-name)
    (treesit-major-mode-setup)))

(sov-treesit-register-language
 'fish
 '((:language fish
    :url "https://github.com/ram02z/tree-sitter-fish"
    :fallback fish-mode
    :ts-mode fish-ts-mode
    :patterns ("\\.fish\\'"))))

(provide 'sov-lang-fish)
;;; sov-lang-fish.el ends here
