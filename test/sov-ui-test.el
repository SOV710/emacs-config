;;; sov-ui-test.el --- Tests for sov-ui -*- lexical-binding: t; -*-

;; This file contains unit tests for the custom mode line helpers defined in
;; `sov-ui-modeline.el'.  The tests mock icon and project functions so they
;; can run without requiring the actual Nerd Fonts or a project.

(require 'ert)
(require 'sov-ui)


;;; Module loading

(ert-deftest sov-ui-test-modeline-module-loaded ()
  "Ensure the custom mode-line module is loaded alongside `sov-ui'."
  (should (featurep 'sov-ui-modeline)))

(ert-deftest sov-ui-test-dashboard-module-loaded ()
  "Ensure the dashboard module is loaded alongside `sov-ui'."
  (should (featurep 'sov-ui-dashboard)))


;;; Evil state lookup

(ert-deftest sov-ui-test-evil-info ()
  "Verify `sov-ui--evil-info' returns the expected label and face.
Compact labels should be a single character, and unknown states should
fall back to the Normal face."
  (should (equal (sov-ui--evil-info 'normal nil)
                 '("NORMAL" sov-ui-mode-line-normal)))
  (should (equal (sov-ui--evil-info 'insert t)
                 '("I" sov-ui-mode-line-insert)))
  (should (equal (sov-ui--evil-info 'unknown nil)
                 '("UNKNOWN" sov-ui-mode-line-normal))))


;;; Path handling

(ert-deftest sov-ui-test-path-variants ()
  "Check that `sov-ui--path-variants' produces full, shortened, and base names."
  (should (equal (sov-ui--path-variants
                  "/work/project/lisp/sov-ui.el" "/work/project/")
                 '("lisp/sov-ui.el" "l/sov-ui.el" "sov-ui.el"))))


;;; Diff hunk counting

(ert-deftest sov-ui-test-diff-hunk-counts ()
  "Verify that `sov-ui--count-diff-hunks' classifies insert/change/delete."
  (should (equal (sov-ui--count-diff-hunks
                  '((2 4 insert) (8 3 change) (20 1 delete)
                    (30 9 insert)))
                 '(2 1 1))))


;;; Region metrics

(ert-deftest sov-ui-test-region-metrics ()
  "Check character, line, and block selection metrics."
  (with-temp-buffer
    (insert "abcd\nxy\n12345\n")
    (should (equal (sov-ui--region-metrics 2 8 'character) "2:6"))
    (should (equal (sov-ui--region-metrics 1 9 'line) "2:8"))
    (should (equal (sov-ui--region-metrics 2 11 'block) "3:2"))))


;;; Flymake diagnostics

(ert-deftest sov-ui-test-flymake-counts ()
  "Verify that Flymake error and warning counts are extracted correctly."
  (let ((flymake-mode t))
    (cl-letf (((symbol-function 'flymake-diagnostics)
               (lambda () '(error-1 warning-1 warning-2 note-1)))
              ((symbol-function 'flymake-diagnostic-type)
               (lambda (diag)
                 (pcase diag
                   ('error-1 :error)
                   ((or 'warning-1 'warning-2) :warning)
                   (_ :note)))))
      (should (equal (sov-ui--flymake-counts) '(1 2))))))


;;; Condition indicators

(ert-deftest sov-ui-test-condition-items ()
  "Check that active conditions are detected and returned in order."
  (with-temp-buffer
    (insert "ab")
    (narrow-to-region 1 2)
    (cl-letf (((symbol-function 'file-remote-p)
               (lambda (&rest _) "/ssh:test:"))
              ((symbol-function 'get-buffer-process)
               (lambda (&rest _) 'process)))
      (let ((defining-kbd-macro t))
        (should (equal (mapcar #'car (sov-ui--condition-items))
                       '(narrow remote macro process)))))))

(ert-deftest sov-ui-test-condition-icon-keeps-font-family ()
  "Ensure that condition icons preserve their original font family."
  (with-temp-buffer
    (insert "ab")
    (narrow-to-region 1 2)
    (cl-letf (((symbol-function 'nerd-icons-mdicon)
               (lambda (&rest _)
                 (propertize "I" 'face '(:family "Test Icons")))))
      (let* ((segment (sov-ui--conditions-segment t))
             (position (string-match "I" segment))
             (face (get-text-property position 'face segment)))
        (should (equal (plist-get face :family) "Test Icons"))))))


;;; Diff-hl caching

(ert-deftest sov-ui-test-cache-diff-hunks-preserves-return-value ()
  "Verify that the diff-hl advice returns the original changes unchanged."
  (with-temp-buffer
    (let ((changes '((1 1 insert) (4 2 change) (9 1 delete))))
      (should (eq (sov-ui--cache-diff-hunks changes) changes))
      (should (equal sov-ui--diff-hunks '(1 1 1))))))


;;; Face color helpers

(ert-deftest sov-ui-test-face-color-falls-back ()
  "Check that `sov-ui--face-color' returns the fallback when unspecified."
  (cl-letf (((symbol-function 'face-attribute)
             (lambda (&rest _) 'unspecified)))
    (should (equal (sov-ui--face-color 'default :foreground "fallback")
                   "fallback"))))


;;; File segment

(ert-deftest sov-ui-test-file-segment-has-no-input-properties ()
  "Verify that the file segment does not attach keymap or mouse-face properties.
Such properties would interfere with Evil window commands."
  (with-temp-buffer
    (setq buffer-file-name "/work/project/lisp/sov-ui.el")
    (cl-letf (((symbol-function 'project-current)
               (lambda (&rest _) 'project))
              ((symbol-function 'project-root)
               (lambda (_) "/work/project/"))
              ((symbol-function 'nerd-icons-icon-for-file)
               (lambda (&rest _) "F")))
      (let ((segment (sov-ui--file-segment 0 nil)))
        (should (string-match-p "lisp/sov-ui.el" segment))
        (should-not (get-text-property 0 'keymap segment))
        (should-not (get-text-property 0 'mouse-face segment))))))

(ert-deftest sov-ui-test-read-only-flag-uses-nerd-icon-function ()
  "Check that the read-only flag renders with the expected lock icon."
  (with-temp-buffer
    (setq buffer-read-only t)
    (cl-letf (((symbol-function 'nerd-icons-mdicon)
               (lambda (name &rest _)
                 (format "<%s>" name))))
      (should (equal (sov-ui--buffer-flags)
                     " <nf-md-lock>")))))


;;; Git branch parsing

(ert-deftest sov-ui-test-branch-normalization ()
  "Check that `sov-ui--git-branch' extracts the branch from `vc-mode'."
  (with-temp-buffer
    (setq-local vc-mode " Git:main")
    (should (equal (sov-ui--git-branch) "main"))))


;;; Diff segment

(ert-deftest sov-ui-test-diff-segment-suppresses-zeroes ()
  "Verify that the diff segment hides zero counts and shows non-zero ones."
  (let ((sov-ui--diff-hunks '(2 0 1)))
    (let ((segment (sov-ui--diff-segment)))
      (should (string-match-p "+2" segment))
      (should-not (string-match-p "~0" segment))
      (should (string-match-p "-1" segment)))))


;;; Layout selection

(ert-deftest sov-ui-test-choose-layout-first-fit ()
  "Check that `sov-ui--choose-layout' picks the first layout that fits."
  (let* ((wide (make-sov-ui--layout
                :tier 0 :left '("1234") :right '("12")))
         (narrow (make-sov-ui--layout
                  :tier 1 :left '("12") :right '("1"))))
    (should (= (sov-ui--layout-tier
                (sov-ui--choose-layout 4 (list wide narrow)))
               1))))


;;; Mode-line format

(ert-deftest sov-ui-test-mode-line-keeps-native-right-align-at-top-level ()
  "Ensure the default mode-line format still uses the native right-align slot."
  (should
   (equal (default-value 'mode-line-format)
          '((:eval (sov-ui--mode-line-left))
            mode-line-format-right-align
            (:eval (sov-ui--mode-line-right))))))

(ert-deftest sov-ui-test-mode-line-aligns-before-right-fringe ()
  "Check that the right mode-line segment is aligned to the right fringe."
  (should (eq mode-line-right-align-edge 'right-fringe)))


;;; Ruler and inactive layout

(ert-deftest sov-ui-test-ruler-occupies-final-block ()
  "Verify that the ruler segment is a single block with trailing spacing."
  (let ((segments (sov-ui--ruler-segments)))
    (should (= (length segments) 1))
    (should (string-suffix-p "  " (car segments)))))

(ert-deftest sov-ui-test-inactive-layout-has-no-right-content ()
  "Check that inactive layouts show only the file/buffer name on the left."
  (with-temp-buffer
    (cl-letf (((symbol-function 'sov-ui--file-icon)
               (lambda () "F")))
      (let ((layout (sov-ui--build-inactive-layout 30)))
        (should (null (sov-ui--layout-right layout)))
        (should (string-match-p
                 (regexp-quote (buffer-name))
                 (apply #'concat (sov-ui--layout-left layout))))))))

(ert-deftest sov-ui-test-provider-error-falls-back-to-buffer-name ()
  "Ensure that a mode-line construction error falls back to the buffer name."
  (with-temp-buffer
    (rename-buffer "fallback-buffer")
    (cl-letf (((symbol-function 'sov-ui--build-active-layout)
               (lambda (&rest _)
                 (error "provider failure")))
              ((symbol-function 'mode-line-window-selected-p)
               (lambda () t)))
      (should
       (string-match-p
        "fallback-buffer"
        (apply #'concat (sov-ui--mode-line-left)))))))


;;; Tier compression matrix

(ert-deftest sov-ui-test-compression-order ()
  "Verify the progressive compression settings across all tiers.
This catches accidental changes to the layout compression order."
  (let ((expected
         '((0 0 nil nil nil t t t)
           (1 1 nil nil nil t t t)
           (2 2 nil nil nil t t t)
           (3 2 t nil nil t t t)
           (4 2 t t nil t t t)
           (5 2 t t t t t t)
           (6 2 t t t nil t t)
           (7 2 t t t nil nil t)
           (8 2 t t t nil nil nil))))
    (dolist (row expected)
      (pcase-let
          ((`(,tier ,path ,major ,conditions ,state
                     ,flymake ,diff ,branch)
            row))
        (should
         (equal (sov-ui--tier-settings tier)
                (list path major conditions state
                      flymake diff branch)))))))


;;; sov-ui-test.el ends here
