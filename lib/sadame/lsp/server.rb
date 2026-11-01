# frozen_string_literal: true

module Sadame
  module Lsp
    # `sadame lsp`: a language server for recipes, on stdin and stdout.
    # Editors start it and send it the files being edited; it answers with
    # problems (see Checker), completions, hover text and the outline (see
    # Editing).
    #
    # Messages are handled one at a time. A failure in one is answered with
    # an error, or logged for a notification, and the server goes on.
    class Server
      INTERNAL_ERROR = -32_603
      METHOD_NOT_FOUND = -32_601
      SEVERITY_ERROR = 1
      MESSAGE_ERROR = 1

      class UnknownMethod < StandardError; end

      # Takes everything a recipe prints while it is evaluated, which would
      # otherwise end up in the middle of the protocol on stdout.
      class Sink
        def write(text)
          text.to_s.size
        end

        def print(*); end

        def puts(*); end

        def flush; end
      end

      def initialize(input, output, shell:)
        @connection = Connection.new(input, output)
        @shell = shell
        @documents = {}
        @published = {}
        @encoding = "utf-16"
        @checker = Checker.new(shell, root: nil, platform: StandIn.platform("debian"))
        @shutdown = false
      end

      # Returns the exit status once the client says exit.
      def run
        loop do
          message = @connection.read
          return 1 if message.nil?

          status = handle(message)
          return status if status
        end
      end

      private

      def handle(message)
        method = message["method"]
        return finish if method == "exit"

        params = message["params"] || {}
        result = dispatch(method, params)
        respond(message["id"], result) if message.key?("id")
        nil
      rescue UnknownMethod
        reply_error(message["id"], METHOD_NOT_FOUND, "sadame lsp does not handle #{method}") if message.key?("id")
        nil
      rescue StandardError => e
        details = "#{method}: #{e.class}: #{e.message}"
        message.key?("id") ? reply_error(message["id"], INTERNAL_ERROR, details) : log(details)
        nil
      end

      def finish
        @shutdown ? 0 : 1
      end

      def dispatch(method, params)
        case method
        when "initialize" then initialize_server(params)
        when "initialized", "$/cancelRequest", "$/setTrace", "workspace/didChangeConfiguration" then nil
        when "shutdown" then shut_down
        when "textDocument/didOpen" then opened(params["textDocument"])
        when "textDocument/didChange" then changed(params)
        when "textDocument/didSave" then saved(params["textDocument"]["uri"])
        when "textDocument/didClose" then closed(params["textDocument"]["uri"])
        when "textDocument/completion" then completion(params)
        when "textDocument/hover" then hover(params)
        when "textDocument/documentSymbol" then symbols(params["textDocument"]["uri"])
        else raise UnknownMethod
        end
      end

      def shut_down
        @shutdown = true
        nil
      end

      def initialize_server(params)
        offered = ((params["capabilities"] || {})["general"] || {})["positionEncodings"] || []
        @encoding = offered.include?("utf-8") ? "utf-8" : "utf-16"
        root = params["rootUri"] ? Text.path(params["rootUri"]) : params["rootPath"]
        platform = (params["initializationOptions"] || {})["platform"] || "debian"
        @checker = Checker.new(@shell, root: root, platform: StandIn.platform(platform))
        {
          capabilities: {
            positionEncoding: @encoding,
            textDocumentSync: { openClose: true, change: 1, save: { includeText: false } },
            completionProvider: { triggerCharacters: [":"] },
            hoverProvider: true,
            documentSymbolProvider: true
          },
          serverInfo: { name: "sadame", version: VERSION }
        }
      end

      def opened(document)
        @documents[document["uri"]] = document["text"].to_s
        publish(document["uri"])
      end

      # Full text sync: the last change holds the whole document.
      def changed(params)
        uri = params["textDocument"]["uri"]
        @documents[uri] = params["contentChanges"].last["text"].to_s
        publish(uri)
      end

      # A saved vars.rb, hosts.rb or template can change what every open
      # recipe finds.
      def saved(uri)
        name = File.basename(Text.path(uri))
        if name == "vars.rb" || (name.start_with?("hosts") && name.end_with?(".rb")) || name.end_with?(".erb")
          @checker.forget
          @documents.each_key { |open| publish(open) }
        end
        publish(uri) if @documents.key?(uri)
        nil
      end

      def closed(uri)
        @documents.delete(uri)
        (@published.delete(uri) || []).each { |target| send_diagnostics(target, []) }
        nil
      end

      def publish(uri)
        path = Text.path(uri)
        problems = quietly { @checker.check(path, @documents[uri].to_s) }
        targets = problems.keys.map { |file| Text.uri(file) }
        ((@published[uri] || []) - targets).each { |target| send_diagnostics(target, []) }
        send_diagnostics(uri, []) unless targets.include?(uri)
        problems.each { |file, entries| send_diagnostics(Text.uri(file), diagnostics(file, entries)) }
        @published[uri] = targets
        nil
      end

      def diagnostics(file, entries)
        lines = (@documents[Text.uri(file)] || read(file)).split("\n", -1)
        entries.map do |line, message|
          line = 0 if line < 0 || line >= lines.size
          width = Text.length(lines[line].to_s, @encoding)
          { range: { start: { line: line, character: 0 }, end: { line: line, character: width } },
            severity: SEVERITY_ERROR, source: "sadame", message: message }
        end
      end

      def send_diagnostics(uri, diagnostics)
        @connection.write({ jsonrpc: "2.0", method: "textDocument/publishDiagnostics",
                            params: { uri: uri, diagnostics: diagnostics } })
      end

      def completion(params)
        line, column = position(params)
        return [] if line.nil?

        editing(params).completion(line, column)
      end

      def hover(params)
        line, column = position(params)
        return nil if line.nil?

        found = editing(params).hover(line, column)
        return nil if found.nil?

        text, start, stop = found
        source = lines_of(params)[line].to_s
        { contents: { kind: "markdown", value: text },
          range: { start: { line: line, character: unit_column(source, start) },
                   end: { line: line, character: unit_column(source, stop) } } }
      end

      def symbols(uri)
        lines = @documents[uri].to_s.split("\n", -1)
        Editing.new(@documents[uri].to_s).symbols.map do |name, kind, line|
          range = { start: { line: line, character: 0 },
                    end: { line: line, character: Text.length(lines[line].to_s, @encoding) } }
          { name: name, kind: kind, range: range, selectionRange: range }
        end
      end

      def editing(params)
        Editing.new(@documents[params["textDocument"]["uri"]].to_s)
      end

      def lines_of(params)
        @documents[params["textDocument"]["uri"]].to_s.split("\n", -1)
      end

      # The position as [line, byte column], or nil for a document that is
      # not open.
      def position(params)
        return nil unless @documents.key?(params["textDocument"]["uri"])

        line = params["position"]["line"].to_i
        [line, Text.byte_column(lines_of(params)[line].to_s, params["position"]["character"].to_i, @encoding)]
      end

      # A byte offset in line, in the client's units.
      def unit_column(line, offset)
        Text.length(line.byteslice(0, offset).to_s, @encoding)
      end

      def read(file)
        File.file?(file) ? File.read(file) : ""
      end

      # Runs a check with stdout taken away, so a recipe's puts cannot
      # break the protocol.
      def quietly
        saved = $stdout
        $stdout = Sink.new
        yield
      ensure
        $stdout = saved
      end

      def respond(id, result)
        @connection.write({ jsonrpc: "2.0", id: id, result: result })
      end

      def reply_error(id, code, message)
        @connection.write({ jsonrpc: "2.0", id: id, error: { code: code, message: message } })
      end

      def log(message)
        @connection.write({ jsonrpc: "2.0", method: "window/logMessage",
                            params: { type: MESSAGE_ERROR, message: message } })
      end
    end
  end
end
