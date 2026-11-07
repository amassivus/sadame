#pragma once

#include <functional>
#include <vector>

#include "output.hpp"
#include "report.hpp"
#include "resource_collection.hpp"
#include "selection.hpp"

namespace sadame {

// Runs plan, drift or apply over a loaded recipe on one host.
//
// plan and drift only read state; they differ in what the exit status means
// (see Report::exit_status). apply walks the resources in order, reads each
// resource's current state right before acting (earlier resources may have
// changed it), applies only when there is a difference, and stops at the
// first failure. Notifications marked immediately run right after the
// resource that triggered them; the others run once each at the end.
//
// With a selection (--tags, --skip-tags), only the selected resources are
// read, applied and reported; notifications still reach any resource.
class Runner {
 public:
  using Clock = std::function<double()>;

  Runner(Host &host, Output::Base &output, Clock clock = nullptr, Selection selection = Selection());

  Report plan(ResourceCollection &resources);
  Report drift(ResourceCollection &resources);
  Report apply(ResourceCollection &resources);

 private:
  Report check(const std::string &command, ResourceCollection &resources);
  std::vector<Resource *> start(const std::string &command, ResourceCollection &resources);
  void finish(Report &report, double started);
  Report::Entry check_entry(Resource &resource, ResourceCollection &resources);
  Report::Entry apply_entry(Resource &resource, ResourceCollection &resources);
  bool notify(const std::vector<Notification> &notifications, ResourceCollection &resources, Report &report,
              std::vector<Notification> &delayed);
  void run_delayed(const std::vector<Notification> &delayed, ResourceCollection &resources, Report &report);
  bool run_notification(const Notification &notification, ResourceCollection &resources, Report &report);
  bool record(Report &report, Report::NotificationRun run);
  static std::string error_message(const std::exception &error);

  Host &host_;
  Output::Base &output_;
  Clock clock_;
  Selection selection_;
};

}  // namespace sadame
