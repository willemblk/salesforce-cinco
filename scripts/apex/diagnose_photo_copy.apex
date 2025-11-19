// Diagnose fotokopie-keten: check of foto's bestaan en worden gevonden door queries

// 1. Check of er foto's zijn op Lead/Lead_Product
System.debug('=== STAP 1: Check bestaande Foto__c records ===');

List<Foto__c> allLeadPhotos = [
    SELECT Id, Name, Lead__c, Lead_Product__c, Copied_Forward__c, URL__c, Beschrijving__c
    FROM Foto__c
    WHERE Lead__c != null OR Lead_Product__c != null
    ORDER BY CreatedDate DESC
    LIMIT 10
];

System.debug('Total Lead/LeadProduct photos found: ' + allLeadPhotos.size());
for (Foto__c f : allLeadPhotos) {
    System.debug('  - ' + f.Id + ' | Lead: ' + f.Lead__c + ' | LP: ' + f.Lead_Product__c + 
                 ' | Copied_Forward__c: ' + f.Copied_Forward__c + ' | URL: ' + f.URL__c);
}

// 2. Test de nieuwe SOQL filter (= false OR = NULL)
System.debug('\n=== STAP 2: Test nieuwe SOQL filter ===');
Set<Id> leadIds = new Set<Id>();
for (Foto__c f : allLeadPhotos) {
    if (f.Lead__c != null) leadIds.add(f.Lead__c);
}

if (!leadIds.isEmpty()) {
    List<Foto__c> matchingPhotos = [
        SELECT Id, Name, Lead__c, Copied_Forward__c
        FROM Foto__c
        WHERE Lead__c IN :leadIds
        AND (Copied_Forward__c = false OR Copied_Forward__c = NULL)
    ];
    System.debug('Photos matching NEW filter (= false OR = NULL): ' + matchingPhotos.size());
    for (Foto__c f : matchingPhotos) {
        System.debug('  - ' + f.Id + ' | Copied_Forward__c: ' + f.Copied_Forward__c);
    }
} else {
    System.debug('No Lead IDs found to test filter');
}

// 3. Test de oude SOQL filter (!= true) voor vergelijking
System.debug('\n=== STAP 3: Test oude SOQL filter (voor vergelijking) ===');
if (!leadIds.isEmpty()) {
    List<Foto__c> oldFilterPhotos = [
        SELECT Id, Name, Lead__c, Copied_Forward__c
        FROM Foto__c
        WHERE Lead__c IN :leadIds
        AND Copied_Forward__c != true
    ];
    System.debug('Photos matching OLD filter (!= true): ' + oldFilterPhotos.size());
    for (Foto__c f : oldFilterPhotos) {
        System.debug('  - ' + f.Id + ' | Copied_Forward__c: ' + f.Copied_Forward__c);
    }
}

// 4. Check of er recent geconverteerde Opportunities zijn
System.debug('\n=== STAP 4: Check recent geconverteerde Opportunities ===');
List<Opportunity> recentOpps = [
    SELECT Id, Name, (SELECT Id FROM OpportunityLineItems LIMIT 5)
    FROM Opportunity
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 5
];
System.debug('Recent opportunities today: ' + recentOpps.size());
for (Opportunity o : recentOpps) {
    System.debug('  - ' + o.Id + ' | ' + o.Name + ' | OLIs: ' + o.OpportunityLineItems.size());
    
    // Check foto's op deze Opp
    Integer photoCount = [SELECT COUNT() FROM Foto__c WHERE Opportunity__c = :o.Id];
    System.debug('    Photos on Opp: ' + photoCount);
    
    // Check foto's op OLIs
    for (OpportunityLineItem oli : o.OpportunityLineItems) {
        Integer oliPhotoCount = [SELECT COUNT() FROM Foto__c WHERE OpportunityLineItem__c = :oli.Id];
        System.debug('    Photos on OLI ' + oli.Id + ': ' + oliPhotoCount);
    }
}

// 5. Check Foto__c field describe voor default value
System.debug('\n=== STAP 5: Check Foto__c.Copied_Forward__c field metadata ===');
Schema.DescribeFieldResult fieldDescribe = Foto__c.Copied_Forward__c.getDescribe();
System.debug('Field: ' + fieldDescribe.getName());
System.debug('Type: ' + fieldDescribe.getType());
System.debug('Default value: ' + fieldDescribe.getDefaultValue());
System.debug('Is nillable: ' + fieldDescribe.isNillable());

System.debug('\n=== DIAGNOSE COMPLETE ===');
