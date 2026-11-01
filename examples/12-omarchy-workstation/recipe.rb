# A personal Arch or Omarchy workstation, applied locally:
#
#   sudo sadame apply examples/12-omarchy-workstation
#
# Packages from the official repositories, dotfiles from files/ into your
# home directory, a systemd user timer, and an AUR package through yay.
# Run `sudo sadame drift ...` now and then: exit 0 means the laptop still
# matches the recipe.
raise "this example is for Arch Linux and Omarchy, not #{platform.description}" unless platform.family == "arch"

me = vars[:user]
raise "run it with sudo, or pass --var user=NAME" if me.nil? || me.empty? || me == "root"

home = "/home/#{me}"

# Packages: only what you want on top of Arch or Omarchy.
vars[:packages].each { |name| package name }

# Dotfiles. Directories are listed so that they belong to you, not root.
["#{home}/.config", "#{home}/.config/systemd", "#{home}/.config/systemd/user", "#{home}/.local",
 "#{home}/.local/bin"].each do |path|
  directory path, owner: me, mode: "0755"
end
file "#{home}/.gitconfig", template: "gitconfig.erb", owner: me, mode: "0644"
file "#{home}/.config/starship.toml", source: "starship.toml", owner: me, mode: "0644"
file "#{home}/.local/bin/update-system", source: "update-system", owner: me, mode: "0755"

# A user timer that empties ~/Downloads of files older than 30 days. Your
# systemd instance must run even when you are logged out, so lingering is
# turned on and the instance started.
exec "enable lingering for #{me}",
     command: "loginctl enable-linger #{me}",
     creates: "/var/lib/systemd/linger/#{me}"
exec "start #{me}'s systemd instance",
     command: "systemctl start user@$(id -u #{me}).service",
     not_if: "systemctl is-active --quiet user@$(id -u #{me}).service"
exec "reload #{me}'s systemd units",
     command: "systemctl --user -M #{me}@ daemon-reload",
     action: :nothing
file "#{home}/.config/systemd/user/clean-downloads.service",
     source: "clean-downloads.service",
     owner: me,
     mode: "0644",
     notifies: [:run, "exec[reload #{me}'s systemd units]", :immediately]
file "#{home}/.config/systemd/user/clean-downloads.timer",
     source: "clean-downloads.timer",
     owner: me,
     mode: "0644",
     notifies: [:run, "exec[reload #{me}'s systemd units]", :immediately]
service "clean-downloads.timer", user: me, enable: true, state: :running

# An AUR package. yay builds as you and asks sudo for pacman, so this needs
# passwordless sudo for pacman or a recent sudo timestamp. Skipped where
# yay is not installed, such as a plain Arch container.
vars[:aur_packages].each do |name|
  exec "install #{name} from the AUR",
       command: "runuser -u #{me} -- yay -S --needed --noconfirm #{name}",
       only_if: "command -v yay",
       not_if: "pacman -Q #{name}"
end
