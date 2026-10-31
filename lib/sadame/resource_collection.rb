# frozen_string_literal: true

module Sadame
  # The ordered list of resources declared by a recipe and its includes.
  class ResourceCollection
    def initialize
      @resources = []
      @by_id = {}
    end

    def add(resource)
      if @by_id.key?(resource.id)
        raise ResourceError, "#{resource.id} is declared more than once"
      end

      @resources << resource
      @by_id[resource.id] = resource
    end

    def find(id)
      @by_id[id]
    end

    def each(&block)
      @resources.each(&block)
    end

    def to_a
      @resources.dup
    end

    def size
      @resources.size
    end

    # Every notification must name a declared resource and an action that
    # resource supports. Checked once the whole recipe is loaded.
    def validate_notifications
      @resources.each do |resource|
        resource.notifications.each { |notification| validate_notification(notification) }
      end
    end

    private

    def validate_notification(notification)
      target = find(notification.target_id)
      if target.nil?
        raise ResourceError, "#{notification.source.id} notifies #{notification.target_id}, " \
                             "which is not declared"
      end
      return if target.class.actions.include?(notification.action)

      supported = target.class.actions.map { |action| action.to_s }.join(", ")
      supported = "none" if supported.empty?
      raise ResourceError, "#{notification.source.id} notifies #{notification.target_id} " \
                           "to #{notification.action}, but #{target.class.type_name} supports: #{supported}"
    end
  end
end
