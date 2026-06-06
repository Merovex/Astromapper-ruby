package builder

import (
	"testing"

	"astromapper/pkg/models"
	"astromapper/pkg/rng"
	"astromapper/pkg/rules"
)

// Genre is the realism<->romance stellar slider: opera (Sun-like T5 table) is far
// more F/G/K than the M-dwarf-heavy normal/firm; firm is the realistic galaxy.
// Mirrors the Ruby test_genre_stellar_model.
func TestGenreStellarModel(t *testing.T) {
	rs, err := rules.Load("t5", "")
	if err != nil {
		t.Fatal(err)
	}
	SetRuleset(rs)
	SetSophonts("")

	census := func(genre string) (fgk, m float64) {
		SetGenre(genre)
		r := rng.New("genre-" + genre)
		fgkN, mN, total := 0, 0, 0
		for i := 0; i < 200; i++ {
			v := &models.Volume{Column: (i % 32) + 1, Row: (i / 32) + 1}
			star := BuildStar(v, nil, 0, r)
			total++
			switch star.StarType {
			case "F", "G", "K":
				fgkN++
			case "M":
				mN++
			}
		}
		return float64(fgkN) / float64(total), float64(mN) / float64(total)
	}

	operaFGK, _ := census("opera")
	normalFGK, _ := census("normal")
	firmFGK, firmM := census("firm")

	if !(operaFGK > normalFGK) {
		t.Errorf("opera FGK %.2f should exceed normal %.2f", operaFGK, normalFGK)
	}
	if !(operaFGK > firmFGK) {
		t.Errorf("opera FGK %.2f should exceed firm %.2f", operaFGK, firmFGK)
	}
	if firmM <= 0.5 {
		t.Errorf("firm should be M-dwarf-heavy, got M fraction %.2f", firmM)
	}
}
