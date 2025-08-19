package models

import (
	"encoding/json"
	"fmt"
	"strings"
)

type Sector struct {
	Name    string      `json:"name"`
	Volumes [][]*Volume `json:"volumes"`
	Width   int         `json:"width"`
	Height  int         `json:"height"`
}

func NewSector(name string, width, height int) *Sector {
	volumes := make([][]*Volume, height)
	for r := 0; r < height; r++ {
		volumes[r] = make([]*Volume, width)
	}
	return &Sector{
		Name:    name,
		Volumes: volumes,
		Width:   width,
		Height:  height,
	}
}

func (s *Sector) SetVolume(col, row int, volume *Volume) {
	if row >= 0 && row < s.Height && col >= 0 && col < s.Width {
		s.Volumes[row][col] = volume
	}
}

func (s *Sector) GetVolume(col, row int) *Volume {
	if row >= 0 && row < s.Height && col >= 0 && col < s.Width {
		return s.Volumes[row][col]
	}
	return nil
}

func (s *Sector) ToASCII() string {
	var output strings.Builder
	
	output.WriteString(fmt.Sprintf("# Sector: %s\n", s.Name))
	output.WriteString("# 32 columns x 40 rows\n")
	output.WriteString("Location UWP       Temp Bases TC          Factions     Stars         Orbits        Name\n")
	output.WriteString("-------- --------- ---- ----- ----------- ------------ ------------- ------------- ----\n")
	
	// Process by subsector (4x4 grid of 8x10 subsectors)
	for subsectorRow := 0; subsectorRow < 4; subsectorRow++ {
		for subsectorCol := 0; subsectorCol < 4; subsectorCol++ {
			subsectorLetter := string(rune('A' + subsectorRow*4 + subsectorCol))
			hasContent := false
			
			// Check if subsector has any content
			for localRow := 0; localRow < 10; localRow++ {
				for localCol := 0; localCol < 8; localCol++ {
					row := subsectorRow*10 + localRow
					col := subsectorCol*8 + localCol
					if vol := s.Volumes[row][col]; vol != nil && !vol.IsEmpty() {
						hasContent = true
						break
					}
				}
				if hasContent {
					break
				}
			}
			
			if hasContent {
				output.WriteString(fmt.Sprintf("\n# Subsector %s\n", subsectorLetter))
				
				// Each subsector is 8 columns x 10 rows
				for localRow := 0; localRow < 10; localRow++ {
					for localCol := 0; localCol < 8; localCol++ {
						row := subsectorRow*10 + localRow
						col := subsectorCol*8 + localCol
						
						if vol := s.Volumes[row][col]; vol != nil && !vol.IsEmpty() {
							output.WriteString(vol.ToASCII())
							output.WriteString("\n")
						}
					}
				}
			}
		}
	}
	
	return output.String()
}

// MarshalJSON custom marshaler to output volumes as a hash with zero-padded coordinate keys
func (s *Sector) MarshalJSON() ([]byte, error) {
	// Create a custom structure with volumes as a map
	type SectorJSON struct {
		Name    string             `json:"name"`
		Volumes map[string]*Volume `json:"volumes"`
		Width   int                `json:"width"`
		Height  int                `json:"height"`
	}
	
	// Convert the 2D array to a map with zero-padded coordinate keys
	volumesMap := make(map[string]*Volume)
	for row := 0; row < s.Height; row++ {
		for col := 0; col < s.Width; col++ {
			if vol := s.Volumes[row][col]; vol != nil && !vol.IsEmpty() {
				// Create zero-padded key: XXYY where XX is column+1, YY is row+1
				// Using 1-based coordinates to match Traveller convention
				key := fmt.Sprintf("%02d%02d", col+1, row+1)
				volumesMap[key] = vol
			}
		}
	}
	
	return json.Marshal(&SectorJSON{
		Name:    s.Name,
		Volumes: volumesMap,
		Width:   s.Width,
		Height:  s.Height,
	})
}