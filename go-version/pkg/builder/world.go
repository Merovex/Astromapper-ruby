package builder

import (
	"astromapper/pkg/models"
	"astromapper/pkg/rng"
)

func BuildWorld(star *models.Star, orbitNum int, r *rng.RNG) *models.World {
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
	
	world.Size = r.TwoD6() - 1
	world.Atmosphere = generateAtmosphere(world.Size, r)
	
	tempDice := r.TwoD6() + getAtmoTempMod(world.Atmosphere)
	world.Temperature = getTemperature(tempDice)
	
	world.Hydro = generateHydrographics(world.Size, world.Atmosphere, world.Zone == 0, world.Temperature, r)
	
	world.Population = r.D6()
	if world.Size < 3 || world.Size > 9 {
		world.Population--
	}
	world.Population += getAtmoPopMod(world.Atmosphere)
	if world.Population < 0 {
		world.Population = 0
	}
	
	world.Government = r.TwoD6() - 7 + world.Population
	if world.Government < 0 {
		world.Government = 0
	}
	if world.Government > 15 {
		world.Government = 15
	}
	
	world.Law = r.TwoD6() - 7 + world.Government
	if world.Law < 0 {
		world.Law = 0
	}
	if world.Law > 15 {
		world.Law = 15
	}
	
	world.Port = generatePort(world.Population, r)
	
	world.Tech = generateTech(world, r)
	
	world.Factions = generateFactions(world.Population, world.Law, r)
	
	world.TradeCodes = generateTradeCodes(world)
	
	world.Bases = generateBases(world.Port, r)
	
	world.TravelCode = generateTravelCode(world.Government, world.Law)
	
	numMoons := r.D6() - 3
	if numMoons > 0 {
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

func generateAtmosphere(size int, r *rng.RNG) int {
	atmo := r.D6()
	if size < 3 {
		return 0
	}
	if size >= 3 && size <= 4 && atmo >= 3 && atmo <= 5 {
		return 1
	}
	if size >= 3 && size <= 4 && atmo > 5 {
		return 10
	}
	return atmo
}

func getAtmoTempMod(atmo int) int {
	mods := []int{0, 0, -2, -2, -1, -1, 0, 0, 1, 1, 2, 6, 6, 2, -1, 2}
	if atmo < len(mods) {
		return mods[atmo]
	}
	return 0
}

func getTemperature(dice int) string {
	temps := []string{"F", "F", "F", "C", "C", "T", "T", "T", "T", "T", "H", "H", "R", "R", "R", "R", "R"}
	if dice < 0 {
		return "F"
	}
	if dice >= len(temps) {
		return "R"
	}
	return temps[dice]
}

func generateHydrographics(size, atmo int, inBiozone bool, temp string, r *rng.RNG) int {
	if size < 2 || !inBiozone {
		return 0
	}
	
	var hydro int
	if atmo == 0 || atmo == 1 || atmo >= 10 && atmo <= 12 {
		hydro = r.TwoD6() - 11 + size
	} else {
		hydro = r.TwoD6() - 7 + size
	}
	
	if temp == "H" {
		hydro -= 2
	}
	if temp == "R" {
		hydro -= 6
	}
	
	if hydro < 0 {
		hydro = 0
	}
	if hydro > 10 {
		hydro = 10
	}
	
	return hydro
}

func getAtmoPopMod(atmo int) int {
	mods := []int{-1, -1, -1, -1, -1, 1, 1, -1, 1, -1, -1, -1, -1, -1, -1, -1}
	if atmo < len(mods) {
		return mods[atmo]
	}
	return -1
}

func generatePort(pop int, r *rng.RNG) string {
	portRoll := r.TwoD6() - 7 + pop
	switch {
	case portRoll <= 2:
		return "X"
	case portRoll <= 4:
		return "E"
	case portRoll <= 6:
		return "D"
	case portRoll <= 8:
		return "C"
	case portRoll <= 10:
		return "B"
	default:
		return "A"
	}
}

func generateTech(w *models.World, r *rng.RNG) int {
	tekDM := 0
	
	portMods := map[string]int{"A": 6, "B": 4, "C": 2, "D": 0, "E": 0, "X": -4}
	if mod, ok := portMods[w.Port]; ok {
		tekDM += mod
	}
	
	sizeMods := []int{2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	if w.Size < len(sizeMods) {
		tekDM += sizeMods[w.Size]
	}
	
	atmoMods := []int{1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1}
	if w.Atmosphere < len(atmoMods) {
		tekDM += atmoMods[w.Atmosphere]
	}
	
	hydroMods := []int{1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2}
	if w.Hydro < len(hydroMods) {
		tekDM += hydroMods[w.Hydro]
	}
	
	popMods := []int{0, 1, 1, 1, 1, 1, 0, 0, 0, 1, 2, 3, 4}
	if w.Population < len(popMods) {
		tekDM += popMods[w.Population]
	}
	
	govMods := []int{1, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, -2, -2, 0}
	if w.Government < len(govMods) {
		tekDM += govMods[w.Government]
	}
	
	tech := r.D6() + tekDM
	
	tekLimits := []int{8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 9, 10, 5, 5, 5}
	if w.Atmosphere < len(tekLimits) && tech > tekLimits[w.Atmosphere] {
		tech = tekLimits[w.Atmosphere]
	}
	
	if tech < 0 {
		tech = 0
	}
	
	return tech
}

func generateFactions(pop, law int, r *rng.RNG) []string {
	if pop == 0 {
		return []string{}
	}
	
	numFactions := r.Roll(1, 3)
	if numFactions < 3 {
		numFactions = 3
	}
	
	if law == 0 || law == 7 {
		numFactions++
	}
	if law > 9 {
		numFactions--
	}
	
	factionTypes := []string{"O", "O", "O", "O", "F", "F", "M", "M", "N", "N", "S", "S", "P"}
	factions := make([]string, numFactions)
	for i := 0; i < numFactions; i++ {
		factions[i] = factionTypes[r.TwoD6()]
	}
	
	return factions
}

func generateTradeCodes(w *models.World) []string {
	codes := []string{}
	
	if w.Atmosphere >= 4 && w.Atmosphere <= 9 && w.Hydro >= 4 && w.Hydro <= 8 && w.Population >= 5 && w.Population <= 7 {
		codes = append(codes, "Ag")
	}
	
	if w.Size == 0 && w.Atmosphere == 0 && w.Hydro == 0 {
		codes = append(codes, "As")
	}
	
	if w.Population == 0 && w.Government == 0 && w.Law == 0 {
		codes = append(codes, "Ba")
	}
	
	if w.Atmosphere >= 2 && w.Hydro == 0 {
		codes = append(codes, "De")
	}
	
	if w.Atmosphere >= 10 && w.Hydro >= 1 {
		codes = append(codes, "Fl")
	}
	
	if w.Size >= 5 && (w.Atmosphere == 4 || w.Atmosphere == 5 || w.Atmosphere == 6 || w.Atmosphere == 7 || w.Atmosphere == 8 || w.Atmosphere == 9) && w.Hydro >= 4 && w.Hydro <= 9 {
		codes = append(codes, "Ga")
	}
	
	if w.Population >= 9 {
		codes = append(codes, "Hi")
	}
	
	if w.Tech >= 12 {
		codes = append(codes, "Ht")
	}
	
	if w.Atmosphere <= 1 && w.Hydro >= 1 {
		codes = append(codes, "Ic")
	}
	
	if (w.Atmosphere == 0 || w.Atmosphere == 1 || w.Atmosphere == 2 || w.Atmosphere == 4 || w.Atmosphere == 7 || w.Atmosphere == 9) && w.Population >= 9 {
		codes = append(codes, "In")
	}
	
	if w.Population >= 1 && w.Population <= 3 {
		codes = append(codes, "Lo")
	}
	
	if w.Tech <= 5 {
		codes = append(codes, "Lt")
	}
	
	if (w.Atmosphere >= 0 && w.Atmosphere <= 3) && w.Hydro >= 0 && w.Hydro <= 3 && w.Population >= 6 {
		codes = append(codes, "Na")
	}
	
	if w.Population >= 4 && w.Population <= 6 {
		codes = append(codes, "Ni")
	}
	
	if w.Atmosphere >= 2 && w.Atmosphere <= 5 && w.Hydro >= 0 && w.Hydro <= 3 {
		codes = append(codes, "Po")
	}
	
	if (w.Atmosphere == 6 || w.Atmosphere == 8) && w.Population >= 6 && w.Population <= 8 {
		codes = append(codes, "Ri")
	}
	
	if w.Hydro == 10 {
		codes = append(codes, "Wa")
	}
	
	if w.Atmosphere == 0 {
		codes = append(codes, "Va")
	}
	
	return codes
}

func generateBases(port string, r *rng.RNG) string {
	bases := ""
	
	switch port {
	case "A":
		if r.TwoD6() >= 8 {
			bases += "N"
		}
		if r.TwoD6() >= 10 {
			bases += "S"
		}
	case "B":
		if r.TwoD6() >= 8 {
			bases += "N"
		}
		if r.TwoD6() >= 9 {
			bases += "S"
		}
	case "C":
		if r.TwoD6() >= 8 {
			bases += "S"
		}
	case "D":
		if r.TwoD6() >= 7 {
			bases += "S"
		}
	}
	
	if r.TwoD6() >= 10 {
		bases += "R"
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
	moons := make([]models.Moon, num)
	for i := 0; i < num; i++ {
		moons[i] = models.Moon{
			Planet: planet,
			Orbit:  i,
			Size:   r.D6() - 3,
			Atmo:   0,
			Hydro:  0,
		}
		if moons[i].Size < 0 {
			moons[i].Size = 0
		}
	}
	return moons
}