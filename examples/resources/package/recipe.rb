# Package names are the distribution's own; these exist on Debian, Ubuntu,
# Rocky (with EPEL for htop), Alpine and Arch.
package "tree"
package "htop"

# Make sure a package is not installed.
package "nano", state: :absent
