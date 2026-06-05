require_relative "test_helper"

# The sandboxed expression evaluator and the data-driven trade-code table.
class ExprTest < Minitest::Test
  E = Astromapper::Rules::Expr

  def test_arithmetic
    assert_equal 5, E.evaluate("2+3")
    assert_equal 7, E.evaluate("10-3")
    assert_equal 6, E.evaluate("2*3")
    assert_equal(-4, E.evaluate("-(2+2)"))
  end

  def test_comparisons_and_booleans
    assert_equal true,  E.evaluate("5>=2 and 5<=9")
    assert_equal false, E.evaluate("5>9 or 1>9")
    assert_equal true,  E.evaluate("not 5>9")
    assert_equal true,  E.evaluate("(1==1) and (2==2)")
  end

  def test_variables_and_strings
    cond = E.compile("atmo>=2 and atmo<=9 and hydro==0")
    assert_equal true,  cond.call("atmo" => 5, "hydro" => 0)
    assert_equal false, cond.call("atmo" => 5, "hydro" => 4)
    assert_equal true,  E.evaluate("port=='X'", "port" => "X")
    assert_equal false, E.evaluate("port=='X'", "port" => "A")
  end

  def test_dice_in_range
    200.times do
      assert_includes (0..10), E.evaluate("2d6-2")
      assert_includes (-5..5), E.evaluate("flux")
    end
  end

  def test_rejects_non_expression_input
    assert_raises(RuntimeError) { E.evaluate("system('rm -rf')") }   # parses as var/string, never executes
    assert_raises(RuntimeError) { E.evaluate("1 +") }
  end

  # The t5.yml trade table must reproduce the known T5 classifications.
  def test_t5_trade_codes_table
    rs = Astromapper::Rules::Ruleset.load("t5")
    earth = { "size"=>8, "atmo"=>6, "hydro"=>7, "pop"=>7, "gov"=>5, "law"=>5, "tech"=>9, "port"=>"A", "temp"=>"T" }
    assert_equal %w[Ga Ag Ri], rs.trade_codes(earth)
    rock = { "size"=>0, "atmo"=>0, "hydro"=>0, "pop"=>0, "gov"=>0, "law"=>0, "tech"=>2, "port"=>"X", "temp"=>"T" }
    assert_equal %w[As Va Ba Lt], rs.trade_codes(rock)   # Lt: tech 2 < 6
  end

  def test_t5_starport_dm_and_base_tables
    rs = Astromapper::Rules::Ruleset.load("t5")
    # orientation table, low roll = best, clamped
    assert_equal %w[A B C D E X], [0, 5, 7, 9, 10, 12].map { |r| rs.starport(r) }
    assert_equal "X", rs.starport(99)
    # tech DMs: port A(+6) size0(+2) atmo0(+1) hydro0(0) pop0(0) gov0(+1) = 10
    assert_equal 10, rs.tech_dm("port"=>"A", "size"=>0, "atmo"=>0, "hydro"=>0, "pop"=>0, "gov"=>0)
    # base thresholds (nil = port can't host that base)
    assert_equal 6,   rs.base_threshold("naval", "A")
    assert_equal 6,   rs.base_threshold("scout", "C")
    assert_nil        rs.base_threshold("naval", "C")
    assert_nil        rs.base_threshold("way",   "D")
  end

  def test_t5_uwp_step_driver
    rs = Astromapper::Rules::Ruleset.load("t5")
    # zero_when: a sizeless world has no atmosphere (and rolls no die for it)
    assert_equal 0, rs.uwp_step("atmo", { "size" => 0 })
    # adjust set:0 — a tiny world is forced dry regardless of the flux roll
    100.times { assert_equal 0, rs.uwp_step("hydro", { "size" => 1, "atmo" => 8 }) }
    # clamps: hydro<=A(10), gov<=F(15), law<=J(18) even with maxed inputs
    srand(20260605)
    300.times do
      assert_includes (0..10), rs.uwp_step("hydro", { "size" => 9, "atmo" => 7 })
      assert_includes (0..15), rs.uwp_step("gov",   { "pop" => 15 })
      assert_includes (0..18), rs.uwp_step("law",   { "gov" => 15 })
    end
  end

  def test_module_registry
    rs = Astromapper::Rules::Ruleset.load("t5")
    %w[extensions climate native].each { |slot| assert_equal "t5", rs.module_for(slot) }
    # default to t5 when a slot is unspecified
    assert_equal "t5", Astromapper::Rules::Ruleset.new("bare", {}).module_for("extensions")
    # explicit disable
    off = Astromapper::Rules::Ruleset.new("off", { "modules" => { "extensions" => "none" } })
    assert_equal "none", off.module_for("extensions")
    # a module name is constrained to a word, so YAML can't smuggle a method/call
    bad = Astromapper::Rules::Ruleset.new("bad", { "modules" => { "climate" => "system('x')" } })
    assert_raises(RuntimeError) { bad.module_for("climate") }
  end
end
