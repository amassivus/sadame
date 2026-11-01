# ansible/playbook.yml, translated task by task. Run it with:
#   sadame apply recipe.rb -g web
# The docs show each section next to the Ansible task it replaces.

# --8<-- [start:package]
# apt with update_cache: sadame runs apt-get update before the first
# install of a run.
%w[nginx openssl cron curl].each { |name| package name }
# --8<-- [end:package]

# --8<-- [start:copy]
file "/etc/issue.net", content: "Authorized access only.\n", mode: "0644"
file "/usr/local/bin/backup", source: "backup.sh", mode: "0755"
# --8<-- [end:copy]

# --8<-- [start:template]
# Handlers are notifications; delayed, like Ansible's, by default.
file "/etc/nginx/conf.d/app.conf",
     template: "app.conf.erb",
     mode: "0644",
     notifies: [:reload, "service[nginx]"]
# --8<-- [end:template]

# --8<-- [start:file]
directory "/srv/app", owner: "www-data", mode: "0755"
file "/etc/nginx/conf.d/old.conf", state: :absent
# --8<-- [end:file]

# --8<-- [start:service]
service "nginx", enable: true, state: :running
# --8<-- [end:service]

# --8<-- [start:user]
# groups: always appends, like append: true.
user "deploy", shell: "/bin/bash", groups: ["www-data"]
# --8<-- [end:user]

# --8<-- [start:command]
exec "openssl req -x509 -newkey rsa:2048 -nodes -days 365 -subj /CN=app.example.com " \
     "-keyout /etc/ssl/private/app.key -out /etc/ssl/certs/app.crt",
     creates: "/etc/ssl/private/app.key"
# --8<-- [end:command]

# --8<-- [start:lineinfile]
# No lineinfile: manage the whole file with file, or guard an exec.
exec "echo EDITOR=vim >> /etc/environment", not_if: "grep -q '^EDITOR=vim$' /etc/environment"
# --8<-- [end:lineinfile]

# --8<-- [start:cron]
file "/etc/cron.d/backup", content: "30 2 * * * root /usr/local/bin/backup\n", mode: "0644"
# --8<-- [end:cron]

# --8<-- [start:get_url]
exec "curl -fsSL -o /srv/app/example.html https://www.example.com/",
     creates: "/srv/app/example.html"
# --8<-- [end:get_url]
