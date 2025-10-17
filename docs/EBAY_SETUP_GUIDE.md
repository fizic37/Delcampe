# eBay API Setup Instructions for Delcampe App

## Quick Start Guide

### Step 1: Register for eBay Developer Program

1. Go to https://developer.ebay.com
2. Click "Register" (top right)
3. Create a NEW account (different from your eBay seller account):
   - Use a unique username
   - Use the same email as in your Gmail (for consistency)
   - Select your country
   - Accept the API License Agreement

4. Wait for approval (usually within 24 hours, check your email)

### Step 2: Get Your API Credentials

Once approved:

1. Log into https://developer.ebay.com
2. Go to "My Account" → "Application Keys"
3. Create an application:
   - Application Title: "Delcampe Postcard Lister" (or similar)
   - Click "Create"

4. You'll get TWO sets of credentials:
   - **Sandbox Keys** (for testing - start here!)
   - **Production Keys** (for real listings - use later)

5. For each environment, you'll see:
   - App ID (Client ID)
   - Dev ID
   - Cert ID (Client Secret)

### Step 3: Update Your .Renviron File

Open the file: `C:\Users\mariu\Documents\R_Projects\Delcampe\.Renviron`

Replace the placeholder values with your actual credentials:

```
# Sandbox credentials (for testing)
EBAY_SANDBOX_CLIENT_ID=paste_your_sandbox_app_id_here
EBAY_SANDBOX_CLIENT_SECRET=paste_your_sandbox_cert_id_here

# Production credentials (for live listings)
EBAY_PROD_CLIENT_ID=paste_your_production_app_id_here
EBAY_PROD_CLIENT_SECRET=paste_your_production_cert_id_here

# Keep this as sandbox for now
EBAY_ENVIRONMENT=sandbox
```

### Step 4: Set Up eBay Business Policies

1. Log into your eBay seller account
2. Go to: https://www.ebay.com/sh/buspolicy
3. Create these policies if you don't have them:

   **Payment Policy:**
   - Name it something like "Standard Payment"
   - Select accepted payment methods
   - Note the Policy ID

   **Return Policy:**
   - Name it something like "30 Day Returns"
   - Set your return terms
   - Note the Policy ID

   **Shipping Policy:**
   - Name it something like "Standard Shipping"
   - Set shipping methods and costs
   - Note the Policy ID

4. Add these IDs to your .Renviron file:
```
EBAY_FULFILLMENT_POLICY_ID=your_shipping_policy_id
EBAY_PAYMENT_POLICY_ID=your_payment_policy_id
EBAY_RETURN_POLICY_ID=your_return_policy_id
```

### Step 5: Test Your Connection

1. Restart R/RStudio (to load the new environment variables)

2. Run your Shiny app:
```r
library(shiny)
runApp()
```

3. In the app:
   - Look for the "eBay API Connection" section
   - Click "Connect to eBay"
   - Authorize in the browser window that opens
   - Copy the authorization code from the URL
   - Paste it back in the app

### Step 6: Create a Test Listing (Sandbox)

1. Make sure you're in Sandbox mode (check .Renviron: EBAY_ENVIRONMENT=sandbox)
2. Fill out the postcard details in the app
3. Click "Create Listing"
4. This will create a test listing (not visible on real eBay)

### Step 7: Switch to Production (When Ready)

1. Change in .Renviron:
```
EBAY_ENVIRONMENT=production
```

2. Restart R/RStudio
3. Re-authorize with production credentials
4. Create real listings!

## Troubleshooting

### "eBay API credentials not found"
- Make sure you've saved the .Renviron file
- Restart R/RStudio after saving
- Check credentials are copied correctly (no extra spaces)

### "Authentication failed"
- Make sure you're using the correct environment (sandbox vs production)
- Authorization codes expire quickly - paste immediately
- Check that redirect URI matches what's in eBay developer settings

### "Failed to create listing"
- In Sandbox: Normal - sandbox has limitations
- In Production: Check all required fields are filled
- Verify Business Policy IDs are correct

## Important Notes

1. **Start with Sandbox**: Always test in sandbox first
2. **Rate Limits**: eBay has API call limits (5,000/day for most APIs)
3. **Token Expiry**: Access tokens last 2 hours, refresh tokens last 18 months
4. **Image Upload**: Currently images need to be uploaded separately to eBay Picture Services

## Next Steps

1. Test creating a listing in Sandbox
2. Integrate with your existing postcard processing workflow
3. Add bulk listing capabilities
4. Implement image upload to eBay Picture Services

## Support Resources

- eBay Developer Forums: https://community.ebay.com/t5/Developer-Groups/ct-p/developergroup
- API Documentation: https://developer.ebay.com/api-docs/sell/inventory/overview.html
- Your Gmail (for storing credentials securely)

## Security Reminder

- Never commit .Renviron to git (it's already in .gitignore)
- Keep your credentials secure
- Use different credentials for sandbox and production
