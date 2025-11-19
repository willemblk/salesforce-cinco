// ===================================================================
// BTW DIAGNOSE SCRIPT - Check waarom BTW__c niet wordt gevuld
// ===================================================================

System.debug('=== 🔍 BTW DIAGNOSE START ===\n');

// STAP 1: Vind de meest recente Lead_Product__c records
List<Lead_Product__c> leadProducts = [
    SELECT Id, Name, 
           Product__c, Product__r.Name, Product__r.ProductCode, Product__r.BTW__c,
           Lead__c, Lead__r.Name, Lead__r.BTW_Toepasbaar__c,
           Aantal__c, 
           BTW__c,                    // ← Dit veld moet gevuld zijn
           Verkoopprijs__c, 
           Totale_Prijs__c, 
           Korting_bedrag__c,
           Totaal__c,                 // Formula: Totale_Prijs__c - Korting_bedrag__c
           BTW_Bedrag__c,             // Formula field
           Totaal_incl_BTW__c         // Formula field
    FROM Lead_Product__c 
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC 
    LIMIT 5
];

System.debug('📦 Found ' + leadProducts.size() + ' Lead_Product__c records created today\n');

if (leadProducts.isEmpty()) {
    System.debug('❌ No Lead_Product__c records found from today.');
    System.debug('Please create a Lead via WordPress first.\n');
} else {
    
    for (Lead_Product__c lp : leadProducts) {
        System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        System.debug('📋 Lead_Product__c: ' + lp.Name + ' (ID: ' + lp.Id + ')');
        System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        
        // Product info
        System.debug('🏷️  PRODUCT INFORMATION:');
        System.debug('   Product: ' + lp.Product__r.Name + ' (' + lp.Product__r.ProductCode + ')');
        System.debug('   Product2.BTW__c: ' + lp.Product__r.BTW__c + '%');
        
        // Lead info
        System.debug('\n👤 LEAD INFORMATION:');
        System.debug('   Lead: ' + lp.Lead__r.Name);
        System.debug('   Lead.BTW_Toepasbaar__c: ' + lp.Lead__r.BTW_Toepasbaar__c);
        
        // Lead_Product__c fields
        System.debug('\n💰 LEAD_PRODUCT FIELDS:');
        System.debug('   Aantal__c: ' + lp.Aantal__c);
        System.debug('   Verkoopprijs__c: €' + lp.Verkoopprijs__c);
        System.debug('   Totale_Prijs__c (bruto): €' + lp.Totale_Prijs__c);
        System.debug('   Korting_bedrag__c: €' + lp.Korting_bedrag__c);
        
        Decimal netto = (lp.Totale_Prijs__c != null ? lp.Totale_Prijs__c : 0) - 
                        (lp.Korting_bedrag__c != null ? lp.Korting_bedrag__c : 0);
        System.debug('   Totaal__c (netto): €' + lp.Totaal__c + ' (formula)');
        
        System.debug('\n🧮 BTW FIELDS:');
        System.debug('   Lead_Product__c.BTW__c: ' + lp.BTW__c + ' ← SHOULD BE ' + lp.Product__r.BTW__c);
        System.debug('   BTW_Bedrag__c: €' + lp.BTW_Bedrag__c + ' (formula)');
        System.debug('   Totaal_incl_BTW__c: €' + lp.Totaal_incl_BTW__c + ' (formula)');
        
        // ANALYSE
        System.debug('\n📊 ANALYSIS:');
        
        // Check 1: Is Lead_Product__c.BTW__c gevuld?
        if (lp.BTW__c == null || lp.BTW__c == 0) {
            System.debug('   ❌ PROBLEM: Lead_Product__c.BTW__c is NULL or 0!');
            System.debug('   ➡️  This field should be populated by FLOW from Product2.BTW__c');
        } else {
            System.debug('   ✅ Lead_Product__c.BTW__c is populated: ' + lp.BTW__c);
        }
        
        // Check 2: Is Lead.BTW_Toepasbaar__c = "Ja"?
        if (lp.Lead__r.BTW_Toepasbaar__c != 'Ja') {
            System.debug('   ⚠️  WARNING: Lead.BTW_Toepasbaar__c is NOT "Ja" (value: ' + lp.Lead__r.BTW_Toepasbaar__c + ')');
            System.debug('   ➡️  This might affect BTW calculation in formula fields');
        } else {
            System.debug('   ✅ Lead.BTW_Toepasbaar__c = "Ja"');
        }
        
        // Check 3: Verwachte BTW berekening
        if (lp.Product__r.BTW__c != null && netto > 0) {
            try {
                Decimal btwPercent = Decimal.valueOf(lp.Product__r.BTW__c); // Convert String to Decimal
                Decimal expectedBTW = netto * (btwPercent / 100);
                Decimal expectedTotal = netto + expectedBTW;
                
                System.debug('\n   📐 EXPECTED CALCULATION:');
                System.debug('      Netto: €' + netto.setScale(2));
                System.debug('      BTW (' + lp.Product__r.BTW__c + '%): €' + expectedBTW.setScale(2));
                System.debug('      Total incl BTW: €' + expectedTotal.setScale(2));
                
                System.debug('\n   🎯 ACTUAL VALUES:');
                System.debug('      BTW_Bedrag__c: €' + (lp.BTW_Bedrag__c != null ? lp.BTW_Bedrag__c : 0));
                System.debug('      Totaal_incl_BTW__c: €' + (lp.Totaal_incl_BTW__c != null ? lp.Totaal_incl_BTW__c : 0));
                
                // Vergelijk
                if (lp.BTW_Bedrag__c == null || lp.BTW_Bedrag__c == 0) {
                    System.debug('\n   ❌ BTW_Bedrag__c is NULL or 0 (should be €' + expectedBTW.setScale(2) + ')');
                } else if (Math.abs(lp.BTW_Bedrag__c - expectedBTW) > 0.01) {
                    System.debug('\n   ⚠️  BTW_Bedrag__c mismatch! Difference: €' + 
                               Math.abs(lp.BTW_Bedrag__c - expectedBTW).setScale(2));
                } else {
                    System.debug('\n   ✅ BTW_Bedrag__c is correct!');
                }
            } catch (Exception e) {
                System.debug('\n   ⚠️  Could not parse BTW__c: ' + e.getMessage());
            }
        }
        
        System.debug('\n');
    }
    
    // STAP 2: Check of Lead_Product__c.BTW__c een formula field is
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    System.debug('🔧 FIELD TYPE CHECK');
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    Schema.DescribeFieldResult fieldDescribe = Lead_Product__c.BTW__c.getDescribe();
    System.debug('Lead_Product__c.BTW__c field type: ' + fieldDescribe.getType());
    System.debug('Is calculated (formula): ' + fieldDescribe.isCalculated());
    System.debug('Is writable: ' + fieldDescribe.isUpdateable());
    
    if (fieldDescribe.isCalculated()) {
        System.debug('\n💡 INSIGHT: BTW__c is a FORMULA field!');
        System.debug('   This means it cannot be written to by PricingService.');
        System.debug('   The formula should reference Product2.BTW__c directly.');
    } else {
        System.debug('\n💡 INSIGHT: BTW__c is a WRITABLE field.');
        System.debug('   PricingService should populate this field in writeBackToSource().');
    }
    
    // STAP 3: Check PricingService trigger
    System.debug('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    System.debug('🔍 TRIGGER CHECK');
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    System.debug('Check if Lead_Product__c trigger is active:');
    System.debug('Setup → Apex Triggers → Search "Lead_Product" or "LeadProduct"');
    System.debug('Status must be: ACTIVE');
    
    // STAP 4: Manually trigger pricing voor test
    System.debug('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    System.debug('🧪 MANUAL PRICING TEST');
    System.debug('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
    
    if (!leadProducts.isEmpty()) {
        Lead_Product__c firstLp = leadProducts[0];
        System.debug('Manually triggering PricingService for Lead: ' + firstLp.Lead__c);
        
        // Reload alle products voor deze lead
        List<Lead_Product__c> allProductsForLead = [
            SELECT Id, Lead__c, Product__c, Aantal__c, Lengte_cm__c, Breedte_cm__c
            FROM Lead_Product__c
            WHERE Lead__c = :firstLp.Lead__c
        ];
        
        System.debug('Found ' + allProductsForLead.size() + ' products for this Lead');
        System.debug('Calling PricingService.reprice()...\n');
        
        try {
            List<SObject> repriced = PricingService.reprice(allProductsForLead);
            System.debug('✅ PricingService.reprice() completed successfully');
            System.debug('Returned ' + repriced.size() + ' records');
            
            // Check results
            Lead_Product__c updated = [
                SELECT BTW__c, BTW_Bedrag__c, Totaal_incl_BTW__c, Product__r.BTW__c
                FROM Lead_Product__c 
                WHERE Id = :firstLp.Id
            ];
            
            System.debug('\n📊 RESULTS AFTER MANUAL REPRICING:');
            System.debug('   Product2.BTW__c: ' + updated.Product__r.BTW__c + '%');
            System.debug('   Lead_Product__c.BTW__c: ' + updated.BTW__c);
            System.debug('   BTW_Bedrag__c: €' + updated.BTW_Bedrag__c);
            System.debug('   Totaal_incl_BTW__c: €' + updated.Totaal_incl_BTW__c);
            
            if (updated.BTW__c != null && updated.BTW__c > 0) {
                System.debug('\n   ✅ SUCCESS: BTW__c is now populated!');
            } else {
                System.debug('\n   ❌ STILL EMPTY: BTW__c is still null or 0');
                System.debug('   ➡️  Check if there is a Flow that should populate this field');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR calling PricingService: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
}

System.debug('\n=== 🏁 BTW DIAGNOSE COMPLETE ===');
