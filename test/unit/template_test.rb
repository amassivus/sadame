# frozen_string_literal: true

class TemplateTest < SadameTest
  def render(source, vars: {}, locals: {})
    Sadame::Template.new(source, "test.erb").render(vars: vars, locals: locals)
  end

  def test_plain_text_is_unchanged
    assert_equal "no tags here\n", render("no tags here\n")
  end

  def test_expressions_use_vars_and_locals
    assert_equal "server example.com:8080\n",
                 render("server <%= vars[:host] %>:<%= locals[:port] %>\n", vars: { host: "example.com" }, locals: { port: 8080 })
  end

  def test_code_tags_control_flow
    source = "<% vars[:names].each do |name| %>- <%= name %>\n<% end %>"
    assert_equal "- a\n- b\n", render(source, vars: { names: ["a", "b"] })
  end

  def test_code_tags_keep_their_newline_like_erb
    assert_equal "\nyes\n", render("<% if true %>\nyes\n<% end %>")
  end

  def test_dash_close_removes_the_following_newline
    source = "<% if vars[:tls] -%>\nlisten 443 ssl;\n<% end -%>\nend\n"
    assert_equal "listen 443 ssl;\nend\n", render(source, vars: { tls: true })
    assert_equal "end\n", render(source, vars: { tls: false })
  end

  def test_dash_open_removes_indentation
    source = "a\n  <%- if true -%>\nb\n  <%- end -%>\nc\n"
    assert_equal "a\nb\nc\n", render(source)
  end

  def test_comments_produce_nothing
    assert_equal "ab", render("a<%# ignored %>b")
  end

  def test_double_percent_is_a_literal_tag
    assert_equal "<% raw %>", render("<%% raw %>")
  end

  def test_text_with_quotes_and_interpolation_markers_is_literal
    source = "say \"hi\" #{'#'}{not_ruby} \\n done"
    assert_equal source, render(source)
  end

  def test_unclosed_tag_reports_the_line
    error = assert_raises(Sadame::RecipeError) { render("one\ntwo <%= oops\n") }
    assert_includes error.message, "test.erb:2"
  end

  def test_errors_point_at_the_template_line
    error = assert_raises(Sadame::RecipeError) { render("line one\nline two\n<%= undefined_name %>\n") }
    assert_includes error.message, "test.erb:3"
    assert_includes error.message, "undefined_name"
  end
end
