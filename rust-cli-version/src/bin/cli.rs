use clap::Parser;
use astromapper_core::{generate_sector, generate_volume, generate_crawford_seed, string_to_crawford};
use astromapper_core::formatters::{AsciiFormatter, SvgGenerator};
use std::fs;
use chrono::Local;

#[derive(Parser, Debug)]
#[command(name = "astromapper")]
#[command(about = "Traveller RPG Star Map Generator", long_about = None)]
struct Args {
    /// Generation type: 'sector' or 'volume'
    #[arg(long, default_value = "sector")]
    r#type: String,
    
    /// Density for sector generation
    #[arg(long, default_value = "standard")]
    density: String,
    
    /// Seed string for generation
    #[arg(long)]
    seed: Option<String>,
    
    /// Name for the sector
    #[arg(long, default_value = "Unnamed")]
    name: String,
    
    /// List available density options
    #[arg(long)]
    list_densities: bool,
}

fn main() -> anyhow::Result<()> {
    let args = Args::parse();
    
    if args.list_densities {
        println!("Available density options:");
        println!("  extra-galactic  (1%)  - Deep space between galaxies");
        println!("  rift           (3%)  - Galactic voids");
        println!("  sparse        (17%)  - Frontier regions");
        println!("  scattered     (33%)  - Outer rim");
        println!("  standard      (50%)  - Typical space");
        println!("  dense         (66%)  - Inner systems");
        println!("  cluster       (83%)  - Stellar clusters");
        println!("  core          (91%)  - Galactic core");
        return Ok(());
    }
    
    // Get density value
    let density = match args.density.as_str() {
        "extra-galactic" => 0.01,
        "rift" => 0.03,
        "sparse" => 0.17,
        "scattered" => 0.33,
        "standard" => 0.50,
        "dense" => 0.66,
        "cluster" => 0.83,
        "core" => 0.91,
        _ => {
            eprintln!("Error: Invalid density '{}'", args.density);
            eprintln!("Use --list-densities to see available options");
            std::process::exit(1);
        }
    };
    
    // Handle seed generation/conversion
    let (seed, crawford_code) = if let Some(s) = args.seed {
        let crawford = string_to_crawford(&s);
        if s == crawford {
            println!("Using seed: {}", crawford);
        } else {
            println!("Input: {}", s);
            println!("Crawford code: {}", crawford);
        }
        (crawford.clone(), crawford)
    } else {
        let crawford = generate_crawford_seed();
        println!("Generated seed: {}", crawford);
        (crawford.clone(), crawford)
    };
    
    // Create output directory
    fs::create_dir_all("output")?;
    
    // Generate based on type
    match args.r#type.as_str() {
        "sector" => {
            println!("Generating sector with {} density ({}%)...", args.density, (density * 100.0) as u32);
            
            let sector = generate_sector(args.name, seed.clone(), density)?;
            
            // Generate ASCII
            let ascii_content = AsciiFormatter::format_sector(&sector);
            
            // Generate SVG
            let svg_content = SvgGenerator::generate_sector(&sector);
            
            // Create filenames with timestamp
            let timestamp = Local::now().format("%Y%m%d-%H%M%S");
            let ascii_path = format!("output/sector_{}_{}.txt", crawford_code, timestamp);
            let svg_path = format!("output/sector_{}_{}.svg", crawford_code, timestamp);
            
            // Write files
            fs::write(&ascii_path, ascii_content)?;
            fs::write(&svg_path, svg_content)?;
            
            println!("ASCII saved to: {}", ascii_path);
            println!("SVG saved to:   {}", svg_path);
            println!("Generated {} star systems in sector", sector.system_count());
        }
        "volume" => {
            println!("Generating single volume...");
            
            let volume = generate_volume(seed.clone(), 0, 0)?;
            
            // Generate ASCII
            let ascii_content = AsciiFormatter::format_volume(&volume);
            
            // Create filename with timestamp
            let timestamp = Local::now().format("%Y%m%d-%H%M%S");
            let ascii_path = format!("output/volume_{}_{}.txt", crawford_code, timestamp);
            
            // Write file
            fs::write(&ascii_path, ascii_content)?;
            
            println!("ASCII saved to: {}", ascii_path);
            
            if !volume.is_empty() {
                if let Some(world) = &volume.world {
                    println!("Generated system: {}", world.name);
                }
            } else {
                println!("Generated empty hex");
            }
        }
        _ => {
            eprintln!("Error: Invalid type '{}'. Must be 'sector' or 'volume'", args.r#type);
            std::process::exit(1);
        }
    }
    
    Ok(())
}