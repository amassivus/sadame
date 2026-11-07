#pragma once

#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "diff.hpp"
#include "host.hpp"
#include "notification.hpp"
#include "resource.hpp"
#include "selection.hpp"

namespace sadame {

// The outcome of a plan, drift or apply run: one entry per resource, the
// notifications that ran, and the exit status that follows from them.
class Report {
 public:
  // One resource's result.
  //
  // plan and drift statuses: create, update, remove, run, unchanged, failed.
  // apply statuses: changed, unchanged, failed, skipped.
  struct Entry {
    Entry(Resource &resource, std::string status, std::vector<Diff::Change> changes = {},
          std::vector<Notification> notifications = {}, std::optional<std::string> error = std::nullopt)
        : resource(&resource),
          status(std::move(status)),
          changes(std::move(changes)),
          notifications(std::move(notifications)),
          error(std::move(error)) {}

    Resource *resource;
    std::string status;
    std::vector<Diff::Change> changes;
    std::vector<Notification> notifications;
    std::optional<std::string> error;

    bool failed() const { return status == "failed"; }
    bool unchanged() const { return status == "unchanged"; }
    // True when plan or drift found a difference for this resource.
    bool pending() const;
    Value to_h() const;
  };

  // A notification that ran during apply.
  struct NotificationRun {
    explicit NotificationRun(Notification notification, std::optional<std::string> error = std::nullopt)
        : notification(std::move(notification)), error(std::move(error)) {}

    Notification notification;
    std::optional<std::string> error;

    bool failed() const { return error.has_value(); }
    Value to_h() const;
  };

  static constexpr int kFormatVersion = 1;

  Report(std::string command, Host &host, Selection selection = Selection())
      : command_(std::move(command)), host_(host), selection_(std::move(selection)) {}

  const std::string &command() const { return command_; }
  Host &host() { return host_; }
  const Selection &selection() const { return selection_; }
  const std::vector<Entry> &entries() const { return entries_; }
  const std::vector<NotificationRun> &notification_runs() const { return notification_runs_; }
  std::optional<double> duration;

  void add(Entry entry) { entries_.push_back(std::move(entry)); }
  void add_notification_run(NotificationRun run) { notification_runs_.push_back(std::move(run)); }

  bool failed() const;
  // True when plan or drift found at least one resource that differs from
  // the recipe.
  bool drift() const;

  // 0: success (plan computed, apply converged, drift found nothing).
  // 1: apply had a failure, or drift found differences.
  // 2: plan or drift could not read the state of every resource.
  int exit_status() const;

  // Number of entries per status, in a fixed order.
  std::vector<std::pair<std::string, int>> counts() const;
  std::vector<const Entry *> entries_with(const std::string &status) const;

  Value to_h();

 private:
  std::string command_;
  Host &host_;
  Selection selection_;
  std::vector<Entry> entries_;
  std::vector<NotificationRun> notification_runs_;
};

}  // namespace sadame
