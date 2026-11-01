# Run with sudo: SUDO_USER is the user whose home directory is managed.
{
  user: ENV["SUDO_USER"],
  git_name: "Your Name",
  git_email: "you@example.com",
  packages: ["git", "htop", "ripgrep", "fd", "bat", "starship"],
  aur_packages: ["visual-studio-code-bin"]
}
