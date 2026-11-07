#include "facts.hpp"

#include <algorithm>
#include <cmath>
#include <sstream>

#include "errors.hpp"

namespace sadame {

namespace {

// sys_vendor or product_name from DMI, for machines without
// systemd-detect-virt; the values are what systemd-detect-virt prints.
const std::vector<std::pair<std::string, std::string>> kDmiVirtualization = {
    {"QEMU", "qemu"},         {"KVM", "kvm"},           {"VMware", "vmware"},
    {"VirtualBox", "oracle"}, {"Xen", "xen"},           {"Bochs", "bochs"},
    {"Parallels", "parallels"}, {"Amazon EC2", "amazon"}, {"Google Compute Engine", "google"}};

std::vector<std::string> words(const std::string &text) {
  std::vector<std::string> result;
  std::istringstream stream(text);
  std::string word;
  while (stream >> word) result.push_back(word);
  return result;
}

std::vector<std::string> lines(const std::string &text) {
  std::vector<std::string> result;
  std::istringstream stream(text);
  std::string line;
  while (std::getline(stream, line)) result.push_back(line);
  return result;
}

bool starts_with(const std::string &text, const std::string &prefix) { return text.rfind(prefix, 0) == 0; }

std::optional<long long> integer(const std::optional<std::string> &text) {
  if (!text || text->empty() || text->find_first_not_of("0123456789") != std::string::npos) return std::nullopt;
  return std::stoll(*text);
}

Value optional_text(const std::optional<std::string> &text) { return text ? Value(*text) : Value(); }

Value optional_integer(const std::optional<long long> &number) { return number ? Value(*number) : Value(); }

std::vector<std::string> unique(const std::vector<std::string> &items) {
  std::vector<std::string> result;
  for (const std::string &item : items) {
    if (std::find(result.begin(), result.end(), item) == result.end()) result.push_back(item);
  }
  return result;
}

Value string_array(const std::vector<std::string> &items) {
  Value result = Value::array();
  for (const std::string &item : items) result.push(Value(item));
  return result;
}

// The words that follow each occurrence of keyword, such as the addresses
// after "inet" in ip and ifconfig output.
std::vector<std::string> words_after(const std::string &text, const std::string &keyword) {
  std::vector<std::string> all = words(text);
  std::vector<std::string> found;
  for (std::size_t index = 0; index + 1 < all.size(); ++index) {
    if (all[index] == keyword) found.push_back(all[index + 1]);
  }
  return found;
}

std::string before(const std::string &text, char separator) { return text.substr(0, text.find(separator)); }

// "20010db8000000000000000000000001" => "2001:db8::1"
std::string ipv6_from_hex(const std::string &hex) {
  std::vector<std::string> groups;
  for (std::size_t index = 0; index < 8; ++index) {
    unsigned long number = std::stoul(hex.substr(index * 4, 4), nullptr, 16);
    std::ostringstream group;
    group << std::hex << number;
    groups.push_back(group.str());
  }

  std::size_t best_start = 0, best_length = 0, index = 0;
  while (index < groups.size()) {
    if (groups[index] == "0") {
      std::size_t stop = index;
      while (stop < groups.size() && groups[stop] == "0") ++stop;
      if (stop - index > best_length) {
        best_start = index;
        best_length = stop - index;
      }
      index = stop;
    } else {
      ++index;
    }
  }

  auto join = [&](std::size_t from, std::size_t to) {
    std::string result;
    for (std::size_t position = from; position < to; ++position) {
      if (position > from) result += ":";
      result += groups[position];
    }
    return result;
  };
  if (best_length < 2) return join(0, groups.size());
  return join(0, best_start) + "::" + join(best_start + best_length, groups.size());
}

}  // namespace

const std::vector<std::string> &Facts::names() {
  static const std::vector<std::string> all = {
      "hostname",  "fqdn",         "arch",        "kernel",         "cpus",      "memory_mb",
      "swap_mb",   "root_disk_gb", "ipv4",        "default_interface", "ipv4_addresses",
      "ipv6_addresses", "virtualization", "container", "service_manager", "machine_id"};
  return all;
}

Value Facts::get(const std::string &given) {
  std::string name = Value::normalize_key(given);
  const auto &known = names();
  if (std::find(known.begin(), known.end(), name) == known.end()) {
    std::vector<std::string> sorted = known;
    std::sort(sorted.begin(), sorted.end());
    std::string list;
    for (const std::string &fact : sorted) list += (list.empty() ? "" : ", ") + fact;
    throw RecipeError("unknown fact " + given + " (facts: " + list + ")");
  }
  auto found = values_.find(name);
  if (found == values_.end()) found = values_.emplace(name, read(name)).first;
  return found->second;
}

Value Facts::to_h() {
  Value result = Value::map();
  for (const std::string &name : names()) result.set(name, get(name));
  return result;
}

Value Facts::read(const std::string &name) {
  try {
    if (name == "hostname") return read_hostname();
    if (name == "fqdn") return read_fqdn();
    if (name == "arch") return optional_text(output("uname -m"));
    if (name == "kernel") return optional_text(output("uname -r"));
    if (name == "cpus") return read_cpus();
    if (name == "memory_mb") return read_memory_mb();
    if (name == "swap_mb") return read_swap_mb();
    if (name == "root_disk_gb") return read_root_disk_gb();
    if (name == "ipv4") return read_ipv4();
    if (name == "default_interface") return read_default_interface();
    if (name == "ipv4_addresses") return read_ipv4_addresses();
    if (name == "ipv6_addresses") return read_ipv6_addresses();
    if (name == "virtualization") return read_virtualization();
    if (name == "container") return read_container();
    if (name == "service_manager") {
      std::string manager = host_.init_system();
      return manager.empty() ? Value() : Value(manager);
    }
    if (name == "machine_id") return read_machine_id();
  } catch (const std::exception &) {
  }
  return Value();
}

// The output of a command, stripped, or nothing when it fails or prints
// nothing.
std::optional<std::string> Facts::output(const std::string &command) {
  CommandResult result = shell().run(command);
  std::string text = strip(result.stdout_text);
  if (result.success() && !text.empty()) return text;
  return std::nullopt;
}

Value Facts::read_hostname() {
  auto name = output("uname -n");
  return name ? Value(*name) : Value();
}

Value Facts::read_fqdn() {
  auto name = output("hostname -f 2>/dev/null");
  if (name && name->find(' ') == std::string::npos) return Value(*name);
  return get("hostname");
}

Value Facts::read_cpus() { return optional_integer(integer(output(darwin() ? "sysctl -n hw.ncpu" : "nproc"))); }

Value Facts::meminfo_mb(const std::string &field) {
  for (const std::string &entry : lines(shell().read_file("/proc/meminfo").value_or(""))) {
    if (!starts_with(entry, field + ":")) continue;
    auto parts = words(entry);
    if (parts.size() < 2) return Value();
    auto kilobytes = integer(parts[1]);
    return kilobytes ? Value(*kilobytes / 1024) : Value();
  }
  return Value();
}

Value Facts::read_memory_mb() {
  if (darwin()) {
    auto bytes = integer(output("sysctl -n hw.memsize"));
    return bytes ? Value(*bytes / 1048576) : Value();
  }
  return meminfo_mb("MemTotal");
}

Value Facts::read_swap_mb() {
  if (darwin()) {
    auto parts = words(output("sysctl -n vm.swapusage").value_or(""));
    std::string total = parts.size() > 2 ? parts[2] : "";
    if (!total.empty() && total.back() == 'M') return Value(static_cast<long long>(std::llround(std::stod(total))));
    return Value();
  }
  return meminfo_mb("SwapTotal");
}

Value Facts::read_root_disk_gb() {
  auto all = lines(output("df -Pk /").value_or(""));
  auto fields = words(all.empty() ? "" : all.back());
  auto kilobytes = integer(fields.size() > 1 ? std::optional<std::string>(fields[1]) : std::nullopt);
  return kilobytes ? Value(static_cast<long long>(std::llround(static_cast<double>(*kilobytes) / 1048576.0))) : Value();
}

// The route to a public address, as `ip route get` reports it: which
// interface and source address the machine would use. Nothing is sent.
std::optional<Facts::Route> Facts::route_lookup() {
  auto parts = words(output("ip -4 route get 1.1.1.1").value_or(""));
  std::string interface, source;
  for (std::size_t index = 0; index + 1 < parts.size(); ++index) {
    if (parts[index] == "dev" && interface.empty()) interface = parts[index + 1];
    if (parts[index] == "src" && source.empty()) source = parts[index + 1];
  }
  if (interface.empty() || source.empty()) return std::nullopt;
  return Route{interface, source};
}

std::optional<Facts::Route> Facts::default_route() {
  if (!default_route_) default_route_ = route_lookup();
  return *default_route_;
}

Value Facts::read_ipv4() {
  if (darwin()) {
    Value interface = get("default_interface");
    if (interface.is_nil()) return Value();
    auto address = output("ipconfig getifaddr " + Shell::escape(interface.to_s()));
    return address ? Value(*address) : Value();
  }
  if (auto route = default_route()) return Value(route->source);
  Value addresses = get("ipv4_addresses");
  return addresses.items().size() == 1 ? addresses.items()[0] : Value();
}

// /proc/net/route lists the default route with destination 00000000.
std::optional<std::string> Facts::proc_default_interface() {
  auto entries = lines(shell().read_file("/proc/net/route").value_or(""));
  for (std::size_t index = 1; index < entries.size(); ++index) {
    auto fields = words(entries[index]);
    if (fields.size() > 1 && fields[1] == "00000000") return fields[0];
  }
  return std::nullopt;
}

Value Facts::read_default_interface() {
  if (darwin()) {
    for (const std::string &entry : lines(output("route -n get default").value_or(""))) {
      std::string text = strip(entry);
      if (starts_with(text, "interface:")) return Value(strip(text.substr(text.find(':') + 1)));
    }
    return Value();
  }
  if (auto route = default_route()) return Value(route->interface);
  auto interface = proc_default_interface();
  return interface ? Value(*interface) : Value();
}

// The machine's own addresses in /proc/net/fib_trie: each "/32 host LOCAL"
// line follows the address it is about.
std::vector<std::string> Facts::proc_ipv4_addresses() {
  std::vector<std::string> addresses;
  std::optional<std::string> previous;
  for (const std::string &line : lines(shell().read_file("/proc/net/fib_trie").value_or(""))) {
    if (line.find("/32 host LOCAL") != std::string::npos && previous) addresses.push_back(*previous);
    auto parts = words(line);
    if (parts.size() > 1 && parts[0] == "|--") previous = parts[1];
  }
  return addresses;
}

Value Facts::read_ipv4_addresses() {
  auto text = output(darwin() ? "ifconfig" : "ip -4 -o addr show");
  std::vector<std::string> addresses;
  if (text) {
    for (const std::string &address : words_after(*text, "inet")) addresses.push_back(before(address, '/'));
  } else {
    addresses = proc_ipv4_addresses();
  }
  std::vector<std::string> kept;
  for (const std::string &address : addresses) {
    if (!starts_with(address, "127.")) kept.push_back(address);
  }
  return string_array(unique(kept));
}

Value Facts::read_ipv6_addresses() {
  std::vector<std::string> result;
  if (darwin()) {
    for (const std::string &address : words_after(output("ifconfig").value_or(""), "inet6")) {
      std::string bare = before(address, '%');
      if (bare != "::1" && !starts_with(bare, "fe80:")) result.push_back(bare);
    }
    return string_array(unique(result));
  }

  for (const std::string &line : lines(shell().read_file("/proc/net/if_inet6").value_or(""))) {
    auto fields = words(line);
    // Scope 00 is global; 10 is the loopback address, 20 link-local.
    if (fields.size() > 3 && fields[3] == "00" && fields[0].size() == 32) result.push_back(ipv6_from_hex(fields[0]));
  }
  return string_array(unique(result));
}

std::optional<std::string> Facts::container_marker() {
  if (shell().run("test -e /.dockerenv").success()) return "docker";
  if (shell().run("test -e /run/.containerenv").success()) return "podman";
  return std::nullopt;
}

std::optional<std::string> Facts::dmi_virtualization() {
  for (const char *field : {"sys_vendor", "product_name"}) {
    std::string text = strip(shell().read_file(std::string("/sys/class/dmi/id/") + field).value_or(""));
    for (const auto &[marker, name] : kDmiVirtualization) {
      if (starts_with(text, marker)) return name;
    }
  }
  return std::nullopt;
}

Value Facts::read_virtualization() {
  if (darwin()) return Value();
  std::string text = strip(shell().run("systemd-detect-virt").stdout_text);
  if (!text.empty()) return text == "none" ? Value() : Value(text);
  if (auto marker = container_marker()) return Value(*marker);
  auto dmi = dmi_virtualization();
  return dmi ? Value(*dmi) : Value();
}

Value Facts::read_container() {
  if (darwin()) return Value(false);
  CommandResult detected = shell().run("systemd-detect-virt --container");
  if (!strip(detected.stdout_text).empty()) return Value(detected.success());
  return Value(container_marker().has_value());
}

Value Facts::read_machine_id() {
  if (darwin()) return Value();
  std::string id = strip(shell().read_file("/etc/machine-id").value_or(""));
  return id.empty() ? Value() : Value(id);
}

}  // namespace sadame
