// DLRS-COMPATIBLE DELETION TEST
// Test de nieuwe async approach die DLRS conflicts voorkomt

System.debug('🔄 DLRS-COMPATIBLE DELETION TEST START');
System.debug('='.repeat(50));

// Cleanup eerst
delete [SELECT Id FROM Wasserij_Item__c WHERE SKU__c = 'DLRS-TEST'];

// Setup test data
Product2 product = new Product2(
    Name='DLRS Test Carpet',
    ProductCode='DLRS-TEST',
    IsActive=true,
    Segment__c = 'Wasserij'
);
insert product;

Prijsmanagement__c pricing = new Prijsmanagement__c(
    Product__c = product.Id,
    Eenheidsprijs__c = 25.00,
    Geldig_vanaf__c = Date.today().addDays(-1),
    Geldig_tot__c = Date.today().addDays(365)
);
insert pricing;

Account account = new Account(Name='DLRS Test Account');
insert account;

Werk_Order__c workOrder = new Werk_Order__c(Account__c = account.Id);
insert workOrder;

System.debug('✅ Test data created');

// Create 3 large carpets (should get bundle discount)
List<Wasserij_Item__c> carpets = new List<Wasserij_Item__c>();
for (Integer i = 1; i <= 3; i++) {
    carpets.add(new Wasserij_Item__c(
        Werk_Order__c = workOrder.Id,
        Product__c = product.Id,
        SKU__c = 'DLRS-TEST',
        Lengte__c = 200,  // 4m² each
        Breedte__c = 200
    ));
}

System.debug('🟢 Inserting 3 carpets...');
insert carpets;

// Wait a moment for processing
for (Integer i = 0; i < 1000; i++) {
    // Small delay
}

// Check state after insert
List<Wasserij_Item__c> after3Items = [
    SELECT Id, Name, Korting__c, Korting_bedrag__c, Oppervlakte_m__c, Totale_Prijs__c
    FROM Wasserij_Item__c 
    WHERE Id IN :carpets
    ORDER BY Name
];

System.debug('\n📊 STATE AFTER INSERT (3 items):');
for (Wasserij_Item__c item : after3Items) {
    System.debug('   ' + item.Name + ': ' + item.Oppervlakte_m__c + 'm², €' + item.Totale_Prijs__c + ', ' + item.Korting__c + '%, €' + item.Korting_bedrag__c);
}

// Now delete 1 carpet - this should trigger DLRS-compatible async recalculation
System.debug('\n🔴 Deleting 1 carpet (testing DLRS-compatible logic)...');
Wasserij_Item__c toDelete = carpets[0];
delete toDelete;

System.debug('✅ Deletion completed');
System.debug('⏱️ Async recalculation has been scheduled via Queueable');
System.debug('💡 Check the Debug Logs in a few seconds to see the queueable execution');

System.debug('\n📝 WHAT TO EXPECT:');
System.debug('1. The deletion should complete without DLRS errors');
System.debug('2. A queueable job should be scheduled');
System.debug('3. The remaining 2 items should get recalculated discount (async)');
System.debug('4. No MAX_DEPTH_IN_FLOW_EXECUTION errors should occur');

// Cleanup test data
delete account;
delete workOrder;
delete pricing;
delete product;

System.debug('\n🧹 Test data cleaned up');
System.debug('🔄 DLRS-COMPATIBLE TEST COMPLETED');
System.debug('='.repeat(50));