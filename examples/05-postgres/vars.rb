# Settings for PostgreSQL. shared_buffers is a quarter of the machine's
# memory unless it is set here or with --var shared_buffers=1GB.
{
  max_connections: 100,
  shared_buffers: nil,
  work_mem: "8MB",
  listen_addresses: "localhost",
  # The PostgreSQL version Debian and Ubuntu install, which names the
  # configuration directory. Override with --var postgres_version=N.
  postgres_version: nil,
  debian_postgres_versions: { "debian 13" => 17, "debian 12" => 15, "ubuntu 24.04" => 16, "ubuntu 22.04" => 14 }
}
