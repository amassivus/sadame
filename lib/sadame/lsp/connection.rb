# frozen_string_literal: true

module Sadame
  module Lsp
    # JSON-RPC messages over a pair of streams, each preceded by a
    # Content-Length header, as the Language Server Protocol frames them.
    class Connection
      def initialize(input, output)
        @input = input
        @output = output
      end

      # The next message as a Hash, or nil at the end of the input.
      def read
        length = nil
        loop do
          line = @input.gets
          return nil if line.nil?

          line = line.chomp
          break if line.empty? && length

          name, value = line.split(":", 2)
          length = value.to_s.strip.to_i if name.to_s.downcase == "content-length"
        end
        JSON.parse(read_bytes(length))
      end

      def write(message)
        body = JsonWriter.generate(message)
        @output.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
        @output.flush if @output.respond_to?(:flush)
      end

      private

      def read_bytes(length)
        data = String.new
        while data.bytesize < length
          chunk = @input.read(length - data.bytesize)
          break if chunk.nil? || chunk.empty?

          data << chunk
        end
        data
      end
    end

    # Paths, URIs and positions. Positions count UTF-16 code units unless
    # the client agreed to UTF-8, where they count bytes; sadame works in
    # bytes.
    module Text
      URI_SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/-._~"
      HEX = "0123456789abcdefABCDEF"

      def self.path(uri)
        text = uri.to_s.start_with?("file://") ? uri.to_s[7..] : uri.to_s
        bytes = text.bytes
        decoded = String.new
        index = 0
        while index < bytes.size
          pair = text.byteslice(index + 1, 2).to_s
          if bytes[index] == 37 && hex?(pair)
            decoded << pair.to_i(16).chr
            index += 3
          else
            decoded << bytes[index].chr
            index += 1
          end
        end
        decoded.respond_to?(:force_encoding) ? decoded.force_encoding("UTF-8") : decoded
      end

      def self.uri(path)
        encoded = path.bytes.map do |byte|
          character = byte.chr
          URI_SAFE.include?(character) && byte < 128 ? character : format("%%%02X", byte)
        end
        "file://#{encoded.join}"
      end

      def self.hex?(text)
        text.size == 2 && text.chars.all? { |character| HEX.include?(character) }
      end

      # The byte offset of position character in line.
      def self.byte_column(line, character, encoding)
        return [character, line.bytesize].min if encoding == "utf-8"

        bytes = line.bytes
        index = 0
        units = 0
        while index < bytes.size && units < character
          length = sequence_length(bytes[index])
          units += length == 4 ? 2 : 1
          index += length
        end
        index
      end

      # The length of line in the units positions are counted in.
      def self.length(line, encoding)
        return line.bytesize if encoding == "utf-8"

        bytes = line.bytes
        index = 0
        units = 0
        while index < bytes.size
          length = sequence_length(bytes[index])
          units += length == 4 ? 2 : 1
          index += length
        end
        units
      end

      def self.sequence_length(byte)
        return 1 if byte < 0xC0
        return 2 if byte < 0xE0
        return 3 if byte < 0xF0

        4
      end
    end
  end
end
