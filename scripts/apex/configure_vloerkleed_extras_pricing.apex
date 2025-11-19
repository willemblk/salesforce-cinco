/**
 * Configure Vloerkleed Extras Pricing in Salesforce
 * 
 * Purpose: Create Prijsmanagement__c records for all vloerkleed extras
 * with correct Price_Type__c and Eenheidsprijs__c values
 * 
 * Run: sf apex run --file scripts/apex/configure_vloerkleed_extras_pricing.apex
 */

System.debug('=== CONFIGURE VLOERKLEED EXTRAS PRICING ===\n');

// Define pricing configuration for each extra
Map<String, Map<String, Object>> extraPricing = new Map<String, Map<String, Object>>{
    'WAS-EXTRA-VLOERKLEED-VEZEL' => new Map<String, Object>{
        'price_type' => 'Normaal',
        'relatieve_prijs' => 10.0, // 10% of base price
        'eenheidsprijs' => null,
        'description' => 'Vezelbescherming (percentage-based)'
    },
    'WAS-EXTRA-VLOERKLEED-GEUR' => new Map<String, Object>{
        'price_type' => 'Normaal',
        'relatieve_prijs' => 20.0, // 20% of base price
        'eenheidsprijs' => null,
        'description' => 'Geurgarantie (percentage-based)'
    },
    'WAS-EXTRA-VLOERKLEED-MOT' => new Map<String, Object>{
        'price_type' => 'Normaal',
        'relatieve_prijs' => null,
        'eenheidsprijs' => 10.00, // €10/m²
        'description' => 'Mottenbehandeling (per m²)'
    },
    'WAS-EXTRA-VLOERKLEED-WATER' => new Map<String, Object>{
        'price_type' => 'Normaal',
        'relatieve_prijs' => null,
        'eenheidsprijs' => 15.00, // €15/m²
        'description' => 'Waterschade behandeling (per m²)'
    },
    'WAS-EXTRA-VLOERKLEED-ZIJDE' => new Map<String, Object>{
        'price_type' => 'Normaal',
        'relatieve_prijs' => null,
        'eenheidsprijs' => 40.00, // €40/m²
        'description' => 'Zijde/viscose behandeling (per m²)'
    },
    'WAS-EXTRA-VLOERKLEED-INPAKOPSLAG' => new Map<String, Object>{
        'price_type' => 'Flat Fee',
        'relatieve_prijs' => null,
        'eenheidsprijs' => 14.46, // Flat fee (not per m²)
        'description' => 'Inpakken & Opslag (flat fee)'
    },
    'WAS-EXTRA-VLOERKLEED-INPAKPLASTIC' => new Map<String, Object>{
        'price_type' => 'Flat Fee',
        'relatieve_prijs' => null,
        'eenheidsprijs' => 9.50, // Flat fee (not per m²)
        'description' => 'Plastic verpakking (flat fee)'
    }
};

// Get all products
Map<String, Product2> productMap = new Map<String, Product2>();
for (Product2 p : [
    SELECT Id, ProductCode, Name 
    FROM Product2 
    WHERE ProductCode IN :extraPricing.keySet()
      AND IsActive = true
]) {
    productMap.put(p.ProductCode, p);
}

System.debug('Found ' + productMap.size() + ' products to configure\n');

// Check existing pricing
Map<Id, Prijsmanagement__c> existingPricing = new Map<Id, Prijsmanagement__c>();
for (Prijsmanagement__c pm : [
    SELECT Id, Product__c, Price_Type__c, Eenheidsprijs__c, Relatieve_prijs__c, Actief__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode IN :extraPricing.keySet()
      AND Actief__c = true
]) {
    existingPricing.put(pm.Product__c, pm);
}

System.debug('Found ' + existingPricing.size() + ' existing pricing records\n');

// Create or update pricing records
List<Prijsmanagement__c> toUpsert = new List<Prijsmanagement__c>();
Integer created = 0;
Integer updated = 0;

for (String productCode : extraPricing.keySet()) {
    if (!productMap.containsKey(productCode)) {
        System.debug('⚠️ Product not found: ' + productCode);
        continue;
    }
    
    Product2 product = productMap.get(productCode);
    Map<String, Object> config = extraPricing.get(productCode);
    
    Prijsmanagement__c pm;
    Boolean isNew = false;
    
    if (existingPricing.containsKey(product.Id)) {
        // Update existing
        pm = existingPricing.get(product.Id);
        updated++;
    } else {
        // Create new
        pm = new Prijsmanagement__c();
        pm.Product__c = product.Id;
        pm.Actief__c = true;
        pm.Geldig_vanaf__c = Date.today();
        // Geldig_tot__c remains null (indefinite)
        isNew = true;
        created++;
    }
    
    // Set pricing fields
    pm.Price_Type__c = (String)config.get('price_type');
    pm.Eenheidsprijs__c = (Decimal)config.get('eenheidsprijs');
    pm.Relatieve_prijs__c = (Decimal)config.get('relatieve_prijs');
    
    toUpsert.add(pm);
    
    // Log what we're doing
    String action = isNew ? 'CREATE' : 'UPDATE';
    String priceInfo = '';
    
    if (pm.Relatieve_prijs__c != null) {
        priceInfo = pm.Relatieve_prijs__c + '% of base';
    } else if (pm.Eenheidsprijs__c != null) {
        priceInfo = '€' + pm.Eenheidsprijs__c;
        if (pm.Price_Type__c == 'Flat Fee') {
            priceInfo += ' (flat)';
        } else {
            priceInfo += ' /m²';
        }
    }
    
    System.debug('[' + action + '] ' + productCode + ': ' + priceInfo + ' (' + config.get('description') + ')');
}

// Upsert records
if (!toUpsert.isEmpty()) {
    System.debug('\n=== UPSERTING ' + toUpsert.size() + ' PRICING RECORDS ===\n');
    
    try {
        upsert toUpsert;
        System.debug('✅ SUCCESS!\n');
        System.debug('Created: ' + created + ' records');
        System.debug('Updated: ' + updated + ' records');
        System.debug('Total: ' + toUpsert.size() + ' records\n');
        
        // Verify results
        System.debug('=== VERIFICATION ===\n');
        for (Prijsmanagement__c pm : [
            SELECT Product__r.ProductCode, Price_Type__c, Eenheidsprijs__c, Relatieve_prijs__c
            FROM Prijsmanagement__c
            WHERE Product__r.ProductCode IN :extraPricing.keySet()
              AND Actief__c = true
            ORDER BY Product__r.ProductCode
        ]) {
            String priceInfo = '';
            if (pm.Relatieve_prijs__c != null) {
                priceInfo = pm.Relatieve_prijs__c + '% of base';
            } else {
                priceInfo = '€' + pm.Eenheidsprijs__c;
            }
            System.debug('✅ ' + pm.Product__r.ProductCode + ' (' + pm.Price_Type__c + '): ' + priceInfo);
        }
        
    } catch (Exception e) {
        System.debug('❌ ERROR: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
    }
} else {
    System.debug('⚠️ No records to upsert');
}

System.debug('\n=== SCRIPT COMPLETE ===');
System.debug('Next steps:');
System.debug('1. Add "Flat Fee" to Price_Type__c picklist if not already present');
System.debug('2. Test API: /wp-json/cinco/v1/calculate-price');
System.debug('3. Check console logs for "flat fee (Salesforce)" message');
