// SR Extras Percentage Pricing Configuration Script
// Run via: sf apex run --file scripts/apex/configure_sr_extras_percentage.apex
// This script sets up Prijsmanagement__c records and parent relationships

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
