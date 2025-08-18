package models

import (
	"fmt"
)

type Volume struct {
	Name      string `json:"name"`
	Column    int    `json:"column"`
	Row       int    `json:"row"`
	Star      *Star  `json:"star,omitempty"`
	GasGiant  string `json:"gas_giant,omitempty"`
}

func (v *Volume) Location() string {
	return fmt.Sprintf("%02d%02d", v.Column, v.Row)
}

func (v *Volume) IsEmpty() bool {
	return v.Star == nil || v.Star.World == nil
}

func (v *Volume) ToASCII() string {
	if v.IsEmpty() {
		return ""
	}
	
	w := v.Star.World
	tradeCodes := joinStrings(w.TradeCodes, " ")
	factions := joinStrings(w.Factions, " ")
	
	bases := w.Bases
	if bases == "" {
		bases = "."
	}
	
	summary := fmt.Sprintf("%-8s %-9s %-4s %-5s %-11s %-12s %-13s %-13s %s",
		v.Location(),
		w.GetUWP(),
		w.Temperature,
		bases,
		tradeCodes,
		factions,
		v.Star.Crib(),
		v.Star.OrbitsCrib(),
		v.Name)
	
	summary += v.Star.OrbitsToASCII()
	return summary
}

func (s *Star) Crib() string {
	stars := []string{s.Classification()}
	for _, comp := range s.Companions {
		stars = append(stars, comp.Classification())
	}
	
	return joinStrings(stars, "/")
}

func (s *Star) OrbitsCrib() string {
	orbits := ""
	for _, o := range s.Orbits {
		orbits += string(o.GetKid())
	}
	return orbits
}

func (s *Star) OrbitsToASCII() string {
	if len(s.Orbits) == 0 {
		return ""
	}
	result := "\n"
	for i, orbit := range s.Orbits {
		if i > 0 {
			result += "\n"
		}
		result += orbit.ToASCII()
	}
	result += "\n"
	return result
}

func joinStrings(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for i := 1; i < len(strs); i++ {
		result += sep + strs[i]
	}
	return result
}