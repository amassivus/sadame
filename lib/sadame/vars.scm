;;; The language of vars.scm: plain Scheme whose last expression is an
;;; association list.
;;;
;;;   '((server-name . "example.com")
;;;     (workers . 4))

(define-module (sadame vars)
  #:use-module (sadame primitives)
  #:use-module (sadame eval)
  #:export ()
  #:re-export (json-parse source-directory read-text-file))
