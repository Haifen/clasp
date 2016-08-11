;;
;; Clasp builder code
;;
(eval-when (:compile-toplevel :load-toplevel :execute)
  (core:select-package :core))


(defun command-line-arguments-as-list ()
  (let ((idx (- (length core:*command-line-arguments*) 1))
        result)
    (tagbody
     top
       (if (>= idx 0)
           (progn
             (setq result (cons (pathname (elt core:*command-line-arguments* idx)) result))
             (setq idx (- idx 1))
             (go top))))
    result))
           

(defun recursive-remove-from-list (item list)
  (if list
      (if (equal item (car list))
          (recursive-remove-from-list item (cdr list))
          (list* (car list) (recursive-remove-from-list item (cdr list))))
      nil))
(export 'recursive-remove-from-list)

(export '(compile-aclasp))
(defun compile-aclasp (&key clean (link-type :bc) (target-backend (default-target-backend)) (system (command-line-arguments-as-list)))
  (aclasp-features)
  (if clean (clean-system #P"src/lisp/kernel/tag/min-start" :no-prompt t :system system))
  (if (out-of-date-bitcodes #P"src/lisp/kernel/tag/min-start" #P"src/lisp/kernel/tag/min-end" :system system)
      (progn
        (load-system #P"src/lisp/kernel/tag/after-init" #P"src/lisp/kernel/tag/min-pre-epilogue" :system system)
        (let* ((*target-backend* target-backend)
               (files (out-of-date-bitcodes #P"src/lisp/kernel/tag/min-start" #P"src/lisp/kernel/tag/min-pre-epilogue" :system system))
               (files-with-epilogue (out-of-date-bitcodes #P"src/lisp/kernel/tag/min-start" #P"src/lisp/kernel/tag/min-end" :system system)))
          (with-compilation-unit ()
            (compile-system files :reload t)
            (if files-with-epilogue (compile-system (bitcode-pathnames #P"src/lisp/kernel/tag/min-pre-epilogue" #P"src/lisp/kernel/tag/min-end" :system system) :reload nil)))
          (let ((cl-bitcode-pathname (build-common-lisp-bitcode-pathname))
                (all-bitcode (bitcode-pathnames #P"src/lisp/kernel/tag/min-start" #P"src/lisp/kernel/tag/min-end" :system system)))
            (if (out-of-date-target cl-bitcode-pathname all-bitcode)
                (progn
                  (cmp:link-bitcode-modules cl-bitcode-pathname all-bitcode)
                  (if (not (eq link-type :bc))
                      (let ((exec-pathname (build-pathname nil link-type)))
                        (bformat t "Linking aclasp %s\n" (string-downcase (string link-type)))
                        (cmp:llvm-link exec-pathname
                                       :lisp-bitcode-files (list cl-bitcode-pathname)
                                       :link-type link-type))))))))))
                   

(defun remove-stage-features ()
  (setq *features* (recursive-remove-from-list :ecl-min *features*))
  (setq *features* (recursive-remove-from-list :clos *features*))
  (setq *features* (recursive-remove-from-list :aclasp *features*))
  (setq *features* (recursive-remove-from-list :bclasp *features*))
  (setq *features* (recursive-remove-from-list :cclasp *features*)))

(export '(aclasp-features with-aclasp-features))
(defun aclasp-features ()
  (remove-stage-features)
  (setq *features* (list* :aclasp :ecl-min *features*)))
(core:fset 'with-aclasp-features
            #'(lambda (whole env)
                (let* ((body (cdr whole)))
                  `(let ((*features* (list* :aclasp :ecl-min *features*)))
                     ,@body)))
            t)


(export '(compile-link-aclasp))
(defun compile-link-aclasp (&key clean)
  (with-aclasp-features
      (if clean (clean-system #P"src/lisp/kernel/tag/start" :no-prompt t))
    (compile-aclasp)))

(export '(bclasp-features with-bclasp-features))
(defun bclasp-features()
  (remove-stage-features)
  (setq *features* (list* :clos :bclasp *features*)))
(core:fset 'with-bclasp-features
            #'(lambda (whole env)
                (let* ((body (cdr whole)))
                  `(let ((*features* (list* :bclasp :clos *features*)))
                     ,@body)))
            t)

(export '(cclasp-features with-cclasp-features))
(defun cclasp-features ()
  (remove-stage-features)
  (setq *features* (list* :clos :cclasp *features*)))
(core:fset 'with-cclasp-features
            #'(lambda (whole env)
                (let* ((body (cdr whole)))
                  `(let ((*features* (list* :cclasp :clos *features*)))
                     ,@body)))
            t)

(export '(compile-bclasp))
(defun compile-bclasp (&key clean (link-type :bc) (system (command-line-arguments-as-list)))
  (bclasp-features)
  (setq *system-files* (expand-build-file-list *build-files*))
  (if clean (clean-system #P"src/lisp/kernel/tag/start" :no-prompt t :system system))
  (let ((*target-backend* (default-target-backend)))
    (if (out-of-date-bitcodes #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/bclasp" :system system)
        (progn
          (load-system #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/bclasp" :interp t :system system)
          (let ((files (out-of-date-bitcodes #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/bclasp" :system system)))
            (compile-system files)
            (let ((cl-bitcode-pathname (build-common-lisp-bitcode-pathname))
                  (all-bitcode (bitcode-pathnames #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/bclasp" :system system)))
              (if (out-of-date-target cl-bitcode-pathname all-bitcode)
                  (progn
                    (cmp:link-bitcode-modules cl-bitcode-pathname all-bitcode)
                    (if (not (eq link-type :bc))
                        (let ((exec-pathname (build-pathname nil link-type)))
                          (bformat t "Linking bclasp %s\n" (string-downcase (string link-type)))
                          (cmp:llvm-link exec-pathname
                                         :lisp-bitcode-files (list cl-bitcode-pathname)
                                         :link-type link-type)))))))))))

(export '(compile-cclasp recompile-cclasp))
(defun recompile-cclasp (&key clean (link-type :bc) (system (command-line-arguments-as-list)))
  (if clean (clean-system #P"src/lisp/kernel/tag/start" :no-prompt t))
  (let ((files (out-of-date-bitcodes #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/cclasp" :system system)))
    (compile-system files)
    (let ((cl-bitcode-pathname (build-common-lisp-bitcode-pathname))
          (all-bitcode (bitcode-pathnames #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/cclasp" :system system)))
      (if (out-of-date-target cl-bitcode-pathname all-bitcode)
          (progn
            (cmp:link-bitcode-modules cl-bitcode-pathname all-bitcode)
            (if (not (eq link-type :bc))
                (let ((exec-pathname (build-pathname nil link-type)))
                  (bformat t "Linking cclasp %s\n" (string-downcase (string link-type))
                           (cmp:llvm-link exec-pathname
                                          :lisp-bitcode-files (list cl-bitcode-pathname)
                                          :link-type link-type)))))))))

(defun compile-cclasp (&key clean (link-type :executable) (system (command-line-arguments-as-list)))
  (cclasp-features)
  (if clean (clean-system #P"src/lisp/kernel/tag/start" :no-prompt t :system system))
  (let ((*target-backend* (default-target-backend)))
    (if (out-of-date-bitcodes #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/cclasp" :system system)
        (time
         (progn
           (load-system #P"src/lisp/kernel/tag/bclasp" #P"src/lisp/kernel/tag/cclasp" :interp t :system system)
           (let ((files (out-of-date-bitcodes #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/cclasp" :system system)))
             (compile-system files)
             (let ((cl-bitcode-pathname (build-common-lisp-bitcode-pathname))
                   (all-bitcode (bitcode-pathnames #P"src/lisp/kernel/tag/start" #P"src/lisp/kernel/tag/cclasp" :system system)))
               (if (out-of-date-target cl-bitcode-pathname all-bitcode)
                   (progn
                     (cmp:link-bitcode-modules cl-bitcode-pathname all-bitcode)
                     (if (not (eq link-type :bc))
                         (let ((exec-pathname (build-pathname nil link-type)))
                           (bformat t "Linking cclasp executable %s\n" (string link-type))
                           (cmp:llvm-link exec-pathname
                                          :lisp-bitcode-files (list cl-bitcode-pathname)
                                          :link-type link-type))))))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  Setup the build system for ASDF
;;
;;

(defun compile-addons ()
  ;; Build serve-event and asdf
  (core:compile-kernel-file #P"src/lisp/modules/serve-event/serve-event" :force-recompile t)
  (core:compile-kernel-file #P"src/lisp/modules/asdf/build/asdf" :force-recompile t))

(defun link-addons ()
  (cmp:llvm-link (core:build-pathname #P"src/lisp/modules/serve-event/serve-event" :fasl)
                 :lisp-bitcode-files (list (core:build-pathname #P"src/lisp/modules/serve-event/serve-event" :bc)))
  (cmp:llvm-link (core:build-pathname #P"src/lisp/modules/asdf/asdf" :fasl)
                 :lisp-bitcode-files (list (core:build-pathname #P"src/lisp/modules/asdf/build/asdf" :bc))))
(export '(compile-addons link-addons))