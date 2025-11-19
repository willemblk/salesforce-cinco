// Inspect repriced Lead_Product__c lines: verify discount amounts applied to extras
Id lpId = 'a4Z9X000002hxlGUAQ';
Lead_Product__c lp = [SELECT Id, Lead__c FROM Lead_Product__c WHERE Id = :lpId LIMIT 1];
if (lp == null) {
    System.debug('❌ Lead_Product__c not found: ' + lpId);
} else {
    Id leadId = lp.Lead__c;
    List<Lead_Product__c> lines = [
        SELECT Id,
               Product__r.ProductCode,
               Product__r.Primaryproduct__c,
               Aantal__c,
               Verkoopprijs__c,
               Totale_Prijs__c,
               Korting__c,
               Korting_bedrag__c,
               Regiotoeslag__c,
               Gerelateerd_Product__c
        FROM Lead_Product__c
        WHERE Lead__c = :leadId
        ORDER BY Product__r.Primaryproduct__c DESC, Product__r.ProductCode
    ];
    System.debug('📊 Lead ' + leadId + ' has ' + lines.size() + ' priced lines:');
    for (Lead_Product__c l : lines) {
        String code = (l.Product__r != null ? l.Product__r.ProductCode : '');
        Boolean isPrimary = (l.Product__r != null && l.Product__r.Primaryproduct__c == true);
        System.debug('— ' + l.Id + ' | ' + code + ' | Primary=' + isPrimary);
        System.debug('   Qty=' + l.Aantal__c + ' | Unit(ex)=' + l.Verkoopprijs__c + ' | Total(ex)=' + l.Totale_Prijs__c);
        System.debug('   Regio%=' + l.Regiotoeslag__c + ' | Korting%=' + l.Korting__c + ' | Korting_bedrag=' + l.Korting_bedrag__c);
        if (!isPrimary) {
            System.debug('   Related Primary Line=' + l.Gerelateerd_Product__c);
        }
    }
}
