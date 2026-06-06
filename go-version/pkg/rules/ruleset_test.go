package rules

import (
	"astromapper/pkg/rng"
	"reflect"
	"testing"
)

func loadT5(t *testing.T) *Ruleset {
	t.Helper()
	rs, err := Load("t5", "")
	if err != nil {
		t.Fatalf("load t5: %v", err)
	}
	return rs
}

func TestT5TradeCodes(t *testing.T) {
	rs := loadT5(t)
	earth := map[string]any{"size": 8, "atmo": 6, "hydro": 7, "pop": 7, "gov": 5, "law": 5, "tech": 9, "port": "A", "temp": "T"}
	if got := rs.TradeCodes(earth); !reflect.DeepEqual(got, []string{"Ga", "Ag", "Ri"}) {
		t.Errorf("earth trade codes = %v, want [Ga Ag Ri]", got)
	}
	rock := map[string]any{"size": 0, "atmo": 0, "hydro": 0, "pop": 0, "gov": 0, "law": 0, "tech": 2, "port": "X", "temp": "T"}
	if got := rs.TradeCodes(rock); !reflect.DeepEqual(got, []string{"As", "Va", "Ba", "Lt"}) {
		t.Errorf("rock trade codes = %v, want [As Va Ba Lt]", got)
	}
}

func TestT5StarportTechBaseTables(t *testing.T) {
	rs := loadT5(t)
	want := []string{"A", "B", "C", "D", "E", "X"}
	for i, roll := range []int{0, 5, 7, 9, 10, 12} {
		if got := rs.Starport(roll); got != want[i] {
			t.Errorf("Starport(%d) = %s, want %s", roll, got, want[i])
		}
	}
	if got := rs.Starport(99); got != "X" {
		t.Errorf("Starport(99) = %s, want X", got)
	}
	if dm := rs.TechDM(map[string]any{"port": "A", "size": 0, "atmo": 0, "hydro": 0, "pop": 0, "gov": 0}); dm != 10 {
		t.Errorf("TechDM = %d, want 10", dm)
	}
	if th, ok := rs.BaseThreshold("naval", "A"); !ok || th != 6 {
		t.Errorf("naval/A = %d,%v want 6,true", th, ok)
	}
	if th, ok := rs.BaseThreshold("scout", "C"); !ok || th != 6 {
		t.Errorf("scout/C = %d,%v want 6,true", th, ok)
	}
	if _, ok := rs.BaseThreshold("naval", "C"); ok {
		t.Error("naval/C should be absent")
	}
}

func TestT5UWPStepDriver(t *testing.T) {
	rs := loadT5(t)
	r := rng.New("uwp")
	// zero_when: a sizeless world has no atmosphere
	if v, _ := rs.UWPStep("atmo", map[string]any{"size": 0}, r); v != 0 {
		t.Errorf("atmo for size 0 = %d, want 0", v)
	}
	// adjust set:0 — a tiny world is forced dry
	for i := 0; i < 100; i++ {
		if v, _ := rs.UWPStep("hydro", map[string]any{"size": 1, "atmo": 8}, r); v != 0 {
			t.Fatalf("hydro for tiny world = %d, want 0", v)
		}
	}
	// clamps
	for i := 0; i < 300; i++ {
		if v, _ := rs.UWPStep("hydro", map[string]any{"size": 9, "atmo": 7}, r); v < 0 || v > 10 {
			t.Fatalf("hydro out of range: %d", v)
		}
		if v, _ := rs.UWPStep("gov", map[string]any{"pop": 15}, r); v < 0 || v > 15 {
			t.Fatalf("gov out of range: %d", v)
		}
		if v, _ := rs.UWPStep("law", map[string]any{"gov": 15}, r); v < 0 || v > 18 {
			t.Fatalf("law out of range: %d", v)
		}
	}
}

func TestModuleRegistry(t *testing.T) {
	rs := loadT5(t)
	for _, slot := range []string{"extensions", "climate", "native"} {
		if m, err := rs.ModuleFor(slot); err != nil || m != "t5" {
			t.Errorf("ModuleFor(%s) = %q,%v want t5", slot, m, err)
		}
	}
	bad := &Ruleset{name: "bad", data: map[string]any{"modules": map[string]any{"climate": "system('x')"}}}
	if _, err := bad.ModuleFor("climate"); err == nil {
		t.Error("expected error for bad module name")
	}
}

func TestValidation(t *testing.T) {
	rs := &Ruleset{name: "broken", data: map[string]any{}}
	err := rs.Validate()
	if err == nil {
		t.Fatal("expected validation error")
	}
	for _, want := range []string{"hex", "uwp.size", "starport"} {
		if !contains(err.Error(), want) {
			t.Errorf("error %q missing %q", err.Error(), want)
		}
	}
}

func TestBaseComparisonDirection(t *testing.T) {
	rs := loadT5(t) // default op <=
	if !rs.BaseMeets(5, 6) || rs.BaseMeets(7, 6) {
		t.Error("t5 base op should be <=")
	}
	ge := &Ruleset{name: "ge", data: map[string]any{"bases": map[string]any{"op": ">="}}}
	if !ge.BaseMeets(8, 7) || ge.BaseMeets(6, 7) {
		t.Error("ge base op should be >=")
	}
}

func TestCepheusInheritsAndOverrides(t *testing.T) {
	cep, err := Load("cepheus", "")
	if err != nil {
		t.Fatalf("load cepheus: %v", err)
	}
	if m, _ := cep.ModuleFor("extensions"); m != "none" {
		t.Errorf("cepheus extensions module = %q, want none", m)
	}
	if m, _ := cep.ModuleFor("climate"); m != "t5" {
		t.Errorf("cepheus climate module = %q, want t5 (inherited)", m)
	}
	if cep.Starport(2) != "X" || cep.Starport(12) != "A" {
		t.Error("cepheus starport should be high=best")
	}
	if th, ok := cep.BaseThreshold("naval", "A"); !ok || th != 8 {
		t.Errorf("cepheus naval/A = %d, want 8", th)
	}
	if _, ok := cep.BaseThreshold("depot", "A"); ok {
		t.Error("cepheus should have no depot base")
	}
	// classic trade set has no Ht
	codes := cep.TradeCodes(map[string]any{"size": 7, "atmo": 6, "hydro": 6, "pop": 6, "gov": 5, "law": 5, "tech": 15, "port": "A", "temp": "T"})
	for _, c := range codes {
		if c == "Ht" {
			t.Error("cepheus trade codes should not include Ht")
		}
	}
}

func TestDeepMergeBangReplaces(t *testing.T) {
	base := map[string]any{"x": map[string]any{"a": 1, "b": 2}}
	child := map[string]any{"x!": map[string]any{"a": 9}}
	merged := deepMerge(base, child)
	got, _ := merged["x"].(map[string]any)
	if len(got) != 1 || toInt(got["a"]) != 9 {
		t.Errorf("x! should replace wholesale, got %v", got)
	}
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
