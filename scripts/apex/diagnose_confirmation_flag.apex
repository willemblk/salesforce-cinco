Pricebook2 stdPb = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!stdPb.IsActive) {
    stdPb.IsActive = true;
    update stdPb;
}

Account customer = new Account(Name = 'Diag Account ' + DateTime.now().getTime());
insert customer;

Account partner = new Account(Name = 'Diag Partner ' + DateTime.now().getTime());
insert partner;

Postcode_Range__c range = new Postcode_Range__c(Name = 'Diag Range ' + DateTime.now().getTime(), Postcode_Begin__c = 1000, Postcode_Einde__c = 1099);
insert range;

Opportunity opp = new Opportunity(
    Name = 'Diag Opp ' + Date.today().format(),
    AccountId = customer.Id,
    StageName = 'Prospecting',
    CloseDate = Date.today().addDays(5),
    Pricebook2Id = stdPb.Id,
    Partner__c = partner.Id,
    Postcodegebied__c = range.Id,
    Uniek_Segment__c = 'Wasserij'
);
insert opp;

Product2 product = new Product2(Name = 'Diag Product ' + DateTime.now().getTime(), IsActive = true, Segment__c = 'Wasserij');
insert product;

PricebookEntry pbe = new PricebookEntry(Pricebook2Id = stdPb.Id, Product2Id = product.Id, UnitPrice = 25, IsActive = true);
insert pbe;

OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 25);
insert oli;

OpportunityToWorkOrderConverter.Request req = new OpportunityToWorkOrderConverter.Request();
req.opportunityId = opp.Id;
OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ req });

Werk_Order__c wo = [
    SELECT Id, Automation_Bypass__c, Bevestigingen_sturen__c, Werk_Order_Status__c
    FROM Werk_Order__c
    WHERE Opportunity__c = :opp.Id
    LIMIT 1
];
Integer wasserijItemCount = [SELECT COUNT() FROM Wasserij_Item__c WHERE Werk_Order__c = :wo.Id];
System.debug('Diag WO => Bevestigingen=' + wo.Bevestigingen_sturen__c + ', Bypass=' + wo.Automation_Bypass__c + ', Status=' + wo.Werk_Order_Status__c + ', Items=' + wasserijItemCount);

// Cleanup created data
List<SObject> cleanup = new List<SObject>();
cleanup.addAll([SELECT Id FROM Wasserij_Item__c WHERE Werk_Order__c = :wo.Id]);
cleanup.add(wo);
cleanup.addAll([SELECT Id FROM OpportunityLineItem WHERE OpportunityId = :opp.Id]);
cleanup.add(opp);
cleanup.add(pbe);
cleanup.add(product);
cleanup.add(range);
cleanup.add(partner);
cleanup.add(customer);

for (Integer i = 0; i < cleanup.size(); i++) {
    try {
        delete cleanup[i];
    } catch (Exception e) {
        System.debug('Cleanup failed for record: ' + cleanup[i] + ' -> ' + e.getMessage());
    }
}
