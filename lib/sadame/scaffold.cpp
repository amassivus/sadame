#include "scaffold.hpp"

#include <sys/stat.h>

#include "errors.hpp"
#include "recipe.hpp"

namespace sadame {

namespace {

const char *kRecipe = R"SCM(;; What the machines should look like. Each resource describes one thing:
;; a package, a file, a service. See what would change with `sadame plan`,
;; change it with `sadame apply`, check it later with `sadame drift`.
;;
;; Every resource: https://enderkus.github.io/sadame/resources/package/

;; A login banner from templates/motd.tmpl, with values from vars.scm and
;; the machine's facts.
(file "/etc/motd" #:template "motd.tmpl" #:mode "0644")

;; More to start from:
;;
;;   (package "nginx")
;;   (service "nginx" #:enable #t #:state 'running)
;;   (user "deploy" #:shell "/bin/bash" #:groups '("sudo"))
;;   (line "PermitRootLogin no" #:path "/etc/ssh/sshd_config"
;;         #:match "^#?\\s*PermitRootLogin\\s")
)SCM";

const char *kVars = R"SCM(;; Values for the recipe and its templates, read with (vars 'name). hosts.scm
;; can set them per group and per host, and --var name=value wins over both.
'((contact . "ops@example.com"))
)SCM";

const char *kHosts = R"SCM(;; The servers sadame manages over SSH, in groups. List them with
;; `sadame hosts`; plan for a group with `sadame plan -g web`.
;;
;; (group 'web
;;   (host "web1.example.com" #:user "deploy" #:sudo #t)
;;   (host "web2.example.com" #:user "deploy" #:sudo #t))
;;
;; (group 'db
;;   (host "db1.example.com" #:user "deploy" #:port 2222 #:sudo #t)
;;   (vars #:contact "dba@example.com"))
;;
;; (group 'all #:include '(web db))
)SCM";

const char *kMotd = R"TMPL(~{(facts 'fqdn)}: ~{(facts 'cpus)} CPUs, ~{(facts 'memory_mb)} MB of memory
Managed by sadame; changes made here by hand will be undone.
Questions: ~{(vars 'contact)}
)TMPL";

// The CI jobs, with RECIPE for the recipe's path. examples/ci has the same
// jobs (a test keeps them equal), with comments for copying them.
const char *kGithub = R"YAML(name: Drift

on:
  schedule:
    - cron: "0 6 * * *"
  workflow_dispatch:

jobs:
  drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - name: Install sadame
        run: curl -fsSL https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh

      - name: Set up SSH
        run: |
          install -d -m 0700 ~/.ssh
          printf '%s\n' "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_ed25519
          chmod 0600 ~/.ssh/id_ed25519
          printf '%s\n' "${{ secrets.SSH_KNOWN_HOSTS }}" > ~/.ssh/known_hosts

      # Exit status: 0 no drift, 1 drift on a server, 2 a server could not be
      # checked. Anything but 0 fails this step and the workflow.
      - name: Check for drift
        run: sadame drift RECIPE -g all --json > drift.json

      - name: Summarize
        if: always()
        run: sadame report drift.json >> "$GITHUB_STEP_SUMMARY"

      - name: Keep the drift report
        if: always()
        uses: actions/upload-artifact@v7
        with:
          name: drift-report
          path: drift.json
)YAML";

const char *kGitlab = R"YAML(drift:
  image: alpine:3.20
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
  before_script:
    - apk add --no-cache openssh-client
    - wget -qO- https://raw.githubusercontent.com/enderkus/sadame/main/install.sh | sh
    - install -d -m 0700 ~/.ssh
    - printf '%s\n' "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
    - chmod 0600 ~/.ssh/id_ed25519
    - printf '%s\n' "$SSH_KNOWN_HOSTS" > ~/.ssh/known_hosts
  script:
    # Exit status: 0 no drift, 1 drift on a server, 2 a server could not be checked.
    - sadame drift RECIPE -g all --json > drift.json
  after_script:
    - sadame report drift.json --format junit > drift.xml
  artifacts:
    when: always
    paths:
      - drift.json
    reports:
      junit: drift.xml
    expire_in: 30 days
)YAML";

const char *kGithubHeader = R"TEXT(# Checks the servers for drift every morning and fails the workflow when
# one differs from the recipe; the run's summary page shows what differs.
# Written by `sadame init`.
#
# It needs repository secrets SSH_PRIVATE_KEY (a key the hosts.scm users
# accept) and SSH_KNOWN_HOSTS (the output of `ssh-keyscan` for every
# server), passwordless sudo on the servers if the recipe needs root, and
# a group named all in hosts.scm.
)TEXT";

const char *kGitlabHeader = R"TEXT(# Checks the servers for drift in scheduled pipelines and fails the job
# when one differs from the recipe; the pipeline's test report shows what
# differs. Written by `sadame init`.
#
# Include it from .gitlab-ci.yml and create a pipeline schedule:
#
#   include:
#     - local: .gitlab/sadame-drift.yml
#
# It needs CI/CD variables SSH_PRIVATE_KEY and SSH_KNOWN_HOSTS (masked,
# protected), passwordless sudo on the servers if the recipe needs root,
# and a group named all in hosts.scm.
)TEXT";

std::string replace_recipe(std::string text, const std::string &recipe) {
  const std::string marker = "RECIPE";
  for (std::size_t at = text.find(marker); at != std::string::npos; at = text.find(marker, at + recipe.size())) {
    text.replace(at, marker.size(), recipe);
  }
  return text;
}

bool exists(const std::string &path) {
  struct stat info;
  return ::stat(path.c_str(), &info) == 0;
}

}  // namespace

const std::vector<std::string> &Scaffold::ci_systems() {
  static const std::vector<std::string> systems = {"github", "gitlab"};
  return systems;
}

std::string Scaffold::github_job(const std::string &recipe) { return replace_recipe(kGithub, recipe); }

std::string Scaffold::gitlab_job(const std::string &recipe) { return replace_recipe(kGitlab, recipe); }

std::string Scaffold::in_directory(const std::string &name) const {
  return directory_ == "." ? name : directory_ + "/" + name;
}

std::vector<std::pair<std::string, std::string>> Scaffold::files() const {
  std::vector<std::pair<std::string, std::string>> result = {
      {in_directory("recipe.scm"), kRecipe},
      {in_directory("vars.scm"), kVars},
      {in_directory("hosts.scm"), kHosts},
      {in_directory("templates/motd.tmpl"), kMotd},
  };
  std::string recipe = in_directory("recipe.scm");
  if (ci_ == "github") {
    result.push_back({".github/workflows/sadame-drift.yml", std::string(kGithubHeader) + "\n" + github_job(recipe)});
  }
  if (ci_ == "gitlab") {
    result.push_back({".gitlab/sadame-drift.yml", std::string(kGitlabHeader) + "\n" + gitlab_job(recipe)});
  }
  return result;
}

std::vector<std::string> Scaffold::write() {
  auto planned = files();
  std::string existing;
  for (const auto &[path, content] : planned) {
    if (exists(path)) existing += (existing.empty() ? "" : ", ") + path;
  }
  if (!existing.empty()) {
    throw UsageError("init writes nothing when one of its files exists, and these do: " + existing);
  }

  std::vector<std::string> paths;
  for (const auto &[path, content] : planned) {
    std::string directory = dirname(path);
    if (directory != ".") shell_.run_checked("mkdir -p " + Shell::escape(directory));
    shell_.write_file(path, content);
    paths.push_back(path);
  }
  return paths;
}

}  // namespace sadame
