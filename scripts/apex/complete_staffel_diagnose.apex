// Volledige diagnose om de Staffel Trede mismatch te vinden
Lead_Product__c lp = [SELECT Id, Lead__c, Product__c FROM Lead_Product__c WHERE Id = 'a4Z9X000002WBNNUA4' LIMIT 1];

System.debug('=== COMPLETE STAFFEL DIAGNOSE ===');

// Test de constanten values
System.debug('CONSTANTS CHECK:');
System.debug('Expected STAFFEL_TREDE: "Staffel Trede"');

// Check de policy data weer
Prijsmanagement__c policy = [SELECT Id, Price_Type__c FROM Prijsmanagement__c WHERE Id = 'a4a9X000003oaPxQAI'];
System.debug('Database Price_Type__c: "' + policy.Price_Type__c + '"');
System.debug('String comparison: ' + (policy.Price_Type__c == 'Staffel Trede'));

// Test het exact vergelijkings-punt waar het misgaat
// Dit is de kritieke check in line 348-349 van PricingService
if (policy.Price_Type__c == 'Staffel Cumulatief' || policy.Price_Type__c == 'Staffel Trede') {
    System.debug('✅ Policy SHOULD trigger staffel loading');
} else {
    System.debug('❌ Policy does NOT match staffel types');
}

// Check if staffels are actually loaded
List<Prijsstaffel__c> directStaffels = [
    SELECT Id, Prijsmanagement__c, Ondergrens__c, Bovengrens__c, Eenheidsprijs__c
    FROM Prijsstaffel__c 
    WHERE Prijsmanagement__c = 'a4a9X000003oaPxQAI'
    ORDER BY Ondergrens__c ASC
];

System.debug('Direct staffel query result: ' + directStaffels.size() + ' records');
for (Prijsstaffel__c staffel : directStaffels) {
    System.debug('  Staffel: ' + staffel.Ondergrens__c + '-' + staffel.Bovengrens__c + ' = €' + staffel.Eenheidsprijs__c);
}