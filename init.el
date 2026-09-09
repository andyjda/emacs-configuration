;;; init.el --- init file at HOME  -*- lexical-binding: t; -*-
;; Copyright (C) 2022  Andrew De Angelis

;; Author: Andrew De Angelis <bobodeangelis@gmail.com>
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

;;; Code:
;;;; NATIVE COMPILATION
;;;;; don't show compilation warnings
;; keeping warnings on for now to monitor native comp til I'm familiar with it
;; (setq native-comp-async-report-warnings-errors nil)
;;;; PACKAGES setup
(require 'package)
(add-to-list 'package-archives
             '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package)
  (setq use-package-always-defer t)
  (require 'use-package-ensure))

(setq use-package-always-ensure t)

(require 'no-littering)

;;;; PATH from shell
(when (memq window-system '(mac ns x))
  (exec-path-from-shell-initialize))

;;;; PERFORMANCE
;;;;; garbage collection
(defun gc-restore-defaults ()
  (setq gc-cons-threshold 800000
	gc-cons-percentage 1.0)
  (gcmh-mode -1))

;; note that GC was essentially turned off during start up
;; use gcmh to reset garbage collection
(use-package gcmh
  :hook
  (after-init . gcmh-mode)
  :config
  (setq gcmh-idle-delay 'auto  ; default is 15s
	gcmh-high-cons-threshold (* 16 1024 1024)  ; 16mb
	gcmh-verbose nil
	gcmh-auto-idle-delay-factor 10))

;; defer gc while in the minibuffer
(defun config:defer-gc ()
  (setq gc-cons-threshold most-positive-fixnum))
(defun config:-do-restore-gc ()
  (setq gc-cons-threshold 16777216))
(defun config:restore-gc ()
  (run-at-time 1 nil #'config:-do-restore-gc))

(add-hook 'minibuffer-setup #'config:defer-gc)
(add-hook 'minibuffer-exit #'config:restore-gc)

;;;;; monitoring init
;; ;; check which packages are slow to load/config
;; (setq use-package-verbose t
;;       use-package-minimum-reported-time 0.005)

;; ;; check where init is slow to load
;; (use-package benchmark-init
;;   :demand t
;;   :init
;;   ;; To disable collection of benchmark data after init is done.
;;   ;; third arg is DEPTH: 100 means FUNCTION is added at the end of the hook list
;;   (add-hook 'after-init-hook #'benchmark-init/deactivate 100))

;;;; local PACKAGES and functionalities
(use-package all-the-haikus
  :load-path "custom/packages/all-the-haikus/")

;; useful for when I'm working on my own packages and need to update
(defun reload-package-from-file (&optional arg)
  (interactive "spackage name: ")
  (delete-package-quietly (intern arg))
  (call-interactively 'package-install-file))

(defun delete-package-quietly (arg)
  (condition-case nil
      (package-delete (cadr (assq arg package-alist)))
    (error (message "error while deleting, most likely had already deleted"))))

;;;; appearance: SIZING, FRAMES, WINDOWS, THEMES
;;;;; startup
;; choose default theme based on time of day
(defun default-theme ()
  (if (not window-system)
      #'modus-vivendi
    (let ((hour (nth 2 (decode-time (current-time)))))
      (if (or (> hour 23) (< hour 8))
	  #'modus-vivendi ; at night
        #'my-monokai)))) ; during the day

(use-package mood-line)

(defun startup-look ()
  "Set (or restore) the initial appearance."
  (interactive)
  ;; NOTE getting some weird behavior when calling this:
  ;; Invalid face box: :color, "#64645E", :line-width, 1, :style, unspecified
  ;; (funcall (default-theme))
  ;; if not already maximized, maximize
  (or (eq (frame-parameter (selected-frame) 'fullscreen) 'maximized)
      (toggle-frame-maximized))
  ;; TODO `mood-line-mode' doesn't work well with PDF View: it doesn't
  ;; display the current page-number and the total number of pages.
  (mood-line-mode t)
  (scroll-bar-mode -1)
  (electric-pair-mode)
  (global-visual-line-mode t)
  (set-fringe-style '(2 . nil))
  (pixel-scroll-precision-mode t)
  (setq-default indent-tabs-mode nil)
  (setq blink-cursor-blinks 5
        fast-but-imprecise-scrolling t
        column-number-mode t
        use-short-answers t))

(add-hook 'after-init-hook #'startup-look -99)

;;;;; close
(add-hook 'kill-emacs-hook (lambda () (setq inhibit-message t)) -99)

;;;;; windows
(defun window-vertically-split-p (&optional window)
  (let ((height (window-height window)))
    (< height (- (frame-height) 1))))

;;;;; dashboard
(use-package dashboard
  :if window-system
  :autoload dashboard-insert-startupify-lists
  :init
  (require 'all-the-haikus)
  (require 'all-the-icons)
  (defun my-dashboard-init ()
    (setq dashboard-init-info
          (format "Emacs started in %s seconds." (emacs-init-time "%.2f"))))

  (defun dashboard-open ()
    "Open the *dashboard* buffer."
    (interactive)
    (my-dashboard-init)
    (let ((time (current-time))
          ;; Refresh dashboard buffer or just switch to it?
          (already-open (and (boundp 'dashboard-buffer-name)
      		             (get-buffer dashboard-buffer-name))))
      (if (not already-open)
          (progn
            ;; make sure you autoload this function (see above):
            (make-it-quiet
             (dashboard-insert-startupify-lists))
            (message
             "Welcome! Dashboard opened in %.2f seconds"
             (float-time (time-since time)))))
      (switch-to-buffer dashboard-buffer-name)))
  :defer 4

  :config
  (add-hook 'dashboard-mode-hook (lambda () (projectile-mode +1)))

  (add-hook 'dashboard-mode-hook
            (lambda ()
              (local-set-key (kbd "C-<return>")
      		             #'show-haiku-from-line-at-point)))

  (setq dashboard-footer-icon
        (all-the-icons-octicon "book"
      		               :height 1.1
      		               :v-adjust -0.05
      		               :face 'font-lock-keyword-face))
  (defun center-and-propertize-haiku-line (line)
    (dashboard-insert-center (propertize line 'face 'dashboard-footer) "\n"))

  (defun dashboard-insert-footer ()
    "Insert custom haiku-footer for dashboard."
    (let ((footer (car dashboard-footer-messages))
          (footer-heading "Today's haiku:\n"))
      (insert "\n\n")
      (dashboard-insert-center dashboard-footer-icon " "
                               (propertize footer-heading
                                           'face 'dashboard-heading))
      (mapcar #'center-and-propertize-haiku-line (split-string footer "\n"))
      (insert "\n")))

  (defun find-or-write-haiku ()
    (if (nth (random 2) (list nil t))
        (find-me-a-haiku)
      (write-me-a-haiku)))

  (setq dashboard-items '((recents  . 10)
                          (projects . 5)
      		          (bookmarks . 5)
                          (agenda . 5)))
  (setq dashboard-set-heading-icons t)
  (setq dashboard-set-file-icons t)
  (setq dashboard-week-agenda t)
  (setq dashboard-agenda-release-buffers t)
  (setq dashboard-footer-messages (list (find-or-write-haiku)))
  (setq dashboard-startup-banner 'logo))

;;;;; resizing and movement
;; resize current frame
(defalias #'fullscreen-frame #'toggle-frame-fullscreen)

(defun big-frame (&optional fullscreen)
  (interactive "P")
  (if fullscreen (toggle-frame-fullscreen)
    (toggle-frame-maximized)))

;; make current window bigger or smaller
(defun wbig (&optional arg)
  (interactive "P")
  (let ((arg (or arg 25)))
    (enlarge-window-horizontally arg)
    (message "expanded window by %s columns" arg)))

(defun wsmall (&optional arg)
  (interactive "P")
  (let ((arg (or arg 25)))
    (shrink-window-horizontally arg)
    (message "reduced window by %s columns" arg)))

;; frame to have together with max youtube
(defun yt-frame (&optional arg)
  (interactive "P")
  (when arg (make-frame))
  (treemacs-close-and-other-windows t)
  (let ((frame (selected-frame)))
    (when (memq (frame-parameter frame 'fullscreen) '(fullscreen fullboth))
      (toggle-frame-fullscreen))
    (when (eq (frame-parameter frame 'fullscreen) 'maximized)
      (toggle-frame-maximized)))
  (set-frame-size (selected-frame) 84 60)
  (right-frame))

(defun right-frame ()
  (interactive)
  (let ((available-width
	 (nth 3 (nth 1 (nth 0 (display-monitor-attributes-list))))))
    (set-frame-position
     (selected-frame) (- available-width (frame-outer-width)) 0)))

(defun left-frame ()
  (interactive)
  (set-frame-position (selected-frame) 0 0))

(defun delete-window-above ()
  (interactive)
  (windmove-up)
  (delete-window))
(defun delete-window-below ()
  (interactive)
  (windmove-down)
  (delete-window))

(defun other-frame-or-make (&optional arg)
  "Switch to `other-frame'. With prefix ARG, `make-frame'"
  (interactive "P")
  (if arg
      (make-frame)
    (other-frame 1)))

(global-set-key (kbd "C-x <up>") #'delete-window-above)
(global-set-key (kbd "C-x <down>") #'delete-window-below)
(global-set-key (kbd "M-o") #'other-frame-or-make)

;;;;; themes and colors
;; TODO: there's a problem in emacs30 with themes:
;; face-spec-set-2: Invalid face box: :color, "#64645E", :line-width, 1, :style, unspecified
(defun un-theme (&optional arg)
  "Disable all custom themes and load theme ARG."
  (interactive (list (intern
                      (completing-read "New theme: "
                                       (mapcar #'symbol-name
				               (custom-available-themes))))))
  (mapc #'disable-theme custom-enabled-themes)
  (if arg (load-theme arg)
    (call-interactively #'load-theme)))

(use-package cyberpunk-theme)

(defun my-misterioso ()
  (interactive)
  (un-theme 'my-misterioso))

(defun my-monokai (&optional arg)
  (interactive "P")
  (un-theme 'my-monokai)
  (if arg
      (un-theme 'my-monokai)
    (progn (un-theme 'cyberpunk)
           (load-theme 'my-monokai))))

(defun tango-dark ()
  (interactive)
  (un-theme 'tango-dark))
(defun cyberpunk  ()
  (interactive)
  (un-theme 'cyberpunk))
(defun modus-vivendi ()
  (interactive)
  (un-theme 'modus-vivendi))

(defun cloud-theme ()
  (interactive)
  (un-theme 'cloud))

;; this highlights characters beyond the 80 char limit
(use-package whitespace
  :init
  ;; shortcut
  (defalias #'wspace #'whitespace-mode)
  :config
  (setq whitespace-style '(face lines-tail trailing)))

;; long line to test whitespace-mode:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;; icons
(use-package all-the-icons)

;;;;; appearance for specific modes

(add-hook 'package-menu-mode-hook
	  (lambda ()
	    (hl-line-mode t)
	    (visual-line-mode -1)
	    (setq-local truncate-lines t)))

(add-hook 'csv-mode-hook
	  (lambda () (visual-line-mode -1) (setq-local truncate-lines t)))

;; (define-key help-mode-map "b" #'help-go-back)
;; (define-key help-mode-map "f" #'help-go-forward)
(use-package help-mode
  :load-path
  lisp-directory
  :init
  (setq help-window-select t)
  :bind
  (:map help-mode-map
        ("b" . help-go-back)
        ("f" . help-go-forward)))

;; json files
(defun show-paren-full-matching-sexp ()
  "Toggle `show-paren-style' between 'parenthesis and 'expression"
  (interactive)
  (if (eq show-paren-style 'expression)
      (setq-local show-paren-style 'parenthesis)
    (setq-local show-paren-style 'expression)))

(add-to-list 'auto-mode-alist '("\\.jsonl\\'" . json-mode))

(defun json-pretty-print-if-scratch ()
  (when (and (equal "*scratch*" (buffer-name (current-buffer)))
	     (y-or-n-p "format this json doc?"))
    (json-pretty-print-buffer)))

(use-package json-mode
  :config
  :hook
  (json-mode . hs-minor-mode)
  (json-mode . json-pretty-print-if-scratch)
  :bind (:map json-mode-map
	      ("C-c C-s" . show-paren-full-matching-sexp)
	      ("C-c C-h" . hs-toggle-hiding)
	      ("C-c C-l" . hs-hide-level)
	      ("C-c C-b" . json-pretty-print-buffer)))

;;;; ORG mode
(use-package org
  :defer 5
  :config

  ;; track progress
  (setq org-todo-keywords
        '((sequence "TODO" "PROG" "|" "DONE")))

  ;; the PROG keyword doesn't have a default face: set it here
  (setq org-todo-keyword-faces
        (quote (("PROG" :foreground "light blue" :weight bold))))

  ;; this is a nice feature
  ;; but it can slow emacs down with certain optimized JIT-lock settings
  (setq org-hide-emphasis-markers t)

  ;; better bullet-points
  (font-lock-add-keywords #'org-mode
                          '(("^ +\\([-]\\) "
                             (0 (prog1 ()
				  (compose-region (match-beginning 1)
						  (match-end 1) "•"))))))

  ;; most of the time I don't use this, so I'm keeping the default
  ;; nil. If needed, it can be set on a per-file basis
  (setq org-log-done nil)

  (setq vc-follow-symlinks t)
  (setq org-agenda-files '(
                           "~/org/TODO.org"
                           "~/org/ToBuy.org"
                           "~/org/chtu_todo.org"
                           "~/org/saved_links.org"
                           "~/org/journal/current_journal_file.org"))

  ;; TODO `org-open-at-point' should be able to use search options
  ;; (see here: https://orgmode.org/manual/Search-Options.html)
  ;; but I'm having trouble setting that up
  (defun org-headline-text ()
    "Return the text of the current headline.
Return nil if not applicable."
    (nth 4 (ignore-errors
	     (org-heading-components))))

  (defun my-org-tab ()
    "If current line is a heading or a property, call regular org-cycle;
    else, first move to previous visible heading, then call it"
    (interactive)
    (move-beginning-of-line 1)
    (when (save-excursion
            (not (looking-at
                  (concat org-outline-regexp "\\|" org-property-re))))
      (org-previous-visible-heading 1))
    (org-cycle))

  (defun open-file-same-window () (interactive)
	 (setf (cdr (assoc 'file org-link-frame-setup))
	       #'find-file)
	 (org-open-at-point)
	 (setf (cdr (assoc 'file org-link-frame-setup))
	       #'find-file-other-window))

  ;; tinkering with this to try to make it not clash with delete-selection-mode
  (defun electric-fontify-will-use-region-p ()
    (setq to-fontify
	  (let ((fontify-list '(?* ?/ ?_ ?= ?~ ?+)))
	    (and (derived-mode-p 'org-mode) mark-active
		 (member last-command-event fontify-list)))))

  (add-hook 'self-insert-uses-region-functions
            #'electric-fontify-will-use-region-p)

  (defun electric-fontify ()
    "If in org-mode (or a derived mode),
when a region is highlighted and we've inserted a character that fontifies text,
the whole region is fontified (by automatically inserting character at mark)"
    (if (and (boundp 'to-fontify) to-fontify)
	(progn (exchange-point-and-mark)
	       (insert last-command-event)
	       (makunbound 'to-fontify))))
  (add-hook 'post-self-insert-hook #'electric-fontify)

  (defun org-link-at-point ()
    "Copy the link at point, message it in the minibuffer, and return it"
    (interactive)
    (let* ((props (text-properties-at (point)))
           (link (plist-get (plist-get props 'htmlize-link) :uri)))
      (if link
          (progn (kill-new link)
                 (message "%s %s"
                          (propertize "copied:" 'face 'minibuffer-prompt)
                          link)
                 link)
        (progn (message (propertize "No link found at point" 'face
                                    'minibuffer-prompt))
               nil))))

  ;; ensure we can pick up a link in org:
  ;; xwidget-webkit uses (thing-at-point 'url):
  ;; TODO: this functionality should be added to eww as well
  (advice-add 'thing-at-point :after-until
              (lambda (thing &optional no-properties)
                (when (eq thing 'url)
                  (org-link-at-point))))

  (defun my/org-post-structure-template (&optional _type)
    "advice to use after `org-insert-structure-template':
after having written the structure, make sure we also add a newline so we can
    start writing the contents"
    ;; if region is active, we are adding the structure *around* existing
    ;; content, so no need to make room for it
    (unless (region-active-p)
      ;; TODO make the search non-case-sensitive
      (let* ((end-of-template-string "#+end_")
	     (end-of-template-rgx (concat
				   (regexp-quote end-of-template-string)
				   ".*\n"))
	     (line (progn
		     (search-forward end-of-template-string)
		     (thing-at-point 'line)))
	     (whitespace (replace-regexp-in-string end-of-template-rgx
						   ""
						   line)))
	;; TEMP for debugging
	;; (message "line: '%s'" line)
        ;; (message "whitespace: '%s'" whitespace)
	(beginning-of-line)
	(left-char)
	(insert
	 (concat "\n" whitespace)))))

  (advice-add #'org-insert-structure-template :after
	      'my/org-post-structure-template)

  ;; KLUDGE this ensures that org-links generated with org-ql queries work right away
  (load (file-name-concat
         (file-name-directory (locate-library "org-ql"))
         "org-ql-search.el"))

  (defun my/org-previous (&optional up-element)
    "With prefix arg UP-ELEMENT, `org-up-element',
else `org-previous-visible-heading'"
    (interactive "P")
    (if up-element
	(org-up-element)
      (org-previous-visible-heading 1)))

  (defun my/org-next (&optional element)
    "With prefix arg ELEMENT, `org-forward-element',
else `org-next-visible-heading'"
    (interactive "P")
    (if element
	(org-forward-element)
      (org-next-visible-heading 1)))

  :hook
  (org-mode . org-indent-mode)
  (org-mode . turn-on-flyspell)
  (org-mode . electric-pair-local-mode)
  :custom
  ;; allow each org file to set their own preferred image-width
  (org-image-actual-width nil)
  ;; use the absolute path for file links
  (org-link-file-path-type 'absolute)
  ;; display things like \to as arrow etc
  ;; https://emacsdocs.org/docs/org/Special-Symbols
  ;; and invoke `org-entities-help' for a full list of special symbols
  (org-pretty-entities t)
  :bind (("C-c s" . org-store-link)
	 ("C-c l" . org-insert-link)
	 ("C-c a" . org-agenda)
	 :map org-mode-map
	 ("M--" . org-timestamp-down-day)
	 ("M-_" . org-timestamp-down-day)
	 ("M-+" . org-timestamp-up-day)
	 ("C-c o" . open-file-same-window)
	 ("C-M-<backspace>" . org-cut-subtree)
	 ("TAB" . my-org-tab)
         ("C-c p" . my/org-previous)
	 ("C-c n" . my/org-next)))

;;;;; org ql
(use-package org-ql)

;;;;; org roam
(use-package org-roam
  :defer 3
  :config
  (org-roam-db-autosync-mode)

  ;; TEMP hack to avoid templates when using org-capture
  (advice-add #'org-capture :before
              (lambda (&rest r)
                (setq auto-insert nil)))
  (advice-add #'org-capture :after
              (lambda (&rest r)
                (setq auto-insert t)))

  ;; TODO I want to make `org-roam-node-read' NOT case-sensitive

  :custom
  ;; TODO maybe explore somehow adding the work org-roam directory
  ;; here as well? some sort of dual setup where one of the
  ;; directories is opt-in would be ideal, maybe through iCloud
  (org-roam-directory "~/org-roam")
  (org-roam-capture-templates
   '(("d" "default" plain "%?"
      :target (file+head "${slug}.org"
                         "#+title: ${title}\n%T\n")
      :unnarrowed t)))
  ;; (org-roam-database-connector 'sqlite-builtin)
  :bind (("C-c n l" . org-roam-buffer-toggle)
	 ("C-c n f" . org-roam-node-find)
	 ("C-c n i" . org-roam-node-insert)))

;; MAYBE it'd be nice to have the option to "turn tags off" so that
;; they're not always displayed in the graph. Crudest way I can think
;; of is to go through every file and comment-out these tags. Then the
;; tag's own node can stay up, and if there any actual links to those
;; node those can stay up as well. Another possibility is to comment
;; out each tag node, which might be easier to implement but not
;; necessarily the best result
;;
;; Another cool thing could be to display the tags as colors (each
;; node with that tag takes that color?) rather than as links? though
;; not sure how to deal with multiple tags on the same node, would
;; have to think that through
(use-package org-roam-tags
  :load-path "custom/packages/org-roam-tags/"
  :after org-roam

  :config
  (defun my/org-roam-tags-toggle-here ()
    (when
        (search-forward org-roam-tags--file-tags-line-marker
                        nil 'no-error)
      (move-beginning-of-line 1)
      ;; if the current line starts with "# ", then remove it,
      ;; else, insert it
      (if (string-prefix-p "# " (thing-at-point 'line))
          (progn
            (message "removing comment")
            (delete-forward-char 2))
        (message "adding comment")
        (insert "# "))
      ;; TODO need to figure out how to actually make it update the
      ;; info within the graph, the below doesn't seem to work as expected
      (org-roam-ui--update-current-node)))

  (defun my/org-roam-tags-toggle-file (file)
    ;; MAYBE when applied to multiple files in bulk, it might be
    ;; convenient to have the option to force one of the two states
    ;; (tagged or un-tagged) rather than toggle the previous state
    (message "\n")
    (with-temp-file file
      (insert-file-contents file)
      (message file)
      (my/org-roam-tags-toggle-here)))

  (defun my/org-roam-tags-toggle-all ()
    (interactive)
    ;; TODO if the buffer is open, it might be better to do it in the
    ;; buffer directly rather than open a separate temp file for it
    ;; (especially if the file is in the current buffer)
    (mapc #'my/org-roam-tags-toggle-file (org-roam-list-files)))

  ;; TODO how to make sure this keymap is loaded together with org-roam?
  :bind (:map org-mode-map
	      ("C-c q" . org-roam-tags-tag-note)))

(use-package org-roam-ui
  :after org-roam
  :custom
  ;; use `xwidget-webkit' by default
  (org-roam-ui-browser-function #'xw-url)
  ;; NOTE: use `org-roam-ui-open' to see the graph
  :config
  (setq org-roam-ui-sync-theme t
        org-roam-ui-follow t
        org-roam-ui-update-on-save t
        org-roam-ui-open-on-start t))

;;;;; org journal
(use-package org-journal
  :init
  (defun journal ()
    (interactive)
    (let ((result (org-journal-read-or-display-entry (current-time))))
      (when (equal result "No journal entry for this date.")
        (org-journal-open-current-journal-file))))

  :config
  (set-face-attribute 'org-journal-calendar-entry-face
                      nil :inherit 'diary :foreground "yellow")
  (set-face-attribute 'org-journal-calendar-scheduled-face
                      nil :inherit 'diary :foreground "green")
  (autoload #'org-element--cache-active-p (concat lisp-directory
                                                  "org/org-element.el"))

  (defun org-journal-narrow-to-entry (&rest _)
    (save-excursion
      ;; NOTE typically this function is called automatically when
      ;; we're creating a new entry.
      ;; in those cases, we know we'll be under the entry's heading,
      ;; so we need to move up.
      (org-previous-visible-heading 1)
      (org-narrow-to-subtree)))

  ;; a new entry is narrowed to display only that day in the buffer
  (advice-add 'org-journal-new-entry :after #'org-journal-narrow-to-entry)

  ;; NOTE that `org-journal-narrow-to-entry' means that we have to
  ;; widen the buffer when we're looking to read any other date
  ;; we achieve this by adding advice to
  ;; `org-journal--get-entry-path', which is called at the beginning
  ;; of `org-journal-read-entry'
  (defun org-journal-widen-buffer (org-journal-file)
    (when-let (j-buffer (find-buffer-visiting org-journal-file))
      (with-current-buffer j-buffer (widen)))
    org-journal-file)

  (advice-add 'org-journal--get-entry-path
              :filter-return #'org-journal-widen-buffer)

  ;; keep track of when entries are being created.
  ;; NOTE the `org-journal' package uses the "CREATED" property to find
  ;; dates, so that property must match the entry date.
  ;; NOTE also that the same day-entry might have multiple sub-entries
  ;; created on different days: do we want to set the properties for those?
  (defun my/org-journal-set-entry-created-date (&rest _r)
    (org-set-property-to-today "ENTRY_CREATED_ON"))
  (advice-add 'org-journal--insert-entry-header
              :after #'my/org-journal-set-entry-created-date)

  ;; TODO standardize diary entries, maybe write a
  ;; `journal-set-as-diary-entry' function that will set the
  ;; :DIARY-ENTRY property (are boolean properties a good practice?)

  ;; NOTE right now it gets buggy when I try to add multiple entries
  ;; for the same day.
  ;; TODO try to fix this

  ;; default to non-TODO entries
  (defun my/org-journal-new-scheduled-entry (prefix &optional scheduled-time)
    "Create a new entry in the future with an active timestamp.

With non-nil prefix argument create a TODO entry.
Otherwise, create a regular entry.
This function is meant to override the original
`org-journal-new-scheduled-entry', which uses the prefix argument the
other way around. I prefer the default to be a non-TODO entry.

This function is called from within `org-journal-new-date-entry'"
    (interactive "P")
    (let* ((org-time-was-given nil) (org-end-time-was-given nil)
           (time (or scheduled-time (org-time-string-to-time (org-read-date nil nil nil "Date:"))))
           org-journal-carryover-items)
      (when (time-less-p time (current-time))
        (user-error "Scheduled time needs to be in the future"))
      (org-journal-new-entry nil time t)
      (when prefix
        (insert "TODO "))
      (if org-time-was-given
          (insert (format-time-string org-journal-time-format time)))
      (save-excursion
        (insert "\n"
                org-journal-scheduled-string
                (if (> (length org-journal-scheduled-string) 0) " " ""))
        (org-insert-time-stamp
         time org-time-was-given nil nil nil (list
                                              org-end-time-was-given)))))

  (advice-add 'org-journal-new-scheduled-entry
              :override #'my/org-journal-new-scheduled-entry)

  ;; TODO the `read-only-mode' in org-journal is almost never useful
  ;; -- turn it off by default

  :custom
  (org-journal-dir "~/org/journal/")
  (org-journal-file-type 'yearly)
  (org-journal-time-format "")
  (org-journal-created-property-timestamp-format "%Y-%m-%d"))

;;;;; saved links
;; TODO these functionalities could work even better by creating a
;; "saved links" mode inheriting from `org-mode'
(defvar saved-links-file "~/org/saved_links.org"
  "File to store links (typically found inside the org directory)")

(defun org-set-property-to-today (property)
  (interactive (list nil))
  (let ((property (or property (org-read-property-name))))
    (org-set-property property (format-time-string "%Y-%m-%d"))))

(defun link-new ()
  "Create a new link in `saved-links-file'"
  (interactive )
  (find-file saved-links-file)
  (goto-char (point-min))
  (search-forward "* to read")
  (insert "\n** ")
  (insert (read-from-minibuffer "title: "))
  (org-set-property-to-today "CREATED")
  (org-set-tags-command)
  ;; MAYBE there's a better way to go past the properties and start
  ;; editing the contents?
  (search-forward ":END:")
  (end-of-line)
  (insert "\n"))

;; TODO check if we could leverage the existing setup for this
;; https://orgmode.org/manual/Archiving.html
(defun link-archive (with-org-roam-node)
  "Archive the link at point (move it to the archived section of the file).
With prefix arg, also create a corresponding `org-roam' node"
  (interactive "P")
  (org-cut-subtree)
  (goto-char (point-max))
  (org-fold-show-subtree)
  (let ((latest-max (point-max)))
    (goto-char latest-max)
    (yank)
    ;; go back to where the yank started, to make sure we set the
    ;; property & tags for this node's top-level
    (goto-char (1+ latest-max))
    (org-set-property-to-today "ARCHIVED")
    (org-set-tags (delete "Toarchive" (org-get-tags))))
  (when with-org-roam-node
    (link-org-roam-node)))

(defun link-org-roam-node ()
  "Create an org-roam-node for the current link"
  (interactive)
  (let ((links-buffer (current-buffer))
        (_ (org-roam-node-find 'other-window  (org-headline-text)))
        (node-buffer (current-buffer))
        (id (org-entry-get (point) "id")))
    (switch-to-buffer links-buffer)
    (org-fold-show-subtree)
    (org-next-visible-heading 1)
    (left-char)
    (insert (format "\n - [[id:%s][org-roam node]]" id))
    (switch-to-buffer node-buffer)))

;;;; MARKDOWN mode
(use-package markdown-mode
  :init
  (add-to-list 'auto-mode-alist '("\\.mdx\\'" . markdown-mode))

  :config
  ;; preview mode
  ;; NOTE actually it seems the package `gh-md' already does pretty
  ;; much what I needed
  ;; TODO might still be good to make
  ;; `markdown-live-preview-window-xwidget' available for others?
  ;; and do some of the other improvements:
  ;; 1. add logic to save the HTML file in a temp directory, rather
  ;; than the current directory (NOTE this might be tricky and not
  ;; worth the effort: the .HTML needs to have access to the same paths
  ;; as the .md file)
  ;; 2. improve the export logic?
  ;; 3. see if there's an easy way to temporarily disable
  ;; `auto-insert-mode' in situations where we are filling up a
  ;; buffer/file automatically and already know what the expected
  ;; contents look like

  ;; below is an attempt at disabling auto-insert-mode
  ;; (defun adv/disable-auto-insert-mode (func)
  ;;   (message "func: %s" func)
  ;;   (let ((auto-insert-mode nil))
  ;;     (message "auto-insert-mode: %s" auto-insert-mode)
  ;;     (apply func)))

  ;; (advice-add 'markdown-live-preview-export :around
  ;; #'adv/disable-auto-insert-mode)
  (defun markdown-current-heading ()
    "Get the current heading"
    (let* ((heading (save-excursion
		      (unless (string-prefix-p "#" (thing-at-point 'line))
			(markdown-previous-heading))
		      (thing-at-point 'line))))
      (when (string-prefix-p "#" heading)
	heading)))

  (defun markdown-current-heading-as-url-anchor ()
    "Get the current heading and format it so it can be used in a url"
    (when-let ((heading (markdown-current-heading)))
      (string-trim-right (replace-regexp-in-string
			  ;; TODO get (some of) these characters from
			  ;; `markdown-electric-pairs'?
			  ;; TODO not sure if the period . must always be removed
			  "`\\|~\\|\\*\\|:\\|\"\\|\\."
			  ""
			  (string-replace
			   " "
			   "-"
			   ;; NOTE don't remember what the purpose of this
			   ;; replace is (in what situations do we get this "+ "?)
			   (replace-regexp-in-string
			    "#+ "
			    "#"
			    (downcase
			     heading)))))))

  (defun markdown-live-preview-window-xwidget (file)
    "Preview FILE with xwidget.
  To be used with `markdown-live-preview-window-function'."
    (xwidget-webkit-browse-url (concat "file://" file))
    (xwidget-buffer (xwidget-webkit-current-session)))

  (setq markdown-live-preview-window-function
	#'markdown-live-preview-window-xwidget)

  (defvar markdown-electric-pairs
    '((?` . ?`) (?* . ?*) (?~ . ?~))
    "Electric pairs for markdown-mode.")

  (defun markdown-add-electric-pairs ()
    (setq-local electric-pair-pairs
		(append electric-pair-pairs markdown-electric-pairs))
    (setq-local electric-pair-text-pairs electric-pair-pairs))


  :bind
  (:map markdown-mode-map
	;; TODO bind this to a consistent spot for markdown and org?
	("C-c C-," . #'markdown-insert-gfm-code-block)
	;; consistent "open link" keys for org and markdown:
	("C-c o" . #'markdown-follow-thing-at-point))

  :custom
  (markdown-fontify-code-blocks-natively t)

  :hook
  (markdown-mode . turn-on-flyspell)
  (markdown-mode . markdown-add-electric-pairs)
  (markdown-mode . electric-pair-local-mode))


;; TODO: could maybe try to integrate gh-md functionalities into
;; `markdown-live-preview-mode'
;; also potentially use `xwidget-webkit' rather than `eww' to show the buffer
(use-package gh-md
  :init
  (defalias #'gh-md-preview #'gh-md-render-buffer))

;;;; FILE utilities
(setq find-file-visit-truename t) ;; TODO is this better on or off?

(defun latest-file (path &optional skip-copy)
  "Get latest file in PATH.
Call `copy-message-return' on the result. If optional arg SKIP-COPY is non-nil,
  only message and return it."
  (message "Finding latest file in path: %s" path)
  ;; MAYBE enforce that `path' should end with a /
  (let* ((relative-filename
	  (car (split-string
		;; TODO: how to deal with this command failing?
		(shell-command-to-string (format "ls -t %s" path))
		"\n")))
	 (absolute-filename (file-name-concat path relative-filename)))
    (copy-message-return
     (if skip-copy
	 nil
       absolute-filename)
     relative-filename
     absolute-filename)))

(defun downloads-latest ()
  "Open the latest file added to the Downloads directory"
  (interactive)
  (find-file (latest-file "/Users/andyjda/Downloads/")))

(defun list-files-newest-first (directory)
  "List files in `directory', sorted by modification date, newest first."
  (mapcar #'car
	  (sort (directory-files-and-attributes zotero-storage-path)
		#'(lambda (x y) (time-less-p (nth 6 y) (nth 6 x))))))

(defun create-symlink (og-file target-dir &optional new-name)
  "Create a symlink to OG-FILE in TARGET-DIR.
When optional NEW-NAME is non-nil, give the new file this name.
Otherwise, use OG-FILE's relative name."
  (let* ((symlink-output-buffer "*symlink-output-buffer*")
	 (directory (file-name-directory og-file))
	 (relative (file-name-nondirectory og-file))
	 (new-name (or new-name (file-name-concat target-dir relative))))
    (if (file-exists-p new-name)
	(progn
	  (message "File already exists: %s" new-name)
	  (error "attempted symlink on existing file"))
      (progn
	;; TODO look into using `call-process' or `start-process' here instead
	(shell-command
	 (format "ln -s \"%s\" \"%s\"" og-file new-name)
	 symlink-output-buffer)
	;; KLUDGE this is a quite primitive mechanism for verifying that the
	;; command worked
	(let ((output
	       (with-current-buffer symlink-output-buffer
		 (buffer-string))))
	  (message "output: %s" output)
	  (if (length> output 0)
	      (warn output)
	    (message "Created symlinked file %s" new-name)))
	(kill-buffer symlink-output-buffer)))))


(defun symlink ()
  "interactive entry-point to `create-symlink'"
  (interactive)
  (let* ((filename (read-file-name "(original) filename to link to: "))
	 (directory (file-name-directory filename))
	 (relative (file-name-nondirectory filename))
	 ;; ensure `ido' doesn't switch us to the existing file
	 (ido-auto-merge-work-directories-length -1)
	 (target (read-file-name "new link: " nil nil nil relative))
	 (target-dir (file-name-directory target))
	 (new-name (file-name-nondirectory target)))
    (create-symlink filename target-dir new-name)))


;;;;; dialog boxes
(setq use-file-dialog nil)
(setq use-dialog-box nil)
;;;;; open file properly at startup
;; this is already handled properly if the file was passed as CLI argument
;; but if Emacs was opened through the GUI, we have to check the
;; `ns-input-file'
;; TODO it seems tricky to get Emacs to see `ns-input-file' before it opens the
;; initial buffer. The value of `ns-input-file' is not set until
;; pretty late in the startup process. An approach that, for very
;; unclear reasons, seems to work is to put it in a format string:
;; (message "ns-input-file: %s" (car ns-input-file))
;; (and call this a few times for good measure)
;; MAYBE hopefully we can use `advice-add' for a later function?
;; (setq initial-buffer-choice
;;       (with-temp-buffer
;;         (insert (or (car ns-input-file) ""))
;; 	(insert (or (car ns-input-file) ""))
;;         ns-input-file))

;; (advice-add 'command-line-1 :before
;;             (lambda (_args-left)
;;               (setq initial-buffer-choice (car ns-input-file))))

;;;;; load faster
;; these are useful especially in VERY large files
(defun jit-lock-optimize-settings ()
  (interactive)
  (setq jit-lock-defer-time 0.05))

(defun jit-lock-default-settings ()
  (interactive)
  (setq jit-lock-defer-time nil))

;;;;; trash
;; don't rm files with just a couple key-presses
(setq delete-by-moving-to-trash t)

;;;;; file shortcuts
(defmacro define-file-shortcut (name file)
  `(defun ,name ()
     ,(format "Interactive shortcut for %s" (eval file))
     (interactive)
     (find-file ,file)))

(defun define-all-shortcuts (args)
  (eval `(progn ,@(mapcar (lambda (el)
                            `(define-file-shortcut ,(car el) ,(cadr el)))
                          args))))

(define-all-shortcuts
 (list
  '(init user-init-file)
  '(early-init early-init-file)
  '(zshrc "~/.zshrc")
  '(forg "~/org")
  '(beorg "~/Library/Mobile Documents/iCloud~com~appsonthemove~beorg/Documents/org/")
  '(todo "~/org/TODO.org")
  '(todo-emacs "~/org/Emacs.org")
  '(tobuy "~/org/ToBuy.org")
  '(my-modes "~/.emacs.d/custom/modes")
  '(crafting-interpreters "~/CraftingInterpreters")
  '(practice-notebook "~/org/practice_notebook.org")
  '(chtu-todo "~/org/chtu_todo.org")
  '(gym-notes "~/org/gym_exercise_notes.org")
  '(papers-and-notes "~/papers and notes/notes.org")
  '(books "~/org/books.org")
  '(sanctuary "~/org/sanctuary_jam_plan.org")
  '(braxton "~/org/anthony_braxton.org")
  '(jazz-notes "~/org/jazz_notes.org")
  '(links "~/org/saved_links.org")
  '(cooking "~/org/cooking.org")
  '(languages "~/org/language_learning.org")
  '(shows "~/org/shows_to_look_into.org")
  '(jobs "~/org/jobs.org")))

;; open a file in my temp directory
(defun temp ()
  (interactive)
  (find-file (read-file-name "find-file " "~/temp/")))

;;;;; resolve home dir
(defun user-home-dir ()
  (getenv "HOME"))

(defun path-expand-user (path)
  "Expand '~' in a path to the full home directory"
  (string-replace "~" (getenv "HOME") path))

;;;;; dired mode
(use-package all-the-icons-dired
  :after dired
  :hook
  (dired-mode-hook . all-the-icons-dired-mode)
  :bind
  (:map dired-mode-map
	("<mouse-2>" . dired-mouse-find-file))
  :config
  (setq all-the-icons-dired-monochrome nil))

(use-package dired-subtree
  :after dired
  :bind
  (:map dired-mode-map
	("<tab>" . dired-subtree-toggle)
	("<backtab>" . dired-subtree-cycle)))

(use-package dired
  ;; it's weird that I have to use `use-package' here,
  ;; but if I don't I get weird errors telling me `dired-mode-map' is
  ;; not a bound variable (yet) when I try to edit it
  :load-path lisp-directory
  :config
  (defun my-advice-dired-copy-absolute (&rest args)
    "if no arg is passed, return 0.
This used as an advice to `dired-copy-filename-as-kill', reversing its
default behavior:
 - with prefix arg, copy relative name
 - with no prefix arg, copy absolute"
    (if (caar args) args (list 0)))
  (advice-add #'dired-copy-filename-as-kill
	      :filter-args #'my-advice-dired-copy-absolute)
  :custom
  (dired-listing-switches "-alh")
  (dired-kill-when-opening-new-dired-buffer t)
  :bind
  (:map dired-mode-map
        ("E" . wdired-change-to-wdired-mode)))

;; Saved macro
(defalias 'dired-my-move
  ;; this works but not as well as I'd like:
  ;; I'd like to be able to edit the target if needed
  ;; TODO I would like to have a similar situation for a copy as well
  (kmacro "C-u w R"))

;;;;; recent files
(use-package recentf
  :init
  (defun my-recentf-open-files ()
    (interactive)
    (recentf-mode +1)
    (recentf-open-files))

  :defer 3

  :bind* (("C-c C-r" . my-recentf-open-files))
  :config
  (setq recentf-max-menu-items 25
        recentf-max-saved-items 25)

  (nconc recentf-exclude (list
                          (recentf-expand-file-name
                           no-littering-var-directory)
                          (recentf-expand-file-name no-littering-etc-directory)))
  ;; (setq recentf-exclude
  ;;       (append recentf-exclude
  ;;       	'("~/.emacs.d/ido.last" ".*treemacs-persist" "~/.emacs.d/bookmarks")))
  (make-it-quiet
   (recentf-mode))

  (defun my-search-for-read-only-buffers ()
    "Start an isearch with the latest inputted key"
    (interactive)
    (isearch-with-start (char-to-string last-input-event)))

  (defun bind-alpha-keys (keymap function)
    "Bind all alphabetical keys to FUNCTION in KEYMAP."
    (let ((alpha-chars (append
			(string-to-list "abcdefghijklmnopqrstuvwxyz")
			(string-to-list "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
			(string-to-list ",./;:"))))
      (dolist (char alpha-chars)
        (define-key keymap (char-to-string char) function))))

  ;; all alphabetical characters are bound to the search function
  ;; this way, when in a recentf-dialog buffer:
  ;; all digits will select a specific file
  ;; all letters will open a search for the specific file
  (bind-alpha-keys recentf-dialog-mode-map 'my-search-for-read-only-buffers)

  :hook (recentf-dialog-mode . hl-line-mode))

;;;;; projectile mode
(use-package projectile
  :defer 6
  :config
  (setq
   projectile-switch-project-action #'projectile-dired-other-window)
  (advice-add #'project-shell :after #'python-activate-venv-in-shell)
  :bind (:map projectile-mode-map
	      ("s-p" . projectile-command-map)))

;;;;; iCloud functionalities
(use-package icloud
  :load-path "custom/packages/icloud-utilities/"
  :custom
  (icloud-default-open-function (if ido-mode #'ido-find-file #'find-file))
  :defer 1)

;;;;; restart
;; with lots of inspiration from this
;; https://github.com/iqbalansari/restart-emacs
;; this is kind of hacky right now
;; some potential improvements:
;; keep better track of the initial `command-line-args', so that for example
;; it'd be easier to restart in terminal or not depending on the situation?
(defun quick-restart--gui-using-sh (&optional args)
  "Start GUI version of Emacs using sh.

ARGS is the list arguments with which Emacs should be started, including the
  Emacs binary."
  (let ((formatted (format "%s &"
                           (string-join (mapcar #'shell-quote-argument
                                                args)
                                        " "))))
    (call-process "sh" nil
                  0 nil
                  "-c" formatted)))

(defun quick-restart (&optional file)
  "Restart Emacs by opening FILE"
  (interactive)
  (when-let*
      ;; NOTE that this actually will always return non-nil
      ;; TODO find a viable way to allow for nil responses
      ((file (or file
		 (read-file-name "Restart by opening file: ")))
       ;; NOTE not sure if it makes sense to let the user defined many options
       ;; here. It wouldn't make sense to specify '-nw' from within a GUI for
       ;; example, because the new process would like a TUI to start in.
       ;; (options (read-string "options: "))
       (command-line-args (list (car command-line-args)
				"--file" file
				;; options
				)))
    ;; (message "command-line-args: %s" command-line-args)
    ;; TODO this isn't working properly: clearly the `restart-emacs' actually gets
    ;; the `command-line-args' from somewhere else?
    ;; look into the approach used here:
    ;; https://github.com/iqbalansari/restart-emacs
    ;; (restart-emacs)
    (let ((kill-emacs-hook (append kill-emacs-hook
				   (list (apply-partially #'quick-restart--gui-using-sh
							  command-line-args)))))
      (kill-emacs))))


;;;; TEXT EDITING and keyboard commands
;;;;; keys
;; allow more flexibility by binding the right-side cmd-key to C-
(setq ns-right-command-modifier 'control)

;;;;; utilities
(defun copy-message-return (it &optional it-message it-return)
  "Handy function to perform these three actions together.
Copy a string, message IT in the minibuffer, and return IT.
IT is the string, optional arguments IT-MESSAGE and IT-RETURN can be used to
  have different behavior for each action: when nil, they default to IT.
IT-MESSAGE can be a string or a list starting with a format string followed by
its arguments"
  (kill-new it)
  (let ((it-message (or it-message it)))
    (if (listp it-message)
	(apply #'message it-message)
      (message it-message)))
  (or it-return it))

(defun dwim-move-beginning-of-line (&optional arg)
  "Move point back to indentation of beginning of line.
  `move-beginning-of-line' but smarter.

  Move point to the first non-whitespace character on this line.
  If point is already there, move to the beginning of the line.
  Effectively toggle between the first non-whitespace character and
  the beginning of the line.

  If ARG is not nil or 1, move forward ARG - 1 lines first.  If
  point reaches the beginning or end of the buffer, stop there."
  (interactive "^p")
  (setq arg (or arg 1))

  (when (/= arg 1)
    (let ((line-move-visual nil))
      (forward-line (1- arg))))

  (let ((orig-point (point)))
    (back-to-indentation)
    (when (= orig-point (point))
      (move-beginning-of-line 1)))
  (point))

;; remap C-a to 'dwim-move-beginning-of-line'
(global-set-key (kbd "\C-a") #'dwim-move-beginning-of-line)

;; when typing in selected region, delete it
(delete-selection-mode t)

;; kill and copy
(defun my-kill-whole-line (&optional arg)
  "Delete the line and, when appropriate, preceding newline.
If ARG not provided or ARG > 1, first move to the beginning of the line,
so we will delete the whole line. Then kill ARG lines.
Then, delete all preceding whitespace."
  (interactive "P")
  (if (or (not arg) (> arg 1))
      (move-beginning-of-line 1))
  (kill-line (or arg
		 ;; if the current line is just whitespace, set arg to 0
		 (when (looking-at "^\\s-*$")
		   0)))
  (when (eq (char-before) ?\C-j) ; newline
    (delete-char -1))
  (delete-horizontal-space 'backwards))

(defun dwim-kill-line (&optional arg)
  "If highlighted, `kill-region', else `my-kill-whole-line'"
  (interactive "P")
  (if mark-active
      (kill-region (region-beginning) (region-end))
    (my-kill-whole-line arg)))

(global-set-key (kbd "C-k") #'dwim-kill-line)

(defun copy-current-line ()
  (let ((orig-point (point)))
    (kill-ring-save (dwim-move-beginning-of-line)
		    (line-end-position))
    (goto-char orig-point))
  (message "%s %s"
           (propertize "copied current line:" 'face 'minibuffer-prompt)
           (current-kill 0))
  (current-kill 0))

(defun dwim-copy ()
  (interactive)
  (if (not mark-active)
      (copy-current-line)
    (kill-ring-save (region-beginning) (region-end))))

(global-set-key (kbd "M-w") #'dwim-copy)

(defun dwim-kill ()
  (interactive)
  (if (not mark-active)
      (progn
        (kill-region (dwim-move-beginning-of-line)
		     (line-end-position))
        (message "%s %s"
                 (propertize "cut line:" 'face 'minibuffer-prompt)
                 (current-kill 0)))
    (kill-region (region-beginning) (region-end))))

(global-set-key (kbd "C-w") #'dwim-kill)

(defun query-delete-line (arg)
  (interactive "sbeginning of line to delete: ")
  (query-replace-regexp
   (concat "\n"
	   "\s*"
	   arg
	   ".*$")
   ""))

(defun current-line-empty-p ()
  "Check if the current line contains nothing but whitespace"
  (save-excursion
    (beginning-of-line)
    (looking-at-p "[[:blank:]]*$")))

;; TODO: due to some changes in how `inhibit-message' works,
;; this macro no longer works
(defmacro make-it-quiet (&rest body)
  `(let ((inhibit-message t))
     (progn ,@body)
     ;; if message aren't actually inhibit, use this to clear the echo area:
     (message nil)))

(defun region-at-point ()
  (thing-at-point 'region 'no-properties))

(defun replace-in-list (to-replace replacement list)
  "Return a new list, replacing TO-REPLACE with REPLACEMENT in LIST.
If REPLACEMENT is a list, each element is inserted.
If TO-REPLACE is not found in LIST, return LIST unaltered"
  (let ((pos (seq-position list to-replace)))
    (if pos
        (append (take pos list)
                (if (sequencep replacement) replacement (list replacement))
                (cdr (nthcdr pos list)))
      list)))

(defun regexp-all-matches (regexp string &optional capture-group-n)
  "Get a list of all regexp matches in a string"
  (save-match-data
    (let ((capture-group-n (or capture-group-n 0))
          (pos 0)
          matches)
      (while (string-match regexp string pos)
        (push (match-string capture-group-n string) matches)
        (setq pos (match-end capture-group-n)))
      matches)))

(add-hook 'kill-emacs-hook (lambda () (setq inhibit-message t)) -99)

(add-hook 'emacs-lisp-mode-hook
          (lambda ()
	    (local-set-key (kbd "M-<up>")
			   #'move-line-up)
	    (local-set-key (kbd "M-<down>")
			   #'move-line-down))
	  99)

;;
(defun count-total-lines ()
  (interactive)
  (message "Buffer '%s' has %d total lines"
	   (buffer-name (current-buffer))
	   (count-lines (point-min) (point-max))))

(global-set-key (kbd "C-x l") #'goto-line)

;; upcase and downcase
(put 'upcase-region 'disabled nil)
(put 'downcase-region 'disabled nil)

;; narrowing
(put 'narrow-to-region 'disabled nil)

(defun on-region-or-char (command)
  (unless mark-active
    (progn
      (set-mark-command nil)
      (forward-char 1)))
  (funcall command (region-beginning) (region-end))
  (buffer-substring (region-beginning) (region-end)))

(defun my-smart-upcase (&optional only-first-chars)
  "If region is selected, `upcase-region', else `upcase-char'.
With prefix-argument ONLY-FIRST-CHARS, use `capitalize-dwim' to only capitalize
  the first character in each word (at point, or in the selected region).
Print a message to alert of the capitalization"
  (interactive "P")
  (if only-first-chars
      (capitalize-dwim 1)
    (if mark-active
	(upcase-region (region-beginning) (region-end))
      (upcase-char nil)))
  (message "CAPITALIZED %s, %s"
	   (thing-at-point
	    (if mark-active
		'region
	      'word))
	   (what-line)))

(defun my-smart-downcase ()
  "If region is selected, `downcase-region', else `downcase-char'.
Print a message to alert of the capitalization"
  (interactive)
  (if mark-active
      (downcase-region (region-beginning) (region-end))
    (downcase-region (point) (progn (forward-char) (point))))
  (message "downCASED %s, %s"
	   (thing-at-point
	    (if mark-active
		'region
	      'word))
	   (what-line)))

(global-set-key (kbd "C-x C-u") #'my-smart-upcase)
(global-set-key (kbd "C-x C-l") #'my-smart-downcase)

;; move lines
(defalias 'move-line-up
  (kmacro "C-e C-SPC C-a C-w C-SPC <up> C-e <backspace> C-a C-y <return> <up>"))
(global-set-key (kbd "M-<up>") #'move-line-up)

(defalias 'move-line-down
  (kmacro "C-e C-SPC C-a C-w <down> C-a C-SPC <up> C-e <backspace> C-e <return> C-y"))

(global-set-key (kbd "M-<down>") #'move-line-down)

;; disable mouse-wheel-text-scale, as it can get in the way and is rarely needed
(defun my-scroll (e)
  (interactive "e")
  (if (and (boundp 'pixel-scroll-precision-mode)
	   pixel-scroll-precision-mode)
      (pixel-scroll-precision e)
    (mwheel-scroll e)))

(global-set-key (kbd "C-<wheel-down>") #'my-scroll)
(global-set-key (kbd "C-<wheel-up>") #'my-scroll)

(use-package avy
  :bind (("s-'" . avy-goto-char-2)
	 ("C-'" . avy-goto-char-2)
	 ("s-0" . avy-goto-word-0)))

;; better text-navigation, especially with god-mode
(global-set-key (kbd "C-b") #'left-word)
(global-set-key (kbd "C-f") #'right-word)


;; save clipboard contents to kill-ring
(setq save-interprogram-paste-before-kill 1000)

(defun word-count ()
  (interactive)
  (message "Buffer has %s words" (count-words (point-min) (point-max))))

;;;;; undo
;; make sure you use the better keyboard command
(global-set-key (kbd "C-x u")
                (lambda ()
                  (interactive)
                  (warn "to UNDO, use C-/ or other, not C-x u")))

;;;;;; visual undo
(use-package vundo
  :config
  (setq vundo-glyph-alist vundo-unicode-symbols)
  (add-hook 'vundo-pre-enter-hook
            (lambda ()
              (garbage-collect-maybe 5)
              (setq gc-cons-threshold most-positive-fixnum)))
  (advice-add 'vundo :after
              (lambda ()
                (setq gc-cons-threshold 16777216)))) ; 16mb

;;;;; flyspell
(use-package flyspell
  :custom
  (flyspell-mark-duplications-flag nil)
  :bind (:map flyspell-mode-map
	      ("<mouse-3>" . flyspell-correct-word)
	      ("C-c f" . flyspell-correct-word-before-point)))

;;;;; search

(defun isearch-with-start (str)
  "Start an isearch with STR"
  (isearch-resume str nil nil t str t))

(setq isearch-lazy-count t) ;; shows the number of total matches in the minibuffer

;; from beginning of document
(defun isearch-from-top (&optional regexp-p)
  (interactive "P")
  (push-mark) ; save the place where search started
  (goto-char (point-min))
  (isearch-forward regexp-p)
  ;; isearch sets the mark to the beginning of the search
  ;; in our case that's useless (just the beginning of the buffer)
  ;; so we pop that
  (pop-mark))

(global-set-key (kbd "M-s") #'isearch-from-top)

;; from end of document
(defun isearch-from-bottom (&optional regexp-p)
  (interactive "P")
  (push-mark) ; save the place where search started
  (goto-char (point-max))
  (isearch-backward regexp-p)
  ;; isearch sets the mark to the beginning of the search
  ;; in our case that's useless (just the end of the buffer)
  ;; so we pop that
  (pop-mark))

(global-set-key (kbd "M-r") #'isearch-from-bottom)

;; use C-u C-SPC to get back to where search started

;;;;; comments
;; copy line/region and comment it out
(defun region-copy-comm ()
  (interactive)
  (kill-ring-save nil nil 'region)
  (comment-dwim nil)
  (message "(un)commented region has been copied"))
(defun line-copy-comm ()
  (interactive)
  (kill-ring-save (line-beginning-position) (line-end-position))
  (comment-line 1)
  (message "(un)commented line has been copied"))
(defun copy-comm ()
  (interactive)
  (if mark-active
      (region-copy-comm)
    (line-copy-comm)))

;; if I call comment with no active region, comment the line
(defun smart-comment ()
  (interactive)
  (if mark-active
      (comment-dwim nil)
    (comment-line 1)))
;; remap M-; to `smart-comment'
(global-set-key (kbd "M-;") #'smart-comment)

(defun query-comment-out (arg)
  (interactive "sstring to comment out: ")
  (query-replace arg (concat comment-start arg)))

(defun query-uncomment (arg)
  (interactive "sstring to uncomment: ")
  (let ((commented-arg (concat comment-start arg)))
    (query-replace commented-arg
		   (string-replace comment-start "" commented-arg))))

(defun comment-out-all (arg)
  (interactive "sstring to comment out: ")
  (while (search-forward-regexp (concat "^[[:space:]]*" arg) nil 'noerror)
    (replace-match (concat comment-start arg)))
  (message "commented-out all lines starting with %s" arg))

(defun uncomment-all (arg)
  (interactive "sstring to uncomment: ")
  (let ((commented-arg (concat comment-start arg)))
    (while (search-forward commented-arg nil 'noerror)
      (replace-match (string-replace comment-start "" commented-arg)))
    (message "uncommented all lines starting with %s" commented-arg)))

;;;;; autocomplete
(use-package company
  :init
  (global-company-mode t)
  :config
  (setq company-dabbrev-downcase nil)
  :bind (:map company-mode-map
	      ("s-RET" . company-abort)))

;;;;; macros
(defun save-macro (name)
  "Save the current macro as named function definition
inside your init file so you can reuse it anytime in the
future."
  (interactive "SSave Macro as: ")
  (name-last-kbd-macro name)
  (save-excursion
    (init)
    (goto-char (point-max))
    (insert "\n\n;; Saved macro\n")
    (insert-kbd-macro name)
    (insert "\n")))

;;;;; god mode
(use-package god-mode
  :config
  (require 'mood-line)
  (advice-add #'mood-line-segment-major-mode :filter-return
	      (lambda (arg)
		(if (bound-and-true-p god-local-mode)
		    (concat "💪⚡" arg)
		  arg)))
  ;; :bind
  ;; I'm out of practice with god-mode, better to avoid triggering it for now
  ;; ("<escape>" . god-mode-all)
  ;; ("s-<escape>" . god-local-mode)
  ;; ("M-<escape>" . god-execute-with-current-bindings)
  ;; ("C-z" . god-mode-all)
  ;; ("C-s-z" . god-local-mode)
  ;; ("C-M-z" . god-execute-with-current-bindings)
  )

;;;; BUFFER AND FRAME movements
(use-package ibuffer
  :config
  (setq ibuffer-directory-abbrev-alist
        (list
         (cons "^/Users/andrewdeangelis" "~")
         (cons "^/Applications/Emacs.app/Contents/Resources/lisp" "Emacs.app/.*/lisp")))
  :bind (("C-x C-b" . ibuffer)
	 :map ibuffer-name-map
	 ("<mouse-1>" . ibuffer-visit-buffer)))

(use-package all-the-icons-ibuffer
  :after (all-the-icons ibuffer)
  :config
  ;; increase size of 'name' column
  (define-ibuffer-column size-h
    (:name "Size" :inline t)
    (cond
     ((> (buffer-size) 1000000) (format "%7.1fM" (/ (buffer-size) 1000000.0)))
     ((> (buffer-size) 1000) (format "%7.1fk" (/ (buffer-size) 1000.0)))
     (t (format "%8d" (buffer-size)))))
  (setq all-the-icons-ibuffer-formats
        `((mark modified read-only ,(if (>= emacs-major-version 26) 'locked "")
		;; Here you may adjust by replacing :right with :center or :left
		;; According to taste, if you want the icon further from the name
		" " ,(if all-the-icons-ibuffer-icon
			 '(icon 2 2 :left :elide)
                       "")
		,(if all-the-icons-ibuffer-icon
		     (propertize " " 'display `(space :align-to 8))
		   "")
		(name 27 27 :left :elide)
		" " (size-h 9 -1 :right)
		" " (mode+ 16 16 :left :elide)
		" " filename-and-process+)
	  (mark " " (name 16 -1) " " filename))))
(add-hook 'ibuffer-mode-hook #'all-the-icons-ibuffer-mode)

(global-set-key (kbd "M-m") 'switch-to-minibuffer)

;; use S-right and S-left to navigate buffers
(when (fboundp 'windmove-default-keybindings)
  (windmove-default-keybindings))

;; turn off M-i = TAB in minibuffer
(define-key minibuffer-local-map (kbd "M-i") "i")

;; find buffer by substring and switch to it
(defun buffer-name-matchp (arg-s arg-b)
  (string-match-p arg-s (buffer-name arg-b)))
(defun get-matching-buffers (arg)
  "Find all buffers whose name contains ARG."
  (seq-filter
   (apply-partially #'buffer-name-matchp arg) (buffer-list)))

;;;; SPEEDBAR & TREEMACS
(use-package sr-speedbar
  :init
  (defun bar-toggle ()
    (interactive)
    (sr-speedbar-toggle))
  (defun bar-open ()
    (interactive)
    (sr-speedbar-open))
  :config
  (defun bar-close ()
    (interactive)
    (sr-speedbar-close))
  (defun bar-refresh ()
    (interactive)
    (sr-speedbar-refresh-turn-on))

  (setq speedbar-show-unknown-files t)

  ;; expand functionalities:
  ;; these 3 functions, plus the built-in
  ;; speedbar-expand-line-descendants & speedbar-contract-line
  ;; allow you to navigate the directory tree in multiple ways
  (defun depth-expand ()
    "Open the directory at line, and keep opening its first subdirectory
until we reach a directory with no subdirectories"
    (interactive)
    (setq line-move-visual nil)
    (point-to-register 'sr)
    (setq expanded-by 'depth)
    (let ((dir-regexp "\\([0-9]:\\)*\\s-*<\\(-\\|\\+\\)>.*"))
      (move-beginning-of-line 1)
      (while (looking-at dir-regexp)
	(speedbar-expand-line)
	(forward-line 1)
	(move-beginning-of-line 1))))

  (defun breadth-expand ()
    "Open the directory at line, and open all its subsequent siblings
(directories that are at its same depth)"
    (interactive)
    (message "expanding by breadth")
    (point-to-register 'sr)
    (setq expanded-by 'breadth)
    (move-beginning-of-line 1)
    (let ((dir-regexp "\\([0-9]:\\)*\\s-*<\\(-\\|\\+\\)>.*"))
      (while (looking-at dir-regexp)
	(speedbar-expand-line)
	(speedbar-restricted-move 1)
	(move-beginning-of-line 1)))
    (message "opened all directories at this level"))

  (defun breadth-contract ()
    "Collapse the directory at line, and close all its subsequent
open siblings (directories at its same depth)"
    (interactive)
    (message "closing all directories at this level")
    (move-beginning-of-line 1)
    (let ((dir-regexp "\\([0-9]:\\)*\\s-*<\\(-\\|\\+\\)>.*"))
      (while (looking-at dir-regexp)
	(speedbar-contract-line)
	(speedbar-restricted-move 1)
	(move-beginning-of-line 1))))

  (defun my-speedbar-expand (&optional arg)
    "call depth-expand. With prefix argument (C-u), call breadth-expand"
    (interactive "P")
    (if arg
	(breadth-expand)
      (depth-expand)))

  (defun my-speedbar-undo ()
    "undo the latest breadth or depth expansion. has no concept of undo tree"
    (interactive)
    (jump-to-register 'sr)
    (cond ((eq expanded-by 'breadth)
	   (breadth-contract)
	   (jump-to-register 'sr)
	   (message "contracted by breadth and jumped to register"))
	  ((eq expanded-by 'depth)
           (speedbar-contract-line)
	   (message "jumped to register and contracted by depth"))))

  :bind (:map speedbar-mode-map
	      ("C-<return>" . my-speedbar-expand)
	      ("M-<down>" . speedbar-restricted-next)
	      ("M-<up>" . speedbar-restricted-prev)
	      ("C-x u" . my-speedbar-undo)))

;;;;; treemacs
(use-package treemacs
  :if window-system
  ;; NOTE this autoload is ton ensure that `my-treemacs-add-project' works
  ;; properly. It may need other things to be autoloaded as well
  :autoload treemacs--select-workspace-by-name
  :init
  (defalias #'tm #'treemacs)

  (defun treemacs-close-window ()
    (if (and
         (fboundp #'treemacs-current-visibility)
         (equal 'visible (treemacs-current-visibility)))
        (delete-window (treemacs-get-local-window))))

  ;; NOTE: forgot what exactly the point of this function is supposed to be
  ;; TODO if not needed, let's get rid of it
  (defun treemacs-close-and-other-windows (&optional arg)
    (interactive "P")
    (if arg (treemacs-close-window))
    (delete-other-windows))

  (defun my-treemacs-add-project (&optional directory)
    "Add project at DIRECTORY to treemacs. Prompt the user for the workspace.
Basically just a nice wrapper around `treemacs-add-project-to-workspace', making
    it more user-friendly"
    (interactive)
    (let* ((directory
	    (or directory
		(read-directory-name "Pick the project's directory: ")))
	   (treemacs-override-workspace (treemacs--select-workspace-by-name)))
      (treemacs-add-project-to-workspace directory)
      (treemacs-do-switch-workspace treemacs-override-workspace)))

  :config
  (add-to-list 'ido-read-file-name-non-ido #'treemacs-rightclick-menu)

  ;; :bind
  ;; (("C-x 1" . treemacs-close-and-other-windows))
  :bind (:map treemacs-mode-map ("x" . treemacs-delete-marked-files)))

;;;; TRANSIENT menus and KEY help
;;;;; which key
(use-package which-key
  :config
  (which-key-setup-minibuffer)
  ;; Allow C-h to trigger which-key before it is done automatically
  (setq which-key-show-early-on-C-h t)
  ;; make sure which-key doesn't show normally but refreshes quickly after it is
  ;; triggered.
  (setq which-key-idle-delay 10000)
  (setq which-key-idle-secondary-delay 0.05)
  (which-key-mode))

;;;;; casual
(defmacro define-casual-subpkg (sub &rest init-forms)
  `(use-package ,(intern (format "casual-%s" sub))
     :init
     ,@(or init-forms '())
     :after (,(intern sub))
     :load-path ,(package-desc-dir
                  (cadr (assq 'casual package-alist)))
     :bind
     (:map ,(intern (format "%s-mode-map" sub))
           ("C-o" . ,(intern (format "casual-%s-tmenu" sub))))))

(use-package casual
  :init
  (let ((pkg-dir (package-desc-dir
                  (cadr (assq 'casual package-alist)))))
    (define-casual-subpkg "calc")
    (define-casual-subpkg "calendar")
    (define-casual-subpkg "dired"
                          (autoload
                            #'casual-dired-search-replace-tmenu
                            (format "%s/%s" pkg-dir
                                    "casual-dired-utils.el"))
                          (autoload
                            #'casual-dired-sort-by-tmenu
                            (format "%s/%s" pkg-dir
                                    "casual-dired-sort-by.el"))
                          (define-key dired-mode-map
                                      "/" #'casual-dired-search-replace-tmenu)
                          (define-key dired-mode-map
                                      "\\" #'casual-dired-sort-by-tmenu))
    (define-casual-subpkg "ibuffer"
                          (autoload
                            #'casual-ibuffer-filter-tmenu
                            (format "%s/%s" pkg-dir
                                    "casual-ibuffer-filter.el"))
                          (autoload
                            #'casual-ibuffer-sortby-tmenu
                            (format "%s/%s" pkg-dir "casual-ibuffer.el"))
                          (define-key ibuffer-mode-map
                                      "F" #'casual-ibuffer-filter-tmenu)
                          (define-key ibuffer-mode-map
                                      "\\" #'casual-ibuffer-sortby-tmenu)))
  (define-casual-subpkg "isearch"))
;; (use-package casual-calc
;;   :after (calc)
;;   :load-path the-dir
;;   :bind
;;   (:map calc-mode-map
;;         ("C-o" . casual-calc-tmenu)))
;; (use-package casual-dired
;;   :after (dired)
;;   :load-path the-dir
;;   :bind
;;   (:map dired-mode-map
;;         ("C-o" . casual-dired-tmenu)
;;         ("/" . casual-dired-search-replace-tmenu)
;;         ("\\" . casual-dired-sort-by-tmenu)))
;; (use-package casual-ibuffer
;;   :after (ibuffer)
;;   :load-path (package-desc-dir
;;               (cadr (assq 'casual package-alist)))
;;   :bind
;;   (:map ibuffer-mode-map
;;         ("C-o" . casual-ibuffer-tmenu)
;;         ("F" . casual-ibuffer-filter-tmenu)
;;         ("\\" . casual-ibuffer-sortby-tmenu)))
;; (use-package casual-isearch
;;   :after (isearch)
;;   :load-path the-dir
;;   :bind
;;   (:map isearch-mode-map
;;         ("C-o" . casual-isearch-tmenu)))

;;;; PROGRAMMING support and utilities
;;;;; ido completion mode
(use-package ido
  :init
  (ido-mode 1)
  :config
  (setq ido-everywhere t)
  (setq ido-enable-flex-matching t))

;;;;; prog-mode
(use-package prog-setup
  :hook
  (prog-mode . prog-setup-appearance)
  :load-path "custom/packages/prog-setup/"
  :config
  (defun prog-insert-date ()
    "Insert today's date.
If the current line is empty, also add 'NOTE'.
Comment-out the current line, if it isn't already"
    (interactive)
    (let ((og-line-empty
	   (= 0
	      (length (string-trim (thing-at-point 'line))))))
      (save-excursion
	(insert (string-trim (shell-command-to-string "date \"+%B %d, %Y, %I:%M%p (%Z)\""))))
      (when og-line-empty
	(insert "NOTE: "))
      (unless (comment-only-p (pos-bol) (pos-eol))
	(comment-line 1)))
    (end-of-visual-line))

  :bind (:map prog-mode-map
	      ("C-c ." . prog-insert-date)))


;;;;; git
(use-package transient
  :load-path "~/.emacs.d/elpa/transient-20251108.1336/")

(use-package magit
  :after transient
  :init

  (defcustom magit-default-homebase-dir "~/"
    "Default directory to clone git projects into"
    :type '(string)
    :group 'magit)

  (defun clone-and-add-project (&optional url)
    "Clone a project into a default directory and add it to a treemacs workspace"
    (interactive "srepo URL: ")
    (let* ((project-name (file-name-base url))
	   (directory (read-directory-name "clone into directory: "
					   (file-name-concat
					    magit-default-homebase-dir
					    project-name))))
      (message "project-name: %s" project-name)
      (message "directory: %s" directory)
      (make-directory directory)
      (my-treemacs-add-project directory)
      (magit-clone-regular url directory (transient-args 'magit-clone))))

  :config

  ;; instead of `magit-insert-unpushed-to-upstream-or-recent',
  ;; show both `magit-insert-unpushed-to-upstream' and
  ;; `magit-insert-recent-commits' in `magit-status-sections-hook'
  (setq magit-status-sections-hook
        (replace-in-list #'magit-insert-unpushed-to-upstream-or-recent
                         '(magit-insert-unpushed-to-upstream
                           magit-insert-recent-commits)
                         magit-status-sections-hook))

  ;;   (defun vc-refresh-buffer (arg)
  ;;     (with-current-buffer arg
  ;;       (vc-refresh-state)))

  ;;   (defun vc-refresh-all-git-buffers ()
  ;;     "Get list of git files from magit,
  ;; for each open buffer with one of these files,
  ;; refresh the version-control state"
  ;;     (mapcar #'vc-refresh-buffer
  ;; 	    (seq-intersection
  ;; 	     (mapcar #'buffer-name (buffer-list))
  ;; 	     (mapcar #'file-name-nondirectory (magit-list-files))
  ;; 	     #'string-equal-ignore-case)))

  (defun my-magit-show-refs (arg)
    "If ARG is nil, list the branches sorted by date of most-recent commit.
  Else, setup the transient for `magit-show-refs'"
    (interactive "P")
    (if arg
	(magit-show-refs 'transient)
      (magit-refs-setup-buffer "HEAD" (list "--sort=-committerdate"))))

  (global-auto-revert-mode)

  ;; TEMP `magit-ido-completing-read' is not found in this setup
  ;; TODO investigate
  ;; (setq magit-completing-read-function 'magit-ido-completing-read)

  ;; this might affect performance when there are many files
  ;; but it can always be turned off. Would be cool to maybe find a way to only
  ;; trigger it when needed (eg we put off refreshing the buffer til next time
  ;; it's opened?) trying to see if this can be accomplished with
  ;; `global-auto-revert-mode'
  ;; :hook (magit-mode . vc-refresh-all-git-buffers)

  ;; in `magit-diff' buffers, when we copy text, we generally don't want to
  ;; include the '+/-' at the beginning of the line
  (defun magit-diff--cleanup-kills (string-in-list &optional _replace)
    (if (bound-and-true-p magit--use-cleanup-kills)
	;; NOTE that `kill-new' actually passes its string argument as a list
	;; so we need to get its car first, and then pass it back in a string
	(let ((str (car string-in-list)))
	  (when (and (string-match "^+" str)
		     (string-match "^-" str))
	    (warn "\
The copied text from the magit-diff buffer contains both PLUS \
symbols and MINUS symbols. Are you sure that you intend to copy text from \
multiple revisions?
(NOTE: if you want to copy the actual diff, you can do so by temporarily \
setting `magit--use-cleanup-kills' to nil. Otherwise, while it is t, MINUS and \
PLUS signs are automatically removed)"))
	  (list
	   (replace-regexp-in-string "^[+ -]" "" str)))
      string-in-list))

  :hook
  ;; NOTE this approach is used by `inferior-python-cleanup-kills' as well.
  ;; it seems a bit suboptimal: adding an advice for a general function
  ;; *everywhere*, but disabling the function's via a buffer-local variable.
  ;; I'm not sure if there's a better way, but this could be investigated
  (magit-diff-mode . (lambda ()
		       (setq-local magit--use-cleanup-kills t)
		       (advice-add #'kill-new :filter-args
				   #'magit-diff--cleanup-kills)))

  :custom
  (magit-clone-set-remote.pushDefault t)
  :bind (:map magit-mode-map
	      ("y" . my-magit-show-refs)))

(use-package magit-todos
  :after magit
  :config (magit-todos-mode 1))

(defcustom git-remote-see-push t
  "Whether to retrieve the PUSH url."
  :type 'boolean
  :group 'magit)

(defun git-remote-url (&optional push)
  "Get the remote URL for the current file or directory.
Copy it, message it in the minibuffer, and return it.
With optional argument PUSH, get the pushRemote"
  (interactive "P")
  (let* (;; get the url in a format suitable for a browser
         (url-from-command
          (shell-command-to-string
           (concat "git remote get-url "
                   (if push "--push " "") "origin")))
         (trimmed (if (string-prefix-p "fatal: not a git repository"
                                       url-from-command)
                      (error url-from-command)
                    (string-trim url-from-command)))
	 (no-at-git (string-replace "@git" "" trimmed))
	 ;; TODO: ensure this can work with both https and @git urls
	 ;; (no-colon (subst-char-in-string ?: ?/ trimmed
	 ;;                                 'inplace)) ; avoid copy
	 ;; (no-git (replace-regexp-in-string ".git$" "" trimmed))
	 ;; (repo-url (replace-regexp-in-string "git@" "https://"
	 ;;                                     no-git))
	 (httped (replace-regexp-in-string
		  "https?///" "https://"
		  (string-replace ":" "/" no-at-git)))
	 (repo-url (replace-regexp-in-string ".git$" "" httped))
	 ;; determine the path of the current file/directory from the repo root
	 (filename (buffer-file-name))
	 (here-path (or filename
			(string-trim (shell-command-to-string
                                      "pwd"))))
	 ;; KLUDGE thing to deal with ssh'd files
	 (here-path (replace-regexp-in-string "/ssh:.*@.*:" "" here-path))
	 (root (string-trim (shell-command-to-string
                             "git rev-parse --show-toplevel")))
	 (relative (replace-regexp-in-string
		    (regexp-quote root) "" here-path))

	 ;; get the current branch
	 (branch (string-trim (shell-command-to-string
			       "git rev-parse --abbrev-ref HEAD")))
	 ;; get the current "anchor:" in most cases, the line or region,
	 ;; or, for markdown files, the current heading
	 (anchor (when filename
		   (cond ((or
			   (string-suffix-p ".md" filename)
			   (string-suffix-p ".mdx" filename))
			  (markdown-current-heading-as-url-anchor))
			 ((region-active-p)
			  (save-excursion
			    (concat "#L" (number-to-string
					  (progn
					    (goto-char
					     (region-beginning))
					    (line-number-at-pos)))
				    "-L" (number-to-string
					  (progn
					    (goto-char (region-end))
					    (line-number-at-pos))))))
			 (t
			  (concat "#L" (number-to-string
					(line-number-at-pos)))))))
	 (final-url (concat repo-url
			    (if filename "/blob/" "/tree/")
			    branch
			    relative
			    anchor)))
    (copy-message-return
     final-url
     (list "%s %s"
	   (propertize "copied:" 'face 'minibuffer-prompt)
	   final-url))))

(defun git-open-remote (&optional in-xwidget push)
  "Open the remote URL for the current file or directory.
  With prefix argument IN-XWIDGET, open it within emacs in a Safari
  xwidget."
  (interactive "P")
  (let ((url (git-remote-url (or push (bound-and-true-p git-remote-see-push)))))
    (message "%s %s"
             (propertize "Opening:" 'face 'minibuffer-prompt)
             url)
    (if in-xwidget
        (xwidget-webkit-browse-url url)
      (open-in-browser url))))

;;;;; outline
(use-package dash)
(use-package outshine
  :config
  ;; collapse the current level even when I'm not at the heading
  (defun my-outline-tab ()
    "if current line is a heading, call regular outshine-kbd-TAB;
  else, first move to previous visible heading, then call it"
    (interactive)
    (move-beginning-of-line 1)
    (if (null (looking-at outline-regexp))
	(outline-previous-visible-heading 1))
    (outshine-kbd-TAB))

  :bind (:map outshine-mode-map
	      ("TAB" . my-outline-tab)
	      ("C-c C-p" . outline-previous-visible-heading)
	      ("C-c C-n" . outline-next-visible-heading)
	      ("C-M-<down>" . outline-move-subtree-down)
	      ("C-M-<up>" . outline-move-subtree-up)))

;; outshine
(add-hook 'outline-minor-mode-hook #'outshine-mode)
;; enable outline-minor-mode for elisp programming buffers
(add-hook 'emacs-lisp-mode-hook #'outline-minor-mode)

;;;;; expand region
(use-package expand-region
  :config
  (er/enable-mode-expansions 'inferior-python-mode
                             'er/add-python-mode-expansions)
  :bind
  ("C-=" . er/expand-region)
  ("C-M-/" . er/expand-region))

;;;;; aggressive indent
(use-package aggressive-indent
  :hook
  (emacs-lisp-mode . aggressive-indent-mode)
  (inferior-emacs-lisp-mode . aggressive-indent-mode))

;;;;; helper functions
;; implemented my own, extremely dumb version of dumb jump
;; possible enhancements:
;; when not found, try to search outside the current file
(defun find-symbol-first-occurrence ()
  "Search for symbol at point within the file."
  (interactive)
  (let ((my-symbol (thing-at-point 'symbol 'no-properties)))
    (if (null my-symbol)
	(message "No symbol at point")
      (progn (beginning-of-buffer)
             (goto-char (search-forward-regexp
                         (isearch-symbol-regexp my-symbol)))
             (isearch-forward-symbol-at-point)))))

;; only use find-symbol-first occurrence as a weak alternative in cases
;; where the backend for xref has not been set
(defun my-find-definition ()
  "If an xref-backend has been set, call `xref-find-definitions'.
  Else, call find-symbol-first-occurrence"
  (interactive)
  (if (equal '(etags--xref-backend) xref-backend-functions)
      (find-symbol-first-occurrence)
    (execute-extended-command nil "xref-find-definitions")))

(global-set-key (kbd "M-.") #'my-find-definition)

;; set appropriate default compile-command
(defun set-compile-command (arg &optional use-file options)
  (setq-local compile-command
	      (concat arg " "
		      (if (and buffer-file-name use-file)
			  (shell-quote-argument
			   (file-name-sans-extension
			    (file-name-nondirectory buffer-file-name))))
		      options)))

(add-hook 'java-mode-hook
	  (lambda () (set-compile-command "javac" t)))
(add-hook 'scala-mode-hook
	  (lambda () (set-compile-command "scalac" t)))
(add-hook 'go-mode-hook
	  (lambda () (set-compile-command "go install")))
(add-hook 'monicelli-mode-hook
	  (lambda () (set-compile-command "mcc" t " -o ")))
(add-hook 'clojurescript-mode-hook
          (lambda () (set-compile-command "lein cljsbuild once")))
(add-hook 'zig-mode-hook
          (lambda () (set-compile-command
                      ;; TEMP thing for ziglings
                      "/Users/andyjda/programming-exercises/zig/zig-lang/zig build")))

;;;;; folding
;; My own very simple implementation of folding mechanisms
;; If it gets more complex or I want more features, consider switching
;; to `origami' or `hs-minor-mode' etc, or "folding" these
;; functionalities into them
(defcustom folding-functions
  '((fold-func . origami-close-node)
    (unfold-func . origami-show-node)
    (unfold-all-func . origami-open-all-nodes))
  "Functions to use in folding commands such as `fold-this',
  `unfold-this', and `unfold-all'")

(defcustom folded-appearance
  (propertize "..." 'face 'comint-highlight-prompt)
  "String to put in folded overlays")

(use-package origami
  :custom
  (origami-fold-replacement folded-appearance)
  :hook
  (after-init . global-origami-mode))

(defun default-folding-setup ()
  "Ensure that any mode needed for folding is activated. Call this
from `startup-look'"
  (make-it-quiet
   (global-origami-mode)))

(defun my--fold (start end)
  (save-excursion
    (let ((ov (make-overlay start end)))
      (overlay-put ov 'display folded-appearance)
      (overlay-put ov 'category 'folded))))

(defun fold-this ()
  (interactive)
  (if (region-active-p)
      (my--fold (region-beginning) (region-end))
    (call-interactively (alist-get 'fold-func folding-functions))))

(defun my--unfold (start end)
  (save-excursion
    (remove-overlays
     start end
     'category 'folded)))

(defun unfold-this ()
  (interactive)
  (if (region-active-p)
      (my--unfold (region-beginning) (region-end)))
  (call-interactively (alist-get 'unfold-func folding-functions)))

(defun unfold-all ()
  (interactive)
  (my--unfold (point-min) (point-max))
  (call-interactively (alist-get 'unfold-all-func folding-functions)))

(defun comint-fold ()
  (interactive)
  (my--fold
   (progn (comint-previous-prompt 1)(end-of-line) (point))
   (progn (comint-next-prompt 1) (previous-line)
          (end-of-line) (point))))

(defun comint-unfold ()
  (interactive)
  (save-excursion
    (my--unfold (progn (comint-previous-prompt 1) (end-of-line)
                       (point))
                (progn (comint-next-prompt 1)
                       (previous-line) (end-of-line)
                       (point)))))

(defun comint-fold-all ()
  (interactive)
  ;; TODO would be nice to be able to do this within a region as well
  (save-excursion
    (goto-char (point-max))
    (while-let ((previous (comint-previous-prompt 1))
                (start (progn previous (end-of-line)
                              (point)))
                (end (progn (comint-next-prompt 1)
                            (previous-line) (end-of-line)
                            (point))))
      (my--fold start end)
      (comint-previous-prompt 1))))

(defun comint-fold-setup ()
  (setq-local
   folding-functions
   '((fold-func . comint-fold)
     (unfold-func . comint-unfold)
     (unfold-all-func . ignore))
   folded-appearance (concat "\n" folded-appearance)))


;;;;; highlight TODO words
(use-package hl-todo
  :hook
  (prog-mode . global-hl-todo-mode))

;;;;; tree-sitter
(use-package treesit-auto
  :demand t
  :custom
  (treesit-auto-install 'prompt)
  :config
  (treesit-auto-add-to-auto-mode-alist (list 'python))
  (global-treesit-auto-mode))


;;;;; LLMs
(defun ollama-ls-models ()
  "Call 'ollama ls' and parse its output to return the list of
available models, *as symbols* (the main use of this right now is within
`gptel-make-ollama', which expects symbols).

NOTE that the expected output from Ollama will look like this:
NAME                       ID              SIZE      MODIFIED       
llama3:latest              365c0bd3c000    4.7 GB    11 minutes ago"
  (let ((raw-output (cmd "ollama ls")))
    (cl-loop for row in (cdr (split-string raw-output "\n"))
	     if (length> row 0)
	     collect (intern (car (split-string row))))))

(defun ollama-start ()
  (interactive)
  (unless (app-is-running "Ollama")
    ;; NOTE we tell it to 'run' as opposed to 'open', so it runs in the
    ;; background without opening a panel
    (cmd "osascript -e 'tell application \"Ollama\" to run'")))

(use-package gptel
  ;; NOTE switching back to the public version of this
  ;; :load-path "custom/packages/gptel/"

  :hook
  ;; NOTE ideally this would happen /after/ the buffer has already been
  ;; displayed, which would make it snappier
  (gptel-mode . ollama-start)

  :config
  (setq
   gptel-model 'llama3.1:latest
   gptel-backend
   (gptel-make-ollama "*gptel-🦙*"
     :host "localhost:11434"
     :stream t
     :models (ollama-ls-models))))

;;;;; formatting
(use-package apheleia
  :config
  (setf (alist-get 'python-ts-mode apheleia-mode-alist) 'ruff)
  (setf (alist-get 'python-mode apheleia-mode-alist) 'ruff))

;;;; PROGRAMMING LANGUAGES
;;;;; java
(use-package javadoc-lookup
  :bind (("C-c s" . org-store-link)))

(use-package cc-mode
  :bind (:map java-mode-map
	      ("C-i" . javadoc-add-import))
  :hook (java-mode . subword-mode))

;;;;; scala
(use-package scala-mode
  :mode "\\.sc\\'")

;;;;; monicelli
(use-package monicelli-mode
  :load-path "custom/modes/"
  :mode "\\.mc\\'")

;;;;; clojure
(use-package clojure-mode
  :hook (clojure-mode . lsp)
  :config
  (defun cljs-open-index-html (_proc res)
    "Open the index.html file for this project.
_PROC and RES are the default arguments given to a `process-sentinel'.
We check the RES to ensure the process finished successfully"
    (if (string-prefix-p "finished" res)
        (progn
          (xw-url
           (concat "file://"
                   (path-expand-user
                    (project-root (project-current t)))
                   "resources/public/index.html"))
          (xwidget-webkit-reload))
      (progn
        (message
         "*compilation* result: %s" res)
        (switch-to-buffer (compilation-find-buffer))
        (delete-window))))

  (defun cljs-open-figwheel (&optional in-browser)
    (let ((url "http://localhost:3449"))
      (if in-browser
          (open-in-browser url)
        (xw-url url))))


  (defun cljs-run-this ()
    (interactive)
    (prog--compile (lambda () (compile "lein figwheel" t)))
    (cljs-open-figwheel 'in-browser))

  (defun cljs-format (arg &optional line-number _)
    (format (concat
             "(js/console.log \""
             (when line-number (format "At line number: %s; " line-number))
             (when arg "%s : \" %s")
             ")")
            arg arg))

  ;; (defun cljs-format-stringify (arg &optional line-number _)
  ;;   (format (concat
  ;;            "(js/console.log \""
  ;;            (when line-number (format "At line number: %s; " line-number))
  ;;            (when arg "%s STRINGIFIED : ${JSON.stringify(%s)}")
  ;;            "\")")
  ;;           arg arg))

  (defun cljs-debug-log (&optional verbose)
    (interactive "P")
    (prog-debug-print verbose #'cljs-format))

  ;; (defun cljs-debug-log-stringify (&optional verbose)
  ;;   (interactive "P")
  ;;   (prog-debug-print verbose #'cljs-format-stringify))

  :bind
  (:map clojurescript-mode-map
        ;; ("M-p" . cljs-debug-log-stringify)
	("C-M-p" . cljs-debug-log)
        ("C-c r" . cljs-run-this)))

(use-package cider)

;;;;; go
(use-package go-mode

  :config
  (defun go-run-this (dir)
    (interactive (list (read-directory-name "run this go-mod in a shell: ")))
    (prog-run-this dir nil
                   (concat "go run "
                           dir " ")))

  (defun go-format (arg &rest line-number-etc)
    (format "fmt.Printf(\"%s : %%v\\n\", %s)" arg arg))

  (defun go-debug-print (&optional arg)
    (interactive "P")
    (prog-debug-print arg #'go-format))
  :hook (go-mode . lsp)
  :bind (:map go-mode-map
              ("C-c r" . go-run-this)
              ("C-M-p" . go-debug-print)))

;;;;; python mode
(use-package python
  :config
  (defun py-generic-format (arg action &optional line-number block-name)
    (let ((arg (if arg
                   (string-replace "\"" "'" arg))))
      (format (concat
               action
               "(f\""
               (when line-number (format "From: `%s` in %s; "
					 block-name
					 (file-name-nondirectory
					  (buffer-file-name))))
               (when line-number (format "line number: %s; " line-number))
               (when arg "%s : {%s}")
               "\")")
              arg arg)))

  (defun py-format (arg &optional line-number block-name)
    (py-generic-format arg "print" line-number block-name))

  (defun py-log-format (arg &optional line-number block-name)
    (py-generic-format arg "logger.info" line-number block-name))

  (defun py-debug-log (&optional arg)
    (interactive "P")
    (prog-debug-print arg #'py-log-format))

  (defun py-debug-print (&optional arg)
    (interactive "P")
    (prog-debug-print arg #'py-format))

  (defun py-run-this (file)
    (interactive (list (read-file-name "run this file in a shell: ")))
    (prog-run-this file nil
                   (concat "python "
                           (file-name-nondirectory file) " ")
                   #'python-activate-venv-in-shell))

  (defun py-query-delete-print ()
    (interactive)
    (query-replace-regexp "\n\s*#?\s*print(.*)" ""))

  ;; NOTE the below is not really necessary
  ;; I'm using it because when I call py-query-delete-print (defined above)
  ;; I always get this other function as another possible option:
  ;; gnus-summary-simplify-subject-query
  ;; I never need these libraries, so I'm ok with unbinding all of their symbols.
  ;; (wrapping it within a condition-case so it doesn't throw an error when it
  ;; tries to unload something that's already been unloaded)
  (condition-case
      nil
      (progn (unload-feature 'gnus-group 'force)
             (unload-feature 'gnus-sum 'force))
    (error nil))

  (setq-local delete-print #'py-query-delete-print)

  (defun query-comment-out-print ()
    (interactive)
    (query-comment-out "print"))

  (setq ruff-format-command "/Users/andyjda/.pyenv/shims/ruff")
  (defun py-run-command-in-project-venv (cmd &optional edit-cmd)
    "Run CMD in a project shell"
    (interactive "srun this command in a venv: ")
    (let* ((prefix-cmd (python--get-project-root-cmd))
	   (full-cmd (concat
		      prefix-cmd
		      (when prefix-cmd " && ")
		      "source .venv/bin/activate && "
		      cmd)))
      (compile (if edit-cmd
		   (compilation-read-command full-cmd)
		 full-cmd)
	       t)))

  ;; TODO having trouble setting this for particular projects
  (defvar py-project-test-command "ruff check --fix && make check-all"
    "Command to use when testing a Python project. Can be customized for
    specific projects")

  (defun py-project-test (&optional edit-cmd)
    "Run 'ruff check --fix && make test-all' in a project shell"
    (interactive "P")
    ;; TODO this could potentially be adapted by leveraging
    ;; `projectile-test-project'
    ;; or `projectile-compile-project' leveraging `set-compile-command'
    (py-run-command-in-project-venv py-project-test-command edit-cmd))

  ;; TODO could this be autoloaded?
  (defun py-install-project (&optional remove-earlier)
    "Use the default command to install a python project.
With prefix arg REMOVE-EARLIER, remove the existing .venv directory."
    (interactive "P")
    ;; TODO this could be potentially optimized if it ran in a more performant
    ;; terminal emulator, like `vterm'? Although so far I'm getting decent
    ;; performance with `compile' and the COMINT flag
    (let ((command (concat
		    (when-let ((prefix-cmd (python--get-project-root-cmd)))
		      (concat prefix-cmd " && "))
		    (when remove-earlier "rm -rf .venv && ")
		    "uv venv && source .venv/bin/activate && uv pip install -e .")))
      (compile command t)))

  (defun ruff-fix ()
    "Run 'ruff check --fix' in a project shell"
    (interactive)
    (py-run-command-in-project-venv "ruff check --fix"))

  ;; since these functions have more to do with formatting, maybe they should be
  ;; in the apheleia section?
  (defun buffer-file-contains-rgx (rgx &optional default)
    "Return whether `buffer-file-name' contains the given RGX.
If `buffer-file-name' returns nil, return DEFAULT"
    (if-let (name (buffer-file-name))
	(string-match-p rgx name)
      default))

  ;; MAYBE would be great to have a way to
  ;; apply `auto-fill' only to docstrings as well
  :hook
  (python-base-mode . subword-mode)
  (inferior-python-mode . subword-mode)

  ;; NOTE turn this off when we need to open and make edits to the cceval datasets,
  ;; without worrying about linting
  ;; (python-base-mode . ruff-format-on-save-mode)
  (python-base-mode . (lambda () (setq-local fill-column 88
					     whitespace-line-column 88
					     comment-auto-fill-only-comments t)))
  :bind (:map python-base-mode-map
              ("M-<right>" . python-indent-shift-right)
              ("M-<left>" . python-indent-shift-left)
              ("C-c r" . py-run-this)
	      ("C-c t" . py-project-test)
              ("C-M-l" . py-debug-log)
              ("C-M-p" . py-debug-print)))


(use-package lsp-pyright
  :hook (python-base-mode . (lambda ()
                              (require 'lsp-pyright)
                              (lsp)))  ; or lsp-deferred
  :config
  (setq lsp-enable-file-watchers nil))

(defun get-project-venv (&optional directory)
  ;; possible improvement: when venv not found,
  ;; add option to query user for venv directory
  (let* ((root (or
                (when (boundp 'projectile-project-root)
                  (projectile-project-root directory))
                directory
                default-directory))
	 (venv-dir (concat root ".venv")))
    (if (file-directory-p venv-dir)
	(file-name-as-directory venv-dir)
      (progn (message
	      "no '.venv' or 'venv' directory found in this project: %s" root)
	     nil))))

;; TODO make this more generic; it's not just for python
(defun python--get-project-root-cmd ()
  "Move to the project directory to run a make command"
  (when (equal (projectile-project-type) 'python-toml)
    (let ((root (if (boundp 'projectile-project-root)
		    (projectile-project-root)
		  (error "No root directory found for this project"))))
      (format "cd %s" root))))

(use-package pyvenv
  :hook (python-base-mode . pyvenv-mode)
  :config

  (setq pyvenv-default-virtual-env-name ".venv/")
  ;; Set correct Python interpreter
  (setq pyvenv-post-activate-hooks
        (list (lambda ()
                (setq python-shell-interpreter (concat pyvenv-virtual-env "bin/python3")))
	      (lambda ()
		(message "activated venv at: \t%s" (getenv "VIRTUAL_ENV")))))
  (setq pyvenv-post-deactivate-hooks
        (list (lambda ()
                (setq python-shell-interpreter "python3")))))

;; when starting interpreter, automatically start the project's virtual environment
(advice-add 'run-python :before
	    (lambda (&optional _cmd _dedicated _show)
	      (message "_cmd from the advice: %s" _cmd)
	      (let ((venv (get-project-venv)))
		;; (read-directory-name "Activate venv: ")
		(when venv (pyvenv-activate (get-project-venv))))))

;; when starting interpreter, make sure to include the default environment variables
;; TODO: this needs some work
;; `exec-path-from-shell' is probably the way to fix this
;; you just need to add the relevant variables before you initialize it
;; (advice-remove 'python-shell-calculate-command :filter-return
;; 	       (lambda (cmd)
;; 		 (message "cmd from the advice: %s" cmd)
;; 		 (message "concated: %s" (concat "source /Users/andrewjda/.zshrc && " cmd))
;; 		 (concat "source /Users/andrewjda/.zshrc && " cmd)))

(defun python-venv--activate-cmd ()
  (let ((venv (get-project-venv)))
    (when venv
      (format "source %sbin/activate" venv))))

(defun python-activate-venv-in-shell ()
  (interactive)
  (let ((venv-cmd (python-venv--activate-cmd)))
    (when venv-cmd
      (comint-send-string nil venv-cmd)
      (comint-send-input nil t))))

(defun named-shell (name &optional setup-funcs)
  "Create (or switch to) a shell with *shell-NAME*  and
  `pop-to-buffer'.
SETUP-FUNCS is a list of functions to run when setting up the shell."
  ;; move or create the buffer: if the buffer is new, it'll be in
  ;; fundamental mode so we also have to start the shell
  (pop-to-buffer name)
  (when (eq major-mode 'fundamental-mode)
    (shell name)
    (dolist (func setup-funcs) (funcall func)))
  (comint-send-input nil t))

(defun named-shell-file (file &optional setup-funcs)
  "Start (or switch to) a shell for FILE.
Start the shell with `named-shell' and cd into FILE's directory.
SETUP-FUNCS is a list of functions to run when setting up the shell."
  (let ((name (format "*shell-%s*" (file-name-nondirectory file)))
        (desired-dir (file-name-directory file)))
    (named-shell name setup-funcs)
    ;; move to the desired dir if needed
    (if (not (equal desired-dir default-directory))
	(progn (comint-send-string nil (message "cd %s" desired-dir))
	       (comint-send-input nil t)))))

(defun python-run-app ()
  (interactive)
  (message "project app: %s" (bound-and-true-p project-app))
  (py-run-this (bound-and-true-p project-app)))

(use-package blacken
  :commands blacken-mode blacken-buffer)

;; for the inferior python interpreter
(defun inferion-python-current-indentation ()
  (beginning-of-line 1)
  (set-mark-command nil)
  (back-to-indentation)
  (buffer-substring (region-beginning) (region-end)))

(defun input-or-newline (&optional arg)
  (if arg
      (comint-send-input)
    (insert ?\n)))

(defun python-smart-indent (&optional arg)
  (interactive)
  (delete-horizontal-space)
  (if (string-match-p "[^[:space:]]" (or (thing-at-point 'line 'no-prop) ""))
      (let ((indent (inferion-python-current-indentation)))
	(move-end-of-line 1)
	(if (eq (char-before) ?:)
	    ;; I'd rather use tabs, but then this weird string gets inserted:
	    ;; 0__dummy_completion__  1__dummy_completion__
	    (setf indent (concat indent "    ")))
	(input-or-newline arg)
	(insert indent))
    (input-or-newline arg)))

(add-hook 'inferior-python-mode-hook
          (lambda ()
	    (local-set-key (kbd "C-<return>")
			   #'python-smart-indent)))

(add-hook 'inferior-python-mode-hook
          (lambda ()
	    (local-set-key (kbd "<return>")
			   (lambda () (interactive) (python-smart-indent 'send)))))

(add-hook 'inferior-python-mode-hook
          (lambda ()
	    (local-set-key (kbd "C-<backspace>")
			   (lambda () (interactive) (delete-backward-char 4)))))

(add-hook 'inferior-python-mode-hook (lambda () (setq-local use-cleanup-kills t)))

(add-hook 'inferior-python-mode-hook (lambda ()
				       (advice-add #'kill-new :filter-args
						   #'inferior-python-cleanup-kills)))

(defun inferior-python-cleanup-kills (string &optional _replace)
  (if (bound-and-true-p use-cleanup-kills)
      (let ((prompt-regexp (concat "^" "\\(" python-shell-prompt-regexp "\\)+"))
	    (prompt-block-regexp (concat "^" "\\(" python-shell-prompt-block-regexp "\\)+")))
	(thread-last
	  (replace-regexp-in-string prompt-block-regexp "    " (car string))
	  (replace-regexp-in-string prompt-regexp "")
	  (list))) ; string argument is actually passed as a list
    string))

;;;;; javascript
;;;

;; aligns annotation to the right hand side
(setq company-tooltip-align-annotations t)

;; formats the buffer before saving
(add-hook 'before-save-hook 'tide-format-before-save)

;; if you use typescript-mode
(add-hook 'typescript-mode-hook #'setup-tide-mode)
;; if you use treesitter based typescript-ts-mode (emacs 29+)
(add-hook 'typescript-ts-mode-hook #'setup-tide-mode)
;;;

(defun setup-tide-mode ()
  (interactive)
  (tide-setup)
  (flycheck-mode +1)
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  (eldoc-mode +1)
  (tide-hl-identifier-mode +1)
  (company-mode +1))

;; aligns annotation to the right hand side
(setq company-tooltip-align-annotations t)

;; formats the buffer before saving
(add-hook 'before-save-hook 'tide-format-before-save)

(add-hook 'typescript-mode-hook #'setup-tide-mode)

(add-hook 'web-mode-hook #'subword-mode)

(defun js-format (arg &optional line-number _)
  (format (concat
           "console.log(`"
           (when line-number (format "At line number: %s; " line-number))
           (when arg "%s : ${%s}`")
           ");")
          arg arg))

(defun js-format-stringify (arg &optional line-number _)
  (format (concat
           "console.log(`"
           (when line-number (format "At line number: %s; " line-number))
           (when arg "%s STRINGIFIED : ${JSON.stringify(%s)}`")
           ");")
          arg arg))

(defun js-debug-log (&optional verbose)
  (interactive "P")
  (prog-debug-print verbose #'js-format))

(defun js-debug-log-stringify (&optional verbose)
  (interactive "P")
  (prog-debug-print verbose #'js-format-stringify))

(defun js-query-delete-console ()
  (interactive)
  (query-replace-regexp "\n\s*\s*console.log(.*);?" ""))

(use-package web-mode
  :config
  (setq web-mode-enable-current-element-highlight t)
  (set (make-local-variable 'delete-print) #'js-query-delete-console)
  :hook
  (web-mode . apheleia-mode)
  :bind (:map web-mode-map
	      ("M-p" . js-debug-log-stringify)
	      ("C-M-p" . js-debug-log)))

(add-to-list 'auto-mode-alist '("\\.tsx\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.jsx\\'" . web-mode))
(add-to-list 'auto-mode-alist '("\\.js\\'" . web-mode))

(add-hook 'web-mode-hook
          (lambda ()
            (when (string-equal "tsx" (file-name-extension buffer-file-name))
              (setup-tide-mode))))

(defun js-run-this ()
  (interactive)
  (python-run-app)
  (comint-send-input)
  (split-window-below)
  (named-shell "*shell-npm-dev*" nil)
  (let ((desired-dir (projectile-project-root)))
    (if (not (equal desired-dir default-directory))
	(progn (comint-send-string nil (message "cd %s" desired-dir))
	       (comint-send-input nil t))))
  (insert "npm run dev"))

(use-package lsp-mode
  :ensure t
  :config
  ;; (require 'lsp-clients)
  (add-hook 'web-mode-hook 'lsp)
  ;; (add-hook 'c-or-c++-ts-mode-hook 'lsp)
  ;; (add-hook 'c-mode-hook 'lsp)
  ;; (add-hook 'c++-mode-hook 'lsp)
  ;; (add-hook 'c-ts-mode-hook 'lsp)
  ;; (add-hook 'c++-ts-mode-hook 'lsp)


  ;; lsp-booster
  ;; (defun lsp-booster--advice-json-parse (old-fn &rest args)
  ;;   "Try to parse bytecode instead of json."
  ;;   (or
  ;;    (when (equal (following-char) ?#)
  ;;      (let ((bytecode (read (current-buffer))))
  ;; 	 (when (byte-code-function-p bytecode)
  ;;          (funcall bytecode))))
  ;;    (apply old-fn args)))
  ;; (advice-add (if (progn (require 'json)
  ;; 			 (fboundp 'json-parse-buffer))
  ;;                 'json-parse-buffer
  ;; 		'json-read)
  ;;             :around
  ;;             #'lsp-booster--advice-json-parse)

  ;; (defun lsp-booster--advice-final-command (old-fn cmd &optional test?)
  ;;   "Prepend emacs-lsp-booster command to lsp CMD."
  ;;   (let ((orig-result (funcall old-fn cmd test?)))
  ;;     (if (and (not test?)                             ;; for check lsp-server-present?
  ;;              (not (file-remote-p default-directory)) ;; see lsp-resolve-final-command, it would add extra shell wrapper
  ;;              lsp-use-plists
  ;;              (not (functionp 'json-rpc-connection))  ;; native json-rpc
  ;;              (executable-find "emacs-lsp-booster"))
  ;;         (progn
  ;;           (when-let ((command-from-exec-path (executable-find (car orig-result))))  ;; resolve command from exec-path (in case not found in $PATH)
  ;;             (setcar orig-result command-from-exec-path))
  ;;           (message "Using emacs-lsp-booster for %s!" orig-result)
  ;;           (cons "emacs-lsp-booster" orig-result))
  ;; 	orig-result)))
  ;; (advice-add 'lsp-resolve-final-command :around
  ;; 	      #'lsp-booster--advice-final-command)

  )


;;;;; rust
(use-package rustic
  :config
  (defun first-non-whitespace-char (str)
    (let ((pos (string-match "[^ \t\n\r]" str)))
      (when pos
        (aref str pos))))

  (defun add-ref-if-needed (str)
    (if (not str)
        ""
      (if (eq (first-non-whitespace-char str) ?&)
          str
        (concat "&" str))))

  ;; (defun rs-format (arg &rest line-number-etc)
  ;;   (format "println!(\"%s : {:?}\", %s);"arg arg))

  (defun rs-format (arg &rest line-number-etc)
    (let ((arg (add-ref-if-needed arg)))
      (format "dbg!(%s);" arg)))

  (defun rs-debug-print (&optional arg)
    (interactive "P")
    (prog-debug-print arg #'rs-format))

  ;; standardize this so `prog-run-this' can use it
  (setq rustic-compilation-buffer-name "*compilation*")

  (defun rs-run-this (file)
    (interactive (list (read-file-name "run this file in a shell: ")))
    (prog-run-this file #'rustic-compile "cargo run"))

  :custom
  (lsp-rust-analyzer-cargo-watch-command "clippy")

  :custom
  ;; doesn't seem to work for some reason
  (rust-format-on-save t)

  :bind (:map rustic-mode-map
              ("C-M-p" . rs-debug-print)
              ("C-c r" . rs-run-this)
              ("C-c c" . rustic-compile)))

;; debugging
(when (executable-find "lldb-mi")
  (use-package dap-mode
    :ensure
    :config
    (dap-ui-mode)
    (dap-ui-controls-mode 1)


    (require 'dap-lldb)
    (require 'dap-codelldb)
    (require 'dap-cpptools)

    (dap-codelldb-setup)
    (setq dap-auto-configure-features '(sessions locals controls tooltip))

    (dap-register-debug-template
     "LLDB::Run Rust"
     (list :type "lldb"
           :request "launch"
           :name "LLDB::Run"
           :miDebuggerPath "~/.cargo/bin/rust-lldb"
           :target nil
           :cwd nil
           :program "~/programming-exercises/rust-book/rectangles/target/debug/rectangles"
           ))
    ))


;;;;; c / c++ / objective c lang
(use-package eglot
  :init
  (add-hook 'c-mode-hook 'eglot-ensure)
  (add-hook 'c++-mode-hook 'eglot-ensure)
  (add-hook 'objc-mode-hook 'eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs '((c++-mode c-mode objc-mode) "clangd")))

(defun use-c-style-comments ()
  (setq comment-start "/*")
  (setq comment-end "*/"))

(mapc
 (lambda (mode-hook)
   (add-hook mode-hook #'use-c-style-comments))
 (list 'c-mode-hook 'c++-mode-hook 'objc-mode-hook))

;;;;; zig
(use-package zig-mode
  :hook
  (zig-mode . subword-mode)
  (zig-mode . lsp))

;;;;; emacs lisp

(defun el-format (arg &optional line-number block-name)
  (let ((arg (if arg
                 (string-replace "\"" "'" arg))))
    (concat
     "("
     "message \""
     (when block-name (format "From: `%s'; " block-name))
     (when line-number (format "At line number: %s; " line-number))
     (if arg (format "%s: %%s\" %s" arg arg arg) "\"")
     ")")))

(defun el-run-this ()
  (interactive)
  (when (called-interactively-p)
    (call-interactively #'elisp-eval-region-or-buffer)
    (funcall #'elisp-eval-region-or-buffer)))

(defun el-debug-print (&optional arg)
  (interactive "P")
  (prog-debug-print arg #'el-format))

;; will use this for a 'find references' thing
(defun elisp-refs-symbol-at-point (path-prefix)
  "Find all the references to the symbol at point."
  (interactive
   (list (ido-read-directory-name
          (format
           "Search for `%s' in loaded files in: " (symbol-at-point))
          (if-let ((current (project-current nil)))
              (project-root current)))))
  (elisp-refs-symbol (symbol-at-point) path-prefix))

(define-key emacs-lisp-mode-map (kbd "C-M-p") 'el-debug-print)
(define-key emacs-lisp-mode-map (kbd "C-c r") 'el-run-this)
;; TODO here I'm using the same keybindings as `lsp-mode' but I think
;; I should find a common more ergonomical binding
(define-key emacs-lisp-mode-map (kbd "s-l g r") 'elisp-refs-symbol-at-point)

(setq source-directory "~/Emacs-Build/emacs")

;;;;; templates
(auto-insert-mode t)
(setq auto-insert-directory "~/.emacs.d/templates")

(defun template-insert-file-name ()
  (let ((name (thread-last
	        (file-name-nondirectory buffer-file-name)
                (file-name-sans-extension)
                (replace-regexp-in-string "_\\|-" " "))))
    (replace-string "Template"
		    (concat (upcase (string (aref name 0))) (seq-drop name 1)))))

(defun add-auto-insert-template-by-extension (arg)
  `(define-auto-insert
     ,(concat "\\." arg "\\'")
     [,(concat arg ".template") template-insert-file-name]))

(defmacro define-all-templates (args)
  `(progn ,@(mapcar 'add-auto-insert-template-by-extension args)))

(define-all-templates
 ("org" "java" "sc" "c" "go"))

;;;; shell commands, term & comint
(setq shell-file-name "/bin/zsh"
      async-shell-command-buffer 'new-buffer)

;;;;; commands


(defun cmd (program-and-args &optional async)
  "Run PROGRAM-AND-ARGS synchronously.
Show the output in the echo area and return it.
NOTE that this doesn't use a shell, so it might not always behave as
  expected: for example, some programs prefer to print to stdout
  rather than return values, and this doesn't give them a chance to do
  that. If needed, use `call-process-shell-command'."
  (interactive "sexecute: ")
  ;; TODO check if there's a way to make this asynchronous (maybe
  ;; leveraging `detached')
  (let* ((split (split-string-shell-command program-and-args))
         (program (car split))
         (args (cdr split))
         (output (with-output-to-string
                   (apply #'call-process program nil standard-output
                          nil args))))
    (message (format "%s%s"
                     (propertize program-and-args 'face 'minibuffer-prompt)
                     (if (string-empty-p output)
                         "✅"
                       (concat " 🤖:\n" output))))
    output))

(defun reveal-in-finder (arg)
  "Use \"open -R ARG\" to select file in Finder."
  (interactive (list (ido-read-file-name
		      "open in Finder: "
		      nil
		      (buffer-file-name))))
  (cmd (format "open -R \"%s\"" arg)))

(defun this-file ()
  "`copy-message-return' the current path (file or directory)"
  (interactive)
  (copy-message-return (or buffer-file-name default-directory)))

(nconc eww-suggest-uris '(region-at-point word-at-point))

(setq eww-search-prefix "https://search.brave.com/search?q=")

(autoload ; so `open-in-browser' works, even if we haven't loaded eww yet
  #'eww-suggested-uris
  (concat lisp-directory "net/eww.el"))

(defun open-in-browser (url)
  (interactive
   (let ((uris (eww-suggested-uris)))
     (list (read-string (format-prompt "Enter URL or keywords"
                                       (and uris (car uris)))
                        nil 'eww-prompt-history uris))))
  ;; NOTE: Mon Nov 17 15:26:46 EST 2025
  ;; that this command might apply some unwanted formatting in the URL:
  ;; the formatting is done by the open command and not by us, so it's hard to
  ;; control. But it only really applies to weird formats and is not usually a problem
  (cmd
   ;; NOTE `eww--dwim-expand-url' must be autoloaded
   (format "open \"%s\"" (eww--dwim-expand-url url))))

(defun app-list-running (&optional no-filter)
  "List all running apps.
This uses the shell commands ps and grep to get a first list of apps.
We then do some filtering to return relevant apps.
By default, remove any apps that are just 'Helper's to other apps, and
  remove the ones whose name is all lowercase (by convention, these
  are OS agents and not user-facing).
If optional arg NO-FILTER is non-nil, don't do any filtering."
  (let* ((raw (shell-command-to-string
               "ps -A | grep \".*\\.app\""))
         ;; NOTE this regex might not catch anything, for example it
         ;; misses 'plugin-container'
         (all
          (delete-dups
           (regexp-all-matches
            "/.*/.*.app/Contents/MacOS/\\([^ ][^-\n]*\\)" raw 1))))
    ;; TODO the filter could use some work, eg I would like it to list Ollama
    ;; even when it's running in the background
    (if no-filter
        all
      ;; remove any app whose name doesn't match (ignoring case)
      ;; one of the apps in the Applications directory
      (let ((available-apps (app-list-all)))
        (cl-remove-if-not
         (lambda (app)
           (cl-some (lambda (available-app)
                      (cl-equalp app available-app))
                    available-apps))
         all)))))

(defun app-is-running (name &optional no-filter)
  (member name (app-list-running no-filter)))

(defun app-list-all ()
  "List all directories in the /Applications/ directory whose name
ends in '.app'."
  ;; TODO: find a way to list the Utilities as well.
  ;; oddly:
  ;; ls -al /Applications/Utilities/ returns nothing
  (string-split
   (shell-command-to-string "ls /Applications/ | grep \".*\\.app\"")
   ".app\n"
   'omit-nulls))

(defun app-quit (app &optional force)
  "Use the recommended MacOS script to quit APP.
If we run into issues with the script, return the output of the command, unless
  FORCE is t, in which case try the more direct command 'killall'"
  (interactive (list (completing-read "quit "
				      (app-list-running))))
  (let* ((force (or force current-prefix-arg))
	 (output (cmd (format "osascript -e 'quit app \"%s\"" app))))
    (when (and force (length> output 0))
      (cmd (format "killall %s" app)))))

(defun app-open (app)
  (interactive (list (completing-read "open "
                                      (app-list-all))))
  (cmd (format "open -a \"%s\"" app)))

(defun app-switch (app)
  "This is just like `app-open', but it lists running apps for
  convenience.
We could also use the appropriate osascript:
```sh
osascript -e 'tell application \"{app_name}\" to activate'
```"
  (interactive
   (list (completing-read "switch to app: "
                          (app-list-running))))
  (app-open app))

(defun os-cleanup ()
  "Perform cleanup steps required for shutdown or restart."
  (app-quit "Slack"))

;; scripts from:
;; https://gist.github.com/atifazad/6afd3cbedb8819dd7ed7be92dec2dc0d
(defun os-shutdown ()
  "Turn off the computer"
  (interactive)
  (os-cleanup)
  (cmd "osascript -e 'tell app \"System Events\" to shutdown'"))

(defun os-restart ()
  "Restart the computer"
  (interactive)
  (os-cleanup)
  (cmd "osascript -e 'tell app \"System Events\" to restart'"))

(defun ghostty ()
  "Open the terminal emulator"
  (interactive)
  ;; TODO also add the option to run commands (not sure how)
  (cmd
   (format
    "open -na ghostty --args --title=ghostty-from-emacs --working-directory=%s"
    default-directory)))

;;;;; detached
;; (use-package detached
;;   :init
;;   (detached-init)
;;   ;; keeping the original commands for now, I want to get an explicit understanding
;;   ;; of when/how I use the detached commands, and what benefits they provide
;;   ;; :bind (;; Replace `async-shell-command' with `detached-shell-command'
;;   ;;        ([remap async-shell-command] . detached-shell-command)
;;   ;;        ;; Replace `compile' with `detached-compile'
;;   ;;        ([remap compile] . detached-compile)
;;   ;;        ([remap recompile] . detached-compile-recompile)
;;   ;;        ;; Replace built in completion of sessions with `consult'
;;   ;;        ([remap detached-open-session] . detached-consult-session))
;;   :custom ((detached-show-output-on-attach t)
;;            (detached-terminal-data-command system-type)))

;;;;; shell appearance
(use-package sticky-shell
  :hook (sticky-shell-mode . sticky-shell-shorten-header-set-mode)
  :load-path "custom/packages/sticky-shell/"
  ;; put the load path here whenever you need to test things
  :config
  (defalias #'sticky-mode #'sticky-shell-mode))

(use-package shell-output-mode
  :load-path "custom/modes/"
  :config
  (setq find-default-options " ")
  :defer 1)


(defun comint-postoutput-scroll-to-center (_string)
  "Just like `comint-postoutput-scroll-to-bottom', but scroll to the
middle of the window instead."
  (let* ((current (current-buffer))
	 (process (get-buffer-process current)))
    (unwind-protect
	(cond
	 ((null process))
	 ((bound-and-true-p follow-mode)
	  (warn "follow-mode not supported in comint-postoutput-scroll-to-center"))
	 (t
          (dolist (w (get-buffer-window-list current nil t))
            (comint-adjust-window-point w process)
            ;; Optionally scroll to the bottom of the window.
            (and comint-scroll-show-maximum-output
                 (eq (window-point w) (point-max))
                 (with-selected-window w
                   (recenter nil))))))
      (set-buffer current))))

;; (defun recenter-middle (string)
;;   (when (eq (window-buffer (selected-window)) (current-buffer))
;;     (recenter nil t))
;;   string)

(define-minor-mode center-shell-mode
  "Minor mode to show the shell output at the center of the buffer."
  :group 'comint
  :global t
  :lighter nil
  (if center-shell-mode
      (progn
        (remove-hook
         'comint-output-filter-functions
         #'comint-postoutput-scroll-to-bottom)
        (add-hook
         'comint-output-filter-functions
         #'comint-postoutput-scroll-to-center 99))
    (progn
      (remove-hook
       'comint-output-filter-functions
       #'comint-postoutput-scroll-to-center)
      (add-hook
       'comint-output-filter-functions
       #'comint-postoutput-scroll-to-bottom 99))))


(use-package coterm
  :init
  (coterm-mode)
  :defer 1)

(define-minor-mode comint-output-read-only-mode
  "Minor mode to set the shell output to read only."
  :group 'comint
  :global t
  :lighter nil

  (defun comint--set-read-only (beg end)
    (add-text-properties
     (save-excursion
       (goto-char beg)
       (comint-previous-prompt 1)
       (point))
     end '(read-only t)))

  (defun comint-undo-read-only-props ()
    ;; still doesn't seem to be working :(
    (remove-text-properties (point-min) (point-max) '(read-only nil)))

  ;; MAYBE: add logic so when the mode is disabled, it sets all of the
  ;; buffer's outputs back to read-only nil?
  (if comint-output-read-only-mode
      (advice-add 'comint--mark-as-output :after #'comint--set-read-only)
    (progn
      (advice-remove 'comint--mark-as-output #'comint--set-read-only))))


(add-hook 'comint-mode-hook
	  (lambda ()
	    (visual-line-mode -1)
	    (electric-pair-local-mode t)
	    (center-shell-mode t)
            (setq comint-prompt-read-only t)
            (comint-output-read-only-mode t)
            (comint-fold-setup)))

;;;; SPECIAL VIEWS (web, PDF, ebooks)
(use-package webkit-mac-enhance
  :defer 1
  :load-path "custom/packages/webkit-mac-enhance/")

;;;;; pdf tools & epub
;; TODO Wed Oct 22 10:56:35 EDT 2025
;; issue with the libraries needed by pdf-tools,
;; haven't been able to figure out the exact problem
(use-package pdf-tools
  :init
  ;; install pdf-tools at the first call to doc-view-mode
  (advice-add 'doc-view-mode :after #'pdf-tools-install)
  :custom
  (pdf-annot-minor-mode-map-prefix (kbd "C-a"))
  :config
  (defun pdf-annot-write-highlight-annotation (list-of-edges)
    "Create an annotation with `pdf-annot-add-highlight-markup-annotation',
then activate it with `pdf-annot-activate-annotation' to start writing"
    (interactive (list (pdf-view-active-region t)))
    (pdf-annot-activate-annotation (pdf-annot-add-highlight-markup-annotation
				    list-of-edges)))

  :bind
  (:map pdf-view-mode-map
	("M-w" . pdf-view-kill-ring-save)
	("C-w" . pdf-view-kill-ring-save)
	("s-c" . pdf-view-kill-ring-save)
	;; "b" was originally mapped to `image-previous-frame',
	;; which in this mode usually just does: (message "No image animation.")
	("b" . pdf-history-backward)
	;; "f" was originally mapped to `pdf-links-isearch-link', whose
	;; behavior/purpose is unclear to me
	("f" . pdf-history-forward)))

;; TODO there should be a way to easily export all annotations into an org/md
;; file.
;; `org-noter' is touted as a way to do this but it seems pretty suboptimal
;; https://github.com/weirdNox/org-noter
;; furthermore, this should be fairly easy to do using nothing but pdf-tools?
;; see this stack overflow answer for some ideas:
;; https://stackoverflow.com/a/29480524
;; TODO would like to figure out if there's a way to link to specific annotation
(use-package pdf-annot
  :after pdf-tools
  :load-path (lambda () (locate-library "pdf-tools"))
  :bind
  (:map pdf-annot-minor-mode-map
	("C-a w" . pdf-annot-write-highlight-annotation)))

(add-to-list 'auto-mode-alist '("\\.epub\\'" . nov-mode))

(setq package-vc-allow-build-commands t)
;; TODO make it only support the file-formats I want to support, NOT
;; epub or xlsx
(use-package reader
  :vc (:url "https://codeberg.org/divyaranjan/emacs-reader"
  	    :make "all"))


;;;;; whatsapp
(use-package wasabi
  :load-path "custom/packages/wasabi/")

;;;; GAMES
;;;;; tetris

(defun tetris-setup ()
  (yt-frame)
  (pixel-scroll-precision-mode -1)
  (define-key tetris-mode-map "q" #'tetris-quit)
  ;; TODO: any time you do fancy stuff with memory, maybe take a look
  ;; at memory-report and see if you can check from there whether or
  ;; not it is safe to do it
  (gcmh-mode -1)
  (setq gc-cons-threshold 400000
        gc-cons-percentage 0.5))

(add-hook 'tetris-mode-hook #'tetris-setup)

;; TODO potential enhancement is to add a prefix argument that, when
;; non-nil, instead of closing the tetris buffer simply gets us back
;; to the normal view. This needs to then be paired with logic to
;; re-wire `tetris' such that it checks whether the buffer exists
;; instead of always creating a new one
(defun tetris-quit ()
  (interactive)
  (my-gc-setup)
  (gcmh-mode +1)
  (pixel-scroll-precision-mode +1)
  (kill-buffer "*Tetris*")
  (condition-case nil
      (kill-buffer "tetris-scores")
    (error (message "no buffer named tetris-scores")))
  (startup-look))

(defun close-scores-and-play ()
  (interactive)
  (delete-window)
  (switch-to-buffer "*Tetris*")
  (tetris-start-game))

(defvar-keymap tetris-score-mode-map
  "n" #'close-scores-and-play
  "q" (lambda ()
        (interactive)
        (View-quit)
        (tetris-quit)))

(define-minor-mode tetris-score-mode
  "Minor mode for displaying tetris scores
  \\{tetris-score-mode-map}"
  :keymap tetris-score-mode-map
  (hl-line-mode t)
  (visual-line-mode -1)
  (setq-local truncate-lines t)
  (add-hook 'view-mode-hook
	    (lambda ()
	      (if tetris-score-mode
		  (progn
                    (define-key view-mode-map "n" nil)
                    (define-key view-mode-map "q" nil))))))

(add-to-list 'auto-mode-alist '("\\tetris-scores\\'" . tetris-score-mode))

;;;; RANDOM STUFF
;; for testing xwidgets
(setq load-prefer-newer t)


;;;;; noaa weather forecast
(use-package noaa
  :init
  (defalias #'weather #'noaa)
  :custom
  (noaa-location "Brooklyn, NY")
  ;; TODO can't quite figure out how to actually set the default style.
  ;; I must not be getting something right, this should be a lot easier!
  (defun noaa-set-defaults (&rest r)
    (interactive)
    (setq noaa--daily-current-style 1
	  noaa--hourly-current-style 1))

  (advice-add 'noaa-mode :after #'noaa-set-defaults))

;; ;;;;; trying out agentic setups
(use-package agent-shell
  :ensure t
  ;; :ensure-system-package
  ;; Add agent installation configs here
  ;; ((claude . "brew install claude-code")
  ;;  (claude-code-acp . "npm install -g
  ;; @zed-industries/claude-code-acp"))
  )

(provide 'init.el)
;;; init.el ends here
