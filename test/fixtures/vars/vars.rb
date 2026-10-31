# Vars for tests: the file's last expression is the hash.
base = { workers: 2 }

base.merge(
  server_name: "example.com",
  workers: 4,
  "string_key" => "from string key"
)
