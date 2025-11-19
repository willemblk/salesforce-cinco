// Check if formula calculation works after explicit recalc
System.debug('=== TESTING FORMULA RECALCULATION ===\n');

// Get one record with BTW = 0
Lead_Product__c testRecord = [
    SELECT Id, Product__r.ProductCode, Product__r.BTW__c,
           Aantal__c, Verkoopprijs__c, Totale_Prijs__c, 
           Korting_bedrag__c, Totaal__c, 
           BTW_Bedrag__c, Totaal_incl_BTW__c
    FROM Lead_Product__c
    WHERE CreatedDate = TODAY
      AND BTW_Bedrag__c = 0
    LIMIT 1
];

System.debug('📊 BEFORE UPDATE:');
System.debug('  Product: ' + testRecord.Product__r.ProductCode);
System.debug('  Product__r.BTW__c: ' + testRecord.Product__r.BTW__c + '%');
System.debug('  Totale_Prijs__c: €' + testRecord.Totale_Prijs__c);
System.debug('  Totaal__c: €' + testRecord.Totaal__c);
System.debug('  BTW_Bedrag__c: €' + testRecord.BTW_Bedrag__c);
System.debug('  Totaal_incl_BTW__c: €' + testRecord.Totaal_incl_BTW__c);

// Touch the record to force formula recalculation
System.debug('\n🔄 Updating record to trigger formula recalc...');
testRecord.Aantal__c = testRecord.Aantal__c; // No change, just touch
update testRecord;

// Re-query to see if formula updated
testRecord = [
    SELECT Id, Product__r.ProductCode, Product__r.BTW__c,
           Totaal__c, BTW_Bedrag__c, Totaal_incl_BTW__c
    FROM Lead_Product__c
    WHERE Id = :testRecord.Id
];

System.debug('\n📊 AFTER UPDATE:');
System.debug('  Totaal__c: €' + testRecord.Totaal__c);
System.debug('  BTW_Bedrag__c: €' + testRecord.BTW_Bedrag__c);
System.debug('  Totaal_incl_BTW__c: €' + testRecord.Totaal_incl_BTW__c);

if (testRecord.BTW_Bedrag__c > 0) {
    System.debug('\n✅ SUCCESS: BTW formula now works after update!');
    System.debug('   → Formula depends on fields that weren\'t set initially');
} else {
    System.debug('\n❌ STILL BROKEN: BTW formula still returns 0');
    System.debug('   → Formula itself might be incorrectly configured');
}

System.debug('\n=== CHECKING FORMULA SYNTAX ===');
System.debug('Expected formula for BTW_Bedrag__c:');
System.debug('  Totaal__c * (VALUE(Product__r.BTW__c) / 100)');
System.debug('');
System.debug('Expected formula for Totaal__c:');
System.debug('  Totale_Prijs__c - Korting_bedrag__c');
System.debug('  OR');
System.debug('  IF(ISBLANK(Korting_bedrag__c), Totale_Prijs__c, Totale_Prijs__c - Korting_bedrag__c)');
System.debug('');
System.debug('⚠️  If Product__r.BTW__c is a String field (as we discovered),');
System.debug('   the formula MUST use VALUE() to convert to number!');
System.debug('');
System.debug('Check in Setup > Object Manager > Lead_Product__c > Fields > BTW_Bedrag__c');
System.debug('View the actual formula and compare with expected formula above.');

System.debug('\n=== END TEST ===');
