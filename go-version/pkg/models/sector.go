package models

import (
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