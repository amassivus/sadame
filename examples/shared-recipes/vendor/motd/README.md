# motd

A login banner with the machine's name, a contact, and any lines a project
adds. Include it with `include_recipe "vendor/motd/recipe"`.

| Var | Default | Meaning |
|---|---|---|
| `motd_contact` | `"root@localhost"` | Who to ask about the machine. |
| `motd_lines` | `[]` | Lines shown between the name and the contact. |
