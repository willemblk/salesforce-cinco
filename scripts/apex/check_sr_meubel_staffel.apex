// Check if SR Meubel products have staffel pricing configured

System.debug('=== CHECKING SR MEUBEL STAFFEL PRICING ===');

// 1. Find SR Meubel products
List<Product2> srMeubelProducts = [
    SELECT Id, ProductCode, Name, IsActive
    FROM Product2
    WHERE ProductCode LIKE 'SR-PRIM-MEUBEL-%'
      AND IsActive = true
    ORDER BY ProductCode
];

System.debug('\n📦 Found ' + srMeubelProducts.size() + ' SR Meubel products:');
for (Product2 p : srMeubelProducts) {
    System.debug('  - ' + p.ProductCode + ': ' + p.Name);
}

// 2. Find Prijsmanagement records for these products
Set<Id> productIds = new Set<Id>();
for (Product2 p : srMeubelProducts) {
    productIds.add(p.Id);
}

List<Prijsmanagement__c> priceRecords = [
    SELECT Id, Product__c, Product__r.ProductCode, Eenheidsprijs__c, 
           Price_Type__c, Actief__c, Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__c IN :productIds
      AND Actief__c = true
      AND Geldig_vanaf__c <= TODAY
      AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
];

System.debug('\n💰 Found ' + priceRecords.size() + ' active price records:');
Map<Id, Prijsmanagement__c> priceMap = new Map<Id, Prijsmanagement__c>();
for (Prijsmanagement__c pm : priceRecords) {
    priceMap.put(pm.Id, pm);
    System.debug('  - ' + pm.Product__r.ProductCode + ': €' + pm.Eenheidsprijs__c + 
                ' (Type: ' + pm.Price_Type__c + ')');
}

// 3. Find Prijsstaffel records
List<Prijsstaffel__c> staffelRecords = [
    SELECT Id, Prijsmanagement__c, Prijsmanagement__r.Product__r.ProductCode,
           Ondergrens__c, Bovengrens__c, Eenheidsprijs__c, Vaste_Prijs__c
    FROM Prijsstaffel__c
    WHERE Prijsmanagement__c IN :priceMap.keySet()
    ORDER BY Prijsmanagement__r.Product__r.ProductCode, Ondergrens__c
];

System.debug('\n📊 Found ' + staffelRecords.size() + ' staffel tiers:');
if (staffelRecords.isEmpty()) {
    System.debug('  ⚠️ NO STAFFEL PRICING CONFIGURED!');
    System.debug('  This is why fallback pricing is being used.');
} else {
    String lastProductCode = '';
    for (Prijsstaffel__c ps : staffelRecords) {
        String productCode = ps.Prijsmanagement__r.Product__r.ProductCode;
        if (productCode != lastProductCode) {
            System.debug('\n  Product: ' + productCode);
            lastProductCode = productCode;
        }
        System.debug('    ' + ps.Ondergrens__c + '-' + ps.Bovengrens__c + ' seats: €' + 
                    (ps.Vaste_Prijs__c != null ? ps.Vaste_Prijs__c + ' (vast)' : 
                     ps.Eenheidsprijs__c + '/seat'));
    }
}

System.debug('\n=== SUMMARY ===');
System.debug('Products: ' + srMeubelProducts.size());
System.debug('Price records: ' + priceRecords.size());
System.debug('Staffel tiers: ' + staffelRecords.size());

if (staffelRecords.isEmpty()) {
    System.debug('\n❌ ACTION REQUIRED: Create Prijsstaffel__c records for SR Meubel products!');
    System.debug('Example for SR-PRIM-MEUBEL-FAUTEUIL:');
    System.debug('  Tier 1: 1-2 seats = €75/seat');
    System.debug('  Tier 2: 3-5 seats = €65/seat');
    System.debug('  Tier 3: 6-999 seats = €55/seat');
} else {
    System.debug('\n✅ Staffel pricing is configured and should be returned by API');
}
