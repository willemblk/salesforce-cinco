// Test script om area calculation en pricing te verifiëren voor Lead_Product__c

// Zoek een vloerkleed product
List<Product2> floorCarpetProducts = [
    SELECT Id, ProductCode, Name
    FROM Product2 
    WHERE ProductCode LIKE 'VKLEED%' 
    LIMIT 1
];

if (floorCarpetProducts.isEmpty()) {
    System.debug('FOUT: Geen vloerkleed producten gevonden met ProductCode VKLEED*');
    return;
}

Product2 product = floorCarpetProducts[0];
System.debug('Gevonden product: ' + product.Name + ' (' + product.ProductCode + ')');

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

// Check pricing rules voor dit product
List<Prijsmanagement__c> rules = [
    SELECT Id, Eenheidsprijs__c, Onderste_staffelwaarde__c, Bovenste_staffelwaarde__c
    FROM Prijsmanagement__c 
    WHERE Product__c = :product.Id
    ORDER BY Onderste_staffelwaarde__c ASC
];

System.debug('Pricing rules gevonden: ' + rules.size());
for (Prijsmanagement__c rule : rules) {
    System.debug('Rule: Eenheidsprijs=' + rule.Eenheidsprijs__c + 
                ', Onderste=' + rule.Onderste_staffelwaarde__c + 
                ', Bovenste=' + rule.Bovenste_staffelwaarde__c);
}

// Test 1: Klein vloerkleed (100x100 = 1m²)
System.debug('\n=== TEST 1: Klein vloerkleed 100x100cm (1m²) ===');
Lead_Product__c test1 = new Lead_Product__c();
test1.Lead__c = testLead.Id;
test1.Product__c = product.Id;
test1.Lengte_cm__c = 100;
test1.Breedte_cm__c = 100;

insert test1;

// Reload om berekende waarden te zien
test1 = [SELECT Id, Oppervlakte_m__c, Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
         FROM Lead_Product__c WHERE Id = :test1.Id];

System.debug('Na insert:');
System.debug('Oppervlakte_m__c: ' + test1.Oppervlakte_m__c);
System.debug('Aantal__c: ' + test1.Aantal__c);
System.debug('Verkoopprijs__c: ' + test1.Verkoopprijs__c);
System.debug('Totale_Prijs__c: ' + test1.Totale_Prijs__c);

// Test 2: Groot vloerkleed (100x1000 = 10m²)
System.debug('\n=== TEST 2: Groot vloerkleed 100x1000cm (10m²) ===');
Lead_Product__c test2 = new Lead_Product__c();
test2.Lead__c = testLead.Id;
test2.Product__c = product.Id;
test2.Lengte_cm__c = 100;
test2.Breedte_cm__c = 1000;

insert test2;

// Reload om berekende waarden te zien
test2 = [SELECT Id, Oppervlakte_m__c, Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
         FROM Lead_Product__c WHERE Id = :test2.Id];

System.debug('Na insert:');
System.debug('Oppervlakte_m__c: ' + test2.Oppervlakte_m__c);
System.debug('Aantal__c: ' + test2.Aantal__c);
System.debug('Verkoopprijs__c: ' + test2.Verkoopprijs__c);
System.debug('Totale_Prijs__c: ' + test2.Totale_Prijs__c);

// Analyse
System.debug('\n=== ANALYSE ===');
if (test1.Oppervlakte_m__c != null && test2.Oppervlakte_m__c != null) {
    System.debug('Verhouding oppervlakte: ' + test2.Oppervlakte_m__c + ' / ' + test1.Oppervlakte_m__c + ' = ' + (test2.Oppervlakte_m__c / test1.Oppervlakte_m__c));
}

if (test1.Totale_Prijs__c != null && test2.Totale_Prijs__c != null) {
    System.debug('Verhouding totale prijs: ' + test2.Totale_Prijs__c + ' / ' + test1.Totale_Prijs__c + ' = ' + (test2.Totale_Prijs__c / test1.Totale_Prijs__c));
}

if (test1.Verkoopprijs__c != null && test2.Verkoopprijs__c != null) {
    System.debug('Verkoopprijs per m² test1: ' + test1.Verkoopprijs__c);
    System.debug('Verkoopprijs per m² test2: ' + test2.Verkoopprijs__c);
    System.debug('Zijn deze gelijk? ' + (test1.Verkoopprijs__c == test2.Verkoopprijs__c));
}

// Cleanup
delete new List<Lead_Product__c>{test1, test2};
System.debug('\nTest records opgeruimd.');