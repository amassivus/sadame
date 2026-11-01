# PostgreSQL with its settings tuned through vars, on Debian, Ubuntu, Rocky
# and Arch. The tuning goes into its own file in a conf.d directory, so the
# distribution's postgresql.conf stays as it was installed.
case platform.family
when "debian"
  version = vars[:postgres_version] || vars[:debian_postgres_versions]["#{platform.id} #{platform.version}"]
  raise "set --var postgres_version=N for #{platform.description}" unless version

  package "postgresql"
  service "postgresql", enable: true, state: :running
  conf_dir = "/etc/postgresql/#{version}/main/conf.d" # Debian's postgresql.conf includes conf.d
when "rhel", "arch"
  data_dir = platform.family == "rhel" ? "/var/lib/pgsql/data" : "/var/lib/postgres/data"
  initdb = if platform.family == "rhel"
             "postgresql-setup --initdb"
           else
             "runuser -u postgres -- initdb --locale=C.UTF-8 --encoding=UTF8 -D #{data_dir}"
           end
  package platform.family == "rhel" ? "postgresql-server" : "postgresql"
  exec "create the database cluster", command: initdb, creates: "#{data_dir}/PG_VERSION"
  exec "include conf.d in postgresql.conf",
       command: "echo \"include_dir = 'conf.d'\" >> #{data_dir}/postgresql.conf",
       not_if: "grep -q \"^include_dir = 'conf.d'\" #{data_dir}/postgresql.conf"
  service "postgresql", enable: true, state: :running
  conf_dir = "#{data_dir}/conf.d"
else
  raise "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not #{platform.description}"
end

directory conf_dir, owner: "postgres", group: "postgres", mode: "0700"
file "#{conf_dir}/tuning.conf",
     template: "tuning.conf.erb",
     owner: "postgres",
     group: "postgres",
     mode: "0640",
     notifies: [:restart, "service[postgresql]"]
