# Production Testing Guide - eBay Integration

## ⚠️ CRITICAL: Production vs Sandbox

**Sandbox** (Current): Test environment with fake money and test users
**Production**: Real eBay with real listings and real money

## Prerequisites Checklist

Before switching to production, you MUST have:

### 1. eBay Production Application Credentials
- [ ] Production App ID (Client ID)
- [ ] Production Cert ID (Client Secret)
- [ ] Production Dev ID
- [ ] RuName configured for production

**How to get these:**
1. Go to https://developer.ebay.com/my/keys
2. Create a **Production** application keyset (separate from sandbox)
3. Note all credentials

### 2. eBay Business Policies (REQUIRED)
You need to create these in your eBay seller account:

- [ ] **Fulfillment Policy** (shipping rules)
- [ ] **Payment Policy** (how you get paid)
- [ ] **Return Policy** (return rules)

**How to create policies:**
1. Log into eBay seller hub: https://www.ebay.com/sh/ovw
2. Go to **Account → Business Policies**
3. Create policies for each type
4. Note the Policy IDs (you'll need these)

### 3. Verified eBay Seller Account
- [ ] eBay account is in good standing
- [ ] Selling limits are sufficient for your needs
- [ ] Payment method is set up (bank account/PayPal)

---

## Step-by-Step Production Setup

### Step 1: Update .Renviron with Production Credentials

Edit `.Renviron` file in your project root:

```bash
# ===== PRODUCTION CREDENTIALS =====
EBAY_PROD_CLIENT_ID=YourActualProductionClientID
EBAY_PROD_CLIENT_SECRET=YourActualProductionCertID
EBAY_PROD_DEV_ID=YourActualProductionDevID

# ===== BUSINESS POLICIES (GET FROM EBAY SELLER HUB) =====
EBAY_FULFILLMENT_POLICY_ID=your_fulfillment_policy_id
EBAY_PAYMENT_POLICY_ID=your_payment_policy_id
EBAY_RETURN_POLICY_ID=your_return_policy_id

# ===== ENVIRONMENT SWITCH =====
EBAY_ENVIRONMENT=production  # Change from "sandbox" to "production"

# Keep sandbox credentials for future testing
EBAY_SANDBOX_CLIENT_ID=...
EBAY_SANDBOX_CLIENT_SECRET=...
EBAY_SANDBOX_DEV_ID=...
```

**IMPORTANT:** After editing `.Renviron`:
1. Save the file
2. Restart your R session completely
3. Run `Sys.getenv("EBAY_ENVIRONMENT")` to verify it shows "production"

### Step 2: Get Business Policy IDs

**Option A: Via eBay Seller Hub (Easiest)**
1. Go to https://www.ebay.com/sh/ovw
2. Click **Account → Business Policies**
3. Look at the URL when viewing each policy - the ID is in the URL
4. Copy each policy ID into your `.Renviron`

**Option B: Via API (Advanced)**
Use the eBay API to fetch your policy IDs programmatically (requires production OAuth).

### Step 3: Restart App and Verify Environment

```r
# In R console
Sys.getenv("EBAY_ENVIRONMENT")  # Should show: "production"
Sys.getenv("EBAY_PROD_CLIENT_ID")  # Should show your actual ID, not placeholder
```

### Step 4: Authenticate with Production eBay Account

1. Run your app: `golem::run_dev()`
2. Go to **eBay Settings** tab
3. Click **"Connect New Account"**
4. Browser will open to **production eBay** (not sandbox!)
5. Log in with your **real eBay seller account**
6. Authorize the app
7. Copy authorization code back to app
8. Click "Submit Code & Connect"

**Verification:**
- You should see: "Connected: [Your eBay Username] (production environment)"
- NOT "sandbox" environment

---

## Testing Strategy

### Phase 1: Read-Only Testing (Recommended First)

Test without creating real listings:

1. **Upload Images** - Use your real postcard images
2. **Run Extraction** - Test grid detection and cropping
3. **AI Extraction** - Test Claude/GPT integration
4. **Review Data** - Check titles, descriptions, pricing

**DO NOT click "Post to eBay" yet!**

### Phase 2: Single Test Listing

Create ONE test listing:

1. Choose a low-value postcard ($1-2)
2. Fill in all details carefully
3. Review everything twice
4. Click "Post to eBay"
5. **IMMEDIATELY check eBay:**
   - Go to https://www.ebay.com/sh/lst/active
   - Find your listing
   - Verify all details are correct
   - **If anything is wrong, END THE LISTING immediately**

### Phase 3: Gradual Scaling

If test listing looks good:
1. Start with 2-3 listings per session
2. Verify each batch on eBay
3. Gradually increase volume
4. Monitor for any issues

---

## Important Production Differences

### Sandbox vs Production Behavior

| Feature | Sandbox | Production |
|---------|---------|------------|
| Money | Fake | **Real** |
| Listings | Hidden from public | **Public on eBay** |
| Sales | Simulated | **Real transactions** |
| Fees | No fees | **eBay fees apply** |
| Images | Test images OK | Must be real, quality images |
| Descriptions | Can be nonsense | Must be accurate, professional |
| Prices | Can be $0.01 | Should be realistic market prices |

### Production Costs to Consider

- **Insertion fees**: Varies by category (often free for first X listings/month)
- **Final value fees**: ~10-15% of sale price + $0.30
- **Payment processing**: ~2.9% + $0.30 (if using eBay Managed Payments)

**Check eBay's current fee structure:** https://www.ebay.com/help/selling/fees-credits-invoices

---

## Safety Checklist Before Each Listing

Before clicking "Post to eBay" in production:

- [ ] Image quality is good (not blurry, proper lighting)
- [ ] Title accurately describes the item
- [ ] Description is truthful and detailed
- [ ] Price is reasonable (check eBay sold listings for comparable items)
- [ ] Condition is accurately stated
- [ ] Shipping cost/time is realistic
- [ ] Business policies are appropriate
- [ ] You actually own/possess this item

---

## Troubleshooting Production Issues

### Issue: "Failed to create listing"

**Possible causes:**
1. Business policies not set up correctly
2. Missing required item specifics for category
3. Image doesn't meet eBay requirements
4. Price outside acceptable range
5. Duplicate listing (same item already listed)

**Solution:**
- Check error message carefully
- Verify all business policies are valid
- Try listing manually on eBay to identify missing fields
- Check eBay API logs in console

### Issue: "OAuth failed" or "Token expired"

**Solution:**
1. Disconnect account in app
2. Connect again with production credentials
3. Make sure you're using your **production** eBay account

### Issue: Listing appears but with wrong details

**Immediate action:**
1. Go to https://www.ebay.com/sh/lst/active
2. Find the listing
3. Click "End listing" immediately
4. Select reason: "No longer available for sale"
5. Fix the issue in your app
6. Try again with corrected details

---

## Monitoring Your Listings

### Check Your Active Listings
- **eBay Seller Hub**: https://www.ebay.com/sh/ovw
- **Active Listings**: https://www.ebay.com/sh/lst/active
- **Unsold Listings**: https://www.ebay.com/sh/lst/unsold
- **Sold Items**: https://www.ebay.com/sh/lst/sold

### Track Performance
- Monitor which postcards sell vs. don't sell
- Adjust pricing based on market response
- Refine descriptions based on buyer questions

---

## Switching Back to Sandbox

If you need to go back to sandbox for testing:

1. Edit `.Renviron`:
   ```bash
   EBAY_ENVIRONMENT=sandbox
   ```

2. Restart R session completely

3. In app, disconnect production account

4. Connect with sandbox account

---

## Best Practices

### DO:
✅ Start with ONE test listing
✅ Verify each listing on eBay immediately
✅ Use real, accurate descriptions
✅ Price competitively (check sold listings)
✅ Keep business policies up to date
✅ Monitor your eBay seller dashboard regularly

### DON'T:
❌ List items you don't actually have
❌ Use misleading titles or descriptions
❌ Set unrealistic shipping times
❌ Ignore eBay fees in your pricing
❌ Create dozens of listings without verifying the first few
❌ Use test/placeholder text in production listings

---

## Emergency Procedures

### If Something Goes Wrong:

1. **Stop immediately** - Don't create more listings
2. **Check eBay** - Review what was actually posted
3. **End bad listings** - Go to eBay and end any problematic listings
4. **Switch to sandbox** - Change `.Renviron` back to sandbox mode
5. **Debug** - Figure out what went wrong in sandbox
6. **Fix** - Correct the issue
7. **Test in sandbox** - Verify fix works
8. **Try production again** - With just ONE test listing

### If a Listing Sells:

1. ✅ Ship the item promptly (within your stated timeframe)
2. ✅ Mark it as shipped in eBay
3. ✅ Provide tracking number
4. ✅ Communicate with buyer if any issues
5. ✅ Request feedback after delivery

**Remember:** In production, you have legal obligations to fulfill sales!

---

## Getting Help

### eBay Support
- **Seller Help**: https://www.ebay.com/help/selling
- **Community Forums**: https://community.ebay.com/
- **Contact eBay**: https://www.ebay.com/help/home (look for "Contact us")

### API Issues
- **eBay Developer Program**: https://developer.ebay.com/support
- **API Documentation**: https://developer.ebay.com/develop/apis

### App Issues
- Check console output for detailed error messages
- Review `.Renviron` configuration
- Verify business policies are set correctly
- Test in sandbox first

---

## Summary: Quick Start Checklist

1. [ ] Get production eBay API credentials
2. [ ] Create business policies in eBay Seller Hub
3. [ ] Update `.Renviron` with production credentials and policy IDs
4. [ ] Change `EBAY_ENVIRONMENT=production`
5. [ ] Restart R session completely
6. [ ] Run app and connect production account
7. [ ] Verify environment shows "production"
8. [ ] Test with ONE low-value listing first
9. [ ] Verify listing on eBay.com
10. [ ] If good, proceed carefully with more listings

**Remember:** Production = Real Money = Real Responsibility

Take it slow, verify everything, and don't hesitate to switch back to sandbox if you need to test changes!
