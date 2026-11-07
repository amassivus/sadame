#include "resource_collection.hpp"

#include <algorithm>

#include "errors.hpp"

namespace sadame {

void ResourceCollection::add(std::unique_ptr<Resource> resource) {
  if (by_id_.count(resource->id())) throw ResourceError(resource->id() + " is declared more than once");

  by_id_[resource->id()] = resource.get();
  resources_.push_back(std::move(resource));
  notifications_by_source_.reset();
}

Resource *ResourceCollection::find(const std::string &id) const {
  auto found = by_id_.find(id);
  return found == by_id_.end() ? nullptr : found->second;
}

std::vector<Notification> ResourceCollection::notifications_from(const Resource &resource) {
  if (!notifications_by_source_) link_notifications();
  auto found = notifications_by_source_->find(resource.id());
  return found == notifications_by_source_->end() ? std::vector<Notification>() : found->second;
}

void ResourceCollection::link_notifications() {
  std::map<std::string, std::vector<Notification>> index;
  for (const auto &resource : resources_) {
    for (const Notification &notification : resource->notifications()) {
      validate_notification(notification);
      index[notification.source_id].push_back(notification);
    }
  }
  notifications_by_source_ = index;
}

void ResourceCollection::validate_notification(const Notification &notification) const {
  bool notifies = notification.option == "notifies";
  const std::string &other_id = notifies ? notification.target_id : notification.source_id;
  if (!find(other_id)) {
    throw ResourceError(notification.declared_by + (notifies ? " notifies " : " subscribes to ") + other_id +
                        ", which is not declared");
  }

  Resource *target = find(notification.target_id);
  std::vector<std::string> actions = target->actions();
  if (std::find(actions.begin(), actions.end(), notification.action) != actions.end()) return;

  std::string supported;
  for (const std::string &action : actions) supported += (supported.empty() ? "" : ", ") + action;
  if (supported.empty()) supported = "none";
  throw ResourceError(notification.declared_by + " asks " + notification.target_id + " to " + notification.action +
                      ", but " + target->type_name() + " supports: " + supported);
}

}  // namespace sadame
