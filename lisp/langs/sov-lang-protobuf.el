;;; sov-lang-protobuf.el --- Protocol Buffers Tree-sitter support -*- lexical-binding: t; -*-

(require 'sov-treesit)

(defgroup protobuf-ts nil
  "Protocol Buffers support powered by Tree-sitter."
  :group 'languages)

(defcustom protobuf-ts-mode-indent-offset 2
  "Number of spaces for each Protocol Buffers indentation step."
  :type 'integer
  :safe #'integerp
  :group 'protobuf-ts)

(defvar protobuf-ts-mode--syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    table)
  "Syntax table used by `protobuf-ts-mode'.")

(defvar protobuf-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'proto
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'proto
   :feature 'keyword
   '(["extend" "extensions" "oneof" "option" "reserved" "syntax" "to"
      "enum" "service" "message" "rpc" "returns" "optional" "repeated"
      "required" "package" "import"] @font-lock-keyword-face)

   :language 'proto
   :feature 'type
   '([(key_type) (type) (message_name) (enum_name) (service_name)
      (message_or_enum_type)] @font-lock-type-face)

   :language 'proto
   :feature 'function
   '((rpc_name) @font-lock-function-name-face)

   :language 'proto
   :feature 'constant
   '((enum_field (identifier) @font-lock-constant-face)
     [(true) (false)] @font-lock-constant-face)

   :language 'proto
   :feature 'string
   '((string) @font-lock-string-face)

   :language 'proto
   :feature 'number
   '([(int_lit) (float_lit)] @font-lock-number-face)

   :language 'proto
   :feature 'bracket
   '(["(" ")" "[" "]" "{" "}" "<" ">"] @font-lock-bracket-face)

   :language 'proto
   :feature 'delimiter
   '([";" ","] @font-lock-delimiter-face)

   :language 'proto
   :feature 'operator
   '(("=") @font-lock-operator-face))
  "Tree-sitter font-lock settings used by `protobuf-ts-mode'.")

(defvar protobuf-ts-mode--indent-rules
  `((proto
     ((node-is "}") parent-bol 0)
     ((parent-is "message_body") parent-bol protobuf-ts-mode-indent-offset)
     ((parent-is "enum_body") parent-bol protobuf-ts-mode-indent-offset)
     ((parent-is "service") parent-bol protobuf-ts-mode-indent-offset)))
  "Tree-sitter indentation rules used by `protobuf-ts-mode'.")

;;;###autoload
(define-derived-mode protobuf-ts-mode prog-mode "Proto"
  "Major mode for Protocol Buffers, powered by Tree-sitter."
  :group 'protobuf-ts
  :syntax-table protobuf-ts-mode--syntax-table
  (setq-local comment-start "// ")
  (setq-local comment-start-skip "\\(?://+\\|/\\*+\\)\\s *")
  (setq-local comment-end "")
  (setq-local electric-indent-chars
              (append "{};" electric-indent-chars))
  ;; Keep direct/manual activation harmless before `:TSInstall protobuf'.
  ;; The lazy dispatcher only selects this mode once the grammar is ready.
  (when (treesit-ready-p 'proto t)
    (setq-local treesit-primary-parser (treesit-parser-create 'proto))
    (setq-local treesit-simple-indent-rules protobuf-ts-mode--indent-rules)
    (setq-local treesit-font-lock-settings protobuf-ts-mode--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment keyword string)
                  (constant function number type)
                  (bracket delimiter operator)))
    (treesit-major-mode-setup)))

(sov-treesit-register-language
 'protobuf
 '((:language proto
    :url "https://github.com/treywood/tree-sitter-proto"
    :fallback protobuf-mode
    :ts-mode protobuf-ts-mode
    :patterns ("\\.proto\\'"))))

;; Emacs derives fenced-code modes from the language tag, but `proto' and
;; `protobuf-ts-mode' do not share the conventional basename.
(with-eval-after-load 'markdown-ts-mode
  (setf (alist-get 'proto markdown-ts-code-block-modes)
        '(protobuf-ts-mode)))

(provide 'sov-lang-protobuf)
;;; sov-lang-protobuf.el ends here
