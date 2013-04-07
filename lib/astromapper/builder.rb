require 'open3'

module Astromapper
  module Builder
    autoload :Sector  , "astromapper/builder/sector"

    class Base
      attr_accessor :root_dir
      def initialize(root_dir)
        @root_dir = Pathname.new(root_dir)
      end
      def config
        Astromapper.config(root_dir)
      end
      def showme
        puts 'test'
      end

      def build(root_dir)
        new(root_dir).build
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