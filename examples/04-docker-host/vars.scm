'((docker_packages . ("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"))
  (docker_users . ("deploy"))
  (log_max_size . "10m")
  (log_max_files . 3))
