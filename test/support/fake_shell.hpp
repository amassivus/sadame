#pragma once

#include <functional>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "../../lib/sadame/diff.hpp"
#include "../../lib/sadame/shell.hpp"

namespace test {

// A shell that records commands instead of running them, with an in-memory
// file system. Responses are set per command with on(); any other command
// exits with default_exit_status and prints nothing.
class FakeShell : public sadame::Shell {
 public:
  explicit FakeShell(std::map<std::string, std::string> initial_files = {}, int default_exit_status = 0)
      : files(std::move(initial_files)), default_exit_status_(default_exit_status) {}

  FakeShell &on(const std::string &command, const std::string &stdout_text = "", const std::string &stderr_text = "",
                int exit_status = 0) {
    responses_[command] = {stdout_text, stderr_text, exit_status};
    return *this;
  }

  sadame::CommandResult run(const std::string &command) override {
    commands.push_back(command);
    auto found = responses_.find(command);
    if (found == responses_.end()) return {command, "", "", default_exit_status_};
    return {command, found->second.out, found->second.err, found->second.status};
  }

  int stream(const std::string &command, const std::function<void(const std::string &)> &on_line) override {
    sadame::CommandResult result = run(command);
    for (const std::string &line : sadame::Diff::split_lines(result.stdout_text + result.stderr_text)) on_line(line);
    return result.exit_status;
  }

  std::optional<std::string> read_file(const std::string &path) override {
    auto found = files.find(path);
    if (found == files.end()) return std::nullopt;
    return found->second;
  }

  void write_file(const std::string &path, const std::string &content) override {
    commands.push_back("write " + path);
    files[path] = content;
  }

  // The last count commands that ran.
  std::vector<std::string> last(std::size_t count) const {
    std::size_t from = commands.size() > count ? commands.size() - count : 0;
    return std::vector<std::string>(commands.begin() + static_cast<long>(from), commands.end());
  }

  std::vector<std::string> commands;
  std::map<std::string, std::string> files;

 protected:
  struct Response {
    std::string out, err;
    int status;
  };

  bool configured(const std::string &command) const { return responses_.count(command) > 0; }
  sadame::CommandResult record(const std::string &command, const std::string &out, const std::string &err, int status) {
    commands.push_back(command);
    return {command, out, err, status};
  }

  std::map<std::string, Response> responses_;
  int default_exit_status_;
};

// A fake shell for a machine where nothing has been configured yet: state
// queries report "missing" and every other command succeeds. Files given to
// it (such as /etc/os-release, or a configuration file a package would ship)
// exist as regular files.
class FreshHostShell : public FakeShell {
 public:
  explicit FreshHostShell(std::map<std::string, std::string> initial_files = {}) : FakeShell(std::move(initial_files)) {
    on("test -d /run/systemd/system");
  }

  // A remote a git resource asks about has every branch and tag asked for.
  static constexpr const char *kFakeCommit = "0123456789abcdef0123456789abcdef01234567";

  sadame::CommandResult run(const std::string &command) override {
    if (configured(command)) return FakeShell::run(command);
    if (command.find(" ls-remote ") != std::string::npos) return remote_refs(command);

    const std::string stat = "stat -c '%a %U %G %F' ";
    if (command.rfind(stat, 0) == 0 && files.count(command.substr(stat.size()))) {
      return record(command, "644 root root regular file\n", "", 0);
    }
    if (!query(command)) return FakeShell::run(command);
    return record(command, "", "No such file or directory\n", 1);
  }

 private:
  sadame::CommandResult remote_refs(const std::string &command) {
    std::string unquoted = command;
    for (char &character : unquoted) {
      if (character == '\'') character = ' ';
    }
    std::string out;
    std::size_t position = 0;
    while (position < unquoted.size()) {
      std::size_t end = unquoted.find(' ', position);
      if (end == std::string::npos) end = unquoted.size();
      std::string word = unquoted.substr(position, end - position);
      if (word == "HEAD" || word.rfind("refs/", 0) == 0) out += std::string(kFakeCommit) + "\t" + word + "\n";
      position = end + 1;
    }
    return record(command, out, "", 0);
  }

  static bool query(const std::string &command) {
    for (const char *prefix : {"stat ", "dpkg-query ", "rpm -q ", "apk info ", "pacman -Q ", "getent ", "id -nG ",
                               "systemctl is-", "test "}) {
      if (command.rfind(prefix, 0) == 0) return true;
    }
    return false;
  }
};

}  // namespace test
