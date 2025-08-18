package data

import (
	_ "embed"
	"strings"
)

//go:embed names.txt
var namesData string

func GetPlanetNames() []string {
	lines := strings.Split(namesData, "\n")
	names := []string{}
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" && !strings.HasPrefix(line, "#") && !strings.HasPrefix(line, "-") {
			names = append(names, line)
		}
	}
	return names
}