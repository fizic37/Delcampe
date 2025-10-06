# Critical Constraints and Preservation Requirements

## System Validation Status ✅
**CONFIRMED**: Current system works perfectly with test images
- Grid Detection: ✅ PASS (test_face.jpg: 3x1 grid, test_verso.jpg: 1x1 grid)
- Image Cropping: ✅ PASS (3 individual cards extracted successfully)
- Face+Verso Combination: ✅ PASS (1 lot image + 3 combined images created)

## ABSOLUTE PRESERVATION REQUIREMENTS

### 1. Python Integration Pattern (CRITICAL - DO NOT MODIFY)
```r
# EXACT pattern that MUST be preserved in decomposed modules:
reticulate::source_python("inst/python/extract_postcards.py")
py_results <- tryCatch({
  detect_grid_layout(rv$image_path_original)  # Direct function call, NOT py$
}, error = function(e) {
  warning(paste("Python detect_grid_layout error:", e$message))
  NULL
})
```

**Key Requirements:**
- Use `detect_grid_layout()` as direct function call (not `py$detect_grid_layout()`)
- Exact error handling pattern with `tryCatch()` and warning messages
- Python script location: `"inst/python/extract_postcards.py"` (exact path)

### 2. Python Virtual Environment (CRITICAL)
- **Location**: `venv_proj/Scripts/python.exe` (Windows executable)
- **Version**: Python 3.12.9 (confirmed working)
- **Dependencies**: cv2, numpy, os (all confirmed working)
- **DO NOT MODIFY**: The existing virtual environment setup

### 3. Test Image Validation (REQUIRED FOR ALL CHANGES)
- **test_face.jpg**: Must detect 3 rows × 1 column grid
- **test_verso.jpg**: Must detect 1 row × 1 column grid  
- **Extraction Results**: Must produce 3 individual card images from face
- **Combination Results**: Must create 1 lot image + 3 combined images
- **Performance**: Complete workflow must finish successfully

### 4. Database Integration Pattern (PRESERVE EXACTLY)
```r
# Pattern found in multiple modules - must be maintained:
source("R/tracking_database.R")
```

**Requirements:**
- Direct sourcing of tracking_database.R in each module that needs DB access
- No centralized database connection management
- Maintain existing session and image tracking calls

### 5. Session Directory Management (CRITICAL FOR FILE PATHS)
```r
# Pattern from mod_postal_cards_face.R:88+ that must be preserved:
session_temp_dir <- tempfile("shiny_session_images_")
dir.create(session_temp_dir, showWarnings = FALSE, recursive = TRUE)
resource_prefix <- ns("session_images")
shiny::addResourcePath(prefix = resource_prefix, directoryPath = session_temp_dir)
python_output_subdir_name <- "py_extracted"
```

**Requirements:**
- Each processing module needs its own session directory
- Resource path registration for web access to images
- Python output subdirectory naming convention

### 6. Grid Boundary Logic (COMPLEX - PRESERVE ALGORITHM)
From existing analysis - complex boundary calculation:
```r
# Internal vs external boundary distinction (lines 310-330 in face module)
py_detected_h_internal <- sort(unique(round(py_h_temp[
  py_h_temp > 1e-6 & py_h_temp < (rv$image_dims_original[2] - 1e-6)
])))

# Full boundary construction including edges
rv$h_boundaries <- sort(unique(round(c(0, py_detected_h_internal, rv$image_dims_original[2]))))
```

**Requirements:**
- Preserve exact epsilon values (1e-6) for boundary filtering
- Maintain edge boundary inclusion logic (0 and max_dimension)
- Keep rounding and uniqueness operations in exact order

### 7. Reactive Architecture Dependencies (HIGH RISK)
**Current Complexity (must be carefully managed):**
- **Face Module**: 15+ observeEvent/renderUI/reactive calls
- **Verso Module**: 12+ observeEvent/renderUI/reactive calls
- Shared `reactiveValues()` state between processing components

**Decomposition Requirements:**
- Inter-module reactive communication must be maintained
- Shared state management through function parameters or return values
- Module communication via callback functions (existing pattern with `on_grid_update`, `on_image_upload`, `on_extraction_complete`)

### 8. Master User Authentication Constraints (FROM PRP)
```r
# Pattern that must be implemented and preserved:
if (user_role == "master" && target_user_role == "master" && 
    user_id != target_user_id) {
  stop("Master users cannot delete each other")  
}
```

**Requirements:**
- Two master users with protected status
- Master users can manage own credentials and created users
- Absolute prohibition on mutual deletion
- Authentication logic must be thoroughly tested

## VALIDATION PROTOCOL FOR DECOMPOSITION

### Phase 1 Requirements (BEFORE any code changes)
1. ✅ **Current System Validation**: Test images process correctly
2. ✅ **Module Analysis**: Understand all 6 oversized modules
3. ✅ **Critical Path Documentation**: All constraints documented

### Phase 2+ Requirements (DURING decomposition)
1. **Incremental Testing**: Each split module must pass test image workflow
2. **Integration Testing**: Multi-module workflows must work exactly as before
3. **Python Integration Testing**: All `detect_grid_layout()` calls must work
4. **Grid Synchronization Testing**: Face-verso grid sharing must work

### Failure Recovery Protocol
- **If ANY test fails**: Stop decomposition, analyze root cause
- **If Python integration breaks**: Restore exact integration patterns  
- **If grid detection fails**: Restore exact boundary calculation logic
- **If file paths break**: Restore exact session directory patterns

## SUCCESS CRITERIA FOR EACH PHASE

### Module Size Compliance
- All R files under 400 lines (currently 6 files over limit)
- Each module has single, focused responsibility

### Functional Preservation  
- 100% test image workflow success rate
- Grid detection accuracy matches current results (3x1 for face, 1x1 for verso)
- All extraction and combination functionality preserved

### Performance Requirements
- Complete test workflow in <30 seconds (current system baseline)
- No degradation in processing speed
- Memory usage should not increase significantly

## IMPLEMENTATION ORDER (BASED ON RISK)

### Lowest Risk First: Support Modules
1. **mod_settings.R** → mod_settings_ui + mod_settings_server
2. **mod_delcampe_actions.R** → mod_delcampe_export + mod_ai_extraction + mod_ai_provider_manager

### Medium Risk: Authentication
3. **mod_login.R** extensions → mod_authentication + mod_user_management  

### Highest Risk Last: Core Processing (PYTHON INTEGRATION)
4. **mod_postal_cards_face.R** → mod_face_upload + mod_face_grid_adjust + mod_face_extraction
5. **mod_postal_cards_verso.R** → mod_verso_upload + mod_verso_sync + mod_verso_extraction

### Final Integration
6. **app_server.R** and **tracking_database.R** size reduction through extracted modules

This order minimizes risk of breaking the proven Python integration while allowing incremental validation at each step.