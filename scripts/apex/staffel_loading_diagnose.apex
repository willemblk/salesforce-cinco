// Extra diagnose om te controleren waarom staffels niet worden ingeladen
// Test direct na het laden van de pricing context

Lead_Product__c lp = [SELECT Id, Lead__c, Product__c FROM Lead_Product__c WHERE Id = 'a4Z9X000002WBNNUA4' LIMIT 1];

System.debug('=== STAFFEL LOADING DIAGNOSE ===');

// Test de exacte staffel query die PricingService gebruikt  
Set<Id> policyIds = new Set<Id>{'a4a9X000003oaPxQAI'}; // Policy ID van onze diagnose

List<Prijsstaffel__c> staffels = [
    SELECT Id, Prijsmanagement__c, Ondergrens__c, Bovengrens__c, Eenheidsprijs__c
    FROM Prijsstaffel__c 
    WHERE Prijsmanagement__c IN :policyIds
    ORDER BY Prijsmanagement__c, Ondergrens__c ASC
];

System.debug('DIRECT QUERY - Gevonden ' + staffels.size() + ' staffel records:');
for (Prijsstaffel__c staffel : staffels) {
    System.debug('  Staffel ID: ' + staffel.Id);
    System.debug('  Prijsmanagement: ' + staffel.Prijsmanagement__c);
    System.debug('  Range: ' + staffel.Ondergrens__c + '-' + staffel.Bovengrens__c);
    System.debug('  Prijs: €' + staffel.Eenheidsprijs__c);
    System.debug('  ---');
}

// Test of de price type constants correct zijn
System.debug('=== PRICE TYPE CONSTANTS ===');
System.debug('PRICE_TYPE_STAFFEL_TREDE = "' + PricingService.PRICE_TYPE_STAFFEL_TREDE + '"');
System.debug('PRICE_TYPE_STAFFEL_CUMULATIEF = "' + PricingService.PRICE_TYPE_STAFFEL_CUMULATIEF + '"');