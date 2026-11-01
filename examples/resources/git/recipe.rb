# The sadame source at its 0.1.0 tag, cloned by a deploy user who owns the
# files. Once the checkout is at the tag, apply has nothing to do; a new
# revision moves it.
package "git"
package "shadow" if platform.family == "alpine" # useradd, for the user resource

user "deploy", shell: "/bin/sh"
directory "/srv/sadame", owner: "deploy", mode: "0755"

git "/srv/sadame",
    repository: "https://github.com/enderkus/sadame.git",
    revision: "v0.1.0",
    user: "deploy"
