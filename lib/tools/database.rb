module Tools
  class Database
    def initialize(configuration)
      @configuration = configuration
    end

    # Backup the database and save it on the backup folder set in the
    # configuration.
    # If you need to make the command more verbose, pass
    # `debug: true` in the arguments of the function.
    #
    # Return the full path of the backup file created in the disk.
    def dump(debug: false)
      full_path = [
        "#{backup_folder}/#{Time.current.strftime('%Y%m%d%H%M%S')}",
        file_suffix,
        '.sql'
      ].join

      cmd = "PGPASSWORD='#{password}' pg_dump -F p -v -O -U '#{user}' -h '#{host}' -d '#{database}' -f '#{full_path}' -p '#{port}' "
      debug ? system(cmd) : system(cmd, err: File::NULL)

      full_path
    end

    # Drop the database and recreate it.
    #
    # This is done by invoking two Active Record's rake tasks:
    #
    # * rake db:drop
    # * rake db:create
    def reset
      Rake::Task['db:drop'].invoke
      Rake::Task['db:create'].invoke
    end

    # Restore the database from a file in the file system.
    #
    # If you need to make the command more verbose, pass
    # `debug: true` in the arguments of the function.
    def restore(file_name, debug: false)
      full_path = "#{backup_folder}/#{file_name}",
      cmd = "PGPASSWORD='#{password}' psql -U '#{user}' -h '#{host}' -d '#{database}' -f '#{full_path}' -p '#{port}'"
      debug ? system(cmd) : system(cmd, err: File::NULL)
    end

    # List all backup files from the local backup folder.
    #
    # Return a list of strings containing only the file names.
    def list_files
      Dir.glob("#{backup_folder}/*.sql")
        .reject { |f| File.directory?(f) }
        .map { |f| Pathname.new(f).basename }
    end

    private

    attr_reader :configuration

    def host
      @host ||= ActiveRecord::Base.connection_config[:host]
    end

    def port
      @port ||= ActiveRecord::Base.connection_config[:port]
    end

    def database
      @database ||= ActiveRecord::Base.connection_config[:database]
    end

    def user
      ActiveRecord::Base.connection_config[:username]
    end

    def password
      @password ||= ActiveRecord::Base.connection_config[:password]
    end

    def file_suffix
      return if configuration.file_suffix.empty?
      @file_suffix ||= "_#{configuration.file_suffix}"
    end

    def backup_folder
      @backup_folder ||= begin
        File.join(Rails.root, configuration.backup_folder).tap do |folder|
          FileUtils.mkdir_p(folder)
        end
      end
    end
  end
end
