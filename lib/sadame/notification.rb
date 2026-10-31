# frozen_string_literal: true

module Sadame
  # A request from one resource to run an action on another when the first
  # one changes, e.g. reload nginx after its configuration file changed.
  #
  #   notifies: [:reload, "service[nginx]"]
  #   notifies: [[:reload, "service[nginx]"], [:run, "exec[rebuild-cache]"]]
  class Notification
    attr_reader :action, :target_id, :source

    def self.parse(value, source)
      return [] if value.nil?

      entries = value.is_a?(Array) && value.first.is_a?(Array) ? value : [value]
      entries.map { |entry| from_entry(entry, source) }
    end

    def self.from_entry(entry, source)
      unless entry.is_a?(Array) && entry.size == 2 && entry[0].is_a?(Symbol) && entry[1].is_a?(String)
        raise ResourceError, "#{source.id}: notifies expects [:action, \"type[name]\"], " \
                             "for example [:reload, \"service[nginx]\"]"
      end

      new(entry[0], entry[1], source)
    end

    def initialize(action, target_id, source)
      @action = action
      @target_id = target_id
      @source = source
    end

    def key
      "#{action} #{target_id}"
    end

    def to_h
      { action: action.to_s, target: target_id, source: source.id }
    end
  end
end
