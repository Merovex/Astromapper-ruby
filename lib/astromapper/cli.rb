# -*- encoding: utf-8 -*-
require 'thor'
require 'Astromapper/version'
module Astromapper
  class Cli < Thor
    FORMATS = %w[pdf draft proof html epub mobi txt]
    check_unknown_options!
    
    def self.exit_on_failure?
      true
    end
    def initialize(args = [], options = {}, config = {})
      # if (config[:current_task] || config[:current_command]).name == "new" && args.empty?
      #   raise Error, "The e-Book path is required. For details run: Astromapper help new"
      # end
      super
    end

    desc "create", "Create Astromapper Directory"
    map %w(-c --create) => :create
    def create(path)
      say "Voices of billions cry out in terror at the creation of '#{path}'"
      generator = Generator.new
      generator.destination_root = path.squish.gsub(' ','-')
      generator.invoke_all
    end

    desc "build", "Generate a map of {sector / domain}"
    map %w{-b --build generate} => :build
    def build(type='sector')
      say "Building #{type}: #{config['name'].inspect}"
      Astromapper::Exporter.run(root_dir, options)
    end

    desc "svg", "Convert ASCII output to SVG"
    map %w{-s --svg} => :svg
    def svg
      source = Astromapper.output_file('sector')
      say "Converting #{source} to SVG"
      s = Svg.new(source)
      s.convert
      say "SVG available at #{Astromapper.output_file('svg')}"
    end
    
    desc "version", "Prints the Astromapper's version information"
    map %w(-v --version) => :version
    def version
      say "Astromapper version #{Astromapper::VERSION}"
    end
    
    private
      def config
        # YAML.load_file(config_path).with_indifferent_access
        Astromapper.config
      end
      def root_dir
        @root ||= Pathname.new(Dir.pwd)
      end
  end
end