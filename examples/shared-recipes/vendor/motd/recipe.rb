# A login banner, shared between projects. A project sets motd_contact,
# and optionally motd_lines, in its vars; the defaults are below.
contact = vars.fetch(:motd_contact, "root@localhost")
lines = vars.fetch(:motd_lines, [])

file "/etc/motd",
     template: "motd.erb",
     locals: { contact: contact, lines: lines },
     mode: "0644"
