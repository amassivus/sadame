# frozen_string_literal: true

module Sadame
  # What a recipe can know about the machine it runs on, read from that
  # machine:
  #
  #   facts[:cpus]        # => 4
  #   facts[:memory_mb]   # => 7951
  #   facts[:ipv4]        # => "203.0.113.10"
  #
  # Each fact is read the first time it is asked for, then kept for the
  # rest of the run, so a recipe that uses none costs nothing. Reading a
  # fact never fails: what cannot be read is nil. Asking for a fact that
  # does not exist raises an error that lists the ones that do.
  #
  # Linux reads /proc, uname, nproc, df and ip (or /proc/net when ip is not
  # installed); macOS, for local runs, reads sysctl, ifconfig and route.
  class Facts
    # Every fact, in the order `sadame facts` prints them.
    NAMES = [
      :hostname, :fqdn, :arch, :kernel, :cpus, :memory_mb, :swap_mb, :root_disk_gb,
      :ipv4, :default_interface, :ipv4_addresses, :ipv6_addresses,
      :virtualization, :container, :service_manager, :machine_id
    ].freeze

    # sys_vendor or product_name from DMI, for machines without
    # systemd-detect-virt; the values are what systemd-detect-virt prints.
    DMI_VIRTUALIZATION = {
      "QEMU" => "qemu", "KVM" => "kvm", "VMware" => "vmware", "VirtualBox" => "oracle",
      "Xen" => "xen", "Bochs" => "bochs", "Parallels" => "parallels", "Amazon EC2" => "amazon",
      "Google Compute Engine" => "google"
    }.freeze

    def initialize(host)
      @host = host
      @values = {}
    end

    def [](name)
      key = name.to_s.to_sym
      unless NAMES.include?(key)
        known = NAMES.map { |fact| fact.to_s }.sort.join(", ")
        raise RecipeError, "unknown fact #{name.inspect} (facts: #{known})"
      end
      @values[key] = read(key) unless @values.key?(key)
      @values[key]
    end

    def fetch(name)
      self[name]
    end

    # Every fact, read now.
    def to_h
      result = {}
      NAMES.each { |name| result[name] = self[name] }
      result
    end

    def inspect
      "#<Sadame::Facts>"
    end

    private

    def shell
      @host.shell
    end

    def darwin?
      @host.platform.darwin?
    end

    # A plain case rather than send: the release binary's mruby has no
    # Kernel#send (that is mruby-metaprog, which only the test build has).
    def read(name)
      case name
      when :hostname then read_hostname
      when :fqdn then read_fqdn
      when :arch then read_arch
      when :kernel then read_kernel
      when :cpus then read_cpus
      when :memory_mb then read_memory_mb
      when :swap_mb then read_swap_mb
      when :root_disk_gb then read_root_disk_gb
      when :ipv4 then read_ipv4
      when :default_interface then read_default_interface
      when :ipv4_addresses then read_ipv4_addresses
      when :ipv6_addresses then read_ipv6_addresses
      when :virtualization then read_virtualization
      when :container then read_container
      when :service_manager then read_service_manager
      when :machine_id then read_machine_id
      end
    rescue StandardError
      nil
    end

    # The output of a command, stripped, or nil when it fails or prints
    # nothing.
    def output(command)
      result = shell.run(command)
      text = result.stdout.strip
      result.success? && !text.empty? ? text : nil
    end

    def integer(text)
      text && text.chars.all? { |char| "0123456789".include?(char) } ? text.to_i : nil
    end

    def read_hostname
      output("uname -n")
    end

    def read_fqdn
      name = output("hostname -f 2>/dev/null")
      name && !name.include?(" ") ? name : self[:hostname]
    end

    def read_arch
      output("uname -m")
    end

    def read_kernel
      output("uname -r")
    end

    def read_cpus
      integer(output(darwin? ? "sysctl -n hw.ncpu" : "nproc"))
    end

    def read_memory_mb
      return bytes_to_mb(integer(output("sysctl -n hw.memsize"))) if darwin?

      meminfo_mb("MemTotal")
    end

    def read_swap_mb
      if darwin?
        total = output("sysctl -n vm.swapusage").to_s.split(" ")[2].to_s
        return total.end_with?("M") ? total.chomp("M").to_f.round : nil
      end
      meminfo_mb("SwapTotal")
    end

    def read_root_disk_gb
      fields = output("df -Pk /").to_s.split("\n").last.to_s.split(" ")
      kilobytes = integer(fields[1])
      kilobytes ? (kilobytes / 1_048_576.0).round : nil
    end

    def read_ipv4
      return darwin_primary_ipv4 if darwin?

      route = default_route
      return route[:source] if route

      addresses = self[:ipv4_addresses]
      addresses.size == 1 ? addresses.first : nil
    end

    def read_default_interface
      return darwin_default_interface if darwin?

      route = default_route
      return route[:interface] if route

      proc_default_interface
    end

    def read_ipv4_addresses
      text = output(darwin? ? "ifconfig" : "ip -4 -o addr show")
      addresses = text ? words_after(text, "inet").map { |address| address.split("/").first } : proc_ipv4_addresses
      unique(addresses.reject { |address| address.start_with?("127.") })
    end

    def read_ipv6_addresses
      if darwin?
        addresses = words_after(output("ifconfig").to_s, "inet6").map { |address| address.split("%").first }
        return unique(addresses.reject { |address| address == "::1" || address.start_with?("fe80:") })
      end

      entries = shell.read_file("/proc/net/if_inet6").to_s.split("\n").map { |line| line.split(" ") }
      # Scope 00 is global; 10 is the loopback address, 20 link-local.
      unique(entries.select { |fields| fields[3] == "00" }.map { |fields| ipv6_from_hex(fields[0]) })
    end

    def read_virtualization
      return nil if darwin?

      detected = shell.run("systemd-detect-virt")
      text = detected.stdout.strip
      return (text == "none" ? nil : text) unless text.empty?

      container_marker || dmi_virtualization
    end

    def read_container
      return false if darwin?

      detected = shell.run("systemd-detect-virt --container")
      return detected.success? unless detected.stdout.strip.empty?

      !container_marker.nil?
    end

    def read_service_manager
      @host.init_system&.to_s
    end

    def read_machine_id
      return nil if darwin?

      id = shell.read_file("/etc/machine-id").to_s.strip
      id.empty? ? nil : id
    end

    def meminfo_mb(field)
      line = shell.read_file("/proc/meminfo").to_s.split("\n").find { |entry| entry.start_with?("#{field}:") }
      kilobytes = integer(line.to_s.split(" ")[1])
      kilobytes ? kilobytes / 1024 : nil
    end

    def bytes_to_mb(bytes)
      bytes ? bytes / 1_048_576 : nil
    end

    # The route to a public address, as `ip route get` reports it: which
    # interface and source address the machine would use. Nothing is sent.
    def default_route
      @default_route = route_lookup if @default_route.nil?
      @default_route == false ? nil : @default_route
    end

    def route_lookup
      words = output("ip -4 route get 1.1.1.1").to_s.split(" ")
      interface = words[words.index("dev") + 1] if words.include?("dev")
      source = words[words.index("src") + 1] if words.include?("src")
      interface && source ? { interface: interface, source: source } : false
    end

    # /proc/net/route lists the default route with destination 00000000.
    def proc_default_interface
      entries = shell.read_file("/proc/net/route").to_s.split("\n")[1..].to_a.map { |line| line.split(" ") }
      default = entries.find { |fields| fields[1] == "00000000" }
      default ? default[0] : nil
    end

    # The machine's own addresses in /proc/net/fib_trie: each "/32 host
    # LOCAL" line follows the address it is about.
    def proc_ipv4_addresses
      addresses = []
      previous = nil
      shell.read_file("/proc/net/fib_trie").to_s.split("\n").each do |line|
        addresses << previous if line.include?("/32 host LOCAL") && previous
        words = line.strip.split(" ")
        previous = words[1] if words[0] == "|--"
      end
      addresses
    end

    def darwin_default_interface
      line = output("route -n get default").to_s.split("\n").find { |entry| entry.strip.start_with?("interface:") }
      line ? line.split(":", 2)[1].strip : nil
    end

    def darwin_primary_ipv4
      interface = self[:default_interface]
      interface ? output("ipconfig getifaddr #{Shell.escape(interface)}") : nil
    end

    def container_marker
      return "docker" if shell.run("test -e /.dockerenv").success?
      return "podman" if shell.run("test -e /run/.containerenv").success?

      nil
    end

    def dmi_virtualization
      ["sys_vendor", "product_name"].each do |field|
        text = shell.read_file("/sys/class/dmi/id/#{field}").to_s.strip
        DMI_VIRTUALIZATION.each { |marker, name| return name if text.start_with?(marker) }
      end
      nil
    end

    # The words that follow each occurrence of keyword, such as the
    # addresses after "inet" in ip and ifconfig output.
    def words_after(text, keyword)
      words = text.split(" ")
      found = []
      words.each_with_index { |word, index| found << words[index + 1] if word == keyword && words[index + 1] }
      found
    end

    def unique(items)
      result = []
      items.each { |item| result << item unless result.include?(item) }
      result
    end

    # "20010db8000000000000000000000001" => "2001:db8::1"
    def ipv6_from_hex(hex)
      groups = []
      8.times { |index| groups << hex[index * 4, 4].to_i(16).to_s(16) }
      start, length = longest_zero_run(groups)
      return groups.join(":") if length < 2

      "#{groups[0, start].join(":")}::#{groups[(start + length)..].join(":")}"
    end

    def longest_zero_run(groups)
      best = [0, 0]
      index = 0
      while index < groups.size
        if groups[index] == "0"
          stop = index
          stop += 1 while stop < groups.size && groups[stop] == "0"
          best = [index, stop - index] if stop - index > best[1]
          index = stop
        else
          index += 1
        end
      end
      best
    end
  end
end
