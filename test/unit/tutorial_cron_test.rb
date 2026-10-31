# frozen_string_literal: true

# The cron resource built step by step in docs/contributing/architecture.md.
# The page embeds the sections between the --8<-- markers, so the tutorial's
# code is compiled and tested on CRuby and mruby like the real resources.
# It lives here, not in lib/, because sadame does not ship a cron resource.
module Tutorial
  # --8<-- [start:resource]
  # Manages one cron job as a file in /etc/cron.d.
  #
  #   cron "backup", schedule: "0 3 * * *", command: "/usr/local/bin/backup"
  class CronResource < Sadame::Resource
    STATES = %w[present absent].freeze
    NAME_CHARACTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    def self.type_name
      "cron"
    end

    def self.allowed_options
      [:schedule, :command, :user, :state]
    end

    def path
      "/etc/cron.d/#{name}"
    end

    def desired
      return { state: "absent" } if absent?

      { state: "present", content: "#{options[:schedule]} #{user} #{options[:command]}\n" }
    end

    def current
      content = shell.read_file(path)
      return { state: "absent" } if content.nil?

      { state: "present", content: content }
    end

    def apply(_changes)
      if absent?
        shell.run!("rm -f #{quote(path)}")
      else
        shell.write_file(path, desired[:content])
        shell.run!("chmod 0644 #{quote(path)}")
      end
    end

    private

    def validate
      validate_choice(:state, STATES)
      unless name.chars.all? { |char| NAME_CHARACTERS.include?(char) }
        raise Sadame::ResourceError, "#{id}: cron.d file names may only use letters, digits, - and _"
      end
      return if absent?

      [:schedule, :command].each do |key|
        raise Sadame::ResourceError, "#{id}: #{key} is required" unless options[key].is_a?(String)
      end
      return if options[:schedule].split(" ").size == 5

      raise Sadame::ResourceError, "#{id}: schedule needs five fields, such as \"0 3 * * *\""
    end

    def absent?
      options[:state].to_s == "absent"
    end

    def user
      options[:user] || "root"
    end
  end
  # --8<-- [end:resource]

  # --8<-- [start:recipe]
  # In lib/sadame/recipe.rb this is one more method of Sadame::Recipe; the
  # tutorial adds it in a subclass to keep the real DSL unchanged.
  class Recipe < Sadame::Recipe
    def cron(name, options = {})
      declare(CronResource, name, options)
    end
  end
  # --8<-- [end:recipe]
end

class TutorialCronTest < SadameTest
  # --8<-- [start:tests]
  def cron(options, shell)
    build_resource(Tutorial::CronResource, "backup", options, shell: shell)
  end

  def test_creates_a_missing_job
    shell = linux_shell
    job = cron({ schedule: "0 3 * * *", command: "/usr/local/bin/backup" }, shell)
    changes = job.diff
    assert_equal :create, job.plan_action(changes)

    job.apply(changes)
    assert_equal "0 3 * * * root /usr/local/bin/backup\n", shell.files["/etc/cron.d/backup"]
    assert_equal "chmod 0644 /etc/cron.d/backup", shell.commands.last
  end

  def test_matching_job_has_no_changes
    shell = linux_shell
    shell.files["/etc/cron.d/backup"] = "0 3 * * * root /usr/local/bin/backup\n"
    assert_empty cron({ schedule: "0 3 * * *", command: "/usr/local/bin/backup" }, shell).diff
  end

  def test_changed_schedule_is_an_update
    shell = linux_shell
    shell.files["/etc/cron.d/backup"] = "0 3 * * * root /usr/local/bin/backup\n"
    job = cron({ schedule: "30 4 * * *", command: "/usr/local/bin/backup" }, shell)
    changes = job.diff
    assert_equal :update, job.plan_action(changes)
    assert_equal [:content], change_attributes(changes)
  end

  def test_removes_a_job
    shell = linux_shell
    shell.files["/etc/cron.d/backup"] = "0 3 * * * root /usr/local/bin/backup\n"
    job = cron({ state: :absent }, shell)
    job.apply(job.diff)
    assert_equal "rm -f /etc/cron.d/backup", shell.commands.last
  end

  def test_validation
    error = assert_raises(Sadame::ResourceError) { cron({ schedule: "daily", command: "x" }, linux_shell) }
    assert_includes error.message, "schedule needs five fields"
    error = assert_raises(Sadame::ResourceError) { cron({ schedule: "0 3 * * *" }, linux_shell) }
    assert_includes error.message, "command is required"
  end
  # --8<-- [end:tests]

  def test_recipes_can_declare_it
    resources = Tutorial::Recipe.load("test/fixtures/recipes/tutorial_cron/recipe.rb", host: host_for(linux_shell), vars: {})
    assert_equal ["cron[backup]", "cron[cleanup]"], resources.to_a.map { |resource| resource.id }
    assert_equal "*/15 * * * * app find /tmp/app -mtime +1 -delete\n", resources.find("cron[cleanup]").desired[:content]
  end
end
