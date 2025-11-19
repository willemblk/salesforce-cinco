// Check welke producten er zijn en test de pricing

// Zoek alle producten
List<Product2> allProducts = [
    SELECT Id, ProductCode, Name
    FROM Product2 
    LIMIT 10
];

System.debug('Gevonden producten: ' + allProducts.size());
for (Product2 p : allProducts) {
    System.debug('Product: ' + p.Name + ' (' + p.ProductCode + ')');
}

if (allProducts.isEmpty()) {
    System.debug('FOUT: Geen producten gevonden');
    return;
}

Product2 product = allProducts[0];
System.debug('Test product: ' + product.Name + ' (' + product.ProductCode + ')');

// Zoek een test Lead
List<Lead> testLeads = [
    SELECT Id, Name 
    FROM Lead 
    LIMIT 1
];

if (testLeads.isEmpty()) {
    System.debug('FOUT: Geen test Lead gevonden');
    return;
}

Lead testLead = testLeads[0];
System.debug('Test Lead: ' + testLead.Name);

// Test basic Lead_Product__c creation
System.debug('\n=== BASIC TEST ===');
Lead_Product__c test = new Lead_Product__c();
test.Lead__c = testLead.Id;
test.Product__c = product.Id;
test.Lengte_cm__c = 200;
test.Breedte_cm__c = 300;
test.Aantal__c = 5; // Set manual quantity

insert test;

// Reload om berekende waarden te zien
test = [SELECT Id, Oppervlakte_m__c, Aantal__c, Verkoopprijs__c, Totale_Prijs__c, SKU__c, Product__r.ProductCode
        FROM Lead_Product__c WHERE Id = :test.Id];

System.debug('Na insert:');
System.debug('Product Code: ' + test.Product__r.ProductCode);
System.debug('Oppervlakte_m__c: ' + test.Oppervlakte_m__c);
System.debug('Aantal__c: ' + test.Aantal__c);
System.debug('Verkoopprijs__c: ' + test.Verkoopprijs__c);
System.debug('Totale_Prijs__c: ' + test.Totale_Prijs__c);
System.debug('SKU__c: ' + test.SKU__c);

// Update test - change dimensions
System.debug('\n=== UPDATE TEST ===');
test.Lengte_cm__c = 100;
test.Breedte_cm__c = 100;
update test;

// Reload again
test = [SELECT Id, Oppervlakte_m__c, Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
        FROM Lead_Product__c WHERE Id = :test.Id];

System.debug('Na update (100x100):');
System.debug('Oppervlakte_m__c: ' + test.Oppervlakte_m__c);
System.debug('Aantal__c: ' + test.Aantal__c);
System.debug('Verkoopprijs__c: ' + test.Verkoopprijs__c);
System.debug('Totale_Prijs__c: ' + test.Totale_Prijs__c);

// Cleanup
delete test;
System.debug('\nTest record opgeruimd.');