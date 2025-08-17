package main

import (
	"astromapper/pkg/builder"
	"astromapper/pkg/data"
	"astromapper/pkg/models"
	"astromapper/pkg/rng"
	"astromapper/pkg/svg"
	"astromapper/pkg/writer"
	"fmt"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type mode int

const (
	modeMenu mode = iota
	modeSeedInput
	modeDensitySelect
	modeGenerating
	modeViewing
)

type model struct {
	mode            mode
	seedInput       textinput.Model
	seed            string
	viewport        viewport.Model
	sector          *models.Sector
	volume          *models.Volume
	planetNames     []string
	width           int
	height          int
	menuSelection   int
	densitySelection int
	ready           bool
	generationType  string
	density         float64
	densityName     string
	lastAsciiPath   string
	lastSVGPath     string
	fileWriter      *writer.FileWriter
}

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("170")).
			MarginBottom(1)
	
	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241"))
	
	selectedStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("170")).
			Bold(true)
	
	normalStyle = lipgloss.NewStyle()
	
	densityOptions = []struct {
		name  string
		value float64
	}{
		{"Extra Galactic (1%)", 0.01},
		{"Rift (3%)", 0.03},
		{"Sparse (17%)", 0.17},
		{"Scattered (33%)", 0.33},
		{"Standard (50%)", 0.50},
		{"Dense (66%)", 0.66},
		{"Cluster (83%)", 0.83},
		{"Core (91%)", 0.91},
	}
)

func initialModel() model {
	ti := textinput.New()
	ti.Placeholder = "Enter seed string..."
	ti.Focus()
	ti.CharLimit = 156
	ti.Width = 50
	
	return model{
		mode:             modeMenu,
		seedInput:        ti,
		planetNames:      data.GetPlanetNames(),
		fileWriter:       writer.New("output"),
		densitySelection: 4, // Default to Standard
		density:          0.50,
		densityName:      "Standard",
	}
}

func (m model) Init() tea.Cmd {
	return textinput.Blink
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		
		if !m.ready {
			m.viewport = viewport.New(msg.Width, msg.Height-4)
			m.viewport.YPosition = 0
			m.ready = true
		} else {
			m.viewport.Width = msg.Width
			m.viewport.Height = msg.Height - 4
		}
		
	case tea.KeyMsg:
		switch m.mode {
		case modeMenu:
			switch msg.String() {
			case "q", "ctrl+c":
				return m, tea.Quit
			case "up", "k":
				m.menuSelection--
				if m.menuSelection < 0 {
					m.menuSelection = 2
				}
			case "down", "j":
				m.menuSelection++
				if m.menuSelection > 2 {
					m.menuSelection = 0
				}
			case "enter":
				switch m.menuSelection {
				case 0:
					m.generationType = "sector"
					m.mode = modeDensitySelect
					return m, nil
				case 1:
					m.generationType = "volume"
					m.mode = modeSeedInput
					m.seedInput.SetValue("")
					m.seedInput.Focus()
					return m, textinput.Blink
				case 2:
					return m, tea.Quit
				}
			}
			
		case modeDensitySelect:
			switch msg.String() {
			case "esc":
				m.mode = modeMenu
				return m, nil
			case "up", "k":
				m.densitySelection--
				if m.densitySelection < 0 {
					m.densitySelection = len(densityOptions) - 1
				}
			case "down", "j":
				m.densitySelection++
				if m.densitySelection >= len(densityOptions) {
					m.densitySelection = 0
				}
			case "enter":
				m.density = densityOptions[m.densitySelection].value
				m.densityName = densityOptions[m.densitySelection].name
				m.mode = modeSeedInput
				m.seedInput.SetValue("")
				m.seedInput.Focus()
				return m, textinput.Blink
			}
			
		case modeSeedInput:
			switch msg.String() {
			case "esc":
				m.mode = modeMenu
				return m, nil
			case "enter":
				m.seed = m.seedInput.Value()
				if m.seed == "" {
					m.seed = "default"
				}
				m.mode = modeGenerating
				return m, m.generate()
			default:
				m.seedInput, cmd = m.seedInput.Update(msg)
				return m, cmd
			}
			
		case modeViewing:
			switch msg.String() {
			case "q", "esc":
				m.mode = modeMenu
				return m, nil
			case "r":
				m.mode = modeSeedInput
				m.seedInput.SetValue(m.seed)
				return m, nil
			default:
				m.viewport, cmd = m.viewport.Update(msg)
				return m, cmd
			}
		}
	
	case generateCompleteMsg:
		m.mode = modeViewing
		if msg.sector != nil {
			m.sector = msg.sector
			m.viewport.SetContent(m.sector.ToASCII())
			m.lastAsciiPath = msg.asciiPath
			m.lastSVGPath = msg.svgPath
		} else if msg.volume != nil {
			m.volume = msg.volume
			m.viewport.SetContent(m.volume.ToASCII())
			m.lastAsciiPath = msg.asciiPath
		}
		return m, nil
	}
	
	return m, nil
}

func (m model) View() string {
	switch m.mode {
	case modeMenu:
		return m.menuView()
	case modeDensitySelect:
		return m.densitySelectView()
	case modeSeedInput:
		return m.seedInputView()
	case modeGenerating:
		return m.generatingView()
	case modeViewing:
		return m.viewingView()
	default:
		return ""
	}
}

func (m model) menuView() string {
	s := titleStyle.Render("🌟 Astromapper - Traveller RPG Star Map Generator") + "\n\n"
	
	options := []string{
		"Generate Sector (40x32 hex grid)",
		"Generate Volume (single hex system)",
		"Quit",
	}
	
	for i, option := range options {
		if i == m.menuSelection {
			s += selectedStyle.Render("▸ " + option) + "\n"
		} else {
			s += normalStyle.Render("  " + option) + "\n"
		}
	}
	
	s += "\n" + helpStyle.Render("Use ↑/↓ or j/k to navigate, Enter to select, q to quit")
	
	return s
}

func (m model) densitySelectView() string {
	s := titleStyle.Render("🌟 Astromapper - Select Sector Density") + "\n\n"
	s += "Choose the density of star systems in the sector:\n\n"
	
	for i, option := range densityOptions {
		if i == m.densitySelection {
			s += selectedStyle.Render("▸ " + option.name) + "\n"
		} else {
			s += normalStyle.Render("  " + option.name) + "\n"
		}
	}
	
	s += "\n" + helpStyle.Render("Use ↑/↓ or j/k to navigate, Enter to select, Esc to go back")
	return s
}

func (m model) seedInputView() string {
	s := titleStyle.Render("🌟 Astromapper - " + strings.Title(m.generationType) + " Generation")
	if m.generationType == "sector" {
		s += fmt.Sprintf(" [%s]", m.densityName)
	}
	s += "\n\n"
	s += "Enter a seed string (any text) to generate consistent results:\n\n"
	s += m.seedInput.View() + "\n\n"
	s += helpStyle.Render("Press Enter to generate, Esc to go back")
	return s
}

func (m model) generatingView() string {
	s := titleStyle.Render("🌟 Astromapper") + "\n\n"
	s += "Generating " + m.generationType + " with seed: " + m.seed + "\n\n"
	s += "Please wait..."
	return s
}

func (m model) viewingView() string {
	header := titleStyle.Render("🌟 Astromapper - " + strings.Title(m.generationType) + " (Seed: " + m.seed + ")")
	
	fileInfo := ""
	if m.lastAsciiPath != "" {
		fileInfo = fmt.Sprintf("\n📄 ASCII saved to: %s", m.lastAsciiPath)
	}
	if m.lastSVGPath != "" {
		fileInfo += fmt.Sprintf("\n🎨 SVG saved to: %s", m.lastSVGPath)
	}
	
	help := helpStyle.Render("Use ↑/↓/PgUp/PgDn to scroll, r to regenerate, q/Esc to go back")
	
	return fmt.Sprintf("%s%s\n%s\n%s", header, fileInfo, m.viewport.View(), help)
}

type generateCompleteMsg struct {
	sector    *models.Sector
	volume    *models.Volume
	asciiPath string
	svgPath   string
}

func (m model) generate() tea.Cmd {
	return func() tea.Msg {
		r := rng.New(m.seed)
		
		if m.generationType == "sector" {
			sector := builder.BuildSector("Generated Sector", 32, 40, m.density, m.planetNames, r)
			
			// Generate ASCII content
			asciiContent := sector.ToASCII()
			
			// Generate SVG content
			svgGen := svg.NewSVGGenerator("Generated Sector")
			svgContent := svgGen.GenerateSector(sector)
			
			// Write files
			asciiPath, svgPath, err := m.fileWriter.WriteFiles(m.seed, asciiContent, svgContent, "sector")
			if err != nil {
				// Just log error and continue - files won't be saved but app continues
				fmt.Printf("Error writing files: %v\n", err)
			}
			
			return generateCompleteMsg{
				sector:    sector,
				asciiPath: asciiPath,
				svgPath:   svgPath,
			}
		} else {
			volume := builder.BuildVolume(1, 1, m.planetNames, r)
			
			// Generate ASCII content
			asciiContent := volume.ToASCII()
			
			// Write ASCII file (no SVG for single volume)
			asciiPath, _, err := m.fileWriter.WriteFiles(m.seed, asciiContent, "", "volume")
			if err != nil {
				fmt.Printf("Error writing files: %v\n", err)
			}
			
			return generateCompleteMsg{
				volume:    volume,
				asciiPath: asciiPath,
			}
		}
	}
}

func main() {
	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v", err)
	}
}