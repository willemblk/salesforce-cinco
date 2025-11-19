// Diepere diagnose van Prijsmanagement en Prijsstaffel records
// Voor Product: 01t9X00000J5oIzQAJ (Dakkapel Reinigen)

System.debug('=== PRIJSMANAGEMENT DIAGNOSE ===');

// Controleer alle Prijsmanagement records voor dit product
List<Prijsmanagement__c> policies = [SELECT Id, Name, Product__c, Product__r.Name, Product__r.ProductCode,
                                           Eenheidsprijs__c, Minimale_prijs__c, Price_Type__c, Regiotoeslag_toepasbaar__c,
                                           Actief__c, Geldig_vanaf__c, Geldig_tot__c
                                      FROM Prijsmanagement__c 
                                      WHERE Product__c = '01t9X00000J5oIzQAJ'
                                      ORDER BY CreatedDate DESC];

System.debug('Gevonden ' + policies.size() + ' Prijsmanagement records voor Dakkapel Reinigen:');

for (Prijsmanagement__c policy : policies) {
    System.debug('Record: ' + policy.Name + ' (ID: ' + policy.Id + ')');
    System.debug('  Product: ' + policy.Product__r.Name + ' (' + policy.Product__r.ProductCode + ')');
    System.debug('  Prijstype: ' + policy.Price_Type__c);
    System.debug('  Eenheidsprijs: €' + policy.Eenheidsprijs__c);
    System.debug('  Minimaleprijs: €' + policy.Minimale_prijs__c);
    System.debug('  Regiotoeslag toepasbaar: ' + policy.Regiotoeslag_toepasbaar__c);
    System.debug('  Actief: ' + policy.Actief__c);
    System.debug('  Geldig vanaf: ' + policy.Geldig_vanaf__c);
    System.debug('  Geldig tot: ' + policy.Geldig_tot__c);
    System.debug('  ---');
    
    // Voor Staffel Trede, check de Prijsstaffel records
    if (policy.Price_Type__c == 'Staffel Trede') {
        List<Prijsstaffel__c> staffels = [SELECT Id, Prijsmanagement__c, Ondergrens__c, Bovengrens__c, Eenheidsprijs__c
                                          FROM Prijsstaffel__c 
                                          WHERE Prijsmanagement__c = :policy.Id
                                          ORDER BY Ondergrens__c ASC];
        
        System.debug('  Gevonden ' + staffels.size() + ' Prijsstaffel records:');
        for (Prijsstaffel__c staffel : staffels) {
            System.debug('    Staffel: ' + staffel.Ondergrens__c + '-' + staffel.Bovengrens__c + ' = €' + staffel.Eenheidsprijs__c);
        }
    }
}

// Test ook de exacte query die PricingService gebruikt
System.debug('=== TESTING EXACT PRICING SERVICE QUERY ===');
List<Prijsmanagement__c> activePolicy = [
    SELECT Id, Product__c, Price_Type__c, Eenheidsprijs__c, Minimale_prijs__c, Regiotoeslag_toepasbaar__c,
           (SELECT Id, Ondergrens__c, Bovengrens__c, Eenheidsprijs__c 
            FROM Prijsstaffels__r 
            ORDER BY Ondergrens__c ASC)
    FROM Prijsmanagement__c 
    WHERE Product__c = '01t9X00000J5oIzQAJ'
    AND Actief__c = true 
    AND (Geldig_vanaf__c = null OR Geldig_vanaf__c <= TODAY)
    AND (Geldig_tot__c = null OR Geldig_tot__c >= TODAY)
    ORDER BY CreatedDate DESC 
    LIMIT 1
];

if (activePolicy.size() > 0) {
    Prijsmanagement__c policy = activePolicy[0];
    System.debug('Active policy gevonden: ' + policy.Id);
    System.debug('  Prijstype: ' + policy.Price_Type__c);
    System.debug('  Eenheidsprijs: €' + policy.Eenheidsprijs__c);
    System.debug('  Staffel records: ' + policy.Prijsstaffels__r.size());
    
    for (Prijsstaffel__c staffel : policy.Prijsstaffels__r) {
        System.debug('    Actieve Staffel: ' + staffel.Ondergrens__c + '-' + staffel.Bovengrens__c + ' = €' + staffel.Eenheidsprijs__c);
    }
} else {
    System.debug('Geen active policy gevonden die voldoet aan de criteria!');
}