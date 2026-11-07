#include "hosts_listing.hpp"

#include <algorithm>

#include "errors.hpp"
#include "json_writer.hpp"
#include "report.hpp"
#include "scheme_literal.hpp"
#include "shell.hpp"
#include "version.hpp"

namespace sadame {

namespace {

std::string ljust(const std::string &text, std::size_t width) {
  return text.size() >= width ? text : text + std::string(width - text.size(), ' ');
}

std::string rstrip(const std::string &text) {
  std::size_t end = text.find_last_not_of(" \t\r\n");
  return end == std::string::npos ? "" : text.substr(0, end + 1);
}

std::string join(const std::vector<std::string> &items, const std::string &separator) {
  std::string result;
  for (std::size_t index = 0; index < items.size(); ++index) {
    if (index > 0) result += separator;
    result += items[index];
  }
  return result;
}

}  // namespace

std::string HostsListing::bold(const std::string &text) const { return color_ ? "\033[1m" + text + "\033[0m" : text; }

void HostsListing::line(const std::string &text) { io_ << rstrip(text) << "\n"; }

void HostsListing::render(const std::vector<Target> &targets, const std::optional<std::string> &inventory_path) {
  std::string source = inventory_path ? "from " + *inventory_path : "given with -h";
  std::string noun = targets.size() == 1 ? "host" : "hosts";
  line(bold(std::string("sadame ") + VERSION + " hosts: " + std::to_string(targets.size()) + " " + noun + " " + source));
  for (const Target &target : targets) {
    line();
    print_target(target);
  }
}

void HostsListing::render_json(const std::vector<Target> &targets) {
  Value document = Value::map();
  document.set("format_version", Report::kFormatVersion);
  document.set("sadame_version", VERSION);
  document.set("command", "hosts");
  Value hosts = Value::array();
  for (const Target &target : targets) hosts.push(target.to_h());
  document.set("hosts", hosts);
  io_ << JsonWriter::generate(document);
}

void HostsListing::print_target(const Target &target) {
  line(bold(target.name));
  field("address", target.address);
  field("user", target.user ? *target.user : "(ssh default)");
  field("port", target.port ? std::to_string(*target.port) : "(ssh default)");
  field("sudo", target.sudo ? "yes" : "no");

  std::vector<std::string> options;
  for (const std::string &option : target.ssh_opts) options.push_back(Shell::escape(option));
  field("ssh_opts", options.empty() ? "(none)" : join(options, " "));
  field("groups", target.groups.empty() ? "(none)" : join(target.groups, ", "));
  if (target.vars.empty()) {
    field("vars", "(none)");
    return;
  }

  line("  vars");
  print_vars(target);
}

void HostsListing::print_vars(const Target &target) {
  const std::vector<std::string> &names = target.vars.keys();
  std::size_t name_width = 0;
  for (const std::string &name : names) name_width = std::max(name_width, name.size());
  name_width += 2;

  std::vector<std::string> values;
  std::size_t value_width = 0;
  for (const std::string &name : names) {
    values.push_back(SchemeLiteral::dump(target.vars.get(name)));
    value_width = std::max(value_width, values.back().size());
  }
  value_width += 2;

  for (std::size_t index = 0; index < names.size(); ++index) {
    line("    " + ljust(names[index], name_width) + ljust(values[index], value_width) +
         target.var_sources.get(names[index]).to_s());
  }
}

void HostsListing::field(const std::string &label, const std::string &value) {
  line("  " + ljust(label, 10) + value);
}

}  // namespace sadame
