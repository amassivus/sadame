#include "file.hpp"

#include <sys/stat.h>

#include <fstream>
#include <sstream>

#include "../path_stat.hpp"
#include "../template.hpp"

namespace sadame {

namespace {

const char *kContentOptions[] = {"content", "template", "source"};

bool regular_file(const std::string &path) {
  struct stat info;
  return ::stat(path.c_str(), &info) == 0 && S_ISREG(info.st_mode);
}

std::string read_local(const std::string &path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) throw Error("cannot read " + path);
  std::ostringstream content;
  content << input.rdbuf();
  return content.str();
}

}  // namespace

bool FileResource::content_managed() const {
  for (const char *key : kContentOptions) {
    if (has(key)) return true;
  }
  return false;
}

std::optional<std::string> FileResource::desired_mode() const {
  if (!has("mode")) return std::nullopt;
  return PathStat::normalize_mode(opt("mode").text());
}

Value FileResource::desired() {
  Value result = Value::map();
  if (absent()) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  if (given("mode")) result.set("mode", desired_mode().value_or(""));
  if (given("owner")) result.set("owner", opt("owner").to_s());
  if (given("group")) result.set("group", opt("group").to_s());
  if (content_managed()) result.set("content", desired_content());
  return result;
}

Value FileResource::current() {
  Value result = Value::map();
  auto stat = read_stat();
  if (!stat) {
    result.set("state", "absent");
    return result;
  }
  result.set("state", "present");
  result.set("mode", stat->mode());
  result.set("owner", stat->owner());
  result.set("group", stat->group());
  if (content_managed()) {
    auto content = shell().read_file(name());
    result.set("content", content ? Value(*content) : Value());
  }
  return result;
}

void FileResource::apply(const std::vector<Diff::Change> &changes) {
  if (absent()) {
    shell().run_checked("rm -f " + quote(name()));
  } else if (changed(changes, "state") || changed(changes, "content")) {
    replace_content();
  } else {
    if (changed(changes, "mode")) shell().run_checked("chmod " + *desired_mode() + " " + quote(name()));
    if (changed(changes, "owner") || changed(changes, "group")) {
      shell().run_checked("chown " + ownership(text_opt("owner"), text_opt("group")) + " " + quote(name()));
    }
  }
}

void FileResource::check_offline() {
  if (content_managed()) desired_content();
}

void FileResource::validate() {
  validate_choice("state", {"present", "absent"});
  validate_boolean("sensitive");
  validate_mode();
  validate_content_options();
  validate_verify();
  if (given("template")) {
    local_file_ = find_local_file(opt("template").to_s(), "templates");
  } else if (given("source")) {
    local_file_ = find_local_file(opt("source").to_s(), "files");
  }
}

void FileResource::validate_content_options() const {
  std::vector<std::string> given_options;
  for (const char *key : kContentOptions) {
    if (has(key)) given_options.push_back(key);
  }
  if (given_options.size() > 1) {
    std::string list;
    for (const std::string &key : given_options) list += (list.empty() ? "" : ", ") + key;
    throw ResourceError(id() + ": use only one of #:content, #:template and #:source (got " + list + ")");
  }
  if (has("locals") && !has("template")) throw ResourceError(id() + ": #:locals only applies to #:template");
  if (absent() && !given_options.empty()) {
    throw ResourceError(id() + ": #:" + given_options[0] + " makes no sense with #:state 'absent");
  }
}

std::string FileResource::in_source_dir(const std::string &relative) const {
  return source_dir() == "." ? relative : source_dir() + "/" + relative;
}

// Finds #:template or #:source relative to the recipe's directory, then in
// its templates/ or files/ subdirectory.
std::string FileResource::find_local_file(const std::string &relative, const std::string &subdirectory) const {
  std::vector<std::string> candidates;
  if (!relative.empty() && relative[0] == '/') {
    candidates = {relative};
  } else {
    candidates = {in_source_dir(relative), in_source_dir(subdirectory + "/" + relative)};
  }
  for (const std::string &candidate : candidates) {
    if (regular_file(candidate)) return candidate;
  }

  std::string looked;
  for (const std::string &candidate : candidates) looked += (looked.empty() ? "" : ", ") + candidate;
  throw ResourceError(id() + ": cannot find " + relative + " (looked in " + looked + ")");
}

const std::string &FileResource::desired_content() {
  if (!desired_content_) desired_content_ = render_content();
  return *desired_content_;
}

std::string FileResource::render_content() {
  if (has("content")) return opt("content").to_s();
  if (has("template")) {
    Value locals = opt("locals").is_nil() ? Value::map() : opt("locals");
    return Template(read_local(local_file_), local_file_).render(vars(), locals, &host().facts());
  }
  return read_local(local_file_);
}

std::optional<PathStat> FileResource::read_stat() {
  auto stat = PathStat::read(shell(), name(), host().platform());
  if (!stat || stat->file()) return stat;
  throw ResourceError(id() + ": " + name() + " is a " + stat->type_label() + ", not a regular file");
}

void FileResource::replace_content() {
  auto existing = read_stat();
  std::optional<std::string> mode = desired_mode();
  if (!mode && existing) mode = existing->mode();
  std::optional<std::string> owner = given("owner") ? text_opt("owner") : std::nullopt;
  if (!owner && existing) owner = existing->owner();
  std::optional<std::string> group = given("group") ? text_opt("group") : std::nullopt;
  if (!group && existing) group = existing->group();
  std::optional<std::string> verify = given("verify") ? text_opt("verify") : std::nullopt;
  replace_file(name(), content_managed() ? desired_content() : "", mode, owner, group, verify);
}

}  // namespace sadame
