# 02-nginx-static-site

A static website behind nginx: the package, nginx's main configuration, a
site configuration and the page from templates, and the service, reloaded
when a configuration file changes.

**Who is this for:** a first real server recipe.

Runs on Debian, Ubuntu, Rocky Linux and Arch Linux with systemd. Tested in
the Docker matrix on all four (see [Testing](../../docs/contributing/testing.md)).

| File | Purpose |
|---|---|
| `recipe.rb` | package, configuration files, document root, service |
| `vars.rb` | site name, server name, page text |
| `templates/nginx.conf.erb` | nginx's main configuration, checked with `nginx -t` before it is installed |
| `templates/site.conf.erb` | the site's `server` block |
| `templates/index.html.erb` | the page |

```sh
sudo sadame plan examples/02-nginx-static-site
sudo sadame apply examples/02-nginx-static-site
curl http://localhost/
sudo sadame apply examples/02-nginx-static-site --var title="Hello"   # rewrites the page only
```
