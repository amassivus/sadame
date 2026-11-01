# frozen_string_literal: true

class ValidateTest < SadameTest
  # The Docker distribution names are validate's platform names.
  def test_every_example_is_valid_on_the_distributions_it_supports
    ExampleMatrix::EXAMPLES.each do |example|
      path = ExampleMatrix.recipe_path(example)
      example[:distros].each do |distro|
        ExampleMatrix.runs(example).each do |arguments|
          status, stdout, stderr = run_cli(["validate", path, "--platform", distro] + arguments)
          assert_equal 0, status, "#{path} on #{distro}: #{stdout}#{stderr}"
        end
      end
    end
  end

  def test_each_host_is_checked_with_its_own_vars
    status, stdout, = run_cli(["validate", "examples/08-multi-role-inventory/site.rb", "-g", "all"])
    assert_equal 0, status
    assert_includes stdout, "as on Debian GNU/Linux 12 (bookworm)\n\n  web1.example.com  ok     6 resources\n"
    assert_includes stdout, "validate on 3 hosts: 3 ok.\n"
  end

  def test_template_errors_are_found_without_a_machine
    status, stdout, = run_cli(["validate", "test/fixtures/recipes/broken_template"])
    assert_equal 2, status
    assert_includes stdout, "  local  error  test/fixtures/recipes/broken_template/templates/app.conf.erb:2: "
    assert_includes stdout, "nmae"
    assert_includes stdout, "validate on 1 host: 0 ok, 1 error.\n"
  end

  def test_json
    status, stdout, = run_cli(["validate", "examples/01-hello", "--json", "--platform", "alpine"])
    assert_equal 0, status
    assert_includes stdout, "\"command\": \"validate\",\n  \"recipe\": \"examples/01-hello/recipe.rb\","
    assert_includes stdout, "\"name\": \"Alpine Linux v3.20\""
    assert_includes stdout, "\"name\": \"local\",\n      \"status\": \"ok\",\n      \"resources\": 1,\n      \"error\": null"
  end

  def test_platform_option
    status, _stdout, stderr = run_cli(["validate", "examples/01-hello", "--platform", "gentoo"])
    assert_equal 2, status
    assert_includes stderr, "unknown platform gentoo for --platform (known: debian, ubuntu, rocky, alpine, arch)"

    status, _stdout, stderr = run_cli(["plan", "examples/01-hello", "--platform", "rocky"])
    assert_equal 2, status
    assert_includes stderr, "--platform only applies to validate"
  end

  def test_the_stand_in_machine_runs_nothing
    host = Sadame::StandIn::Host.new(name: "web1.example.com", groups: [:web], platform: Sadame::StandIn.platform("alpine"))
    error = assert_raises(Sadame::Error) { host.shell.run("rm -rf /") }
    assert_includes error.message, "validate runs no commands"
    assert_equal ["web1", "web1.example.com", 2, "openrc"],
                 [host.facts[:hostname], host.facts[:fqdn], host.facts[:cpus], host.facts[:service_manager]]
    assert_raises(Sadame::RecipeError) { host.facts[:cpu] }
  end
end
