#include "validation.hpp"

#include <algorithm>
#include <sstream>

#include "errors.hpp"
#include "json_writer.hpp"
#include "report.hpp"
#include "stand_in.hpp"
#include "version.hpp"

namespace sadame {

Validation::Result Validation::check(const std::string &name, const std::vector<std::string> &groups, const Value &vars,
                                     const Recipe::Sources &sources) {
  Result result{name, std::nullopt, std::nullopt, {}};
  try {
    StandIn::StandInHost host(name, groups, platform_);
    ResourceCollection resources = Recipe::load(recipe_path_, host, vars, sources, &result.files);
    for (const auto &resource : resources.resources()) resource->check_offline();
    result.resources = resources.size();
  } catch (const Error &error) {
    result.error = error.what();
  } catch (const std::exception &error) {
    result.error = error_class_name(error) + ": " + error.what();
  }
  return result;
}

int Validation::exit_status(const std::vector<Result> &results) {
  return std::any_of(results.begin(), results.end(), [](const Result &result) { return result.error.has_value(); }) ? 2
                                                                                                                      : 0;
}

std::string ValidationListing::paint(const std::string &text, int code) const {
  return color_ ? "\033[" + std::to_string(code) + "m" + text + "\033[0m" : text;
}

void ValidationListing::render(const std::string &recipe_path, const Platform &platform,
                               const std::vector<Validation::Result> &results) {
  std::string header = std::string("sadame ") + VERSION + " validate " + recipe_path + ", as on " + platform.description();
  line(color_ ? "\033[1m" + header + "\033[0m" : header);
  line();

  std::size_t width = 0;
  for (const Validation::Result &result : results) width = std::max(width, result.name.size());
  width += 2;
  auto pad = [](const std::string &text, std::size_t size) {
    return text.size() >= size ? text : text + std::string(size - text.size(), ' ');
  };

  for (const Validation::Result &result : results) {
    if (result.error) {
      std::istringstream lines(*result.error);
      std::string first;
      std::getline(lines, first);
      line("  " + pad(result.name, width) + paint("error", 31) + "  " + first);
      std::string rest;
      while (std::getline(lines, rest)) line("  " + std::string(width + 7, ' ') + rest);
    } else {
      std::string noun = *result.resources == 1 ? "resource" : "resources";
      line("  " + pad(result.name, width) + paint("ok", 32) + "     " + std::to_string(*result.resources) + " " + noun);
    }
  }

  std::size_t errors = std::count_if(results.begin(), results.end(),
                                     [](const Validation::Result &result) { return result.error.has_value(); });
  std::string noun = results.size() == 1 ? "host" : "hosts";
  std::string counts = std::to_string(results.size() - errors) + " ok";
  if (errors > 0) counts += ", " + std::to_string(errors) + " error";
  line();
  line("validate on " + std::to_string(results.size()) + " " + noun + ": " + counts + ".");
}

void ValidationListing::render_json(const std::string &recipe_path, const Platform &platform,
                                    const std::vector<Validation::Result> &results) {
  Value document = Value::map();
  document.set("format_version", Report::kFormatVersion);
  document.set("sadame_version", VERSION);
  document.set("command", "validate");
  document.set("recipe", recipe_path);
  document.set("platform", platform.to_h());
  Value hosts = Value::array();
  for (const Validation::Result &result : results) {
    Value host = Value::map();
    host.set("name", result.name);
    host.set("status", result.error ? "error" : "ok");
    host.set("resources", result.resources ? Value(*result.resources) : Value());
    host.set("error", result.error ? Value(*result.error) : Value());
    hosts.push(host);
  }
  document.set("hosts", hosts);
  document.set("exit_status", Validation::exit_status(results));
  io_ << JsonWriter::generate(document);
}

}  // namespace sadame
