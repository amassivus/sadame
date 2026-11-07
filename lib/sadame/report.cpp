#include "report.hpp"

#include <algorithm>
#include <cmath>

#include "version.hpp"

namespace sadame {

namespace {

const std::vector<std::string> kPendingStatuses = {"create", "update", "remove", "run"};
const std::vector<std::string> kPlanStatuses = {"create", "update", "remove", "run", "unchanged", "failed"};
const std::vector<std::string> kApplyStatuses = {"changed", "unchanged", "failed", "skipped"};

Value string_array(const std::vector<std::string> &items) {
  Value result = Value::array();
  for (const std::string &item : items) result.push(Value(item));
  return result;
}

Value change_to_h(const Resource &resource, const Diff::Change &change) {
  Value hash = Value::map();
  hash.set("attribute", change.attribute);
  if (change.content()) {
    hash.set("sensitive", resource.sensitive());
    hash.set("diff", resource.sensitive()
                         ? Value()
                         : Value(Diff::unified(change.from.to_s(), change.to.to_s(), "current", "desired")));
  } else {
    hash.set("from", change.from);
    hash.set("to", change.to);
  }
  if (change.reason) hash.set("reason", *change.reason);
  return hash;
}

}  // namespace

bool Report::Entry::pending() const {
  return std::find(kPendingStatuses.begin(), kPendingStatuses.end(), status) != kPendingStatuses.end();
}

Value Report::Entry::to_h() const {
  Value hash = Value::map();
  hash.set("id", resource->id());
  hash.set("type", resource->type_name());
  hash.set("name", resource->name());
  hash.set("status", status);
  Value change_list = Value::array();
  for (const Diff::Change &change : changes) change_list.push(change_to_h(*resource, change));
  hash.set("changes", change_list);
  Value notification_list = Value::array();
  for (const Notification &notification : notifications) notification_list.push(notification.to_h());
  hash.set("notifications", notification_list);
  hash.set("error", error ? Value(*error) : Value());
  return hash;
}

Value Report::NotificationRun::to_h() const {
  Value hash = notification.to_h();
  hash.set("status", failed() ? "failed" : "ok");
  hash.set("error", error ? Value(*error) : Value());
  return hash;
}

bool Report::failed() const {
  return std::any_of(entries_.begin(), entries_.end(), [](const Entry &entry) { return entry.failed(); }) ||
         std::any_of(notification_runs_.begin(), notification_runs_.end(),
                     [](const NotificationRun &run) { return run.failed(); });
}

bool Report::drift() const {
  return std::any_of(entries_.begin(), entries_.end(), [](const Entry &entry) { return entry.pending(); });
}

int Report::exit_status() const {
  if (command_ == "apply") return failed() ? 1 : 0;
  if (failed()) return 2;
  if (command_ == "drift" && drift()) return 1;
  return 0;
}

std::vector<std::pair<std::string, int>> Report::counts() const {
  std::vector<std::pair<std::string, int>> result;
  for (const std::string &status : command_ == "apply" ? kApplyStatuses : kPlanStatuses) result.push_back({status, 0});
  for (const Entry &entry : entries_) {
    for (auto &[status, count] : result) {
      if (status == entry.status) ++count;
    }
  }
  return result;
}

std::vector<const Report::Entry *> Report::entries_with(const std::string &status) const {
  std::vector<const Entry *> result;
  for (const Entry &entry : entries_) {
    if (entry.status == status) result.push_back(&entry);
  }
  return result;
}

Value Report::to_h() {
  Value hash = Value::map();
  hash.set("format_version", kFormatVersion);
  hash.set("sadame_version", VERSION);
  hash.set("command", command_);
  hash.set("host", host_.name());
  hash.set("platform", host_.platform().to_h());
  hash.set("tags", string_array(selection_.tags()));
  hash.set("skip_tags", string_array(selection_.skip_tags()));

  Value resource_list = Value::array();
  for (const Entry &entry : entries_) resource_list.push(entry.to_h());
  hash.set("resources", resource_list);
  Value notification_list = Value::array();
  for (const NotificationRun &run : notification_runs_) notification_list.push(run.to_h());
  hash.set("notifications", notification_list);

  Value summary = Value::map();
  for (const auto &[status, count] : counts()) summary.set(status, count);
  hash.set("summary", summary);
  hash.set("drift", command_ == "apply" ? Value() : Value(drift()));
  hash.set("failed", failed());
  hash.set("exit_status", exit_status());
  hash.set("duration_seconds", duration ? Value(std::round(*duration * 100) / 100.0) : Value());
  return hash;
}

}  // namespace sadame
