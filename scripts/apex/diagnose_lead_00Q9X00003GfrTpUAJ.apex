// ===================================================================
// BTW DIAGNOSE voor Lead 00Q9X00003GfrTpUAJ
// ===================================================================

System.debug('=== 🔍 BTW DIAGNOSE voor specifieke Lead ===\n');

Id leadId = '00Q9X00003GfrTpUAJ';

// STAP 1: Check Lead
Lead lead = [
    SELECT Id, Name, PostalCode, BTW_Toepasbaar__c, Automatisch_aangemaakt__c
    FROM Lead 
    WHERE Id = :leadId
];

System.debug('📋 LEAD INFORMATION:');
System.debug('   Name: ' + lead.Name);
System.debug('   PostalCode: ' + lead.PostalCode);
System.debug('   BTW_Toepasbaar__c: ' + lead.BTW_Toepasbaar__c);
System.debug('   Automatisch_aangemaakt__c: ' + lead.Automatisch_aangemaakt__c);

// STAP 2: Check Lead_Product__c records
List<Lead_Product__c> leadProducts = [
    SELECT Id, Name, Product__c, Product__r.Name, Product__r.ProductCode, Product__r.BTW__c,
           Aantal__c, Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, Oppervlakte_m__c,
           Gerelateerd_Product__c,
           BTW__c, Verkoopprijs__c, Totale_Prijs__c, Korting_bedrag__c,
           BTW_Bedrag__c, Totaal_incl_BTW__c
    FROM Lead_Product__c 
    WHERE Lead__c = :leadId
    ORDER BY CreatedDate
];

System.debug('\n📦 Found ' + leadProducts.size() + ' Lead_Product__c records\n');

for (Lead_Product__c lp : leadProducts) {
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    System.debug('📋 ' + lp.Name);
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    System.debug('   Product: ' + lp.Product__r.Name);
    System.debug('   ProductCode: ' + lp.Product__r.ProductCode);
    System.debug('   Product2.BTW__c (source): ' + lp.Product__r.BTW__c);
    System.debug('');
    System.debug('   Aantal__c: ' + lp.Aantal__c);
    System.debug('   Lengte_cm__c: ' + lp.Lengte_cm__c);
    System.debug('   Breedte_cm__c: ' + lp.Breedte_cm__c);
    System.debug('   Diameter_cm__c: ' + lp.Diameter_cm__c);
    System.debug('   Oppervlakte_m__c: ' + lp.Oppervlakte_m__c);
    System.debug('   Gerelateerd_Product__c: ' + lp.Gerelateerd_Product__c);
    System.debug('');
    System.debug('   Verkoopprijs__c: €' + lp.Verkoopprijs__c);
    System.debug('   Totale_Prijs__c: €' + lp.Totale_Prijs__c);
    System.debug('   Korting_bedrag__c: €' + lp.Korting_bedrag__c);
    System.debug('');
    System.debug('   ⚠️  BTW__c: ' + lp.BTW__c + ' ← SHOULD BE ' + lp.Product__r.BTW__c);
    System.debug('   BTW_Bedrag__c: €' + lp.BTW_Bedrag__c);
    System.debug('   Totaal_incl_BTW__c: €' + lp.Totaal_incl_BTW__c);
    
    if (lp.BTW__c == null || lp.BTW__c == 0) {
        System.debug('   ❌ PROBLEM: BTW__c is NOT populated!');
    } else {
        System.debug('   ✅ BTW__c is populated');
    }
    System.debug('');
}

// STAP 3: Check of trigger bestaat en actief is
System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
System.debug('🔍 TRIGGER CHECK');
System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

// Query ApexTrigger metadata
List<ApexTrigger> triggers = [
    SELECT Id, Name, TableEnumOrId, Status, ApiVersion
    FROM ApexTrigger 
    WHERE TableEnumOrId = 'Lead_Product__c'
];

if (triggers.isEmpty()) {
    System.debug('❌ NO TRIGGER found for Lead_Product__c!');
    System.debug('   This is the problem - no trigger to call PricingService');
} else {
    for (ApexTrigger t : triggers) {
        System.debug('Trigger: ' + t.Name);
        System.debug('   Status: ' + t.Status);
        System.debug('   API Version: ' + t.ApiVersion);
        
        if (t.Status == 'Active') {
            System.debug('   ✅ Trigger is ACTIVE');
        } else {
            System.debug('   ❌ Trigger is INACTIVE!');
        }
    }
}

// STAP 4: Manually trigger repricing
System.debug('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
System.debug('🔄 MANUAL REPRICING TEST');
System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

System.debug('Calling PricingService.reprice() on ' + leadProducts.size() + ' products...');

try {
    PricingService.reprice(leadProducts);
    System.debug('✅ PricingService.reprice() completed');
    
    // Update to database
    update leadProducts;
    System.debug('✅ Database update completed');
    
    // Re-query to see results
    leadProducts = [
        SELECT Id, Name, Product__r.ProductCode, BTW__c, BTW_Bedrag__c, Totaal_incl_BTW__c
        FROM Lead_Product__c 
        WHERE Lead__c = :leadId
    ];
    
    System.debug('\n📊 RESULTS AFTER MANUAL REPRICING:');
    for (Lead_Product__c lp : leadProducts) {
        System.debug('   ' + lp.Product__r.ProductCode + ':');
        System.debug('      BTW__c: ' + lp.BTW__c);
        System.debug('      BTW_Bedrag__c: €' + lp.BTW_Bedrag__c);
        System.debug('      Totaal_incl_BTW__c: €' + lp.Totaal_incl_BTW__c);
        
        if (lp.BTW__c != null && lp.BTW__c > 0) {
            System.debug('      ✅ SUCCESS!');
        } else {
            System.debug('      ❌ STILL NOT WORKING');
        }
    }
    
} catch (Exception e) {
    System.debug('❌ ERROR: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

System.debug('\n=== 🏁 DIAGNOSE COMPLETE ===');
