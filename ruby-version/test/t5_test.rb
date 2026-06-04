require_relative "test_helper"

# Unit tests pinning the Traveller 5 generation rules independently of the golden
# master, so a regression points at the specific rule that broke.
class T5Test < Minitest::Test
  include SectorBuilder

  # All mainworlds for a seed/config.
  def worlds(seed:, **opts)
    Astromapper.test_config = SectorBuilder::DEFAULTS.merge(opts.transform_keys(&:to_s))
    srand(seed)
    sec = Astromapper::Builder::Sector.constitute(Pathname.new(Dir.pwd))
    sec.instance_variable_get(:@volumes).map { |v| v.instance_variable_get(:@star).world }.compact
  end

  def star_types(seed:, genre:)
    Astromapper.test_config = SectorBuilder::DEFAULTS.merge("genre" => genre)
    srand(seed)
    Astromapper::Builder::Sector.constitute(Pathname.new(Dir.pwd))
      .instance_variable_get(:@volumes).map { |v| v.instance_variable_get(:@star).type }
  end

  def iv(w, name) = w.instance_variable_get(name)

  def test_ehex_skips_i_and_o
    assert_equal "F", 15.hexd
    assert_equal "G", 16.hexd
    assert_equal "H", 17.hexd
    assert_equal "J", 18.hexd      # I is skipped
  end

  def test_uwp_digit_ceilings
    worlds(seed: 42).each do |w|
      assert (0..10).cover?(iv(w, :@h20)),  "hydro must be 0-A"
      assert (0..15).cover?(iv(w, :@govm)), "gov must be 0-F"
      assert (0..18).cover?(iv(w, :@law)),  "law must be 0-J"
      assert (0..15).cover?(iv(w, :@tek)),  "tech must be 0-F"
    end
  end

  def test_climate_is_hz_based
    worlds(seed: 42).each { |w| assert %w[T H C Tz Lk].include?(w.temp), "bad climate #{w.temp}" }
  end

  def test_trade_codes_follow_t5_table
    worlds(seed: 42).each do |w|
      a, s, h = iv(w, :@atmo), iv(w, :@size), iv(w, :@h20)
      tc = w.trade_codes
      assert_includes tc, "Va", "atmo 0 must be Vacuum" if a == 0
      assert_includes tc, "As", "size/atmo/hydro 0 = Asteroid" if s == 0 && a == 0 && h == 0
    end
  end

  def test_extensions_present_and_cultural_floor
    worlds(seed: 42).each do |w|
      assert_kind_of Integer, w.ix
      assert_kind_of Integer, w.ru
      %i[homo acc str sym].each { |k| assert_operator w.cx[k], :>=, 1, "Cx #{k} floors at 1" }
    end
  end

  def test_f_and_hotter_worlds_cap_at_colony_size
    worlds(seed: 7, genre: "opera").each do |w|
      next unless %w[O B A F].include?(w.instance_variable_get(:@star).type)
      assert_operator iv(w, :@popx), :<=, 6, "F-and-hotter worlds are colony-sized"
    end
  end

  def test_genre_stellar_demographics
    firm  = star_types(seed: 7, genre: "firm")
    opera = star_types(seed: 7, genre: "opera")
    assert_operator firm.count("M").to_f / firm.size, :>, 0.6, "firm is M-dwarf-heavy"
    fgk = opera.count { |t| %w[F G K].include?(t) }.to_f / opera.size
    assert_operator fgk, :>, 0.6, "opera is sun-like (F/G/K)"
  end

  def test_human_only_default
    statuses = worlds(seed: 42).map(&:native).uniq
    refute_includes statuses, "Native", "default sophonts:human has no native aliens"
    refute_includes statuses, "Exotic"
  end

  # Every surviving system must have a neighbour within jump-4 — isolated lone
  # stars (which no route can reach) are pruned during generation.
  def test_prune_removes_isolated_systems
    Astromapper.test_config = SectorBuilder::DEFAULTS.merge("prune_isolated" => true)
    srand(7)
    sec = Astromapper::Builder::Sector.constitute(Pathname.new(Dir.pwd))
    coords = sec.instance_variable_get(:@volumes).map { |v| [v.column, v.row] }
    coords.each do |h|
      assert coords.any? { |o| o != h && Astromapper::Islands.jump(h, o) <= 4 },
        "#{'%02d%02d' % h} is isolated (no neighbour within jump-4) but survived pruning"
    end
  end

  # Disabling the prune keeps every rolled system, so the count is >= pruned.
  def test_prune_can_be_disabled
    count = lambda do |prune|
      Astromapper.test_config = SectorBuilder::DEFAULTS.merge("prune_isolated" => prune)
      srand(7)
      Astromapper::Builder::Sector.constitute(Pathname.new(Dir.pwd))
        .instance_variable_get(:@volumes).size
    end
    assert_operator count.(false), :>=, count.(true),
      "disabling the prune keeps at least as many systems"
  end

  # Non-colony (Settled, pop >= 7) worlds must sit in the habitable gravity band:
  # ~0.4-1.5 g (size 5-A) — enough to shield radiation, not enough to crush.
  def test_settled_worlds_in_habitable_gravity_band
    %w[normal opera firm].each do |g|
      worlds(seed: 7, genre: g).each do |w|
        next unless iv(w, :@popx) >= 7
        assert (0.4..1.5).cover?(w.gravity),
          "Settled world (pop #{iv(w, :@popx)}) has gravity #{w.gravity} outside 0.4-1.5"
      end
    end
  end
end
