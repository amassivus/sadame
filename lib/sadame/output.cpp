#include "output.hpp"

#include <cstdio>
#include <map>
#include <sstream>

#include "json_writer.hpp"
#include "version.hpp"

namespace sadame {
namespace Output {

namespace {

const std::map<std::string, int> kColors = {{"bold", 1}, {"dim", 2},    {"red", 31},
                                             {"green", 32}, {"yellow", 33}, {"cyan", 36}};
const std::map<std::string, std::string> kPlanSymbols = {
    {"create", "+"}, {"update", "~"}, {"remove", "-"}, {"run", "!"}, {"failed", "x"}};
const std::map<std::string, std::string> kPlanColors = {
    {"create", "green"}, {"update", "yellow"}, {"remove", "red"}, {"run", "cyan"}, {"failed", "red"}};
const std::map<std::string, std::string> kApplyColors = {{"changed", "yellow"}, {"unchanged", "dim"}, {"failed", "red"},
                                                         {"skipped", "dim"},    {"notified", "cyan"}};
const std::map<std::string, std::string> kPlanLabels = {{"create", "to create"}, {"update", "to update"},
                                                        {"remove", "to remove"}, {"run", "to run"},
                                                        {"unchanged", "unchanged"}, {"failed", "failed"}};

const std::string kPlanIndent = "    ";
const std::string kApplyIndent = "           ";
constexpr std::size_t kSummaryLabelWidth = 11;
constexpr std::size_t kSummaryCountWidth = 3;

std::string ljust(const std::string &text, std::size_t width) {
  return text.size() >= width ? text : text + std::string(width - text.size(), ' ');
}

std::string rjust(const std::string &text, std::size_t width) {
  return text.size() >= width ? text : std::string(width - text.size(), ' ') + text;
}

std::string plural(std::size_t count, const std::string &noun) {
  return count == 1 ? "1 " + noun : std::to_string(count) + " " + noun + "s";
}

std::vector<std::string> split_lines(const std::string &text) {
  std::vector<std::string> result;
  std::istringstream stream(text);
  std::string line;
  while (std::getline(stream, line)) result.push_back(line);
  return result;
}

std::string format_value(const Value &value) {
  if (value.is_nil()) return "(none)";
  if (value.is_array()) {
    if (value.items().empty()) return "(none)";
    std::string result;
    for (std::size_t index = 0; index < value.items().size(); ++index) {
      if (index > 0) result += ", ";
      result += value.items()[index].to_s();
    }
    return result;
  }
  return value.to_s();
}

bool starts_with(const std::string &text, const std::string &prefix) { return text.rfind(prefix, 0) == 0; }

std::string lookup(const std::map<std::string, std::string> &table, const std::string &key) {
  auto found = table.find(key);
  return found == table.end() ? "" : found->second;
}

}  // namespace

std::string Human::paint(const std::string &text, const std::string &color) const {
  if (!color_ || color.empty()) return text;
  return "\033[" + std::to_string(kColors.at(color)) + "m" + text + "\033[0m";
}

void Human::line(const std::string &text) { io_ << text << "\n"; }

void Human::start(const std::string &command, Host &host, const std::optional<std::string> &note) {
  line(paint(std::string("sadame ") + VERSION + " " + command + " on " + host.name() + " (" +
                 host.platform().description() + ")",
             "bold"));
  if (note) line(paint(*note, "cyan"));
  line();
}

void Human::planned(const Report::Entry &entry) {
  if (entry.unchanged()) return;

  line(paint(lookup(kPlanSymbols, entry.status) + " " + entry.resource->id(), lookup(kPlanColors, entry.status)));
  details(entry, kPlanIndent);
  for (const Notification &notification : entry.notifications) {
    std::string text = "notifies: " + notification.action + " " + notification.target_id + " (" + notification.timing + ")";
    line(kPlanIndent + paint(text, "cyan"));
  }
  line();
}

void Human::applied(const Report::Entry &entry) {
  line(paint(ljust(entry.status, kApplyIndent.size()), lookup(kApplyColors, entry.status)) + entry.resource->id());
  if (!entry.unchanged()) details(entry, kApplyIndent);
}

void Human::notified(const Report::NotificationRun &run) {
  const Notification &notification = run.notification;
  std::string label = run.failed() ? "failed" : "notified";
  line(paint(ljust(label, kApplyIndent.size()), run.failed() ? "red" : "cyan") + notification.target_id + ": " +
       notification.action + " (" + notification.timing + ", from " + notification.source_id + ")");
  if (run.failed()) indented("error: " + *run.error, kApplyIndent, "red");
}

void Human::finish(Report &report) {
  if (report.command() == "plan") {
    line(paint(plan_summary(report), "bold"));
  } else if (report.command() == "drift") {
    drift_summary(report);
  } else {
    apply_summary(report);
  }
}

void Human::details(const Report::Entry &entry, const std::string &indent) {
  for (const Diff::Change &change : entry.changes) change_lines(*entry.resource, change, indent);
  if (entry.error) indented("error: " + *entry.error, indent, "red");
}

void Human::change_lines(const Resource &resource, const Diff::Change &change, const std::string &indent) {
  if (change.content()) {
    content_lines(resource, change, indent);
  } else {
    std::string transition = change.from.is_nil() ? format_value(change.to)
                                                  : format_value(change.from) + " -> " + format_value(change.to);
    line(indent + change.attribute + ": " + transition);
  }
  if (change.reason) line(indent + paint("(" + *change.reason + ")", "dim"));
}

void Human::content_lines(const Resource &resource, const Diff::Change &change, const std::string &indent) {
  if (resource.sensitive()) {
    line(indent + "content: (sensitive, diff hidden)");
    return;
  }

  std::string old_label = change.from.is_nil() ? "/dev/null" : resource.content_path();
  std::string diff = Diff::unified(change.from.to_s(), change.to.to_s(), old_label, resource.content_path() + " (desired)");
  for (const std::string &diff_line : split_lines(diff)) line(indent + paint_diff_line(diff_line));
}

std::string Human::paint_diff_line(const std::string &text) const {
  if (starts_with(text, "---") || starts_with(text, "+++")) return paint(text, "bold");
  if (starts_with(text, "@@")) return paint(text, "cyan");
  if (starts_with(text, "-")) return paint(text, "red");
  if (starts_with(text, "+")) return paint(text, "green");
  return text;
}

std::string Human::plan_summary(const Report &report) const {
  std::string parts;
  for (const auto &[status, count] : report.counts()) {
    if (status == "failed" && count == 0) continue;
    if (!parts.empty()) parts += ", ";
    parts += std::to_string(count) + " " + kPlanLabels.at(status);
  }
  return "Plan: " + parts + ".";
}

void Human::drift_summary(const Report &report) {
  std::size_t total = report.entries().size();
  std::size_t drifted = 0;
  for (const Report::Entry &entry : report.entries()) {
    if (entry.pending()) ++drifted;
  }

  if (drifted > 0) {
    std::string verb = drifted == 1 ? "differs" : "differ";
    line(paint("Drift: " + std::to_string(drifted) + " of " + plural(total, "resource") + " " + verb + " from the recipe.",
               "yellow"));
  } else if (!report.failed()) {
    std::string verb = total == 1 ? "matches" : "match";
    line(paint("No drift: " + plural(total, "resource") + " " + verb + " the recipe.", "green"));
  }

  std::size_t failed = report.entries_with("failed").size();
  if (failed == 0) return;
  line(paint("Could not check " + plural(failed, "resource") + "; see the errors above.", "red"));
}

// A table of results by status, then the run time:
//
//   Summary
//     changed      2  package[nginx]
//                     file[/etc/nginx/nginx.conf]
//     unchanged    5
//     failed       0
//     skipped      0
//     notified     1  service[nginx]: reload
void Human::apply_summary(const Report &report) {
  line();
  line(paint("Summary", "bold"));
  for (const auto &[status, count] : report.counts()) {
    std::vector<std::string> ids;
    if (status != "unchanged") {
      for (const Report::Entry *entry : report.entries_with(status)) ids.push_back(entry->resource->id());
    }
    summary_row(status, count, ids);
  }

  std::vector<std::string> runs;
  for (const Report::NotificationRun &run : report.notification_runs()) {
    std::string text = run.notification.target_id + ": " + run.notification.action;
    runs.push_back(run.failed() ? text + " (failed)" : text);
  }
  summary_row("notified", static_cast<int>(runs.size()), runs);
  line();

  char buffer[64];
  std::snprintf(buffer, sizeof buffer, "Finished in %.2fs.", report.duration.value_or(0.0));
  line(paint(buffer, "bold"));
}

void Human::summary_row(const std::string &status, int count, const std::vector<std::string> &items) {
  std::string label = ljust(status, kSummaryLabelWidth);
  if (count > 0) label = paint(label, lookup(kApplyColors, status));
  std::string prefix = "  " + label + rjust(std::to_string(count), kSummaryCountWidth);
  if (items.empty()) {
    line(prefix);
    return;
  }

  std::string continuation(2 + kSummaryLabelWidth + kSummaryCountWidth + 2, ' ');
  line(prefix + "  " + items.front());
  for (std::size_t index = 1; index < items.size(); ++index) line(continuation + items[index]);
}

void Human::indented(const std::string &text, const std::string &indent, const std::string &color) {
  for (const std::string &text_line : split_lines(text)) line(indent + paint(text_line, color));
}

void Json::finish(Report &report) { io_ << JsonWriter::generate(report.to_h()); }

}  // namespace Output
}  // namespace sadame
