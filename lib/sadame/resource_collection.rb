# frozen_string_literal: true

module Sadame
  # The ordered list of resources declared by a recipe and its includes,
  # plus the notifications between them.
  class ResourceCollection
    def initialize
      @resources = []
      @by_id = {}
      @notifications_by_source = nil
    end

    def add(resource)
      if @by_id.key?(resource.id)
        raise ResourceError, "#{resource.id} is declared more than once"
      end

      @resources << resource
      @by_id[resource.id] = resource
      @notifications_by_source = nil
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

    # Notifications that fire when the given resource changes, whether they
    # were declared with notifies: on it or subscribes: on another resource.
    def notifications_from(resource)
      link_notifications if @notifications_by_source.nil?
      @notifications_by_source[resource.id] || []
    end

    # Checks every notification names declared resources and an action the
    # target supports, and indexes them by source. Recipe.load calls this
    # once the whole recipe is loaded, so mistakes surface before anything
    # runs.
    def link_notifications
      index = {}
      @resources.each do |resource|
        resource.notifications.each do |notification|
          validate_notification(notification)
          (index[notification.source_id] ||= []) << notification
        end
      end
      @notifications_by_source = index
    end

    private

    def validate_notification(notification)
      other_id = notification.option == :notifies ? notification.target_id : notification.source_id
      if find(other_id).nil?
        verb = notification.option == :notifies ? "notifies" : "subscribes to"
        raise ResourceError, "#{notification.declared_by} #{verb} #{other_id}, which is not declared"
      end

      target = find(notification.target_id)
      return if target.class.actions.include?(notification.action)

      supported = target.class.actions.map { |action| action.to_s }.join(", ")
      supported = "none" if supported.empty?
      raise ResourceError, "#{notification.declared_by} asks #{notification.target_id} " \
                           "to #{notification.action}, but #{target.class.type_name} supports: #{supported}"
    end
  end
end
