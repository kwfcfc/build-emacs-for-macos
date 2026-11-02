;;; gui-verify.el --- Check that an Emacs-IGC bundle opens a Cocoa frame -*- lexical-binding: t; -*-

;; Usage:
;;   open -n Emacs-IGC.app --args -Q \
;;     --eval '(setq emacs-igc-gui-output "/path/to/result.txt")' \
;;     -l gui-verify.el
;;
;; Writes the result to `emacs-igc-gui-output' after startup, then quits
;; three seconds later.

(defvar emacs-igc-gui-output nil
  "File that receives the GUI verification result.")

(add-hook 'emacs-startup-hook
          (lambda ()
            (with-temp-file emacs-igc-gui-output
              (insert (if (and (display-graphic-p) (eq window-system 'ns))
                          "Cocoa GUI: OK\n"
                        "Cocoa GUI: FAILED\n")
                      (format "IGC: %S\nBundle: %s\n"
                              (and (fboundp 'igc-info) (igc-info) t)
                              invocation-directory)))
            (run-at-time 3 nil #'kill-emacs)))

;;; gui-verify.el ends here
