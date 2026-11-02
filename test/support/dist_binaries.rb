# frozen_string_literal: true

# Makes sure a binary in dist/ was built from the source as it is now. The
# integration tests run the binaries in dist/, and dist/ is not under
# version control: a binary left there by an earlier build would test old
# code while the run reports success.
#
# Development tooling: CRuby only.
module DistBinaries
  ROOT = File.expand_path("../..", __dir__)
  # Everything a binary is built from.
  # (Not build_config.rb.lock: every build rewrites it.)
  SOURCES = ["lib/**/*.rb", "tools/sadame/**/*", "mrbgem.rake", "build_config.rb"].freeze
  BUILD_TASKS = {
    "sadame-linux-amd64" => "build:linux-amd64", "sadame-linux-arm64" => "build:linux-arm64",
    "sadame-darwin-arm64" => "build:macos", "sadame-darwin-amd64" => "build:macos"
  }.freeze

  module_function

  # Aborts, naming the build task, when dist/NAME is missing or older than
  # a file it is built from.
  def check!(*names)
    stale = names.reject { |name| fresh?(name) }
    return if stale.empty?

    tasks = stale.map { |name| BUILD_TASKS.fetch(name) }.uniq
    abort "#{stale.map { |name| "dist/#{name}" }.join(", ")} #{stale.size == 1 ? "is" : "are"} missing or older " \
          "than the source (newest: #{newest_source.delete_prefix("#{ROOT}/")}); rebuild with: rake #{tasks.join(" ")}"
  end

  # In GitHub Actions the binaries are built from the same commit earlier in
  # the run and downloaded as artifacts, whose file times say nothing about
  # the source; there, being there is enough.
  def fresh?(name)
    path = File.join(ROOT, "dist", name)
    return false unless File.exist?(path)

    ENV["GITHUB_ACTIONS"] == "true" || File.mtime(path) >= File.mtime(newest_source)
  end

  def newest_source
    @newest_source ||= SOURCES.flat_map { |pattern| Dir.glob(File.join(ROOT, pattern)) }
                              .select { |path| File.file?(path) }
                              .max_by { |path| File.mtime(path) }
  end
end
