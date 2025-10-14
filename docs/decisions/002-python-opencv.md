# ADR-002: Use Python with OpenCV for Image Processing

**Status:** Accepted  
**Date:** 2024-01-15 (Approximate - documented retroactively)  
**Deciders:** Project Lead, Development Team  
**Technical Story:** Core requirement for postal card detection and extraction

## Context and Problem Statement

The application needs to process images of postal cards, including:
- Detecting grid layouts (multiple cards on a single sheet)
- Finding individual card boundaries
- Cropping and extracting individual cards
- Handling various image formats and quality levels

What technology should we use for these image processing tasks in an R Shiny application?

## Decision Drivers

- **Computer Vision Capabilities:** Need robust algorithms for edge detection, contour finding
- **Integration with R:** Must work seamlessly with R Shiny
- **Team Expertise:** Python experience available in team
- **Performance:** Real-time or near-real-time processing for good UX
- **Community Support:** Active community for troubleshooting
- **Cost:** Prefer open-source solutions
- **Maintenance:** Should be stable and well-maintained

## Considered Options

### Option 1: Pure R with imager or magick packages

**Description:** Use native R image processing packages like `imager` (ImageMagick wrapper) or `magick`

**Pros:**
- ✅ No language bridge needed - pure R solution
- ✅ Simple deployment (no Python dependency)
- ✅ Seamless integration with Shiny
- ✅ R-native data structures

**Cons:**
- ❌ Limited computer vision capabilities compared to OpenCV
- ❌ Fewer examples for complex tasks like grid detection
- ❌ Performance may be slower for complex operations
- ❌ Less active development for CV-specific features
- ❌ Smaller community for CV-specific problems

### Option 2: Python with OpenCV via reticulate

**Description:** Use Python's OpenCV library, called from R using the reticulate package

**Pros:**
- ✅ Industry-standard computer vision library
- ✅ Extensive algorithms for detection, contours, morphological operations
- ✅ Massive community and documentation
- ✅ High performance (C++ backend)
- ✅ Team has Python experience
- ✅ reticulate provides stable R-Python bridge
- ✅ Easy to find examples and solutions

**Cons:**
- ❌ Requires Python dependency and virtual environment
- ❌ Adds complexity to deployment
- ❌ Need to manage Python environment alongside R
- ❌ Cross-language debugging can be tricky
- ❌ Data conversion between R and Python

### Option 3: Web API Service (Cloud-based)

**Description:** Use a cloud-based image processing API (Google Vision, AWS Rekognition, etc.)

**Pros:**
- ✅ No local computation needed
- ✅ Potentially more advanced ML models
- ✅ Scales automatically

**Cons:**
- ❌ Ongoing API costs per image
- ❌ Requires internet connection
- ❌ Data privacy concerns (images sent to third party)
- ❌ Latency from network calls
- ❌ Vendor lock-in
- ❌ Not optimized for postal card grids specifically

## Decision Outcome

**Chosen option:** "Python with OpenCV via reticulate"

### Justification

1. **Superior CV Capabilities:** OpenCV provides exactly the tools needed:
   - `findContours()` for card boundary detection
   - Morphological operations for grid analysis
   - Perspective transforms for card straightening
   - Extensive preprocessing options

2. **Team Readiness:** Team has Python experience and R expertise, making reticulate a natural fit

3. **Proven Integration:** reticulate is mature, stable, and widely used in production R applications

4. **Cost-Effective:** Open-source solution with no per-use costs

5. **Performance:** C++-backed OpenCV provides excellent performance for our use case

6. **Community:** Enormous community means solutions for almost any CV problem

### Positive Consequences

- ✅ Rapid development with extensive OpenCV examples available
- ✅ High-quality grid detection and card extraction
- ✅ Performance meets real-time requirements
- ✅ Can leverage both R and Python ecosystems
- ✅ Easy to add new CV features as needed

### Negative Consequences

- ⚠️ **Deployment Complexity:** Must manage Python virtual environment
  - **Mitigation:** Pre-configured `venv_proj/` with pinned dependencies
  - **Mitigation:** Clear documentation in setup guides
  
- ⚠️ **Cross-Language Debugging:** Issues can span R and Python
  - **Mitigation:** Good error handling and logging in both layers
  - **Mitigation:** Clear interface boundaries between R and Python
  
- ⚠️ **Learning Curve:** Team must understand reticulate
  - **Mitigation:** Document patterns and best practices
  - **Mitigation:** Establish "DO NOT MODIFY" zones in codebase

## Implementation Notes

### File Structure
```
inst/python/
└── extract_postcards.py    # Python OpenCV functions

R/
├── app_server.R            # Loads Python at startup
└── mod_postal_card_processor.R  # Calls Python functions
```

### Key Python Functions
- `detect_grid_layout(image_path, rows, cols)` - Grid detection
- `crop_image_with_boundaries(image_path, boundaries)` - Card extraction
- `combine_face_verso_images(face_path, verso_path)` - Image combination

### Reticulate Configuration
```r
# In app_server.R
reticulate::use_virtualenv("venv_proj", required = TRUE)
reticulate::source_python("inst/python/extract_postcards.py")
```

### Python Environment
- **Python Version:** 3.12.9
- **Key Dependencies:** opencv-python, numpy
- **Environment:** `venv_proj/` (committed to repository)

### Critical Constraints
- ⚠️ **DO NOT MODIFY** the reticulate setup without careful testing
- ⚠️ **PRESERVE** Python virtual environment configuration
- ⚠️ Only extend Python functions, never replace the integration layer

## Related Decisions

- **ADR-001:** Use Golem Framework for R Shiny
- **ADR-003:** Use SQLite for Data Persistence

## References

- [OpenCV Python Documentation](https://docs.opencv.org/4.x/d6/d00/tutorial_py_root.html)
- [reticulate Documentation](https://rstudio.github.io/reticulate/)
- [OpenCV Contour Detection Tutorial](https://docs.opencv.org/4.x/d4/d73/tutorial_py_contours_begin.html)
- [Shiny + reticulate Best Practices](https://rstudio.github.io/reticulate/articles/package.html)

## Validation

### Success Criteria
- ✅ Grid detection accuracy > 90% for typical inputs
- ✅ Card extraction preserves image quality
- ✅ Processing time < 2 seconds per image
- ✅ Stable production operation without Python errors
- ✅ Team can extend functionality without breaking existing code

### Review Date
Reviewed: 2025-10-11 (Documented retroactively)  
Next Review: 2026-01-15 or when major CV requirements change

### Metrics
- Grid detection success rate: ~95% (empirical)
- Average processing time: ~1.5 seconds
- Python-related bugs: Minimal after initial stabilization
- Team productivity: High (leveraging OpenCV examples)

### Outcomes (As of 2025-10-11)
- ✅ Integration is stable and battle-tested
- ✅ Team comfortable with reticulate patterns
- ✅ Successfully implemented multiple CV features
- ✅ No major issues with deployment or maintenance
- ✅ Performance meets requirements

**Verdict:** Decision validated. Continue with current approach.

---

**Last Updated:** 2025-10-11  
**Author:** Project Team  
**Status:** This decision is stable and should not be revisited without compelling reasons
