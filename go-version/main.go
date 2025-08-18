package main

import (
	"astromapper/pkg/builder"
	"astromapper/pkg/data"
	"astromapper/pkg/rng"
	"astromapper/pkg/svg"
	"astromapper/pkg/writer"
	"crypto/rand"
	"encoding/json"
	"flag"
	"fmt"
	"hash/fnv"
	"math/big"
	"os"
	"strings"
)

var densityMap = map[string]float64{
	"extra-galactic": 0.01,
	"rift":           0.03,
	"sparse":         0.17,
	"scattered":      0.33,
	"standard":       0.50,
	"dense":          0.66,
	"cluster":        0.83,
	"core":           0.91,
}

func generateRandomSeed() string {
	// Excluding I, O, 0, 1 to avoid confusion
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	seed := make([]byte, 10)
	for i := range seed {
		n, _ := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		seed[i] = charset[n.Int64()]
	}
	// Format as XXXXX-XXXXX for readability
	return string(seed[:5]) + "-" + string(seed[5:])
}

// Convert any string to a CRAWFORD-style 10-character code
func stringToCrawford(input string) string {
	// Excluding I, O, 0, 1 to avoid confusion
	const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	
	// Use FNV-1a hash to get a deterministic value from the input
	h := fnv.New64a()
	h.Write([]byte(input))
	hash := h.Sum64()
	
	// Convert hash to 10-character string
	result := make([]byte, 10)
	for i := 0; i < 10; i++ {
		// Use different parts of the hash for each character
		index := (hash >> (uint(i) * 6)) % uint64(len(charset))
		result[i] = charset[index]
	}
	
	// Format as XXXXX-XXXXX
	return string(result[:5]) + "-" + string(result[5:])
}

func main() {
	// Define command-line flags
	var (
		genType = flag.String("type", "sector", "Generation type: 'sector' or 'volume'")
		density = flag.String("density", "standard", "Density for sector generation: extra-galactic, rift, sparse, scattered, standard, dense, cluster, core")
		seed    = flag.String("seed", "", "Seed string for generation (if not provided, generates random seed in format XXXXX-XXXXX)")
		name    = flag.String("name", "Unnamed", "Name for the sector (default: Unnamed)")
		help    = flag.Bool("help", false, "Show help message")
		listDensities = flag.Bool("list-densities", false, "List available density options")
	)

	flag.Parse()

	// Show help if requested
	if *help {
		showHelp()
		os.Exit(0)
	}

	// List densities if requested
	if *listDensities {
		fmt.Println("Available density options:")
		fmt.Println("  extra-galactic  (1%)  - Deep space between galaxies")
		fmt.Println("  rift           (3%)  - Galactic voids")
		fmt.Println("  sparse        (17%)  - Frontier regions")
		fmt.Println("  scattered     (33%)  - Outer rim")
		fmt.Println("  standard      (50%)  - Typical space")
		fmt.Println("  dense         (66%)  - Inner systems")
		fmt.Println("  cluster       (83%)  - Stellar clusters")
		fmt.Println("  core          (91%)  - Galactic core")
		os.Exit(0)
	}

	// Validate generation type
	if *genType != "sector" && *genType != "volume" {
		fmt.Fprintf(os.Stderr, "Error: Invalid type '%s'. Must be 'sector' or 'volume'\n", *genType)
		os.Exit(1)
	}

	// Get density value
	densityValue, ok := densityMap[*density]
	if !ok && *genType == "sector" {
		fmt.Fprintf(os.Stderr, "Error: Invalid density '%s'\n", *density)
		fmt.Println("Use --list-densities to see available options")
		os.Exit(1)
	}

	// Handle seed generation/conversion
	var seedStr string
	var crawfordCode string
	
	if *seed == "" {
		// No seed provided, generate random one
		crawfordCode = generateRandomSeed()
		seedStr = crawfordCode
		fmt.Printf("Generated seed: %s\n", crawfordCode)
	} else if len(*seed) == 11 && strings.Contains(*seed, "-") && len(strings.Split(*seed, "-")) == 2 {
		// Already in CRAWFORD format (XXXXX-XXXXX)
		crawfordCode = *seed
		seedStr = *seed
		fmt.Printf("Using seed: %s\n", crawfordCode)
	} else {
		// Convert any other string to CRAWFORD format
		crawfordCode = stringToCrawford(*seed)
		seedStr = crawfordCode
		fmt.Printf("Input: %s\n", *seed)
		fmt.Printf("Crawford code: %s\n", crawfordCode)
	}

	// Initialize RNG with seed
	r := rng.New(seedStr)

	// Load planet names
	planetNames := data.GetPlanetNames()

	// Create file writer
	fileWriter := writer.New("output")

	// Generate based on type
	if *genType == "sector" {
		fmt.Printf("Generating sector with %s density (%.0f%%)...\n", *density, densityValue*100)
		
		// Generate sector
		sector := builder.BuildSector(*name, 32, 40, densityValue, planetNames, r)
		
		// Generate ASCII content
		asciiContent := sector.ToASCII()
		
		// Generate SVG content
		svgGen := svg.NewSVGGenerator(*name)
		svgContent := svgGen.GenerateSector(sector)
		
		// Generate JSON content
		jsonData, err := json.MarshalIndent(sector, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error generating JSON: %v\n", err)
			os.Exit(1)
		}
		jsonContent := string(jsonData)
		
		// Write files
		asciiPath, svgPath, jsonPath, err := fileWriter.WriteFiles(seedStr, asciiContent, svgContent, jsonContent, "sector")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error writing files: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("ASCII saved to: %s\n", asciiPath)
		fmt.Printf("SVG saved to:   %s\n", svgPath)
		fmt.Printf("JSON saved to:  %s\n", jsonPath)
		
		// Count systems
		systemCount := 0
		for r := 0; r < sector.Height; r++ {
			for c := 0; c < sector.Width; c++ {
				if vol := sector.Volumes[r][c]; vol != nil && !vol.IsEmpty() {
					systemCount++
				}
			}
		}
		fmt.Printf("Generated %d star systems in sector\n", systemCount)
		
	} else {
		fmt.Println("Generating single volume...")
		
		// Generate volume
		volume := builder.BuildVolume(1, 1, planetNames, r)
		
		// Generate ASCII content
		asciiContent := volume.ToASCII()
		
		// Generate JSON content
		jsonData, err := json.MarshalIndent(volume, "", "  ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error generating JSON: %v\n", err)
			os.Exit(1)
		}
		jsonContent := string(jsonData)
		
		// Write files (no SVG for single volume)
		asciiPath, _, jsonPath, err := fileWriter.WriteFiles(seedStr, asciiContent, "", jsonContent, "volume")
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error writing files: %v\n", err)
			os.Exit(1)
		}
		
		fmt.Printf("ASCII saved to: %s\n", asciiPath)
		fmt.Printf("JSON saved to:  %s\n", jsonPath)
		
		if !volume.IsEmpty() {
			fmt.Printf("Generated system: %s\n", volume.Name)
		} else {
			fmt.Println("Generated empty hex")
		}
	}
}

func showHelp() {
	fmt.Println("Astromapper - Traveller RPG Star Map Generator")
	fmt.Println()
	fmt.Println("Usage: astromapper [options]")
	fmt.Println()
	fmt.Println("Options:")
	fmt.Println("  --type <type>        Generation type: 'sector' or 'volume' (default: sector)")
	fmt.Println("  --density <density>  Density for sector generation (default: standard)")
	fmt.Println("                       Options: extra-galactic, rift, sparse, scattered,")
	fmt.Println("                                standard, dense, cluster, core")
	fmt.Println("  --seed <string>      Seed string for generation")
	fmt.Println("                       If not provided, generates random seed (format: XXXXX-XXXXX)")
	fmt.Println("  --name <string>      Name for the sector (default: Unnamed)")
	fmt.Println("  --list-densities     List available density options with descriptions")
	fmt.Println("  --help               Show this help message")
	fmt.Println()
	fmt.Println("Examples:")
	fmt.Println("  astromapper                                    # Generate standard sector with random seed")
	fmt.Println("  astromapper --seed MYSEED123                  # Generate sector with specific seed")
	fmt.Println("  astromapper --density sparse --seed FRONTIER  # Generate sparse sector")
	fmt.Println("  astromapper --type volume --seed ALPHA7       # Generate single star system")
	fmt.Println("  astromapper --name \"Spinward Marches\"         # Generate sector with custom name")
	fmt.Println()
	fmt.Println("Output:")
	fmt.Println("  Files are saved to the 'output' directory:")
	fmt.Println("  - ASCII text file with system data")
	fmt.Println("  - SVG vector graphic (sector only)")
	fmt.Println("  - JSON data file")
}