# Settings for a small server with 2 GB of memory; scale shared_buffers to
# about a quarter of the memory.
{
  max_connections: 100,
  shared_buffers: "512MB",
  work_mem: "8MB",
  listen_addresses: "localhost",
  # The PostgreSQL version Debian and Ubuntu install, which names the
  # configuration directory. Override with --var postgres_version=N.
  postgres_version: nil,
  debian_postgres_versions: { "debian 13" => 17, "debian 12" => 15, "ubuntu 24.04" => 16, "ubuntu 22.04" => 14 }
}
