package models

import (
	"encoding/json"
	"math"
)

// Custom JSON marshaling for Star to handle Orbit interface slice
func (s *Star) MarshalJSON() ([]byte, error) {
	type Alias Star
	type OrbitJSON struct {
		Type       string          `json:"type"`
		Data       json.RawMessage `json:"data"`
	}
	
	// Convert Orbits slice to JSON-friendly format
	orbitsJSON := make([]OrbitJSON, 0, len(s.Orbits))
	for _, orbit := range s.Orbits {
		var orbitType string
		var data []byte
		var err error
		
		switch o := orbit.(type) {
		case *EmptyOrbit:
			orbitType = "empty"
			// Round AU to 1 decimal place
			rounded := *o
			rounded.AU = math.Round(o.AU*10) / 10
			data, err = json.Marshal(&rounded)
		case *Belt:
			orbitType = "belt"
			// Round AU to 1 decimal place
			rounded := *o
			rounded.AU = math.Round(o.AU*10) / 10
			data, err = json.Marshal(&rounded)
		case *Rockball:
			orbitType = "rockball"
			// Round AU to 1 decimal place
			rounded := *o
			rounded.AU = math.Round(o.AU*10) / 10
			data, err = json.Marshal(&rounded)
		case *Hostile:
			orbitType = "hostile"
			// Round AU to 1 decimal place
			rounded := *o
			rounded.AU = math.Round(o.AU*10) / 10
			data, err = json.Marshal(&rounded)
		case *GasGiant:
			orbitType = "gas_giant"
			// Round AU to 1 decimal place
			rounded := *o
			rounded.AU = math.Round(o.AU*10) / 10
			data, err = json.Marshal(&rounded)
		case *World:
			orbitType = "world"
			// Round AU to 1 decimal place
			rounded := *o
			rounded.AU = math.Round(o.AU*10) / 10
			data, err = json.Marshal(&rounded)
		case *Companion:
			orbitType = "companion"
			// Avoid circular reference by creating a simplified version
			compData := struct {
				OrbitNumber int     `json:"orbit_number"`
				AU          float64 `json:"au"`
				StarClass   string  `json:"star_classification"`
			}{
				OrbitNumber: o.OrbitNumber,
				AU:          math.Round(o.AU*10) / 10, // Round to 1 decimal place
				StarClass:   o.CompanionStar.Classification(),
			}
			data, err = json.Marshal(compData)
		default:
			continue
		}
		
		if err != nil {
			return nil, err
		}
		
		orbitsJSON = append(orbitsJSON, OrbitJSON{
			Type: orbitType,
			Data: data,
		})
	}
	
	// Handle the World field separately to round AU
	var worldData *World
	if s.World != nil {
		rounded := *s.World
		rounded.AU = math.Round(s.World.AU*10) / 10
		worldData = &rounded
	}
	
	// Create a custom struct with the orbits and world replaced
	return json.Marshal(&struct {
		*Alias
		Orbits []OrbitJSON `json:"orbits,omitempty"`
		World  *World      `json:"world,omitempty"`
	}{
		Alias:  (*Alias)(s),
		Orbits: orbitsJSON,
		World:  worldData,
	})
}