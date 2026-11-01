# The VMs `rake vm:test` runs on. Copy this file to hosts.local.rb, which
# git ignores, and put in your own values; nothing about real machines
# belongs in the repository. The addresses below are from the range
# reserved for documentation and reach nothing.
#
# One group per distribution, each with one host:
#   address, user, port  how to reach the VM over SSH (the user needs
#                        passwordless sudo)
#   ssh_opts             accept-new records the VM's host key for port 2222
#                        the first time example 07 moves SSH there; a key
#                        that changed is still refused
#   vars libvirt_domain: the VM's libvirt domain name
#   vars snapshot:       the libvirt snapshot with the VM's clean state
vm_ssh_opts = ["-o", "StrictHostKeyChecking=accept-new"]

group :ubuntu do
  host "ubuntu-vm", address: "192.0.2.11", user: "tester", port: 22, sudo: true, ssh_opts: vm_ssh_opts,
                    vars: { libvirt_domain: "sadame-ubuntu", snapshot: "clean" }
end

group :debian do
  host "debian-vm", address: "192.0.2.12", user: "tester", port: 22, sudo: true, ssh_opts: vm_ssh_opts,
                    vars: { libvirt_domain: "sadame-debian", snapshot: "clean" }
end

group :rocky do
  host "rocky-vm", address: "192.0.2.13", user: "tester", port: 22, sudo: true, ssh_opts: vm_ssh_opts,
                   vars: { libvirt_domain: "sadame-rocky", snapshot: "clean" }
end

group :arch do
  host "arch-vm", address: "192.0.2.14", user: "tester", port: 22, sudo: true, ssh_opts: vm_ssh_opts,
                  vars: { libvirt_domain: "sadame-arch", snapshot: "clean" }
end

# The desktop user of the Omarchy install is the user example 12 manages.
group :omarchy do
  host "omarchy-vm", address: "192.0.2.15", user: "tester", port: 22, sudo: true, ssh_opts: vm_ssh_opts,
                     vars: { libvirt_domain: "sadame-omarchy", snapshot: "clean", user: "tester" }
end

# The machine running libvirt. `rake vm:reset` runs virsh there over SSH.
group :hypervisor do
  host "hypervisor", address: "192.0.2.1", user: "tester", port: 22,
                     vars: { libvirt_uri: "qemu:///system" }
end
