#!/usr/bin/env ruby
# island-borders.rb — post-process an Astromapper SVG: find clusters of systems
# ("islands") and draw a border around each one along the hex grid lines.
#
#   ruby island-borders.rb path/to/sector.svg [jump=2] [min_size=2] [opacity=0.85]
#
# Reads the SVG, computes the borders, and writes them back into the same file
# (idempotent — re-running replaces the previous borders). Self-contained: needs
# only the SVG, which carries each system's hex via a `<!-- Volume: NNNN ... -->`
# comment.
#
# The clustering/geometry lives in lib/astromapper/islands.rb so this tool and
# the SVG generator stay in sync; this script is just SVG I/O around it.

require_relative '../lib/astromapper/islands'

SIDE   = 40.0
FACTOR = 1.732   # must match svg.rb's @factor so borders align with the hexes

svg_path = ARGV[0] or abort "usage: ruby island-borders.rb <sector.svg> [jump=2] [min_size=2] [opacity=0.85]"
threshold = (ARGV[1] || 2).to_i      # systems within this many jumps are one island
min_size  = (ARGV[2] || 2).to_i      # only border clusters of at least this many systems
opacity   = (ARGV[3] || 0.85).to_f   # border opacity, 0.0 (invisible) to 1.0 (solid)

svg = File.read(svg_path)
hexes = svg.scan(/<!-- Volume:\s+(\d{2})(\d{2})/).map { |c, r| [c.to_i, r.to_i] }.uniq
abort "no systems found in #{svg_path}" if hexes.empty?

groups = Astromapper::Islands.borders(hexes, side: SIDE, factor: FACTOR,
                                      threshold: threshold, min_size: min_size)

# --- emit the SVG group (strip any previous run first) ---
svg = svg.sub(%r{\n?<g class='islands'[^>]*>.*?</g><!--/islands-->}m, '')
lines = groups.map do |colour, loops, size|
  body = loops.map { |ring|
    pts = ring.map { |x, y| "#{x},#{y}" }.join(' ')
    "<polygon points='#{pts}' stroke='#{colour}' fill='none' stroke-width='6' stroke-linejoin='round' style='opacity:#{opacity}'/>" }.join
  "<g><!--island n=#{size}-->#{body}</g>"
end.join("\n")
block = "\n<g class='islands'>\n#{lines}\n</g><!--/islands-->"
svg = svg.sub(%r{(\s*</svg>)}, "#{block}\\1")

File.write(svg_path, svg)
puts "#{hexes.size} systems -> #{groups.size} islands (jump<=#{threshold}, size>=#{min_size}); borders written to #{svg_path}"
groups.sort_by { |_, _, size| -size }.each_with_index { |(_, _, size), i| puts "  island #{i + 1}: #{size} systems" }
