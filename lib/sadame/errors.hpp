#pragma once

#include <stdexcept>
#include <string>

namespace sadame {

// Outcome of one shell command.
struct CommandResult {
  std::string command;
  std::string stdout_text;
  std::string stderr_text;
  int exit_status = 0;

  bool success() const { return exit_status == 0; }
};

// Base class for errors that sadame reports to the user as a plain message.
class Error : public std::runtime_error {
 public:
  using std::runtime_error::runtime_error;
};

// The command line could not be understood.
class UsageError : public Error {
 public:
  using Error::Error;
};

// A recipe, vars file or template could not be loaded or evaluated.
class RecipeError : public Error {
 public:
  using Error::Error;
};

// A resource was declared with invalid options or cannot work on this host.
class ResourceError : public Error {
 public:
  using Error::Error;
};

// A shell command exited with a non-zero status.
class CommandFailed : public Error {
 public:
  explicit CommandFailed(const CommandResult &result) : Error(describe(result)), result_(result) {}

  const CommandResult &result() const { return result_; }

  static std::string describe(const CommandResult &result);

 private:
  CommandResult result_;
};

// The class name of an error as the user sees it in "Class: message".
std::string error_class_name(const std::exception &error);

// "path:line: message", so the message points at the line the user wrote.
std::string located_message(const std::string &message, const std::string &path, int line);

// A misspelled option is reported on the line that names it. The line a
// failed call is attributed to is where its top-level form starts, so the
// reported line is only where to start looking: the nearest line that
// names the option wins.
int option_line(const std::string &message, const std::string &source, int line);

std::string strip(const std::string &text);
std::string chomp(const std::string &text);

}  // namespace sadame
