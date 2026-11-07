;;; What a template expression sees: ~{(vars 'name)}, ~{(locals 'name)} and
;;; ~{(facts 'cpus)}, plus (ref alist key) for the items of a ~(each) loop.

(define-module (sadame template)
  #:use-module (sadame eval)
  #:use-module (sadame primitives)
  #:use-module (srfi srfi-1)
  #:export (vars locals facts ref evaluate-template-expression))

;; "not-if", not_if and #:not-if are all the symbol not_if.
(define (normalize-key key)
  (let ((text (cond ((symbol? key) (symbol->string key))
                    ((keyword? key) (symbol->string (keyword->symbol key)))
                    (else key))))
    (string->symbol (string-map (lambda (c) (if (char=? c #\-) #\_ c)) text))))

;; The value for KEY in an association list, DEFAULT (or #f) when it has none.
(define (ref alist key . default)
  (let* ((wanted (normalize-key key))
         (entry (find (lambda (pair)
                        (and (pair? pair)
                             (or (symbol? (car pair)) (string? (car pair)) (keyword? (car pair)))
                             (eq? (normalize-key (car pair)) wanted)))
                      alist)))
    (cond (entry (cdr entry))
          ((pair? default) (car default))
          (else #f))))

;; The vars of the run: (vars 'name), (vars 'name default), or (vars) for all.
(define (vars . key) (apply %template-lookup 'vars key))

;; The file resource's #:locals.
(define (locals . key) (apply %template-lookup 'locals key))

;; The machine's facts, read when first asked for.
(define (facts . key) (apply %template-lookup 'facts key))

(define template-env
  (let ((env (make-fresh-user-module)))
    (module-use! env (resolve-interface '(sadame template)))
    env))

;; Evaluates the expression in EXPRESSION with BINDINGS, an association list
;; of loop variables, in scope. Returns (ok . value) or (error kind message).
(define (evaluate-template-expression expression bindings)
  (call-guarded
   (lambda ()
     (let ((form (read (open-input-string expression))))
       (eval `(let ,(map (lambda (binding) `(,(car binding) (quote ,(cdr binding)))) bindings)
                ,form)
             template-env)))))
