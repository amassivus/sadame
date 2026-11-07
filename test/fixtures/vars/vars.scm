;; Vars for tests: the file's last expression is the association list.
(define base '((workers . 2)))

(append '((server-name . "example.com")
          (workers . 4)
          ("string_key" . "from string key"))
        base)
