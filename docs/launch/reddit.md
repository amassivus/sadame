# Reddit

## r/ruby

**Title:** Sadame 0.1.0: Itamae-style recipes in a single mruby binary, with plan/apply/drift

**Body:**

I released the first version of Sadame, a configuration management tool
whose recipes are plain Ruby:

```ruby
package "nginx"
file "/etc/nginx/conf.d/app.conf", template: "app.conf.erb", notifies: [:reload, "service[nginx]"]
service "nginx", enable: true, state: :running
```

The Ruby side may interest this sub: the whole tool is compiled with mruby
into one static binary of about 1 MB, which runs the recipes, the
inventory (`hosts.rb`, also Ruby) and an ERB-compatible template engine
without any Ruby on the target. The same test suite runs on CRuby
(minitest) and inside the mruby build (mruby-mtest), which keeps `lib/`
honest about what mruby supports; the architecture page lists the
differences that bit me, such as a bare `raise` inside `rescue`.

Docs: https://enderkus.github.io/sadame/
Source (MIT): https://github.com/enderkus/sadame

It is 0.1.0 with six resource types, so feedback on what to add next is
welcome.

## r/devops

**Title:** Sadame 0.1.0: plan/apply/drift for Linux servers from one binary, no agent, no Python on targets

**Body:**

Sadame is a small configuration management tool I released this week. The
workflow is the one Terraform users know, applied to what is inside the
machines:

- `sadame plan site.rb -g web` reads each host and prints what would
  change, with diffs.
- `sadame apply site.rb -g web` changes only what differs.
- `sadame drift site.rb -g all` exits 1 when a host no longer matches, 2
  when the check itself failed; `--json` for CI artifacts.

Targets need SSH, a POSIX shell and `tar`; sadame copies its own static
binary over, keyed by checksum. Inventories are Ruby files with groups,
per-host vars and dynamic hosts from any command's JSON output.

Honest limits: six resource types, Linux only, no secrets management, no
central server, first release. There is a comparison page with Ansible,
Chef and Puppet in the docs.

Docs: https://enderkus.github.io/sadame/
