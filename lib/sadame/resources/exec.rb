# frozen_string_literal: true

module Sadame
  # Runs a shell command. To stay idempotent it needs a guard that tells
  # sadame when the work is already done:
  #
  #   exec "certbot --nginx -d example.com",
  #        not_if: "test -f /etc/letsencrypt/live/example.com/fullchain.pem"
  #   exec "make install", cwd: "/opt/app", creates: "/usr/local/bin/app"
  #   exec "systemctl daemon-reload", only_if: "test -f /etc/systemd/system/app.service"
  #
  # The command runs when every given guard agrees: creates: names a path
  # that is missing, not_if: exits non-zero and only_if: exits zero. Without
  # any guard it runs on every apply and always shows up in plan and drift.
  # Guards run during plan too, so they must not change anything.
  class ExecResource < Resource
    IDENTIFIER_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"

    def self.type_name
      "exec"
    end

    def self.allowed_options
      [:command, :only_if, :not_if, :creates, :cwd, :env]
    end

    def self.actions
      [:run]
    end

    def command
      (options[:command] || name).to_s
    end

    def diff
      reason = pending_reason
      return [] if reason.nil?

      [Diff::Change.new(:command, nil, command, reason: reason)]
    end

    def plan_action(changes)
      changes.empty? ? :unchanged : :run
    end

    def apply(_changes)
      shell.run!(script(command))
    end

    def run_action(action)
      raise ResourceError, "#{id} does not support the #{action} action" unless action == :run

      shell.run!(script(command))
    end

    # The command as sh sees it, with env: exported and cwd: entered first.
    def script(text)
      lines = []
      (options[:env] || {}).each { |key, value| lines << "export #{key}=#{quote(value)}" }
      if options[:cwd]
        lines << "cd #{quote(options[:cwd])} && {"
        lines << text
        lines << "}"
      else
        lines << text
      end
      lines.join("\n")
    end

    private

    def validate
      [:command, :only_if, :not_if, :creates, :cwd].each do |key|
        value = options[key]
        next if value.nil? || value.is_a?(String)

        raise ResourceError, "#{id}: #{key} must be a String, got #{value.class}"
      end
      validate_env
    end

    def validate_env
      env = options[:env]
      return if env.nil?
      raise ResourceError, "#{id}: env must be a Hash" unless env.is_a?(Hash)

      env.each_key do |key|
        next if valid_variable_name?(key.to_s)

        raise ResourceError, "#{id}: env key #{key.inspect} is not a valid variable name"
      end
    end

    def valid_variable_name?(name)
      !name.empty? && !"0123456789".include?(name[0]) &&
        name.chars.all? { |char| IDENTIFIER_CHARACTERS.include?(char) }
    end

    # Why the command still has to run, or nil when a guard says it is done.
    def pending_reason
      reasons = []
      if options[:creates]
        return nil if guard_passes?("test -e #{quote(options[:creates])}")

        reasons << "#{options[:creates]} does not exist"
      end
      if options[:not_if]
        return nil if guard_passes?(options[:not_if])

        reasons << "not_if exited non-zero"
      end
      if options[:only_if]
        return nil unless guard_passes?(options[:only_if])

        reasons << "only_if exited zero"
      end
      reasons.empty? ? "no guard, runs on every apply" : reasons.join(", ")
    end

    def guard_passes?(guard)
      shell.run(script(guard)).success?
    end
  end
end
