#pragma once

#include <optional>
#include <string>

#include "platform.hpp"
#include "shell.hpp"

namespace sadame {

// Type, permission bits and ownership of a path, read with stat(1).
class PathStat {
 public:
  enum class Type { File, Directory, Symlink, Other };

  // Returns nothing when the path does not exist.
  static std::optional<PathStat> read(Shell &shell, const std::string &path, const Platform &platform);
  static std::string command_for(const std::string &path, const Platform &platform);

  // Parses "644 root root regular file" (GNU and BusyBox) or
  // "644 root wheel Regular File" (BSD).
  static PathStat parse(const std::string &line);

  // Accepts "644" or "0644" and returns four octal digits, or nothing when
  // the value is not a valid mode string.
  static std::optional<std::string> normalize_mode(const std::string &value);

  PathStat(Type type, std::string mode, std::string owner, std::string group)
      : type_(type), mode_(std::move(mode)), owner_(std::move(owner)), group_(std::move(group)) {}

  Type type() const { return type_; }
  const std::string &mode() const { return mode_; }
  const std::string &owner() const { return owner_; }
  const std::string &group() const { return group_; }

  bool file() const { return type_ == Type::File; }
  bool directory() const { return type_ == Type::Directory; }
  std::string type_label() const;

 private:
  Type type_;
  std::string mode_, owner_, group_;
};

}  // namespace sadame
