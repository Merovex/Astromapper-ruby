package rules

import (
	"astromapper/pkg/rng"
	"testing"
)

func evalExpr(t *testing.T, src string, ctx map[string]any) any {
	t.Helper()
	v, err := Evaluate(src, ctx, rng.New("expr-test"))
	if err != nil {
		t.Fatalf("Evaluate(%q) error: %v", src, err)
	}
	return v
}

func TestExprArithmetic(t *testing.T) {
	cases := map[string]int{"2+3": 5, "10-3": 7, "2*3": 6, "-(2+2)": -4, "2*3+1": 7}
	for src, want := range cases {
		if got := toInt(evalExpr(t, src, nil)); got != want {
			t.Errorf("%q = %d, want %d", src, got, want)
		}
	}
}

func TestExprComparisonsAndBooleans(t *testing.T) {
	cases := map[string]bool{
		"5>=2 and 5<=9":     true,
		"5>9 or 1>9":        false,
		"not 5>9":           true,
		"(1==1) and (2==2)": true,
		"3>4 or 4>3":        true,
	}
	for src, want := range cases {
		if got := evalExpr(t, src, nil); got != want {
			t.Errorf("%q = %v, want %v", src, got, want)
		}
	}
}

func TestExprVariablesAndStrings(t *testing.T) {
	cond := MustCompile("atmo>=2 and atmo<=9 and hydro==0")
	if got := cond(map[string]any{"atmo": 5, "hydro": 0}, nil); got != true {
		t.Errorf("expected true, got %v", got)
	}
	if got := cond(map[string]any{"atmo": 5, "hydro": 4}, nil); got != false {
		t.Errorf("expected false, got %v", got)
	}
	if got := evalExpr(t, "port=='X'", map[string]any{"port": "X"}); got != true {
		t.Errorf("port==X with X: got %v", got)
	}
	if got := evalExpr(t, "port=='X'", map[string]any{"port": "A"}); got != false {
		t.Errorf("port==X with A: got %v", got)
	}
}

func TestExprDiceInRange(t *testing.T) {
	r := rng.New("dice")
	twoD6, flux := MustCompile("2d6-2"), MustCompile("flux")
	for i := 0; i < 500; i++ {
		if v := toInt(twoD6(nil, r)); v < 0 || v > 10 {
			t.Fatalf("2d6-2 out of range: %d", v)
		}
		if v := toInt(flux(nil, r)); v < -5 || v > 5 {
			t.Fatalf("flux out of range: %d", v)
		}
	}
}

func TestExprRejectsBadInput(t *testing.T) {
	for _, src := range []string{"1 +", "((1)", "2 @ 3"} {
		if _, err := Compile(src); err == nil {
			t.Errorf("expected error compiling %q", src)
		}
	}
}
