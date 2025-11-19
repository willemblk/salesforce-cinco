// Simple BTW Update Test
Lead_Product__c lp = [
    SELECT Id, Product__r.BTW__c, BTW__c 
    FROM Lead_Product__c 
    WHERE BTW__c = null AND CreatedDate = TODAY 
    LIMIT 1
];

System.debug('BEFORE: BTW__c = ' + lp.BTW__c);
System.debug('Product2.BTW__c = ' + lp.Product__r.BTW__c);

// Manually set BTW__c (simulating what PricingService should do)
lp.BTW__c = Decimal.valueOf(lp.Product__r.BTW__c) / 100;

System.debug('AFTER (in-memory): BTW__c = ' + lp.BTW__c);

update lp;

Lead_Product__c updated = [SELECT BTW__c, BTW_Bedrag__c FROM Lead_Product__c WHERE Id = :lp.Id];
System.debug('AFTER (database): BTW__c = ' + updated.BTW__c);
System.debug('BTW_Bedrag__c = €' + updated.BTW_Bedrag__c);
