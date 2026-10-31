# frozen_string_literal: true

module Sadame
  # A request to run an action on one resource when another one changes,
  # e.g. reload nginx after its configuration file changed.
  #
  # Declared from either side:
  #
  #   file "/etc/nginx/nginx.conf", ..., notifies: [:reload, "service[nginx]"]
  #   service "nginx", subscribes: [:reload, "file[/etc/nginx/nginx.conf]"]
  #
  # Both forms take a list of entries too, and an optional timing:
  # :delayed (the default) runs once at the end of apply, :immediately runs
  # right after the changed resource.
  class Notification
    TIMINGS = [:delayed, :immediately].freeze

    attr_reader :action, :source_id, :target_id, :timing, :declared_by, :option

    # notifies: entries name the resource to act on.
    def self.from_notifies(value, resource)
      entries(value, resource, :notifies).map do |action, other_id, timing|
        new(action, source_id: resource.id, target_id: other_id, timing: timing,
                    declared_by: resource.id, option: :notifies)
      end
    end

    # subscribes: entries name the resource to watch.
    def self.from_subscribes(value, resource)
      entries(value, resource, :subscribes).map do |action, other_id, timing|
        new(action, source_id: other_id, target_id: resource.id, timing: timing,
                    declared_by: resource.id, option: :subscribes)
      end
    end

    def self.entries(value, resource, option)
      return [] if value.nil?

      list = value.is_a?(Array) && value.first.is_a?(Array) ? value : [value]
      list.map { |entry| validate_entry(entry, resource, option) }
    end

    def self.validate_entry(entry, resource, option)
      unless entry.is_a?(Array) && entry.size.between?(2, 3) && entry[0].is_a?(Symbol) && entry[1].is_a?(String)
        raise ResourceError, "#{resource.id}: #{option} expects [:action, \"type[name]\"] " \
                             "or [:action, \"type[name]\", :immediately]"
      end

      timing = entry[2] || :delayed
      unless TIMINGS.include?(timing)
        raise ResourceError, "#{resource.id}: #{option} timing must be :delayed or :immediately, " \
                             "got #{timing.inspect}"
      end

      [entry[0], entry[1], timing]
    end

    def initialize(action, source_id:, target_id:, timing:, declared_by:, option:)
      @action = action
      @source_id = source_id
      @target_id = target_id
      @timing = timing
      @declared_by = declared_by
      @option = option
    end

    def immediately?
      timing == :immediately
    end

    # Identifies a delayed notification, which runs once however many
    # resources trigger it.
    def key
      "#{action} #{target_id}"
    end

    def to_h
      { action: action.to_s, source: source_id, target: target_id, timing: timing.to_s }
    end
  end
end
