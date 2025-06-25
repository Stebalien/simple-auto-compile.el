;;; simple-auto-compile.el --- Auto compile elisp files on load -*- lexical-binding: t -*-

;; Copyright 2025 Steven Allen <steven@stebalien.com>

;; Author: Steven Allen <steven@stebalien.com>
;; URL: https://github.com/Stebalien/simple-auto-compile.el
;; Version: 0.0.1
;; Package-Requires: ((emacs "28.1"))
;; Keywords: extensions

;; This file is not part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Auto-compiles files on load. This is not the first, second, or third package
;; to do this but unlike all the alternatives, I avoid advising require, etc.
;; because require performance can be critical.

;;; Code:

(eval-when-compile (require 'rx))

(defgroup simple-auto-compile nil
  "Automatically compiles elisp files on load."
  :group 'lisp)

(defcustom simple-auto-compile-exclude-patterns
  (list
   ;; Ignore the init file for extra safety.
   early-init-file
   ;; ignore system directories, we can't put .elc files there anyways.
   (rx bos (or "/usr/" "/opt/"))
   ;; Ignore pkg/autoload files.
   (rx "-" (or "autoloads" "pkg") ".el" eos))
  "List of regular expressions for files to exclude from auto-compilation."
  :type '(repeat regexp)
  :group 'simple-auto-compile)

(defconst simple-auto-compile--valid-sources
  (rx ".el" (eval (cons 'or load-file-rep-suffixes)) eos))

(defun simple-auto-compile--should-compile-p (file)
  "Return non-nil if FILE should be compiled."
  (and file
       (string-match-p simple-auto-compile--valid-sources file)
       ;; Check against exclusion patterns
       (not (seq-some (lambda (pattern)
                        (string-match-p pattern file))
                      simple-auto-compile-exclude-patterns))))

(defun simple-auto-compile--compile-loaded-files ()
  "Compile all previously loaded Emacs Lisp files found in `load-history'."
  (dolist (entry load-history)
    (simple-auto-compile--compile (car entry))))

(defun simple-auto-compile--compile (file)
  "After loading FILE, native compile it if needed and return t on success."
  (when (simple-auto-compile--should-compile-p file)
    (message "Auto-compiling %s..." file)
    (if (ignore-errors (byte-compile-file file))
        (native--compile-async (byte-compile-dest-file file) nil 'late nil)
      (message "Failed to compile %s" file))))

;; NOTE: This uses advice instead of the after-load-functions hook so we can:
;; 1. Compile and reload before any "after load" stuff happens.
;; 2. Avoid running any 'after load" stuff twice.

;;;###autoload
(define-minor-mode simple-auto-compile-mode
  "Toggle automatic compilation of loaded Emacs Lisp files.
When enabled, Emacs will automatically compile any .el file after it's loaded,
and reload it once compilation is complete. When enabled, also compiles all
previously loaded uncompiled files."
  :global t
  :group 'simple-auto-compile
  (if simple-auto-compile-mode
      (progn
        (advice-add #'do-after-load-evaluation :before-until #'simple-auto-compile--compile)
        (simple-auto-compile--compile-loaded-files))
    (advice-remove #'do-after-load-evaluation #'simple-auto-compile-mode)))

(provide 'simple-auto-compile)
;;; simple-auto-compile.el ends here
