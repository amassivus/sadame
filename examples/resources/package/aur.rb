# AUR packages are not handled by the package resource in sadame 0.1. Use an
# AUR helper through exec, guarded so it only runs when the package is
# missing and the helper is installed. yay and paru refuse to run as root,
# so the command runs as the user named in vars[:aur_user].
exec "runuser -u #{vars[:aur_user]} -- yay -S --needed --noconfirm visual-studio-code-bin",
     only_if: "command -v yay",
     not_if: "pacman -Q visual-studio-code-bin"
