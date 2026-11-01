# frozen_string_literal: true

module Sadame
  # Keeps a git checkout at a revision: a branch, a tag or a commit.
  #
  #   git "/srv/app", repository: "https://github.com/example/app.git", revision: "v1.4.2"
  #   git "/srv/app", repository: "git@github.com:example/app.git", revision: "main", user: "deploy"
  #
  # The checkout is a clone of repository: with the commit that revision:
  # names checked out (a detached HEAD). For a branch, that is the branch's
  # latest commit on the remote, so every plan asks the remote (git
  # ls-remote) and apply moves the checkout when the branch has moved.
  # Without revision:, the remote's default branch is used. Local changes
  # to tracked files are discarded when the checkout moves.
  #
  # With user:, every git command runs as that user (through su), so the
  # files belong to them and their SSH keys and git configuration apply.
  # git must be installed; declare package "git" before.
  class GitResource < Resource
    STATES = %w[present absent].freeze
    COMMIT_LENGTH = 40
    HEX_DIGITS = "0123456789abcdef"

    def self.type_name
      "git"
    end

    def self.allowed_options
      [:repository, :revision, :user, :state]
    end

    def path
      name
    end

    def revision
      (options[:revision] || "HEAD").to_s
    end

    def desired
      return { state: "absent" } if absent?

      { state: "present", repository: options[:repository], revision: remote_commit || revision }
    end

    def current
      return { state: "absent" } unless checkout_exists?
      return { state: "present" } if absent?

      {
        state: "present",
        repository: git("-C #{quote(path)} config --get remote.origin.url").stdout.strip,
        revision: git("-C #{quote(path)} rev-parse HEAD").stdout.strip
      }
    end

    # The changes come from a diff made right before, with git installed,
    # so a revision change names a commit.
    def apply(changes)
      if absent?
        shell.run!("rm -rf #{quote(path)}")
        return
      end

      require_git
      if changed?(changes, :state)
        git!("clone --quiet --no-checkout #{quote(options[:repository])} #{quote(path)}")
      else
        if changed?(changes, :repository)
          git!("-C #{quote(path)} remote set-url origin #{quote(options[:repository])}")
        end
        git!("-C #{quote(path)} fetch --quiet --tags origin")
      end
      commit = changes.find { |change| change.attribute == :revision }&.to
      git!("-C #{quote(path)} checkout --quiet --force --detach #{quote(commit)}") if commit
    end

    private

    def validate
      validate_choice(:state, STATES)
      [:repository, :revision, :user].each do |key|
        value = options[key]
        next if value.nil? || (value.is_a?(String) && !value.empty?)

        raise ResourceError, "#{id}: #{key} must be a non-empty String"
      end
      return if absent? || options[:repository]

      raise ResourceError, "#{id}: repository: is required, such as repository: \"https://github.com/example/app.git\""
    end

    def absent?
      options[:state].to_s == "absent"
    end

    # A directory with a .git directory is a checkout; a missing path or an
    # empty directory is where one can be cloned; anything else is an error.
    def checkout_exists?
      stat = PathStat.read(shell, path, host.platform)
      return false if stat.nil?
      unless stat.directory?
        raise ResourceError, "#{id}: #{path} is a #{stat.type_label}, not a git checkout"
      end
      return true if shell.run("test -d #{quote(File.join(path, ".git"))}").success?
      return false if shell.run!("ls -A #{quote(path)}").stdout.strip.empty?

      raise ResourceError, "#{id}: #{path} is a directory with files in it, but not a git checkout"
    end

    # The commit revision names on the remote, or nil when git is not
    # installed yet: a plan on a fresh machine then shows the revision as
    # written, and apply, which runs after the package is installed,
    # resolves it.
    def remote_commit
      return revision if commit?(revision)
      return nil unless shell.run("command -v git").success?

      refs = remote_refs
      commit = ref_candidates.map { |ref| refs[ref] }.compact.first
      return commit if commit

      raise ResourceError, "#{id}: #{options[:repository]} has no branch or tag named #{revision}"
    end

    # Tags first, peeled to their commit, then branches, as git itself
    # resolves a name.
    def ref_candidates
      return ["HEAD"] if revision == "HEAD"

      ["refs/tags/#{revision}^{}", "refs/tags/#{revision}", "refs/heads/#{revision}"]
    end

    def remote_refs
      patterns = ref_candidates.map { |ref| quote(ref) }.join(" ")
      result = git("ls-remote #{quote(options[:repository])} #{patterns}")
      unless result.success?
        raise ResourceError, "#{id}: cannot read #{options[:repository]}: #{CommandFailed.describe(result)}"
      end

      refs = {}
      result.stdout.split("\n").each do |entry|
        commit, ref = entry.split("\t", 2)
        refs[ref.strip] = commit if ref
      end
      refs
    end

    def require_git
      return if shell.run("command -v git").success?

      raise ResourceError, "#{id}: git is not installed (declare package \"git\" before this resource)"
    end

    def commit?(text)
      text.size == COMMIT_LENGTH && text.chars.all? { |char| HEX_DIGITS.include?(char) }
    end

    def git(arguments)
      shell.run(command_line(arguments))
    end

    def git!(arguments)
      shell.run!(command_line(arguments))
    end

    # Never prompts for credentials: there is nobody to answer. As root, a
    # checkout that belongs to another user is still trusted.
    def command_line(arguments)
      if options[:user]
        inner = "cd / && GIT_TERMINAL_PROMPT=0 git #{arguments}"
        "su -s /bin/sh #{quote(options[:user])} -c #{quote(inner)}"
      else
        "GIT_TERMINAL_PROMPT=0 git -c safe.directory=#{quote(path)} #{arguments}"
      end
    end
  end
end
