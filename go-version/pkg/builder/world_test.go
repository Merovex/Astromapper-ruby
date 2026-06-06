package builder

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"astromapper/pkg/rng"
	"astromapper/pkg/rules"
)

// genSector deterministically builds n single-column volumes under a ruleset and
// returns the non-empty system lines joined — enough to exercise the whole
// ruleset-driven world pipeline (UWP, trade, tech, bases, extensions, climate).
func genSector(t *testing.T, rulesetName, seed string, n int) string {
	t.Helper()
	rs, err := rules.Load(rulesetName, "")
	if err != nil {
		t.Fatalf("load %s: %v", rulesetName, err)
	}
	SetRuleset(rs)
	SetSophonts("")
	r := rng.New(seed)
	var lines []string
	for col := 1; col <= n; col++ {
		v := BuildVolume(col, 1, nil, r)
		if !v.IsEmpty() {
			lines = append(lines, v.ToASCII())
		}
	}
	return strings.Join(lines, "\n")
}

func TestWorldGoldenT5(t *testing.T) {
	got := genSector(t, "t5", "go-golden", 60)
	golden := filepath.Join("testdata", "world_t5.txt")
	if os.Getenv("UPDATE_GOLDEN") != "" {
		if err := os.MkdirAll("testdata", 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(golden, []byte(got), 0o644); err != nil {
			t.Fatal(err)
		}
		t.Skip("regenerated " + golden)
	}
	want, err := os.ReadFile(golden)
	if err != nil {
		t.Fatalf("missing golden master (run with UPDATE_GOLDEN=1 to create): %v", err)
	}
	if string(want) != got {
		t.Error("t5 world output drifted from the golden master (UPDATE_GOLDEN=1 if intended)")
	}
}

func TestWorldReproducible(t *testing.T) {
	if a, b := genSector(t, "t5", "rep", 40), genSector(t, "t5", "rep", 40); a != b {
		t.Error("same seed should reproduce identical output")
	}
}

func TestCepheusDiffersAndHasNoExtensions(t *testing.T) {
	t5 := genSector(t, "t5", "cmp", 40)
	cep := genSector(t, "cepheus", "cmp", 40)
	if t5 == cep {
		t.Error("cepheus should produce a different map than t5 from the same seed")
	}
	if strings.Contains(cep, "RU:") {
		t.Error("cepheus (extensions: none) should have no Ix/Ex/Cx/RU block")
	}
	if !strings.Contains(t5, "RU:") {
		t.Error("t5 should include the extensions block")
	}
}
