module Astromapper
  module Builder
    autoload :SECTOR  , "bookmaker/parser/sector"

    class Base
      # The e-book directory.
      #
      attr_accessor :root_dir

      # Where the text files are stored.
      #
      attr_accessor :source

      def self.parse(root_dir)
        new(root_dir).parse
      end

      def initialize(root_dir)
        @root_dir = Pathname.new(root_dir)
        @source = root_dir.join("text")
      end

      # Return directory's basename.
      #
      def name
        File.basename(root_dir)
      end

      # Return the configuration file.
      #
      def config
        Astromapper.config(root_dir)
      end


      end
      def spawn_command(cmd)
        begin
          stdout_and_stderr, status = Open3.capture2e(*cmd)
        rescue Errno::ENOENT => e
          puts e.message
        else
          puts stdout_and_stderr unless status.success?
          status.success?
        end
      end
    end
  end
end