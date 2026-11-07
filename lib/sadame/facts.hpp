#pragma once

#include <map>
#include <optional>
#include <string>
#include <vector>

#include "host.hpp"
#include "value.hpp"

namespace sadame {

// What a recipe can know about the machine it runs on, read from that
// machine:
//
//   (facts 'cpus)        ; 4
//   (facts 'memory-mb)   ; 7951
//   (facts 'ipv4)        ; "203.0.113.10"
//
// Each fact is read the first time it is asked for, then kept for the rest
// of the run, so a recipe that uses none costs nothing. Reading a fact never
// fails: what cannot be read is nil. Asking for a fact that does not exist
// raises an error that lists the ones that do.
//
// Linux reads /proc, uname, nproc, df and ip (or /proc/net when ip is not
// installed); macOS, for local runs, reads sysctl, ifconfig and route.
class Facts {
 public:
  // Every fact, in the order `sadame facts` prints them.
  static const std::vector<std::string> &names();

  explicit Facts(Host &host) : host_(host) {}
  virtual ~Facts() = default;

  Value get(const std::string &name);

  // Every fact, read now.
  Value to_h();

 protected:
  virtual Value read(const std::string &name);

  Shell &shell() { return host_.shell(); }

  Host &host_;

 private:
  struct Route {
    std::string interface, source;
  };

  bool darwin() { return host_.platform().darwin(); }
  std::optional<std::string> output(const std::string &command);
  std::optional<Route> default_route();
  std::optional<Route> route_lookup();

  Value read_hostname();
  Value read_fqdn();
  Value read_cpus();
  Value read_memory_mb();
  Value read_swap_mb();
  Value read_root_disk_gb();
  Value read_ipv4();
  Value read_default_interface();
  Value read_ipv4_addresses();
  Value read_ipv6_addresses();
  Value read_virtualization();
  Value read_container();
  Value read_machine_id();
  Value meminfo_mb(const std::string &field);
  std::optional<std::string> container_marker();
  std::optional<std::string> dmi_virtualization();
  std::optional<std::string> proc_default_interface();
  std::vector<std::string> proc_ipv4_addresses();

  std::map<std::string, Value> values_;
  std::optional<std::optional<Route>> default_route_;
};

}  // namespace sadame
