# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'astromapper/version'

Gem::Specification.new do |s|
  s.name          = "astromapper"
  s.version       = Astromapper::VERSION
  s.authors       = ["Merovex"]
  s.email         = ["dausha@gmail.com"]
  s.description   = %q{Astromapper generates Traveller RPG Star Charts (from Sector to Domain).}
  s.summary       = %q{Generating Traveller RPG Star Charts for YOTS}
  s.homepage      = ""
  s.license       = "MIT"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 2.6"
  s.add_development_dependency "cucumber"
  s.add_development_dependency "aruba"
  s.add_dependency "activesupport"
  s.add_dependency "thor"
end
