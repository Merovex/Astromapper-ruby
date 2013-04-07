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
    
    desc "version", "Prints the Astromapper's version information"
    map %w(-v --version) => :version
    def version
      say "Astromapper version #{Astromapper::VERSION}"
    end
    
    private
      def config
        YAML.load_file(config_path).with_indifferent_access
      end
  end
end