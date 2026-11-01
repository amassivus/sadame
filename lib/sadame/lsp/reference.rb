# frozen_string_literal: true

# Generated from docs/ by script/build/lsp-reference.rb (rake lsp:reference).
# Do not edit: change the docs and generate it again.
module Sadame
  module Lsp
    module Reference
      RESOURCES = {
        "package" => {
          "summary" => "`package` makes sure a system package is installed, or not installed. Sadame reads `/etc/os-release` to pick the package manager, so the same recipe works on Debian and Ubuntu (apt), Rocky, AlmaLinux and Fedora (dnf), Alpine (apk), and Arch and Arch-based systems such as Omarchy (pacman). Before acting it asks the package manager whether the package is installed, and only installs or removes when the answer differs from the recipe.",
          "url" => "https://enderkus.github.io/sadame/resources/package/",
          "options" => {
            "state" => {
              "type" => "`:installed` or `:absent`",
              "default" => "`:installed`",
              "description" => "Whether the package must be installed.",
              "values" => ["installed", "absent"]
            },
            "options" => {
              "type" => "String or Array of Strings",
              "default" => "none",
              "description" => "Extra flags for the install or remove command, placed before the package name. A String is used as is; Array elements are each shell-quoted.",
              "values" => []
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "file" => {
          "summary" => "`file` manages a regular file: its content, permission bits and owner. The content comes from a string, an ERB template, or a file shipped next to the recipe. When the content differs, `plan` shows a unified diff of the file on disk against the desired content. On `apply`, new content is written to a temporary file in the same directory, given its final mode and owner, and renamed over the target, so programs reading the file never see it half written.",
          "url" => "https://enderkus.github.io/sadame/resources/file/",
          "options" => {
            "content" => {
              "type" => "String",
              "default" => "none",
              "description" => "The exact file content.",
              "values" => []
            },
            "template" => {
              "type" => "String",
              "default" => "none",
              "description" => "ERB template, rendered with `vars`, `locals` and [`facts`](https://enderkus.github.io/sadame/recipes/facts/). Looked up next to the recipe, then in its `templates/` directory. Absolute paths are used as is.",
              "values" => []
            },
            "source" => {
              "type" => "String",
              "default" => "none",
              "description" => "File copied as is. Looked up next to the recipe, then in its `files/` directory.",
              "values" => []
            },
            "locals" => {
              "type" => "Hash",
              "default" => "`{}`",
              "description" => "Values for the template, available as `locals[:name]`. Only with `template:`.",
              "values" => []
            },
            "mode" => {
              "type" => "String of 3 or 4 octal digits",
              "default" => "unmanaged",
              "description" => "Permission bits, such as `\"0644\"` or `\"0755\"`.",
              "values" => []
            },
            "owner" => {
              "type" => "String",
              "default" => "unmanaged",
              "description" => "User name that owns the file.",
              "values" => []
            },
            "group" => {
              "type" => "String",
              "default" => "unmanaged",
              "description" => "Group name of the file.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` deletes the file.",
              "values" => ["present", "absent"]
            },
            "sensitive" => {
              "type" => "`true` or `false`",
              "default" => "`false`",
              "description" => "Hide content diffs in output and JSON, for files holding secrets.",
              "values" => []
            },
            "verify" => {
              "type" => "String containing `%{path}`",
              "default" => "none",
              "description" => "A command that checks the new content before it replaces the file, such as `\"visudo -cf %{path}\"`. `%{path}` is the temporary file. If the command fails, the file is left as it was and the resource fails.",
              "values" => []
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "line" => {
          "summary" => "`line` manages one line in a file that something else owns, such as a setting in the configuration file a package installs, and leaves the rest of the file alone. When the file would change, plan shows the change as a diff of the file, and apply writes it in one rename, keeping the file's mode and owner.",
          "url" => "https://enderkus.github.io/sadame/resources/line/",
          "options" => {
            "path" => {
              "type" => "String",
              "default" => "required",
              "description" => "Absolute path of the file to edit.",
              "values" => []
            },
            "line" => {
              "type" => "String",
              "default" => "the name",
              "description" => "The line, without a newline. Give it when the name is a description, or when the same line goes into two files.",
              "values" => []
            },
            "match" => {
              "type" => "Regexp, or a String with one",
              "default" => "none",
              "description" => "Lines to replace. Every line that matches is replaced by the line; when none matches and the line is not in the file, it is appended.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` removes the line, and every line that matches `match`.",
              "values" => ["present", "absent"]
            },
            "verify" => {
              "type" => "String containing `%{path}`",
              "default" => "none",
              "description" => "A command that checks the new content before it replaces the file, such as `\"sshd -t -f %{path}\"`. If it fails, the file is not changed.",
              "values" => []
            },
            "sensitive" => {
              "type" => "`true` or `false`",
              "default" => "`false`",
              "description" => "Hide the diff in output and JSON, for lines with secrets.",
              "values" => []
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "directory" => {
          "summary" => "`directory` makes sure a directory exists, with the permission bits and owner you give, or that it does not exist. Missing parent directories are created along the way. Use it before `file` resources that write into a new directory, and to keep application directories owned by the right user.",
          "url" => "https://enderkus.github.io/sadame/resources/directory/",
          "options" => {
            "mode" => {
              "type" => "String of 3 or 4 octal digits",
              "default" => "unmanaged",
              "description" => "Permission bits, such as `\"0755\"`.",
              "values" => []
            },
            "owner" => {
              "type" => "String",
              "default" => "unmanaged",
              "description" => "User name that owns the directory.",
              "values" => []
            },
            "group" => {
              "type" => "String",
              "default" => "unmanaged",
              "description" => "Group name of the directory.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` removes the directory.",
              "values" => ["present", "absent"]
            },
            "recursive" => {
              "type" => "`true` or `false`",
              "default" => "`false`",
              "description" => "With `state: :absent`, remove the directory and everything in it (`rm -rf`). Without it, only an empty directory can be removed (`rmdir`).",
              "values" => []
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "link" => {
          "summary" => "`link` makes sure a symbolic link exists and points where you say, or that it does not exist. It reads the link with `readlink`, creates or repoints it with `ln -sfn`, and removes it with `rm -f`. Use it for the classic \"enabled\" links (`sites-enabled/app`), for a `current` link between releases, and to put a program on the `PATH`.",
          "url" => "https://enderkus.github.io/sadame/resources/link/",
          "options" => {
            "to" => {
              "type" => "String",
              "default" => "required",
              "description" => "Where the link points. Stored as given: a relative target such as `\"releases/2\"` is relative to the link's directory. The target does not have to exist.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` removes the link.",
              "values" => ["present", "absent"]
            },
            "force" => {
              "type" => "`true` or `false`",
              "default" => "`false`",
              "description" => "Replace a regular file that is where the link should be. Without it, a file in the way is an error.",
              "values" => []
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "service" => {
          "summary" => "`service` manages a service: whether it starts at boot (`enable`) and whether it is running now (`state`). It works with systemd, and with OpenRC on Alpine. It reads the current state with `systemctl is-enabled` and `systemctl is-active` (or `rc-update show` and `rc-service NAME status`) and only changes what differs. Other resources can ask a service to reload or restart when they change, through `notifies:`.",
          "url" => "https://enderkus.github.io/sadame/resources/service/",
          "options" => {
            "enable" => {
              "type" => "`true` or `false`",
              "default" => "unmanaged",
              "description" => "Start at boot (`systemctl enable`) or not (`systemctl disable`). Enabled means `systemctl is-enabled` prints `enabled`.",
              "values" => []
            },
            "state" => {
              "type" => "`:running` or `:stopped`",
              "default" => "unmanaged",
              "description" => "Running now (`systemctl start`) or not (`systemctl stop`). Running means `systemctl is-active` prints `active`.",
              "values" => ["running", "stopped"]
            },
            "user" => {
              "type" => "String",
              "default" => "none",
              "description" => "Manage the unit in this user's systemd instance (`systemctl --user -M USER@`), such as a unit in `~/.config/systemd/user/`. The user must be logged in or have lingering enabled (`loginctl enable-linger USER`). systemd only.",
              "values" => []
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "exec" => {
          "summary" => "`exec` runs a shell command. It is the escape hatch for anything the other resources do not cover: issuing a certificate, running an installer, installing from the AUR. A command has no state sadame can read, so to stay idempotent an `exec` needs a guard that says when the work is already done. Guards are evaluated during `plan` as well as `apply`; the command itself only runs during `apply`.",
          "url" => "https://enderkus.github.io/sadame/resources/exec/",
          "options" => {
            "command" => {
              "type" => "String",
              "default" => "the resource name",
              "description" => "Command to run, when you want the name to be a short label.",
              "values" => []
            },
            "creates" => {
              "type" => "String",
              "default" => "none",
              "description" => "Skip when this path exists.",
              "values" => []
            },
            "not_if" => {
              "type" => "String",
              "default" => "none",
              "description" => "Skip when this command exits 0.",
              "values" => []
            },
            "only_if" => {
              "type" => "String",
              "default" => "none",
              "description" => "Skip unless this command exits 0.",
              "values" => []
            },
            "cwd" => {
              "type" => "String",
              "default" => "inherited",
              "description" => "Working directory for the command and its guards.",
              "values" => []
            },
            "env" => {
              "type" => "Hash of String to String",
              "default" => "none",
              "description" => "Environment variables for the command and its guards.",
              "values" => []
            },
            "action" => {
              "type" => "`:run` or `:nothing`",
              "default" => "`:run`",
              "description" => "`:nothing` never runs the command on its own, only when another resource notifies it.",
              "values" => ["run", "nothing"]
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this command runs. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "user" => {
          "summary" => "`user` manages a local Linux user account: whether it exists, its UID, home directory, login shell, and the groups it must belong to. It reads the account with `getent passwd` and `id -nG`, and changes it with `useradd`, `usermod` and `userdel` only when something differs.",
          "url" => "https://enderkus.github.io/sadame/resources/user/",
          "options" => {
            "uid" => {
              "type" => "Integer",
              "default" => "unmanaged",
              "description" => "Numeric user ID.",
              "values" => []
            },
            "home" => {
              "type" => "String",
              "default" => "unmanaged",
              "description" => "Home directory path.",
              "values" => []
            },
            "shell" => {
              "type" => "String",
              "default" => "unmanaged",
              "description" => "Login shell, such as `\"/bin/bash\"` or `\"/usr/sbin/nologin\"`.",
              "values" => []
            },
            "groups" => {
              "type" => "Array of Strings",
              "default" => "unmanaged",
              "description" => "Groups the user must belong to. Other memberships are left alone. The groups must exist.",
              "values" => []
            },
            "system" => {
              "type" => "`true` or `false`",
              "default" => "`false`",
              "description" => "Create a system account (`useradd -r`), which gets no home directory. Only used when the user is created.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` deletes the account with `userdel`; the home directory is kept.",
              "values" => ["present", "absent"]
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "group" => {
          "summary" => "`group` makes sure a local group exists, with the gid you give, or that it does not exist. It reads the group with `getent group` and changes it with `groupadd`, `groupmod` and `groupdel` only when something differs. Members are set on the user side, with the [user](https://enderkus.github.io/sadame/resources/user/) resource's `groups:`.",
          "url" => "https://enderkus.github.io/sadame/resources/group/",
          "options" => {
            "gid" => {
              "type" => "Integer",
              "default" => "unmanaged",
              "description" => "Numeric group ID. Changing it on an existing group runs `groupmod -g`; files keep their old gid.",
              "values" => []
            },
            "system" => {
              "type" => "`true` or `false`",
              "default" => "`false`",
              "description" => "Create a system group (`groupadd -r`), with a gid from the system range. Only used when the group is created.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` deletes the group with `groupdel`.",
              "values" => ["present", "absent"]
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        },
        "git" => {
          "summary" => "`git` keeps a checkout of a git repository at a revision: a tag, a branch or a commit. The first apply clones the repository; later ones move the checkout when the revision points somewhere else, such as a branch that got new commits. Use it to deploy an application or a site from its repository, or to keep a tool's source on a machine.",
          "url" => "https://enderkus.github.io/sadame/resources/git/",
          "options" => {
            "repository" => {
              "type" => "String",
              "default" => "required",
              "description" => "The URL to clone, as `git clone` takes it: HTTPS, SSH (`git@github.com:example/app.git`) or a local path.",
              "values" => []
            },
            "revision" => {
              "type" => "String",
              "default" => "the remote's default branch",
              "description" => "A tag, a branch or a full 40-character commit.",
              "values" => []
            },
            "user" => {
              "type" => "String",
              "default" => "root",
              "description" => "Run every git command as this user (through `su`), so the checkout belongs to them and their SSH keys and git configuration apply.",
              "values" => []
            },
            "state" => {
              "type" => "`:present` or `:absent`",
              "default" => "`:present`",
              "description" => "`:absent` removes the checkout with `rm -rf`.",
              "values" => ["present", "absent"]
            },
            "notifies" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on other resources when this one changes. See [Notifications](https://enderkus.github.io/sadame/recipes/notifications/).",
              "values" => []
            },
            "subscribes" => {
              "type" => "`[:action, \"type[name]\"]`, optionally with `:immediately`, or a list of them",
              "default" => "none",
              "description" => "Actions to run on this resource when another one changes.",
              "values" => []
            },
            "tags" => {
              "type" => "Symbol, String, or an Array of them",
              "default" => "none",
              "description" => "Tags for running part of a recipe with `--tags` and `--skip-tags`. See [Tags](https://enderkus.github.io/sadame/recipes/tags/).",
              "values" => []
            }
          }
        }
      }.freeze

      FACTS = {
        "hostname" => "String, such as `\"web1\"`. Read from `uname -n`.",
        "fqdn" => "String, such as `\"web1.example.com\"`. Read from `hostname -f`; `hostname` when that fails.",
        "arch" => "String, such as `\"x86_64\"`, `\"aarch64\"`. Read from `uname -m`.",
        "kernel" => "String, such as `\"6.1.0-26-amd64\"`. Read from `uname -r`.",
        "cpus" => "Integer, such as `4`. Read from `nproc`: the CPUs sadame may run on.",
        "memory_mb" => "Integer, such as `7941`. Read from `MemTotal` in `/proc/meminfo`.",
        "swap_mb" => "Integer, such as `2047`. Read from `SwapTotal` in `/proc/meminfo`.",
        "root_disk_gb" => "Integer, such as `39`. Read from size of the file system holding `/`, from `df -Pk /`.",
        "ipv4" => "String or nil, such as `\"203.0.113.10\"`. Read from source address of the route to the internet (`ip -4 route get`); nothing is sent.",
        "default_interface" => "String or nil, such as `\"eth0\"`. Read from interface of that route.",
        "ipv4_addresses" => "Array of Strings, such as `[\"203.0.113.10\", \"10.8.0.1\"]`. Read from every IPv4 address except `127.0.0.0/8` (`ip -4 -o addr show`).",
        "ipv6_addresses" => "Array of Strings, such as `[\"2001:db8::10\"]`. Read from global IPv6 addresses, from `/proc/net/if_inet6`.",
        "virtualization" => "String or nil, such as `\"kvm\"`, `\"docker\"`. Read from `systemd-detect-virt`; nil on bare metal.",
        "container" => "`true` or `false`, such as `false`. Read from `systemd-detect-virt --container`.",
        "service_manager" => "String or nil, such as `\"systemd\"`, `\"openrc\"`. Read from what the [service](https://enderkus.github.io/sadame/resources/service/) resource would use.",
        "machine_id" => "String or nil, such as `\"4c2a0f5e9b1d...\"`. Read from `/etc/machine-id`: unique per installation, never changes."
      }.freeze

      HELPERS = {
        "vars" => "- `vars`: Hash of variables with symbol keys (see below)",
        "platform" => "- `platform.family`: `\"debian\"`, `\"rhel\"`, `\"alpine\"`, `\"arch\"` or `nil`\n- `platform.package_manager`: `\"apt\"`, `\"dnf\"`, `\"apk\"`, `\"pacman\"` or `nil`\n- `platform.id`, `platform.version`, `platform.codename`, `platform.name`: `ID`, `VERSION_ID`, `VERSION_CODENAME` and `PRETTY_NAME` from `/etc/os-release`",
        "facts" => "- `facts[:cpus]`, `facts[:memory_mb]`, `facts[:ipv4]` and more: what the machine has, read from it; see [Facts](https://enderkus.github.io/sadame/recipes/facts/)",
        "host_name" => "- `host_name`, `host_groups`: the host's name and groups from the inventory; see [Inventory](https://enderkus.github.io/sadame/recipes/inventory/#using-groups-in-recipes)",
        "host_groups" => "- `host_name`, `host_groups`: the host's name and groups from the inventory; see [Inventory](https://enderkus.github.io/sadame/recipes/inventory/#using-groups-in-recipes)",
        "include_recipe" => "- `include_recipe \"path\"`: evaluate another recipe file; `tags:` tags everything it declares (see [Tags](https://enderkus.github.io/sadame/recipes/tags/))"
      }.freeze
    end
  end
end
