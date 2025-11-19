# SR Extras Percentage Pricing - Implementation Summary

## Overview
✅ **Implementation Complete** - Percentage-based pricing voor SR extras geïmplementeerd in WordPress en Salesforce.

**Feature**: SR extras (Vezelbeschermer, Ontgeuren) worden geprijsd als percentage van base product prijs in plaats van vaste bedragen.

**Voordelen**:
- 🎯 Schaalt automatisch met meubeltype prijzen
- 🎯 Schaalt automatisch met staffel pricing
- 🎯 Schaalt automatisch met regiotoeslag
- 🎯 Eén extra product per type (niet per meubelvariant)
- 🎯 Centraal beheer in Salesforce

## Implementatie Overzicht

### WordPress Plugin
**Files Modified**: 2 JavaScript files

1. **cinco-pricing.js** (799 lines)
   - **Lines 196-199**: SR Meubel extras array
     - Changed from `price: 15` to `percentageOfBase: 10`
   - **Lines 315-340**: SR Meubel `priceItem()` calculation
     - NEW: `extraPrice = basePriceTotal * (percentageOfBase / 100)`
   - **Lines 405-409**: SR Tapijt extras array
     - Removed vlekbehandeling, changed to percentage-based
   - **Lines 485-508**: SR Tapijt `itemRawSubtotal()` calculation
     - NEW: Percentage logic for both PLAT and TRAP

2. **cinco-product-config-component.js** (5665 lines)
   - **Lines 504-568**: `updateExtraPrices()` supports `pricingType='percentage'`
   - **Lines 618-653**: `mapExtraCodeToKey()` mappings for SR-EXTRA-*
   - **Lines 2690-2720**: `getExtraPriceText()` shows "+10%" format

### Salesforce Apex
**Files Modified**: 1 class

1. **PriceCalculationApi.cls** (898 lines)
   - **Lines 69-78**: `ResponseProduct` class
     - NEW fields: `percentageOfBase`, `pricingType`
   - **Lines 389-402**: Prijsmanagement__c query
     - Added `Relatieve_prijs__c` field to SELECT
   - **Lines 507-539**: Extra pricing logic
     - Check if `Relatieve_prijs__c != null` → percentage pricing
     - Else use `Eenheidsprijs__c` → absolute pricing

**Deploy Status**: ✅ Deployed successfully (Deploy ID: 0Af9X000012nnVnSAI)

## Product Configuratie

### SR Meubel Extras
| Product Code | Label | Percentage | Notes |
|--------------|-------|-----------|-------|
| SR-EXTRA-MEUBEL-VEZEL | Vezelbeschermer | 10% | Beschermt tegen vlekken |
| SR-EXTRA-MEUBEL-GEUR | Ontgeuren overig | 10% | Geen urine |
| SR-EXTRA-MEUBEL-URINE | Ontgeuren urine | 15% | Urine behandeling |

### SR Tapijt Extras
| Product Code | Label | Percentage | Notes |
|--------------|-------|-----------|-------|
| SR-EXTRA-TAPIJT-VEZEL | Vezelbeschermer | 10% | Voor vast tapijt |
| SR-EXTRA-TAPIJT-GEUR | Ontgeuren overig | 10% | Geen urine |
| SR-EXTRA-TAPIJT-URINE | Ontgeuren urine | 15% | Urine behandeling |

## Pricing Examples

### SR Meubel: Bank met losse kussens
```
Base price: 3 seats @ €50/seat = €150.00

Extras selected:
- Vezelbeschermer (10%) = €150 × 0.10 = €15.00
- Ontgeuren urine (15%) = €150 × 0.15 = €22.50

Subtotal: €150.00
Extras: +€37.50
Regiotoeslag (50%): +€93.75
Total (excl BTW): €281.25
Total (incl 21% BTW): €340.31
```

### SR Tapijt: Vast tapijt
```
Base price: 10 m² @ €5/m² = €50.00

Extras selected:
- Vezelbeschermer (10%) = €50 × 0.10 = €5.00
- Ontgeuren overig (10%) = €50 × 0.10 = €5.00

Subtotal: €50.00
Extras: +€10.00
Regiotoeslag (50%): +€30.00
Total (excl BTW): €90.00
Total (incl 21% BTW): €108.90
```

## Data Flow

### 1. Catalog Loading (Step 1: Postcode Check)
```
WordPress → /wp-json/cinco/v1/calculate-price
  ↓
Salesforce PriceCalculationApi.cls
  ↓
Query Prijsmanagement__c (includes Relatieve_prijs__c)
  ↓
Return ResponseProduct with:
  - percentageOfBase: 10
  - pricingType: 'percentage'
  - basePrice: null
  ↓
WordPress caches in SessionStorage
```

### 2. Price Calculation (Step 2: Product Config)
```
User selects SR Meubel + extras
  ↓
cinco-pricing.js: calculatePricesForSRMeubel()
  ↓
basePriceTotal = prijsPerSeat × seats
  ↓
For each extra:
  if (e.percentageOfBase) {
      extraPrice = basePriceTotal × (e.percentageOfBase / 100)
  }
  ↓
Apply regiotoeslag to (basePriceTotal + extraPrices)
  ↓
Display in UI
```

### 3. Lead Creation (Step 3: Submit)
```
WordPress → /wp-json/cinco/v1/lead
  ↓
Create Lead + Lead_Product__c records
  ↓
Salesforce PricingService.cls
  ↓
Recalculate prices using Prijsmanagement__c
  ↓
Store in Lead_Product__c.Verkoopprijs__c
```

## Vereiste Salesforce Configuratie

⚠️ **IMPORTANT**: Data moet nog geconfigureerd worden!

### Stap 1: Run Configuratie Script
```powershell
cd "c:\Users\wblok\Projecten\SalesforceProjecten\salesforce-pricing-engine\salesforce-pricing-engine"
sf apex run --file scripts/apex/configure_sr_extras_percentage.apex
```

**Dit script doet**:
1. Update `Gerelateerd_hoofdproduct__c` voor SR-EXTRA-MEUBEL-* producten
2. Create/Update `Prijsmanagement__c` records met `Relatieve_prijs__c`
3. Set `Eenheidsprijs__c = null` (niet €0!)

### Stap 2: Verify Configuratie
```powershell
sf apex run --file scripts/apex/test_sr_percentage_extras.apex
```

**Verwacht resultaat**:
```
✅ Found 6 products with percentage pricing:
  - SR-EXTRA-MEUBEL-VEZEL: 10%
  - SR-EXTRA-MEUBEL-GEUR: 10%
  - SR-EXTRA-MEUBEL-URINE: 15%
  - SR-EXTRA-TAPIJT-VEZEL: 10%
  - SR-EXTRA-TAPIJT-GEUR: 10%
  - SR-EXTRA-TAPIJT-URINE: 15%

✅ Percentage pricing working correctly!
   - Percentage-based extras: 6
```

## Testing Checklist

### ✅ Code Implementation
- [x] cinco-pricing.js: Percentage calculation for SR Meubel
- [x] cinco-pricing.js: Percentage calculation for SR Tapijt
- [x] cinco-product-config-component.js: updateExtraPrices() supports percentage
- [x] cinco-product-config-component.js: mapExtraCodeToKey() includes SR extras
- [x] cinco-product-config-component.js: getExtraPriceText() shows "+10%"
- [x] PriceCalculationApi.cls: Query Relatieve_prijs__c field
- [x] PriceCalculationApi.cls: ResponseProduct has percentageOfBase/pricingType
- [x] PriceCalculationApi.cls: Extra pricing logic checks percentage vs absolute
- [x] Deploy successful to Salesforce

### ⏸️ Data Configuration
- [ ] Run configure_sr_extras_percentage.apex script
- [ ] Verify 6 extras have Prijsmanagement__c with Relatieve_prijs__c
- [ ] Verify SR-EXTRA-MEUBEL-* have Gerelateerd_hoofdproduct__c
- [ ] Run test_sr_percentage_extras.apex for verification

### ⏸️ Frontend Testing
- [ ] Navigate to /postcode-check/?segment=SR
- [ ] Check catalog loads with percentageOfBase in SessionStorage
- [ ] Select SR Meubel + extras
- [ ] Verify console logs show "10% of €150.00 = €15.00"
- [ ] Verify summary shows correct percentage calculations
- [ ] Submit order and check Lead_Product__c records

## Console Logging

### Expected Logs (WordPress)
```javascript
// Catalog loading
✅ SR-EXTRA-MEUBEL-VEZEL: 10% of base price (percentage)
✅ SR-EXTRA-TAPIJT-GEUR: 10% of base price (percentage)

// Price calculation
💰 SR Meubel extra "Vezelbeschermer": 10% of €150.00 = €15.00
💰 SR Tapijt extra "Ontgeuren overig": 10% of €50.00 = €5.00
```

### Expected Logs (Salesforce)
```apex
// Pricing query
💰 Price found for product 01t...: 10% (percentage-based)

// Extra pricing assignment
💰 Extra SR-EXTRA-MEUBEL-VEZEL percentage pricing: 10% of base product

// API response
✅ Extra linked: SR-EXTRA-MEUBEL-VEZEL → Primary: SR-PRIM-MEUBEL-FAUTEUIL (€null) (ID: 01t...)
```

## Architecture Decisions

### Q: Waarom percentage in plaats van absolute prijzen?
**A**: 
- Schaalt automatisch met verschillende meubeltypes (€27.50 fauteuil vs €50 bank)
- Werkt met staffel pricing (3 zitplaatsen = andere prijs dan 5)
- Werkt met regiotoeslag (Amsterdam 50% vs Rotterdam 25%)
- Eén product per extra type (niet 6 varianten voor 6 meubeltypes)

### Q: Waarom Relatieve_prijs__c in plaats van Eenheidsprijs__c?
**A**:
- Duidelijke scheiding tussen absolute (€10) en relatieve (10%) prijzen
- API kan `pricingType` field gebruiken om onderscheid te maken
- Voorkomt verwarring tussen €0 (gratis) en null (percentage)

### Q: Waarom niet alle extras percentage-based?
**A**:
- Vloerkleed extras zijn vaak vast bedrag (€20 motbescherming)
- SR extras schalen beter met percentage (10% van €150 vs 10% van €50)
- Flexibiliteit per segment (Wasserij vs SR vs Dakkapel)

### Q: Waarom één Gerelateerd_hoofdproduct__c voor alle SR Meubel extras?
**A**:
- Extras zijn niet meubeltype-specifiek (vezelbeschermer werkt voor alles)
- API haalt alle extras op via parent lookup
- Frontend logic bepaalt welke extras beschikbaar zijn
- Eenvoudiger te onderhouden (1 relatie vs 6 relaties)

## Known Issues & Limitations

### ⚠️ Issue 1: Gerelateerd_hoofdproduct__c Required
**Problem**: Extras zonder parent worden niet getoond in catalog  
**Solution**: Run configuratie script om relaties te maken  
**Status**: Configuratie vereist

### ⚠️ Issue 2: Eenheidsprijs__c moet null zijn
**Problem**: Als Eenheidsprijs__c = €0, dan wordt percentage niet gebruikt  
**Solution**: Configuratie script set Eenheidsprijs__c = null (niet €0)  
**Status**: Script handelt dit af

### ✅ Issue 3: Bundle discounts voor SR
**Problem**: Geen bundle discounts metadata voor SR segment  
**Solution**: Nog niet nodig (SR is on-site, geen bundelkorting verwacht)  
**Status**: Toekomstige feature

## Documentation Links

### Implementation Guides
- 📚 [SR-IMPLEMENTATION-GUIDE.md](../../Local%20Sites/cinco-dev/app/public/wp-content/plugins/cinco-offerte-systeem/SR-IMPLEMENTATION-GUIDE.md) - WordPress implementatie
- 🏗️ [SR-SALESFORCE-CONFIGURATION.md](SR-SALESFORCE-CONFIGURATION.md) - Salesforce data model
- 🎯 [SR-OVERVIEW.md](SR-OVERVIEW.md) - Cross-workspace overzicht

### Configuration Guides
- ⚙️ [SR-EXTRAS-PERCENTAGE-CONFIGURATION.md](SR-EXTRAS-PERCENTAGE-CONFIGURATION.md) - Salesforce configuratie stappen
- 📝 [configure_sr_extras_percentage.apex](scripts/apex/configure_sr_extras_percentage.apex) - Configuratie script
- ✅ [test_sr_percentage_extras.apex](scripts/apex/test_sr_percentage_extras.apex) - Test script

## Next Steps

### Immediate (Required)
1. ✅ Run `configure_sr_extras_percentage.apex` in Salesforce
2. ✅ Run `test_sr_percentage_extras.apex` to verify
3. ✅ Test frontend catalog loading
4. ✅ Test price calculations with extras
5. ✅ Test Lead_Product__c creation

### Future Enhancements
1. ⏸️ Add bundle discounts for SR segment (if needed)
2. ⏸️ Add staffel pricing for SR Meubel (volume discounts)
3. ⏸️ Add photo upload for SR orders
4. ⏸️ Add conditional extras based on material type (Stof vs Leer)

---

**Version**: 1.0  
**Implementation Date**: 2025-01-07  
**Status**: ✅ Code Complete | ⚠️ Configuration Required  
**Author**: GitHub Copilot  
**Review**: Ready for testing after configuration
