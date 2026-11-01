# frozen_string_literal: true

class TagsTest < SadameTest
  SITE = "test/fixtures/recipes/tags/site.rb"

  def load_site(shell = fresh_shell)
    Sadame::Recipe.load(SITE, host: host_for(shell), vars: {})
  end

  def test_tags_are_strings_and_include_recipe_adds_its_own
    tags = load_site.to_a.map { |resource| [resource.id, resource.tags] }
    assert_equal [["file[/etc/motd]", []], ["package[nginx]", ["web"]],
                  ["file[/etc/nginx/conf.d/app.conf]", ["web", "config"]], ["service[nginx]", ["web"]],
                  ["package[htop]", ["tools"]]], tags
  end

  def test_invalid_tags
    [3, "a,b", "two words", "", [:ok, nil]].each do |value|
      error = assert_raises(Sadame::ResourceError) do
        build_resource(Sadame::PackageResource, "git", { tags: value })
      end
      assert_includes error.message, "tags must be Symbols or Strings without commas or spaces", value.inspect
    end
  end

  def test_selection
    resources = load_site.to_a
    pick = lambda do |selection|
      resources.select { |resource| selection.include?(resource) }.map { |resource| resource.id }
    end
    assert_equal 5, pick.call(Sadame::Selection.new).size
    assert_equal ["package[nginx]", "file[/etc/nginx/conf.d/app.conf]", "service[nginx]"],
                 pick.call(Sadame::Selection.new(tags: ["web"]))
    assert_equal ["file[/etc/nginx/conf.d/app.conf]", "package[htop]"],
                 pick.call(Sadame::Selection.new(tags: ["config", "tools"]))
    assert_equal ["package[nginx]", "service[nginx]"],
                 pick.call(Sadame::Selection.new(tags: ["web"], skip_tags: ["config"]))
  end

  def test_plan_reports_only_the_selected_resources
    status, stdout, = run_cli(["plan", SITE, "--tags", "web"], shell: fresh_shell)
    assert_equal 0, status
    assert_includes stdout, "on local (Debian GNU/Linux 12 (bookworm))\nOnly resources tagged web: 3 of 5.\n\n"
    refute_includes stdout, "package[htop]"
    refute_includes stdout, "file[/etc/motd]"
    assert_includes stdout, "Plan: 2 to create, 1 to update,"

    _status, stdout, = run_cli(["plan", SITE, "--skip-tags=web,tools", "--json"], shell: fresh_shell)
    assert_includes stdout, "\"tags\": [],\n  \"skip_tags\": [\n    \"web\",\n    \"tools\"\n  ],"
    assert_includes stdout, "\"id\": \"file[/etc/motd]\""
    refute_includes stdout, "\"id\": \"package[nginx]\""
  end

  # The file is selected, the service is not; the reload still runs.
  def test_notifications_reach_resources_outside_the_selection
    shell = fresh_shell.on("test -d /run/systemd/system")
    status, stdout, = run_cli(["apply", SITE, "--tags", "config"], shell: shell)
    assert_equal 0, status
    assert_includes stdout, "changed    file[/etc/nginx/conf.d/app.conf]"
    assert_includes stdout, "notified   service[nginx]: reload"
    assert_includes shell.commands, "systemctl reload nginx"
    refute_includes stdout, "package[nginx]"
  end

  def test_tags_only_apply_to_recipe_commands
    status, _stdout, stderr = run_cli(["facts", "--tags", "web"])
    assert_equal 2, status
    assert_includes stderr, "--tags only applies to plan, apply and drift"
  end

  def test_include_recipe_takes_only_tags
    status, _stdout, stderr = run_cli(["plan", "test/fixtures/recipes/tags/bad_include.rb"], shell: fresh_shell)
    assert_equal 2, status
    assert_includes stderr, "include_recipe takes only tags:, got :when"
  end
end
