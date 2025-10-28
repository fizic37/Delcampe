# eBay API Documentation for Postcard Listings

## Critical API Documentation Links

### Official eBay Developer Resources
- **Developer Portal**: https://developer.ebay.com
- **Sandbox Portal**: https://sandbox.ebay.com (US marketplace for testing)
- **Inventory API Overview**: https://developer.ebay.com/api-docs/sell/inventory/overview.html
- **Required Fields Guide**: https://developer.ebay.com/api-docs/sell/static/inventory/publishing-offers.html
- **OAuth Documentation**: https://developer.ebay.com/api-docs/static/oauth-tokens.html

## Sandbox Environment Details

### Sandbox URLs
- **API Base URL**: `https://api.sandbox.ebay.com`
- **Auth URL**: `https://auth.sandbox.ebay.com`
- **Web Interface**: `https://sandbox.ebay.com` (view your test listings)
- **View Specific Listing**: `https://sandbox.ebay.com/itm/{ItemID}`

### Test Users
- Default test users have prefix `TESTUSER_`
- Each test user gets $500,000 play money (refreshed weekly)
- Create at least 2 test users: one seller, one buyer
- Example naming: `TESTUSER_postcard_seller`, `TESTUSER_buyer1`

## Required Fields for Postcard Listings

### Minimum Required Fields (from API docs)

#### 1. Inventory Item Fields (createOrReplaceInventoryItem)
```yaml
Required:
  - sku: Unique identifier for your inventory
  - product.title: Item title (max 80 characters)
  - product.description: Full description (max 4000 chars, HTML allowed)
  - product.imageUrls: At least one image URL
  - condition: Item condition code
  - availability.shipToLocationAvailability.quantity: Available quantity

Optional but Recommended:
  - product.aspects: Item specifics (see below)
  - conditionDescription: Additional condition details (max 1000 chars)
```

#### 2. Location Fields (createInventoryLocation)
```yaml
Required:
  - merchantLocationKey: Unique location identifier
  - location.address.country: Two-letter country code
  - location.address.postalCode: Postal/ZIP code
  
For Store locations also need:
  - location.address.city
  - location.address.stateOrProvince
```

#### 3. Offer Fields (createOffer)
```yaml
Required:
  - sku: Reference to inventory item
  - marketplaceId: "EBAY_US" for US market
  - format: "FIXED_PRICE" or "AUCTION"
  - pricingSummary.price.value: Price as string
  - pricingSummary.price.currency: "USD"
  - listingPolicies: Payment, return, fulfillment policy IDs
  - categoryId: eBay category (914 for postcards)
```

## Postcard-Specific Requirements

### Category Information
- **Primary Category ID**: `914` (Collectibles > Postcards & Supplies > Postcards)
- **Subcategories**:
  - Topographical Postcards
  - Non-Topographical Postcards
  - Various theme-based categories

### Required/Recommended Aspects for Postcards

Based on eBay's category requirements, postcards should include:

```yaml
Typical Postcard Aspects:
  Type: 
    - values: ["Postcard"]
    - required: Often
    
  Era:
    - values: ["Pre-1900", "1900-1919", "1920-1939", "1940-1959", "1960-1979", "1980-Present", "Unknown"]
    - required: Recommended
    
  Theme:
    - values: ["Travel", "Cities & Towns", "Famous Places", "Greetings", "Holiday", "Art", "Military", "Transportation", "Animals", "Nature", "Other"]
    - required: Recommended
    
  Original/Licensed Reprint:
    - values: ["Original", "Licensed Reprint"]
    - required: Recommended
    
  Posted/Unposted:
    - values: ["Posted", "Unposted"]
    - required: Optional
    
  Country/Region of Manufacture:
    - values: [Any country name or "Unknown"]
    - required: Optional
    
  Size:
    - values: ["Standard (3.5 x 5.5 in)", "Continental (4 x 6 in)", "Other"]
    - required: Optional
```

### Condition Codes for Postcards
```yaml
Allowed Conditions:
  NEW: "Brand new, unused"
  LIKE_NEW: "Like new, minimal signs of use"
  NEW_OTHER: "New but see description"
  USED_EXCELLENT: "Used but excellent condition"
  USED_VERY_GOOD: "Used, very good condition"
  USED_GOOD: "Used, good condition"
  USED_ACCEPTABLE: "Used, acceptable condition"
```

## API Call Flow for Creating a Listing

### Step-by-Step Process

1. **Create Inventory Location** (one-time setup)
```http
POST /sell/inventory/v1/location/{merchantLocationKey}
```

2. **Create/Update Inventory Item**
```http
PUT /sell/inventory/v1/inventory_item/{sku}
Body: {
  "product": {
    "title": "Vintage Paris Eiffel Tower Postcard 1950s",
    "description": "Beautiful vintage postcard...",
    "imageUrls": ["https://..."],
    "aspects": {
      "Type": ["Postcard"],
      "Era": ["1940-1959"],
      "Theme": ["Famous Places"],
      "Original/Licensed Reprint": ["Original"],
      "Posted/Unposted": ["Unposted"]
    }
  },
  "condition": "USED_EXCELLENT",
  "conditionDescription": "Minor wear on corners...",
  "availability": {
    "shipToLocationAvailability": {
      "quantity": 1
    }
  }
}
```

3. **Create Offer**
```http
POST /sell/inventory/v1/offer
Body: {
  "sku": "PC-001",
  "marketplaceId": "EBAY_US",
  "format": "FIXED_PRICE",
  "categoryId": "914",
  "listingPolicies": {
    "fulfillmentPolicyId": "123456",
    "paymentPolicyId": "234567",
    "returnPolicyId": "345678"
  },
  "pricingSummary": {
    "price": {
      "currency": "USD",
      "value": "9.99"
    }
  },
  "merchantLocationKey": "default_location"
}
```

4. **Publish Offer**
```http
POST /sell/inventory/v1/offer/{offerId}/publish
```

Returns:
```json
{
  "listingId": "110552376745"
}
```

## OAuth Scopes Required

For postcard listings, you need:
```
https://api.ebay.com/oauth/api_scope/sell.inventory
```

This scope allows:
- Creating/updating inventory items
- Managing locations
- Creating/publishing offers
- Managing listings

## Constraints and Limitations

### Sandbox Limitations
- Listings are not visible in production eBay
- Payment processing is simulated
- Some features may be limited or unavailable
- Test data is periodically cleaned

### API Limits
- **Revision limit**: 250 revisions per listing per day
- **API calls**: 5,000 calls per day (most APIs)
- **Token expiry**: Access tokens valid for 2 hours
- **Refresh tokens**: Valid for 18 months

### Listing Constraints
- **Title**: Maximum 80 characters
- **Description**: Maximum 4000 characters
- **Images**: At least 1, maximum 12 images
- **Price**: Must be greater than 0
- **Quantity**: Minimum 1

## Error Codes and Troubleshooting

### Common Error Codes
```yaml
25806: "Location type cannot be deleted (fulfillment center)"
25122: "Contact URL incorrectly formatted"
25118: "Must provide contact info for Manufacturer"
1002: "Missing access token"
2003: "Invalid category ID"
2004: "Required field missing"
```

### Validation Errors
- Missing required aspects
- Invalid condition for category
- Price format issues (must be string with 2 decimals)
- Invalid image URLs
- Missing business policies

## Testing Checklist

### Before Publishing
- [ ] OAuth token is valid and not expired
- [ ] At least one inventory location exists
- [ ] All required fields populated
- [ ] At least one image provided
- [ ] Business policies created and IDs available
- [ ] Category ID is correct (914 for postcards)
- [ ] Price is formatted correctly (e.g., "9.99")

### After Publishing
- [ ] Listing ID returned in response
- [ ] Listing visible at https://sandbox.ebay.com/itm/{listingId}
- [ ] Database record created with listing details
- [ ] Success notification shown to user

## Important Notes

1. **Listings created via API cannot be edited through eBay web interface** - all changes must be made through API

2. **Sandbox test users are public** - don't store sensitive information

3. **Category 914 (Postcards) qualifies for eBay Standard Envelope** shipping ($0.53 vs $4+ for regular mail)

4. **AI-extracted data mapping**:
   - Map AI condition strings to eBay condition codes
   - Extract era/theme from description if possible
   - Default to "Unknown" for missing aspects

5. **Image requirements**:
   - JPEG, PNG, GIF formats accepted
   - Minimum 500x500 pixels recommended
   - Maximum 12MB per image
   - First image becomes primary listing photo
