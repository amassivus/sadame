#include "shell.hpp"

#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include <cerrno>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>

namespace sadame {

namespace {

const char *kSafeCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_./:=@%+,";

int exit_status_from(int status) {
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
  return 1;
}

std::string read_all(FILE *pipe) {
  std::string result;
  char buffer[4096];
  std::size_t count;
  while ((count = std::fread(buffer, 1, sizeof buffer, pipe)) > 0) result.append(buffer, count);
  return result;
}

bool file_exists(const std::string &path) {
  struct stat info;
  return ::stat(path.c_str(), &info) == 0;
}

}  // namespace

std::string Shell::escape(const std::string &value) {
  if (value.empty()) return "''";
  if (value.find_first_not_of(kSafeCharacters) == std::string::npos) return value;

  std::string result = "'";
  for (char character : value) {
    if (character == '\'') {
      result += "'\\''";
    } else {
      result += character;
    }
  }
  return result + "'";
}

std::string Shell::next_stderr_path() {
  ++counter_;
  const char *directory = std::getenv("TMPDIR");
  std::string base = directory && *directory ? directory : "/tmp";
  return base + "/sadame-" + std::to_string(::getpid()) + "-" + std::to_string(counter_) + ".stderr";
}

CommandResult Shell::run(const std::string &command) {
  std::string stderr_path = next_stderr_path();
  std::string wrapped = std::string("(\n") + kLocale + "\n" + command + "\n) </dev/null 2>" + escape(stderr_path);
  std::fflush(nullptr);
  FILE *pipe = ::popen(wrapped.c_str(), "r");
  if (!pipe) throw Error("cannot run a command: " + std::string(std::strerror(errno)));

  CommandResult result;
  result.command = command;
  result.stdout_text = read_all(pipe);
  result.exit_status = exit_status_from(::pclose(pipe));
  if (file_exists(stderr_path)) {
    std::ifstream input(stderr_path, std::ios::binary);
    std::ostringstream content;
    content << input.rdbuf();
    result.stderr_text = content.str();
    std::remove(stderr_path.c_str());
  }
  return result;
}

int Shell::stream(const std::string &command, const std::function<void(const std::string &)> &on_line) {
  std::string wrapped = std::string("(\n") + kLocale + "\n" + command + "\n) </dev/null 2>&1";
  std::fflush(nullptr);
  FILE *pipe = ::popen(wrapped.c_str(), "r");
  if (!pipe) throw Error("cannot run a command: " + std::string(std::strerror(errno)));

  std::string line;
  int character;
  while ((character = std::fgetc(pipe)) != EOF) {
    line += static_cast<char>(character);
    if (character == '\n') {
      on_line(line);
      line.clear();
    }
  }
  if (!line.empty()) on_line(line);
  return exit_status_from(::pclose(pipe));
}

std::optional<std::string> Shell::read_file(const std::string &path) {
  if (!file_exists(path)) return std::nullopt;
  std::ifstream input(path, std::ios::binary);
  if (!input) return std::nullopt;
  std::ostringstream content;
  content << input.rdbuf();
  return content.str();
}

void Shell::write_file(const std::string &path, const std::string &content) {
  std::ofstream output(path, std::ios::binary | std::ios::trunc);
  if (!output) throw Error("cannot write " + path + ": " + std::strerror(errno));
  output << content;
  if (!output) throw Error("cannot write " + path + ": " + std::strerror(errno));
}

CommandResult Shell::run_checked(const std::string &command) {
  CommandResult result = run(command);
  if (!result.success()) throw CommandFailed(result);
  return result;
}

}  // namespace sadame
