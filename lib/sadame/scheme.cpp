#include "scheme.hpp"

#include <libguile.h>

#include <cstdint>
#include <cstdio>

#include "embedded_scheme.hpp"
#include "errors.hpp"
#include "facts.hpp"
#include "inventory.hpp"
#include "json_writer.hpp"
#include "recipe.hpp"
#include "template.hpp"

namespace sadame {
namespace scheme {

namespace {

SCM g_sadame_error = SCM_BOOL_F;

// ---------------------------------------------------------------------------
// Scheme values <-> Value
// ---------------------------------------------------------------------------

std::string text_of(SCM string) {
  char *raw = scm_to_utf8_stringn(string, nullptr);
  std::string result(raw ? raw : "");
  std::free(raw);
  return result;
}

SCM make_string(const std::string &text) {
  return scm_from_utf8_stringn(text.data(), text.size());
}

SCM make_symbol(const std::string &text) { return scm_from_utf8_symbol(text.c_str()); }

std::string symbol_name(SCM symbol) { return text_of(scm_symbol_to_string(symbol)); }

bool is_key(SCM x) { return scm_is_symbol(x) || scm_is_keyword(x) || scm_is_string(x); }

std::string key_name(SCM x) {
  if (scm_is_keyword(x)) return Value::normalize_key(symbol_name(scm_keyword_to_symbol(x)));
  if (scm_is_symbol(x)) return Value::normalize_key(symbol_name(x));
  return Value::normalize_key(text_of(x));
}

bool proper_list(SCM x) { return scm_is_true(scm_list_p(x)); }

// An association list: a list of pairs whose cars are names.
bool looks_like_alist(SCM x) {
  if (!scm_is_pair(x) || !proper_list(x)) return false;
  for (SCM rest = x; scm_is_pair(rest); rest = scm_cdr(rest)) {
    SCM entry = scm_car(rest);
    if (!scm_is_pair(entry) || !is_key(scm_car(entry))) return false;
  }
  return true;
}

// arrays_only turns off the guess that a list of pairs is a map, for the
// options that are always lists, such as #:notifies.
Value from_scm(SCM x, bool arrays_only = false) {
  if (scm_is_bool(x)) return Value(scm_is_true(x));
  if (scm_is_eq(x, SCM_UNSPECIFIED) || SCM_UNBNDP(x) || scm_is_eq(x, SCM_ELISP_NIL)) return Value();
  if (scm_is_null(x)) return Value::array();
  if (scm_is_string(x)) return Value(text_of(x));
  if (scm_is_keyword(x)) return Value::symbol(symbol_name(scm_keyword_to_symbol(x)));
  if (scm_is_symbol(x)) return Value::symbol(symbol_name(x));
  if (scm_is_true(scm_exact_integer_p(x))) {
    if (scm_is_signed_integer(x, INT64_MIN, INT64_MAX)) return Value(static_cast<long long>(scm_to_int64(x)));
    return Value(scm_to_double(x));
  }
  if (scm_is_true(scm_real_p(x))) return Value(scm_to_double(x));

  if (scm_is_vector(x)) {
    Value result = Value::array();
    for (size_t index = 0; index < scm_c_vector_length(x); ++index) {
      result.push(from_scm(scm_c_vector_ref(x, index), arrays_only));
    }
    return result;
  }

  if (scm_is_pair(x)) {
    if (!proper_list(x)) throw Error("cannot use a dotted pair here; write a list or an association list");
    if (!arrays_only && looks_like_alist(x)) {
      Value result = Value::map();
      for (SCM rest = x; scm_is_pair(rest); rest = scm_cdr(rest)) {
        SCM entry = scm_car(rest);
        // As with assoc, the first entry for a name wins, so (cons new old) overrides.
        std::string key = key_name(scm_car(entry));
        if (!result.has(key)) result.set(key, from_scm(scm_cdr(entry), false));
      }
      return result;
    }
    Value result = Value::array();
    for (SCM rest = x; scm_is_pair(rest); rest = scm_cdr(rest)) result.push(from_scm(scm_car(rest), arrays_only));
    return result;
  }

  throw Error("cannot use this kind of Scheme value in a recipe (use strings, numbers, booleans, symbols and lists)");
}

SCM to_scm(const Value &value, bool string_keys = false) {
  switch (value.kind()) {
    case Value::Kind::Nil: return SCM_BOOL_F;
    case Value::Kind::Bool: return scm_from_bool(value.boolean());
    case Value::Kind::Int: return scm_from_int64(value.integer());
    case Value::Kind::Float: return scm_from_double(value.real());
    case Value::Kind::String: return make_string(value.text());
    case Value::Kind::Symbol: return make_symbol(value.text());
    case Value::Kind::Array: {
      SCM list = SCM_EOL;
      for (auto item = value.items().rbegin(); item != value.items().rend(); ++item) {
        list = scm_cons(to_scm(*item, string_keys), list);
      }
      return list;
    }
    case Value::Kind::Map: {
      SCM list = SCM_EOL;
      for (std::size_t index = value.keys().size(); index > 0; --index) {
        const std::string &key = value.keys()[index - 1];
        SCM name = string_keys ? make_string(key) : make_symbol(key);
        list = scm_cons(scm_cons(name, to_scm(value.values()[index - 1], string_keys)), list);
      }
      return list;
    }
  }
  return SCM_BOOL_F;
}

// Options that are always lists, whatever their elements look like.
bool is_list_option(const std::string &key) {
  return key == "notifies" || key == "subscribes" || key == "groups" || key == "ssh_opts" || key == "include" ||
         key == "options" || key == "tags";
}

// A flat keyword list, as in (#:state 'running #:enable #t), as a map.
Value options_from_plist(SCM plist) {
  Value options = Value::map();
  SCM rest = plist;
  while (scm_is_pair(rest)) {
    SCM key = scm_car(rest);
    if (!scm_is_keyword(key)) {
      throw Error("expected a keyword such as #:state, got " + from_scm(key).inspect());
    }
    std::string name = key_name(key);
    rest = scm_cdr(rest);
    if (!scm_is_pair(rest)) throw Error("keyword #:" + name + " needs a value");
    options.set(name, from_scm(scm_car(rest), is_list_option(name)));
    rest = scm_cdr(rest);
  }
  return options;
}

// Either keywords, (vars #:workers 4), or one association list,
// (vars '((workers . 4))).
Value options_from_arguments(SCM arguments) {
  if (scm_is_pair(arguments) && !scm_is_keyword(scm_car(arguments))) {
    if (scm_is_pair(scm_cdr(arguments))) throw Error("expected keyword arguments or one association list");
    Value alist = from_scm(scm_car(arguments));
    if (!alist.is_map_like()) throw Error("expected an association list, got " + alist.type_name());
    return alist.is_map() ? alist : Value::map();
  }
  return options_from_plist(arguments);
}

std::string name_text(SCM x) {
  Value value = from_scm(x);
  if (value.is_text() || value.is_int() || value.is_float()) return value.to_s();
  throw Error("expected a name such as \"nginx\", got " + value.inspect());
}

// ---------------------------------------------------------------------------
// Primitives. Each runs its body in guarded(), which turns a C++ exception
// into a Scheme error after the body's frames are gone.
// ---------------------------------------------------------------------------

SCM run_guarded(const std::function<SCM()> &body, SCM *error) {
  try {
    return body();
  } catch (const std::exception &failure) {
    std::string kind = error_class_name(failure);
    std::string message = failure.what();
    *error = scm_list_2(make_string(kind), make_string(message));
  }
  return SCM_UNSPECIFIED;
}

SCM guarded(const std::function<SCM()> &body) {
  SCM error = SCM_BOOL_F;
  SCM result = run_guarded(body, &error);
  if (!scm_is_false(error)) scm_throw(g_sadame_error, error);
  return result;
}

Recipe &current_recipe() {
  if (!Recipe::current()) throw Error("this can only be used in a recipe");
  return *Recipe::current();
}

InventoryBuilder &current_inventory() {
  if (!InventoryBuilder::current()) throw Error("this can only be used in hosts.scm");
  return *InventoryBuilder::current();
}

SCM prim_declare(SCM type, SCM name, SCM options) {
  return guarded([&]() -> SCM {
    current_recipe().declare(symbol_name(type), name_text(name), options_from_plist(options));
    return SCM_UNSPECIFIED;
  });
}

SCM prim_include_recipe(SCM name, SCM options) {
  return guarded([&]() -> SCM {
    current_recipe().include_recipe(name_text(name), options_from_plist(options));
    return SCM_UNSPECIFIED;
  });
}

SCM prim_platform(SCM key) {
  return guarded([&]() -> SCM {
    const Platform &platform = current_recipe().host().platform();
    auto text = [](const std::optional<std::string> &value) { return value ? Value(*value) : Value(); };

    Value all = Value::map();
    all.set("id", text(platform.id()));
    all.set("name", text(platform.name()));
    all.set("version", text(platform.version()));
    all.set("codename", text(platform.codename()));
    all.set("family", text(platform.family()));
    all.set("kernel", platform.kernel());
    all.set("package_manager", text(platform.package_manager()));
    all.set("description", platform.description());
    if (scm_is_eq(key, SCM_UNDEFINED) || scm_is_null(key)) return to_scm(all);

    std::string name = key_name(scm_car(key));
    if (!all.has(name)) {
      throw Error("unknown platform attribute " + name +
                  " (id, name, version, codename, family, kernel, package-manager, description)");
    }
    return to_scm(all.get(name));
  });
}

SCM prim_facts(SCM key) {
  return guarded([&]() -> SCM {
    Facts &facts = current_recipe().host().facts();
    if (scm_is_null(key)) return to_scm(facts.to_h());
    return to_scm(facts.get(key_name(scm_car(key))));
  });
}

Value lookup_in(const Value &values, SCM arguments) {
  if (scm_is_null(arguments)) return values;
  std::string key = key_name(scm_car(arguments));
  if (values.has(key)) return values.get(key);
  if (scm_is_pair(scm_cdr(arguments))) return from_scm(scm_cadr(arguments));
  return Value();
}

SCM prim_vars(SCM arguments) {
  return guarded([&]() -> SCM { return to_scm(lookup_in(current_recipe().vars(), arguments)); });
}

SCM prim_host_name() {
  return guarded([&]() -> SCM { return make_string(current_recipe().host().name()); });
}

SCM prim_host_groups() {
  return guarded([&]() -> SCM {
    SCM list = SCM_EOL;
    const auto &groups = current_recipe().host().groups();
    for (auto group = groups.rbegin(); group != groups.rend(); ++group) list = scm_cons(make_symbol(*group), list);
    return list;
  });
}

SCM prim_inventory_group_begin(SCM name, SCM includes) {
  return guarded([&]() -> SCM {
    Value options = Value::map();
    options.set("include", from_scm(includes, true));
    current_inventory().group_begin(name_text(name), options);
    return SCM_UNSPECIFIED;
  });
}

SCM prim_inventory_group_end() {
  return guarded([&]() -> SCM {
    current_inventory().group_end();
    return SCM_UNSPECIFIED;
  });
}

SCM prim_inventory_host(SCM name, SCM options) {
  return guarded([&]() -> SCM {
    current_inventory().host(name_text(name), options_from_plist(options));
    return SCM_UNSPECIFIED;
  });
}

SCM prim_inventory_vars(SCM arguments) {
  return guarded([&]() -> SCM {
    current_inventory().vars(options_from_arguments(arguments));
    return SCM_UNSPECIFIED;
  });
}

SCM prim_command_output(SCM command) {
  return guarded([&]() -> SCM { return make_string(current_inventory().command_output(name_text(command))); });
}

SCM prim_json_parse(SCM text) {
  return guarded([&]() -> SCM {
    if (!scm_is_string(text)) throw Error("json-parse expects a string");
    return to_scm(JsonParser::parse(text_of(text)), true);
  });
}

SCM prim_template_lookup(SCM which, SCM arguments) {
  return guarded([&]() -> SCM {
    TemplateContext *context = TemplateContext::current();
    if (!context) throw Error("this can only be used in a template");

    std::string name = symbol_name(which);
    if (name == "facts") {
      if (!context->facts) throw RecipeError("facts are not available here");
      if (scm_is_null(arguments)) return to_scm(context->facts->to_h());
      return to_scm(context->facts->get(key_name(scm_car(arguments))));
    }
    const Value *values = name == "vars" ? context->vars : context->locals;
    return to_scm(lookup_in(*values, arguments));
  });
}

void define_primitives(void *) {
  auto define = [](const char *name, int required, int optional, int rest, void *function) {
    scm_c_define_gsubr(name, required, optional, rest, reinterpret_cast<scm_t_subr>(function));
    scm_c_export(name, nullptr);
  };
  define("%declare", 3, 0, 0, reinterpret_cast<void *>(prim_declare));
  define("%include-recipe", 2, 0, 0, reinterpret_cast<void *>(prim_include_recipe));
  define("%platform", 0, 0, 1, reinterpret_cast<void *>(prim_platform));
  define("%facts", 0, 0, 1, reinterpret_cast<void *>(prim_facts));
  define("%vars", 0, 0, 1, reinterpret_cast<void *>(prim_vars));
  define("%host-name", 0, 0, 0, reinterpret_cast<void *>(prim_host_name));
  define("%host-groups", 0, 0, 0, reinterpret_cast<void *>(prim_host_groups));
  define("%inventory-group-begin", 2, 0, 0, reinterpret_cast<void *>(prim_inventory_group_begin));
  define("%inventory-group-end", 0, 0, 0, reinterpret_cast<void *>(prim_inventory_group_end));
  define("%inventory-host", 2, 0, 0, reinterpret_cast<void *>(prim_inventory_host));
  define("%inventory-vars", 1, 0, 0, reinterpret_cast<void *>(prim_inventory_vars));
  define("%command-output", 1, 0, 0, reinterpret_cast<void *>(prim_command_output));
  define("json-parse", 1, 0, 0, reinterpret_cast<void *>(prim_json_parse));
  define("%template-lookup", 1, 0, 1, reinterpret_cast<void *>(prim_template_lookup));
}

// ---------------------------------------------------------------------------

void initialize() {
  static bool started = false;
  if (started) return;
  started = true;

  g_sadame_error = scm_from_utf8_symbol("sadame-error");
  scm_c_define_module("sadame primitives", define_primitives, nullptr);
  for (std::size_t index = 0; index < kEmbeddedSourceCount; ++index) {
    scm_c_eval_string(kEmbeddedSources[index].text);
  }
}

SCM public_ref(const char *module, const char *name) { return scm_c_public_ref(module, name); }

void *guile_trampoline(void *data) {
  auto *call = static_cast<std::pair<const std::function<int()> *, int> *>(data);
  initialize();
  call->second = (*call->first)();
  return nullptr;
}

}  // namespace

int with_guile(const std::function<int()> &body) {
  std::pair<const std::function<int()> *, int> call{&body, 0};
  scm_with_guile(guile_trampoline, &call);
  return call.second;
}

Value evaluate_file(const std::string &kind, const std::string &path, const std::string &source) {
  SCM interface = scm_list_2(make_symbol("sadame"), make_symbol(kind));
  SCM env = scm_call_1(public_ref("sadame eval", "make-env"), interface);
  SCM result = scm_call_3(public_ref("sadame eval", "evaluate-source"), make_string(path), make_string(source), env);
  scm_force_output(scm_current_output_port());

  std::string status = symbol_name(scm_car(result));
  if (status == "ok") return from_scm(scm_cadr(result));

  std::string error_kind = text_of(scm_cadr(result));
  std::string message = text_of(scm_caddr(result));
  int line = scm_to_int(scm_cadddr(result));
  if (error_kind == "RecipeError") throw RecipeError(message);
  if (error_kind == "UsageError") throw UsageError(message);
  throw RecipeError(located_message(message, path, option_line(message, source, line)));
}

ExpressionResult evaluate_expression(const std::string &expression,
                                     const std::vector<std::pair<std::string, Value>> &bindings) {
  SCM alist = SCM_EOL;
  for (auto binding = bindings.rbegin(); binding != bindings.rend(); ++binding) {
    alist = scm_cons(scm_cons(make_symbol(binding->first), to_scm(binding->second)), alist);
  }
  SCM result = scm_call_2(public_ref("sadame template", "evaluate-template-expression"), make_string(expression), alist);

  ExpressionResult outcome;
  if (symbol_name(scm_car(result)) == "ok") {
    outcome.ok = true;
    try {
      outcome.value = from_scm(scm_cdr(result));
    } catch (const std::exception &failure) {
      outcome.ok = false;
      outcome.kind = "Error";
      outcome.message = failure.what();
    }
  } else {
    outcome.kind = text_of(scm_cadr(result));
    outcome.message = text_of(scm_caddr(result));
  }
  return outcome;
}

}  // namespace scheme
}  // namespace sadame
