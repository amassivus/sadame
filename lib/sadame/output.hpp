#pragma once

#include <optional>
#include <ostream>
#include <string>

#include "host.hpp"
#include "report.hpp"

namespace sadame {

// Renders reports. Human writes progress as resources are processed; Json
// writes one document when the run is finished. Both only write to a stream.
namespace Output {

class Base {
 public:
  virtual ~Base() = default;

  // note says which resources a --tags run covers.
  virtual void start(const std::string &command, Host &host, const std::optional<std::string> &note) = 0;
  virtual void planned(const Report::Entry &entry) = 0;
  virtual void applied(const Report::Entry &entry) = 0;
  virtual void notified(const Report::NotificationRun &run) = 0;
  virtual void finish(Report &report) = 0;
};

// Terminal output with optional ANSI colors.
class Human : public Base {
 public:
  Human(std::ostream &io, bool color = false) : io_(io), color_(color) {}

  void start(const std::string &command, Host &host, const std::optional<std::string> &note) override;
  // Used by plan and drift.
  void planned(const Report::Entry &entry) override;
  void applied(const Report::Entry &entry) override;
  void notified(const Report::NotificationRun &run) override;
  void finish(Report &report) override;

 private:
  void details(const Report::Entry &entry, const std::string &indent);
  void change_lines(const Resource &resource, const Diff::Change &change, const std::string &indent);
  void content_lines(const Resource &resource, const Diff::Change &change, const std::string &indent);
  std::string paint_diff_line(const std::string &text) const;
  std::string plan_summary(const Report &report) const;
  void drift_summary(const Report &report);
  void apply_summary(const Report &report);
  void summary_row(const std::string &status, int count, const std::vector<std::string> &items);
  void indented(const std::string &text, const std::string &indent, const std::string &color);
  std::string paint(const std::string &text, const std::string &color) const;
  void line(const std::string &text = "");

  std::ostream &io_;
  bool color_;
};

// Machine-readable output for --json.
class Json : public Base {
 public:
  explicit Json(std::ostream &io) : io_(io) {}

  void start(const std::string &, Host &, const std::optional<std::string> &) override {}
  void planned(const Report::Entry &) override {}
  void applied(const Report::Entry &) override {}
  void notified(const Report::NotificationRun &) override {}
  void finish(Report &report) override;

 private:
  std::ostream &io_;
};

}  // namespace Output
}  // namespace sadame
