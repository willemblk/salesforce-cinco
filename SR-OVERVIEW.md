# SR Implementation - Cross-Workspace Overview

**Last Updated**: October 7, 2025  
**Status**: ✅ Production Ready

---

## Quick Navigation

### Documentation by Workspace

| Workspace | Document | Focus |
|-----------|----------|-------|
| 🎨 **WordPress** | [SR-IMPLEMENTATION-GUIDE.md](../../Local%20Sites/cinco-dev/app/public/wp-content/plugins/cinco-offerte-systeem/SR-IMPLEMENTATION-GUIDE.md) | Frontend, UI, Integration, Pricing Engine |
| ⚙️ **Salesforce** | [SR-SALESFORCE-CONFIGURATION.md](SR-SALESFORCE-CONFIGURATION.md) | Data Model, Products, Prices, API |

### Quick Links

- 🎯 **Full Implementation Guide**: [WordPress SR-IMPLEMENTATION-GUIDE.md](../../Local%20Sites/cinco-dev/app/public/wp-content/plugins/cinco-offerte-systeem/SR-IMPLEMENTATION-GUIDE.md)
- 🔧 **Salesforce Configuration**: [SR-SALESFORCE-CONFIGURATION.md](SR-SALESFORCE-CONFIGURATION.md)
- 📚 **Main Project README**: [WordPress README.md](../../Local%20Sites/cinco-dev/app/public/wp-content/plugins/cinco-offerte-systeem/README.md)
- 🏗️ **Salesforce Architecture**: [Salesforce README.md](README.md)

---

## Architecture Overview

### The Big Picture

```
┌─────────────────────────────────────────────────────────────┐
│                    SALESFORCE (Source of Truth)              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Product2: SR-PRIM-MEUBEL-*, SR-PRIM-TAPIJT-*       │  │
│  │  Prijsmanagement__c: €50/seat, €5/m², €7.50/trede   │  │
│  │  PriceCalculationApi.cls: REST API endpoint          │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────┘
                            │ HTTPS/REST
                            │ OAuth2
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    WORDPRESS (Integration)                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  api-routes.php: Proxy to Salesforce                 │  │
│  │  salesforce-api.php: OAuth2 + Lead creation          │  │
│  │  Transient cache: 5 minutes                          │  │
│  └──────────────────────────────────────────────────────┘  │
└───────────────────────────┬─────────────────────────────────┘
                            │ JavaScript
                            │ SessionStorage
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    FRONTEND (User Interface)                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  cinco-product-config-component.js: Web Component    │  │
│  │  cinco-pricing.js: Pricing calculation               │  │
│  │  Modern UI: Cards, counters, animations              │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## SR Products Summary

### SR Meubel (Furniture Cleaning On-Site)

| Product Code | Name | Price | Unit |
|--------------|------|-------|------|
| `SR-PRIM-MEUBEL-BANKMK` | Bank (met losse kussens) | €50.00 | /zitplaats |
| `SR-PRIM-MEUBEL-BANKZK` | Bank (zonder losse kussens) | €45.00 | /zitplaats |
| `SR-PRIM-MEUBEL-FAUTEUIL` | Fauteuil | €27.50 | /zitplaats |
| `SR-PRIM-MEUBEL-HOEKBANK` | Hoekbank | €50.00 | /zitplaats |
| `SR-PRIM-MEUBEL-EETKAMERSTOEL` | Eetkamerstoel | €22.50 | /zitplaats |
| `SR-PRIM-MEUBEL-BUREAUSTOEL` | Bureaustoel | €22.50 | /zitplaats |

**Key Field**: `Lead_Product__c.Aantal__c` = Number of seats

### SR Tapijt (Carpet Cleaning On-Site)

| Product Code | Name | Price | Unit |
|--------------|------|-------|------|
| `SR-PRIM-TAPIJT-PLAT` | Vast tapijt | €5.00 | /m² |
| `SR-PRIM-TAPIJT-TRAP` | Tapijt trap | €7.50 | /trede |

**Key Fields**:
- **Vast tapijt**: `Lead_Product__c.Aantal__c` = Area in m²
- **Tapijt trap**: `Lead_Product__c.Aantal__c` = Number of treden

---

## Data Flow Summary

### Step 1: Postcode Check → Load Catalog

```
User enters postcode (1012AB) + segment (SR)
    ↓
WordPress: POST /wp-json/cinco/v1/calculate-price
    ↓
Salesforce: POST /services/apexrest/v1/calculatePrice
    ↓
Query Product2 WHERE Segment__c = 'SR' AND IsActive = true
Query Prijsmanagement__c WHERE Actief__c = true AND Geldig_vanaf__c <= TODAY
    ↓
Response: { availableProducts: [...], regioToeslagPercentage: 50 }
    ↓
Frontend: Store in SessionStorage (window.CINCO.catalogState)
```

### Step 2: Product Configuration → Calculate Prices

```
User configures product (SR Tapijt PLAT, 10 m²)
    ↓
cinco-pricing.js: sr_tapijt.priceItem(item, regioToeslag)
    ↓
1. Try window.CINCO.staffelPricing['SR-PRIM-TAPIJT-PLAT'] (no staffel)
2. Try window.CINCO.catalogState.primaryProducts.find(...).basePrice (€5)
3. Fallback: hardcoded €18.50 (should never happen)
    ↓
Calculate: 10 m² × €5 = €50
Apply regiotoeslag: €50 × 1.5 = €75
Apply BTW: €75 × 1.21 = €90.75
    ↓
Display: €90.75 (incl. BTW + 50% regio)
```

### Step 3: Form Submit → Create Lead

```
User submits form with:
  - service: 'sr_tapijt'
  - sku: 'SR-PRIM-TAPIJT-PLAT'
  - carpetType: 'SR-PRIM-TAPIJT-PLAT'
  - dims: { area_m2: 10 }
    ↓
WordPress: POST /wp-json/cinco/v1/lead
    ↓
buildLeadProductData():
  if (carpetType === 'SR-PRIM-TAPIJT-PLAT') {
      Aantal__c = floatval(dims['area_m2']) = 10
  } elseif (carpetType === 'SR-PRIM-TAPIJT-TRAP') {
      Aantal__c = intval(treden) = 15
  }
    ↓
Salesforce: POST /services/data/v59.0/sobjects/Lead_Product__c/
  {
    Lead__c: '00QXXXXXXXXXXX',
    Product__c: '01tXXXXXXXXXXX',
    Aantal__c: 10,
    Verkoopprijs__c: 7.50,
    Totale_Prijs__c: 75.00,
    SKU__c: 'SR-PRIM-TAPIJT-PLAT'
  }
```

---

## Critical Implementation Details

### Pricing Cascade (WordPress: cinco-pricing.js)

**For ALL SR products, the pricing engine follows this priority**:

```javascript
// 1. SALESFORCE STAFFEL PRICING (highest priority)
let price = window.CINCO.staffelPricing[productCode]?.find(tier => 
    quantity >= tier.ondergrens && quantity <= tier.bovengrens
)?.eenheidsprijs;

// 2. SALESFORCE BASE PRICE (middle priority)
if (!price) {
    price = window.CINCO.catalogState.primaryProducts.find(p => 
        p.productCode === productCode
    )?.basePrice;
}

// 3. HARDCODED FALLBACK (lowest priority - should never happen)
if (!price) {
    price = defaultFallbackPrice;  // e.g., €75 for meubel, €18.50/€8.50 for tapijt
    console.warn('⚠️ Using fallback price!');
}
```

**Production Expectation**: Steps 1 or 2 ALWAYS succeed. Step 3 should NEVER execute.

### Aantal__c Mapping (WordPress: class-cinco-lead-endpoint.php)

**Critical**: `Lead_Product__c.Aantal__c` must represent the correct unit:

```php
if ($service === 'sr_meubel') {
    // SR Meubel: Aantal__c = number of seats
    $productData['Aantal__c'] = intval($item['qty']);
    
} elseif ($service === 'sr_tapijt') {
    $carpetType = $item['meta']['carpetType'] ?? $item['carpetType'];
    
    if ($carpetType === 'SR-PRIM-TAPIJT-PLAT') {
        // Vast tapijt: Aantal__c = area in m²
        $productData['Aantal__c'] = floatval($item['dims']['area_m2']);
        
    } elseif ($carpetType === 'SR-PRIM-TAPIJT-TRAP') {
        // Tapijt trap: Aantal__c = number of treden
        $productData['Aantal__c'] = intval($item['treden']);
    }
}
```

---

## UI Features (WordPress: cinco-product-config-component.js)

### Modern SR Tapijt Interface

**1. Side-by-Side Carpet Type Cards**
```html
<div class="carpet-type-grid">
    <button class="carpet-type-card active">
        <!-- Vast tapijt card with gradient, icon, checkmark -->
    </button>
    <button class="carpet-type-card">
        <!-- Tapijt trap card -->
    </button>
</div>
```

**2. Modern Counter with +/- Buttons**
```html
<div class="modern-counter-wrapper">
    <button class="counter-btn counter-minus">-</button>
    <input type="number" class="counter-input" step="0.5" value="10">
    <span class="counter-unit">m²</span>
    <button class="counter-btn counter-plus">+</button>
</div>
```

**3. Key Features**
- ✅ Gradient background on active card
- ✅ Green checkmark icon with fade-in animation
- ✅ Hover effects persist on active cards
- ✅ Large, easy-to-use counter buttons
- ✅ Comma decimal support (12,5 → 12.5)
- ✅ Smooth cubic-bezier transitions (0.3s)
- ✅ Responsive design (stacks on mobile)

---

## Testing Workflows

### Salesforce Testing

```powershell
# Navigate to Salesforce project
cd "c:\Users\wblok\Projecten\SalesforceProjecten\salesforce-pricing-engine\salesforce-pricing-engine"

# Check products
sf apex run --file scripts/apex/check_sr_products.apex

# Check pricing
sf apex run --file scripts/apex/check_sr_pricing.apex

# Test API
sf apex run --file scripts/apex/test_sr_api.apex
```

### WordPress Testing

```powershell
# Navigate to WordPress plugin
cd "c:\Users\wblok\Local Sites\cinco-dev\app\public\wp-content\plugins\cinco-offerte-systeem"

# Check debug logs
Get-Content "../../../wp-content/debug.log" -Tail 50 | Select-String "Cinco SF"

# Open test page
Start-Process "http://cinco-dev.local/configuratie/?segment=SR&postcode=1012AB&rt=50&afhandeling=Order"
```

### Frontend Testing (Browser Console)

```javascript
// Check catalog loaded
console.log('Catalog:', window.CINCO.catalogState);

// Check SR Tapijt products
const tapijt = window.CINCO.catalogState.primaryProducts.filter(p => 
    p.productCode.includes('TAPIJT')
);
console.log('SR Tapijt products:', tapijt);

// Check prices
tapijt.forEach(p => {
    console.log(`${p.productCode}: €${p.basePrice}`);
});

// Expected output:
// SR-PRIM-TAPIJT-PLAT: €5
// SR-PRIM-TAPIJT-TRAP: €7.5
```

---

## Troubleshooting Quick Reference

### Issue: Prices showing €0

**Diagnosis**:
1. ❌ Catalog not loaded → Check SessionStorage: `window.CINCO.catalogState`
2. ❌ No active price in SF → Run `scripts/apex/check_sr_pricing.apex`
3. ❌ Product inactive → Check `Product2.IsActive = true`

**Fix**: Navigate to `/postcode-check/` and restart flow

### Issue: "Using fallback price" in console

**Diagnosis**:
- ⚠️ SF pricing data not found

**Fix**:
1. Verify `Prijsmanagement__c` exists and is active
2. Clear WordPress cache: `wp transient delete cinco_price_calc_*`
3. Refresh page

### Issue: Wrong Aantal__c in Lead_Product__c

**Diagnosis**:
- ❌ SKU mismatch or missing `carpetType`

**Check**:
```javascript
console.log('Item structure:', {
    service: item.service,
    sku: item.sku,
    carpetType: item.carpetType,
    dims: item.dims,
    treden: item.treden
});
```

**Fix**: Ensure `carpetType` is set correctly in `cinco-product-config-component.js`

---

## Deployment Checklist

### Pre-Deployment

**Salesforce**:
- [ ] All Product2 records created and active
- [ ] All Prijsmanagement__c records created with correct prices
- [ ] PriceCalculationApi.cls deployed and tested
- [ ] Test scripts executed successfully

**WordPress**:
- [ ] OAuth2 credentials configured in wp-config.php
- [ ] All component files updated
- [ ] Test on staging environment

**Frontend**:
- [ ] SessionStorage working across navigation
- [ ] Prices display correctly
- [ ] Counter buttons functional
- [ ] Mobile responsive

### Post-Deployment

- [ ] Monitor WordPress debug.log for errors
- [ ] Monitor Salesforce debug logs
- [ ] Check API usage metrics
- [ ] Verify Lead_Product__c records created correctly
- [ ] Test end-to-end flow: Postcode → Config → Submit → SF

---

## Key Files Reference

### Salesforce

| File | Purpose |
|------|---------|
| `PriceCalculationApi.cls` | REST API for WordPress |
| `TriggerRecursionGuard.cls` | Prevent infinite loops |
| `scripts/apex/check_sr_products.apex` | Validate product configuration |
| `scripts/apex/check_sr_pricing.apex` | Validate pricing configuration |
| `SR-SALESFORCE-CONFIGURATION.md` | Full SF documentation |

### WordPress

| File | Purpose |
|------|---------|
| `cinco-product-config-component.js` | Main UI component (5643 lines) |
| `cinco-pricing.js` | Pricing calculation engine (658 lines) |
| `class-cinco-lead-endpoint.php` | Lead creation REST API |
| `salesforce-api.php` | OAuth2 + SF integration |
| `api-routes.php` | REST API proxy to SF |
| `SR-IMPLEMENTATION-GUIDE.md` | Full implementation guide |

---

## Maintenance Schedule

### Daily
- Monitor error logs (WordPress + Salesforce)

### Weekly
- Check API usage metrics
- Review Lead_Product__c records for anomalies

### Monthly
- Review pricing accuracy
- Check for orphaned products (active but no price)

### Quarterly
- Full end-to-end testing
- Price audit

### Yearly
- Year-over-year price comparison
- Documentation review and update

---

## Support Contacts

**For Salesforce Issues**:
- Check: [SR-SALESFORCE-CONFIGURATION.md](SR-SALESFORCE-CONFIGURATION.md)
- Debug: `scripts/apex/check_sr_pricing.apex`

**For WordPress Issues**:
- Check: [SR-IMPLEMENTATION-GUIDE.md](../../Local%20Sites/cinco-dev/app/public/wp-content/plugins/cinco-offerte-systeem/SR-IMPLEMENTATION-GUIDE.md)
- Debug: `wp-content/debug.log`

**For Frontend Issues**:
- Check: Browser console (`F12`)
- Debug: `window.CINCO.catalogState`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-10-07 | Initial documentation - SR Meubel + SR Tapijt complete |

---

**Next Steps**: Refer to the detailed implementation guides for your specific task:
- 🎨 Frontend work → [SR-IMPLEMENTATION-GUIDE.md](../../Local%20Sites/cinco-dev/app/public/wp-content/plugins/cinco-offerte-systeem/SR-IMPLEMENTATION-GUIDE.md)
- ⚙️ Salesforce config → [SR-SALESFORCE-CONFIGURATION.md](SR-SALESFORCE-CONFIGURATION.md)

*This overview is maintained as part of the Cinco Offerte Systeem multi-workspace project.*
