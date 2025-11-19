# SR Extras Percentage Pricing - Salesforce Configuration

## Overview
Dit document beschrijft de vereiste Salesforce configuratie om percentage-based pricing voor SR extras te activeren.

**Status**: ✅ Code compleet | ⚠️ Data configuratie vereist

## Test Resultaten

### Huidig ❌
```
Found 6 SR extra products
✅ Found 1 product with percentage pricing:
  - SR-EXTRA-MEUBEL-GEUR: 10%
    
⚠️ WARNING: No percentage-based extras found in API response
   Expected at least 3 (SR-EXTRA-MEUBEL-VEZEL, SR-EXTRA-MEUBEL-GEUR, SR-EXTRA-MEUBEL-URINE)

Problems:
1. Only 1 product has Relatieve_prijs__c configured
2. SR-EXTRA-MEUBEL-* products have no Gerelateerd_hoofdproduct__c
```

### Verwacht ✅
```
Found 6 SR extra products
✅ Found 6 products with percentage pricing:
  - SR-EXTRA-MEUBEL-VEZEL: 10%
  - SR-EXTRA-MEUBEL-GEUR: 10%
  - SR-EXTRA-MEUBEL-URINE: 15%
  - SR-EXTRA-TAPIJT-VEZEL: 10%
  - SR-EXTRA-TAPIJT-GEUR: 10%
  - SR-EXTRA-TAPIJT-URINE: 15%
    
✅ Percentage pricing working correctly!
   - Total products: 13
   - Percentage-based extras: 6
```

## Vereiste Configuratie

### 1. Prijsmanagement__c Records Aanmaken

Voor **alle 6 SR extra producten** moet een `Prijsmanagement__c` record bestaan met:

| Product Code | Relatieve_prijs__c | Eenheidsprijs__c | Actief__c | Geldig_vanaf__c |
|--------------|-------------------|------------------|-----------|-----------------|
| SR-EXTRA-MEUBEL-VEZEL | 10 | null | true | TODAY |
| SR-EXTRA-MEUBEL-GEUR | 10 | null | true | TODAY |
| SR-EXTRA-MEUBEL-URINE | 15 | null | true | TODAY |
| SR-EXTRA-TAPIJT-VEZEL | 10 | null | true | TODAY |
| SR-EXTRA-TAPIJT-GEUR | 10 | null | true | TODAY |
| SR-EXTRA-TAPIJT-URINE | 15 | null | true | TODAY |

**Belangrijk**:
- ✅ `Relatieve_prijs__c` = percentage (10 = 10%, 15 = 15%)
- ✅ `Eenheidsprijs__c` = **null** (niet €0, maar leeg/null)
- ✅ `Actief__c` = **true**
- ✅ `Geldig_vanaf__c` = vandaag of eerder
- ✅ `Geldig_tot__c` = leeg (of toekomstige datum)

### 2. Product2 Records Updaten

Voor **SR Meubel extras** moet `Gerelateerd_hoofdproduct__c` ingesteld worden:

| Product Code | Gerelateerd_hoofdproduct__c | Primaryproduct__c |
|--------------|----------------------------|-------------------|
| SR-EXTRA-MEUBEL-VEZEL | **Must point to ANY SR-PRIM-MEUBEL-*** | false |
| SR-EXTRA-MEUBEL-GEUR | **Must point to ANY SR-PRIM-MEUBEL-*** | false |
| SR-EXTRA-MEUBEL-URINE | **Must point to ANY SR-PRIM-MEUBEL-*** | false |

**Waarom ANY SR-PRIM-MEUBEL-*?**
- SR Meubel extras zijn **niet meubeltype-specifiek**
- 1 extra product geldt voor ALLE meubeltypes (bank, fauteuil, etc.)
- Frontend haalt extras op via parent lookup
- Kies een willekeurig primary product als "anchor" (bijv. SR-PRIM-MEUBEL-FAUTEUIL)

**Voor SR Tapijt extras**: Al correct geconfigureerd (wijzen naar SR-PRIM-TAPIJT-PLAT)

### 3. Beschikbare_Websites__c Checken

Alle 6 extras moeten beschikbaar zijn voor de site:

```apex
// Check current configuration
SELECT ProductCode, Beschikbare_Websites__c 
FROM Product2 
WHERE ProductCode LIKE 'SR-EXTRA-%'
```

Verwacht: `Beschikbare_Websites__c` moet `CincoCleaning` bevatten (of leeg zijn voor "alle sites")

## Configuratie Script

Run dit script in Salesforce Developer Console (Execute Anonymous):

```apex
// SR Extras Percentage Pricing Configuration Script

System.debug('=== SR EXTRAS CONFIGURATION SCRIPT ===\n');

// 1. Find all SR extra products
Map<String, Product2> productMap = new Map<String, Product2>();
for (Product2 p : [
    SELECT Id, ProductCode, Name, Gerelateerd_hoofdproduct__c
    FROM Product2
    WHERE ProductCode LIKE 'SR-EXTRA-%'
      AND IsActive = true
]) {
    productMap.put(p.ProductCode, p);
}

System.debug('Found ' + productMap.size() + ' SR extra products\n');

// 2. Find a primary meubel product to use as anchor
Product2 anchorMeubel = [
    SELECT Id, ProductCode FROM Product2 
    WHERE ProductCode = 'SR-PRIM-MEUBEL-FAUTEUIL' 
    LIMIT 1
];

if (anchorMeubel == null) {
    System.debug('❌ ERROR: No SR-PRIM-MEUBEL-FAUTEUIL found!');
    return;
}

System.debug('✅ Using anchor: ' + anchorMeubel.ProductCode + ' (ID: ' + anchorMeubel.Id + ')\n');

// 3. Update Gerelateerd_hoofdproduct__c for SR Meubel extras
List<Product2> toUpdateProducts = new List<Product2>();

if (productMap.containsKey('SR-EXTRA-MEUBEL-VEZEL')) {
    Product2 p = productMap.get('SR-EXTRA-MEUBEL-VEZEL');
    if (p.Gerelateerd_hoofdproduct__c == null) {
        p.Gerelateerd_hoofdproduct__c = anchorMeubel.Id;
        toUpdateProducts.add(p);
        System.debug('Updating SR-EXTRA-MEUBEL-VEZEL → ' + anchorMeubel.ProductCode);
    }
}

if (productMap.containsKey('SR-EXTRA-MEUBEL-GEUR')) {
    Product2 p = productMap.get('SR-EXTRA-MEUBEL-GEUR');
    if (p.Gerelateerd_hoofdproduct__c == null) {
        p.Gerelateerd_hoofdproduct__c = anchorMeubel.Id;
        toUpdateProducts.add(p);
        System.debug('Updating SR-EXTRA-MEUBEL-GEUR → ' + anchorMeubel.ProductCode);
    }
}

if (productMap.containsKey('SR-EXTRA-MEUBEL-URINE')) {
    Product2 p = productMap.get('SR-EXTRA-MEUBEL-URINE');
    if (p.Gerelateerd_hoofdproduct__c == null) {
        p.Gerelateerd_hoofdproduct__c = anchorMeubel.Id;
        toUpdateProducts.add(p);
        System.debug('Updating SR-EXTRA-MEUBEL-URINE → ' + anchorMeubel.ProductCode);
    }
}

if (!toUpdateProducts.isEmpty()) {
    update toUpdateProducts;
    System.debug('\n✅ Updated ' + toUpdateProducts.size() + ' products with parent relationship\n');
} else {
    System.debug('\n⚠️ No products needed updating for parent relationship\n');
}

// 4. Create/Update Prijsmanagement__c records
Map<String, Decimal> percentages = new Map<String, Decimal>{
    'SR-EXTRA-MEUBEL-VEZEL' => 10,
    'SR-EXTRA-MEUBEL-GEUR' => 10,
    'SR-EXTRA-MEUBEL-URINE' => 15,
    'SR-EXTRA-TAPIJT-VEZEL' => 10,
    'SR-EXTRA-TAPIJT-GEUR' => 10,
    'SR-EXTRA-TAPIJT-URINE' => 15
};

// Check existing pricing
Map<Id, Prijsmanagement__c> existingPricing = new Map<Id, Prijsmanagement__c>();
for (Prijsmanagement__c pm : [
    SELECT Id, Product__c, Relatieve_prijs__c, Eenheidsprijs__c, Actief__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode IN :percentages.keySet()
      AND Actief__c = true
]) {
    existingPricing.put(pm.Product__c, pm);
}

List<Prijsmanagement__c> toUpsertPricing = new List<Prijsmanagement__c>();

for (String productCode : percentages.keySet()) {
    if (!productMap.containsKey(productCode)) {
        System.debug('⚠️ Product not found: ' + productCode);
        continue;
    }
    
    Product2 product = productMap.get(productCode);
    Decimal percentage = percentages.get(productCode);
    
    if (existingPricing.containsKey(product.Id)) {
        // Update existing
        Prijsmanagement__c pm = existingPricing.get(product.Id);
        if (pm.Relatieve_prijs__c != percentage || pm.Eenheidsprijs__c != null) {
            pm.Relatieve_prijs__c = percentage;
            pm.Eenheidsprijs__c = null; // IMPORTANT: Set to null, not 0
            toUpsertPricing.add(pm);
            System.debug('Updating pricing for ' + productCode + ': ' + percentage + '%');
        } else {
            System.debug('✅ Pricing already correct for ' + productCode + ': ' + percentage + '%');
        }
    } else {
        // Create new
        Prijsmanagement__c pm = new Prijsmanagement__c();
        pm.Product__c = product.Id;
        pm.Relatieve_prijs__c = percentage;
        pm.Eenheidsprijs__c = null; // IMPORTANT: null, not 0
        pm.Actief__c = true;
        pm.Geldig_vanaf__c = Date.today();
        // Geldig_tot__c blijft null (oneindig geldig)
        toUpsertPricing.add(pm);
        System.debug('Creating new pricing for ' + productCode + ': ' + percentage + '%');
    }
}

if (!toUpsertPricing.isEmpty()) {
    upsert toUpsertPricing;
    System.debug('\n✅ Upserted ' + toUpsertPricing.size() + ' pricing records');
} else {
    System.debug('\n⚠️ No pricing records needed updating');
}

System.debug('\n=== CONFIGURATION COMPLETE ===');
System.debug('Run test script to verify: sf apex run --file scripts/apex/test_sr_percentage_extras.apex');
```

## Verificatie Stappen

### Stap 1: Run Configuratie Script
```powershell
cd "c:\Users\wblok\Projecten\SalesforceProjecten\salesforce-pricing-engine\salesforce-pricing-engine"
sf apex run --file scripts/apex/configure_sr_extras_percentage.apex
```

### Stap 2: Run Test Script
```powershell
sf apex run --file scripts/apex/test_sr_percentage_extras.apex
```

### Verwacht Resultaat
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

### Stap 3: Test WordPress Frontend
1. Navigate to `/postcode-check/?segment=SR`
2. Open browser console
3. Check for percentage pricing logs:
   ```
   💰 SR Meubel extra "Vezelbeschermer": 10% of €165.00 = €16.50
   💰 Extra SR-EXTRA-MEUBEL-VEZEL percentage pricing: 10% of base product
   ```

## Prijslogica

### Frontend Berekening (cinco-pricing.js)
```javascript
// SR Meubel: Percentage of total base price
let basePriceTotal = prijsPerSeat * seats; // e.g., €55 * 3 = €165

for (const ex of (it.extras || [])) {
    const e = this.extras.find(x => x.key === ex);
    if (e.percentageOfBase && e.percentageOfBase > 0) {
        const extraPrice = basePriceTotal * (e.percentageOfBase / 100);
        sub += extraPrice;
        // Example: €165 * (10 / 100) = €16.50
    }
}
```

### SR Tapijt: Percentage of carpet area/treden price
```javascript
// For PLAT (vast tapijt)
let basePrice = prijsPerM2 * m2; // e.g., €5 * 10m² = €50

// For TRAP (tapijt trap)  
let basePrice = prijsPerTrede * treden; // e.g., €7.50 * 12 = €90

// Then apply percentage extras
if (e.percentageOfBase) {
    extraPrice = basePrice * (e.percentageOfBase / 100);
}
```

## Troubleshooting

### ❌ Problem: "No percentage-based extras found in API response"
**Oorzaak**: Prijsmanagement__c records missen of hebben geen Relatieve_prijs__c
**Oplossing**: Run configuratie script (zie boven)

### ❌ Problem: "Extra has no Gerelateerd_hoofdproduct__c"
**Oorzaak**: SR Meubel extras niet gekoppeld aan primary product
**Oplossing**: Run configuratie script dat Gerelateerd_hoofdproduct__c update

### ❌ Problem: Extras show €0.00 instead of percentage
**Oorzaak**: Eenheidsprijs__c is €0 in plaats van null
**Oplossing**: Update Prijsmanagement__c records met Eenheidsprijs__c = **null**

### ❌ Problem: Frontend shows "€16.50" instead of "+10%"
**Verwacht gedrag**: UI toont percentage, berekening gebeurt dynamisch
**Check**: `getExtraPriceText()` in cinco-product-config-component.js moet `+${extra.percentageOfBase}%` returnen

## Code Changes Samenvatting

### ✅ Compleet

#### WordPress Plugin
1. **cinco-pricing.js**: Percentage calculation in `priceItem()` methods
   - Lines 315-340: SR Meubel extras
   - Lines 485-508: SR Tapijt extras
   - Arrays updated with `percentageOfBase` field

2. **cinco-product-config-component.js**: 
   - Lines 504-568: `updateExtraPrices()` supports `pricingType='percentage'`
   - Lines 618-653: `mapExtraCodeToKey()` includes SR-EXTRA-* mappings
   - Lines 2690-2720: `getExtraPriceText()` shows "+10%" format

#### Salesforce Apex
1. **PriceCalculationApi.cls**:
   - Line 69-78: `ResponseProduct` class has `percentageOfBase` and `pricingType` fields
   - Lines 389-402: Query includes `Relatieve_prijs__c` field
   - Lines 507-539: Extra pricing logic checks percentage vs absolute

### ⏸️ Vereist: Data Configuratie
1. Prijsmanagement__c records voor 6 extras (zie configuratie script)
2. Gerelateerd_hoofdproduct__c voor SR-EXTRA-MEUBEL-* (zie configuratie script)
3. Beschikbare_Websites__c checken

## Deployment Status

### Code: ✅ Deployed
```
Deploy ID: 0Af9X000012nnVnSAI
Status: Succeeded
Deployed: PriceCalculationApi.cls (v64.0)
```

### Data: ⚠️ Pending
Run configuratie script om data in te stellen.

---

**Version**: 1.0  
**Last Updated**: 2025-01-07  
**Author**: GitHub Copilot  
**Related**: SR-IMPLEMENTATION-GUIDE.md, SR-SALESFORCE-CONFIGURATION.md
