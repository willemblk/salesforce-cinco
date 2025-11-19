// Test Opportunity → Werk_Order__c photo copy
System.debug('========== TESTING OPP → WERK ORDER PHOTO COPY ==========');

// Find an Opportunity with photos
List<Opportunity> opps = [
    SELECT Id, Name, AccountId
    FROM Opportunity 
    WHERE Id IN (SELECT Opportunity__c FROM Foto__c)
    AND AccountId != NULL
    ORDER BY CreatedDate DESC
    LIMIT 1
];

if (opps.isEmpty()) {
    System.debug('❌ No Opportunities with photos found');
} else {
    Opportunity opp = opps[0];
    
    // Count photos separately
    Integer photoCount = [SELECT COUNT() FROM Foto__c WHERE Opportunity__c = :opp.Id];
    System.debug('✅ Found Opportunity: ' + opp.Name + ' with ' + photoCount + ' photos');
    
    // Create a simple Werk_Order__c for testing
    Werk_Order__c wo = new Werk_Order__c(
        Opportunity__c = opp.Id,
        Account__c = opp.AccountId
    );
    insert wo;
    System.debug('✅ Created Werk_Order__c: ' + wo.Id);
    
    // Now manually trigger the photo copy
    Map<Id, Id> oppToWo = new Map<Id, Id>();
    oppToWo.put(opp.Id, wo.Id);
    
    System.debug('\n💰 Calling PhotoCopyService.copyOpportunityPhotosToWerkOrders...');
    PhotoCopyService.copyOpportunityPhotosToWerkOrders(oppToWo);
    
    // Check results
    List<Foto__c> woPhotos = [
        SELECT Id, Name, Bron__c, Werk_Order1__c
        FROM Foto__c
        WHERE Werk_Order1__c = :wo.Id
    ];
    
    System.debug('\n✅ WERK ORDER HAS ' + woPhotos.size() + ' PHOTOS:');
    for (Foto__c f : woPhotos) {
        System.debug('  - ' + f.Id + ' | ' + f.Name + ' | Bron: ' + f.Bron__c);
    }
    
    // Check original photos
    List<Foto__c> oppPhotos = [
        SELECT Id, Name, Copied_Forward__c
        FROM Foto__c
        WHERE Opportunity__c = :opp.Id
        ORDER BY CreatedDate
    ];
    
    System.debug('\nORIGINAL OPP PHOTOS AFTER CONVERSION:');
    for (Foto__c f : oppPhotos) {
        System.debug('  - ' + f.Id + ' | Copied_Forward__c: ' + f.Copied_Forward__c + ' (should be true)');
    }
    
    // Cleanup
    delete wo;
    delete woPhotos;
}

System.debug('\n========== TEST COMPLETE ==========');
