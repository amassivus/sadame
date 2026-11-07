#include "recipe.hpp"

#include <sys/stat.h>

#include <algorithm>
#include <filesystem>

#include "errors.hpp"
#include "scheme.hpp"

namespace sadame {

namespace {

bool is_file(const std::string &path) {
  struct stat info;
  return ::stat(path.c_str(), &info) == 0 && S_ISREG(info.st_mode);
}

std::string expand(const std::string &path) {
  return std::filesystem::absolute(path).lexically_normal().string();
}

}  // namespace

std::string dirname(const std::string &path) {
  std::size_t slash = path.rfind('/');
  if (slash == std::string::npos) return ".";
  if (slash == 0) return "/";
  return path.substr(0, slash);
}

Recipe *&Recipe::current() {
  static Recipe *current = nullptr;
  return current;
}

ResourceCollection Recipe::load(const std::string &path, Host &host, const Value &vars, const Sources &sources,
                                std::vector<std::string> *loaded) {
  ResourceCollection collection;
  std::vector<std::string> own_list;
  if (!loaded) loaded = &own_list;
  Recipe(path, host, vars, collection, loaded, {}, sources).evaluate();
  collection.link_notifications();
  return collection;
}

Recipe::Recipe(std::string path, Host &host, const Value &vars, ResourceCollection &collection,
               std::vector<std::string> *loaded, std::vector<std::string> tags, const Sources &sources)
    : path_(std::move(path)),
      host_(host),
      vars_(vars),
      collection_(collection),
      loaded_(loaded),
      tags_(std::move(tags)),
      sources_(sources) {}

void Recipe::evaluate() {
  std::string expanded = expand(path_);
  if (loaded_) loaded_->push_back(expanded);

  std::string source;
  auto given = sources_.find(expanded);
  if (given != sources_.end()) {
    source = given->second;
  } else {
    auto content = Shell().read_file(path_);
    if (!content) throw RecipeError("cannot read " + path_);
    source = *content;
  }

  Recipe *previous = current();
  current() = this;
  try {
    scheme::evaluate_file("recipe", path_, source);
  } catch (...) {
    current() = previous;
    throw;
  }
  current() = previous;
}

std::string Recipe::recipe_dir() const { return dirname(path_); }

void Recipe::include_recipe(const std::string &name, const Value &options) {
  for (const std::string &key : options.keys()) {
    if (key != "tags") throw Error("include-recipe takes only #:tags, got #:" + key);
  }

  std::vector<std::string> tags = tags_;
  for (const std::string &tag : Resource::tag_list(options.get("tags"), "include-recipe " + name)) tags.push_back(tag);

  bool has_extension = name.size() >= 4 && name.compare(name.size() - 4, 4, ".scm") == 0;
  std::string file_name = has_extension ? name : name + ".scm";
  std::string path = recipe_dir() == "." ? file_name : recipe_dir() + "/" + file_name;
  if (!is_file(path)) throw Error("include-recipe cannot find " + path);
  if (loaded_ && std::find(loaded_->begin(), loaded_->end(), expand(path)) != loaded_->end()) return;

  Recipe(path, host_, vars_, collection_, loaded_, tags, sources_).evaluate();
}

void Recipe::declare(const std::string &type, const std::string &name, Value options) {
  if (options.is_map() && !tags_.empty()) {
    std::vector<std::string> own;
    if (options.get("tags").is_array()) {
      for (const Value &tag : options.get("tags").items()) own.push_back(tag.to_s());
    } else if (!options.get("tags").is_nil()) {
      own.push_back(options.get("tags").to_s());
    }
    Value merged = Value::array();
    for (const std::string &tag : tags_) merged.push(Value::symbol(tag));
    for (const std::string &tag : own) merged.push(Value::symbol(tag));
    options.set("tags", merged);
  }
  collection_.add(make_resource(type, name, options, host_, recipe_dir(), vars_));
}

}  // namespace sadame
