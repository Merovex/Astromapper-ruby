#!/usr/bin/env ruby
# sector2svg.rb — render an SVG map from a T5 Second Survey TAB-delimited sector
# file (TravellerMap standard), reusing the production Astromapper::Svg renderer
# (hex grid, worlds, starports, stars, bases, gas giants, jump routes, islands).
#
#   ruby tools/sector2svg.rb input.tab [output.svg]
#
# Reads the named tab columns it needs (Hex, UWP, Bases, Zone, PBG, Stars, Name),
# converts each to the Ruby tab-format line the renderer parses, and runs convert.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require 'tempfile'
require 'astromapper'

# Base/feature glyph string: scouts/naval/depot/way from Bases, gas giant from PBG.
def nsg(bases, has_gg)
  s = +""
  s << "N" if bases.include?("N")
  s << "S" if bases.include?("S")
  s << "G" if has_gg
  s << "D" if bases.include?("D")
  s << "W" if bases.include?("W")
  s.empty? ? "." : s
end

input  = ARGV[0] or abort "usage: ruby tools/sector2svg.rb input.tab [output.svg]"
output = ARGV[1] || input.sub(/\.tab$|\.sector\.txt$|\.txt$/i, '') + ".svg"
rows = File.readlines(input, encoding: "utf-8").reject { |l| l.strip.empty? || l.start_with?("#") }
header = rows.shift.chomp.split("\t")
col = header.each_with_index.to_h
abort "not a T5SS tab file (no Hex/UWP columns)" unless col["Hex"] && col["UWP"]

name = (rows.first && rows.first.split("\t")[col["Sector"] || -1]).to_s.strip
name = "Sector" if name.empty?

lines = rows.map do |line|
  f = line.chomp.split("\t")
  hex   = f[col["Hex"]].to_s.strip
  uwp   = f[col["UWP"]].to_s.strip
  bases = f[col["Bases"]].to_s.strip
  pbg   = f[col["PBG"]].to_s.strip
  zone  = f[col["Zone"]].to_s.strip
  stars = f[col["Stars"]].to_s.strip
  nm    = f[col["Name"]].to_s.strip
  has_gg = pbg.length >= 3 && pbg[2] != "0"
  tz = { "A" => "AZ", "R" => "RZ" }[zone] || ".."
  details = "%s %s %s %s %s" % [hex, uwp, "T", nsg(bases, has_gg), tz]   # T = climate placeholder (not rendered)
  "%s\t\t\t%s\t%s" % [details, stars, nm]
end

# Config injection: the renderer reads only name + island settings from config.
module Astromapper
  class << self
    attr_writer :svg_config
    def config(_ = nil); (@svg_config || {}).with_indifferent_access; end
  end
end
Astromapper.svg_config = { "name" => name, "islands" => true,
                           "island_jump" => 2, "island_min" => 2, "island_opacity" => 0.85 }
srand(0)   # stable belt jitter

tmp = Tempfile.new(["sector", ".sector"])
tmp.write("# rendered from #{File.basename(input)}\n" + lines.join("\n") + "\n")
tmp.close

svg = Astromapper::Svg.new(tmp.path)
svg.instance_variable_set(:@svg_filename, output)
svg.convert
tmp.unlink
puts "wrote #{output}  (#{lines.size} systems)"
