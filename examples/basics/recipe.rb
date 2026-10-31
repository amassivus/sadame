# Packages every machine in this example gets. vars come from vars.rb and
# --var; a recipe is plain Ruby, so a loop is just a loop.
vars[:base_packages].each do |name|
  package name
end

directory "/etc/sadame-demo", mode: "0755"

# Paths in include_recipe are relative to this file; ".rb" is optional.
include_recipe "parts/motd"
