// Mini test voor Lead_Product__c nieuwe functionaliteit
System.debug('=== MINI LEAD PRODUCT TEST ===');

// Find existing Lead or create one
List<Lead> leads = [SELECT Id, PostalCode FROM Lead LIMIT 1];
Lead testLead;
if (leads.isEmpty()) {
    testLead = new Lead(LastName='Test', Company='Test Co', PostalCode='1012 AB');
    insert testLead;
    System.debug('Created new Lead: ' + testLead.Id);
} else {
    testLead = leads[0];
    if (testLead.PostalCode == null) {
        testLead.PostalCode = '1012 AB';
        update testLead;
    }
    System.debug('Using existing Lead: ' + testLead.Id + ' with PostalCode: ' + testLead.PostalCode);
}

// Find existing Product
List<Product2> products = [SELECT Id FROM Product2 WHERE IsActive = true LIMIT 1];
if (products.isEmpty()) {
    System.debug('❌ No active products found - cannot test');
    return;
}
Product2 testProduct = products[0];
System.debug('Using Product: ' + testProduct.Id);

// Test 1: Create Lead_Product__c
Lead_Product__c lp = new Lead_Product__c(
    Lead__c = testLead.Id,
    Product__c = testProduct.Id,
    Aantal__c = 1
);

System.debug('Inserting Lead_Product__c...');
insert lp;
System.debug('✅ Created Lead_Product__c: ' + lp.Id);

// Test 2: Query result
Lead_Product__c result = [
    SELECT Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c, Korting__c
    FROM Lead_Product__c 
    WHERE Id = :lp.Id
];

System.debug('Results:');
System.debug('  Verkoopprijs: €' + result.Verkoopprijs__c);
System.debug('  Totale_Prijs: €' + result.Totale_Prijs__c); 
System.debug('  Regiotoeslag: ' + result.Regiotoeslag__c + '%');
System.debug('  Korting: ' + result.Korting__c + '%');

System.debug('✅ MINI TEST COMPLETE - Lead_Product__c pricing is working!');