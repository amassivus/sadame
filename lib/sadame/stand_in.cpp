#include "stand_in.hpp"

#include "errors.hpp"

namespace sadame {
namespace StandIn {

namespace {

// os-release of the systems --platform can name.
const std::vector<std::pair<std::string, std::string>> kPlatforms = {
    {"debian",
     "ID=debian\nVERSION_ID=\"12\"\nVERSION_CODENAME=bookworm\nPRETTY_NAME=\"Debian GNU/Linux 12 (bookworm)\"\n"},
    {"ubuntu", "ID=ubuntu\nID_LIKE=debian\nVERSION_ID=\"24.04\"\nVERSION_CODENAME=noble\nPRETTY_NAME=\"Ubuntu 24.04 LTS\"\n"},
    {"rocky",
     "ID=\"rocky\"\nID_LIKE=\"rhel centos fedora\"\nVERSION_ID=\"9.4\"\nPRETTY_NAME=\"Rocky Linux 9.4 (Blue Onyx)\"\n"},
    {"alpine", "ID=alpine\nVERSION_ID=3.20.3\nPRETTY_NAME=\"Alpine Linux v3.20\"\n"},
    {"arch", "ID=arch\nPRETTY_NAME=\"Arch Linux\"\n"},
};

}  // namespace

const std::vector<std::string> &platform_names() {
  static const std::vector<std::string> names = [] {
    std::vector<std::string> result;
    for (const auto &entry : kPlatforms) result.push_back(entry.first);
    return result;
  }();
  return names;
}

Platform platform(const std::string &name) {
  for (const auto &[known, text] : kPlatforms) {
    if (known == name) return Platform::from_os_release(text);
  }

  std::string list;
  for (const std::string &known : platform_names()) list += (list.empty() ? "" : ", ") + known;
  throw UsageError("unknown platform " + name + " for --platform (known: " + list + ")");
}

CommandResult RefusingShell::run(const std::string &command) {
  throw Error("validate runs no commands, and something asked for: " + command);
}

int RefusingShell::stream(const std::string &command, const std::function<void(const std::string &)> &) {
  run(command);
  return 0;
}

std::optional<std::string> RefusingShell::read_file(const std::string &path) {
  throw Error("validate reads no files on the machine, and something asked for " + path);
}

void RefusingShell::write_file(const std::string &path, const std::string &) {
  throw Error("validate writes no files, and something asked to write " + path);
}

Value MadeUpFacts::read(const std::string &name) {
  auto strings = [](std::initializer_list<const char *> items) {
    Value result = Value::array();
    for (const char *item : items) result.push(Value(item));
    return result;
  };

  if (name == "hostname") return Value(host_.name().substr(0, host_.name().find('.')));
  if (name == "fqdn") return Value(host_.name());
  if (name == "arch") return Value("x86_64");
  if (name == "kernel") return Value("6.1.0");
  if (name == "cpus") return Value(2);
  if (name == "memory_mb") return Value(2048);
  if (name == "swap_mb") return Value(0);
  if (name == "root_disk_gb") return Value(20);
  if (name == "ipv4") return Value("192.0.2.10");
  if (name == "default_interface") return Value("eth0");
  if (name == "ipv4_addresses") return strings({"192.0.2.10"});
  if (name == "ipv6_addresses") return strings({"2001:db8::10"});
  if (name == "virtualization") return Value("kvm");
  if (name == "container") return Value(false);
  if (name == "service_manager") return Value(host_.init_system());
  if (name == "machine_id") return Value("0123456789abcdef0123456789abcdef");
  return Value();
}

StandInHost::StandInHost(std::string name, std::vector<std::string> groups, Platform platform)
    : Host(detail::ShellHolder::shell, std::move(name), std::move(groups)), made_up_facts_(*this) {
  platform_ = std::move(platform);
}

Facts &StandInHost::facts() { return made_up_facts_; }

std::string StandInHost::init_system() { return platform_->family() == std::optional<std::string>("alpine") ? "openrc" : "systemd"; }

}  // namespace StandIn
}  // namespace sadame
