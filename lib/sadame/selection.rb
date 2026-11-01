# frozen_string_literal: true

module Sadame
  # Which resources a run works on, from --tags and --skip-tags:
  #
  #   sadame apply site.rb --tags nginx         only resources tagged nginx
  #   sadame apply site.rb --skip-tags slow     everything not tagged slow
  #
  # Resources outside the selection are not read or changed and are left
  # out of the report, but notifications can still act on them.
  class Selection
    attr_reader :tags, :skip_tags

    def initialize(tags: [], skip_tags: [])
      @tags = tags
      @skip_tags = skip_tags
    end

    def all?
      tags.empty? && skip_tags.empty?
    end

    def include?(resource)
      return false unless (resource.tags & skip_tags).empty?

      tags.empty? || !(resource.tags & tags).empty?
    end

    # "Only resources tagged nginx: 3 of 12."
    def description(selected, total)
      parts = []
      parts << "tagged #{tags.join(", ")}" unless tags.empty?
      parts << "not tagged #{skip_tags.join(", ")}" unless skip_tags.empty?
      "Only resources #{parts.join(" and ")}: #{selected} of #{total}."
    end
  end
end
