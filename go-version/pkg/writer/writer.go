package writer

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type FileWriter struct {
	OutputDir string
}

func New(outputDir string) *FileWriter {
	return &FileWriter{
		OutputDir: outputDir,
	}
}

func (w *FileWriter) EnsureOutputDir() error {
	return os.MkdirAll(w.OutputDir, 0755)
}

func (w *FileWriter) WriteFiles(seed, asciiContent, svgContent, jsonContent string, fileType string) (string, string, string, error) {
	if err := w.EnsureOutputDir(); err != nil {
		return "", "", "", fmt.Errorf("failed to create output directory: %w", err)
	}
	
	timestamp := time.Now().Format("20060102-150405")
	baseName := fmt.Sprintf("%s_%s_%s", fileType, seed, timestamp)
	
	asciiPath := filepath.Join(w.OutputDir, baseName+".txt")
	if err := os.WriteFile(asciiPath, []byte(asciiContent), 0644); err != nil {
		return "", "", "", fmt.Errorf("failed to write ASCII file: %w", err)
	}
	
	svgPath := ""
	if svgContent != "" {
		svgPath = filepath.Join(w.OutputDir, baseName+".svg")
		if err := os.WriteFile(svgPath, []byte(svgContent), 0644); err != nil {
			return asciiPath, "", "", fmt.Errorf("failed to write SVG file: %w", err)
		}
	}
	
	jsonPath := ""
	if jsonContent != "" {
		jsonPath = filepath.Join(w.OutputDir, baseName+".json")
		if err := os.WriteFile(jsonPath, []byte(jsonContent), 0644); err != nil {
			return asciiPath, svgPath, "", fmt.Errorf("failed to write JSON file: %w", err)
		}
	}
	
	return asciiPath, svgPath, jsonPath, nil
}