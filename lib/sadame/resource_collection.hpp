#pragma once

#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "notification.hpp"
#include "resource.hpp"

namespace sadame {

// The ordered list of resources declared by a recipe and its includes, plus
// the notifications between them.
class ResourceCollection {
 public:
  void add(std::unique_ptr<Resource> resource);

  Resource *find(const std::string &id) const;
  const std::vector<std::unique_ptr<Resource>> &resources() const { return resources_; }
  std::size_t size() const { return resources_.size(); }

  // Notifications that fire when the given resource changes, whether they
  // were declared with #:notifies on it or #:subscribes on another resource.
  std::vector<Notification> notifications_from(const Resource &resource);

  // Checks every notification names declared resources and an action the
  // target supports, and indexes them by source. Recipe::load calls this once
  // the whole recipe is loaded, so mistakes surface before anything runs.
  void link_notifications();

 private:
  void validate_notification(const Notification &notification) const;

  std::vector<std::unique_ptr<Resource>> resources_;
  std::map<std::string, Resource *> by_id_;
  std::optional<std::map<std::string, std::vector<Notification>>> notifications_by_source_;
};

}  // namespace sadame
