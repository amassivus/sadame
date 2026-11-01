# A project's recipe that uses a recipe shared from another repository.
# vendor/motd stands for a git submodule: in a real project it would be
# added with
#
#   git submodule add https://github.com/example/sadame-motd.git vendor/motd
#
# and pinned to a tag there. Its files are copied here so the tests run it.
include_recipe "vendor/motd/recipe", tags: [:motd]

# The project's own resources follow, as usual.
directory "/etc/demo-shared", mode: "0755"
file "/etc/demo-shared/owner", content: "#{vars[:motd_contact]}\n", mode: "0644"
