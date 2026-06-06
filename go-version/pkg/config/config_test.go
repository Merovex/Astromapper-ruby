package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefaults(t *testing.T) {
	d := Defaults()
	if d.Ruleset != "t5" || d.Density != "standard" || !d.Islands || d.IslandJump != 2 {
		t.Errorf("unexpected defaults: %+v", d)
	}
}

func TestLoadMissingFileIsNotAnError(t *testing.T) {
	cfg, found, err := Load(filepath.Join(t.TempDir(), "nope.yml"))
	if err != nil {
		t.Fatalf("missing file should not error: %v", err)
	}
	if found {
		t.Error("found should be false for a missing file")
	}
	if cfg != Defaults() {
		t.Error("a missing file should yield the defaults")
	}
}

func TestLoadOverridesOnlyPresentKeys(t *testing.T) {
	path := filepath.Join(t.TempDir(), "_astromapper.yml")
	yml := "name: Frontier\nruleset: cepheus\nisland_min: 4\nislands: false\n"
	if err := os.WriteFile(path, []byte(yml), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg, found, err := Load(path)
	if err != nil || !found {
		t.Fatalf("load: found=%v err=%v", found, err)
	}
	// present keys overridden
	if cfg.Name != "Frontier" || cfg.Ruleset != "cepheus" || cfg.IslandMin != 4 || cfg.Islands {
		t.Errorf("present keys not applied: %+v", cfg)
	}
	// omitted keys keep defaults
	if cfg.Density != "standard" || cfg.Sophonts != "human" || cfg.IslandJump != 2 {
		t.Errorf("omitted keys should keep defaults: %+v", cfg)
	}
}

// The `astromapper new` scaffold must be valid YAML that loads with the given name.
func TestTemplateRoundTrips(t *testing.T) {
	path := filepath.Join(t.TempDir(), "_astromapper.yml")
	if err := os.WriteFile(path, []byte(Template("Spinward Marches")), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg, found, err := Load(path)
	if err != nil || !found {
		t.Fatalf("scaffold should load: found=%v err=%v", found, err)
	}
	if cfg.Name != "Spinward Marches" {
		t.Errorf("template name = %q, want \"Spinward Marches\"", cfg.Name)
	}
	if cfg.Ruleset != "t5" || cfg.Density != "standard" || !cfg.Islands {
		t.Errorf("template defaults wrong: %+v", cfg)
	}
}
