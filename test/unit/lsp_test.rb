# frozen_string_literal: true

class LspTest < SadameTest
  PROJECT = File.expand_path("test/fixtures/lsp/project")
  WEB = "#{PROJECT}/roles/web.rb"

  def frame(message)
    body = JSON.generate(message)
    "Content-Length: #{body.bytesize}\r\n\r\n#{body}"
  end

  # Runs the server over the messages; returns [exit status, messages out].
  def session(*messages, capabilities: {})
    first = { jsonrpc: "2.0", id: 0, method: "initialize",
              params: { rootUri: Sadame::Lsp::Text.uri(PROJECT), capabilities: capabilities } }
    input = FakeInput.new(([first] + messages).map { |message| frame(message) }.join)
    output = FakeIO.new
    status = Sadame::Lsp::Server.new(input, output, shell: linux_shell).run
    [status, parse_frames(output.string)]
  end

  def parse_frames(text)
    text = text.respond_to?(:b) ? text.b : text
    messages = []
    until text.empty?
      header_end = text.index("\r\n\r\n")
      length = text[0, header_end].split(":")[1].strip.to_i
      messages << JSON.parse(text[header_end + 4, length])
      text = text[(header_end + 4 + length)..] || ""
    end
    messages
  end

  def open(path, text = File.read(path))
    { jsonrpc: "2.0", method: "textDocument/didOpen",
      params: { textDocument: { uri: Sadame::Lsp::Text.uri(path), languageId: "ruby", version: 1, text: text } } }
  end

  def change(path, text)
    { jsonrpc: "2.0", method: "textDocument/didChange",
      params: { textDocument: { uri: Sadame::Lsp::Text.uri(path), version: 2 }, contentChanges: [{ text: text }] } }
  end

  def request(id, method, path, line, character)
    { jsonrpc: "2.0", id: id, method: method,
      params: { textDocument: { uri: Sadame::Lsp::Text.uri(path) }, position: { line: line, character: character } } }
  end

  def done
    [{ jsonrpc: "2.0", id: 99, method: "shutdown" }, { jsonrpc: "2.0", method: "exit" }]
  end

  # The last diagnostics sent for each file, as [line, message] pairs.
  def diagnostics(messages)
    result = {}
    messages.select { |message| message["method"] == "textDocument/publishDiagnostics" }.each do |message|
      file = Sadame::Lsp::Text.path(message["params"]["uri"]).sub("#{PROJECT}/", "")
      result[file] = message["params"]["diagnostics"].map { |entry| [entry["range"]["start"]["line"], entry["message"]] }
    end
    result
  end

  def response(messages, id)
    messages.find { |message| message["id"] == id }
  end

  def test_capabilities_and_clean_exit
    status, messages = session(*done)
    assert_equal 0, status
    capabilities = response(messages, 0)["result"]["capabilities"]
    assert_equal ["utf-16", 1, [":"], true, true],
                 [capabilities["positionEncoding"], capabilities["textDocumentSync"]["change"],
                  capabilities["completionProvider"]["triggerCharacters"], capabilities["hoverProvider"],
                  capabilities["documentSymbolProvider"]]
    assert_equal({ "result" => nil, "id" => 99, "jsonrpc" => "2.0" }, response(messages, 99))

    status, = session({ jsonrpc: "2.0", method: "exit" })
    assert_equal 1, status
  end

  def test_the_platform_comes_from_initialization_options
    text = "raise \"not RHEL\" unless platform.family == \"rhel\"\npackage \"httpd\"\n"
    path = "#{PROJECT}/scratch.rb"
    first = { jsonrpc: "2.0", id: 0, method: "initialize",
              params: { rootUri: Sadame::Lsp::Text.uri(PROJECT), capabilities: {},
                        initializationOptions: { platform: "rocky" } } }
    input = FakeInput.new(([first, open(path, text)] + done).map { |message| frame(message) }.join)
    output = FakeIO.new
    Sadame::Lsp::Server.new(input, output, shell: linux_shell).run
    assert_equal({ "scratch.rb" => [] }, diagnostics(parse_frames(output.string)))

    _status, messages = session(open(path, text), *done)
    assert_equal [[0, "not RHEL"]], diagnostics(messages)["scratch.rb"]
  end

  def test_utf8_positions_when_the_client_offers_them
    _status, messages = session(*done, capabilities: { general: { positionEncodings: ["utf-8", "utf-16"] } })
    assert_equal "utf-8", response(messages, 0)["result"]["capabilities"]["positionEncoding"]
  end

  # roles/web.rb is included on the web servers only, so db1's missing
  # workers var is not a problem.
  def test_an_included_file_is_checked_for_the_hosts_that_include_it
    _status, messages = session(open(WEB), *done)
    assert_equal({ "roles/web.rb" => [] }, diagnostics(messages))
  end

  def test_a_typo_is_reported_on_its_line
    text = File.read(WEB).sub("mode:", "mdoe:")
    _status, messages = session(open(WEB), change(WEB, text), *done)
    problems = diagnostics(messages)["roles/web.rb"]
    assert_equal 1, problems.size
    assert_equal 3, problems[0][0]
    assert_includes problems[0][1], "file[/etc/app.conf]: unknown option :mdoe (valid options:"
  end

  def test_template_errors_go_to_the_template_and_name_the_hosts
    site = "#{PROJECT}/site.rb"
    text = File.read(site).sub("if host_groups.include?(:web)", "")
    _status, messages = session(open(site, text), *done)
    problems = diagnostics(messages)
    assert_equal [[0, "undefined method '*' for nil (on db1.example.com)"]],
                 problems["roles/templates/app.conf.erb"].map { |line, message| [line, message.sub(" for NilClass", " for nil")] }
    assert_equal [], problems["site.rb"]
  end

  def test_errors_without_a_line_are_placed_on_the_declaration
    text = "#{File.read(WEB)}service \"nginx-extra\", notifies: [:reload, \"service[missing]\"]\n"
    _status, messages = session(open(WEB, text), *done)
    problems = diagnostics(messages)["roles/web.rb"]
    assert_equal [[5, "service[nginx-extra] notifies service[missing], which is not declared"]], problems
  end

  def test_files_outside_a_project_are_left_alone
    path = File.expand_path("Rakefile")
    _status, messages = session(open(path), *done)
    assert_equal({ "Rakefile" => [] }, diagnostics(messages).transform_keys { |key| File.basename(key) })
  end

  def test_completion
    text = "package \"nginx\", st\nfile \"/etc/x\",\n     \nservice \"nginx\", state: :\nx = facts[:c\n"
    path = "#{PROJECT}/scratch.rb"
    _status, messages = session(open(path, text), request(1, "textDocument/completion", path, 0, 19),
                                request(2, "textDocument/completion", path, 2, 5),
                                request(3, "textDocument/completion", path, 3, 25),
                                request(4, "textDocument/completion", path, 4, 12),
                                request(5, "textDocument/completion", path, 5, 0), *done)
    labels = ->(id) { response(messages, id)["result"].map { |item| item["label"] } }
    assert_equal ["state:", "options:", "notifies:", "subscribes:", "tags:"], labels.call(1)
    assert_includes labels.call(2), "template:"
    assert_equal ["running", "stopped"], labels.call(3)
    assert_includes labels.call(4), "cpus"
    assert_includes labels.call(5), "git"
    assert_includes labels.call(5), "include_recipe"
    option = response(messages, 2)["result"].find { |item| item["label"] == "mode:" }
    assert_equal ["mode: ", 10], [option["insertText"], option["kind"]]
    assert_includes option["documentation"]["value"], "Permission bits"
  end

  def test_hover_and_symbols
    _status, messages = session(open(WEB), request(1, "textDocument/hover", WEB, 0, 3),
                                request(2, "textDocument/hover", WEB, 3, 6),
                                { jsonrpc: "2.0", id: 3, method: "textDocument/documentSymbol",
                                  params: { textDocument: { uri: Sadame::Lsp::Text.uri(WEB) } } }, *done)
    package = response(messages, 1)["result"]
    assert package["contents"]["value"].start_with?("**package**\n\n`package` makes sure a system package")
    assert_equal({ "line" => 0, "character" => 0 }, package["range"]["start"])
    assert_includes response(messages, 2)["result"]["contents"]["value"], "**mode** (file)"
    assert_equal ["package[nginx]", "file[/etc/app.conf]", "service[nginx]"],
                 response(messages, 3)["result"].map { |symbol| symbol["name"] }
  end

  def test_unknown_requests_and_recipes_that_print
    text = "puts \"debugging\"\npackage \"nginx\"\n"
    path = "#{PROJECT}/scratch.rb"
    _status, messages = session(open(path, text), { jsonrpc: "2.0", id: 1, method: "textDocument/definition", params: {} },
                                *done)
    assert_equal(-32_601, response(messages, 1)["error"]["code"])
    assert_equal({ "scratch.rb" => [] }, diagnostics(messages))
  end

  def test_positions_count_utf16_units
    line = "file \"/etc/motd\", content: \"Grüße 👋\", mo"
    assert_equal line.bytesize, Sadame::Lsp::Text.byte_column(line, 41, "utf-16")
    assert_equal 41, Sadame::Lsp::Text.length(line, "utf-16")
    assert_equal 5, Sadame::Lsp::Text.byte_column(line, 5, "utf-8")
  end

  def test_uris
    path = "/srv/my recipes/sité.rb"
    uri = Sadame::Lsp::Text.uri(path)
    assert_equal "file:///srv/my%20recipes/sit%C3%A9.rb", uri
    assert_equal path, Sadame::Lsp::Text.path(uri)
  end
end
