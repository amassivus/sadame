#pragma once

#include "../resource.hpp"

namespace sadame {

// Manages a service: whether it starts at boot and whether it is running
// now, with systemd, or with OpenRC on Alpine.
//
//   (service "nginx" #:enable #t #:state 'running)
//   (service "cups" #:enable #f #:state 'stopped)
//
// Other resources can ask it to start, stop, restart or reload through
// #:notifies.
//
// With OpenRC, #:enable #t adds the service to the default runlevel and
// #:enable #f removes it from every runlevel it is in.
//
// With #:user (systemd only), the unit belongs to that user's systemd
// instance (systemctl --user -M USER@), such as a timer in
// ~/.config/systemd/user. The user's instance must be running: the user is
// logged in, or has lingering enabled (loginctl enable-linger USER).
class ServiceResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "service"; }
  std::vector<std::string> allowed_options() const override { return {"enable", "state", "user"}; }
  std::vector<std::string> actions() const override { return {"start", "stop", "restart", "reload", "enable", "disable"}; }

  Value desired() override;
  Value current() override;
  void apply(const std::vector<Diff::Change> &changes) override;
  void run_action(const std::string &action) override;

 protected:
  void validate() override;

 private:
  void require_service_manager();
  bool openrc() { return host().init_system() == "openrc"; }
  bool enabled();
  bool active();
  void enable();
  void disable();
  void control(const std::string &verb);
  std::vector<std::string> runlevels();
  void systemctl(const std::string &verb);
  std::string systemctl_command() const;
};

}  // namespace sadame
