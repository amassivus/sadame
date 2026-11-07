(package "n" #:tags (quote (a b)))(user "u" #:tags (quote users))(package "p" #:notifies (quote (reload "service[x]")))
