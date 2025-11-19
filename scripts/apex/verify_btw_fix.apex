// ===================================================================
// BTW FIX VERIFICATION - Test dat BTW__c nu wordt gevuld
// ===================================================================

System.debug('=== 🧪 BTW FIX VERIFICATION START ===\n');

// STAP 1: Vind een Lead_Product__c zonder BTW__c
Lead_Product__c testRecord = [
    SELECT Id, Lead__c, Product__c, Product__r.BTW__c, BTW__c, Aantal__c, 
           Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, Oppervlakte_m__c,
           Gerelateerd_Product__c,
           Totale_Prijs__c, BTW_Bedrag__c, Totaal_incl_BTW__c
    FROM Lead_Product__c 
    WHERE BTW__c = null 
      AND CreatedDate = TODAY
    LIMIT 1
];

System.debug('📋 Test Record: ' + testRecord.Id);
System.debug('   Product2.BTW__c: ' + testRecord.Product__r.BTW__c);
System.debug('   Lead_Product__c.BTW__c (BEFORE): ' + testRecord.BTW__c);
System.debug('   BTW_Bedrag__c (BEFORE): €' + testRecord.BTW_Bedrag__c);
System.debug('   Totaal_incl_BTW__c (BEFORE): €' + testRecord.Totaal_incl_BTW__c);

// STAP 2: Manually trigger PricingService
System.debug('\n🔄 Manually triggering PricingService.reprice()...');

List<Lead_Product__c> records = new List<Lead_Product__c>{ testRecord };
PricingService.reprice(records);

System.debug('✅ PricingService.reprice() completed');

// IMPORTANT: reprice() updates in-memory, but doesn't UPDATE to database
// We need to manually update for this test
System.debug('💾 Updating record to database...');
update records;
System.debug('✅ Database update completed');

// STAP 3: Query de record opnieuw om de updates te zien
Lead_Product__c updated = [
    SELECT BTW__c, BTW_Bedrag__c, Totaal_incl_BTW__c, Product__r.BTW__c, Totale_Prijs__c, Korting_bedrag__c
    FROM Lead_Product__c 
    WHERE Id = :testRecord.Id
];

System.debug('\n📊 AFTER REPRICING:');
System.debug('   Product2.BTW__c: ' + updated.Product__r.BTW__c + ' (String)');
System.debug('   Lead_Product__c.BTW__c: ' + updated.BTW__c + ' (Percent/Decimal)');
System.debug('   BTW_Bedrag__c: €' + updated.BTW_Bedrag__c);
System.debug('   Totaal_incl_BTW__c: €' + updated.Totaal_incl_BTW__c);

// STAP 4: Verify berekening
Decimal netto = (updated.Totale_Prijs__c != null ? updated.Totale_Prijs__c : 0) - 
                (updated.Korting_bedrag__c != null ? updated.Korting_bedrag__c : 0);

if (updated.BTW__c != null && updated.BTW__c > 0) {
    Decimal expectedBTW = netto * updated.BTW__c; // BTW__c is already 0.21 (21%)
    Decimal expectedTotal = netto + expectedBTW;
    
    System.debug('\n📐 VERIFICATION:');
    System.debug('   Netto: €' + netto.setScale(2));
    System.debug('   Expected BTW (' + (updated.BTW__c * 100).setScale(0) + '%): €' + expectedBTW.setScale(2));
    System.debug('   Expected Total incl BTW: €' + expectedTotal.setScale(2));
    System.debug('   Actual BTW_Bedrag__c: €' + updated.BTW_Bedrag__c);
    System.debug('   Actual Totaal_incl_BTW__c: €' + updated.Totaal_incl_BTW__c);
    
    if (Math.abs(updated.BTW_Bedrag__c - expectedBTW) < 0.01) {
        System.debug('\n✅ SUCCESS: BTW__c is correctly populated!');
        System.debug('✅ Formula fields are calculating correctly!');
    } else {
        System.debug('\n⚠️  WARNING: BTW_Bedrag__c mismatch!');
        System.debug('   Difference: €' + Math.abs(updated.BTW_Bedrag__c - expectedBTW).setScale(2));
    }
} else {
    System.debug('\n❌ FAIL: BTW__c is still NULL or 0');
    System.debug('   Check if Product2.BTW__c is populated');
}

System.debug('\n=== 🏁 BTW FIX VERIFICATION COMPLETE ===');
