# Inline content.
file "/etc/issue.net", content: "Authorized access only.\n", mode: "0644"

# A template, rendered with vars (from vars.rb or --var) and locals.
directory "/etc/hello"
file "/etc/hello/hello.conf",
     template: "hello.conf.erb",
     locals: { port: 8080 },
     mode: "0640",
     owner: "root",
     group: "root"

# A file copied as is from the files/ directory.
file "/usr/local/bin/hello", source: "hello.sh", mode: "0755"

# Make sure a file does not exist.
file "/etc/hello/old.conf", state: :absent
