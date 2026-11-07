#include "path_stat.hpp"

#include <algorithm>
#include <cctype>
#include <sstream>

namespace sadame {

std::string PathStat::command_for(const std::string &path, const Platform &platform) {
  if (platform.darwin()) return "stat -f '%Lp %Su %Sg %HT' " + Shell::escape(path);
  return "stat -c '%a %U %G %F' " + Shell::escape(path);
}

std::optional<PathStat> PathStat::read(Shell &shell, const std::string &path, const Platform &platform) {
  CommandResult result = shell.run(command_for(path, platform));
  if (result.success()) return parse(result.stdout_text);
  if (result.stderr_text.find("No such file") != std::string::npos) return std::nullopt;
  throw CommandFailed(result);
}

PathStat PathStat::parse(const std::string &line) {
  std::istringstream words(strip(line));
  std::string mode, owner, group, rest;
  words >> mode >> owner >> group;
  std::getline(words >> std::ws, rest);
  std::string description = rest;
  std::transform(description.begin(), description.end(), description.begin(),
                 [](unsigned char character) { return std::tolower(character); });

  Type type = Type::Other;
  if (description.rfind("regular", 0) == 0) type = Type::File;
  else if (description == "directory") type = Type::Directory;
  else if (description == "symbolic link") type = Type::Symlink;
  return PathStat(type, normalize_mode(mode).value_or(""), owner, group);
}

std::optional<std::string> PathStat::normalize_mode(const std::string &value) {
  if (value.size() < 3 || value.size() > 4) return std::nullopt;
  if (value.find_first_not_of("01234567") != std::string::npos) return std::nullopt;
  return std::string(4 - value.size(), '0') + value;
}

std::string PathStat::type_label() const {
  switch (type_) {
    case Type::File: return "regular file";
    case Type::Directory: return "directory";
    case Type::Symlink: return "symbolic link";
    default: return "special file";
  }
}

}  // namespace sadame
