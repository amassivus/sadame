#include "facts_listing.hpp"

#include <algorithm>

#include "facts.hpp"
#include "json_writer.hpp"
#include "report.hpp"
#include "version.hpp"

namespace sadame {

namespace {

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

std::string rstrip(const std::string &text) {
  std::size_t end = text.find_last_not_of(" \t\r\n");
  return end == std::string::npos ? "" : text.substr(0, end + 1);
}

}  // namespace

void FactsListing::render(Host &host) {
  std::size_t width = 0;
  for (const std::string &name : Facts::names()) width = std::max(width, name.size());
  width += 2;

  std::string header = std::string("sadame ") + VERSION + " facts on " + host.name() + " (" +
                       host.platform().description() + ")";
  line(color_ ? "\033[1m" + header + "\033[0m" : header);
  line();

  Value facts = host.facts().to_h();
  for (std::size_t index = 0; index < facts.keys().size(); ++index) {
    std::string name = facts.keys()[index];
    name.resize(std::max(width, name.size()), ' ');
    line(rstrip(name + format_value(facts.values()[index])));
  }
}

void FactsListing::render_json(Host &host) {
  Value document = Value::map();
  document.set("format_version", Report::kFormatVersion);
  document.set("sadame_version", VERSION);
  document.set("command", "facts");
  document.set("host", host.name());
  document.set("platform", host.platform().to_h());
  document.set("facts", host.facts().to_h());
  io_ << JsonWriter::generate(document);
}

}  // namespace sadame
