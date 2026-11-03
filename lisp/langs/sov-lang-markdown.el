;;; sov-lang-markdown.el --- Markdown language configuration -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'subr-x)
(require 'sov-treesit)
(require 'image)
(require 'yank-media)
(require 'url-util)

(declare-function markdown-table-wrap "markdown-table-wrap"
                  (text width &optional max-cell-height strip-markup compact))
(declare-function markdown-table-wrap-inside-code-fence-p
                  "markdown-table-wrap" (pos))
(declare-function markdown-table-wrap-unwrap "markdown-table-wrap" (text))
(declare-function markdown-code-block-at-point-p "markdown-mode" ())
(declare-function markdown-insert-inline-image "markdown-mode" (text url &optional title))
(declare-function markdown-display-inline-images "markdown-mode" ())
(declare-function projectile-project-root "projectile" (&optional dir))
(declare-function evil-next-line-first-non-blank "evil-commands" (count))
(declare-function evil-previous-line-first-non-blank "evil-commands" (count))

(defvar markdown-inline-image-overlays)
(defvar markdown-display-remote-images)
(defvar markdown-max-image-size)

;;; Clipboard images

(defgroup sov-markdown-images nil
  "External image files and inline previews in Markdown buffers."
  :group 'text)

(defcustom sov-markdown-image-directory "assets/"
  "Image directory relative to the Projectile root, or the Markdown file.
When the Markdown file is outside a project, use its containing directory."
  :type 'string
  :group 'sov-markdown-images)

(defcustom sov-markdown-image-name-format "%Y%m%d-%H%M%S-%6N"
  "Time format used when the image name is left empty."
  :type 'string
  :group 'sov-markdown-images)

(defcustom sov-markdown-image-scale 1.0
  "Preferred image scale before fitting previews to the available area.
The default 1.0 keeps small images at their original size."
  :type 'number
  :group 'sov-markdown-images)

(defcustom sov-markdown-image-zoom-factor 1.1
  "Factor used by manual image enlargement; shrinking uses its reciprocal."
  :type 'number
  :group 'sov-markdown-images)

(defcustom sov-markdown-image-preview-program "magick"
  "ImageMagick executable used to rasterize previews in memory.
No preview files or disk pixel caches are created.  If unavailable, keep
Emacs's ordinary image display.  The original image is never modified."
  :type 'string
  :group 'sov-markdown-images)

(defun sov-markdown--image-window-limits ()
  "Snapshot the selected window's usable width, half-height, and font width."
  (let* ((window (selected-window))
         (character-width (window-font-width window)))
    (list (max 1 (floor (- (window-body-width window t)
                           (if display-line-numbers
                               (line-number-display-width t)
                             0)
                           character-width)))
          (max 1 (floor (/ (window-body-height window t) 2)))
          character-width)))

(defun sov-markdown--unscaled-image (image)
  "Return a copy of IMAGE with only its original dimensions and scale 1."
  (let ((original (copy-tree image)))
    (dolist (property '(:width :height :max-width :max-height))
      (setf (image-property original property) nil))
    (setf (image-property original :scale) 1.0)
    original))

(defun sov-markdown--image-source (overlay)
  "Return OVERLAY's original image descriptor, independent of its preview."
  (or (overlay-get overlay 'sov-markdown-image-source)
      (let ((source (sov-markdown--unscaled-image (overlay-get overlay 'display))))
        (overlay-put overlay 'sov-markdown-image-source source)
        source)))

(defun sov-markdown--image-native-size (overlay)
  "Return and cache the original pixel dimensions of OVERLAY's image."
  (or (overlay-get overlay 'sov-markdown-image-native-size)
      (let* ((displayed (overlay-get overlay 'display))
             (original (sov-markdown--image-source overlay)))
        (unwind-protect
            (let ((size (image-size original t)))
              (unless (and (> (car size) 0) (> (cdr size) 0))
                (user-error "Cannot determine image dimensions"))
              (overlay-put overlay 'sov-markdown-image-native-size size)
              size)
          ;; Measuring a fitted image may load an extra full-resolution copy.
          ;; Keep its dimensions in Lisp, not its decoded pixels in the cache.
          (unless (equal original displayed)
            (image-flush original t))))))

(defun sov-markdown--memory-image-preview (source width height density)
  "Rasterize SOURCE to WIDTH by HEIGHT logical pixels at DENSITY.
Return a PNG descriptor whose bytes stay in memory, or nil if conversion
is unavailable.  DENSITY preserves detail on HiDPI frames."
  (when-let* ((file (image-property source :file))
              ((not (file-remote-p file)))
              ((file-readable-p file))
              (program (executable-find sov-markdown-image-preview-program)))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (let* ((coding-system-for-read 'no-conversion)
             (coding-system-for-write 'no-conversion)
             ;; Read stdin so brackets and leading dashes in filenames are
             ;; never interpreted as ImageMagick options or frame selectors.
             (status (call-process
                      program file '(t nil) nil
                      "-limit" "map" "0" "-limit" "disk" "0"
                      "-limit" "thread" "1" "-[0]" "-resize"
                      (format "%dx%d!" (max 1 (round (* width density)))
                              (max 1 (round (* height density))))
                      "-strip" "png:-")))
        (when (and (eq status 0) (> (buffer-size) 0))
          (create-image (buffer-string) 'png t :scale (/ 1.0 density)))))))

(defun sov-markdown--set-image-scale (overlay scale)
  "Set OVERLAY to SCALE, keeping one rasterized preview in memory."
  (let* ((previous (overlay-get overlay 'display))
         (source (sov-markdown--image-source overlay))
         (size (sov-markdown--image-native-size overlay))
         (width (max 1 (round (* (car size) scale))))
         (height (max 1 (round (* (cdr size) scale))))
         (density (frame-scale-factor))
         (key (list width height density)))
    (unless (equal key (overlay-get overlay 'sov-markdown-image-preview-key))
      (let ((image (or (sov-markdown--memory-image-preview source width height density)
                       (let ((image (copy-tree source)))
                         (setf (image-property image :scale) scale)
                         image))))
        (unless (equal previous image)
          ;; Drop both Emacs's decoded cache entry and the overlay's old bytes.
          ;; Never keep a history of previews for earlier zoom levels.
          (image-flush previous t)
          (overlay-put overlay 'display image))
        (overlay-put overlay 'sov-markdown-image-preview-key key)))
    (overlay-put overlay 'sov-markdown-image-scale scale)
    (sov-markdown--watch-image-preview overlay)))

(defun sov-markdown--fit-image (overlay limits)
  "Fit OVERLAY once to the selected window snapshot LIMITS."
  (save-excursion
    (save-restriction
      (widen)
      (goto-char (overlay-start overlay))
      (let* ((size (sov-markdown--image-native-size overlay))
             (width (max 1 (- (car limits)
                              (* (current-indentation) (caddr limits)))))
             (scale (min sov-markdown-image-scale
                         (/ (float width) (car size))
                         (/ (float (cadr limits)) (cdr size)))))
        (sov-markdown--set-image-scale overlay scale)))))

(defun sov-markdown--image-at-point ()
  "Return the local Markdown image overlay containing point, if any."
  (cl-find-if
   (lambda (overlay)
     (and (eq (overlay-buffer overlay) (current-buffer))
          (<= (overlay-start overlay) (point))
          (< (point) (overlay-end overlay))))
   (bound-and-true-p markdown-inline-image-overlays)))

(defun sov-markdown--zoom-image (overlay factor)
  "Multiply the current displayed size of OVERLAY by FACTOR immediately."
  (let* ((size (sov-markdown--image-native-size overlay))
         (image (overlay-get overlay 'display))
         (scale (or (overlay-get overlay 'sov-markdown-image-scale)
                    (image-property image :scale)))
         (current (if (numberp scale) scale (image-compute-scaling-factor scale)))
         (minimum (/ 1.0 (min (car size) (cdr size)))))
    ;; Stop at one pixel on the short edge instead of creating endless cache
    ;; entries whose distinct scales all render the same one-pixel image.
    (sov-markdown--set-image-scale overlay (max minimum (* current factor)))))

(defun sov-markdown-image-increase-size ()
  "Enlarge the image under point, or use Evil's usual + motion elsewhere."
  (interactive)
  (if-let* ((overlay (sov-markdown--image-at-point)))
      (sov-markdown--zoom-image overlay sov-markdown-image-zoom-factor)
    (call-interactively #'evil-next-line-first-non-blank)))

(defun sov-markdown-image-decrease-size ()
  "Shrink the image under point, or use Evil's usual - motion elsewhere."
  (interactive)
  (if-let* ((overlay (sov-markdown--image-at-point)))
      (sov-markdown--zoom-image overlay (/ 1.0 sov-markdown-image-zoom-factor))
    (call-interactively #'evil-previous-line-first-non-blank)))

(defun sov-markdown--release-image-preview (overlay)
  "Release OVERLAY's decoded image and preview bytes, then delete it."
  (when-let* ((image (overlay-get overlay 'display)))
    (image-flush image t))
  (overlay-put overlay 'display nil)
  (delete-overlay overlay))

(defun sov-markdown--image-preview-modified (overlay after &rest _)
  "Release OVERLAY after a text change leaves its image link empty."
  (when (and after
             (overlay-buffer overlay)
             (= (overlay-start overlay) (overlay-end overlay)))
    (with-current-buffer (overlay-buffer overlay)
      (setq markdown-inline-image-overlays
            (delq overlay markdown-inline-image-overlays)))
    (sov-markdown--release-image-preview overlay)))

(defun sov-markdown--watch-image-preview (overlay)
  "Arrange for OVERLAY to release its preview when its link is deleted."
  ;; Evaporation would delete the overlay before its after-change callback.
  ;; Keep an empty overlay alive until that callback releases its resources.
  (overlay-put overlay 'evaporate nil)
  (let ((hooks (overlay-get overlay 'modification-hooks)))
    (unless (memq #'sov-markdown--image-preview-modified hooks)
      (overlay-put overlay 'modification-hooks
                   (cons #'sov-markdown--image-preview-modified hooks)))))

(defun sov-markdown--clear-image-previews ()
  "Release this buffer's decoded images and in-memory preview bytes."
  (dolist (overlay (bound-and-true-p markdown-inline-image-overlays))
    (sov-markdown--release-image-preview overlay))
  (setq markdown-inline-image-overlays nil))

(defun sov-markdown--render-images ()
  "Create local image overlays before applying a one-shot fit."
  (when (display-images-p)
    (require 'markdown-mode)
    (let ((image-scaling-factor sov-markdown-image-scale)
          (markdown-display-remote-images nil)
          (markdown-max-image-size nil))
      (sov-markdown--clear-image-previews)
      (markdown-display-inline-images))
    (dolist (overlay markdown-inline-image-overlays)
      (sov-markdown--watch-image-preview overlay))))

(defun sov-markdown-fit-images ()
  "Fit every local image once to the current window, resetting manual zoom."
  (interactive)
  (unless (display-images-p)
    (user-error "Image fitting requires a graphical window"))
  (let ((limits (sov-markdown--image-window-limits)))
    (sov-markdown--render-images)
    (dolist (overlay markdown-inline-image-overlays)
      (sov-markdown--fit-image overlay limits))))

(defalias 'sov-markdown-refresh-images #'sov-markdown-fit-images
  "Render local images and fit them once to the current window.")

(defun sov-markdown--yank-image (_mimetype data)
  "Save clipboard image DATA and insert a relative Markdown image link.
Emacs's image library detects the binary format and supplies the extension."
  (barf-if-buffer-read-only)
  (unless (and buffer-file-name (not (file-remote-p buffer-file-name)))
    (user-error "Save the Markdown buffer to a local file first"))
  (require 'markdown-mode)
  (require 'projectile)
  (let* ((type (or (image-type-from-data data)
                   (user-error "Emacs could not identify the clipboard image")))
         (name (read-string "Image name (without extension; empty = timestamp): "))
         (name (if (string-empty-p name)
                   (format-time-string sov-markdown-image-name-format)
                 name))
         (default-directory (file-name-directory buffer-file-name))
         (directory (expand-file-name
                     sov-markdown-image-directory
                     (or (projectile-project-root default-directory)
                         default-directory)))
         (filename (concat name "." (symbol-name type)))
         (file (expand-file-name filename directory)))
    (when (or (member name '("." ".."))
              (string-match-p "[/\\\\\n\r<>]" name))
      (user-error "Enter an image name, without a directory or angle brackets"))
    (make-directory directory t)
    ;; Exclusive creation avoids silently overwriting an existing attachment.
    ;; Binary coding preserves every byte, independently of the .md encoding.
    (let ((coding-system-for-write 'no-conversion))
      (write-region data nil file nil 'silent nil 'excl))
    ;; Escape Markdown/URL punctuation while keeping Unicode names readable.
    ;; markdown-mode's renderer decodes these escapes before opening the file.
    (let ((start (point)))
      (markdown-insert-inline-image
       "" (replace-regexp-in-string
           (rx (any " \t()[]%?#<>\"")) #'url-hexify-string
           (file-relative-name file default-directory) t t))
      ;; Render only the new link.  Other previews keep their manual sizes.
      (when (display-images-p)
        (when-let* ((image (create-image file nil nil :scale sov-markdown-image-scale)))
          (let ((overlay (make-overlay start (point))))
            (overlay-put overlay 'display image)
            (overlay-put overlay 'face 'default)
            (sov-markdown--watch-image-preview overlay)
            (push overlay markdown-inline-image-overlays)
            (sov-markdown--fit-image overlay (sov-markdown--image-window-limits))))))))

(defun sov-markdown-paste-image ()
  "Paste a clipboard image as an external file and preview it immediately."
  (interactive)
  (barf-if-buffer-read-only)
  (unless (and buffer-file-name (not (file-remote-p buffer-file-name)))
    (user-error "Save the Markdown buffer to a local file first"))
  ;; Restrict this command to image data, even if another handler is installed.
  (let ((yank-media--registered-handlers
         '(("image/.*" . sov-markdown--yank-image)))
        (yank-media-preferred-types
         (append '(image/png image/jpeg)
                 (list (lambda (types) types)))))
    (yank-media)))

(defun sov-markdown-image-setup-keys ()
  "Bind image insertion, manual zoom, and one-shot fitting in this buffer."
  (local-set-key (kbd "C-c y") #'sov-markdown-paste-image)
  (when (featurep 'evil)
    (dolist (state '(normal insert))
      (evil-local-set-key state (kbd "C-c y") #'sov-markdown-paste-image))
    (evil-local-set-key 'normal (kbd "+") #'sov-markdown-image-increase-size)
    (evil-local-set-key 'normal (kbd "-") #'sov-markdown-image-decrease-size)
    (evil-local-set-key 'normal (kbd "<leader>if") #'sov-markdown-fit-images)))

(defun sov-markdown-image-setup ()
  "Set up clipboard image insertion and existing image previews."
  (add-hook 'kill-buffer-hook #'sov-markdown--clear-image-previews nil t)
  (add-hook 'change-major-mode-hook #'sov-markdown--clear-image-previews nil t)
  ;; Share markdown-mode's renderer across Emacs 30 and 31.  Do not create
  ;; a second set of previews with markdown-ts-mode's native renderer.
  (when (derived-mode-p 'markdown-ts-mode)
    (setq-local markdown-ts-inline-images nil))
  (sov-markdown-image-setup-keys)
  (when (display-images-p)
    (sov-markdown-fit-images)))

(add-hook 'markdown-mode-hook #'sov-markdown-image-setup)
(add-hook 'markdown-ts-mode-hook #'sov-markdown-image-setup)

(defconst sov-markdown-table--start-marker-regexp
  "^<!-- sov-markdown-table-wrap width:\\([1-9][0-9]*\\) -->[ \t]*$")

(defconst sov-markdown-table--end-marker-regexp
  "^<!-- /sov-markdown-table-wrap -->[ \t]*$")

(defconst sov-markdown-table--marker-line-regexp
  "^<!--[ \t]+\\(?:/\\)?sov-markdown-table-wrap.*$")

(defconst sov-markdown-table--pipe-line-regexp
  "^[ \t]*|.*|[ \t]*$")

(defconst sov-markdown-table--separator-line-regexp
  "^[ \t]*|[-:| \t]*-[-:| \t]*|[ \t]*$")

(defun sov-markdown-table--marker-ranges ()
  "Return validated wrapped-table marker ranges in the current buffer.
Each result is a plist containing the marker, content, and width fields.
Signal `user-error' for malformed, unmatched, or nested markers."
  (save-excursion
    (goto-char (point-min))
    (let (open ranges)
      (while (re-search-forward sov-markdown-table--marker-line-regexp nil t)
        (let* ((line-beg (line-beginning-position))
               (line-end (line-end-position))
               (line (buffer-substring-no-properties line-beg line-end)))
          (cond
           ((string-match sov-markdown-table--start-marker-regexp line)
            (when open
              (user-error "Nested Markdown table wrap markers are invalid"))
            (unless (< line-end (point-max))
              (user-error "Markdown table wrap start marker has no content"))
            (setq open
                  (list :whole-beg line-beg
                        :content-beg (1+ line-end)
                        :width (string-to-number (match-string 1 line)))))
           ((string-match-p sov-markdown-table--end-marker-regexp line)
            (unless open
              (user-error "Markdown table wrap end marker has no start"))
            (let ((content-end line-beg))
              (when (and (> content-end (point-min))
                         (eq (char-before content-end) ?\n))
                (setq content-end (1- content-end)))
              (push (append open
                            (list :content-end content-end
                                  :whole-end line-end))
                    ranges)
              (setq open nil)))
           (t
            (user-error "Malformed Markdown table wrap marker: %s" line)))))
      (when open
        (user-error "Markdown table wrap start marker has no end"))
      (nreverse ranges))))

(defun sov-markdown-table--range-at-point (ranges)
  "Return the member of RANGES containing point, or nil."
  (let ((pos (point)))
    (cl-find-if (lambda (range)
                  (and (<= (plist-get range :whole-beg) pos)
                       (<= pos (plist-get range :whole-end))))
                ranges)))

(defun sov-markdown-table--line-count (text)
  "Return the number of nonempty lines in TEXT."
  (length (split-string text "\n" t)))

(defun sov-markdown-table--table-region-at-point ()
  "Return bounds of the pipe table at point, or signal `user-error'."
  (save-excursion
    (beginning-of-line)
    (unless (looking-at-p sov-markdown-table--pipe-line-regexp)
      (user-error "Point is not in a Markdown pipe table"))
    (while (and (> (line-beginning-position) (point-min))
                (progn
                  (forward-line -1)
                  (looking-at-p sov-markdown-table--pipe-line-regexp))))
    (unless (looking-at-p sov-markdown-table--pipe-line-regexp)
      (forward-line 1))
    (let ((beg (line-beginning-position)))
      (while (and (looking-at-p sov-markdown-table--pipe-line-regexp)
                  (= (forward-line 1) 0)))
      (let ((end (if (bolp) (1- (point)) (line-end-position))))
        (cons beg end)))))

(defun sov-markdown-table--valid-table-p (text &optional wrapped)
  "Return non-nil when TEXT is a structurally valid pipe table.
When WRAPPED is non-nil, allow multiple visual header lines."
  (let* ((lines (split-string text "\n" t))
         (separator-index
          (cl-position-if
           (lambda (line)
             (string-match-p sov-markdown-table--separator-line-regexp line))
           lines))
         (separator-count
          (cl-count-if
           (lambda (line)
             (string-match-p sov-markdown-table--separator-line-regexp line))
           lines)))
    (and (>= (length lines) 2)
         (cl-every (lambda (line)
                     (string-match-p sov-markdown-table--pipe-line-regexp line))
                   lines)
         (= separator-count 1)
         separator-index
         (> separator-index 0)
         (or wrapped (= separator-index 1)))))

(defun sov-markdown-table--unwrap-marked-text (text width)
  "Validate and unwrap marked table TEXT produced for WIDTH."
  (require 'markdown-table-wrap)
  (unless (sov-markdown-table--valid-table-p text t)
    (user-error "Wrapped Markdown table is structurally invalid"))
  (let ((unwrapped (markdown-table-wrap-unwrap text)))
    (unless (sov-markdown-table--valid-table-p unwrapped)
      (user-error "Wrapped Markdown table could not be unwrapped reliably"))
    (unless (equal unwrapped
                   (markdown-table-wrap-unwrap
                    (markdown-table-wrap unwrapped width)))
      (user-error "Wrapped Markdown table has ambiguous row boundaries"))
    unwrapped))

(defun sov-markdown-table--replace-range (beg end text)
  "Replace BEG through END with TEXT without disturbing surrounding newlines."
  (goto-char beg)
  (delete-region beg end)
  (insert text))

(defun sov-markdown-table-wrap-at-point (&optional width)
  "Wrap the Markdown pipe table at point for WIDTH columns.
With a numeric prefix argument, use that width.  Otherwise use the current
window body width with a two-column margin.  An already marked table is first
unwrapped, then rendered again at the new width."
  (interactive "P")
  (require 'markdown-table-wrap)
  (let* ((target-width (if width
                           (prefix-numeric-value width)
                         (max 20 (- (window-body-width) 2))))
         (ranges (sov-markdown-table--marker-ranges))
         (range (sov-markdown-table--range-at-point ranges))
         bounds raw beg end)
    (when (< target-width 1)
      (user-error "Markdown table width must be positive"))
    (if range
        (setq beg (plist-get range :whole-beg)
              end (plist-get range :whole-end)
              raw (sov-markdown-table--unwrap-marked-text
                   (buffer-substring-no-properties
                    (plist-get range :content-beg)
                    (plist-get range :content-end))
                   (plist-get range :width)))
      (setq bounds (sov-markdown-table--table-region-at-point)
            beg (car bounds)
            end (cdr bounds)
            raw (buffer-substring-no-properties beg end)))
    (when (markdown-table-wrap-inside-code-fence-p beg)
      (user-error "Markdown tables inside fenced code blocks are not wrapped"))
    (unless (sov-markdown-table--valid-table-p raw)
      (user-error "Point is not in a valid GFM pipe table"))
    (let* ((wrapped (markdown-table-wrap raw target-width))
           (needs-projection (> (sov-markdown-table--line-count wrapped)
                                (sov-markdown-table--line-count raw)))
           (replacement
            (if needs-projection
                (format "<!-- sov-markdown-table-wrap width:%d -->\n%s\n<!-- /sov-markdown-table-wrap -->"
                        target-width wrapped)
              wrapped)))
      (atomic-change-group
        (save-excursion
          (sov-markdown-table--replace-range beg end replacement))))))

(defun sov-markdown-table-unwrap-at-point ()
  "Unwrap the marked Markdown table at point and remove its markers."
  (interactive)
  (let* ((range (sov-markdown-table--range-at-point
                 (sov-markdown-table--marker-ranges))))
    (unless range
      (user-error "Point is not in a marked wrapped Markdown table"))
    (let ((unwrapped
           (sov-markdown-table--unwrap-marked-text
            (buffer-substring-no-properties
             (plist-get range :content-beg)
             (plist-get range :content-end))
            (plist-get range :width))))
      (atomic-change-group
        (save-excursion
          (sov-markdown-table--replace-range
           (plist-get range :whole-beg)
           (plist-get range :whole-end)
           unwrapped))))))

(defun sov-markdown-table-unwrap-buffer ()
  "Unwrap every marked Markdown table in the current buffer."
  (interactive)
  (let ((ranges (reverse (sov-markdown-table--marker-ranges))))
    (atomic-change-group
      (save-excursion
        (dolist (range ranges)
          (sov-markdown-table--replace-range
           (plist-get range :whole-beg)
           (plist-get range :whole-end)
           (sov-markdown-table--unwrap-marked-text
            (buffer-substring-no-properties
             (plist-get range :content-beg)
             (plist-get range :content-end))
            (plist-get range :width))))))))

(defun sov-markdown-table--project-content ()
  "Return current buffer contents with all marked tables unwrapped.
Signal `user-error' without modifying the current buffer when markers or
wrapped tables are invalid."
  (let ((source (current-buffer)))
    (with-temp-buffer
      (insert-buffer-substring source)
      (dolist (range (reverse (sov-markdown-table--marker-ranges)))
        (sov-markdown-table--replace-range
         (plist-get range :whole-beg)
         (plist-get range :whole-end)
         (sov-markdown-table--unwrap-marked-text
          (buffer-substring-no-properties
           (plist-get range :content-beg)
           (plist-get range :content-end))
          (plist-get range :width))))
      (buffer-string))))

(defun sov-markdown-table--apply-saved-file-modes (setmodes)
  "Restore file modes and extended attributes described by SETMODES."
  (when setmodes
    (condition-case nil
        (unless (with-demoted-errors "Error setting file modes: %S"
                  (set-file-modes buffer-file-name (car setmodes)))
          (set-file-extended-attributes buffer-file-name (nth 1 setmodes)))
      (error nil))))

(defun sov-markdown-table--write-projection (content)
  "Write CONTENT to the current visited file using standard save semantics.
Return a cons of the resulting `buffer-backed-up' value and SETMODES data."
  (let ((source (current-buffer))
        result)
    (with-temp-buffer
      (insert content)
      (setq buffer-file-name (buffer-local-value 'buffer-file-name source)
            buffer-file-truename
            (buffer-local-value 'buffer-file-truename source)
            buffer-file-coding-system
            (buffer-local-value 'buffer-file-coding-system source)
            save-buffer-coding-system
            (buffer-local-value 'save-buffer-coding-system source)
            buffer-backed-up (buffer-local-value 'buffer-backed-up source)
            write-region-annotate-functions
            (buffer-local-value 'write-region-annotate-functions source)
            write-region-post-annotation-function
            (buffer-local-value 'write-region-post-annotation-function source)
            file-precious-flag t
            default-directory (buffer-local-value 'default-directory source))
      (set-buffer-modified-p t)
      (let ((setmodes (basic-save-buffer-2)))
        (setq result (cons buffer-backed-up setmodes))))
    result))

(defun sov-markdown-table-projection-write-contents ()
  "Write an unwrapped projection when the current buffer has wrap markers."
  (let ((ranges (sov-markdown-table--marker-ranges)))
    (when ranges
      ;; Validate before invoking VC, then project again in case VC updated text.
      (sov-markdown-table--project-content)
      (vc-before-save)
      (let* ((projection (sov-markdown-table--project-content))
             (save-result (sov-markdown-table--write-projection projection)))
        (setq buffer-backed-up (car save-result))
        (sov-markdown-table--apply-saved-file-modes (cdr save-result))
        (set-buffer-modified-p nil)
        (set-visited-file-modtime)
        t))))

(defun sov-markdown-table-projection-setup ()
  "Install the wrapped-table projection writer in the current buffer."
  (add-hook 'write-contents-functions
            #'sov-markdown-table-projection-write-contents nil t))

(add-hook 'markdown-mode-hook #'sov-markdown-table-projection-setup)
(add-hook 'markdown-ts-mode-hook #'sov-markdown-table-projection-setup)

(use-package markdown-table-wrap
  :ensure (:host github
           :repo "dnouri/markdown-table-wrap"
           :wait t)
  :commands (markdown-table-wrap markdown-table-wrap-unwrap))

(defun sov-lang-markdown-mode ()
  "Select the configured Markdown mode for the current Emacs version."
  (interactive)
  (if (>= emacs-major-version 31)
      (markdown-ts-mode)
    (markdown-mode)))

(with-eval-after-load 'evil
  (evil-define-command sov-markdown-next-heading-center (count)
    "Move forward COUNT same-level headings, then center the current line."
    :repeat nil
    (interactive "<c>")
    (outline-forward-same-level (or count 1))
    ;; `zz' calls this command.  Its count is a line number, so do not
    ;; forward the heading count to it.
    (evil-scroll-line-to-center nil))

  (evil-define-command sov-markdown-previous-heading-center (count)
    "Move backward COUNT same-level headings, then center the current line."
    :repeat nil
    (interactive "<c>")
    (outline-backward-same-level (or count 1))
    (evil-scroll-line-to-center nil))

  (defun sov-markdown-setup-heading-navigation ()
    "Bind centered heading jumps in the current Markdown buffer."
    ;; Evil's local state map takes precedence over Outline minor mode's
    ;; state map; a major-mode binding alone would be shadowed by it.
    (evil-local-set-key 'normal (kbd "C-j")
                        #'sov-markdown-next-heading-center)
    (evil-local-set-key 'normal (kbd "C-k")
                        #'sov-markdown-previous-heading-center))

  (add-hook 'markdown-mode-hook #'sov-markdown-setup-heading-navigation)
  (add-hook 'markdown-ts-mode-hook #'sov-markdown-setup-heading-navigation))

(defun sov-lang-markdown--protect-code-blocks-from-fill ()
  "Prevent `auto-fill-mode' from wrapping fenced code blocks."
  (add-hook 'fill-nobreak-predicate
            #'markdown-code-block-at-point-p nil t))

;; Render LaTeX math expressions as image overlays in Markdown buffers.
;; `math-preview-all' previews the current buffer when it is opened; it can
;; also be called interactively after editing.  The Node.js companion is kept
;; with the Elpaca source and is invoked explicitly through `node'.
(use-package math-preview
  :ensure (:host gitlab
           :repo "matsievskiysv/math-preview"
           :wait t)
  :custom
  (math-preview-command
   (list "node"
         (expand-file-name "math-preview.js"
                           (expand-file-name "math-preview/"
                                             elpaca-sources-directory))))
  ;; MathJax expects `em' to track font height and `ex' to approximate the
  ;; x-height.  The package defaults use character width and full height,
  ;; which makes fallback CJK text disproportionately small.
  (math-preview-mathjax-em #'window-font-height)
  (math-preview-mathjax-ex
   (lambda ()
     (/ (window-font-height) 2.0)))
  :hook ((markdown-mode . math-preview-all)
         (markdown-ts-mode . math-preview-all)))

;; `markdown-mode' supplies the Emacs 30 fallback and GFM support.  Long
;; paragraphs wrap visually without inserting newlines while typing.
(use-package markdown-mode
  :ensure (:host github
           :repo "jrblevin/markdown-mode"
           :wait t)
  :mode (("\\.md\\'" . sov-lang-markdown-mode)
         ("\\.markdown\\'" . sov-lang-markdown-mode)
         ("\\.mdown\\'" . sov-lang-markdown-mode)
         ("\\.mkdn\\'" . sov-lang-markdown-mode))
  :custom
  (markdown-italic-underscore t)
  (markdown-fontify-code-blocks-natively t)
  (markdown-fontify-whole-heading-line t)
  (markdown-enable-math t)
  (markdown-enable-highlighting-syntax t)
  (markdown-hide-urls nil)
  (markdown-mouse-follow-link nil)
  :hook ((markdown-mode . visual-line-mode)
         (markdown-mode . sov-lang-markdown--protect-code-blocks-from-fill))
  :config
  (evil-define-key 'normal markdown-mode-map
    (kbd "<leader>ma") #'math-preview-all
    (kbd "<leader>mr") #'math-preview-at-point
    (kbd "<leader>mc") #'math-preview-clear-all
    (kbd "<leader>md") #'math-preview-clear-at-point
    (kbd "<localleader>tw") #'sov-markdown-table-wrap-at-point
    (kbd "<localleader>tu") #'sov-markdown-table-unwrap-at-point
    (kbd "<localleader>tU") #'sov-markdown-table-unwrap-buffer)
  (evil-define-key 'visual markdown-mode-map
    (kbd "<leader>ma") #'math-preview-all
    (kbd "<leader>mr") #'math-preview-region
    (kbd "<leader>mc") #'math-preview-clear-all
    (kbd "<leader>md") #'math-preview-clear-region))

;; Doom uses GFM mode for README files because repositories commonly rely on
;; GitHub-specific tables, task lists, and fenced-code conventions.
(add-to-list 'auto-mode-alist '("/README\\(?:\\.md\\)?\\'" . gfm-mode))

;; Emacs 31 ships an enhanced Tree-sitter Markdown mode.  Keep its setup
;; separate from `markdown-mode': Emacs 30 uses the latter directly, without
;; installing an external Tree-sitter Markdown mode.
(when (>= emacs-major-version 31)
  (require 'markdown-ts-mode)
  (setq-default markdown-ts-hide-markup nil)
  (setq markdown-ts-ellipsis " "
        markdown-ts-checked-checkbox '("☑" . "+")
        markdown-ts-unchecked-checkbox '("☐" . "-")
        markdown-ts-fontify-code-blocks-natively t
        ;; Keep TAB/Shift-TAB cell navigation without letting the native
        ;; formatter remove the padding spaces required by `valign'.
        markdown-ts-table-auto-align nil)
  ;; Keep every heading larger than body text while preserving a clear visual
  ;; hierarchy.  `markdown-ts-setext-heading' inherits the level-one face.
  (dolist (face-height '((markdown-ts-heading-1 . 1.50)
                         (markdown-ts-heading-2 . 1.35)
                         (markdown-ts-heading-3 . 1.25)
                         (markdown-ts-heading-4 . 1.18)
                         (markdown-ts-heading-5 . 1.12)
                         (markdown-ts-heading-6 . 1.06)))
    (set-face-attribute (car face-height) nil :height (cdr face-height)))
  (add-hook 'markdown-ts-mode-hook #'visual-line-mode)
  (with-eval-after-load 'evil
    (evil-define-key 'normal markdown-ts-mode-map
      (kbd "<leader>ma") #'math-preview-all
      (kbd "<leader>mr") #'math-preview-at-point
      (kbd "<leader>mc") #'math-preview-clear-all
      (kbd "<leader>md") #'math-preview-clear-at-point
      (kbd "<localleader>tw") #'sov-markdown-table-wrap-at-point
      (kbd "<localleader>tu") #'sov-markdown-table-unwrap-at-point
      (kbd "<localleader>tU") #'sov-markdown-table-unwrap-buffer)
    (evil-define-key 'visual markdown-ts-mode-map
      (kbd "<leader>ma") #'math-preview-all
      (kbd "<leader>mr") #'math-preview-region
      (kbd "<leader>mc") #'math-preview-clear-all
      (kbd "<leader>md") #'math-preview-clear-region)))

;; `valign' is installed by the Org language module and shared here.  It only
;; adds display properties; Markdown table source and semantics stay intact.
(use-package valign
  :ensure nil
  :custom
  (valign-max-table-size 10000)
  :hook ((markdown-mode . valign-mode)
         (gfm-mode . valign-mode)
         (markdown-ts-mode . valign-mode)))

;; Keep Markdown in the shared Tree-sitter registry so `:TSInstall markdown'
;; installs both grammars required by `markdown-ts-mode'.  Grammar v0.5
;; requires Tree-sitter ABI 15 or newer.
(sov-treesit-register-language
 'markdown
 `((:language markdown
    :url "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
    :revision ,(lambda ()
                 (if (< (treesit-library-abi-version) 15)
                     "v0.4.1"
                   "v0.5.1"))
    :source-dir "tree-sitter-markdown/src")
   (:language markdown-inline
    :url "https://github.com/tree-sitter-grammars/tree-sitter-markdown"
    :revision ,(lambda ()
                 (if (< (treesit-library-abi-version) 15)
                     "v0.4.1"
                   "v0.5.1"))
    :source-dir "tree-sitter-markdown-inline/src")))


(provide 'sov-lang-markdown)
;;; sov-lang-markdown.el ends here
