#include "platform.hpp"

#include <sstream>

#include "errors.hpp"

namespace sadame {

namespace {

// Distribution IDs (ID and ID_LIKE in os-release) for each family.
const std::vector<std::pair<std::string, std::vector<std::string>>> kFamilyIds = {
    {"debian", {"debian", "ubuntu", "linuxmint", "pop", "raspbian"}},
    {"rhel", {"rhel", "centos", "fedora", "rocky", "almalinux", "ol"}},
    {"alpine", {"alpine"}},
    {"arch", {"arch", "archarm", "manjaro", "endeavouros"}},
};

const std::map<std::string, std::string> kPackageManagers = {
    {"debian", "apt"}, {"rhel", "dnf"}, {"alpine", "apk"}, {"arch", "pacman"}};

const char *kOsReleasePaths[] = {"/etc/os-release", "/usr/lib/os-release"};

std::string unquote(const std::string &value) {
  if (value.size() >= 2 && (value[0] == '"' || value[0] == '\'') && value.back() == value[0]) {
    return value.substr(1, value.size() - 2);
  }
  return value;
}

Platform::Text lookup(const std::map<std::string, std::string> &fields, const std::string &key) {
  auto found = fields.find(key);
  if (found == fields.end()) return std::nullopt;
  return found->second;
}

}  // namespace

Platform Platform::detect(Shell &shell) {
  std::string kernel = strip(shell.run("uname -s").stdout_text);
  std::optional<std::string> text;
  for (const char *path : kOsReleasePaths) {
    if (!text) text = shell.read_file(path);
  }
  return from_os_release(text.value_or(""), kernel);
}

std::map<std::string, std::string> Platform::parse_os_release(const std::string &text) {
  std::map<std::string, std::string> fields;
  std::istringstream stream(text);
  std::string raw;
  while (std::getline(stream, raw)) {
    std::string line = strip(raw);
    if (line.empty() || line[0] == '#') continue;
    std::size_t equals = line.find('=');
    if (equals == std::string::npos) continue;
    fields[line.substr(0, equals)] = unquote(line.substr(equals + 1));
  }
  return fields;
}

Platform Platform::from_os_release(const std::string &text, const std::string &kernel) {
  auto fields = parse_os_release(text);
  Text name = lookup(fields, "PRETTY_NAME");
  if (!name) name = lookup(fields, "NAME");
  Text codename = lookup(fields, "VERSION_CODENAME");
  if (!codename) codename = lookup(fields, "UBUNTU_CODENAME");
  return Platform(lookup(fields, "ID"), lookup(fields, "ID_LIKE"), name, lookup(fields, "VERSION_ID"), codename, kernel);
}

Platform::Platform(Text id, Text id_like, Text name, Text version, Text codename, std::string kernel)
    : id_(std::move(id)),
      name_(std::move(name)),
      version_(std::move(version)),
      codename_(std::move(codename)),
      kernel_(std::move(kernel)) {
  std::vector<std::string> candidates;
  if (id_) candidates.push_back(*id_);
  if (id_like) {
    std::istringstream words(*id_like);
    std::string word;
    while (words >> word) candidates.push_back(word);
  }
  for (const std::string &candidate : candidates) {
    for (const auto &[family, ids] : kFamilyIds) {
      for (const std::string &known : ids) {
        if (known == candidate && !family_) family_ = family;
      }
    }
    if (family_) break;
  }
}

Platform::Text Platform::package_manager() const {
  if (!family_) return std::nullopt;
  auto found = kPackageManagers.find(*family_);
  if (found == kPackageManagers.end()) return std::nullopt;
  return found->second;
}

std::string Platform::description() const {
  if (name_) return *name_;
  if (darwin()) return "macOS";
  return kernel_.empty() ? "unknown system" : kernel_;
}

Value Platform::to_h() const {
  Value result = Value::map();
  result.set("name", description());
  auto optional = [](const Text &text) { return text ? Value(*text) : Value(); };
  result.set("family", optional(family_));
  result.set("package_manager", optional(package_manager()));
  return result;
}

}  // namespace sadame
