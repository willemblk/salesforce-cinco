# Dynamische Prijslijst Implementation - Salesforce Backend

## 🎯 Implementatie Overzicht

De statische prijzen in WordPress cinco-pricing.js worden nu vervangen door een dynamische prijslijst die direct uit Salesforce wordt geladen. Dit zorgt voor real-time prijssynchronisatie en centraal prijsbeheer.

## ✅ Wat Er Is Geïmplementeerd

### 1. Enhanced ResponseProduct Class
```apex
global class ResponseProduct {
    // ... bestaande properties ...
    @AuraEnabled public Decimal basePrice { get; set; }           // Dynamische basisprijs
    @AuraEnabled public Map<String, Decimal> extraPrices { get; set; }  // Prijzen voor extras
}
```

### 2. Dynamic Price Loading Logic
```apex
// Verzamel alle Product ID's
Set<Id> productIds = new Set<Id>();
for(Product2 p : allProducts) {
    productIds.add(p.Id);
}

// Haal actieve prijsregels op
Map<Id, Prijsmanagement__c> priceMap = new Map<Id, Prijsmanagement__c>();
for(Prijsmanagement__c priceRule : [
    SELECT Product__c, Eenheidsprijs__c 
    FROM Prijsmanagement__c 
    WHERE Product__c IN :productIds 
      AND Actief__c = true 
      AND Geldig_vanaf__c <= TODAY 
      AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
]) {
    priceMap.put(priceRule.Product__c, priceRule);
}
```

### 3. Price Assignment to Products
```apex
// Primary products krijgen basePrice
if (priceMap.containsKey(primaryId)) {
    rp.basePrice = priceMap.get(primaryId).Eenheidsprijs__c;
} else {
    rp.basePrice = 0; // Fallback
}

// Extra products krijgen basePrice + worden toegevoegd aan parent's extraPrices
if (priceMap.containsKey(extra.Id)) {
    extraProd.basePrice = priceMap.get(extra.Id).Eenheidsprijs__c;
    parentPrimary.extraPrices.put(extra.ProductCode, extraProd.basePrice);
}
```

## 🔄 Data Flow: Van Salesforce naar WordPress

### 1. WordPress Request (Poortwachter)
```javascript
// WordPress vraagt product catalog op
fetch('/wp-json/cinco/v1/calculate-price', {
    body: JSON.stringify({
        postcode: '1012AB',
        segment: 'Wasserij',
        siteId: 'CincoCleaning'
        // Geen products = catalog request
    })
})
```

### 2. Salesforce Processing
```apex
// Salesforce laadt producten + prijzen
1. Vind products voor segment + website
2. Laad actieve Prijsmanagement__c records
3. Koppel prijzen aan producten
4. Bouw response met dynamic pricing
```

### 3. Enhanced JSON Response
```json
{
    "success": true,
    "availableProducts": [
        {
            "productCode": "WAS-PRIM-VLOERKLEED-REINIGEN",
            "productNaam": "Vloerkleed",
            "isPrimary": true,
            "basePrice": 29.50,  // ← DYNAMIC FROM SALESFORCE
            "extraPrices": {     // ← DYNAMIC EXTRA PRICES
                "WAS-EX-VLEKKENBEHANDELING": 4.50,
                "WAS-EX-SPOEDSERVICE": 50.00
            }
        },
        {
            "productCode": "WAS-EX-VLEKKENBEHANDELING", 
            "productNaam": "Vlekkenbehandeling",
            "isPrimary": false,
            "basePrice": 4.50,   // ← DYNAMIC FROM SALESFORCE
            "relatedProductCode": "WAS-PRIM-VLOERKLEED-REINIGEN"
        }
    ]
}
```

### 4. WordPress Integration (Future)
```javascript
// WordPress cinco-pricing.js kan nu dynamic prices gebruiken
const catalogData = await loadCatalogFromSalesforce();

// Replace static prices with dynamic ones
const vloerkleed = {
    key: 'vloerkleed',
    label: 'Vloerkleed',
    base_per_m2: catalogData.getBasePrice('WAS-PRIM-VLOERKLEED-REINIGEN'), // Dynamic!
    extras: [
        {
            key: 'vlekkenbehandeling',
            price_per_m2: catalogData.getExtraPrice('WAS-EX-VLEKKENBEHANDELING') // Dynamic!
        }
    ]
};
```

## 📋 Enhanced Debug Logging

De implementatie bevat uitgebreide debug logging:

```apex
// Price loading
💰 Loading dynamic prices for 12 products...
💰 Price found for product 01t...: €29.50
💰 Loaded 8 active price rules

// Primary product pricing
💰 Primary WAS-PRIM-VLOERKLEED-REINIGEN base price: €29.50
⚠️ Primary WAS-PRIM-KUSSEN-REINIGEN no price found - using €0 fallback

// Extra product pricing
💰 Extra WAS-EX-VLEKKENBEHANDELING base price: €4.50
✅ Extra linked: WAS-EX-VLEKKENBEHANDELING → Primary: WAS-PRIM-VLOERKLEED-REINIGEN (€4.50)
```

## 📊 Expected Benefits

### Voor Implementation (Static Prices):
```javascript
// cinco-pricing.js (hardcoded)
const vloerkleed = {
    base_per_m2: 29.50,  // Manual update required
    extras: [
        { price_per_m2: 4.50 }  // Manual update required
    ]
};
```

### Na Implementation (Dynamic Prices):
```javascript
// cinco-pricing.js (dynamic)
const vloerkleed = {
    base_per_m2: salesforceData.basePrice,     // Auto-updated!
    extras: [
        { price_per_m2: salesforceData.extraPrices['WAS-EX-VLEKKENBEHANDELING'] }  // Auto-updated!
    ]
};
```

### Business Benefits:
✅ **Real-time Pricing**: Wijzigingen in Salesforce direct zichtbaar op website  
✅ **Single Source of Truth**: Alle prijzen beheerd via Prijsmanagement__c  
✅ **No Manual Updates**: Geen code changes nodig voor prijswijzigingen  
✅ **Centralized Control**: Marketing team kan prijzen direct aanpassen  
✅ **Consistency**: Zelfde prijzen in Salesforce en WordPress  

## 🧪 Testing

### Test Script: `DYNAMIC_PRICING_TEST.apex`
- Test enhanced ResponseProduct structure
- Check Prijsmanagement__c records
- Simulate price lookup logic
- Verify price assignment to products

### Manual Test Flow:
1. Deploy updated PriceCalculationApi.cls
2. Create/verify Prijsmanagement__c records for test products
3. Test product catalog API via WordPress poortwachter
4. Verify JSON response contains basePrice and extraPrices
5. Update WordPress cinco-pricing.js to use dynamic data

## 🔧 Configuration Requirements

### Prijsmanagement__c Records Setup:
```
Product__c: WAS-PRIM-VLOERKLEED-REINIGEN
Eenheidsprijs__c: 29.50
Actief__c: true
Geldig_vanaf__c: 2024-01-01
Geldig_tot__c: null (or future date)
```

### SOQL Query Requirements:
- `Prijsmanagement__c` object must exist
- Required fields: `Product__c`, `Eenheidsprijs__c`, `Actief__c`, `Geldig_vanaf__c`, `Geldig_tot__c`
- Proper date range handling for price validity

## 🚀 Deployment Steps

1. **Deploy Salesforce Changes:**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/classes/PriceCalculationApi.cls
   ```

2. **Run Test Script:**
   ```bash
   sfdx force:apex:execute -f DYNAMIC_PRICING_TEST.apex
   ```

3. **Setup Price Data:**
   - Create Prijsmanagement__c records for all products
   - Verify Actief__c = true and valid date ranges

4. **Test Integration:**
   - Test catalog API via WordPress poortwachter
   - Verify enhanced JSON response structure

5. **WordPress Integration (Phase 2):**
   - Update cinco-pricing.js to consume dynamic pricing
   - Replace static prices with Salesforce data

## ✅ Success Criteria

- [ ] ResponseProduct contains basePrice and extraPrices properties
- [ ] Price lookup query retrieves Prijsmanagement__c records correctly
- [ ] Primary products receive dynamic basePrice values
- [ ] Extra products receive dynamic pricing + parent extraPrices mapping
- [ ] WordPress receives enhanced JSON with pricing data
- [ ] Debug logs show successful price loading and assignment

## 🎯 Future WordPress Integration

WordPress kan nu de statische prijzen vervangen:

```javascript
// Old way (static)
const prices = { vloerkleed: 29.50, vlekkenbehandeling: 4.50 };

// New way (dynamic from Salesforce)
const prices = await loadDynamicPricesFromSalesforce();
```

Dit maakt de implementatie van dynamische prijslijst compleet! 🎉