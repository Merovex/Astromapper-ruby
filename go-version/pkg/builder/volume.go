package builder

import (
	"astromapper/pkg/models"
	"astromapper/pkg/rng"
	"fmt"
)

func BuildVolume(col, row int, names []string, r *rng.RNG) *models.Volume {
	volume := &models.Volume{
		Column: col,
		Row:    row,
	}
	
	if len(names) > 0 {
		volume.Name = names[r.Intn(len(names))]
	} else {
		volume.Name = fmt.Sprintf("%02d%02d", col, row)
	}
	
	volume.Star = BuildStar(volume, nil, 0, r)
	
	companionRoll := r.TwoD6()
	companionCounts := []int{0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2}
	numCompanions := 0
	if companionRoll < len(companionCounts) {
		numCompanions = companionCounts[companionRoll]
	}
	
	for i := 0; i < numCompanions; i++ {
		companion := BuildStar(volume, volume.Star, i, r)
		volume.Star.Companions = append(volume.Star.Companions, companion)
		clearForbiddenOrbits(volume.Star, companion, r)
	}
	
	return volume
}

func clearForbiddenOrbits(primary, companion *models.Star, r *rng.RNG) {
	companionAU := primary.OrbitToAU(companion.Orbit)
	innerOrbit := primary.AUToOrbit(companionAU * 0.67)
	outerOrbit := primary.AUToOrbit(companionAU * 3)
	
	newOrbits := []models.Orbit{}
	for i, orbit := range primary.Orbits {
		if i < innerOrbit || i > outerOrbit {
			newOrbits = append(newOrbits, orbit)
		}
	}
	
	companionOrbit := &models.Companion{
		BaseOrbit: models.BaseOrbit{
			Star:        primary,
			OrbitNumber: companion.Orbit,
			AU:          companionAU,
			Kid:         models.OrbitCompanion,
		},
		CompanionStar: companion,
	}
	
	inserted := false
	finalOrbits := []models.Orbit{}
	for _, orbit := range newOrbits {
		if !inserted && orbit.GetOrbitNumber() > companion.Orbit {
			finalOrbits = append(finalOrbits, companionOrbit)
			inserted = true
		}
		finalOrbits = append(finalOrbits, orbit)
	}
	if !inserted {
		finalOrbits = append(finalOrbits, companionOrbit)
	}
	
	primary.Orbits = finalOrbits
	
	for i, orbit := range primary.Orbits {
		if base, ok := orbit.(*models.BaseOrbit); ok {
			base.OrbitNumber = i
			base.AU = primary.OrbitToAU(i)
		}
	}
}