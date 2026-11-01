file "/etc/motd", content: "hello\n"
include_recipe "roles/web", tags: [:web]
package "htop", tags: :tools
