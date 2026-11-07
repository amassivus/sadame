(file "/etc/motd" #:content "hello\n")
(include-recipe "roles/web" #:tags '(web))
(package "htop" #:tags 'tools)
