#pragma once

#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "diff.hpp"
#include "host.hpp"
#include "notification.hpp"
#include "value.hpp"

namespace sadame {

// Base class of every resource.
//
// A resource describes one piece of desired state (a package, a file, a
// service...). Subclasses implement:
//
//   desired        the attributes this resource manages
//   current        the same attributes, read from the host
//   apply(changes) make the host match desired; changes is the list diff
//                  returned
//
// diff compares desired and current. Nothing is applied when it is empty,
// which is what makes every resource idempotent.
class Resource {
 public:
  Resource(std::string name, Value options, Host &host, std::string source_dir, Value vars);
  virtual ~Resource() = default;

  // Checks the declaration: option names, tags, notifications and what the
  // subclass validates. Called once, right after construction (a base class
  // constructor cannot call the subclass's virtual functions).
  void initialize();

  // tags: as given (a Symbol, a String or an Array of them) as Strings.
  static std::vector<std::string> tag_list(const Value &value, const std::string &owner);

  const std::string &name() const { return name_; }
  const Value &options() const { return options_; }
  Host &host() { return host_; }
  const std::string &source_dir() const { return source_dir_; }
  const Value &vars() const { return vars_; }
  const std::vector<Notification> &notifications() const { return notifications_; }
  const std::vector<std::string> &tags() const { return tags_; }

  virtual std::string type_name() const = 0;
  // Options this resource accepts in addition to the common ones.
  virtual std::vector<std::string> allowed_options() const { return {}; }
  // Actions other resources can trigger through notifies.
  virtual std::vector<std::string> actions() const { return {}; }

  std::string id() const { return type_name() + "[" + name_ + "]"; }

  virtual Value desired() = 0;
  virtual Value current() = 0;
  virtual std::vector<Diff::Change> diff();
  virtual void apply(const std::vector<Diff::Change> &changes) = 0;

  // Runs an action requested by a notification.
  virtual void run_action(const std::string &action);

  // What a plan would do: create, remove, update or unchanged.
  virtual std::string plan_action(const std::vector<Diff::Change> &changes) const;

  // True when output must not show content diffs for this resource (see
  // the file resource's #:sensitive option).
  virtual bool sensitive() const { return false; }

  // Checks what can be checked without the machine, for `sadame validate`;
  // options were already checked when it was declared.
  virtual void check_offline() {}

  // The file that content diffs of this resource are labelled with.
  virtual std::string content_path() const { return name_; }

 protected:
  Shell &shell() { return host_.shell(); }

  // Hook for subclasses to check option values when the resource is
  // declared, so mistakes surface before anything runs.
  virtual void validate() {}

  bool has(const std::string &key) const { return options_.has(key); }
  // True when the option is given and is not #f, like Ruby's truthiness.
  bool given(const std::string &key) const { return !opt(key).is_nil() && !opt(key).is_false(); }
  const Value &opt(const std::string &key) const { return options_.get(key); }
  // The option as text, or nothing when it is not given.
  std::optional<std::string> text_opt(const std::string &key) const;
  // The option as a String when it is one.
  bool string_opt(const std::string &key) const { return opt(key).is_string(); }

  void validate_choice(const std::string &key, const std::vector<std::string> &choices) const;
  void validate_boolean(const std::string &key) const;
  void validate_mode() const;
  void validate_verify() const;

  // Writes content to path through a temporary file next to it: the
  // temporary file gets its mode and ownership first, the verify command
  // (with %{path}) checks it, and a rename puts it in place, so readers
  // never see a half-written file and a failed check changes nothing.
  void replace_file(const std::string &path, const std::string &content, const std::optional<std::string> &mode,
                    const std::optional<std::string> &owner, const std::optional<std::string> &group,
                    const std::optional<std::string> &verify);

  static bool changed(const std::vector<Diff::Change> &changes, const std::string &attribute);
  static std::string quote(const std::string &value) { return Shell::escape(value); }
  // "owner:group", "owner" or ":group" for chown.
  static std::string ownership(const std::optional<std::string> &owner, const std::optional<std::string> &group);

  bool absent() const { return text_opt("state") == std::optional<std::string>("absent"); }

 private:
  void validate_option_names() const;
  void verify_file(const std::string &path, const std::string &temporary, const std::string &verify);

  std::string name_;
  Value options_;
  Host &host_;
  std::string source_dir_;
  Value vars_;
  std::vector<Notification> notifications_;
  std::vector<std::string> tags_;
};

// The resource types a recipe can declare, such as "package".
std::unique_ptr<Resource> make_resource(const std::string &type, const std::string &name, const Value &options,
                                        Host &host, const std::string &source_dir, const Value &vars);

// The names make_resource accepts, in the order the DSL lists them.
const std::vector<std::string> &resource_types();

}  // namespace sadame
