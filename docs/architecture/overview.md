# System Architecture Overview

## High-Level Architecture

The Delcampe Postal Card Processor is a hybrid R Shiny and Python application built on the Golem framework, designed to process images of postal cards for listing on Delcampe marketplace.

```
┌─────────────────────────────────────────────────────────────┐
│                     Delcampe Application                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │   R Shiny UI     │◄───────►│  R Shiny Server  │          │
│  │  (User Interface)│         │   (Logic Layer)  │          │
│  └──────────────────┘         └─────────┬────────┘          │
│           │                              │                   │
│           │                              │                   │
│           ▼                              ▼                   │
│  ┌──────────────────┐         ┌──────────────────┐          │
│  │    JavaScript    │         │    reticulate    │          │
│  │  (Client-side)   │         │  (R-Python Bridge)│         │
│  └──────────────────┘         └─────────┬────────┘          │
│           │                              │                   │
│           │                              ▼                   │
│           │                    ┌──────────────────┐          │
│           │                    │  Python OpenCV   │          │
│           │                    │ (Image Processing)│         │
│           │                    └──────────────────┘          │
│           │                                                  │
│           └──────────────┬─────────────────────────────────┘
│                          │
│                          ▼
│                 ┌──────────────────┐
│                 │  SQLite Database │
│                 │   (Persistence)  │
│                 └──────────────────┘
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. R Shiny Layer (UI/Server)
**Purpose:** User interface and application orchestration

**Technologies:**
- Golem framework for production-ready structure
- bslib for modern UI components
- Shiny modules for component organization

**Key Files:**
- `R/app_ui.R` - Main UI definition
- `R/app_server.R` - Server logic orchestration
- `R/mod_*.R` - Individual Shiny modules

**Responsibilities:**
- User interaction handling
- Image upload and display
- Settings management
- Result presentation

### 2. Python Processing Layer
**Purpose:** Heavy computational tasks and image processing

**Technologies:**
- Python 3.12.9
- OpenCV (cv2) for image processing
- NumPy for numerical operations

**Key Files:**
- `inst/python/extract_postcards.py` - Main Python module

**Key Functions:**
- `detect_grid_layout()` - Detects rows/columns in postcard sheets
- `crop_image_with_boundaries()` - Extracts individual cards
- `combine_face_verso_images()` - Creates combined face/verso images

### 3. R-Python Bridge (reticulate)
**Purpose:** Seamless integration between R and Python

**Configuration:**
- Virtual environment: `venv_proj/`
- Python version: 3.12.9
- Initialized at app startup

**Critical Constraints:**
- ⚠️ **DO NOT modify** existing reticulate setup
- Configuration is stable and battle-tested
- Only extend, never replace

### 4. JavaScript Layer
**Purpose:** Client-side interactions and coordinate management

**Key Files:**
- `inst/app/www/draggable_lines.js` - Interactive line positioning
- `inst/app/www/styles.css` - Styling

**Responsibilities:**
- Coordinate system management (Original ↔ Rendered ↔ Wrapper)
- Drag-and-drop interactions
- Real-time UI updates

### 5. Data Persistence Layer
**Purpose:** Store user data, settings, and tracking information

**Technology:** SQLite

**Key Tables:**
- `users` - User authentication
- `api_keys` - Encrypted API credentials
- `ai_extractions` - AI model results
- `ebay_posts` - eBay posting attempts
- `image_hashes` - Deduplication tracking

## Architectural Patterns

### 1. Modular Design (Golem)
```
R/
├── app_ui.R              # Main UI assembly
├── app_server.R          # Server orchestration
├── mod_postal_card_processor.R    # Core module
├── mod_settings.R        # Settings module
├── fct_*.R               # Business logic functions
└── utils_*.R             # Utility functions
```

**Benefits:**
- Clear separation of concerns
- Testable components
- Reusable modules
- Namespace protection

### 2. Reactive Programming
```r
# Reactive values
values <- reactiveValues(
  image_path = NULL,
  boundaries = list()
)

# Reactive expressions
processed_data <- reactive({
  req(values$image_path)
  process_image(values$image_path)
})

# Observers
observeEvent(input$process_btn, {
  values$boundaries <- detect_boundaries()
})
```

**Benefits:**
- Automatic dependency tracking
- Efficient updates
- Predictable data flow

### 3. Command Pattern (Python Functions)
```r
# R calls Python functions as commands
detect_grid_layout <- function(image_path, ...) {
  reticulate::py$detect_grid_layout(image_path, ...)
}
```

**Benefits:**
- Clear interface
- Language independence
- Easy testing

## Data Flow

### Image Processing Flow
```
┌──────────────┐
│ User Uploads │
│    Image     │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ Shiny Server     │
│ Receives File    │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Python OpenCV    │
│ Detects Grid     │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ JavaScript       │
│ Renders Lines    │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ User Adjusts     │
│ Boundaries       │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Python Crops     │
│ Individual Cards │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ AI Extraction    │
│ (Optional)       │
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│ Results Display  │
└──────────────────┘
```

### Authentication Flow
```
Login → Verify Credentials → Create Session → Check Role → Grant Access
         ↓                                      ↓
    Hash Password                          Master/Regular User
         ↓                                      ↓
    Compare Hashes                        Different Permissions
```

## Module Organization

### Core Modules
- **mod_postal_card_processor** - Main processing interface
- **mod_settings** - Application configuration
- **mod_llm_settings** - LLM model configuration

### Supporting Functions
- **fct_image_processing.R** - Image manipulation
- **fct_ai_integration.R** - AI API integration
- **utils_auth.R** - Authentication helpers
- **utils_database.R** - Database operations

## Scalability Considerations

### Current Scale
- **Users:** Small team (< 10 concurrent users)
- **Images:** Moderate (< 100 images/day)
- **Database:** SQLite (< 1GB)

### Future Scale Options
1. **More Users:** Consider PostgreSQL migration
2. **More Images:** Add file storage service (S3, etc.)
3. **Higher Performance:** Implement caching layer
4. **Background Processing:** Add job queue (e.g., Redis + workers)

## Security Architecture

### Authentication
- SHA-256 password hashing
- Session-based authentication
- Master user protection

### API Keys
- Encrypted storage in SQLite
- Environment variable option
- Per-user configuration

### Data Protection
- No external data transmission (except AI APIs)
- Local processing only
- Secure session management

## Technology Choices

See `/docs/decisions/` for detailed Architecture Decision Records (ADRs) explaining:
- Why Golem framework
- Why Python + OpenCV
- Why SQLite
- Why reticulate

## Performance Characteristics

### Strengths
- ✅ Fast local processing
- ✅ No server costs
- ✅ Simple deployment

### Limitations
- ⚠️ Single-threaded R (for most operations)
- ⚠️ SQLite concurrent write limits
- ⚠️ Memory constraints for large images

### Optimizations
- Lazy loading of modules
- Efficient coordinate calculations
- Cached Python environment

## Related Documentation

- **Data Flow:** See `data-flow.md` for detailed data transformations
- **R-Python Integration:** See `r-python-integration.md` for technical details
- **Module Structure:** See `module-structure.md` for module relationships

---

**Last Updated:** 2025-10-11  
**Version:** 1.0  
**Status:** Current
