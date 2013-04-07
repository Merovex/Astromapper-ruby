
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
  # autoload :Markdown,   "astromapper/adapters/markdown"
  autoload :Builder,     "astromapper/builder"
  # autoload :Stats,      "astromapper/stats"
  # autoload :Stream,     "astromapper/stream"
  # autoload :TOC,        "astromapper/toc"
  autoload :Version,    "astromapper/version"

	Encoding.default_internal = "utf-8"
	Encoding.default_external = "utf-8"
  # Your code goes here...
  def self.logger
     @logger ||= Logger.new(File.open("/tmp/astromapper.log", "a"))
  end
end
