
# require "awesome_print"
require "active_support/all"
# require "notifier"
require "pathname"
require "thor"
require "thor/group"
require "yaml"

module Astromapper
  require 'astromapper/extensions/float'
  require 'astromapper/extensions/integer'
  require 'astromapper/extensions/string'
  require 'astromapper/extensions/array'


  autoload :Version,     "astromapper/version"
  autoload :Builder,     "astromapper/builder"
  autoload :Seed,        "astromapper/seed"
  autoload :Cli,         "astromapper/cli"
  # autoload :Dependency, "astromapper/dependency"
  autoload :Exporter,    "astromapper/exporter"
  autoload :Generator,   "astromapper/generator"
  # autoload :Stats,      "astromapper/stats"
  # autoload :Stream,     "astromapper/stream"
  # autoload :TOC,        "astromapper/toc"
  autoload :Svg,         "astromapper/svg"

	Encoding.default_internal = "utf-8"
	Encoding.default_external = "utf-8"
  def self.config(root_dir = nil)
    root_dir ||= Pathname.new(Dir.pwd)
    path = root_dir.join("_astromapper.yml")

    raise "Not an Astromapper project: #{path} not found. Run `astromapper new <name>` first." unless File.file?(path)
    content = File.read(path)
    erb = ERB.new(content).result

    # unsafe_load restores the pre-Psych-4 default so trusted local config may
    # use Ruby-specific tags such as `!ruby/range`.
    YAML.unsafe_load(erb).to_hash.with_indifferent_access
  end
  def self.output_file(ext="txt")
    "output/#{config['name'].to_permalink}.#{ext}"
  end
  def self.names(root_dir = nil)
    root_dir ||= Pathname.new(Dir.pwd)
    path = root_dir.join("templates/names.yml")

    raise "Missing #{path}. Run `astromapper new <name>` to scaffold a project." unless File.file?(path)
    content = File.read(path)
    erb = ERB.new(content).result

    @names = YAML.unsafe_load(erb)
  end
  def self.logger
     @logger ||= Logger.new(File.open("/tmp/astromapper.log", "a"))
  end
end
