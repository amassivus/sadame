;;; Evaluation helpers shared by the recipe, hosts, vars and template
;;; languages. Everything here catches errors and returns them as data, so
;;; no Scheme exception ever unwinds through C++ frames.

(define-module (sadame eval)
  #:use-module (sadame primitives)
  #:use-module (ice-9 textual-ports)
  #:export (call-guarded evaluate-source make-env source-directory read-text-file))

;; The file being evaluated, for (source-directory).
(define source-path (make-fluid #f))

;; The directory of the file being evaluated, so recipes and hosts.scm can
;; find the files next to them whatever directory sadame runs in.
(define (source-directory)
  (let ((path (fluid-ref source-path)))
    (if path (dirname path) ".")))

;; The text of the file at PATH, which must exist.
(define (read-text-file path)
  (call-with-input-file path get-string-all))

;; (kind message) for an exception thrown with KEY and ARGS. Errors that
;; come from sadame carry their own kind; anything else is a Scheme error.
(define (describe-error key args)
  (if (eq? key 'sadame-error)
      (list 'error (car args) (cadr args))
      (list 'error "Error"
            (string-trim-right
             (or (false-if-exception
                  (call-with-output-string
                   (lambda (port) (print-exception port #f key args))))
                 (format #f "~s" (cons key args)))))))

;; (ok . value) when THUNK returns, (error kind message) when it throws.
(define (call-guarded thunk)
  (catch #t
    (lambda () (cons 'ok (thunk)))
    (lambda (key . args) (describe-error key args))))

;; The 1-based line a top-level form starts on, or 0.
(define (form-line form)
  (let ((line (and (pair? form) (source-property form 'line))))
    (if line (+ line 1) 0)))

;; The line of the outermost parenthesis in TEXT that is never closed, or #f.
;; Strings, ; comments and character literals such as #\( are skipped.
(define (unclosed-line text)
  (let ((size (string-length text)))
    (let loop ((i 0) (line 1) (open '()))
      (if (>= i size)
          (and (pair? open) (car (last-pair open)))
          (let ((c (string-ref text i)))
            (cond
             ((char=? c #\newline) (loop (+ i 1) (+ line 1) open))
             ((char=? c #\;)
              (let skip ((j i))
                (if (or (>= j size) (char=? (string-ref text j) #\newline))
                    (loop j line open)
                    (skip (+ j 1)))))
             ((char=? c #\")
              (let skip ((j (+ i 1)) (l line))
                (cond ((>= j size) (loop j l open))
                      ((char=? (string-ref text j) #\\) (skip (+ j 2) l))
                      ((char=? (string-ref text j) #\") (loop (+ j 1) l open))
                      ((char=? (string-ref text j) #\newline) (skip (+ j 1) (+ l 1)))
                      (else (skip (+ j 1) l)))))
             ((and (char=? c #\#) (< (+ i 1) size) (char=? (string-ref text (+ i 1)) #\\))
              (loop (+ i 3) line open))
             ((char=? c #\() (loop (+ i 1) line (cons line open)))
             ((and (char=? c #\)) (pair? open)) (loop (+ i 1) line (cdr open)))
             (else (loop (+ i 1) line open))))))))

;; The message for a form that could not be read.
(define (read-failure path source port message)
  (cond ((and (string-contains message "end of input") (unclosed-line source))
         => (lambda (line)
              (format #f "~a:~a: a form that starts here is never closed" path line)))
        ((string-prefix? path message) message)
        (else (format #f "~a:~a: ~a" path (+ 1 (port-line port)) message))))

;; Reads and evaluates every form of SOURCE in ENV. Returns (ok value) with
;; the value of the last form, or (error kind message line).
(define (evaluate-source path source env)
  (let ((port (open-input-string source)))
    (set-port-filename! port path)
    (let loop ((last #f))
      (let ((read-result (call-guarded (lambda () (read port)))))
        (if (eq? (car read-result) 'error)
            (list 'error "RecipeError"
                  (read-failure path source port (caddr read-result))
                  0)
            (let ((form (cdr read-result)))
              (if (eof-object? form)
                  (list 'ok last)
                  (let ((result (call-guarded (lambda () (with-fluids ((source-path path)) (eval form env))))))
                    (if (eq? (car result) 'error)
                        (list 'error (cadr result) (caddr result) (form-line form))
                        (loop (cdr result)))))))))))

;; A fresh module for one file, with the bindings of the module named by
;; INTERFACE (such as (sadame recipe)) defined in it. They are defined
;; rather than imported so they may shadow Guile's own, like `link'.
(define (make-env interface)
  (let ((env (make-fresh-user-module))
        (exports (resolve-interface interface)))
    (module-map (lambda (name variable) (module-add! env name variable)) exports)
    env))
