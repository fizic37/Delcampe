# Technology Stack and Architecture

## Primary Technologies

### R/Shiny Framework
- **Golem Framework**: Core framework for building production-ready Shiny applications
- **Shiny**: Web application framework for R
- **R Version**: Likely R 4.x (based on DESCRIPTION file structure)

### Python Integration
- **reticulate**: R package for seamless R-Python integration (CRITICAL: existing setup must be preserved)
- **Python Version**: 3.12.9 (from venv_proj/pyvenv.cfg)
- **Virtual Environment**: Located in `venv_proj/` directory

### Python Dependencies
- **OpenCV (cv2)**: Computer vision library for image processing
- **NumPy**: Numerical computing for array operations
- **os**: File system operations

## Architecture Components

### Golem Structure
- `R/`: Contains R source files (app_ui.R, app_server.R, run_app.R, app_config.R)
- `dev/`: Development scripts (01_start.R, 02_dev.R, 03_deploy.R, run_dev.R)
- `inst/`: Installation files including Python scripts and Golem config
- `man/`: Auto-generated documentation
- `DESCRIPTION`: Package metadata and dependencies

### Python Integration
- **Location**: `inst/python/extract_postcards.py`
- **Purpose**: Image processing, grid detection, card extraction
- **Key Functions**:
  - `detect_grid_layout()`: Detects rows/columns in postcard sheets
  - `crop_image_with_boundaries()`: Extracts individual cards
  - `combine_face_verso_images()`: Creates combined face/verso images

### File Organization
```
Delcampe/
├── R/                  # R source code
│   └── mod_postal_card_processor.R  # Main processing module
├── dev/                # Development scripts
├── inst/
│   ├── app/
│   │   └── www/        # Static web assets
│   │       ├── draggable_lines.js  # Coordinate mapping logic
│   │       └── styles.css          # Styling
│   ├── python/         # Python image processing
│   └── golem-config.yml
├── tests/              # Test suite
│   ├── testthat/       # Automated unit tests
│   └── manual/         # Manual verification scripts
├── venv_proj/          # Python virtual environment
├── test_images/        # Test image assets
└── .serena/
    └── memories/       # LLM context and solutions
        └── draggable_lines_coordinate_fix.md
```

## Key Components

### JavaScript Components
- **draggable_lines.js**: Handles coordinate mapping for interactive line positioning
  - Manages three coordinate systems: Original, Rendered, Wrapper
  - Accounts for CSS `object-fit: contain` padding
  - Provides accurate coordinate conversion for image cropping
  - See: `.serena/memories/draggable_lines_coordinate_fix.md`

### Modules
- **mod_postal_card_processor**: Core module for postcard processing
  - Handles image upload and display
  - Manages draggable grid lines for crop boundaries
  - Coordinates with Python for detection and extraction
  - Displays extracted cards in grid layout

## Critical Constraints
1. **DO NOT MODIFY** existing R-Python integration via reticulate
2. **Preserve** the current Python virtual environment setup
3. **Follow** Golem naming conventions and project structure
4. **Maintain** separation between R UI/server logic and Python processing
5. **DO NOT REMOVE** data attributes on images (data-original-width, data-original-height)
6. **PRESERVE** object-fit: contain on images for proper rendering

## Known Solutions & Fixes

### Draggable Lines Coordinate Mapping (2025-01-06)
**Problem**: Lines didn't align with crop boundaries due to CSS padding
**Solution**: Complete JavaScript rewrite accounting for rendered image offset
**Reference**: `.serena/memories/draggable_lines_coordinate_fix.md`
**Tests**: `tests/testthat/test-mod_postal_card_processor.R`