#pragma once

#include <functional>
#include <optional>
#include <string>

#include "errors.hpp"

namespace sadame {

// The single gateway between sadame and the system it manages. Resources
// read state and make changes only through this class, which lets tests
// swap in a fake shell and lets us log every command in one place.
class Shell {
 public:
  virtual ~Shell() = default;

  // Every command runs in the C.UTF-8 locale, whatever the user's: sadame
  // reads the output of stat and package managers, and guards such as
  // `ufw status | grep -q active` match English text. ssh passes LANG
  // from the machine running sadame, and sudo keeps it, so a target can
  // otherwise answer in Turkish or German. Where C.UTF-8 does not exist,
  // programs fall back to C, which is English too.
  static constexpr const char *kLocale = "LC_ALL=C.UTF-8; export LC_ALL; unset LANGUAGE";

  // Quotes a value for /bin/sh. Plain words are left as they are so that
  // command lines stay readable in output and tests.
  static std::string escape(const std::string &value);

  // Runs a command with /bin/sh, stdin closed, and captures its output.
  virtual CommandResult run(const std::string &command);

  // Runs a command and calls on_line for each line of its output (stdout
  // and stderr together) as it arrives. Returns the exit status.
  virtual int stream(const std::string &command, const std::function<void(const std::string &)> &on_line);

  // Returns the file content, or nothing when the file does not exist.
  virtual std::optional<std::string> read_file(const std::string &path);

  virtual void write_file(const std::string &path, const std::string &content);

  // Like run, but throws CommandFailed when the command exits non-zero.
  CommandResult run_checked(const std::string &command);

 private:
  std::string next_stderr_path();

  int counter_ = 0;
};

}  // namespace sadame
