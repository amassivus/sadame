;; Public keys of throwaway key pairs whose private halves were deleted;
;; replace them with your team's.
'((user . "deploy")
  (ssh_keys . ("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMSkMjo7/L7Aau+k2sv9cXbHMpbiE8L7S1eqqtyrbnPx alice@example.com"
               "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOzqxoVbWh6bqVN+LCr80++bpR0tu297MNEB4USqRMYj bob@example.com"))
  ;; The commands the user may run as root; ("ALL") for an administrator.
  (sudo_commands . ("/usr/bin/systemctl restart app" "/usr/bin/systemctl status app")))
