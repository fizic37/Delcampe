# PRP: eBay OAuth Connection Failure in Production

**Date**: 2025-11-05
**Status**: ACTIVE - Investigation & Debugging
**Priority**: CRITICAL
**Complexity**: HIGH
**Environment**: Hetzner Production Server (Docker)

## Executive Summary

eBay OAuth authentication is failing in production Docker deployment with "unauthorized_client" error, despite having correct credentials loaded via environment variables. The authentication system migration caused database schema conflicts that have been partially resolved, but eBay connection still fails.

## Current State

### Error Symptoms
1. **Primary Error**: "unauthorized_client" when attempting to connect eBay account
2. **Database Schema Fixed**: ✅ Resolved "table users has no column named user_id" errors
3. **Authentication Working**: ✅ Can login with master1@delcampe.com
4. **Credentials Loaded**: ✅ All EBAY_PROD_* environment variables present in container

### Environment Details
- **Server**: Hetzner VPS (37.27.80.87:3838)
- **Container**: delcampe-app (rocker/shiny:4.3.3)
- **Database**: /data/tracking.sqlite (persistent volume)
- **Deployment**: Docker Compose with .env.production

### Credentials Verified Present
```bash
# Confirmed via: docker exec delcampe-app printenv | grep EBAY
EBAY_PROD_CLIENT_ID=TITAMARI-Delcampe-PRD-2ead09bb4-ebc86ad4
EBAY_PROD_CLIENT_SECRET=PRD-ead09bb48777-72d3-4499-9b7e-dd18
EBAY_PROD_CERT_ID=PRD-ead09bb48777-72d3-4499-9b7e-dd18
EBAY_PROD_DEV_ID=f31d6100-687c-483f-b762-a0d486e12a68
EBAY_REDIRECT_URI=TITA_MARIUS-TITAMARI-Delcam-njpondg
EBAY_ENVIRONMENT=production
```

## Problem History

### What We've Fixed Already
1. ✅ **Volume permissions**: Changed `/mnt/HC_Volume_103879961` to 999:999
2. ✅ **Database path abstraction**: Implemented `get_db_path()` for Docker detection
3. ✅ **Infinite recursion**: Fixed function default parameters calling `get_db_path()`
4. ✅ **docker-compose env vars**: Removed `environment:` section causing empty variables
5. ✅ **Missing CERT_ID**: Added `EBAY_PROD_CERT_ID` to .env.production
6. ✅ **Database schema conflict**: Removed old users table, fixed JOIN clauses to use new `id` column
7. ✅ **Session initialization**: Removed user INSERT from `start_processing_session()`

### What's Still Failing
- ❌ **eBay OAuth**: "unauthorized_client" error persists
- ⚠️ **Warning in logs**: "eBay API credentials not found" (though env vars exist)
- ⚠️ **Application token**: "Failed to get application token: HTTP 401 Unauthorized"

## Investigation Plan

### Phase 1: Credential Flow Verification

**Step 1**: Verify credential loading in R environment
```bash
# On Hetzner server:
docker exec delcampe-app Rscript -e "cat(Sys.getenv('EBAY_PROD_CLIENT_ID'), '\n')"
docker exec delcampe-app Rscript -e "cat(Sys.getenv('EBAY_PROD_CLIENT_SECRET'), '\n')"
docker exec delcampe-app Rscript -e "cat(Sys.getenv('EBAY_PROD_CERT_ID'), '\n')"
```

**Expected**: All should print non-empty values

**Step 2**: Check R/ebay_api.R credential initialization
- Location: R/ebay_api.R (EbayAPI$initialize method)
- Verify it reads `EBAY_PROD_*` variables when `EBAY_ENVIRONMENT=production`
- Confirm no hardcoded sandbox references

**Step 3**: Trace OAuth flow in R/mod_ebay_settings.R
- Verify OAuth URL construction uses correct production endpoints
- Check redirect URI matches eBay Developer Portal configuration
- Confirm state parameter is properly maintained

### Phase 2: eBay Developer Portal Verification

**Step 1**: Verify OAuth Redirect URI in eBay App Settings
- Login to: https://developer.ebay.com/my/keys
- Navigate to production keys for app "Delcampe"
- Confirm "OAuth redirect URI" field contains:
  ```
  TITA_MARIUS-TITAMARI-Delcam-njpondg
  ```
- **CRITICAL**: Redirect URIs must match EXACTLY (case-sensitive, no trailing slashes)

**Step 2**: Verify Production Credentials Match
- Compare CLIENT_ID, CLIENT_SECRET, CERT_ID with .env.production values
- Check if credentials have been rotated/regenerated
- Verify app is in "Production" status (not "Sandbox only")

**Step 3**: Check OAuth Scopes Required
- Verify app has these scopes enabled:
  - `https://api.ebay.com/oauth/api_scope` (basic)
  - `https://api.ebay.com/oauth/api_scope/sell.inventory` (for Trading API)
  - `https://api.ebay.com/oauth/api_scope/sell.account` (for account access)

### Phase 3: Code Analysis

**File: R/ebay_api.R**
```r
# Check initialize() method:
# 1. Does it correctly detect EBAY_ENVIRONMENT=production?
# 2. Does it load EBAY_PROD_* variables?
# 3. Does it construct correct OAuth endpoints?
# 4. Is cert_id being used in API calls?
```

**File: R/mod_ebay_settings.R**
```r
# Check OAuth flow:
# 1. How is authorization URL constructed?
# 2. Is state parameter properly saved/retrieved?
# 3. Does redirect_uri match env variable exactly?
# 4. Is token exchange using correct endpoint?
```

**File: R/auth_system.R**
```r
# Check if authentication affects eBay OAuth:
# 1. Does user session isolation cause issues?
# 2. Are eBay tokens stored per-user in database?
# 3. Is there a session cleanup breaking OAuth state?
```

### Phase 4: Logging Enhancement

**Add detailed logging to trace OAuth flow**:

**Location: R/ebay_api.R**
```r
# Add to initialize() method:
message("🔍 eBay Environment: ", Sys.getenv("EBAY_ENVIRONMENT"))
message("🔍 CLIENT_ID loaded: ", substr(self$client_id, 1, 20), "...")
message("🔍 CLIENT_SECRET loaded: ", if(nchar(self$client_secret) > 0) "YES" else "NO")
message("🔍 CERT_ID loaded: ", if(nchar(self$cert_id) > 0) "YES" else "NO")
message("🔍 REDIRECT_URI: ", self$redirect_uri)
```

**Location: R/mod_ebay_settings.R**
```r
# Add to OAuth URL construction:
message("🔍 OAuth URL: ", oauth_url)
message("🔍 State parameter: ", state)

# Add to token exchange:
message("🔍 Authorization code received: ", substr(code, 1, 20), "...")
message("🔍 Token exchange endpoint: ", token_url)
message("🔍 Token exchange status: ", response$status_code)
if (response$status_code != 200) {
  message("❌ Token exchange error: ", httr::content(response, "text"))
}
```

### Phase 5: Comparison with Local Working Setup

**Compare environments**:
```r
# Local (working):
# - Database: inst/app/data/tracking.sqlite
# - Credentials: .Renviron
# - Environment detection: file.exists("/data") = FALSE

# Production (failing):
# - Database: /data/tracking.sqlite
# - Credentials: docker-compose env_file
# - Environment detection: file.exists("/data") = TRUE
```

**Potential differences**:
1. Database schema mismatch (already fixed)
2. Session ID generation different?
3. OAuth state parameter storage location?
4. Redirect URI handling in Docker?

## Acceptance Criteria

### Must Have
1. ✅ User can login at http://37.27.80.87:3838
2. ✅ Database initializes on /data volume
3. ✅ All EBAY_PROD_* credentials loaded in container
4. ❌ User can click "Connect eBay Account" and complete OAuth flow successfully
5. ❌ eBay account connection persists after page refresh
6. ❌ No "unauthorized_client" errors in logs
7. ❌ No "eBay API credentials not found" warnings

### Should Have
1. Clear error messages if OAuth fails with reason
2. Ability to disconnect and reconnect eBay account
3. Logging shows successful token acquisition

### Nice to Have
1. OAuth state debugging panel in UI
2. Environment variable viewer in settings (admin only)
3. eBay credential test button

## Technical Constraints

1. **Production Credentials**: Cannot be checked into git
2. **Docker Environment**: Must work in containerized deployment
3. **Volume Persistence**: Database on Hetzner volume must retain eBay tokens
4. **Multi-User**: Each authenticated user should have their own eBay connection
5. **Security**: OAuth tokens must be stored encrypted or hashed

## Next Steps

### Immediate Actions (For AI Assistant)
1. Read R/ebay_api.R and analyze credential loading logic
2. Read R/mod_ebay_settings.R and analyze OAuth flow
3. Add comprehensive logging to OAuth flow (Phase 4)
4. Check if redirect URI construction is environment-aware

### User Actions Required
1. Verify eBay Developer Portal settings (Phase 2)
2. Run enhanced logging version on Hetzner
3. Capture full OAuth flow logs
4. Compare with local working setup

## Related Files

### Code Files to Investigate
- `R/ebay_api.R` - eBay API client initialization and credentials
- `R/mod_ebay_settings.R` - OAuth flow implementation
- `R/auth_system.R` - User authentication (may affect eBay OAuth)
- `R/tracking_database.R` - Database schema and eBay token storage

### Configuration Files
- `.env.production` - Production credentials (server only)
- `.Renviron` - Development credentials (local only)
- `docker-compose.yml` - Docker environment configuration
- `Dockerfile` - Container build configuration

### Related PRPs
- `PRP_DOCKER_DEPLOYMENT_HETZNER.md` - Deployment configuration
- `PRP_EBAY_MULTI_ACCOUNT.md` - Multi-account eBay support
- `PRP_EBAY_ACCESS_UX_IMPROVEMENTS.md` - OAuth UX improvements

## Success Metrics

- **OAuth Success Rate**: 100% (currently 0%)
- **Time to Connect**: < 30 seconds
- **Error Rate**: 0% "unauthorized_client" errors
- **Uptime**: eBay connections persist across app restarts

## Risk Assessment

**HIGH RISK**: Production deployment is not functional for core eBay feature

**Potential Root Causes** (ordered by likelihood):
1. **Redirect URI mismatch**: Production OAuth redirect may differ from Developer Portal
2. **Credential format error**: CERT_ID may be wrong credential type
3. **OAuth endpoint mismatch**: Using sandbox URLs with production credentials
4. **Session state issue**: OAuth state parameter not persisting in database
5. **Network issue**: Docker container cannot reach eBay OAuth servers
6. **Rate limiting**: eBay blocking requests from Hetzner IP range

## Appendix: Credential Environment Variables

### Required Variables
```bash
EBAY_ENVIRONMENT=production          # Selects prod vs sandbox
EBAY_PROD_CLIENT_ID=<from eBay>     # OAuth Client ID
EBAY_PROD_CLIENT_SECRET=<from eBay> # OAuth Client Secret
EBAY_PROD_CERT_ID=<from eBay>       # OAuth Certificate ID
EBAY_PROD_DEV_ID=<from eBay>        # Application Developer ID
EBAY_REDIRECT_URI=<from eBay>       # OAuth Redirect URI (must match portal exactly)
```

### Optional Variables
```bash
EBAY_SANDBOX_CLIENT_ID=<from eBay>
EBAY_SANDBOX_CLIENT_SECRET=<from eBay>
EBAY_SANDBOX_CERT_ID=<from eBay>
```

## Notes

- This PRP should be executed systematically through each phase
- Each phase should be completed and logged before moving to next
- If Phase 1-2 pass, issue is in code logic (Phase 3-4)
- If Phase 1-2 fail, issue is in credentials or portal configuration
- Keep this PRP updated as investigation progresses
