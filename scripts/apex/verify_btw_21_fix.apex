// ===================================================================
// BTW FIX VERIFICATION - Test dat BTW__c nu 21 is (niet 0.21)
// ===================================================================

System.debug('=== 🧪 BTW FIX VERIFICATION (21 vs 0.21) ===\n');

Id leadId = '00Q9X00003GfrTpUAJ';

// STAP 1: Check huidige staat
List<Lead_Product__c> leadProducts = [
    SELECT Id, Name, Product__r.ProductCode, Product__r.BTW__c,
           BTW__c, Totale_Prijs__c, BTW_Bedrag__c, Totaal_incl_BTW__c,
           Aantal__c, Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, 
           Oppervlakte_m__c, Gerelateerd_Product__c, Lead__c
    FROM Lead_Product__c 
    WHERE Lead__c = :leadId
];

System.debug('📦 Found ' + leadProducts.size() + ' Lead_Product__c records\n');

System.debug('BEFORE REPRICING:');
for (Lead_Product__c lp : leadProducts) {
    System.debug('   ' + lp.Product__r.ProductCode);
    System.debug('      Product2.BTW__c (source): ' + lp.Product__r.BTW__c);
    System.debug('      Lead_Product__c.BTW__c: ' + lp.BTW__c + ' ← Should be 21');
    System.debug('      BTW_Bedrag__c: €' + lp.BTW_Bedrag__c);
    System.debug('      Totaal_incl_BTW__c: €' + lp.Totaal_incl_BTW__c);
    System.debug('');
}

// STAP 2: Trigger repricing
System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
System.debug('🔄 Calling PricingService.reprice()...');
System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

try {
    PricingService.reprice(leadProducts);
    System.debug('✅ PricingService.reprice() completed');
    
    // Update to database
    update leadProducts;
    System.debug('✅ Database update completed\n');
    
    // Re-query to see results
    leadProducts = [
        SELECT Id, Name, Product__r.ProductCode, 
               BTW__c, Totale_Prijs__c, BTW_Bedrag__c, Totaal_incl_BTW__c
        FROM Lead_Product__c 
        WHERE Lead__c = :leadId
    ];
    
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    System.debug('📊 AFTER REPRICING:');
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    Boolean allCorrect = true;
    
    for (Lead_Product__c lp : leadProducts) {
        System.debug('   ' + lp.Product__r.ProductCode);
        System.debug('      BTW__c: ' + lp.BTW__c);
        System.debug('      BTW_Bedrag__c: €' + lp.BTW_Bedrag__c);
        System.debug('      Totaal_incl_BTW__c: €' + lp.Totaal_incl_BTW__c);
        
        // Verify BTW__c is 21 (not 0.21 or 0)
        if (lp.BTW__c == 21) {
            System.debug('      ✅ SUCCESS: BTW__c = 21');
        } else if (lp.BTW__c == 0.21) {
            System.debug('      ⚠️  OLD VALUE: BTW__c = 0.21 (should be 21)');
            allCorrect = false;
        } else if (lp.BTW__c == null || lp.BTW__c == 0) {
            System.debug('      ❌ FAIL: BTW__c is null or 0');
            allCorrect = false;
        } else {
            System.debug('      ⚠️  UNEXPECTED: BTW__c = ' + lp.BTW__c);
            allCorrect = false;
        }
        
        // Verify BTW_Bedrag__c is calculated
        if (lp.BTW_Bedrag__c != null && lp.BTW_Bedrag__c > 0) {
            Decimal expectedBTW = lp.Totale_Prijs__c * 0.21; // 21%
            System.debug('      Expected BTW_Bedrag__c: €' + expectedBTW.setScale(2));
            
            if (Math.abs(lp.BTW_Bedrag__c - expectedBTW) < 0.01) {
                System.debug('      ✅ BTW_Bedrag__c is correct!');
            } else {
                System.debug('      ⚠️  BTW_Bedrag__c mismatch (diff: €' + 
                           Math.abs(lp.BTW_Bedrag__c - expectedBTW).setScale(2) + ')');
            }
        } else {
            System.debug('      ❌ BTW_Bedrag__c is null or 0');
            allCorrect = false;
        }
        
        System.debug('');
    }
    
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    if (allCorrect) {
        System.debug('🎉 SUCCESS: All BTW fields are correct!');
    } else {
        System.debug('⚠️  Some fields need attention');
    }
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
} catch (Exception e) {
    System.debug('❌ ERROR: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

System.debug('\n=== 🏁 VERIFICATION COMPLETE ===');
