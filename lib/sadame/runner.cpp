#include "runner.hpp"

#include <algorithm>
#include <chrono>

#include "errors.hpp"

namespace sadame {

namespace {

double now() {
  using namespace std::chrono;
  return duration<double>(steady_clock::now().time_since_epoch()).count();
}

}  // namespace

Runner::Runner(Host &host, Output::Base &output, Clock clock, Selection selection)
    : host_(host), output_(output), clock_(clock ? std::move(clock) : Clock(now)), selection_(std::move(selection)) {}

Report Runner::plan(ResourceCollection &resources) { return check("plan", resources); }

Report Runner::drift(ResourceCollection &resources) { return check("drift", resources); }

Report Runner::apply(ResourceCollection &resources) {
  Report report("apply", host_, selection_);
  double started = clock_();
  std::vector<Resource *> selected = start("apply", resources);
  std::vector<Notification> delayed;
  bool stopped = false;

  for (Resource *resource : selected) {
    Report::Entry entry = stopped ? Report::Entry(*resource, "skipped") : apply_entry(*resource, resources);
    report.add(entry);
    output_.applied(entry);
    stopped = stopped || entry.failed();
    if (stopped || entry.status != "changed") continue;

    stopped = !notify(entry.notifications, resources, report, delayed);
  }

  if (!stopped) run_delayed(delayed, resources, report);
  finish(report, started);
  return report;
}

Report Runner::check(const std::string &command, ResourceCollection &resources) {
  Report report(command, host_, selection_);
  double started = clock_();
  for (Resource *resource : start(command, resources)) {
    Report::Entry entry = check_entry(*resource, resources);
    report.add(entry);
    output_.planned(entry);
  }
  finish(report, started);
  return report;
}

// Prints the header and returns the resources to work on.
std::vector<Resource *> Runner::start(const std::string &command, ResourceCollection &resources) {
  std::vector<Resource *> selected;
  for (const auto &resource : resources.resources()) {
    if (selection_.includes(*resource)) selected.push_back(resource.get());
  }
  std::optional<std::string> note;
  if (!selection_.all()) note = selection_.description(selected.size(), resources.size());
  output_.start(command, host_, note);
  return selected;
}

void Runner::finish(Report &report, double started) {
  report.duration = clock_() - started;
  output_.finish(report);
}

Report::Entry Runner::check_entry(Resource &resource, ResourceCollection &resources) {
  try {
    std::vector<Diff::Change> changes = resource.diff();
    std::vector<Notification> notifications;
    if (!changes.empty()) notifications = resources.notifications_from(resource);
    std::string status = resource.plan_action(changes);
    return Report::Entry(resource, status, changes, notifications);
  } catch (const std::exception &error) {
    return Report::Entry(resource, "failed", {}, {}, error_message(error));
  }
}

Report::Entry Runner::apply_entry(Resource &resource, ResourceCollection &resources) {
  std::vector<Diff::Change> changes;
  try {
    changes = resource.diff();
    if (changes.empty()) return Report::Entry(resource, "unchanged");

    resource.apply(changes);
    return Report::Entry(resource, "changed", changes, resources.notifications_from(resource));
  } catch (const std::exception &error) {
    return Report::Entry(resource, "failed", changes, {}, error_message(error));
  }
}

// Runs immediate notifications now and queues delayed ones. Returns false
// when an immediate notification failed, which stops the run.
bool Runner::notify(const std::vector<Notification> &notifications, ResourceCollection &resources, Report &report,
                    std::vector<Notification> &delayed) {
  for (const Notification &notification : notifications) {
    if (notification.immediately()) {
      if (!run_notification(notification, resources, report)) return false;
    } else if (std::none_of(delayed.begin(), delayed.end(),
                            [&](const Notification &queued) { return queued.key() == notification.key(); })) {
      delayed.push_back(notification);
    }
  }
  return true;
}

void Runner::run_delayed(const std::vector<Notification> &delayed, ResourceCollection &resources, Report &report) {
  for (const Notification &notification : delayed) run_notification(notification, resources, report);
}

bool Runner::run_notification(const Notification &notification, ResourceCollection &resources, Report &report) {
  try {
    resources.find(notification.target_id)->run_action(notification.action);
    return record(report, Report::NotificationRun(notification));
  } catch (const std::exception &error) {
    return record(report, Report::NotificationRun(notification, error_message(error)));
  }
}

bool Runner::record(Report &report, Report::NotificationRun run) {
  report.add_notification_run(run);
  output_.notified(run);
  return !run.failed();
}

// Our own errors carry a message meant for users; anything else is a bug or
// an unexpected condition, so keep its class name visible.
std::string Runner::error_message(const std::exception &error) {
  if (dynamic_cast<const Error *>(&error)) return error.what();
  return error_class_name(error) + ": " + error.what();
}

}  // namespace sadame
