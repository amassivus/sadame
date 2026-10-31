# The AUR helper must run as a normal user. When sadame runs through sudo,
# SUDO_USER is the user who called it.
{
  aur_user: ENV["SUDO_USER"] || ENV["USER"]
}
