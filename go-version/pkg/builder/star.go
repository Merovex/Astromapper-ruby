package builder

import (
	"astromapper/pkg/models"
	"astromapper/pkg/rng"
	"math"
)

var BodeRatios = []float64{0.3, 0.3, 0.3, 0.3, 0.35, 0.35, 0.35, 0.4, 0.4, 0.4, 0.4}
var CompanionSeparation = []float64{
	0.05, 0.05, 0.5, 0.5, 0.5, 2.0, 2.0, 10.0, 10.0, 10.0,
	50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0, 50.0,
}

var SpectralTypes = map[models.StarType][]int{
	"O": {9},
	"B": {0, 2, 5, 8},
	"A": {0, 2, 5},
	"F": {0, 2, 5},
	"G": {0, 2, 5, 8},
	"K": {0, 2, 5},
	"M": {0, 2, 4, 6},
}

func BuildStar(volume *models.Volume, primary *models.Star, ternary int, r *rng.RNG) *models.Star {
	star := &models.Star{
		Volume:     volume,
		Primary:    primary,
		Companions: []*models.Star{},
		Orbits:     []models.Orbit{},
	}
	
	if primary == nil {
		star.Orbit = 0
		star.TypeDM = min(r.TwoD6()+getStarDM(volume), 12)
		star.SizeDM = min(r.TwoD6(), 12)
		
		starTypes := []models.StarType{"B", "B", "A", "M", "M", "M", "M", "M", "K", "G", "F", "F", "F"}
		star.StarType = starTypes[star.TypeDM]
		
		starSizes := []int{0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 5, 6, 500}
		star.StarSize = starSizes[star.SizeDM]
	} else {
		separationIndex := r.ThreeD6() + (4 * ternary) - 2
		// Ensure index is within bounds (0-19)
		if separationIndex >= len(CompanionSeparation) {
			separationIndex = len(CompanionSeparation) - 1
		}
		if separationIndex < 0 {
			separationIndex = 0
		}
		separation := float64(r.TwoD6()) * CompanionSeparation[separationIndex]
		separation = math.Round(separation*100) / 100
		
		star.Orbit = star.AUToOrbit(separation) - 1
		
		companionTypes := []models.StarType{"X", "B", "A", "F", "F", "G", "G", "K", "K", "M", "M", "M", "M"}
		star.StarType = companionTypes[min(r.TwoD6()+primary.TypeDM, 12)]
		
		companionSizes := []int{0, 1, 2, 3, 4, 500, 500, 5, 5, 6, 500, 500, 500, 500}
		star.StarSize = companionSizes[min(r.TwoD6()+primary.SizeDM, 12)]
	}
	
	spectralSubtypes := SpectralTypes[star.StarType]
	subtype := spectralSubtypes[r.Intn(len(spectralSubtypes))]
	star.Spectral = string(star.StarType) + string('0'+subtype)
	
	if star.StarSize == 500 {
		star.StarSubtype = "B"
		star.StarType = "D"
	}
	
	if star.StarType == "M" && star.StarSize == 5 {
		star.BodeConstant = 0.2
	} else {
		star.BodeConstant = BodeRatios[r.Intn(len(BodeRatios))]
	}
	
	dm := 0
	if star.StarSize == 3 {
		dm += 4
	}
	if star.StarSize < 3 {
		dm += 8
	}
	if star.StarType == "M" {
		dm -= 4
	}
	if star.StarType == "K" {
		dm -= 2
	}
	
	numOrbits := max(r.TwoD6()+dm, 0)
	for i := 0; i < numOrbits; i++ {
		au := star.OrbitToAU(i)
		if au > star.OuterLimit() {
			break
		}
		
		orbit := populateOrbit(star, i, r)
		star.Orbits = append(star.Orbits, orbit)
		
		if world, ok := orbit.(*models.World); ok {
			star.World = world
		}
	}
	
	if star.World != nil {
		hasGasGiant := false
		for _, orbit := range star.Orbits {
			if orbit.GetKid() == models.OrbitGasGiant {
				hasGasGiant = true
				break
			}
		}
		if hasGasGiant {
			star.World.GasGiant = "G"
		} else {
			star.World.GasGiant = "."
		}
	}
	
	pruneOrbits(star)
	
	return star
}

func populateOrbit(star *models.Star, orbitNum int, r *rng.RNG) models.Orbit {
	au := star.OrbitToAU(orbitNum)
	biozone := star.GetBiozone()
	
	if au < star.InnerLimit() {
		return &models.EmptyOrbit{
			BaseOrbit: models.BaseOrbit{
				Star:        star,
				OrbitNumber: orbitNum,
				AU:          au,
				Kid:         models.OrbitEmpty,
			},
		}
	}
	
	zone := 0
	if au < biozone[0] {
		zone = -1
	} else if au > biozone[1] {
		zone = 1
	}
	
	distant := au > biozone[1]*10
	
	if zone == 0 {
		return populateBiozone(star, orbitNum, r)
	} else if zone < 0 {
		return populateInner(star, orbitNum, au, zone, distant, r)
	} else {
		return populateOuter(star, orbitNum, au, zone, distant, r)
	}
}

func populateBiozone(star *models.Star, orbitNum int, r *rng.RNG) models.Orbit {
	return BuildWorld(star, orbitNum, r)
}

func populateInner(star *models.Star, orbitNum int, au float64, zone int, distant bool, r *rng.RNG) models.Orbit {
	roll := r.TwoD6()
	
	base := models.BaseOrbit{
		Star:        star,
		OrbitNumber: orbitNum,
		AU:          au,
		Zone:        zone,
		Distant:     distant,
	}
	
	switch {
	case roll < 5:
		base.Kid = models.OrbitEmpty
		return &models.EmptyOrbit{BaseOrbit: base}
	case roll >= 5 && roll <= 6:
		base.Kid = models.OrbitHostile
		hostile := &models.Hostile{BaseOrbit: base}
		hostile.Atmosphere = []int{10, 11, 12, 13, 14}[r.Intn(5)]
		hostile.Hydro = r.TwoD6() - 4
		if hostile.Hydro < 0 {
			hostile.Hydro = 0
		}
		return hostile
	case roll >= 7 && roll <= 9:
		base.Kid = models.OrbitRockball
		return &models.Rockball{BaseOrbit: base}
	case roll >= 10 && roll <= 11:
		base.Kid = models.OrbitBelt
		return &models.Belt{BaseOrbit: base}
	default:
		base.Kid = models.OrbitGasGiant
		gg := &models.GasGiant{BaseOrbit: base}
		if r.D6() < 4 {
			gg.GiantSize = "S"
		} else {
			gg.GiantSize = "L"
		}
		return gg
	}
}

func populateOuter(star *models.Star, orbitNum int, au float64, zone int, distant bool, r *rng.RNG) models.Orbit {
	roll := r.D6()
	if distant {
		roll++
	}
	
	base := models.BaseOrbit{
		Star:        star,
		OrbitNumber: orbitNum,
		AU:          au,
		Zone:        zone,
		Distant:     distant,
	}
	
	switch {
	case roll == 1:
		base.Kid = models.OrbitRockball
		return &models.Rockball{BaseOrbit: base}
	case roll == 2:
		base.Kid = models.OrbitBelt
		return &models.Belt{BaseOrbit: base}
	case roll == 3:
		base.Kid = models.OrbitEmpty
		return &models.EmptyOrbit{BaseOrbit: base}
	case roll >= 4 && roll <= 7:
		base.Kid = models.OrbitGasGiant
		gg := &models.GasGiant{BaseOrbit: base}
		if r.D6() < 4 {
			gg.GiantSize = "S"
		} else {
			gg.GiantSize = "L"
		}
		numMoons := r.TwoD6()
		if gg.GiantSize == "S" {
			numMoons = max(numMoons-4, 0)
		}
		if numMoons > 0 {
			gg.Moons = generateMoons(numMoons, &gg.BaseOrbit, r)
		}
		return gg
	default:
		base.Kid = models.OrbitRockball
		return &models.Rockball{BaseOrbit: base}
	}
}

func pruneOrbits(star *models.Star) {
	lastNonEmpty := -1
	for i := len(star.Orbits) - 1; i >= 0; i-- {
		if star.Orbits[i].GetKid() != models.OrbitEmpty {
			lastNonEmpty = i
			break
		}
	}
	
	if lastNonEmpty >= 0 {
		star.Orbits = star.Orbits[:lastNonEmpty+1]
	}
	
	for i := range star.Orbits {
		if orbit, ok := star.Orbits[i].(*models.BaseOrbit); ok {
			orbit.OrbitNumber = i
			orbit.AU = star.OrbitToAU(i)
		}
	}
}

func getStarDM(volume *models.Volume) int {
	return 0
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}