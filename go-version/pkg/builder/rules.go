package builder

import (
	"strings"

	"astromapper/pkg/models"
	"astromapper/pkg/rng"
	"astromapper/pkg/rules"
)

// Package-level generation settings, the Go analog of Ruby's Astromapper.ruleset /
// config globals. Set once before generating a sector (CLI or tests); a single
// sector is generated on one goroutine, so a plain var is sufficient.
var (
	activeRuleset  *rules.Ruleset
	activeSophonts string // "" or "human" = human-only; "varied" allows alien sophonts
)

// SetRuleset selects the active ruleset; SetSophonts the native-life mode.
func SetRuleset(rs *rules.Ruleset) { activeRuleset = rs }
func SetSophonts(s string)         { activeSophonts = strings.ToLower(s) }

// ruleset returns the active ruleset, lazily loading the built-in t5 if none is set.
func ruleset() *rules.Ruleset {
	if activeRuleset == nil {
		rs, err := rules.Load("t5", "")
		if err != nil {
			panic("builder: cannot load default ruleset: " + err.Error())
		}
		activeRuleset = rs
	}
	return activeRuleset
}

// ---- climate slot -------------------------------------------------------

func climate(w *models.World, r *rng.RNG) string {
	mod, _ := ruleset().ModuleFor("climate")
	if mod == "none" {
		return "T"
	}
	return climateT5(w, r) // only t5 implemented; unknown names fall back to t5
}

// climateT5 derives climate from the Habitable-Zone variance (Flux), matching Ruby.
func climateT5(w *models.World, r *rng.RNG) string {
	if w.OrbitNumber <= 1 {
		return "Tz"
	}
	variance := []int{-2, -1, -1, -1, 0, 0, 0, 0, 0, 1, 1, 1, 2}[r.FluxRoll()+6]
	switch {
	case variance <= -1:
		return "H"
	case variance >= 1:
		return "C"
	default:
		return "T"
	}
}

// ---- native slot --------------------------------------------------------

func nativeStatus(w *models.World) string {
	mod, _ := ruleset().ModuleFor("native")
	if mod == "none" {
		return ""
	}
	return nativeStatusT5(w)
}

func nativeStatusT5(w *models.World) string {
	if activeSophonts == "varied" {
		if w.Population >= 7 {
			if w.Atmosphere <= 1 {
				return "Exotic"
			}
			return "Native"
		}
		if w.Population >= 1 && w.Population <= 6 {
			return "Colony"
		}
		return ""
	}
	if w.Population >= 7 {
		return "Settled"
	}
	if w.Population >= 1 && w.Population <= 6 {
		return "Colony"
	}
	return ""
}

// ---- extensions slot ----------------------------------------------------

// buildExtensions runs the ruleset's extensions module (if any), then native status.
// Called as a post-pass once the system's gas-giant and belt counts are known.
func buildExtensions(w *models.World, gasGiants, belts int, r *rng.RNG) {
	mod, _ := ruleset().ModuleFor("extensions")
	if mod != "none" {
		buildExtensionsT5(w, gasGiants, belts, r)
	}
	w.Native = nativeStatus(w)
}

// buildExtensionsT5 computes Ix / Ex / Cx + Resource Units (T5 WorldGen page 435).
func buildExtensionsT5(w *models.World, gasGiants, belts int, r *rng.RNG) {
	tc := w.TradeCodes

	ix := 0
	if w.Port == "A" || w.Port == "B" {
		ix++
	}
	if w.Port == "D" || w.Port == "E" || w.Port == "X" {
		ix--
	}
	if w.Tech >= 10 {
		ix++
	}
	if w.Tech <= 8 {
		ix--
	}
	ix += countAny(tc, "Ag", "Hi", "In", "Ri")
	if w.Population <= 6 {
		ix--
	}
	if hasBase(w.Bases, "N") && hasBase(w.Bases, "S") {
		ix++
	}
	if hasBase(w.Bases, "W") {
		ix++
	}
	w.Ix = ix

	res := r.TwoD6()
	if w.Tech >= 8 {
		res += gasGiants + belts
	}
	lab := w.Population - 1
	if lab < 0 {
		lab = 0
	}
	var inf int
	switch {
	case hasAny(tc, "Ba", "Di", "Lo"):
		inf = 0
	case has(tc, "Ni"):
		inf = r.D6()
	default:
		inf = r.TwoD6() + ix
		if inf < 0 {
			inf = 0
		}
	}
	eff := r.FluxRoll()
	w.Ex = [4]int{res, lab, inf, eff}
	w.RU = nz(res) * nz(lab) * nz(inf) * nz(eff)

	// Cx: Homogeneity, Acceptance, Strangeness, Symbols (each clamped to >= 1).
	homo := min1(w.Population + r.FluxRoll())
	acc := min1(w.Population + ix)
	str := min1(5 + r.FluxRoll())
	sym := min1(w.Tech + r.FluxRoll())
	w.Cx = [4]int{homo, acc, str, sym}

	w.Extended = true
}

func nz(v int) int {
	if v == 0 {
		return 1
	}
	return v
}

func min1(v int) int {
	if v < 1 {
		return 1
	}
	return v
}

func has(list []string, s string) bool {
	for _, x := range list {
		if x == s {
			return true
		}
	}
	return false
}

func hasAny(list []string, ss ...string) bool {
	for _, s := range ss {
		if has(list, s) {
			return true
		}
	}
	return false
}

func countAny(list []string, ss ...string) int {
	n := 0
	for _, s := range ss {
		if has(list, s) {
			n++
		}
	}
	return n
}

func hasBase(bases, letter string) bool { return strings.Contains(bases, letter) }
