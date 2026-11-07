#include "resource.hpp"

#include <algorithm>

#include "errors.hpp"
#include "path_stat.hpp"
#include "resources/directory.hpp"
#include "resources/exec.hpp"
#include "resources/file.hpp"
#include "resources/git.hpp"
#include "resources/group.hpp"
#include "resources/line.hpp"
#include "resources/link.hpp"
#include "resources/package.hpp"
#include "resources/service.hpp"
#include "resources/user.hpp"

namespace sadame {

namespace {

const std::vector<std::string> kCommonOptions = {"notifies", "subscribes", "tags"};

// Option names are shown the way recipes write them: with dashes.
std::string keyword(const std::string &key) {
  std::string result = key;
  std::replace(result.begin(), result.end(), '_', '-');
  return result;
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

Resource::Resource(std::string name, Value options, Host &host, std::string source_dir, Value vars)
    : name_(std::move(name)),
      options_(options.is_map_like() && !options.is_map() ? Value::map() : std::move(options)),
      host_(host),
      source_dir_(std::move(source_dir)),
      vars_(std::move(vars)) {}

std::vector<std::string> Resource::tag_list(const Value &value, const std::string &owner) {
  std::vector<Value> list;
  if (value.is_array()) {
    list = value.items();
  } else if (!value.is_nil()) {
    list.push_back(value);
  }

  std::vector<std::string> result;
  for (const Value &tag : list) {
    std::string text = tag.to_s();
    bool valid = tag.is_text() && !text.empty() && text.find_first_of(", \t\n") == std::string::npos;
    if (!valid) {
      throw ResourceError(owner + ": tags must be symbols or strings without commas or spaces, got " + tag.inspect());
    }
    result.push_back(text);
  }
  return result;
}

void Resource::initialize() {
  if (name_.empty()) throw ResourceError(type_name() + ": name must not be empty");
  if (!options_.is_map()) throw ResourceError(id() + ": options must be keyword arguments, got " + options_.type_name());

  validate_option_names();
  for (const std::string &tag : tag_list(options_.get("tags"), id())) {
    if (std::find(tags_.begin(), tags_.end(), tag) == tags_.end()) tags_.push_back(tag);
  }
  notifications_ = Notification::from_notifies(options_.get("notifies"), id());
  for (Notification &notification : Notification::from_subscribes(options_.get("subscribes"), id())) {
    notifications_.push_back(notification);
  }
  validate();
}

std::vector<Diff::Change> Resource::diff() { return Diff::changes(desired(), current()); }

void Resource::run_action(const std::string &action) {
  throw ResourceError(id() + " does not support the " + action + " action");
}

std::string Resource::plan_action(const std::vector<Diff::Change> &changes) const {
  if (changes.empty()) return "unchanged";
  for (const Diff::Change &change : changes) {
    if (change.attribute != "state") continue;
    if (change.from.to_s() == "absent") return "create";
    if (change.to.to_s() == "absent") return "remove";
    return "update";
  }
  return "update";
}

std::optional<std::string> Resource::text_opt(const std::string &key) const {
  const Value &value = opt(key);
  if (value.is_nil()) return std::nullopt;
  return value.to_s();
}

void Resource::validate_option_names() const {
  std::vector<std::string> allowed = kCommonOptions;
  for (const std::string &name : allowed_options()) allowed.push_back(name);

  for (const std::string &key : options_.keys()) {
    if (std::find(allowed.begin(), allowed.end(), key) != allowed.end()) continue;

    std::vector<std::string> valid;
    for (const std::string &name : allowed) valid.push_back(keyword(name));
    std::sort(valid.begin(), valid.end());
    throw ResourceError(id() + ": unknown option #:" + keyword(key) + " (valid options: " + join(valid, ", ") + ")");
  }
}

void Resource::validate_choice(const std::string &key, const std::vector<std::string> &choices) const {
  const Value &value = opt(key);
  if (value.is_nil() || std::find(choices.begin(), choices.end(), value.to_s()) != choices.end()) return;
  throw ResourceError(id() + ": " + keyword(key) + " must be one of " + join(choices, ", ") + ", got " + value.inspect());
}

void Resource::validate_boolean(const std::string &key) const {
  const Value &value = opt(key);
  if (value.is_nil() || value.is_bool()) return;
  throw ResourceError(id() + ": " + keyword(key) + " must be #t or #f, got " + value.inspect());
}

void Resource::validate_mode() const {
  const Value &mode = opt("mode");
  if (mode.is_nil()) return;
  if (mode.is_string() && PathStat::normalize_mode(mode.text())) return;
  throw ResourceError(id() + ": mode must be a string of octal digits such as \"0644\", got " + mode.inspect());
}

void Resource::validate_verify() const {
  const Value &command = opt("verify");
  if (command.is_nil()) return;
  if (command.is_string() && command.text().find("%{path}") != std::string::npos) return;
  throw ResourceError(id() + ": verify must be a command containing %{path}, such as \"visudo -cf %{path}\"");
}

void Resource::replace_file(const std::string &path, const std::string &content, const std::optional<std::string> &mode,
                            const std::optional<std::string> &owner, const std::optional<std::string> &group,
                            const std::optional<std::string> &verify) {
  std::string temporary = path + ".sadame-new";
  try {
    shell().write_file(temporary, content);
    if (mode) shell().run_checked("chmod " + *mode + " " + quote(temporary));
    if (owner || group) shell().run_checked("chown " + ownership(owner, group) + " " + quote(temporary));
    if (verify) verify_file(path, temporary, *verify);
    shell().run_checked("mv -f " + quote(temporary) + " " + quote(path));
  } catch (...) {
    shell().run("rm -f " + quote(temporary));
    throw;
  }
}

void Resource::verify_file(const std::string &path, const std::string &temporary, const std::string &verify) {
  std::string command = verify;
  const std::string placeholder = "%{path}";
  for (std::size_t at = command.find(placeholder); at != std::string::npos; at = command.find(placeholder, at)) {
    command.replace(at, placeholder.size(), quote(temporary));
    at += quote(temporary).size();
  }

  CommandResult result = shell().run(command);
  if (result.success()) return;

  std::string details = strip(strip(result.stderr_text).empty() ? result.stdout_text : result.stderr_text);
  throw ResourceError(id() + ": verify failed, " + path + " was not changed: " + command + "\n" + details);
}

bool Resource::changed(const std::vector<Diff::Change> &changes, const std::string &attribute) {
  return std::any_of(changes.begin(), changes.end(),
                     [&](const Diff::Change &change) { return change.attribute == attribute; });
}

std::string Resource::ownership(const std::optional<std::string> &owner, const std::optional<std::string> &group) {
  if (owner && group) return *owner + ":" + *group;
  if (owner) return *owner;
  return ":" + group.value_or("");
}

const std::vector<std::string> &resource_types() {
  static const std::vector<std::string> types = {"package", "file", "directory", "service", "exec",
                                                 "user",    "group", "link",      "line",    "git"};
  return types;
}

std::unique_ptr<Resource> make_resource(const std::string &type, const std::string &name, const Value &options,
                                        Host &host, const std::string &source_dir, const Value &vars) {
  std::unique_ptr<Resource> resource;
  if (type == "package") resource = std::make_unique<PackageResource>(name, options, host, source_dir, vars);
  else if (type == "file") resource = std::make_unique<FileResource>(name, options, host, source_dir, vars);
  else if (type == "directory") resource = std::make_unique<DirectoryResource>(name, options, host, source_dir, vars);
  else if (type == "service") resource = std::make_unique<ServiceResource>(name, options, host, source_dir, vars);
  else if (type == "exec") resource = std::make_unique<ExecResource>(name, options, host, source_dir, vars);
  else if (type == "user") resource = std::make_unique<UserResource>(name, options, host, source_dir, vars);
  else if (type == "group") resource = std::make_unique<GroupResource>(name, options, host, source_dir, vars);
  else if (type == "link") resource = std::make_unique<LinkResource>(name, options, host, source_dir, vars);
  else if (type == "line") resource = std::make_unique<LineResource>(name, options, host, source_dir, vars);
  else if (type == "git") resource = std::make_unique<GitResource>(name, options, host, source_dir, vars);
  else throw ResourceError("unknown resource type " + type);
  resource->initialize();
  return resource;
}

}  // namespace sadame
