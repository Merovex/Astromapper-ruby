package models

import "fmt"

type Moon struct {
	Planet *BaseOrbit `json:"-"`
	Orbit  int        `json:"orbit"`
	Size   int        `json:"size"`
	Atmo   int        `json:"atmosphere"`
	Hydro  int        `json:"hydrographics"`
}

func (m *Moon) ToASCII() string {
	return fmt.Sprintf("\n     -- Moon %d: Size %s Atmo %s Hydro %s",
		m.Orbit+1,
		toHex(m.Size),
		toHex(m.Atmo),
		toHex(m.Hydro))
}