// Test script voor Lead_Product__c Regiotoeslag functionaliteit
// Dit script test de nieuwe implementatie van regiotoeslag voor Lead_Product__c

// Stap 1: Setup test data
System.debug('=== LEAD PRODUCT REGIOTOESLAG TEST START ===');

// Create Lead with PostalCode
Lead testLead = new Lead(
    FirstName = 'Test', 
    LastName = 'RegioToeslag', 
    Company = 'Test Company',
    PostalCode = '1012 AB',  // Amsterdam centrum
    Email = 'test@regiotoeslag.nl'
);
insert testLead;
System.debug('Created Lead: ' + testLead.Id + ' with PostalCode: ' + testLead.PostalCode);

// Create Product
Product2 testProduct = new Product2(
    Name = 'Test Regiotoeslag Product',
    ProductCode = 'REGIO-TEST',
    IsActive = true,
    Segment__c = 'Wasserij'
);
insert testProduct;

// Create pricing rule
Prijsmanagement__c testRule = new Prijsmanagement__c(
    Product__c = testProduct.Id,
    Eenheidsprijs__c = 25.00,
    Minimale_prijs__c = 100.00,
    Geldig_vanaf__c = Date.today().addDays(-1),
    Geldig_tot__c = Date.today().addDays(365)
);
insert testRule;

System.debug('Created Product: ' + testProduct.Id);
System.debug('Created Pricing Rule: Eenheidsprijs=€' + testRule.Eenheidsprijs__c);

// Stap 2: Create Lead_Product__c to trigger pricing calculation
Lead_Product__c testLeadProduct = new Lead_Product__c(
    Lead__c = testLead.Id,
    Product__c = testProduct.Id,
    Aantal__c = 2,
    SKU__c = 'REGIO-TEST'
);

System.debug('Inserting Lead_Product__c...');
insert testLeadProduct;

// Stap 3: Query results and verify regiotoeslag calculation
Lead_Product__c result = [
    SELECT Id, Lead__c, Product__c, Aantal__c, 
           Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c,
           Korting__c, Korting_bedrag__c
    FROM Lead_Product__c 
    WHERE Id = :testLeadProduct.Id
];

System.debug('=== RESULTS ===');
System.debug('Aantal: ' + result.Aantal__c);
System.debug('Verkoopprijs: €' + result.Verkoopprijs__c);
System.debug('Totale_Prijs: €' + result.Totale_Prijs__c);
System.debug('Regiotoeslag: ' + result.Regiotoeslag__c + '%');
System.debug('Korting: ' + result.Korting__c + '%');
System.debug('Korting_bedrag: €' + result.Korting_bedrag__c);

// Expected calculation:
// Base: 2 * €25.00 = €50.00
// Plus regiotoeslag (should be applied if Amsterdam has surcharge configured)
System.debug('Expected base price: €' + (2 * 25.00));

// Stap 4: Test cross-item updates
System.debug('\n=== TESTING CROSS-ITEM UPDATES ===');

// Add second product to same Lead
Lead_Product__c secondProduct = new Lead_Product__c(
    Lead__c = testLead.Id,
    Product__c = testProduct.Id,
    Aantal__c = 3,
    SKU__c = 'REGIO-TEST-2'
);

System.debug('Inserting second Lead_Product__c to trigger cross-item updates...');
insert secondProduct;

// Query both products after cross-item update
List<Lead_Product__c> allProducts = [
    SELECT Id, Aantal__c, Verkoopprijs__c, Totale_Prijs__c, 
           Regiotoeslag__c, Korting__c, Korting_bedrag__c
    FROM Lead_Product__c 
    WHERE Lead__c = :testLead.Id
    ORDER BY Aantal__c
];

System.debug('=== CROSS-ITEM UPDATE RESULTS ===');
for (Lead_Product__c lp : allProducts) {
    System.debug('Product ' + lp.Id + ':');
    System.debug('  Aantal: ' + lp.Aantal__c);
    System.debug('  Verkoopprijs: €' + lp.Verkoopprijs__c);
    System.debug('  Totale_Prijs: €' + lp.Totale_Prijs__c);
    System.debug('  Regiotoeslag: ' + lp.Regiotoeslag__c + '%');
    System.debug('  Korting: ' + lp.Korting__c + '%');
}

// Stap 5: Test deletion recalculation
System.debug('\n=== TESTING DELETION RECALCULATION ===');
delete secondProduct;
System.debug('Deleted second product - async recalculation should trigger');

System.debug('=== LEAD PRODUCT REGIOTOESLAG TEST COMPLETE ===');