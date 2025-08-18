package models

import (
	"fmt"
)

type OrbitType string

const (
	OrbitEmpty     OrbitType = "."
	OrbitBelt      OrbitType = "B"
	OrbitRockball  OrbitType = "R"
	OrbitHostile   OrbitType = "H"
	OrbitGasGiant  OrbitType = "G"
	OrbitWorld     OrbitType = "W"
	OrbitCompanion OrbitType = "S"
)

type Orbit interface {
	GetOrbitNumber() int
	GetAU() float64
	GetKid() OrbitType
	GetUWP() string
	IsWorld() bool
	ToASCII() string
}

type BaseOrbit struct {
	Star        *Star     `json:"-"`
	OrbitNumber int       `json:"orbit_number"`
	AU          float64   `json:"au"`
	Kid         OrbitType `json:"orbit_type"`
	Zone        int       `json:"zone"`
	Distant     bool      `json:"distant"`
	Port        string    `json:"starport"`
	Size        int       `json:"size"`
	Atmosphere  int       `json:"atmosphere"`
	Hydro       int       `json:"hydrographics"`
	Population  int       `json:"population"`
	Government  int       `json:"government"`
	Law         int       `json:"law_level"`
	Tech        int       `json:"tech_level"`
	Moons       []Moon    `json:"moons,omitempty"`
}

func (o *BaseOrbit) GetOrbitNumber() int { return o.OrbitNumber }
func (o *BaseOrbit) GetAU() float64      { return o.AU }
func (o *BaseOrbit) GetKid() OrbitType   { return o.Kid }
func (o *BaseOrbit) IsWorld() bool       { return o.Kid == OrbitWorld }

func (o *BaseOrbit) GetUWP() string {
	if o.Kid == "." {
		return ".......-."
	}
	return fmt.Sprintf("%s%s%s%s%s%s%s-%s",
		o.Port,
		toHex(o.Size),
		toHex(o.Atmosphere),
		toHex(o.Hydro),
		toHex(o.Population),
		toHex(o.Government),
		toHex(o.Law),
		toHex(o.Tech))
}

func (o *BaseOrbit) ToASCII() string {
	bio := " "
	if o.Zone == 0 {
		bio = "*"
	}
	if o.AU > o.Star.OuterLimit() {
		bio = "-"
	}
	output := fmt.Sprintf("  -- %2d. %s  %s // %s // %4.1f au",
		o.OrbitNumber+1, bio, o.Kid, o.GetUWP(), o.AU)
	
	for _, moon := range o.Moons {
		output += moon.ToASCII()
	}
	return output
}

func (o *BaseOrbit) IsInner() bool   { return o.Zone < 0 }
func (o *BaseOrbit) IsOuter() bool   { return o.Zone > 0 }
func (o *BaseOrbit) IsBiozone() bool { return o.Zone == 0 }
func (o *BaseOrbit) IsDistant() bool { return o.Distant }
func (o *BaseOrbit) IsLimit() bool   { return o.AU < o.Star.InnerLimit() }

type EmptyOrbit struct {
	BaseOrbit
}

type Belt struct {
	BaseOrbit
}

func (b *Belt) GetUWP() string {
	return "XR00000-0"
}

type Rockball struct {
	BaseOrbit
}

type Hostile struct {
	BaseOrbit
}

type GasGiant struct {
	BaseOrbit
	GiantSize string `json:"giant_size"`
}

func (g *GasGiant) GetUWP() string {
	if g.GiantSize == "S" {
		return "Small GG "
	}
	return "Large GG "
}

type World struct {
	BaseOrbit
	Temperature string   `json:"temperature"`
	Factions    []string `json:"factions,omitempty"`
	GasGiant    string   `json:"gas_giant,omitempty"`
	TradeCodes  []string `json:"trade_codes,omitempty"`
	Bases       string   `json:"bases,omitempty"`
	TravelCode  string   `json:"travel_code,omitempty"`
}

func (w *World) GetUWP() string {
	return fmt.Sprintf("%s%s%s%s%s%s%s-%s",
		w.Port,
		toHex(w.Size),
		toHex(w.Atmosphere),
		toHex(w.Hydro),
		toHex(w.Population),
		toHex(w.Government),
		toHex(w.Law),
		toHex(w.Tech))
}

type Companion struct {
	BaseOrbit
	CompanionStar *Star
}

func (c *Companion) GetUWP() string {
	return fmt.Sprintf("%-9s", c.CompanionStar.Classification())
}

func toHex(n int) string {
	if n < 0 {
		return "0"
	}
	if n < 10 {
		return fmt.Sprintf("%d", n)
	}
	hexMap := map[int]string{
		10: "A", 11: "B", 12: "C", 13: "D", 14: "E", 15: "F",
	}
	if h, ok := hexMap[n]; ok {
		return h
	}
	return "F"
}