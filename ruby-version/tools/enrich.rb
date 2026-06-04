#!/usr/bin/env ruby
# enrich.rb — add the Ruby T5 features to a (Go-format) Converted-Sector JSON
# WITHOUT recalculating from a seed. Keeps every existing fixed value (UWP, stars,
# orbits, factions, temperature) and layers on, computed from those values via the
# real Ruby rules:
#   * full T5 trade codes        (deterministic from the UWP — exact)
#   * Ix / Ex / Cx / RU          (Ix deterministic; Ex/Cx random terms rolled fresh)
#   * native status              (deterministic)
#   * moons on worlds & gas giants (rolled fresh — never existed in this export)
#
#   ruby tools/enrich.rb input.json [output.json]
#
# It drives the actual lib classes (Astromapper::Builder::World / Moon): a World is
# allocated and its ivars set to the existing values, then build_extensions/
# trade_codes run; moons use the real Moon constructor with a planet stub. So the
# rules are the Ruby rules, not a re-port.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require 'json'
require 'astromapper'
require 'astromapper/builder/orbit'   # ensure World/Moon are loaded (not just autoloaded)

# Config injection (same trick as the test suite): generation reads only
# Astromapper.config, so overriding it drives the rules. Genre is irrelevant here
# (we overwrite the UWP ivars), sophonts:human gives Settled/Colony native status.
module Astromapper
  class << self
    attr_writer :enrich_config
    def config(_ = nil); (@enrich_config || {}).with_indifferent_access; end
  end
end
Astromapper.enrich_config = { "genre" => "normal", "sophonts" => "human", "always_inhabited" => true }

# The original seed is gone, so the fresh rolls (Ex/Cx random terms, moons) can't be
# reproduced — but we fix a seed here so THIS enrichment is at least reproducible
# (same input -> same output). Override with ENRICH_SEED if you want a different draw.
srand(Integer(ENV["ENRICH_SEED"] || 20260604))

W    = Astromapper::Builder::World
MOON = Astromapper::Builder::Moon
BIOZONE = Astromapper::Builder::Star::BIOZONE
# port letter -> a @port_roll that maps back to it (port = %w{A A A A A B B C C D E E X}[roll])
PORT_ROLL = { "A" => 0, "B" => 5, "C" => 7, "D" => 9, "E" => 10, "X" => 12 }.freeze

def base_hash(bases)
  b = bases.to_s
  { "Naval" => b.include?("N") ? "N" : ".", "Scout" => b.include?("S") ? "S" : ".",
    "Depot" => b.include?("D") ? "D" : ".", "Way" => b.include?("W") ? "W" : "." }
end

# Zone of an orbit (inner -1 / biozone 0 / outer 1) from its AU vs the star biozone.
def orbit_zone(au, type, size)
  bz = BIOZONE[type] && BIOZONE[type][size % 10]
  return -1 if bz.nil? || bz.empty?
  return -1 if au < bz[0]
  return  1 if au > bz[1]
  0
end

# A stand-in planet for Moon.new — Moon only reads xsize/size/inner?/outer?/biozone?.
def planet_stub(xsize, size, zone)
  p = Object.new
  p.define_singleton_method(:xsize) { xsize }
  p.define_singleton_method(:size)  { size }
  p.define_singleton_method(:inner?)   { zone < 0 }
  p.define_singleton_method(:outer?)   { zone > 0 }
  p.define_singleton_method(:biozone?) { zone == 0 }
  p
end

def moon_json(m, i)
  { "orbit" => i, "orbital_radius" => m.orbit, "size" => m.size,
    "atmosphere" => m.instance_variable_get(:@atmo), "hydrographics" => m.h20 }
end

# Roll moons for one orbit body, returning JSON moon hashes (or nil if none).
def roll_moons(otype, size, zone)
  case otype
  when "world", "hostile", "rockball"
    count = (1.d6 - 3)            # toss(1,3); whole handled by negative -> no moons
    count = 0 if count < 0
    stub = planet_stub(".", size.to_i, zone)
    count.times.map { |i| moon_json(MOON.new(stub, i), i) }
  when "gas_giant"
    xsize = (1.d6 < 4) ? "L" : "S"
    count = 2.d6                  # toss(2,0)
    count = [count - 4, 0].max if xsize == "S"
    stub = planet_stub(xsize, 0, zone)
    count.times.map { |i| moon_json(MOON.new(stub, i), i) }
  end
end

input  = ARGV[0] or abort "usage: ruby tools/enrich.rb input.json [output.json]"
output = ARGV[1] || input.sub(/\.json$/i, '') + "-t5.json"
doc = JSON.parse(File.read(input, encoding: "utf-8"))

doc["volumes"].each_value do |v|
  s = v["star"]; w = s["world"]
  orbits = s["orbits"] || []
  gg    = orbits.count { |o| o["type"] == "gas_giant" }
  belts = orbits.count { |o| o["type"] == "belt" }

  # --- extensions + full T5 trade codes via the real World rules ---
  world = W.allocate
  { "@size" => w["size"], "@atmo" => w["atmosphere"], "@h20" => w["hydrographics"],
    "@popx" => w["population"], "@govm" => w["government"], "@law" => w["law_level"],
    "@tek" => w["tech_level"], "@temp" => w["temperature"], "@orbit_number" => w["orbit_number"],
    "@port_roll" => (PORT_ROLL[w["starport"]] || 12), "@base" => base_hash(w["bases"]) }
    .each { |k, val| world.instance_variable_set(k, val) }
  world.build_extensions(gg, belts)

  w["trade_codes"] = world.trade_codes
  w["ix"] = world.ix
  w["ex"] = world.ex.transform_keys(&:to_s)
  w["cx"] = world.cx.transform_keys(&:to_s)
  w["ru"] = world.ru
  w["native"] = world.native

  # --- moons on every world/gas-giant orbit ---
  orbits.each do |o|
    d = o["data"]
    zone = orbit_zone(d["au"].to_f, s["star_type"], s["star_size"].to_i)
    moons = roll_moons(o["type"], d["size"], zone)
    d["moons"] = moons if moons && !moons.empty?
  end
end

File.write(output, JSON.pretty_generate(doc))
puts "wrote #{output}  (#{doc['volumes'].size} systems enriched)"
