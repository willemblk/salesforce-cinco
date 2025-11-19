Pricebook2 standardBook = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
if (!standardBook.IsActive) {
    standardBook.IsActive = true;
    update standardBook;
}

Product2 primaryProduct = new Product2(
    Name = 'Primary Script Product',
    ProductCode = 'PRIM-SCRIPT',
    IsActive = true,
    Segment__c = 'SR'
);
insert primaryProduct;

PricebookEntry primaryEntry = new PricebookEntry(
    Pricebook2Id = standardBook.Id,
    Product2Id = primaryProduct.Id,
    UnitPrice = 100,
    IsActive = true
);
insert primaryEntry;

LeadStatus openStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false LIMIT 1];
Lead leadRecord = new Lead(
    FirstName = 'Manual',
    LastName = 'Test',
    Company = 'Manual Co',
    Status = openStatus.MasterLabel
);
insert leadRecord;

Lead_Product__c primaryLeadProduct = new Lead_Product__c(
    Lead__c = leadRecord.Id,
    Product__c = primaryProduct.Id,
    Aantal__c = 2,
    Totale_Prijs__c = 200,
    Bijzonderheden__c = 'Manual hoofd'
);
insert primaryLeadProduct;

LeadToOpportunityConverter.Request request = new LeadToOpportunityConverter.Request();
request.leadId = leadRecord.Id;

List<LeadToOpportunityConverter.Response> responses = LeadToOpportunityConverter.convert(new List<LeadToOpportunityConverter.Request>{ request });
System.debug(responses);

OpportunityLineItem[] lines = [SELECT Quantity, UnitPrice, TotalPrice, PricebookEntry.UnitPrice FROM OpportunityLineItem WHERE OpportunityId = :responses[0].opportunityId];
for (OpportunityLineItem line : lines) {
    System.debug('OLI -> Qty=' + line.Quantity + ' Unit=' + line.UnitPrice + ' Total=' + line.TotalPrice + ' EntryUnit=' + line.PricebookEntry.UnitPrice);
}
