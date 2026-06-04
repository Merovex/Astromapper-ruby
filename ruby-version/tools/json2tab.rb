#!/usr/bin/env ruby
# json2tab.rb — emit a (Go-format) Converted-Sector JSON as a T5 Second Survey
# TAB-delimited sector file (the TravellerMap interchange standard). Tab-delimited
# is robust to parse (no column overflow) and maps cleanly onto our enriched data.
#
#   ruby tools/json2tab.rb input.json [output.tab]
#
# Columns:
#   Sector  SS  Hex  Name  UWP  Bases  Remarks  Zone  PBG  Allegiance
#   Stars  {Ix}  (Ex)  [Cx]  Nobility  W  RU

require 'json'

ROMAN = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"].freeze
EHEX  = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ".freeze
def ehex(n); n = n.to_i; n < 0 ? "0" : (EHEX[n] || EHEX[-1]); end

ALLEGIANCE = ENV["ALLEGIANCE"] || "Na"   # Non-Aligned default (no allegiance in source)

def uwp(w)
  "%s%s%s%s%s%s%s-%s" % [w["starport"], ehex(w["size"]), ehex(w["atmosphere"]), ehex(w["hydrographics"]),
                         ehex(w["population"]), ehex(w["government"]), ehex(w["law_level"]), ehex(w["tech_level"])]
end

# T5SS stars: "F2 V", companions space-separated; white dwarfs "D" + subtype.
def t5_star(s)
  return "D#{s['star_subtype']}" if s["star_type"] == "D"
  "#{s['spectral']} #{ROMAN[s['star_size']]}".strip
end

def stars(s)
  comp = (s["orbits"] || []).select { |o| o["type"] == "companion" }.map { |o| o["data"]["star_classification"] }.compact
  ([t5_star(s)] + comp).join(" ")
end

# Zone: T5SS single letter (Amber / Red), blank otherwise — derived from the UWP.
def zone(w)
  a, g, l = w["atmosphere"].to_i, w["government"].to_i, w["law_level"].to_i
  return "R" if l >= 15 || g >= 15
  return "A" if a > 9 || [0, 7, 10].include?(g) || l == 0 || (9..14).include?(l)
  ""
end

input  = ARGV[0] or abort "usage: ruby tools/json2tab.rb input.json [output.tab]"
output = ARGV[1] || input.sub(/\.json$/i, '') + ".tab"
srand(Integer(ENV["TAB_SEED"] || 20260604))   # only the PBG population-multiplier is rolled
doc = JSON.parse(File.read(input, encoding: "utf-8"))
sector = doc["name"].to_s

cols = %w[Sector SS Hex Name UWP Bases Remarks Zone PBG Allegiance Stars {Ix} (Ex) [Cx] Nobility W RU]
legend = <<~LEG.chomp
  # Sector: #{sector} -- T5 Second Survey (tab-delimited). Lines beginning with # are comments.
  #
  # COLUMNS: Sector SS Hex Name UWP Bases Remarks Zone PBG Allegiance Stars {Ix} (Ex) [Cx] Nobility W RU
  #   SS         Subsector A-P (4x4 grid of 8x10 subsectors)
  #   Hex        Column+row (e.g. 0801)
  #   UWP        Starport Size Atmo Hydro Pop Gov Law - Tech (eHex: 0-9 A-H J-N P-Z, skips I/O)
  #   Bases      N Naval  S Scout  D Depot  W Way  C Corsair  (blank = none)
  #   Remarks    Trade classifications (Traveller 5 TCS)
  #   Zone       A Amber  R Red  (blank = none)
  #   PBG        Population-multiplier, Belts, Gas giants
  #   Stars      Spectral + luminosity; companions space-separated (e.g. F2 V M4 V)
  #   {Ix}       Importance extension
  #   (Ex)       Economic: Resources Labor Infrastructure +-Efficiency
  #   [Cx]       Cultural: Homogeneity Acceptance Strangeness Symbols
  #   W  Worlds in system    RU  Resource Units (R x L x I x E)
  #
LEG
rows = [legend, cols.join("\t")]

doc["volumes"].values.sort_by { |v| [v["row"], v["column"]] }.each do |v|
  s = v["star"]; w = s["world"]; orbits = s["orbits"] || []
  ss   = (("A".ord) + ((v["row"] - 1) / 10) * 4 + ((v["column"] - 1) / 8)).chr
  hex  = "%02d%02d" % [v["column"], v["row"]]
  bases = w["bases"].to_s.delete(".").delete("G")          # G is a PBG digit, not a base
  belts = orbits.count { |o| o["type"] == "belt" }
  gg    = orbits.count { |o| o["type"] == "gas_giant" }
  pmul  = w["population"].to_i.zero? ? 0 : (1 + rand(9))   # population multiplier (1-9)
  pbg   = "%d%d%d" % [pmul, [belts, 9].min, [gg, 9].min]
  worlds = [orbits.count { |o| o["type"] == "world" }, 1].max
  ix = ex = cx = ru = ""
  if w["ix"]
    e = w["ex"]; c = w["cx"]
    ix = "{ %d }" % w["ix"]
    ex = "(%s%s%s%+d)" % [ehex(e["res"]), ehex(e["lab"]), ehex(e["inf"]), e["eff"].to_i]
    cx = "[%s%s%s%s]" % [ehex(c["homo"]), ehex(c["acc"]), ehex(c["str"]), ehex(c["sym"])]
    ru = w["ru"].to_s
  end

  rows << [sector, ss, hex, v["name"], uwp(w), bases, (w["trade_codes"] || []).join(" "),
           zone(w), pbg, ALLEGIANCE, stars(s), ix, ex, cx, "", worlds, ru].join("\t")
end

File.write(output, rows.join("\n") + "\n")
puts "wrote #{output}  (#{doc['volumes'].size} systems, T5SS tab)"
