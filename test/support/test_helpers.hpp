#pragma once

// Helpers shared by the unit tests: fixtures, fake machines and builders.

#include <fstream>
#include <initializer_list>
#include <memory>
#include <sstream>
#include <utility>

#include "../../lib/sadame/cli.hpp"
#include "../../lib/sadame/host.hpp"
#include "../../lib/sadame/resource.hpp"
#include "fake_shell.hpp"
#include "test_framework.hpp"

namespace test {

using sadame::Value;

inline const char *kFixtures = "test/fixtures";

inline std::string fixture(const std::string &path) {
  std::ifstream input(std::string(kFixtures) + "/" + path, std::ios::binary);
  if (!input) throw Failure("missing fixture " + path);
  std::ostringstream content;
  content << input.rdbuf();
  return content.str();
}

inline std::string os_release(const std::string &name) { return fixture("os-release/" + name); }

// A map from entries: map({{"mode", "0644"}, {"owner", "root"}}).
inline Value map(std::initializer_list<std::pair<std::string, Value>> entries = {}) {
  Value result = Value::map();
  for (const auto &[key, value] : entries) result.set(key, value);
  return result;
}

inline Value list(std::initializer_list<Value> items) { return Value::array(std::vector<Value>(items)); }
inline Value sym(const std::string &name) { return Value::symbol(name); }

// A machine: a fake shell and the host that uses it.
struct Machine {
  explicit Machine(std::unique_ptr<FakeShell> given) : owned(std::move(given)), shell(*owned), host(*owned) {}

  std::unique_ptr<FakeShell> owned;
  FakeShell &shell;
  sadame::Host host;
};

// A fake Linux shell whose /etc/os-release is the named fixture.
inline std::unique_ptr<Machine> linux_machine(const std::string &distribution = "debian", int default_exit_status = 0) {
  auto shell = std::make_unique<FakeShell>(std::map<std::string, std::string>{{"/etc/os-release", os_release(distribution)}},
                                           default_exit_status);
  shell->on("uname -s", "Linux\n");
  return std::make_unique<Machine>(std::move(shell));
}

// A fake Linux machine on which nothing from the recipe exists yet, apart
// from the existing files (empty), such as files a package would ship. It has
// 2 CPUs and 2 GB of memory, for recipes that read facts.
inline std::unique_ptr<Machine> fresh_machine(const std::string &distribution = "debian",
                                              const std::vector<std::string> &existing = {}) {
  std::map<std::string, std::string> files = {
      {"/etc/os-release", os_release(distribution)},
      {"/proc/meminfo", "MemTotal:        2030000 kB\nSwapTotal:             0 kB\n"}};
  for (const std::string &path : existing) files[path] = "";
  auto shell = std::make_unique<FreshHostShell>(files);
  shell->on("uname -s", "Linux\n").on("uname -n", "fresh\n").on("nproc", "2\n");
  return std::make_unique<Machine>(std::move(shell));
}

template <typename R>
std::unique_ptr<R> build_resource(sadame::Host &host, const std::string &name, const Value &options = Value::map(),
                                  const Value &vars = Value::map(), const std::string &source_dir = ".") {
  auto resource = std::make_unique<R>(name, options, host, source_dir, vars);
  resource->initialize();
  return resource;
}

// Makes `stat` report path as existing with the given attributes.
inline void stub_stat(FakeShell &shell, const std::string &path, const std::string &mode = "644",
                      const std::string &owner = "root", const std::string &group = "root",
                      const std::string &type = "regular file") {
  shell.on("stat -c '%a %U %G %F' " + sadame::Shell::escape(path), mode + " " + owner + " " + group + " " + type + "\n");
}

// Makes `stat` report path as missing.
inline void stub_missing(FakeShell &shell, const std::string &path) {
  shell.on("stat -c '%a %U %G %F' " + sadame::Shell::escape(path), "",
           "stat: cannot statx '" + path + "': No such file or directory\n", 1);
}

inline std::vector<std::string> change_attributes(const std::vector<sadame::Diff::Change> &changes) {
  std::vector<std::string> result;
  for (const auto &change : changes) result.push_back(change.attribute);
  return result;
}

struct CliResult {
  int status;
  std::string out;
  std::string err;
};

// Runs the CLI with a fake shell and returns its exit status and output.
inline CliResult run_cli(const std::vector<std::string> &arguments, sadame::Shell &shell,
                         std::map<std::string, std::string> environment = {}) {
  std::ostringstream out, err;
  sadame::CLI::Environment env;
  env.variables = std::move(environment);
  sadame::CLI cli(arguments, out, err, shell, env);
  int status = cli.run();
  return {status, out.str(), err.str()};
}

inline CliResult run_cli(const std::vector<std::string> &arguments) {
  auto machine = linux_machine();
  return run_cli(arguments, machine->shell);
}

}  // namespace test
