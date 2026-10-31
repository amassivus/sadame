# groups: only adds memberships; the docker group is created by the package.
package "docker.io"
user "deploy", groups: ["docker"]
