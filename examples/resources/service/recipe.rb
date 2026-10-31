# On Arch, installing nginx does not enable or start it; the service
# resource does. Debian and Ubuntu start services on install, so there the
# same resource usually reports no change.
package "nginx"
service "nginx", enable: true, state: :running
