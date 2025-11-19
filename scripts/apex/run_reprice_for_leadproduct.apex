// Reprice the Lead associated with a given Lead_Product__c and print line summaries
Id lpId = 'a4Z9X000002hxlGUAQ';
Lead_Product__c lp = [SELECT Id, Lead__c FROM Lead_Product__c WHERE Id = :lpId LIMIT 1];
if (lp == null) {
    System.debug('❌ Lead_Product__c not found: ' + lpId);
} else {
    List<SObject> priced = PricingService.repriceLead(lp.Lead__c);
    System.debug('✅ Repriced ' + priced.size() + ' lines for Lead ' + lp.Lead__c);

    // Build primary discount map by productId for mirroring
    Map<Id, Decimal> primaryDiscountByProduct = new Map<Id, Decimal>();

    for (SObject so : priced) {
        Lead_Product__c l = (Lead_Product__c)so;
        if (l.Product__r != null && l.Product__r.Primaryproduct__c == true) {
            primaryDiscountByProduct.put(l.Product__c, l.Korting__c);
        }
    }

    for (SObject so : priced) {
        Lead_Product__c l = (Lead_Product__c)so;
        String code = (l.Product__r != null ? l.Product__r.ProductCode : l.SKU__c);
        Boolean isPrimary = (l.Product__r != null ? l.Product__r.Primaryproduct__c : false);
        System.debug('— Line: ' + l.Id + ' | Code=' + code + ' | Primary=' + isPrimary);
        System.debug('   Aantal=' + l.Aantal__c + ' | Unit(ex)=' + l.Verkoopprijs__c + ' | Total(ex)=' + l.Totale_Prijs__c);
    System.debug('   Regio%=' + l.Regiotoeslag__c + ' | Korting%=' + l.Korting__c + ' | Gerelateerd_Product__c=' + l.Gerelateerd_Product__c);

        if (!isPrimary && l.Gerelateerd_Product__c != null) {
            Decimal expectedMirrored = primaryDiscountByProduct.get(l.Gerelateerd_Product__c);
            System.debug('   🔎 Extra validation → Expected mirrored Korting% (from primary): ' + expectedMirrored + ' | Regio% should be 0');
        }
    }
}
