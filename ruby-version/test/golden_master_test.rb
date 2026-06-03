require_relative "test_helper"

# Locks in the generator's output so the fixes, the genre star-bias, and the
# seeding behaviour can't silently regress. The fixture is byte-compared.
#
# Regenerate the fixture intentionally after a deliberate generation change:
#   UPDATE_GOLDEN=1 ruby -Itest test/golden_master_test.rb
class GoldenMasterTest < Minitest::Test
  include SectorBuilder

  SEED   = 20260603
  GOLDEN = File.expand_path("fixtures/sector_normal_#{SEED}.txt", __dir__)

  def test_matches_golden_master
    text = sector_text(seed: SEED, genre: "normal")

    if ENV["UPDATE_GOLDEN"]
      FileUtils.mkdir_p(File.dirname(GOLDEN))
      File.write(GOLDEN, text)
      skip "regenerated golden master at #{GOLDEN}"
    end

    assert File.exist?(GOLDEN),
      "missing golden master; create it with UPDATE_GOLDEN=1"
    assert_equal File.read(GOLDEN), text,
      "sector output drifted from the golden master (run UPDATE_GOLDEN=1 if intended)"
  end

  def test_same_seed_is_reproducible
    assert_equal sector_text(seed: SEED), sector_text(seed: SEED)
  end

  def test_different_seed_differs
    refute_equal sector_text(seed: 1), sector_text(seed: 2)
  end

  # Locks in the B-practical feature: settled space trends toward F/G/K stars,
  # strengthening with genre realism (normal < opera < firm).
  # Genre stellar model: opera (T5 sun-like table) is far more F/G/K than the
  # M-dwarf-heavy normal and firm; firm is the realistic, M-dominated galaxy.
  def test_genre_stellar_model
    normal = fgk_fraction(sector_text(seed: SEED, genre: "normal"))
    opera  = fgk_fraction(sector_text(seed: SEED, genre: "opera"))
    firm   = fgk_fraction(sector_text(seed: SEED, genre: "firm"))

    assert_operator opera, :>, normal, "opera (T5 sun-like) should beat M-heavy normal"
    assert_operator opera, :>, firm,   "opera should be more F/G/K than realistic firm"
    assert_operator firm,  :<, 0.5,    "firm should be M-dwarf-heavy (realistic galaxy)"
  end
end
