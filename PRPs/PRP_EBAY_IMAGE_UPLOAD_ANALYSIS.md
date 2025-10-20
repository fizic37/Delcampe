# PRP: eBay Image Upload Solution Analysis

## Context

**Current State:**
- Production eBay API integration is complete and functional
- Listings are being created successfully with placeholder images
- `R/ebay_integration.R` currently uses: `"https://via.placeholder.com/500x350.png?text=Postcard"`
- Local postcard images exist but cannot be used directly

**Problem:**
eBay requires publicly accessible HTTPS URLs for images. Local file paths (`file://`, local temp files) are not accepted by eBay's API.

**Confirmed Technical Constraint:**
- eBay Commerce Media API requires either:
  - Option A: Publicly accessible HTTPS URLs (via `ExternalPictureURL`)
  - Option B: Binary image uploads (via `UploadSiteHostedPictures` multipart/form-data)

## Goal

Analyze and recommend the **simplest and most optimal** solution to enable local image uploads from the R Shiny application to eBay, considering:

1. **Implementation complexity** (minimize code changes)
2. **Reliability** (production-ready, minimal failure points)
3. **Cost** (prefer free/low-cost solutions)
4. **Integration ease** (works well with existing R/Shiny codebase)
5. **Maintenance burden** (minimal ongoing management)

## Key Constraints

1. **Language/Framework**: R Shiny application (not Python, Node.js, etc.)
2. **Current flow**: `postal_cards` table → `R/ebay_integration.R` → eBay API
3. **Image source**: Local files stored in application directory
4. **Production requirement**: Must work reliably with eBay production API
5. **Existing infrastructure**: No cloud services currently configured

## Analysis Required

Evaluate and compare these approaches:

### Option 1: eBay EPS Binary Upload
- Use `UploadSiteHostedPictures` API with multipart/form-data
- Upload image binary directly to eBay Picture Services
- Receive back EPS URL for listing
- **Requires**: HTTP multipart request construction in R

### Option 2: Temporary Cloud Storage
- Upload to free/low-cost image host (Imgur, Cloudinary, etc.)
- Get public HTTPS URL
- Pass URL to eBay via `ExternalPictureURL`
- **Requires**: Third-party service integration

### Option 3: Local Web Server Bridge
- Spin up temporary local HTTP server
- Make images temporarily accessible
- Upload to eBay, then shut down server
- **Requires**: Port management, firewall considerations

### Option 4: Base64 Encoding (if supported)
- Encode image as base64
- Include in API request
- **Requires**: Verification of eBay API support

## Deliverables

Provide:

1. **Recommended Solution**: Single best approach with justification
2. **Implementation Overview**: High-level steps (not detailed code)
3. **Required R Packages**: List any additional dependencies needed
4. **Risk Assessment**: Potential failure modes and mitigations
5. **Integration Points**: Where in `R/ebay_integration.R` to integrate
6. **Alternative Ranking**: Backup options if primary fails

## Success Criteria

- ✅ Solution integrates cleanly with existing `create_ebay_listing_from_card()`
- ✅ Minimal code changes to working production flow
- ✅ No ongoing manual intervention required
- ✅ Works reliably with eBay production environment
- ✅ Clear implementation path for next PRP

## Out of Scope

- Detailed implementation code (save for execution PRP)
- UI changes (focus on backend solution)
- Image processing/optimization (assume images are ready)
- Multi-account handling (covered by existing `ebay_account_manager.R`)

---

**Status**: Analysis Required  
**Priority**: High (blocks production listings with real images)  
**Estimated Analysis Time**: 30 minutes  
**Next PRP**: Implementation based on recommended solution
