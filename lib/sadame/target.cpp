#include "target.hpp"

#include <algorithm>

#include "errors.hpp"
#include "vars.hpp"

namespace sadame {

namespace {

std::string quoted(const std::string &text) { return "\"" + text + "\""; }

std::optional<int> parse_port(const std::string &text, const std::string &spec) {
  int port = 0;
  if (Vars::is_integer(text) && text.size() <= 5) port = std::stoi(text);
  if (port < 1 || port > 65535) throw UsageError("invalid port in " + quoted(spec));
  return port;
}

std::pair<std::string, std::optional<int>> split_port(const std::string &text, const std::string &spec) {
  if (!text.empty() && text[0] == '[') {
    std::size_t closing = text.find(']');
    if (closing == std::string::npos) throw UsageError("missing ] in " + quoted(spec));
    std::string rest = text.substr(closing + 1);
    std::string host = text.substr(1, closing - 1);
    if (rest.empty()) return {host, std::nullopt};
    if (rest[0] != ':') throw UsageError("unexpected " + quoted(rest) + " in " + quoted(spec));
    return {host, parse_port(rest.substr(1), spec)};
  }

  std::size_t colon = text.find(':');
  if (colon == std::string::npos) return {text, std::nullopt};
  if (std::count(text.begin(), text.end(), ':') > 1) throw UsageError("put IPv6 addresses in brackets: [" + text + "]");
  return {text.substr(0, colon), parse_port(text.substr(colon + 1), spec)};
}

}  // namespace

Target::Spec Target::parse(const std::string &spec) {
  std::string text = strip(spec);
  Spec result;
  std::size_t at = text.find('@');
  if (at != std::string::npos) {
    result.user = text.substr(0, at);
    text = text.substr(at + 1);
    if (result.user->empty()) throw UsageError("missing user name before @ in " + quoted(spec));
  }
  auto [host, port] = split_port(text, spec);
  if (host.empty()) throw UsageError("missing host name in " + quoted(spec));
  result.host = host;
  result.port = port;
  return result;
}

Value Target::to_h() const {
  Value result = Value::map();
  result.set("name", name);
  result.set("address", address);
  result.set("user", user ? Value(*user) : Value());
  result.set("port", port ? Value(*port) : Value());
  result.set("sudo", sudo);
  Value options = Value::array();
  for (const std::string &option : ssh_opts) options.push(Value(option));
  result.set("ssh_opts", options);
  Value group_names = Value::array();
  for (const std::string &group : groups) group_names.push(Value(group));
  result.set("groups", group_names);
  result.set("vars", vars);
  result.set("var_sources", var_sources);
  return result;
}

}  // namespace sadame
