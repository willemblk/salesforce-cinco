// Check SR Tapijt Product Pricing Configuration
// This script checks if SR-PRIM-TAPIJT-PLAT and SR-PRIM-TAPIJT-TRAP products exist
// and have correct pricing configured in Salesforce

System.debug('🧶 ===== SR TAPIJT PRICING CHECK =====');

// 1. Find SR Tapijt products
List<Product2> srTapijtProducts = [
    SELECT Id, ProductCode, Name, IsActive, Family
    FROM Product2 
    WHERE ProductCode LIKE 'SR-PRIM-TAPIJT%'
    ORDER BY ProductCode
];

System.debug('📦 Found ' + srTapijtProducts.size() + ' SR Tapijt products:');
for (Product2 p : srTapijtProducts) {
    System.debug('  - ' + p.ProductCode + ': ' + p.Name + ' (Active: ' + p.IsActive + ')');
}

if (srTapijtProducts.isEmpty()) {
    System.debug('❌ ERROR: No SR Tapijt products found! Please create:');
    System.debug('  - SR-PRIM-TAPIJT-PLAT (Vast tapijt - per m²)');
    System.debug('  - SR-PRIM-TAPIJT-TRAP (Tapijt trap - per trede)');
} else {
    // 2. Check Prijsmanagement (Price Management) records
    Set<Id> productIds = new Set<Id>();
    for (Product2 p : srTapijtProducts) {
        productIds.add(p.Id);
    }
    
    List<Prijsmanagement__c> priceRecords = [
        SELECT Id, Product__c, Product__r.ProductCode, Product__r.Name,
               Eenheidsprijs__c, Price_Type__c,
               Actief__c, Geldig_vanaf__c, Geldig_tot__c
        FROM Prijsmanagement__c
        WHERE Product__c IN :productIds
        ORDER BY Product__r.ProductCode
    ];
    
    System.debug('\n💰 Found ' + priceRecords.size() + ' price records:');
    for (Prijsmanagement__c pr : priceRecords) {
        System.debug('  - ' + pr.Product__r.ProductCode + ': €' + pr.Eenheidsprijs__c + 
                    ' (Active: ' + pr.Actief__c + ', Type: ' + pr.Price_Type__c + ')');
        if (pr.Eenheidsprijs__c < 5) {
            System.debug('    ⚠️ WARNING: Price seems too low! Expected €15-25/m² or €8-12/trede');
        }
    }
    
    // 3. Check for Staffel Pricing (Tiered Pricing)
    List<Prijsstaffel__c> staffelRecords = [
        SELECT Id, Prijsmanagement__r.Product__r.ProductCode,
               Ondergrens__c, Bovengrens__c, Eenheidsprijs__c
        FROM Prijsstaffel__c
        WHERE Prijsmanagement__c IN :priceRecords
        ORDER BY Prijsmanagement__r.Product__r.ProductCode, Ondergrens__c
    ];
    
    System.debug('\n📊 Found ' + staffelRecords.size() + ' staffel tiers:');
    if (staffelRecords.isEmpty()) {
        System.debug('  ℹ️ No staffel pricing configured (using flat Eenheidsprijs__c)');
    } else {
        String currentProduct = '';
        for (Prijsstaffel__c s : staffelRecords) {
            if (s.Prijsmanagement__r.Product__r.ProductCode != currentProduct) {
                currentProduct = s.Prijsmanagement__r.Product__r.ProductCode;
                System.debug('\n  ' + currentProduct + ':');
            }
            System.debug('    - ' + s.Ondergrens__c + '-' + s.Bovengrens__c + 
                        ' → €' + s.Eenheidsprijs__c);
        }
    }
}

System.debug('\n✅ Check complete!');
System.debug('\n💡 RECOMMENDED PRICING:');
System.debug('  - SR-PRIM-TAPIJT-PLAT: €18.50/m² (vast tapijt ter plekke)');
System.debug('  - SR-PRIM-TAPIJT-TRAP: €8.50/trede (tapijt trap)');
