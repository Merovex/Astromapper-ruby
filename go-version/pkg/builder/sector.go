package builder

import (
	"astromapper/pkg/models"
	"astromapper/pkg/rng"
)

func BuildSector(name string, width, height int, density float64, names []string, r *rng.RNG) *models.Sector {
	sector := models.NewSector(name, width, height)
	
	for row := 0; row < height; row++ {
		for col := 0; col < width; col++ {
			if r.Float64() < density {
				volume := BuildVolume(col+1, row+1, names, r)
				if !volume.IsEmpty() {
					sector.SetVolume(col, row, volume)
				}
			}
		}
	}
	
	return sector
}