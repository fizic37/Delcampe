# eBay Image Upload Requirement

## Current Status: Blocked on Image Hosting

**Problem**: eBay production listings require publicly accessible image URLs. Local file paths cannot be used.

**Current Error**: `2004: Invalid request` when creating inventory item with placeholder or local image path.

## What Works Now

✅ OAuth authentication (production)
✅ Business policies configured
✅ Condition mapping (USED, NEW, etc.)
✅ Inventory API integration
✅ Multi-account support

## What's Blocked

❌ **Production listings** - Cannot create real eBay listings without public image URLs

## Solutions (Choose One)

### Option 1: eBay Picture Services (EPS) - Recommended

eBay provides their own image hosting service specifically for listings.

**Pros:**
- Official eBay solution
- Images hosted on eBay's CDN
- No third-party dependencies
- Free for sellers

**Cons:**
- Requires additional API implementation
- Images tied to eBay account

**Implementation needed:**
- Upload API endpoint: `POST /sell/media/v1/video`
- Returns public image URL
- Use that URL in inventory item creation

**API Documentation**: https://developer.ebay.com/api-docs/sell/media/overview.html

### Option 2: Third-Party Image Hosting (Imgur, Cloudinary, AWS S3)

Upload images to external hosting service, get public URLs.

**Pros:**
- Simple REST APIs
- Images can be reused across platforms
- Free tiers available

**Cons:**
- External dependency
- May have upload limits
- Cost at scale

**Example services:**
- **Imgur**: Free, simple API, 50 images/hour limit
- **Cloudinary**: Free tier, 25GB storage
- **AWS S3**: Pay-as-you-go, unlimited

### Option 3: Self-Hosted Solution

Set up your own web server to serve images publicly.

**Pros:**
- Full control
- No external dependencies
- No API limits

**Cons:**
- Requires web server setup
- Domain/hosting costs
- Maintenance overhead
- Security concerns

## Recommended Approach

**For MVP/Testing:**
1. Implement **Imgur integration** (simplest, free)
   - Upload postcard image to Imgur
   - Get public URL
   - Use in eBay listing

**For Production:**
1. Migrate to **eBay Picture Services** (official solution)
   - More reliable long-term
   - Better integration with eBay ecosystem

## Implementation Status

- [x] eBay OAuth (production)
- [x] Business policies
- [x] Condition mapping
- [x] Basic listing flow
- [ ] **Image upload implementation** ← YOU ARE HERE
- [ ] Full production listing test

## Next Steps

1. Choose image hosting solution
2. Implement upload functionality
3. Test with single postcard
4. Verify listing appears on eBay.com
5. Scale to batch processing

## Code Location

When ready to implement, update:
- `R/ebay_integration.R` - `create_ebay_listing_from_card()` function
- Add new file: `R/image_upload_service.R` (for chosen solution)
- Update `R/mod_delcampe_export.R` - Call upload before eBay listing

## Testing Notes

**Sandbox vs Production:**
- Sandbox may accept placeholder URLs for testing
- Production **requires real, accessible URLs**
- Test upload integration in sandbox first

**Image Requirements (eBay):**
- Minimum: 500px on longest side
- Maximum: 12MB file size
- Formats: JPG, PNG, GIF
- At least 1 image required, up to 24 allowed

## Current Workaround

None - production listings are blocked until image hosting is implemented.

For testing the rest of the flow, you could:
1. Manually upload image to Imgur
2. Get public URL
3. Hardcode URL temporarily in `ebay_integration.R`
4. Test the listing flow

But this won't work for batch processing.

---

**Status**: Documentation complete. Ready for implementation decision.
