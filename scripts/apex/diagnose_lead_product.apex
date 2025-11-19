// Debug script voor specifieke Lead Product pricing diagnose
// Lead_Product__c : a4Z9X000002WBNNUA4
// Lead: 00Q9X00003Fw2KDUAZ

Lead_Product__c lp = [SELECT Id, Lead__c, Product__c, Product__r.Name, Product__r.ProductCode, 
                           Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
                      FROM Lead_Product__c 
                      WHERE Id = 'a4Z9X000002WBNNUA4' LIMIT 1];

System.debug('=== LEAD PRODUCT DIAGNOSE ===');
System.debug('Lead Product ID: ' + lp.Id);
System.debug('Product: ' + lp.Product__r.Name + ' (' + lp.Product__r.ProductCode + ')');
System.debug('Product ID: ' + lp.Product__c);
System.debug('Aantal: ' + lp.Aantal__c);
System.debug('Huidige Verkoopprijs: ' + lp.Verkoopprijs__c);
System.debug('Huidige Totale_Prijs: ' + lp.Totale_Prijs__c);

// Test de PricingService direct
System.debug('=== TRIGGERING PRICING SERVICE ===');
List<SObject> updatedRecords = PricingService.repriceLead(lp.Lead__c);

System.debug('=== RESULTATEN ===');
System.debug('Aantal geretourneerde records: ' + updatedRecords.size());

for (SObject record : updatedRecords) {
    if (record instanceof Lead_Product__c) {
        Lead_Product__c updated = (Lead_Product__c) record;
        if (updated.Id == lp.Id) {
            System.debug('GEVONDEN - Updated Lead Product:');
            System.debug('  Nieuwe Verkoopprijs: ' + updated.Verkoopprijs__c);
            System.debug('  Nieuwe Totale_Prijs: ' + updated.Totale_Prijs__c);
            System.debug('  Nieuwe Regiotoeslag: ' + updated.Regiotoeslag__c);
        }
    }
}