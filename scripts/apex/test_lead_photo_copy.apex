// Test fotokopie met een echte Lead conversie en volledige logging

System.debug('\n========== TEST LEAD PHOTO COPY START ==========\n');

// Stap 1: Vind een recente Lead met foto's
Lead testLead = [
    SELECT Id, Email, LastName, Company, Status
    FROM Lead
    WHERE IsConverted = false
    ORDER BY CreatedDate DESC
    LIMIT 1
];

System.debug('Found test Lead: ' + testLead.Id + ' | ' + testLead.LastName + ' | ' + testLead.Email);

// Check foto's op deze Lead
List<Foto__c> leadPhotos = [
    SELECT Id, Name, Lead__c, URL__c, Copied_Forward__c
    FROM Foto__c
    WHERE Lead__c = :testLead.Id
];
System.debug('Lead has ' + leadPhotos.size() + ' photos:');
for (Foto__c f : leadPhotos) {
    System.debug('  - ' + f.Id + ' | ' + f.Name + ' | Copied_Forward__c: ' + f.Copied_Forward__c);
}

if (leadPhotos.isEmpty()) {
    System.debug('\n⚠️ NO PHOTOS ON LEAD - creating test photos first...');
    
    Foto__c testPhoto1 = new Foto__c(
        Lead__c = testLead.Id,
        Name = 'Test Foto 1',
        URL__c = 'https://example.com/photo1.jpg',
        Beschrijving__c = 'Test foto voor lead',
        Is_Public__c = true
        // Deliberately NOT setting Copied_Forward__c to test NULL behavior
    );
    insert testPhoto1;
    System.debug('Created test photo: ' + testPhoto1.Id);
    
    // Verify it was created with NULL
    testPhoto1 = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE Id = :testPhoto1.Id];
    System.debug('New photo Copied_Forward__c value: ' + testPhoto1.Copied_Forward__c);
    
    leadPhotos = new List<Foto__c>{ testPhoto1 };
}

// Check Lead_Product__c en foto's daarop
List<Lead_Product__c> leadProducts = [
    SELECT Id, Product__c, Lead__c
    FROM Lead_Product__c
    WHERE Lead__c = :testLead.Id
];
System.debug('\nLead has ' + leadProducts.size() + ' Lead Products');

if (!leadProducts.isEmpty()) {
    Set<Id> lpIds = new Set<Id>();
    for (Lead_Product__c lp : leadProducts) {
        lpIds.add(lp.Id);
    }
    List<Foto__c> lpPhotos = [
        SELECT Id, Name, Lead_Product__c, Copied_Forward__c
        FROM Foto__c
        WHERE Lead_Product__c IN :lpIds
    ];
    System.debug('Lead Products have ' + lpPhotos.size() + ' photos total:');
    for (Foto__c f : lpPhotos) {
        System.debug('  - ' + f.Id + ' | LP: ' + f.Lead_Product__c + ' | Copied_Forward__c: ' + f.Copied_Forward__c);
    }
    
    if (lpPhotos.isEmpty() && !leadProducts.isEmpty()) {
        System.debug('\n⚠️ NO PHOTOS ON LEAD PRODUCTS - creating test photo...');
        Foto__c testLpPhoto = new Foto__c(
            Lead_Product__c = leadProducts[0].Id,
            Name = 'Test LP Foto',
            URL__c = 'https://example.com/lp-photo.jpg',
            Beschrijving__c = 'Test foto voor lead product'
        );
        insert testLpPhoto;
        System.debug('Created test LP photo: ' + testLpPhoto.Id);
    }
}

// Stap 2: Converteer de Lead via LeadToOpportunityConverter
System.debug('\n--- Starting Lead Conversion ---');

LeadToOpportunityConverter.Request req = new LeadToOpportunityConverter.Request();
req.leadId = testLead.Id;

List<LeadToOpportunityConverter.Response> responses = LeadToOpportunityConverter.convert(
    new List<LeadToOpportunityConverter.Request>{ req }
);

System.debug('\n--- Conversion Complete ---');
LeadToOpportunityConverter.Response resp = responses[0];
System.debug('Success: ' + resp.success);
System.debug('Message: ' + resp.message);
System.debug('Opportunity ID: ' + resp.opportunityId);
System.debug('OLI IDs: ' + resp.opportunityLineItemIds);

if (resp.success && resp.opportunityId != null) {
    // Check foto's op de nieuwe Opportunity
    List<Foto__c> oppPhotos = [
        SELECT Id, Name, Opportunity__c, Bron__c, Copied_Forward__c
        FROM Foto__c
        WHERE Opportunity__c = :resp.opportunityId
    ];
    System.debug('\n✅ NEW OPPORTUNITY HAS ' + oppPhotos.size() + ' PHOTOS:');
    for (Foto__c f : oppPhotos) {
        System.debug('  - ' + f.Id + ' | ' + f.Name + ' | Bron: ' + f.Bron__c);
    }
    
    // Check of originele foto's zijn gemarkeerd
    leadPhotos = [
        SELECT Id, Copied_Forward__c
        FROM Foto__c
        WHERE Id IN :leadPhotos
    ];
    System.debug('\nORIGINAL LEAD PHOTOS AFTER CONVERSION:');
    for (Foto__c f : leadPhotos) {
        System.debug('  - ' + f.Id + ' | Copied_Forward__c: ' + f.Copied_Forward__c + ' (should be true)');
    }
    
    // Check OLI foto's
    if (!resp.opportunityLineItemIds.isEmpty()) {
        List<Foto__c> oliPhotos = [
            SELECT Id, Name, OpportunityLineItem__c, Bron__c
            FROM Foto__c
            WHERE OpportunityLineItem__c IN :resp.opportunityLineItemIds
        ];
        System.debug('\n✅ OPPORTUNITY LINE ITEMS HAVE ' + oliPhotos.size() + ' PHOTOS:');
        for (Foto__c f : oliPhotos) {
            System.debug('  - ' + f.Id + ' | OLI: ' + f.OpportunityLineItem__c + ' | Bron: ' + f.Bron__c);
        }
    }
} else {
    System.debug('\n❌ CONVERSION FAILED - cannot check photos');
}

System.debug('\n========== TEST COMPLETE ==========\n');
