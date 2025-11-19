// Reprice and persist all Lead_Product__c lines for the Lead of a given Lead_Product__c
Id lpId = 'a4Z9X000002hxlGUAQ';

Lead_Product__c seed = [SELECT Id, Lead__c FROM Lead_Product__c WHERE Id = :lpId LIMIT 1];
if (seed == null) {
    System.debug('❌ Lead_Product__c not found: ' + lpId);
    return;
}

Id leadId = seed.Lead__c;
List<SObject> priced = PricingService.repriceLead(leadId);

// Collect typed list for DML
List<Lead_Product__c> toUpdate = new List<Lead_Product__c>();
for (SObject so : priced) {
    toUpdate.add((Lead_Product__c)so);
}

Database.SaveResult[] sr = Database.update(toUpdate, false);
Integer ok = 0, ko = 0;
for (Database.SaveResult r : sr) {
    if (r.isSuccess()) ok++; else ko++;
}

System.debug('✅ Persisted repricing for Lead ' + leadId + ' | Success: ' + ok + ' | Failed: ' + ko);

// Show a compact summary after persistence
List<Lead_Product__c> lines = [
    SELECT Id, Product__r.ProductCode, Product__r.Primaryproduct__c,
           Aantal__c, Verkoopprijs__c, Totale_Prijs__c,
           Korting__c, Korting_bedrag__c, Regiotoeslag__c
    FROM Lead_Product__c
    WHERE Lead__c = :leadId
    ORDER BY Product__r.Primaryproduct__c DESC, Product__r.ProductCode
];
for (Lead_Product__c l : lines) {
    System.debug('— ' + l.Id + ' | ' + l.Product__r.ProductCode + ' | Prim=' + l.Product__r.Primaryproduct__c
        + ' | Unit=' + l.Verkoopprijs__c + ' | Total=' + l.Totale_Prijs__c 
        + ' | Regio%=' + l.Regiotoeslag__c + ' | Kort%=' + l.Korting__c + ' | Kort€=' + l.Korting_bedrag__c);
}
