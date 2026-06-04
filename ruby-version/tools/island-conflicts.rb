#!/usr/bin/env ruby
# island-conflicts.rb — diagnose where island borders collide. Recomputes each
# island's territory + perimeter exactly as Astromapper::Islands does, then reports:
#   * OVERLAP  — a hex claimed by two islands (territories grew into each other)
#   * TOUCH    — a border edge shared by two islands (two borders drawn on one line)
#
#   ruby tools/island-conflicts.rb path/to/sector.tab [jump=2] [min_size=2]
#
# Reads system hexes from a T5SS .tab (Hex column), a .sector.txt, or any file with
# `NNNN` hex tokens at line start.

require_relative '../lib/astromapper/islands'
J = Astromapper::Islands
SIDE = 40.0; FACTOR = 1.732
COLS = 32; ROWS = 40

path = ARGV[0] or abort "usage: ruby tools/island-conflicts.rb <sector.tab> [jump] [min_size]"
threshold = (ARGV[1] || 2).to_i
min_size  = (ARGV[2] || 2).to_i

# --- read system hexes (tab Hex column, or leading NNNN tokens) ---
lines = File.readlines(path, encoding: "utf-8").reject { |l| l.start_with?("#") }
hexes =
  if lines.first && lines.first.include?("\t") && lines.first =~ /Hex/
    hdr = lines.shift.chomp.split("\t"); hi = hdr.index("Hex")
    lines.map { |l| h = l.chomp.split("\t")[hi]; h && h =~ /^\d{4}$/ ? [h[0, 2].to_i, h[2, 2].to_i] : nil }.compact
  else
    lines.map { |l| l =~ /^(\d{2})(\d{2})/ ? [$1.to_i, $2.to_i] : nil }.compact
  end.uniq
abort "no system hexes found in #{path}" if hexes.empty?

# --- cluster (union-find, jump <= threshold) ---
parent = {}; hexes.each { |h| parent[h] = h }
find = ->(x) { x = parent[x] while parent[x] != x; x }
hexes.combination(2) { |a, b| (parent[find.(a)] = find.(b)) if J.jump(a, b) <= threshold && find.(a) != find.(b) }
clusters = hexes.group_by { |h| find.(h) }.values.select { |c| c.size >= min_size }

neighbours = lambda do |c, r|
  out = []
  ((c - 1)..(c + 1)).each do |nc|
    next unless (1..COLS).cover?(nc)
    ((r - 1)..(r + 1)).each do |nr|
      next unless (1..ROWS).cover?(nr)
      out << [nc, nr] if !(nc == c && nr == r) && J.jump([c, r], [nc, nr]) == 1
    end
  end
  out
end

# --- replicate territory + perimeter edges per island ---
hw = SIDE / 2; hh = SIDE * FACTOR / 2
corners = [[SIDE, 0], [hw, hh], [-hw, hh], [-SIDE, 0], [-hw, -hh], [hw, -hh]]
# Pass 1: raw territories (systems + bridges + compactness close)
terrs = clusters.map do |systems|
  terr = {}; systems.each { |s| terr[s] = true }
  adj = Hash.new(0)
  systems.each do |sc, sr|
    ((sc - 2)..(sc + 2)).each { |c| next unless (1..COLS).cover?(c); ((sr - 2)..(sr + 2)).each { |r| next unless (1..ROWS).cover?(r); adj[[c, r]] += 1 if J.jump([sc, sr], [c, r]) == 1 } }
  end
  adj.each { |h, n| terr[h] = true if n >= 2 }
  loop do
    cand = {}; terr.each_key { |c, r| neighbours.(c, r).each { |n| cand[n] = true unless terr[n] } }
    add = cand.keys.select { |h| neighbours.(*h).count { |n| terr[n] } >= 3 }
    break if add.empty?
    add.each { |h| terr[h] = true }
  end
  terr
end
# Resolve overlaps to nearest cluster (mirrors Astromapper::Islands)
own = Hash.new { |h, k| h[k] = [] }
terrs.each_with_index { |t, i| t.each_key { |h| own[h] << i } }
own.each do |h, ids|
  next if ids.size == 1
  keep = ids.min_by { |i| clusters[i].map { |s| J.jump(h, s) }.min }
  (ids - [keep]).each { |i| terrs[i].delete(h) }
end
# Pass 2: perimeters from exclusive territories
islands = terrs.each_with_index.map do |terr, i|
  edges = Hash.new(0)
  terr.each_key do |c, r|
    cx = SIDE + (c - 1) * SIDE * 1.5
    cy = (r - 1) * SIDE * FACTOR + (SIDE * FACTOR / (1 + (c % 2)))
    pts = corners.map { |dx, dy| [(cx + dx).round, (cy + dy).round] }
    6.times { |k| key = [pts[k], pts[(k + 1) % 6]].sort; edges[key] += 1 }
  end
  { idx: i, size: clusters[i].size, terr: terr.keys, perim: edges.select { |_, n| n == 1 }.keys }
end

hx = ->(h) { "%02d%02d" % h }

# --- OVERLAP: a hex in two territories ---
owner = Hash.new { |h, k| h[k] = [] }
islands.each { |is| is[:terr].each { |t| owner[t] << is[:idx] } }
overlaps = owner.select { |_, v| v.size > 1 }

# --- TOUCH: a perimeter edge shared by two islands ---
edge_owner = Hash.new { |h, k| h[k] = [] }
islands.each { |is| is[:perim].each { |e| edge_owner[e] << is[:idx] } }
shared = edge_owner.select { |_, v| v.uniq.size > 1 }
# group shared edges by island pair
pairs = Hash.new(0)
shared.each { |_, v| v.uniq.combination(2) { |a, b| pairs[[a, b].sort] += 1 } }

puts "#{hexes.size} systems -> #{clusters.size} islands (jump<=#{threshold}, size>=#{min_size})"
puts ""
if overlaps.empty?
  puts "OVERLAP (hex claimed by 2 islands): none"
else
  puts "OVERLAP (#{overlaps.size} hexes claimed by 2+ islands):"
  overlaps.each { |h, v| puts "  #{hx.(h)} claimed by islands #{v.join(' & ')}" }
end
puts ""
if pairs.empty?
  puts "TOUCH (islands sharing a border edge): none"
else
  puts "TOUCH (#{pairs.size} island pairs share border edges — these draw overlapping borders):"
  pairs.sort_by { |_, n| -n }.each do |(a, b), n|
    sa = islands.find { |i| i[:idx] == a }; sb = islands.find { |i| i[:idx] == b }
    # contact hexes: territory hexes of A adjacent to territory of B
    bset = sb[:terr].to_h { |h| [h, true] }
    contact = sa[:terr].select { |h| neighbours.(*h).any? { |nb| bset[nb] } }.map { |h| hx.(h) }
    puts "  islands #{a}(#{sa[:size]}sys) <-> #{b}(#{sb[:size]}sys): #{n} shared edge(s); contact near #{contact.first(4).join(', ')}"
  end
end
