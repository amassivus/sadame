# frozen_string_literal: true

module Sadame
  # A machine to run on over SSH, with the connection options and vars that
  # apply to it.
  class Target
    attr_reader :name, :address, :user, :port, :sudo, :ssh_opts, :groups, :vars, :var_sources

    # Parses "[user@]host[:port]". IPv6 addresses go in brackets:
    # "admin@[2001:db8::1]:2222".
    def self.parse(spec)
      text = spec.to_s.strip
      user = nil
      if text.include?("@")
        user, text = text.split("@", 2)
        raise UsageError, "missing user name before @ in #{spec.inspect}" if user.empty?
      end
      host, port = split_port(text, spec)
      raise UsageError, "missing host name in #{spec.inspect}" if host.empty?

      [user, host, port]
    end

    def self.split_port(text, spec)
      if text.start_with?("[")
        closing = text.index("]")
        raise UsageError, "missing ] in #{spec.inspect}" if closing.nil?

        rest = text[(closing + 1)..]
        return [text[1...closing], nil] if rest.empty?
        raise UsageError, "unexpected #{rest.inspect} in #{spec.inspect}" unless rest.start_with?(":")

        return [text[1...closing], parse_port(rest[1..], spec)]
      end

      return [text, nil] unless text.include?(":")
      raise UsageError, "put IPv6 addresses in brackets: [#{text}]" if text.count(":") > 1

      host, port = text.split(":", 2)
      [host, parse_port(port, spec)]
    end

    def self.parse_port(text, spec)
      port = Vars.integer?(text) ? text.to_i : 0
      raise UsageError, "invalid port in #{spec.inspect}" unless port.between?(1, 65_535)

      port
    end

    def initialize(name, address: nil, user: nil, port: nil, sudo: false, ssh_opts: [], groups: [], vars: {},
                   var_sources: {})
      @name = name
      @address = address || name
      @user = user
      @port = port
      @sudo = sudo
      @ssh_opts = ssh_opts
      @groups = groups
      @vars = vars
      @var_sources = var_sources
    end

    # A copy with some attributes replaced.
    def with(**changes)
      Target.new(
        changes.fetch(:name, name), address: changes.fetch(:address, address), user: changes.fetch(:user, user),
                                    port: changes.fetch(:port, port), sudo: changes.fetch(:sudo, sudo),
                                    ssh_opts: changes.fetch(:ssh_opts, ssh_opts), groups: changes.fetch(:groups, groups),
                                    vars: changes.fetch(:vars, vars), var_sources: changes.fetch(:var_sources, var_sources)
      )
    end

    def to_h
      {
        name: name,
        address: address,
        user: user,
        port: port,
        sudo: sudo,
        ssh_opts: ssh_opts,
        groups: groups.map { |group| group.to_s },
        vars: vars,
        var_sources: var_sources
      }
    end
  end
end
