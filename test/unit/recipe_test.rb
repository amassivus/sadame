# frozen_string_literal: true

class RecipeTest < SadameTest
  BASIC = "test/fixtures/recipes/basic/recipe.rb"

  def load_recipe(path, vars: {})
    Sadame::Recipe.load(path, host: host_for(linux_shell), vars: vars)
  end

  def test_loads_resources_in_declaration_order
    resources = load_recipe(BASIC, vars: { port: 80, server_name: "example.com" })
    ids = resources.to_a.map { |resource| resource.id }
    expected = [
      "package[nginx]",
      "directory[/var/www/app]",
      "file[/etc/nginx/conf.d/app.conf]",
      "service[nginx]",
      "exec[touch /var/www/app/.ready]"
    ]
    assert_equal expected, ids
  end

  def test_vars_drive_plain_ruby_conditions
    resources = load_recipe(BASIC, vars: { with_user: true })
    refute_nil resources.find("user[deploy]")
  end

  def test_included_recipes_resolve_templates_relative_to_themselves
    resources = load_recipe(BASIC)
    file = resources.find("file[/etc/nginx/conf.d/app.conf]")
    assert_equal "test/fixtures/recipes/basic/templates/app.conf.erb", file.local_file
  end

  def test_duplicate_resources_are_rejected
    error = assert_raises(Sadame::RecipeError) { load_recipe("test/fixtures/recipes/duplicate/recipe.rb") }
    assert_includes error.message, "test/fixtures/recipes/duplicate/recipe.rb:3"
    assert_includes error.message, "package[git] is declared more than once"
  end

  def test_notifications_must_target_declared_resources
    error = assert_raises(Sadame::ResourceError) { load_recipe("test/fixtures/recipes/bad_notification/recipe.rb") }
    assert_includes error.message, "file[/etc/app.conf] notifies service[app], which is not declared"
  end

  def test_notifications_must_use_supported_actions
    shell = linux_shell
    collection = Sadame::ResourceCollection.new
    host = host_for(shell)
    collection.add(Sadame::ExecResource.new("make", {}, host: host, source_dir: ".", vars: {}))
    collection.add(Sadame::FileResource.new("/etc/x", { content: "x", notifies: [:reload, "exec[make]"] },
                                            host: host, source_dir: ".", vars: {}))
    error = assert_raises(Sadame::ResourceError) { collection.validate_notifications }
    assert_includes error.message, "to reload, but exec supports: run"
  end

  def test_syntax_errors_name_the_file
    error = assert_raises(Sadame::RecipeError) { load_recipe("test/fixtures/recipes/syntax_error/recipe.rb") }
    assert_includes error.message, "test/fixtures/recipes/syntax_error/recipe.rb"
  end

  def test_resource_errors_point_at_the_recipe_line
    error = assert_raises(Sadame::RecipeError) { load_recipe("test/fixtures/recipes/unknown_option/recipe.rb") }
    assert_includes error.message, "test/fixtures/recipes/unknown_option/recipe.rb:2"
    assert_includes error.message, "unknown option :contents"
  end

  def test_missing_include
    error = assert_raises(Sadame::RecipeError) { load_recipe("test/fixtures/recipes/missing_include/recipe.rb") }
    assert_includes error.message, "recipe.rb:2"
    assert_includes error.message, "include_recipe cannot find test/fixtures/recipes/missing_include/roles/missing.rb"
  end

  def test_notifies_accepts_a_list
    host = host_for(linux_shell)
    resource = Sadame::FileResource.new("/etc/x", { content: "x", notifies: [[:reload, "service[a]"], [:run, "exec[b]"]] },
                                        host: host, source_dir: ".", vars: {})
    assert_equal ["reload service[a]", "run exec[b]"], resource.notifications.map { |notification| notification.key }
  end

  def test_notifies_rejects_malformed_values
    host = host_for(linux_shell)
    error = assert_raises(Sadame::ResourceError) do
      Sadame::FileResource.new("/etc/x", { content: "x", notifies: "service[nginx]" }, host: host, source_dir: ".", vars: {})
    end
    assert_includes error.message, "notifies expects [:action, \"type[name]\"]"
  end
end
