
# require "awesome_print"
require "active_support/all"
# require "notifier"
require "pathname"
require "thor"
require "thor/group"
require "yaml"

module Astromapper
  autoload :Cli,        "astromapper/cli"
  # autoload :Dependency, "astromapper/dependency"
  autoload :Exporter,   "astromapper/exporter"
  autoload :Generator,  "astromapper/generator"
  autoload :Builder,     "astromapper/builder"
  # autoload :Stats,      "astromapper/stats"
  # autoload :Stream,     "astromapper/stream"
  # autoload :TOC,        "astromapper/toc"
  autoload :Version,    "astromapper/version"

	Encoding.default_internal = "utf-8"
	Encoding.default_external = "utf-8"
  def self.config(root_dir = nil)
    root_dir ||= Pathname.new(Dir.pwd)
    path = root_dir.join("_astromapper.yml")

    raise "Invalid Bookmaker directory; couldn't found #{path} file." unless File.file?(path)
    content = File.read(path)
    erb = ERB.new(content).result

    YAML.load(erb)#.with_indifferent_access
  end
  def self.logger
     @logger ||= Logger.new(File.open("/tmp/astromapper.log", "a"))
  end
end
