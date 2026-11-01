{
  ssh_port: 2222,
  # Extra TCP ports to open, such as [80, 443] on a web server; on the
  # command line: --var open_ports=80,443
  open_ports: [],
  # fail2ban: ban an address for ban_time after max_retry failures.
  max_retry: 5,
  ban_time: "1h"
}
