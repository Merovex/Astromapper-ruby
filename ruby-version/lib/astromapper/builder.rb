require 'open3'

module Astromapper
  module Builder
    autoload :Orbit,  "astromapper/builder/orbit"
    autoload :Sector, "astromapper/builder/sector"
    autoload :Star,   "astromapper/builder/star"
    autoload :Volume, "astromapper/builder/volume"

    class Base
      attr_accessor :root_dir

      def self.constitute(root_dir)
        new(root_dir).constitute
      end
      def initialize(root_dir)
        @root_dir = Pathname.new(root_dir)
      end

      def config
        Astromapper.config(root_dir)
      end
      def toss(a=2,b=2)
        (a.d6 - b).whole
        # (@@dice.roll(a) - b).whole
      end
      def names
        Astromapper.names
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
