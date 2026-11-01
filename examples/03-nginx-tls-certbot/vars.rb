# Set domain and email to yours: the domain must point at this server and
# port 80 must be reachable from the internet for Let's Encrypt to check it.
{
  domain: "example.com",
  email: "admin@example.com",
  # Empty for Let's Encrypt. sadame's tests point these at Pebble, a test
  # certificate authority: --var acme_server=https://pebble:14000/dir
  # --var certbot_flags=--no-verify-ssl
  acme_server: nil,
  certbot_flags: ""
}
