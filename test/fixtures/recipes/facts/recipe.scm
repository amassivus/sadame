(file "/etc/app.conf" #:template "app.conf.tmpl")
(unless (facts 'container)
  (file "/etc/cpus" #:content (string-append (number->string (facts 'cpus)) "\n")))
