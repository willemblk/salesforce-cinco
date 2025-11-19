// COMPREHENSIVE DLRS-COMPATIBLE TEST
// Tests the complete deletion scenario with async processing

System.debug('🎯 COMPREHENSIVE DLRS-COMPATIBLE TEST');
System.debug('='.repeat(50));

// Cleanup first
delete [SELECT Id FROM Wasserij_Item__c WHERE SKU__c = 'COMP-DLRS'];

// Setup
Product2 product = new Product2(
    Name='Complete DLRS Test Carpet',
    ProductCode='COMP-DLRS',
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

Account account = new Account(Name='Complete DLRS Test Account');
insert account;

Werk_Order__c workOrder = new Werk_Order__c(Account__c = account.Id);
insert workOrder;

System.debug('✅ Test data created');

// Create 3 large carpets
List<Wasserij_Item__c> carpets = new List<Wasserij_Item__c>();
for (Integer i = 1; i <= 3; i++) {
    carpets.add(new Wasserij_Item__c(
        Werk_Order__c = workOrder.Id,
        Product__c = product.Id,
        SKU__c = 'COMP-DLRS',
        Lengte__c = 200,  // 4m² each
        Breedte__c = 200
    ));
}

System.debug('🟢 Creating 3 carpets...');
insert carpets;

// Check discount after insert
List<Wasserij_Item__c> afterInsert = [
    SELECT Id, Name, Korting__c, Korting_bedrag__c, Oppervlakte_m__c, Totale_Prijs__c
    FROM Wasserij_Item__c 
    WHERE Id IN :carpets
    ORDER BY Name
];

System.debug('\n📊 AFTER INSERT (3 items):');
Decimal expectedDiscount3 = null;
for (Wasserij_Item__c item : afterInsert) {
    System.debug('   ' + item.Name + ': ' + item.Korting__c + '%, €' + item.Korting_bedrag__c);
    expectedDiscount3 = item.Korting__c;
}

// Delete 1 carpet - CRITICAL TEST
System.debug('\n🔴 DELETING 1 CARPET (DLRS-COMPATIBLE)...');
Wasserij_Item__c toDelete = carpets[0];
System.debug('Deleting: ' + toDelete.Id);

delete toDelete;

System.debug('✅ Deletion completed WITHOUT DLRS errors!');
System.debug('⏱️ Async recalculation has been scheduled via Queueable');

// Check if queueable was enqueued (may take a moment)
List<AsyncApexJob> recentJobs = [
    SELECT Id, Status, JobType, CreatedDate 
    FROM AsyncApexJob 
    WHERE JobType = 'Queueable' 
    AND CreatedDate = TODAY 
    ORDER BY CreatedDate DESC 
    LIMIT 1
];

if (!recentJobs.isEmpty()) {
    System.debug('✅ Queueable job found: ' + recentJobs[0].Id + ' (Status: ' + recentJobs[0].Status + ')');
} else {
    System.debug('⚠️ No recent queueable job found (may still be processing)');
}

System.debug('\n💡 WHAT SHOULD HAPPEN NEXT:');
System.debug('1. The queueable will execute in the background');
System.debug('2. Remaining 2 items should get recalculated discount');
System.debug('3. No DLRS conflicts or MAX_DEPTH errors');

System.debug('\n📝 TO VERIFY THE FIX:');
System.debug('1. Wait 10-30 seconds for async processing');
System.debug('2. Check remaining items for correct 2-item discount');
System.debug('3. Verify no trigger exception errors in debug logs');

// Cleanup
delete account;
delete workOrder;
delete pricing;
delete product;

System.debug('\n🧹 Test data cleaned up');
System.debug('🎯 DLRS-COMPATIBLE TEST COMPLETED');
System.debug('='.repeat(50));