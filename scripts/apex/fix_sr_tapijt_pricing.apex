// Fix SR Tapijt Pricing - Update to correct values
// SR-PRIM-TAPIJT-PLAT: €5.00 → €18.50/m²
// SR-PRIM-TAPIJT-TRAP: €7.50 → €8.50/trede (slightly increase)

System.debug('🔧 ===== FIXING SR TAPIJT PRICING =====');

// Find the products
List<Product2> products = [
    SELECT Id, ProductCode, Name
    FROM Product2
    WHERE ProductCode IN ('SR-PRIM-TAPIJT-PLAT', 'SR-PRIM-TAPIJT-TRAP')
];

if (products.isEmpty()) {
    System.debug('❌ ERROR: Products not found!');
} else {
    Map<String, Id> productMap = new Map<String, Id>();
    for (Product2 p : products) {
        productMap.put(p.ProductCode, p.Id);
        System.debug('✅ Found product: ' + p.ProductCode + ' (' + p.Name + ')');
    }
    
    // Find existing price records
    List<Prijsmanagement__c> priceRecords = [
        SELECT Id, Product__c, Product__r.ProductCode, Eenheidsprijs__c
        FROM Prijsmanagement__c
        WHERE Product__c IN :productMap.values()
          AND Actief__c = true
    ];
    
    if (priceRecords.isEmpty()) {
        System.debug('⚠️ No active price records found - creating new ones');
        
        // Create new price records
        List<Prijsmanagement__c> newPrices = new List<Prijsmanagement__c>();
        
        if (productMap.containsKey('SR-PRIM-TAPIJT-PLAT')) {
            newPrices.add(new Prijsmanagement__c(
                Product__c = productMap.get('SR-PRIM-TAPIJT-PLAT'),
                Eenheidsprijs__c = 18.50,
                Price_Type__c = 'Normaal',
                Actief__c = true,
                Geldig_vanaf__c = Date.today()
            ));
        }
        
        if (productMap.containsKey('SR-PRIM-TAPIJT-TRAP')) {
            newPrices.add(new Prijsmanagement__c(
                Product__c = productMap.get('SR-PRIM-TAPIJT-TRAP'),
                Eenheidsprijs__c = 8.50,
                Price_Type__c = 'Normaal',
                Actief__c = true,
                Geldig_vanaf__c = Date.today()
            ));
        }
        
        if (!newPrices.isEmpty()) {
            insert newPrices;
            System.debug('✅ Created ' + newPrices.size() + ' new price records');
        }
    } else {
        System.debug('📝 Updating existing price records');
        
        List<Prijsmanagement__c> toUpdate = new List<Prijsmanagement__c>();
        
        for (Prijsmanagement__c pr : priceRecords) {
            Decimal oldPrice = pr.Eenheidsprijs__c;
            Decimal newPrice = oldPrice;
            
            if (pr.Product__r.ProductCode == 'SR-PRIM-TAPIJT-PLAT') {
                newPrice = 18.50;
                System.debug('  - SR-PRIM-TAPIJT-PLAT: €' + oldPrice + ' → €' + newPrice);
            } else if (pr.Product__r.ProductCode == 'SR-PRIM-TAPIJT-TRAP') {
                newPrice = 8.50;
                System.debug('  - SR-PRIM-TAPIJT-TRAP: €' + oldPrice + ' → €' + newPrice);
            }
            
            if (newPrice != oldPrice) {
                pr.Eenheidsprijs__c = newPrice;
                toUpdate.add(pr);
            }
        }
        
        if (!toUpdate.isEmpty()) {
            update toUpdate;
            System.debug('✅ Updated ' + toUpdate.size() + ' price records');
        } else {
            System.debug('ℹ️ All prices already correct');
        }
    }
}

System.debug('\n🎉 Price update complete!');
System.debug('📋 Summary:');
System.debug('  - SR-PRIM-TAPIJT-PLAT: €18.50/m²');
System.debug('  - SR-PRIM-TAPIJT-TRAP: €8.50/trede');
