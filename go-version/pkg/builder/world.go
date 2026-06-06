package builder

import (
	"astromapper/pkg/models"
	"astromapper/pkg/rng"
)

// BuildWorld generates a mainworld via the active ruleset (Traveller 5 by default).
// The UWP step formulas, trade codes, starport/tech/base tables, and the
// climate/native modules all come from rules/<name>.yml; only the orbital framing
// (zone, AU, moons) is intrinsic to the system. Extensions (Ix/Ex/Cx) are filled in
// later by buildExtensions, once the system's gas-giant and belt counts are known.
func BuildWorld(star *models.Star, orbitNum int, r *rng.RNG) *models.World {
	rs := ruleset()

	world := &models.World{
		BaseOrbit: models.BaseOrbit{
			Star:        star,
			OrbitNumber: orbitNum,
			AU:          star.OrbitToAU(orbitNum),
			Kid:         models.OrbitWorld,
			Port:        "X",
		},
	}

	biozone := star.GetBiozone()
	world.Zone = determineZone(world.AU, biozone)
	world.Distant = world.AU > biozone[1]*10

	// UWP spine — Size / Atmo / Hydro from the ruleset's step formulas.
	ctx := map[string]any{}
	world.Size, _ = rs.UWPStep("size", ctx, r)
	ctx["size"] = world.Size
	world.Atmosphere, _ = rs.UWPStep("atmo", ctx, r)
	ctx["atmo"] = world.Atmosphere
	world.Hydro, _ = rs.UWPStep("hydro", ctx, r)
	ctx["hydro"] = world.Hydro

	world.Temperature = climate(world, r)
	ctx["temp"] = world.Temperature

	// Genre realism pass may thin/dry the atmosphere and hydrographics (opera/firm).
	applyGenreAtmoHydro(world)
	ctx["atmo"], ctx["hydro"] = world.Atmosphere, world.Hydro

	// Population — the port-orientation roll is taken now (firm genre nudges it by pop).
	portRoll := r.TwoD6()
	pop, _ := rs.UWPStep("pop", ctx, r)
	pop, portRoll = firmPopStrip(world, pop, portRoll)
	if pop < 0 {
		pop = 0
	}
	if pop > 15 {
		pop = 15 // population ceiling is F
	}
	pop = capColonyPopulation(world, pop) // hot-star / gravity-band colony cap
	world.Population = pop
	ctx["pop"] = pop

	world.Government, _ = rs.UWPStep("gov", ctx, r)
	ctx["gov"] = world.Government
	world.Law, _ = rs.UWPStep("law", ctx, r)
	ctx["law"] = world.Law

	world.Port = rs.Starport(portRoll)
	ctx["port"] = world.Port

	world.Factions = generateFactions(world.Population, world.Law, r)

	tech := r.D6() + rs.TechDM(ctx)
	if tech < 0 {
		tech = 0
	}
	if tech > 15 {
		tech = 15
	}
	world.Tech = tech
	if world.Population == 0 { // an uninhabited world has no law, government, or tech
		world.Law, world.Government, world.Tech = 0, 0, 0
	}
	ctx["tech"], ctx["gov"], ctx["law"] = world.Tech, world.Government, world.Law

	world.TradeCodes = rs.TradeCodes(ctx)
	world.Bases = generateBases(world.Port, r)
	world.TravelCode = generateTravelCode(world.Government, world.Law)

	if numMoons := r.D6() - 3; numMoons > 0 {
		world.Moons = generateMoons(numMoons, &world.BaseOrbit, r)
	}

	return world
}

func determineZone(au float64, biozone [2]float64) int {
	if au < biozone[0] {
		return -1
	}
	if au > biozone[1] {
		return 1
	}
	return 0
}

// generateFactions mirrors the Ruby model: 1D3 factions (+/- by law level), each a
// type rolled on 2D. (MgT p. 173.)
func generateFactions(pop, law int, r *rng.RNG) []string {
	if pop == 0 {
		return []string{}
	}
	count := r.Roll(1, 3)
	if count > 3 {
		count = 3
	}
	if law == 0 || law == 7 {
		count++
	}
	if law > 9 {
		count--
	}
	if count < 0 {
		count = 0
	}
	types := []string{"O", "O", "O", "O", "F", "F", "M", "M", "N", "N", "S", "S", "P"}
	rolls := []int{r.TwoD6(), r.TwoD6(), r.TwoD6(), r.TwoD6(), r.TwoD6()}
	factions := []string{}
	for i := 0; i < count && i < len(rolls); i++ {
		factions = append(factions, types[rolls[i]])
	}
	return factions
}

// generateBases rolls each base the ruleset allows for this starport, in order
// (naval, scout, depot, way), using the ruleset's comparison direction.
func generateBases(port string, r *rng.RNG) string {
	rs := ruleset()
	bases := ""
	for _, b := range []struct{ kind, letter string }{
		{"naval", "N"}, {"scout", "S"}, {"depot", "D"}, {"way", "W"},
	} {
		if th, ok := rs.BaseThreshold(b.kind, port); ok && rs.BaseMeets(r.TwoD6(), th) {
			bases += b.letter
		}
	}
	if bases == "" {
		bases = "."
	}
	return bases
}

func generateTravelCode(gov, law int) string {
	if (gov == 0 && law == 0) || law >= 9 {
		return "A"
	}
	return "."
}

func generateMoons(num int, planet *models.BaseOrbit, r *rng.RNG) []models.Moon {
	// Orbit tables from the Ruby code.
	closeOrbits := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
	ringOrbits := []int{1, 1, 1, 2, 2, 3}
	farOrbits := make([]int, len(closeOrbits))
	extremeOrbits := make([]int, len(closeOrbits))
	for i := range closeOrbits {
		farOrbits[i] = closeOrbits[i] * 5
		extremeOrbits[i] = closeOrbits[i] * 25
	}

	moons := make([]models.Moon, num)
	for i := 0; i < num; i++ {
		size := r.D6() - 3
		if size < 0 {
			size = 0
		}

		orbitRoll := r.TwoD6() + i
		var orbitalRadius int

		switch {
		case size < 1:
			idx := r.D6() - 1
			if idx >= len(ringOrbits) {
				idx = len(ringOrbits) - 1
			}
			orbitalRadius = ringOrbits[idx]
		case orbitRoll == 12 && planet.Kid == models.OrbitGasGiant:
			idx := r.TwoD6()
			if idx >= len(extremeOrbits) {
				idx = len(extremeOrbits) - 1
			}
			orbitalRadius = extremeOrbits[idx]
		case orbitRoll < 8:
			idx := r.TwoD6()
			if idx >= len(closeOrbits) {
				idx = len(closeOrbits) - 1
			}
			orbitalRadius = closeOrbits[idx]
		default:
			idx := r.TwoD6()
			if idx >= len(farOrbits) {
				idx = len(farOrbits) - 1
			}
			orbitalRadius = farOrbits[idx]
		}

		moons[i] = models.Moon{
			Planet:        planet,
			Orbit:         i,
			OrbitalRadius: orbitalRadius,
			Size:          size,
			Atmo:          0,
			Hydro:         0,
		}
	}
	return moons
}
