;;; verify.el --- Batch checks for an Emacs-IGC bundle -*- lexical-binding: t; -*-

;; Usage: Emacs.app/Contents/MacOS/Emacs -Q --batch -l verify.el
;;
;; Exits non-zero unless IGC (MPS), full AOT native compilation, native
;; compile/load and Tree-sitter all work.  The native-compile smoke test runs
;; in a temporary directory, so nothing is written next to this file.

(require 'comp)

(defun emacs-igc-verify--check (label ok)
  "Print LABEL as OK, or signal an error when OK is nil."
  (unless ok
    (error "%s: FAILED" label))
  (princ (format "%s: OK\n" label)))

;; `(featurep 'igc)' is nil even on IGC builds; `igc-info' is the real probe.
(emacs-igc-verify--check "IGC" (and (fboundp 'igc-info) (igc-info)))
(emacs-igc-verify--check
 "MPS feature" (member "MPS" (split-string system-configuration-features)))
(emacs-igc-verify--check "Native compilation" (native-comp-available-p))
(emacs-igc-verify--check
 "Full AOT"
 (string-match-p "--with-native-compilation=aot" system-configuration-options))
(emacs-igc-verify--check "Tree-sitter" (treesit-available-p))

(let* ((dir (make-temp-file "emacs-igc-verify-" t))
       (source (expand-file-name "smoke.el" dir))
       (native-comp-eln-load-path (list (expand-file-name "eln-cache/" dir))))
  (unwind-protect
      (progn
        (with-temp-file source
          (insert ";;; smoke.el -*- lexical-binding: t; -*-\n"
                  "(defun emacs-igc-verify-smoke (x) (+ x 17))\n"))
        (load (native-compile source (expand-file-name "smoke.eln" dir))
              nil t)
        (emacs-igc-verify--check
         "Native compile/load"
         (and (native-comp-function-p
               (symbol-function 'emacs-igc-verify-smoke))
              (= (emacs-igc-verify-smoke 25) 42))))
    (delete-directory dir t)))

(garbage-collect)
(emacs-igc-verify--check "GC" t)
(princ (format "Emacs %s\nBundle: %s\n" emacs-version invocation-directory))

;;; verify.el ends here
