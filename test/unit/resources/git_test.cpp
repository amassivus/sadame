#include "../../support/test_helpers.hpp"

#include "../../../lib/sadame/resources/git.hpp"

using namespace sadame;
using namespace test;

namespace {

const char *kPath = "/srv/app";
const char *kRepository = "https://github.com/example/app.git";
const std::string kCommit = FreshHostShell::kFakeCommit;
const char *kStat = "stat -c '%a %U %G %F' /srv/app";

std::string git(const std::string &arguments) { return "GIT_TERMINAL_PROMPT=0 git -c safe.directory=/srv/app " + arguments; }

std::unique_ptr<GitResource> git_resource(Machine &machine, const Value &options) {
  Value full = map({{"repository", kRepository}});
  for (std::size_t index = 0; index < options.keys().size(); ++index) full.set(options.keys()[index], options.values()[index]);
  return build_resource<GitResource>(machine.host, kPath, full);
}

// A machine with git where the checkout does not exist yet.
std::unique_ptr<Machine> fresh() {
  auto machine = fresh_machine();
  return machine;
}

// A machine with an existing checkout at `commit`.
std::unique_ptr<Machine> checkout(const std::string &commit, const std::string &url = kRepository) {
  auto machine = fresh_machine();
  machine->shell.on(kStat, "755 root root directory\n");
  machine->shell.on("test -d /srv/app/.git");
  machine->shell.on(git("-C /srv/app config --get remote.origin.url"), url + "\n");
  machine->shell.on(git("-C /srv/app rev-parse HEAD"), commit + "\n");
  return machine;
}

}  // namespace

TEST(GitResource, clones_and_checks_out_the_branch_head) {
  auto machine = fresh();
  auto resource = git_resource(*machine, map({{"revision", "main"}}));
  auto changes = resource->diff();
  EXPECT_EQ(std::string("create"), resource->plan_action(changes));
  EXPECT_EQ(Value(kCommit), changes.back().to);

  resource->apply(changes);
  EXPECT_EQ(git("clone --quiet --no-checkout https://github.com/example/app.git /srv/app"), machine->shell.last(2).front());
  EXPECT_EQ(git("-C /srv/app checkout --quiet --force --detach " + kCommit), machine->shell.commands.back());
}

TEST(GitResource, tags_win_over_branches_and_are_peeled) {
  auto machine = fresh();
  auto resource = git_resource(*machine, map({{"revision", "v1.4.2"}}));
  resource->diff();
  EXPECT_CONTAINS(machine->shell.commands.back() + machine->shell.commands[machine->shell.commands.size() - 2],
                  "'refs/tags/v1.4.2^{}' refs/tags/v1.4.2 refs/heads/v1.4.2");
}

TEST(GitResource, without_revision_follows_the_remote_head) {
  auto machine = fresh();
  auto resource = git_resource(*machine, map());
  EXPECT_EQ(Value(kCommit), resource->diff().back().to);
  EXPECT_EQ(std::string("HEAD"), resource->revision());
}

TEST(GitResource, a_commit_needs_no_remote_lookup) {
  auto machine = fresh();
  std::string commit(40, 'a');
  auto resource = git_resource(*machine, map({{"revision", commit}}));
  EXPECT_EQ(Value(commit), resource->diff().back().to);
  for (const std::string &command : machine->shell.commands) EXPECT_NOT_CONTAINS(command, "ls-remote");
}

TEST(GitResource, an_up_to_date_checkout_is_unchanged) {
  auto machine = checkout(kCommit);
  EXPECT_EMPTY(git_resource(*machine, map({{"revision", "main"}}))->diff());
}

TEST(GitResource, moves_the_checkout_when_the_branch_moved) {
  auto machine = checkout(std::string(40, 'b'));
  auto resource = git_resource(*machine, map({{"revision", "main"}}));
  auto changes = resource->diff();
  EXPECT_EQ((std::vector<std::string>{"revision"}), change_attributes(changes));
  resource->apply(changes);
  EXPECT_EQ(git("-C /srv/app fetch --quiet --tags origin"), machine->shell.last(2).front());
  EXPECT_EQ(git("-C /srv/app checkout --quiet --force --detach " + kCommit), machine->shell.commands.back());
}

TEST(GitResource, a_new_repository_url_is_set_without_moving_the_checkout) {
  auto machine = checkout(kCommit, "https://old.example.com/app.git");
  auto resource = git_resource(*machine, map({{"revision", "main"}}));
  auto changes = resource->diff();
  EXPECT_EQ((std::vector<std::string>{"repository"}), change_attributes(changes));
  resource->apply(changes);
  EXPECT_EQ(git("-C /srv/app remote set-url origin " + std::string(kRepository)), machine->shell.last(2).front());
}

TEST(GitResource, runs_git_as_the_user) {
  auto machine = fresh();
  auto resource = git_resource(*machine, map({{"revision", "main"}, {"user", "deploy"}}));
  resource->diff();
  EXPECT_CONTAINS(machine->shell.commands.back(), "su -s /bin/sh deploy -c ");
  EXPECT_CONTAINS(machine->shell.commands.back(), "cd / && GIT_TERMINAL_PROMPT=0 git ls-remote");
}

TEST(GitResource, plan_on_a_machine_without_git_shows_the_revision_as_written) {
  auto machine = fresh();
  machine->shell.on("command -v git", "", "", 1);
  auto resource = git_resource(*machine, map({{"revision", "v1.0"}}));
  EXPECT_EQ(Value("v1.0"), resource->diff().back().to);
  EXPECT_THROWS(ResourceError, resource->apply(resource->diff()), "git is not installed");
}

TEST(GitResource, errors_from_the_remote) {
  auto machine = fresh();
  machine->shell.on(git("ls-remote https://github.com/example/app.git HEAD"), "", "fatal: repository not found\n", 128);
  EXPECT_THROWS(ResourceError, git_resource(*machine, map())->diff(), "cannot read https://github.com/example/app.git");

  auto empty = fresh();
  empty->shell.on(git("ls-remote https://github.com/example/app.git 'refs/tags/nope^{}' refs/tags/nope refs/heads/nope"), "");
  EXPECT_THROWS(ResourceError, git_resource(*empty, map({{"revision", "nope"}}))->diff(), "has no branch or tag named nope");
}

TEST(GitResource, an_empty_directory_is_cloned_into) {
  auto machine = fresh();
  machine->shell.on(kStat, "755 root root directory\n");
  machine->shell.on("test -d /srv/app/.git", "", "", 1);
  machine->shell.on("ls -A /srv/app", "");
  auto resource = git_resource(*machine, map({{"revision", "main"}}));
  EXPECT_EQ(std::string("create"), resource->plan_action(resource->diff()));

  auto full = fresh();
  full->shell.on(kStat, "755 root root directory\n");
  full->shell.on("test -d /srv/app/.git", "", "", 1);
  full->shell.on("ls -A /srv/app", "file.txt\n");
  EXPECT_THROWS(ResourceError, git_resource(*full, map())->diff(), "directory with files in it, but not a git checkout");
}

TEST(GitResource, removes_a_checkout) {
  auto machine = checkout(kCommit);
  auto resource = git_resource(*machine, map({{"state", sym("absent")}}));
  auto changes = resource->diff();
  EXPECT_EQ(std::string("remove"), resource->plan_action(changes));
  resource->apply(changes);
  EXPECT_EQ(std::string("rm -rf /srv/app"), machine->shell.commands.back());
}

TEST(GitResource, validation) {
  auto machine = fresh();
  EXPECT_THROWS(ResourceError, build_resource<GitResource>(machine->host, kPath, map()), "#:repository is required");
  EXPECT_THROWS(ResourceError, git_resource(*machine, map({{"revision", ""}})), "revision must be a non-empty string");
}
