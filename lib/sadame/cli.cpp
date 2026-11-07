#include "cli.hpp"

#include <sys/stat.h>

#include <algorithm>
#include <memory>

#include "errors.hpp"
#include "facts_listing.hpp"
#include "hosts_listing.hpp"
#include "inventory.hpp"
#include "output.hpp"
#include "recipe.hpp"
#include "runner.hpp"
#include "scaffold.hpp"
#include "selection.hpp"
#include "stand_in.hpp"
#include "validation.hpp"
#include "vars.hpp"
#include "version.hpp"

namespace sadame {

namespace {

const std::vector<std::string> kCommands = {"init", "plan", "apply", "drift", "validate", "hosts", "facts", "report", "lsp"};
const std::vector<std::string> kRecipeCommands = {"plan", "apply", "drift"};

bool contains(const std::vector<std::string> &list, const std::string &item) {
  return std::find(list.begin(), list.end(), item) != list.end();
}

std::string join(const std::vector<std::string> &items, const std::string &separator) {
  std::string result;
  for (std::size_t index = 0; index < items.size(); ++index) {
    if (index > 0) result += separator;
    result += items[index];
  }
  return result;
}

bool is_directory(const std::string &path) {
  struct stat info;
  return ::stat(path.c_str(), &info) == 0 && S_ISDIR(info.st_mode);
}

bool is_file(const std::string &path) {
  struct stat info;
  return ::stat(path.c_str(), &info) == 0 && S_ISREG(info.st_mode);
}

std::string in_directory(const std::string &directory, const std::string &name) {
  return directory == "." ? name : directory + "/" + name;
}

bool digits(const std::string &text) {
  return !text.empty() && text.find_first_not_of("0123456789") == std::string::npos;
}

// "--limit=web*" is the same as "--limit web*".
std::pair<std::string, std::optional<std::string>> split_option(const std::string &argument) {
  if (argument.rfind("--", 0) != 0) return {argument, std::nullopt};
  std::size_t equals = argument.find('=');
  if (equals == std::string::npos) return {argument, std::nullopt};
  return {argument.substr(0, equals), argument.substr(equals + 1)};
}

std::string value(const std::string &name, const std::optional<std::string> &text) {
  if (!text || text->empty()) throw UsageError(name + " needs a value");
  return *text;
}

int positive_integer(const std::string &name, const std::optional<std::string> &given) {
  std::string text = value(name, given);
  if (digits(text) && text.size() < 9 && std::stoi(text) > 0) return std::stoi(text);
  throw UsageError(name + " needs a whole number of hosts, at least 1 (got " + text + ")");
}

// A number of hosts, or a percentage of them: "2" or "25%".
std::string batch_size(const std::string &name, const std::optional<std::string> &given) {
  std::string text = value(name, given);
  if (text.back() != '%') return std::to_string(positive_integer(name, text));

  std::string percent = text.substr(0, text.size() - 1);
  if (digits(percent) && percent.size() < 4 && std::stoi(percent) >= 1 && std::stoi(percent) <= 100) return text;
  throw UsageError(name + " needs a number of hosts or a percentage from 1% to 100% (got " + text + ")");
}

std::vector<std::string> list_value(const std::string &name, const std::optional<std::string> &given) {
  std::string text = value(name, given);
  std::vector<std::string> items;
  std::size_t start = 0;
  while (start <= text.size()) {
    std::size_t comma = text.find(',', start);
    std::string item = strip(text.substr(start, comma == std::string::npos ? std::string::npos : comma - start));
    if (!item.empty()) items.push_back(item);
    if (comma == std::string::npos) break;
    start = comma + 1;
  }
  return items;
}

}  // namespace

const char *CLI::usage() {
  return R"TEXT(Usage: sadame COMMAND [RECIPE] [options]
       sadame init [DIRECTORY] [--ci github|gitlab]
       sadame report FILE [--format markdown|junit]
       sadame lsp

Commands:
  init     Start a project: recipe.scm, vars.scm, hosts.scm, a template, and
           with --ci a daily drift check for GitHub Actions or GitLab CI.
  plan     Show what apply would change, as a diff. Changes nothing.
  apply    Make the hosts match the recipe.
  drift    Like plan, but exit 1 when a host differs from the recipe.
  validate Check the recipe for every selected host without connecting.
  hosts    Show the selected hosts with their connection options and vars.
  facts    Show the facts recipes see on each host: CPUs, memory, addresses.
  report   Turn the --json output of plan, apply or drift into Markdown
           (for a CI summary page) or JUnit XML (for test reports).
  lsp      Run a language server for editors, on stdin and stdout.

RECIPE is a recipe file or a directory containing recipe.scm
(default: ./recipe.scm). vars.scm and hosts.scm next to it are loaded if
present; hosts and facts only use those. Without -h, -g or --limit,
sadame runs on this machine.

Targets:
  -h, --host [USER@]HOST[:PORT],...   Run on these hosts over SSH
  -g, --group GROUP,...               Run on the hosts of these groups
  --limit GLOB                        Only hosts whose name matches, e.g. "web*"
  --inventory PATH                    Use this inventory instead of ./hosts.scm
  --sudo                              Run sadame with sudo on every target
  --forks N                           Work on at most N hosts at once (default: all)
  --serial N|N%                       Run in batches of N hosts (or N% of them), one
                                      batch after another; stop when a batch fails

Options:
  --platform NAME     validate as on debian, ubuntu, rocky, alpine or arch
                      (default: debian)
  --tags T,...        Only resources with one of these tags (plan, apply, drift)
  --skip-tags T,...   Leave out resources with one of these tags
  --var KEY=VALUE     Set (vars 'KEY); repeatable, overrides everything else
  --vars-file PATH    Load more vars from a Scheme file (local runs)
  --json              Print a JSON report instead of text
  --format FORMAT     report: markdown (default) or junit
  --ci SYSTEM         init: also write a drift check for github or gitlab
  --color             Always use colors
  --no-color          Never use colors (also: NO_COLOR environment variable)
  --host-name NAME    (host-name) in recipes and reports for local runs (default: local)
  --host-groups G,... (host-groups) in recipes for local runs
  --version           Print the version
  --help              Print this help

Exit status:
  0  success; for drift, every host matches the recipe
  1  apply failed, or drift found differences
  2  usage or recipe error, the state of a resource could not be read,
     or a host could not be reached
)TEXT";
}

CLI::CLI(std::vector<std::string> argv, std::ostream &out, std::ostream &err, Shell &shell, Environment environment)
    : argv_(std::move(argv)), out_(out), err_(err), shell_(shell), environment_(std::move(environment)) {}

CLI::CLI(std::vector<std::string> argv, std::ostream &out, std::ostream &err, Shell &shell)
    : CLI(std::move(argv), out, err, shell, Environment()) {}

int CLI::run() {
  try {
    Options options = parse(argv_);
    if (options.help) {
      out_ << usage();
      return 0;
    }
    if (options.version) {
      out_ << "sadame " << VERSION << "\n";
      return 0;
    }
    return execute(options);
  } catch (const UsageError &error) {
    err_ << "sadame: " << error.what() << "\nRun 'sadame --help' for usage.\n";
    return 2;
  } catch (const Error &error) {
    err_ << "sadame: " << error.what() << "\n";
    return 2;
  } catch (const std::exception &error) {
    err_ << "sadame: " << error_class_name(error) << ": " << error.what() << "\n";
    return 2;
  }
}

int CLI::not_ported(const std::string &what) {
  err_ << "sadame: " << what << " is not available in the Guile Scheme and C++ rewrite yet\n";
  return 2;
}

int CLI::execute(const Options &options) {
  if (!contains(kRecipeCommands, options.command)) {
    if (!options.tags.empty()) throw UsageError("--tags only applies to plan, apply and drift");
    if (!options.skip_tags.empty()) throw UsageError("--skip-tags only applies to plan, apply and drift");
  }
  if (options.platform && options.command != "validate") throw UsageError("--platform only applies to validate");
  if (options.format && options.command != "report") throw UsageError("--format only applies to report");
  if (options.ci && options.command != "init") throw UsageError("--ci only applies to init");
  if (options.command == "report") return not_ported("report");
  if (options.command == "init") return init_project(options);
  if (options.command == "lsp") return not_ported("lsp");
  if (options.command == "hosts") return list_hosts(options);
  if (options.command == "facts") return show_facts(options);
  if (options.command == "validate") return validate(options);

  std::string recipe_path = resolve_recipe(options.recipe);
  Value base_vars = Vars::load_file(in_directory(dirname(recipe_path), "vars.scm"));
  if (is_remote(options)) return not_ported("running on remote hosts with -h, -g and --limit (push mode)");

  return run_local(options, recipe_path, base_vars);
}

void CLI::check_local_options(const Options &options) const {
  if (options.sudo) throw UsageError("--sudo only applies to -h, -g and --limit; run `sudo sadame` here instead");
  if (options.forks) throw UsageError("--forks only applies to -h, -g and --limit");
  if (options.serial) throw UsageError("--serial only applies to -h, -g and --limit");
}

void CLI::check_remote_options(const Options &options) const {
  if (options.vars_file) throw UsageError("--vars-file is for local runs; put the vars in hosts.scm or vars.scm");
  if (options.host_name || !options.host_groups.empty()) {
    throw UsageError("--host-name and --host-groups are for local runs; targets get them from hosts.scm");
  }
}

bool CLI::is_remote(const Options &options) const {
  return !options.hosts.empty() || !options.groups.empty() || options.limit.has_value();
}

bool CLI::use_color(const Options &options) const {
  if (options.color) return *options.color;
  auto no_color = environment_.variables.find("NO_COLOR");
  if (no_color != environment_.variables.end() && !no_color->second.empty()) return false;
  return environment_.stdout_tty;
}

int CLI::run_local(const Options &options, const std::string &recipe_path, const Value &base_vars) {
  check_local_options(options);
  Value file_vars = options.vars_file ? load_vars_file(*options.vars_file) : Value::map();
  Value vars = Vars::merge({base_vars, file_vars, options.vars});
  Host host(shell_, options.host_name.value_or("local"), options.host_groups);
  ResourceCollection resources = Recipe::load(recipe_path, host, vars);

  std::unique_ptr<Output::Base> output;
  if (options.json) {
    output = std::make_unique<Output::Json>(out_);
  } else {
    output = std::make_unique<Output::Human>(out_, use_color(options));
  }

  Runner runner(host, *output, nullptr, Selection(options.tags, options.skip_tags));
  Report report = options.command == "plan"    ? runner.plan(resources)
                  : options.command == "drift" ? runner.drift(resources)
                                               : runner.apply(resources);
  return report.exit_status();
}

// RECIPE is the directory here, "." by default.
int CLI::init_project(const Options &options) {
  std::string directory = options.recipe.value_or(".");
  std::string ci = options.ci.value_or("");
  if (!ci.empty() && !contains(Scaffold::ci_systems(), ci)) {
    throw UsageError("--ci must be one of " + join(Scaffold::ci_systems(), ", ") + ", got " + ci);
  }
  if (!ci.empty() && !directory.empty() && directory[0] == '/') {
    throw UsageError("with --ci, give the directory relative to the repository's root, where the CI file goes");
  }

  for (const std::string &path : Scaffold(shell_, directory, ci).write()) out_ << "created " << path << "\n";
  std::string target = directory == "." ? "" : " " + directory;
  std::string hosts = in_directory(directory, "hosts.scm");
  out_ << "\nNext:\n"
       << "  sadame validate" << target << "        check the recipe without connecting to anything\n"
       << "  sudo sadame plan" << target << "       see what it would change on this machine\n"
       << "  sadame plan" << target << " -g all     on your servers, once " << hosts << " lists them\n";
  return 0;
}

Inventory CLI::load_inventory(const Options &options, const std::string &base_dir) const {
  std::string path = options.inventory.value_or(in_directory(base_dir, kDefaultInventory));
  if (is_file(path)) return Inventory::load(path, shell_);
  if (options.inventory) throw UsageError("inventory not found: " + path);
  return Inventory::empty();
}

std::vector<Target> CLI::select_targets(const Inventory &inventory, const Options &options,
                                        const Value &base_vars) const {
  Inventory::Selection selection;
  selection.host_specs = options.hosts;
  selection.group_names = options.groups;
  selection.limit = options.limit;
  selection.base_vars = base_vars;
  selection.cli_vars = options.vars;
  selection.sudo = options.sudo;
  return inventory.select(selection);
}

// The recipe for each selected host, or for this machine, against a stand-in
// machine: nothing is connected to.
int CLI::validate(const Options &options) {
  std::string recipe_path = resolve_recipe(options.recipe);
  std::string base_dir = dirname(recipe_path);
  Value base_vars = Vars::load_file(in_directory(base_dir, "vars.scm"));
  Platform platform = StandIn::platform(options.platform.value_or("debian"));

  struct Check {
    std::string name;
    std::vector<std::string> groups;
    Value vars;
  };
  std::vector<Check> checks;
  if (is_remote(options)) {
    check_remote_options(options);
    for (const Target &target : select_targets(load_inventory(options, base_dir), options, base_vars)) {
      checks.push_back({target.name, target.groups, target.vars});
    }
  } else {
    check_local_options(options);
    Value file_vars = options.vars_file ? load_vars_file(*options.vars_file) : Value::map();
    checks.push_back({options.host_name.value_or("local"), options.host_groups,
                      Vars::merge({base_vars, file_vars, options.vars})});
  }

  Validation validation(recipe_path, platform);
  std::vector<Validation::Result> results;
  for (const Check &check : checks) results.push_back(validation.check(check.name, check.groups, check.vars));

  ValidationListing listing(out_, use_color(options));
  if (options.json) {
    listing.render_json(recipe_path, platform, results);
  } else {
    listing.render(recipe_path, platform, results);
  }
  return Validation::exit_status(results);
}

// Facts of this machine. On selected hosts they are read over SSH.
int CLI::show_facts(const Options &options) {
  std::string base_dir = recipe_directory(options.recipe);
  if (is_remote(options)) return not_ported("reading facts from remote hosts with -h, -g and --limit (push mode)");

  check_local_options(options);
  Host host(shell_, options.host_name.value_or("local"), options.host_groups);
  FactsListing listing(out_, use_color(options));
  if (options.json) {
    listing.render_json(host);
  } else {
    listing.render(host);
  }
  return 0;
}

int CLI::list_hosts(const Options &options) {
  std::string base_dir = recipe_directory(options.recipe);
  Value base_vars = Vars::load_file(in_directory(base_dir, "vars.scm"));
  Inventory inventory = load_inventory(options, base_dir);
  if (inventory.is_empty() && options.hosts.empty()) {
    std::string path = options.inventory.value_or(in_directory(base_dir, kDefaultInventory));
    if (is_file(path)) throw UsageError("no hosts in " + path + " yet; declare some there, or use -h");
    throw UsageError("no hosts: " + path + " not found; use --inventory or -h");
  }

  std::vector<Target> targets = select_targets(inventory, options, base_vars);
  HostsListing listing(out_, use_color(options));
  if (options.json) {
    listing.render_json(targets);
  } else {
    listing.render(targets, inventory.path());
  }
  return 0;
}

Value CLI::load_vars_file(const std::string &path) const {
  if (!is_file(path)) throw UsageError("vars file not found: " + path);
  return Vars::load_file(path);
}

CLI::Options CLI::parse(const std::vector<std::string> &argv) const {
  Options options;
  std::vector<std::string> positional;
  std::vector<std::string> arguments = argv;
  std::size_t next = 0;
  auto take = [&]() -> std::optional<std::string> {
    if (next >= arguments.size()) return std::nullopt;
    return arguments[next++];
  };

  while (next < arguments.size()) {
    std::string argument = arguments[next++];
    auto [name, inline_value] = split_option(argument);
    auto given = [&]() { return inline_value ? inline_value : take(); };
    auto append = [](std::vector<std::string> &target, const std::vector<std::string> &items) {
      target.insert(target.end(), items.begin(), items.end());
    };

    if (name == "--help") options.help = true;
    else if (name == "--version") options.version = true;
    else if (name == "--json") options.json = true;
    else if (name == "--sudo") options.sudo = true;
    else if (name == "--color") options.color = true;
    else if (name == "--no-color") options.color = false;
    else if (name == "--var") {
      auto assignment = given();
      if (!assignment) throw UsageError("--var expects key=value");
      auto [key, parsed] = Vars::parse_assignment(*assignment);
      options.vars.set(key, parsed);
    }
    else if (name == "-h" || name == "--host") append(options.hosts, list_value(name, given()));
    else if (name == "-g" || name == "--group") append(options.groups, list_value(name, given()));
    else if (name == "--limit") options.limit = value(name, given());
    else if (name == "--inventory") options.inventory = value(name, given());
    else if (name == "--platform") options.platform = value(name, given());
    else if (name == "--format") options.format = value(name, given());
    else if (name == "--ci") options.ci = value(name, given());
    else if (name == "--tags") append(options.tags, list_value(name, given()));
    else if (name == "--skip-tags") append(options.skip_tags, list_value(name, given()));
    else if (name == "--forks") options.forks = positive_integer(name, given());
    else if (name == "--serial") options.serial = batch_size(name, given());
    else if (name == "--vars-file") options.vars_file = value(name, given());
    else if (name == "--host-name") options.host_name = value(name, given());
    else if (name == "--host-groups") append(options.host_groups, list_value(name, given()));
    else {
      if (argument.rfind("-", 0) == 0) throw UsageError("unknown option " + argument);
      positional.push_back(argument);
    }
  }
  if (options.help || options.version) return options;

  return assign_positional(options, positional);
}

CLI::Options CLI::assign_positional(Options options, std::vector<std::string> positional) const {
  if (positional.empty()) throw UsageError("missing command");
  std::string command = positional.front();
  positional.erase(positional.begin());
  if (!contains(kCommands, command)) throw UsageError("unknown command " + command);
  if (positional.size() > 1) throw UsageError("too many arguments: " + join(positional, " "));

  options.command = command;
  if (!positional.empty()) options.recipe = positional.front();
  return options;
}

std::string CLI::resolve_recipe(const std::optional<std::string> &argument) const {
  std::string path = argument.value_or(kDefaultRecipe);
  if (is_directory(path)) path += std::string("/") + kDefaultRecipe;
  if (!is_file(path)) throw UsageError("recipe not found: " + path);
  return path;
}

// For `hosts`, RECIPE only says where hosts.scm and vars.scm are.
std::string CLI::recipe_directory(const std::optional<std::string> &argument) const {
  if (!argument) return ".";
  if (is_directory(*argument)) return *argument;
  return dirname(*argument);
}

}  // namespace sadame
