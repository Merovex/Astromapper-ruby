use thiserror::Error;

#[derive(Error, Debug)]
pub enum AstromapperError {
    #[error("Invalid density: {0}")]
    InvalidDensity(String),
    
    #[error("RNG not initialized")]
    RngNotInitialized,
    
    #[error("Invalid coordinates: ({0}, {1})")]
    InvalidCoordinates(usize, usize),
    
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    
    #[error("Format error: {0}")]
    FormatError(String),
    
    #[error("JSON serialization error: {0}")]
    JsonError(#[from] serde_json::Error),
}

pub type Result<T> = std::result::Result<T, AstromapperError>;