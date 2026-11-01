# PostgreSQL with its settings tuned through vars, on Debian, Ubuntu, Rocky
# and Arch. The tuning goes into its own file in a conf.d directory, so the
# distribution's postgresql.conf stays as it was installed.
data_dir = nil
case platform.family
when "debian"
  version = vars[:postgres_version] || vars[:debian_postgres_versions]["#{platform.id} #{platform.version}"]
  raise "set --var postgres_version=N for #{platform.description}" unless version

  package "postgresql" # creates and starts a cluster; its postgresql.conf includes conf.d
  conf_dir = "/etc/postgresql/#{version}/main/conf.d"
when "rhel", "arch"
  data_dir = platform.family == "rhel" ? "/var/lib/pgsql/data" : "/var/lib/postgres/data"
  initdb = if platform.family == "rhel"
             "postgresql-setup --initdb"
           else
             "runuser -u postgres -- initdb --locale=C.UTF-8 --encoding=UTF8 -D #{data_dir}"
           end
  package platform.family == "rhel" ? "postgresql-server" : "postgresql"
  exec "create the database cluster", command: initdb, creates: "#{data_dir}/PG_VERSION"
  conf_dir = "#{data_dir}/conf.d"
else
  raise "this example supports Debian/Ubuntu, Rocky/RHEL and Arch, not #{platform.description}"
end

# A quarter of the memory is PostgreSQL's usual starting point.
shared_buffers = vars[:shared_buffers] || "#{facts[:memory_mb] / 4}MB"

# The settings exist before PostgreSQL starts, so it never sees an
# include_dir that points nowhere.
directory conf_dir, owner: "postgres", group: "postgres", mode: "0700"
file "#{conf_dir}/tuning.conf",
     template: "tuning.conf.erb",
     locals: { shared_buffers: shared_buffers },
     owner: "postgres",
     group: "postgres",
     mode: "0640",
     notifies: [:restart, "service[postgresql]"]
if data_dir
  # Rocky's and Arch's postgresql.conf has include_dir commented out; this
  # turns that line into one that reads conf.d.
  line "include_dir = 'conf.d'",
       path: "#{data_dir}/postgresql.conf",
       match: /^#?\s*include_dir\s*=/,
       notifies: [:restart, "service[postgresql]"]
end

service "postgresql", enable: true, state: :running
