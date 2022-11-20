;;; early-init.el --- pre-GUI initialization -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Andrew De Angelis

;; Author: Andrew De Angelis <andrewdeangelis@Andrews-MacBook-Air.local>
;; Keywords: local

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, version 3.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:

(progn ;; early customizations for nice appearance
  (push '(tool-bar-lines . 0)   default-frame-alist)
  (push '(vertical-scroll-bars) default-frame-alist)
  (setq tool-bar-mode   nil
	scroll-bar-mode nil)

  ;; scratch buffer in fundamental mode
  (setq initial-major-mode 'fundamental-mode)
  (setq initial-scratch-message "**Welcome to Emacs!**\n\n\n")

  (push '(left-fringe . 2)  default-frame-alist)
  (push '(right-fringe . 0) default-frame-alist)

  (setq inhibit-startup-screen t
        inhibit-startup-echo-area-message user-login-name))

;; optimization
;; avoid garbage collection at startup:
(setq gc-cons-threshold most-positive-fixnum ; 2^61 bytes
      gc-cons-percentage 0.6
      ;; avoid checking this list for any file that's opened
      my-file-name-handler-alist file-name-handler-alist
      file-name-handler-alist nil)
;; reset these after init:
(add-hook 'after-init-hook
          (lambda ()
            (setq gc-cons-threshold 16777216 ; 16mb
                  gc-cons-percentage 0.1
                  file-name-handler-alist my-file-name-handler-alist)))

(unless noninteractive

  ;; since we won't ever use these, we can avoid loading them
  (advice-add #'display-startup-echo-area-message :override #'ignore)
  (advice-add #'display-startup-screen :override #'ignore)

  (advice-add #'scroll-bar-mode :override #'ignore)
  (advice-add #'tool-bar-mode :override #'ignore)

  (unless (memq initial-window-system '(x pgtk))
    (setq command-line-x-option-alist nil)))
(setq load-prefer-newer noninteractive)


(provide 'early-init)
;;; early-init.el ends here
