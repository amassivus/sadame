#pragma once

#include <string>
#include <vector>

#include "value.hpp"

namespace sadame {

// A request to run an action on one resource when another one changes,
// e.g. reload nginx after its configuration file changed.
//
// Declared from either side:
//
//   (file "/etc/nginx/nginx.conf" ... #:notifies '(reload "service[nginx]"))
//   (service "nginx" #:subscribes '(reload "file[/etc/nginx/nginx.conf]"))
//
// Both forms take a list of entries too, and an optional timing: delayed
// (the default) runs once at the end of apply, immediately runs right after
// the changed resource.
struct Notification {
  std::string action;
  std::string source_id;
  std::string target_id;
  std::string timing;
  std::string declared_by;
  std::string option;  // "notifies" or "subscribes"

  bool immediately() const { return timing == "immediately"; }

  // Identifies a delayed notification, which runs once however many
  // resources trigger it.
  std::string key() const { return action + " " + target_id; }

  Value to_h() const;

  // notifies: entries name the resource to act on.
  static std::vector<Notification> from_notifies(const Value &value, const std::string &resource_id);
  // subscribes: entries name the resource to watch.
  static std::vector<Notification> from_subscribes(const Value &value, const std::string &resource_id);
};

}  // namespace sadame
