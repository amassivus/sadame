#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "shell.hpp"
#include "value.hpp"

namespace sadame {

// Facts about the operating system, read from /etc/os-release.
//
//   Platform platform = Platform::from_os_release(text);
//   platform.family();           // "arch"
//   platform.package_manager();  // "pacman"
class Platform {
 public:
  using Text = std::optional<std::string>;

  static Platform detect(Shell &shell);
  static Platform from_os_release(const std::string &text, const std::string &kernel = "Linux");
  static std::map<std::string, std::string> parse_os_release(const std::string &text);

  Platform(Text id, Text id_like, Text name, Text version, Text codename, std::string kernel);

  const Text &id() const { return id_; }
  const Text &name() const { return name_; }
  const Text &version() const { return version_; }
  const Text &codename() const { return codename_; }
  const Text &family() const { return family_; }
  const std::string &kernel() const { return kernel_; }

  Text package_manager() const;
  bool linux_kernel() const { return kernel_ == "Linux"; }
  bool darwin() const { return kernel_ == "Darwin"; }

  // Human-readable label used in output headers.
  std::string description() const;

  // { name:, family:, package_manager: }
  Value to_h() const;

 private:
  Text id_, name_, version_, codename_, family_;
  std::string kernel_;
};

}  // namespace sadame
