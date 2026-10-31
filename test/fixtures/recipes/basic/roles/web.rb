service "nginx", enable: true, state: :running

exec "touch /var/www/app/.ready", creates: "/var/www/app/.ready"
