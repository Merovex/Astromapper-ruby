#!/usr/bin/env ruby
# json2sector.rb — expand a Converted-Sector JSON into the columnar .sector.txt
# format. A faithful Ruby port of the Go writer (go-version/pkg/models/*.go), so
# the output matches the format the Go tool produces.
#
#   ruby tools/json2sector.rb input.json [output.sector.txt]
#
# Emits the full ("expanded") map: the main line per system plus a detail line
# for EVERY orbit (empties shown as `. // .......-.`), and a line per moon where
# the JSON carries them. Handles both the current export (companions stored with
# a star_classification) and the older/leaner one (e.g. teradoma: companions are
# bare `S` orbits, no moons) — missing data simply isn't emitted.

require 'json'

ROMAN = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"].freeze
EHEX  = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ".freeze   # T5 extended hex for Ix/Ex/Cx (skips I,O)
def ehex(n); n = n.to_i; n < 0 ? "0" : (EHEX[n] || EHEX[-1]); end
# go: StarMass[type][size]; OuterLimit = 40 * mass (default mass 0.3)
STAR_MASS = {
  "O" => [70, 60, 0, 0, 50, 0], "B" => [50, 40, 35, 30, 20, 10],
  "A" => [30, 16, 10, 6, 4, 3], "F" => [15, 13, 8, 2.5, 2.2, 1.9],
  "G" => [12, 10, 6, 2.7, 1.8, 1.1, 0.8], "K" => [15, 12, 6, 3, 2.3, 0.9, 0.5],
  "M" => [20, 16, 8, 4, 0.3, 0.2], "D" => [0.8, 0.8, 0.8, 0.8, 0.8, 0.8],
}.freeze
TYPE_LETTER = { "companion" => "S", "world" => "W", "belt" => "B", "gas_giant" => "G",
                "hostile" => "H", "rockball" => "R", "empty" => "." }.freeze

def to_hex(n)
  n = n.to_i
  return "0" if n < 0
  return n.to_s if n < 10
  { 10 => "A", 11 => "B", 12 => "C", 13 => "D", 14 => "E", 15 => "F" }[n] || "F"
end

def to_roman(n); n = n.to_i; n == 500 ? "D" : (ROMAN[n] || n.to_s); end

def outer_limit(s)
  masses = STAR_MASS[s["star_type"]]
  mass = (masses && s["star_size"].to_i < masses.size) ? masses[s["star_size"].to_i] : 0.3
  40 * mass
end

# Resolve an orbit's single-letter kind: prefer the stored orbit_type, else map
# from the orbit's structural type (so bare companion orbits become "S").
def orbit_letter(o)
  t = o["data"]["orbit_type"].to_s
  t.empty? ? (TYPE_LETTER[o["type"]] || ".") : t
end

def body_uwp(d, letter)
  return ".......-." if letter == "."
  "%s%s%s%s%s%s%s-%s" % [d["starport"].to_s,
    to_hex(d["size"]), to_hex(d["atmosphere"]), to_hex(d["hydrographics"]),
    to_hex(d["population"]), to_hex(d["government"]), to_hex(d["law_level"]), to_hex(d["tech_level"])]
end

def classification(s)
  return "D#{s['star_subtype']}" if s["star_type"] == "D"
  "#{s['spectral']}#{to_roman(s['star_size'])}"
end

def orbit_ascii(o, limit)
  d = o["data"]
  letter = orbit_letter(o)
  bio = d["zone"] == 0 ? "*" : " "      # explicit 0 only; older exports leave non-biozone orbits nil
  bio = "-" if d["au"].to_f > limit
  line = "  -- %2d. %s  %s // %s // %4.1f au" % [d["orbit_number"].to_i + 1, bio, letter, body_uwp(d, letter), d["au"].to_f]
  (d["moons"] || []).each do |m|
    line += "\n     -- Moon %d: Size %s Atmo %s Hydro %s" % [m["orbit"].to_i + 1, to_hex(m["size"]), to_hex(m["atmosphere"]), to_hex(m["hydrographics"])]
  end
  line
end

def volume_ascii(v)
  s = v["star"]; w = s["world"]
  bases = w["bases"].to_s.delete(".")   # compact positional ".S..." -> "S"; "....." -> none
  bases = "." if bases.empty?
  orbits = s["orbits"] || []
  # Stars crib = primary + each companion's classification (from companion orbits
  # that carry star_classification; older exports have none -> primary only).
  comp = orbits.select { |o| o["type"] == "companion" }.map { |o| o["data"]["star_classification"] }.compact
  stars = ([classification(s)] + comp).join("/")
  summary = "%-8s %-9s %-4s %-5s %-11s %-12s %-13s %-13s %s" % [
    "%02d%02d" % [v["column"], v["row"]], body_uwp(w, "W"), w["temperature"], bases,
    (w["trade_codes"] || []).join(" "), (w["factions"] || []).join(" "),
    stars, orbits.map { |o| orbit_letter(o) }.join, v["name"]]

  # T5 extensions, appended after the name when present (Ix / Ex / Cx / RU + native)
  if w["ix"]
    ex = w["ex"]; cx = w["cx"]
    summary += "  { %+d } (%s%s%s%+d) [%s%s%s%s] RU:%d  %s" % [w["ix"],
      ehex(ex["res"]), ehex(ex["lab"]), ehex(ex["inf"]), ex["eff"].to_i,
      ehex(cx["homo"]), ehex(cx["acc"]), ehex(cx["str"]), ehex(cx["sym"]), w["ru"], w["native"]]
  end

  return summary if orbits.empty?
  limit = outer_limit(s)
  summary + "\n" + orbits.map { |o| orbit_ascii(o, limit) }.join("\n") + "\n"
end

input  = ARGV[0] or abort "usage: ruby tools/json2sector.rb input.json [output.sector.txt]"
output = ARGV[1] || input.sub(/\.json$/i, '') + ".sector.txt"
doc = JSON.parse(File.read(input, encoding: "utf-8"))
vols = doc["volumes"]

io = +""
io << "# Sector: #{doc['name']}\n"
io << "# 32 columns x 40 rows\n"
io << <<~LEGEND
  #
  # FIELDS (left to right): Location UWP Temp Bases TC Factions Stars Orbits Name  { Ix } (Ex) [Cx] RU:n  Native
  #   Location  Hex column+row (e.g. 0801)
  #   UWP       Starport Size Atmo Hydro Pop Gov Law - Tech (eHex)
  #   Temp      Climate: T Temperate  H Hot  C Cold  Tz Twilight  Lk Locked
  #   Bases     N Naval  S Scout  D Depot  W Way  C Corsair  (. = none)
  #   TC        Trade classifications (Traveller 5 TCS)
  #   Factions  Government types present: O F M N S P
  #   Stars     Spectral + luminosity, primary/companions (e.g. G2V/DB)
  #   Orbits    Per orbit: W World  B Belt  G GasGiant  S Companion  R Rockball  H Hostile  . empty
  #   Name      Mainworld name
  #   { Ix }    Importance extension
  #   (Ex)      Economic: Resources Labor Infrastructure +-Efficiency (eHex)
  #   [Cx]      Cultural: Homogeneity Acceptance Strangeness Symbols (eHex)
  #   RU:n      Resource Units (R x L x I x E)
  #   Native    Settled / Colony (human) ; Native / Exotic (sophonts)
  #
  # eHex digits: 0-9 A-H J-N P-Z  (skips I and O)
  #
  # Orbit lines ( -- N. ): orbit no., * biozone / - beyond outer limit, type, UWP, distance (AU)
  # Moon lines  ( -- Moon N: ): size, atmosphere, hydrographics
  #
LEGEND
io << "Location UWP       Temp Bases TC          Factions     Stars         Orbits        Name\n"
io << "-------- --------- ---- ----- ----------- ------------ ------------- ------------- ----\n"

by_key = {}
vols.each { |_, v| by_key[[v["column"], v["row"]]] = v }   # go: 4x4 grid of 8x10 subsectors, A..P
4.times do |srow|
  4.times do |scol|
    letter = ("A".ord + srow * 4 + scol).chr
    cells = []
    10.times { |lr| 8.times { |lc| (v = by_key[[scol * 8 + lc + 1, srow * 10 + lr + 1]]) && cells << v } }
    next if cells.empty?
    io << "\n# Subsector #{letter}\n"
    cells.each { |v| io << volume_ascii(v) << "\n" }
  end
end

File.write(output, io)
puts "wrote #{output}  (#{vols.size} systems)"
