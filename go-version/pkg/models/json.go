package models

import (
	"encoding/json"
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
			data, err = json.Marshal(o)
		case *Belt:
			orbitType = "belt"
			data, err = json.Marshal(o)
		case *Rockball:
			orbitType = "rockball"
			data, err = json.Marshal(o)
		case *Hostile:
			orbitType = "hostile"
			data, err = json.Marshal(o)
		case *GasGiant:
			orbitType = "gas_giant"
			data, err = json.Marshal(o)
		case *World:
			orbitType = "world"
			data, err = json.Marshal(o)
		case *Companion:
			orbitType = "companion"
			// Avoid circular reference by creating a simplified version
			compData := struct {
				OrbitNumber int    `json:"orbit_number"`
				AU          float64 `json:"au"`
				StarClass   string  `json:"star_classification"`
			}{
				OrbitNumber: o.OrbitNumber,
				AU:          o.AU,
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
	
	// Create a custom struct with the orbits replaced
	return json.Marshal(&struct {
		*Alias
		Orbits []OrbitJSON `json:"orbits,omitempty"`
	}{
		Alias:  (*Alias)(s),
		Orbits: orbitsJSON,
	})
}