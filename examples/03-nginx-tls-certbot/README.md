# 03-nginx-tls-certbot

HTTPS for one domain with a certificate from Let's Encrypt. The `exec` that
runs certbot is guarded with `not_if: "test -f .../fullchain.pem"`, so the
certificate is requested once; later applies, and `drift`, leave it alone.
Renewal is certbot's timer, with a deploy hook that reloads nginx.

**Who is this for:** anyone putting a site on the internet; and a worked
example of an `exec` with a guard and of `:immediately` notifications.

Runs on Debian, Ubuntu, Rocky Linux (certbot from EPEL) and Arch Linux with
systemd. On Arch, certbot has no renewal timer; add one (see the Arch wiki).

| File | Purpose |
|---|---|
| `recipe.rb` | nginx, the HTTP site that answers the challenge, certbot, the HTTPS site |
| `vars.rb` | domain, contact email, and the ACME server for tests |
| `templates/http.conf.erb` | port 80: the challenge directory, a redirect for everything else |
| `templates/https.conf.erb` | port 443 with the certificate |

Before applying, point the domain's DNS at the server and open port 80.

```sh
sudo sadame apply examples/03-nginx-tls-certbot --var domain=www.example.org --var email=you@example.org
sudo sadame drift examples/03-nginx-tls-certbot --var domain=www.example.org --var email=you@example.org
```

**Testing.** Real certificates need a public domain, so the Docker tests
request one from [Pebble](https://github.com/letsencrypt/pebble), Let's
Encrypt's test server, with `--var acme_server=https://pebble:14000/dir
--var certbot_flags=--no-verify-ssl`. This example needs a real kernel and
boot to be trusted, so it only counts as passing after the VM layer (see
[Testing](../../docs/contributing/testing.md)).
