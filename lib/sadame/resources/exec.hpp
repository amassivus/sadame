#pragma once

#include <optional>

#include "../resource.hpp"

namespace sadame {

// Runs a shell command. To stay idempotent it needs a guard that tells
// sadame when the work is already done:
//
//   (exec "certbot --nginx -d example.com"
//         #:not-if "test -f /etc/letsencrypt/live/example.com/fullchain.pem")
//   (exec "make install" #:cwd "/opt/app" #:creates "/usr/local/bin/app")
//   (exec "systemctl daemon-reload" #:only-if "test -f /etc/systemd/system/app.service")
//
// The command runs when every given guard agrees: #:creates names a path
// that is missing, #:not-if exits non-zero and #:only-if exits zero. Without
// any guard it runs on every apply and always shows up in plan and drift.
// Guards run during plan too, so they must not change anything.
//
// With #:action 'nothing the command never runs on its own, only when
// another resource notifies it:
//
//   (exec "systemctl daemon-reload" #:action 'nothing)
class ExecResource : public Resource {
 public:
  using Resource::Resource;

  std::string type_name() const override { return "exec"; }
  std::vector<std::string> allowed_options() const override {
    return {"command", "only_if", "not_if", "creates", "cwd", "env", "action"};
  }
  std::vector<std::string> actions() const override { return {"run"}; }

  std::string command() const;

  Value desired() override { return Value::map(); }
  Value current() override { return Value::map(); }
  std::vector<Diff::Change> diff() override;
  std::string plan_action(const std::vector<Diff::Change> &changes) const override;
  void apply(const std::vector<Diff::Change> &changes) override;
  void run_action(const std::string &action) override;

  // The command as sh sees it, with #:env exported and #:cwd entered first.
  std::string script(const std::string &text) const;

 protected:
  void validate() override;

 private:
  void validate_env() const;
  std::optional<std::string> pending_reason();
  bool guard_passes(const std::string &guard);
};

}  // namespace sadame
