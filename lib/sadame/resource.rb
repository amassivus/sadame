# frozen_string_literal: true

module Sadame
  # Base class of every resource.
  #
  # A resource describes one piece of desired state (a package, a file, a
  # service...). Subclasses implement:
  #
  #   desired        Hash of the attributes this resource manages
  #   current        the same attributes, read from the host
  #   apply(changes) make the host match desired; changes is the list diff
  #                  returned
  #
  # diff compares desired and current. Nothing is applied when it is empty,
  # which is what makes every resource idempotent.
  class Resource
    COMMON_OPTIONS = [:notifies].freeze

    attr_reader :name, :options, :host, :source_dir, :vars, :notifications

    def self.type_name
      raise NotImplementedError, "#{self} must define type_name"
    end

    # Options this resource accepts in addition to COMMON_OPTIONS.
    def self.allowed_options
      []
    end

    # Actions other resources can trigger through notifies.
    def self.actions
      []
    end

    def initialize(name, options, host:, source_dir:, vars:)
      @name = name.to_s
      @options = options
      @host = host
      @source_dir = source_dir
      @vars = vars
      raise ResourceError, "#{self.class.type_name}: name must not be empty" if @name.empty?
      raise ResourceError, "#{id}: options must be a Hash, got #{options.class}" unless options.is_a?(Hash)

      validate_option_names
      @notifications = Notification.parse(options[:notifies], self)
      validate
    end

    def id
      "#{self.class.type_name}[#{name}]"
    end

    def desired
      raise NotImplementedError, "#{self.class} must define desired"
    end

    def current
      raise NotImplementedError, "#{self.class} must define current"
    end

    def diff
      Diff.changes(desired, current)
    end

    def apply(_changes)
      raise NotImplementedError, "#{self.class} must define apply"
    end

    # Runs an action requested by a notification.
    def run_action(action)
      raise ResourceError, "#{id} does not support the #{action} action"
    end

    # What a plan would do: :create, :remove, :update or :unchanged.
    def plan_action(changes)
      return :unchanged if changes.empty?

      state = changes.find { |change| change.attribute == :state }
      return :update if state.nil?
      return :create if state.from == "absent"
      return :remove if state.to == "absent"

      :update
    end

    # True when output must not show content diffs for this resource (see
    # the file resource's sensitive: option).
    def sensitive?
      false
    end

    private

    def shell
      host.shell
    end

    # Hook for subclasses to check option values when the resource is
    # declared, so mistakes surface before anything runs.
    def validate; end

    def validate_option_names
      allowed = COMMON_OPTIONS + self.class.allowed_options
      options.each_key do |key|
        next if allowed.include?(key)

        valid = allowed.map { |option| option.to_s }.sort.join(", ")
        raise ResourceError, "#{id}: unknown option #{key.inspect} (valid options: #{valid})"
      end
    end

    def validate_choice(key, choices)
      value = options[key]
      return if value.nil? || choices.include?(value.to_s)

      raise ResourceError, "#{id}: #{key} must be one of #{choices.join(", ")}, got #{value.inspect}"
    end

    def validate_boolean(key)
      value = options[key]
      return if value.nil? || value == true || value == false

      raise ResourceError, "#{id}: #{key} must be true or false, got #{value.inspect}"
    end

    def validate_mode
      return if options[:mode].nil? || PathStat.normalize_mode(options[:mode])

      raise ResourceError, "#{id}: mode must be a string of octal digits such as \"0644\", " \
                           "got #{options[:mode].inspect}"
    end

    def changed?(changes, attribute)
      changes.any? { |change| change.attribute == attribute }
    end

    def quote(value)
      Shell.escape(value)
    end

    # "owner:group", "owner" or ":group" for chown.
    def ownership(owner, group)
      return "#{owner}:#{group}" if owner && group
      return owner.to_s if owner

      ":#{group}"
    end
  end
end
