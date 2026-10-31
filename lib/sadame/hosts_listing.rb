# frozen_string_literal: true

module Sadame
  # Output of `sadame hosts`: each selected target with the connection
  # options and vars it would get, and where each var came from.
  class HostsListing
    def initialize(io, color: false)
      @io = io
      @color = color
    end

    def render(targets, inventory_path)
      source = inventory_path ? "from #{inventory_path}" : "given with -h"
      noun = targets.size == 1 ? "host" : "hosts"
      line(bold("sadame #{VERSION} hosts: #{targets.size} #{noun} #{source}"))
      targets.each do |target|
        line
        print_target(target)
      end
    end

    def render_json(targets)
      document = {
        format_version: Report::FORMAT_VERSION,
        sadame_version: VERSION,
        command: "hosts",
        hosts: targets.map { |target| target.to_h }
      }
      @io.write(JsonWriter.generate(document))
    end

    private

    def print_target(target)
      line(bold(target.name))
      field("address", target.address)
      field("user", target.user || "(ssh default)")
      field("port", target.port ? target.port.to_s : "(ssh default)")
      field("sudo", target.sudo ? "yes" : "no")
      field("ssh_opts", target.ssh_opts.empty? ? "(none)" : target.ssh_opts.map { |opt| Shell.escape(opt) }.join(" "))
      field("groups", target.groups.empty? ? "(none)" : target.groups.join(", "))
      if target.vars.empty?
        field("vars", "(none)")
        return
      end

      line("  vars")
      print_vars(target)
    end

    def print_vars(target)
      names = target.vars.keys
      name_width = names.map { |name| name.to_s.size }.max + 2
      values = names.map { |name| RubyLiteral.dump(target.vars[name]) }
      value_width = values.map { |value| value.size }.max + 2
      names.each_with_index do |name, index|
        line("    #{name.to_s.ljust(name_width)}#{values[index].ljust(value_width)}#{target.var_sources[name]}")
      end
    end

    def field(label, value)
      line("  #{label.ljust(10)}#{value}")
    end

    def bold(text)
      @color ? "\e[1m#{text}\e[0m" : text
    end

    def line(text = "")
      @io.write("#{text.rstrip}\n")
    end
  end
end
