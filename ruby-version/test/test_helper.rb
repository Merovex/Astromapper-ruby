$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "fileutils"
require "astromapper"

# Hermetic config injection: tests bypass the on-disk _astromapper.yml so a
# sector can be generated from an in-memory config. Generation reads only
# Astromapper.config, so overriding it is enough to drive the whole pipeline.
module Astromapper
  class << self
    attr_writer :test_config

    def config(_root_dir = nil)
      (@test_config || {}).with_indifferent_access
    end
  end
end

# Shared helpers for building deterministic sectors and inspecting them.
module SectorBuilder
  DEFAULTS = {
    "density"          => "scattered",
    "genre"            => "normal",
    "named"            => false,        # location codes, not the 2000-name list
    "always_inhabited" => true,
  }.freeze

  # Deterministically generate a sector and return its ASCII as one string.
  def sector_text(seed:, **overrides)
    Astromapper.test_config = DEFAULTS.merge(overrides.transform_keys(&:to_s))
    srand(seed)
    sector = Astromapper::Builder::Sector.constitute(Pathname.new(Dir.pwd))
    sector.instance_variable_get(:@volumes).map(&:to_ascii).join("\n")
  end

  # Primary star letter (F/G/K/M/A/B/D) for each system, parsed from the crib.
  def primary_types(text)
    text.lines.select { |l| l =~ /^\d{4}/ }.map do |line|
      crib = line.split("\t")[3].to_s.strip
      crib[0]
    end
  end

  # Fraction of systems whose primary is a habitable-friendly F/G/K star.
  def fgk_fraction(text)
    types = primary_types(text)
    return 0.0 if types.empty?
    types.count { |c| %w[F G K].include?(c) }.to_f / types.size
  end
end
