# Existing Module Analysis - Current Architecture

## Verified Line Counts (PRP Accurate)
- `mod_settings.R`: 913 lines ❌ (>400 limit)
- `mod_delcampe_actions.R`: 898 lines ❌ (>400 limit)  
- `mod_postal_cards_face.R`: 892 lines ❌ (>400 limit)
- `mod_postal_cards_verso.R`: 829 lines ❌ (>400 limit)
- `app_server.R`: 542 lines ❌ (>400 limit)
- `tracking_database.R`: 575 lines ❌ (>400 limit)
- `mod_login.R`: 268 lines ✅ (within limit)
- `app_ui.R`: 192 lines ✅ (within limit)

**Total oversized files: 6 files exceeding 400-line limit**

## Functional Analysis

### mod_postal_cards_face.R (892 lines) - Core Responsibilities
1. **File Upload & Validation** (~100 lines)
   - fileInput for face image upload
   - Image path handling and validation
   - Session directory management

2. **Python Integration & Grid Detection** (~200 lines)
   - `reticulate::source_python("inst/python/extract_postcards.py")`
   - Direct calls to `detect_grid_layout(rv$image_path_original)`
   - Grid boundary processing and validation
   - Internal vs external boundary logic

3. **Interactive Grid Adjustment UI** (~300 lines)
   - Draggable grid lines JavaScript integration
   - `observeEvent` handlers for line movements
   - Real-time grid boundary updates
   - UI rendering for grid visualization

4. **Card Extraction & Processing** (~200 lines)
   - Python cropping function calls
   - Extracted image display and management
   - Status reporting and error handling

5. **Database Integration** (~92 lines)
   - `source("R/tracking_database.R")` calls
   - Session and image tracking
   - Grid configuration persistence

### mod_postal_cards_verso.R (829 lines) - Core Responsibilities
1. **Verso Upload & Cross-Sync** (~150 lines)
   - Verso-specific file upload
   - Face-verso grid synchronization logic
   - Grid dimension inheritance patterns

2. **Python Integration** (~100 lines)  
   - Same Python integration pattern as face module
   - Grid detection specifically for verso images

3. **Grid UI & Adjustment** (~250 lines)
   - Similar draggable grid interface
   - Verso-specific grid rendering
   - Cross-sync with face grid dimensions

4. **Extraction & Lot Combination** (~200 lines)
   - Verso card extraction
   - Face+verso combination logic
   - Lot image generation

5. **Database & Session Management** (~129 lines)
   - Session tracking for verso processing
   - Grid persistence and retrieval

### mod_settings.R (913 lines) - Responsibilities
Based on search patterns, contains:
- User role management (`user_role` references)
- Admin/user privilege controls
- System configuration management
- User preferences and settings persistence

### mod_delcampe_actions.R (898 lines) - Responsibilities  
Based on module name and size:
- Delcampe export functionality
- Lot formatting and preparation
- API integration for Delcampe platform
- Action processing for completed card sets

## Critical Integration Patterns

### Python Integration Pattern (MUST PRESERVE)
```r
# EXACT pattern found in both face/verso modules
reticulate::source_python("inst/python/extract_postcards.py")
py_results <- tryCatch({
  detect_grid_layout(rv$image_path_original)  # Direct function call
}, error = function(e) {
  warning(paste("Python detect_grid_layout error:", e$message))
  NULL
})
```

### Database Integration Pattern
```r
source("R/tracking_database.R")  # Direct sourcing in multiple places
```

### Reactive Architecture Complexity
- **Face Module**: 15+ observeEvent/renderUI/reactive calls
- **Verso Module**: 12+ observeEvent/renderUI/reactive calls
- Heavy interdependencies between reactive elements
- Complex state management via reactiveValues()

## Decomposition Strategy Insights

### Natural Split Points Identified

#### mod_postal_cards_face.R → 3 modules:
1. **mod_face_upload** (~300 lines)
   - File upload, validation, session setup
   - Initial image processing and display
   - Database integration for upload tracking

2. **mod_face_grid_adjust** (~250 lines)
   - Grid detection API calls to Python
   - Interactive grid adjustment UI
   - Draggable lines and boundary management

3. **mod_face_extraction** (~350 lines)
   - Card extraction processing
   - Python cropping function integration
   - Extracted image display and management

#### mod_postal_cards_verso.R → 3 modules:
1. **mod_verso_upload** (~300 lines)
   - Verso upload with cross-sync detection
   - Grid inheritance from face processing
   - Verso-specific validation logic

2. **mod_verso_sync** (~200 lines)
   - Face-verso synchronization engine
   - Grid dimension cross-referencing
   - Sync status management

3. **mod_verso_extraction** (~350 lines)
   - Verso extraction processing
   - Face+verso lot combination
   - Final output generation

## Risk Assessment for Decomposition

### High Risk Areas
1. **Python Integration**: Critical dependency, exact patterns must be preserved
2. **Reactive Dependencies**: Complex inter-module communication needed
3. **Session State**: Shared reactiveValues() across split modules
4. **Database Transactions**: Multi-module database consistency

### Medium Risk Areas  
1. **Grid Synchronization**: Face-verso communication patterns
2. **File Path Management**: Session directory handling
3. **Error Handling**: Distributed error states across modules

### Preservation Requirements
1. All existing `reticulate::source_python()` calls
2. Direct `detect_grid_layout()` function call pattern
3. Session directory structure and resource paths
4. Grid boundary calculation algorithms
5. Database integration points with tracking_database.R