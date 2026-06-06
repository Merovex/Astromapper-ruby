// Package config loads an optional _astromapper.yml so the Go build can be driven
// by a project file (like the Ruby version) instead of repeating flags. Precedence
// is: explicit CLI flag > config file > built-in defaults.
package config

import (
	"os"

	"gopkg.in/yaml.v3"
)

// Config is the on-disk generation settings. Keys mirror the Ruby _astromapper.yml
// where the feature exists in the Go build.
type Config struct {
	Type          string  `yaml:"type"`
	Name          string  `yaml:"name"`
	Density       string  `yaml:"density"`
	Seed          string  `yaml:"seed"`
	Ruleset       string  `yaml:"ruleset"`
	Sophonts      string  `yaml:"sophonts"`
	Islands       bool    `yaml:"islands"`
	IslandJump    int     `yaml:"island_jump"`
	IslandMin     int     `yaml:"island_min"`
	IslandOpacity float64 `yaml:"island_opacity"`
}

// Defaults returns the built-in configuration (used when no file/flag overrides it).
func Defaults() Config {
	return Config{
		Type:          "sector",
		Name:          "Unnamed",
		Density:       "standard",
		Seed:          "",
		Ruleset:       "t5",
		Sophonts:      "human",
		Islands:       true,
		IslandJump:    2,
		IslandMin:     2,
		IslandOpacity: 0.85,
	}
}

// Load reads path over the defaults. yaml.Unmarshal only sets keys present in the
// file, so omitted keys keep their default. Returns found=false (no error) when the
// file does not exist, so a missing config is fine.
func Load(path string) (cfg Config, found bool, err error) {
	cfg = Defaults()
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, false, nil
		}
		return cfg, false, err
	}
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return cfg, false, err
	}
	return cfg, true, nil
}
