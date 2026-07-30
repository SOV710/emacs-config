;;; sov-treesit.el --- Native Tree-sitter grammar management -*- lexical-binding: t; -*-

;; This module owns grammar recipes and the lifecycle commands for Emacs's
;; built-in `treesit' integration.  Language modules only declare their
;; grammar metadata here; they do not download or compile grammars at startup.

(require 'cl-lib)
(require 'subr-x)
(require 'treesit)


;;; Configuration

(defgroup sov-treesit nil
  "Native Tree-sitter support for this configuration."
  :group 'treesit)

(defcustom sov-treesit-grammar-directory
  (locate-user-emacs-file "tree-sitter")
  "Directory managed by the Tree-sitter install commands."
  :type 'directory
  :group 'sov-treesit)

(defvar sov-treesit--languages nil
  "Alist mapping configured language groups to grammar specifications.")

(defvar sov-treesit--grammar-index nil
  "Alist mapping grammar symbols to their registered specifications.")

(defvar-local sov-treesit--generic-language nil
  "Language parsed by `sov-treesit-generic-mode' in the current buffer.")


;;; Registration

(defun sov-treesit--resolve-revision (revision)
  "Resolve REVISION, evaluating a deferred revision function when necessary."
  (if (functionp revision) (funcall revision) revision))

(defun sov-treesit--normalize-spec (group spec)
  "Validate and return a copy of GROUP's grammar SPEC."
  (let ((language (plist-get spec :language))
        (url (plist-get spec :url))
        (fallback (plist-get spec :fallback))
        (ts-mode (plist-get spec :ts-mode))
        (patterns (plist-get spec :patterns)))
    (unless (symbolp language)
      (error "Tree-sitter grammar in %s has no symbol :language" group))
    (unless (stringp url)
      (error "Tree-sitter grammar %s has no string :url" language))
    (unless (or (null fallback) (symbolp fallback))
      (error "Tree-sitter grammar %s has an invalid :fallback" language))
    (unless (or (null ts-mode) (symbolp ts-mode))
      (error "Tree-sitter grammar %s has an invalid :ts-mode" language))
    (unless (or (null patterns)
                (and (listp patterns) (cl-every #'stringp patterns)))
      (error "Tree-sitter grammar %s has invalid :patterns" language))
    (let ((normalized (copy-sequence spec)))
      (plist-put normalized :group group)
      normalized)))

(defun sov-treesit--register-source (spec)
  "Register SPEC in `treesit-language-source-alist'."
  (let* ((language (plist-get spec :language))
         (url (plist-get spec :url))
         (revision (sov-treesit--resolve-revision
                    (plist-get spec :revision)))
         (source-dir (plist-get spec :source-dir))
         (cc (plist-get spec :cc))
         (c++ (plist-get spec :c++)))
    (setq treesit-language-source-alist
          (assq-delete-all language treesit-language-source-alist))
    (push (list language url revision source-dir cc c++)
          treesit-language-source-alist)))

(defun sov-treesit--dispatcher-name (language)
  "Return the dispatcher symbol for grammar LANGUAGE."
  (intern (format "sov-treesit-%s-mode" language)))

(defun sov-treesit--register-auto-mode (spec)
  "Register SPEC's file patterns with a lazy major-mode dispatcher."
  (when-let* ((patterns (plist-get spec :patterns))
              (language (plist-get spec :language)))
    (let ((dispatcher (sov-treesit--dispatcher-name language)))
      (let ((captured-spec spec))
        (fset dispatcher
              (lambda ()
                (interactive)
                (sov-treesit--activate-spec captured-spec))))
      (dolist (pattern patterns)
        (add-to-list 'auto-mode-alist (cons pattern dispatcher))))))

(defun sov-treesit-register-language (group grammars)
  "Register GROUP and its GRAMMARS with native Tree-sitter.

Each grammar is a plist with required `:language' and `:url' fields.  Optional
`:revision', `:source-dir', `:fallback', `:ts-mode', and `:patterns' fields
describe installation and activation behavior."
  (unless (symbolp group)
    (error "Tree-sitter group must be a symbol: %S" group))
  (unless (listp grammars)
    (error "Tree-sitter grammars for %s must be a list" group))
  (let ((normalized (mapcar (lambda (spec)
                              (sov-treesit--normalize-spec group spec))
                            grammars)))
    (setq sov-treesit--languages
          (assq-delete-all group sov-treesit--languages))
    (push (cons group normalized) sov-treesit--languages)
    (dolist (spec normalized)
      (let ((language (plist-get spec :language)))
        (setq sov-treesit--grammar-index
              (assq-delete-all language sov-treesit--grammar-index))
        (push (cons language spec) sov-treesit--grammar-index)
        (sov-treesit--register-source spec)
        (sov-treesit--register-auto-mode spec)))
    group))


;;; Mode activation

(defun sov-treesit--grammar-available-p (language)
  "Return non-nil when LANGUAGE can be loaded by the current Emacs process."
  (car (treesit-language-available-p language t)))

(defun sov-treesit--ensure-parser (language)
  "Create or reuse a parser for LANGUAGE in the current buffer when available."
  (when (treesit-ready-p language t)
    (condition-case err
        (treesit-parser-create language)
      (error
       (display-warning
        'sov-treesit
        (format "Could not create the %s Tree-sitter parser: %s"
                language (error-message-string err))
        :warning)))))

(define-derived-mode sov-treesit-generic-mode prog-mode "Tree-sitter"
  "Parser-only fallback for a grammar without an installed major mode.")

(defun sov-treesit--activate-generic-mode (language)
  "Activate a parser-only mode for LANGUAGE."
  (sov-treesit-generic-mode)
  (setq-local sov-treesit--generic-language language)
  (setq-local mode-name (format "Tree-sitter[%s]" language))
  (sov-treesit--ensure-parser language))

(defun sov-treesit--activate-spec (spec)
  "Activate the most capable mode available for grammar SPEC."
  (let ((language (plist-get spec :language))
        (ts-mode (plist-get spec :ts-mode))
        (fallback (plist-get spec :fallback)))
    (cond
     ((and ts-mode (fboundp ts-mode) (treesit-ready-p language t))
      (funcall ts-mode))
     ((and fallback (fboundp fallback))
      (funcall fallback)
      (sov-treesit--ensure-parser language))
     ((treesit-ready-p language t)
      (sov-treesit--activate-generic-mode language))
     (t
      (fundamental-mode)))))

(defun sov-treesit--spec-matches-current-buffer-p (spec)
  "Return non-nil when SPEC's fallback applies to the current buffer."
  (let ((patterns (plist-get spec :patterns))
        (name (or buffer-file-name (buffer-name))))
    (or (null patterns)
        (cl-some (lambda (pattern) (string-match-p pattern name)) patterns))))

(defun sov-treesit--enable-parser-in-fallback-mode ()
  "Add parsers when a configured fallback major mode is selected manually."
  (dolist (entry sov-treesit--grammar-index)
    (let* ((spec (cdr entry))
           (fallback (plist-get spec :fallback)))
      (when (and fallback
                 (eq major-mode fallback)
                 (sov-treesit--spec-matches-current-buffer-p spec))
        (sov-treesit--ensure-parser (plist-get spec :language))))))

(add-hook 'after-change-major-mode-hook
          #'sov-treesit--enable-parser-in-fallback-mode)


;;; Selection and status

(defun sov-treesit-language-groups ()
  "Return configured Tree-sitter language group symbols in display order."
  (sort (mapcar #'car sov-treesit--languages)
        (lambda (left right)
          (string< (symbol-name left) (symbol-name right)))))

(defun sov-treesit-grammar-languages ()
  "Return configured Tree-sitter grammar symbols in display order."
  (sort (mapcar #'car sov-treesit--grammar-index)
        (lambda (left right)
          (string< (symbol-name left) (symbol-name right)))))

(defun sov-treesit--selection-candidates ()
  "Return completion candidates accepted by Tree-sitter commands."
  (append '("all")
          (mapcar #'symbol-name (sov-treesit-language-groups))
          (mapcar #'symbol-name (sov-treesit-grammar-languages))))

(defun sov-treesit--parse-selection (selection)
  "Resolve group or grammar names in SELECTION to grammar specifications."
  (let ((names (cond
                ((null selection) nil)
                ((listp selection) selection)
                (t (list selection))))
        specs)
    (if (or (null names)
            (member "all" names)
            (memq 'all names))
        (setq specs (mapcar #'cdr sov-treesit--grammar-index))
      (dolist (name names)
        (let* ((symbol (if (symbolp name) name (intern name)))
               (group (assq symbol sov-treesit--languages))
               (grammar (assq symbol sov-treesit--grammar-index)))
          (cond
           (group (setq specs (append specs (cdr group))))
           (grammar (push (cdr grammar) specs))
           (t
            (user-error "Unknown Tree-sitter language: %s" name))))))
    (let (seen result)
      (dolist (spec specs)
        (let ((language (plist-get spec :language)))
          (unless (memq language seen)
            (push language seen)
            (push spec result))))
      (nreverse result))))

(defun sov-treesit--ex-selection ()
  "Return the language selection written after an Evil Ex command."
  (when (and (boundp 'evil-called-from-ex-p)
             evil-called-from-ex-p
             (boundp 'evil-ex-argument))
    (split-string (or evil-ex-argument "") "[[:space:],]+" t)))

(defun sov-treesit--read-selection ()
  "Read a group or grammar selection, allowing an empty answer for all."
  ;; An empty Ex argument is deliberately nil: it means all grammars, rather
  ;; than a request to fall through to minibuffer completion.
  (if (and (boundp 'evil-called-from-ex-p)
           evil-called-from-ex-p
           (boundp 'evil-ex-argument))
      (sov-treesit--ex-selection)
    (completing-read-multiple
     "Tree-sitter languages (empty for all): "
     (sov-treesit--selection-candidates) nil t)))

(defun sov-treesit--library-path (language)
  "Return this configuration's managed shared-library path for LANGUAGE."
  (let ((suffix (or (car dynamic-library-suffixes) ".so")))
    (expand-file-name (format "libtree-sitter-%s%s" language suffix)
                      sov-treesit-grammar-directory)))

(defun sov-treesit--integration-status (spec)
  "Return a concise activation description for SPEC."
  (let ((ts-mode (plist-get spec :ts-mode))
        (fallback (plist-get spec :fallback)))
    (cond
     ((and ts-mode (fboundp ts-mode))
      (format "native %s" ts-mode))
     ((and fallback (fboundp fallback))
      (format "parser + %s" fallback))
     (fallback
      (format "parser fallback %s unavailable" fallback))
     (t "parser-only fallback"))))

(defun sov-treesit--status-lines (selection)
  "Return display lines describing grammar specs selected by SELECTION."
  (let ((specs (sov-treesit--parse-selection selection)))
    (append
     (list (format "Directory: %s" sov-treesit-grammar-directory)
           (format "Git: %s    C compiler: %s    C++ compiler: %s"
                   (if (executable-find "git") "found" "missing")
                   (if (or (executable-find "cc") (executable-find "gcc"))
                       "found" "missing")
                   (if (or (executable-find "c++") (executable-find "g++"))
                       "found" "missing"))
           ""
           (format "%-14s %-18s %-11s %s"
                   "Group" "Grammar" "Library" "Integration")
           (make-string 78 ?-))
     (mapcar
      (lambda (spec)
        (let* ((language (plist-get spec :language))
               (path (sov-treesit--library-path language))
               (library (cond
                         ((file-exists-p path) "managed")
                         ((sov-treesit--grammar-available-p language) "external")
                         (t "missing"))))
          (format "%-14s %-18s %-11s %s"
                  (plist-get spec :group) language library
                  (sov-treesit--integration-status spec))))
      specs))))


;;; Lifecycle commands

(defun sov-treesit--report-install-result (operation installed skipped failures)
  "Report OPERATION results for INSTALLED, SKIPPED, and FAILURES."
  (let ((summary
         (string-join
          (delq nil
                (list (when installed
                        (format "installed %s"
                                (mapconcat #'symbol-name
                                           (nreverse installed) ", ")))
                      (when skipped
                        (format "already available %s"
                                (mapconcat #'symbol-name
                                           (nreverse skipped) ", ")))
                      (when failures
                        (format "failed %s"
                                (mapconcat (lambda (failure)
                                             (format "%s (%s)"
                                                     (car failure) (cdr failure)))
                                           (nreverse failures) "; ")))))
          "; ")))
    (if failures
        (display-warning 'sov-treesit
                         (format "Tree-sitter %s: %s" operation summary)
                         :warning)
      (message "Tree-sitter %s: %s" operation (or summary "nothing to do")))))

(defun sov-treesit--install-selection (selection update)
  "Install SELECTED grammars, forcing rebuilds when UPDATE is non-nil."
  (let (installed skipped failures)
    (dolist (spec (sov-treesit--parse-selection selection))
      (let ((language (plist-get spec :language)))
        (if (and (not update) (sov-treesit--grammar-available-p language))
            (push language skipped)
          (condition-case err
              (progn
                (treesit-install-language-grammar
                 language sov-treesit-grammar-directory)
                (if (sov-treesit--grammar-available-p language)
                    (push language installed)
                  (push (cons language "library is not loadable") failures)))
            (error
             (push (cons language (error-message-string err)) failures))))))
    (sov-treesit--report-install-result
     (if update "update" "install") installed skipped failures)))

(defun sov-treesit-install (&optional selection)
  "Install missing Tree-sitter grammars from registered sources.

Interactively, an empty selection installs every configured grammar.  From
Evil Ex, use `:TSInstall rust typescript' or omit arguments for all."
  (interactive (list (sov-treesit--read-selection)))
  (sov-treesit--install-selection selection nil))

(defun sov-treesit-update (&optional selection)
  "Rebuild selected Tree-sitter grammars from their registered sources."
  (interactive (list (sov-treesit--read-selection)))
  (sov-treesit--install-selection selection t))

(defun sov-treesit-clear (&optional selection force)
  "Delete managed shared libraries for SELECTED Tree-sitter grammars.

Only files in `sov-treesit-grammar-directory' are removed.  A restarted Emacs
is required to unload a grammar that has already been loaded in this process.
With prefix FORCE, do not ask for confirmation."
  (interactive (list (sov-treesit--read-selection) current-prefix-arg))
  (let ((specs (sov-treesit--parse-selection selection)))
    (when (or force
              (yes-or-no-p
               (format "Delete %d managed Tree-sitter grammar(s)? "
                       (length specs))))
      (let (deleted failures)
        (dolist (spec specs)
          (let* ((language (plist-get spec :language))
                 (path (sov-treesit--library-path language)))
            (dolist (candidate (list path (concat path ".old")))
              (when (file-exists-p candidate)
                (condition-case err
                    (progn
                      (delete-file candidate)
                      (push language deleted))
                  (error
                   (push (cons language (error-message-string err))
                         failures)))))))
        (if failures
            (display-warning
             'sov-treesit
             (format "Tree-sitter clear failed: %s"
                     (mapconcat (lambda (failure)
                                  (format "%s (%s)" (car failure) (cdr failure)))
                                (nreverse failures) "; "))
             :warning)
          (message "Tree-sitter clear: %s"
                   (if deleted
                       (mapconcat #'symbol-name (delete-dups deleted) ", ")
                     "no managed libraries found")))))))

(defun sov-treesit-status (&optional selection)
  "Display Tree-sitter installation and activation status for SELECTION."
  (interactive (list (sov-treesit--read-selection)))
  (let ((buffer (get-buffer-create "*SOV Tree-sitter*")))
    (with-current-buffer buffer
      (setq buffer-read-only nil)
      (erase-buffer)
      (insert (string-join (sov-treesit--status-lines selection) "\n"))
      (insert "\n")
      (goto-char (point-min))
      (special-mode))
    (display-buffer buffer)))


;;; Evil Ex commands

(defun sov-treesit--define-evil-ex-commands ()
  "Expose Tree-sitter lifecycle commands through Evil Ex when available."
  (when (fboundp 'evil-ex-define-cmd)
    (evil-ex-define-cmd "TSInstall" #'sov-treesit-install)
    (evil-ex-define-cmd "TSUpdate" #'sov-treesit-update)
    (evil-ex-define-cmd "TSClear" #'sov-treesit-clear)
    (evil-ex-define-cmd "TSStatus" #'sov-treesit-status)))

(with-eval-after-load 'evil-ex
  (sov-treesit--define-evil-ex-commands))


(provide 'sov-treesit)
;;; sov-treesit.el ends here
