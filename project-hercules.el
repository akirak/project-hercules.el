;;; project-hercules.el --- Per-project transient keymaps -*- lexical-binding: t -*-

(require 'hercules)
(require 'project)

(defvar project-hercules-commands nil)

(defun project-hercules--ensure ()
  (unless project-hercules-commands
    (setq project-hercules-commands
          (make-hash-table :test #'equal))))

(defun project-hercules--normalize-root (root)
  (file-truename (file-name-as-directory root)))

(defun project-hercules--find-by-root (root)
  (project-hercules--ensure)
  (or (gethash (project-hercules--normalize-root root)
               project-hercules-commands)
      (when-let (worktrees (let ((default-directory root))
                             (thread-last (magit-list-worktrees)
                               (mapcar #'car)
                               (delq root))))
        (catch 'found
          (dolist (worktree worktrees)
            (when-let (command (gethash (project-hercules--normalize-root worktree)
                                        project-hercules-commands))
              (throw 'found command)))))))

(defun project-hercules--remove-plist (plist prop)
  (cond
   ((null plist) plist)
   ((eq prop (car plist))
    (project-hercules--remove-plist (cddr plist) prop))
   (t
    `(,(nth 0 plist)
      ,(nth 1 plist)
      ,@(project-hercules--remove-plist (cddr plist) prop)))))

(defun project-hercules--make-default-map (root)
  "Create the default keymap for ROOT."
  (make-sparse-keymap))

(cl-defmacro project-hercules-make-map (root &rest hercules-args
                                             &key init &allow-other-keys)
  (let ((hercules-args (project-hercules--remove-plist hercules-args
                                                       :init)))
    `(progn
       (project-hercules--ensure)
       (let* ((root (project-hercules--normalize-root ,root))
              (command (gethash root project-hercules-commands))
              (map-symbol (when command
                            (get command 'project-hercules-map))))
         (unless command
           (setq command (make-symbol "project-hercules-command"))
           (setq map-symbol (make-symbol "project-hercules-map"))
           (set map-symbol ,(or init '(project-hercules--make-default-map root)))
           (put command 'project-hercules-map map-symbol)
           (puthash root command project-hercules-commands))
         (hercules-def
          :show-funs command
          :keymap map-symbol
          ,@hercules-args)
         (symbol-value map-symbol)))))

(defun project-hercules-remove-project (root)
  "Remove the definition for the project ROOT."
  (interactive (list (or (project-root (project-current))
                         (user-error "No project found"))))
  (project-hercules--ensure)
  (remhash (project-hercules--normalize-root root)
           project-hercules-commands))

(defun project-hercules-dispatch ()
  (interactive)
  (if-let (root (project-root (project-current)))
      (if-let (command (project-hercules--find-by-root root))
          (funcall-interactively command)
        (user-error "Not found for project %s" root))
    (user-error "No project found")))

(provide 'project-hercules)
;;; project-hercules.el ends here
