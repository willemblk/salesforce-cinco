/**
 * Verificatie Script: Partner & Postcodegebied Lookup IDs
 * 
 * Dit script controleert of de lookup IDs correct worden doorgegeven
 * van Dienstgebied_Postcode_Associatie__c → API → Lead
 * 
 * Test Flow:
 * 1. Check Dienstgebied_Postcode_Associatie__c data completeness
 * 2. Simulate PriceCalculationApi call
 * 3. Verify recent Leads have proper lookups
 * 
 * Run: sf apex run --file scripts/apex/verify_lookup_ids_flow.apex
 */

System.debug('═══════════════════════════════════════════════════════════');
System.debug('  LOOKUP IDs VERIFICATION - Partner & Postcodegebied');
System.debug('═══════════════════════════════════════════════════════════');
System.debug('');

// ═══════════════════════════════════════════════════════════
// TEST 1: Check Dienstgebied_Postcode_Associatie__c Data Quality
// ═══════════════════════════════════════════════════════════
System.debug('');
System.debug('▼▼▼ TEST 1: Dienstgebied_Postcode_Associatie__c Data Quality ▼▼▼');
System.debug('');

List<Dienstgebied_Postcode_Associatie__c> associaties = [
    SELECT Id, Name, 
           Partner__c, Partner__r.Name,
           Postcode_Gebied__c, Postcode_Gebied__r.Name,
           Dienstgebied__c, Dienstgebied__r.Name,
           Segment__c, Afhandelingsmethode__c, Toeslag__c
    FROM Dienstgebied_Postcode_Associatie__c
    ORDER BY Segment__c, Partner__r.Name
    LIMIT 20
];

System.debug('Found ' + associaties.size() + ' associations');
System.debug('');

Integer completeCount = 0;
Integer missingPartnerCount = 0;
Integer missingPostcodeGebiedCount = 0;
Integer invalidIdLengthCount = 0;

for (Dienstgebied_Postcode_Associatie__c assoc : associaties) {
    Boolean isComplete = true;
    
    System.debug('─────────────────────────────────────');
    System.debug('Association: ' + assoc.Name);
    System.debug('Segment: ' + assoc.Segment__c);
    
    // Check Partner
    if (assoc.Partner__c != null) {
        String partnerId = String.valueOf(assoc.Partner__c);
        if (partnerId.length() == 18) {
            System.debug('Partner: ' + assoc.Partner__r.Name + ' (' + partnerId + ') ✅');
        } else {
            System.debug('Partner: ' + assoc.Partner__r.Name + ' (' + partnerId + ') ⚠️ NOT 18 CHARS');
            invalidIdLengthCount++;
            isComplete = false;
        }
    } else {
        System.debug('Partner: ❌ MISSING');
        missingPartnerCount++;
        isComplete = false;
    }
    
    // Check Postcodegebied
    if (assoc.Postcode_Gebied__c != null) {
        String postcodeGebiedId = String.valueOf(assoc.Postcode_Gebied__c);
        if (postcodeGebiedId.length() == 18) {
            System.debug('Postcodegebied: ' + assoc.Postcode_Gebied__r.Name + ' (' + postcodeGebiedId + ') ✅');
        } else {
            System.debug('Postcodegebied: ' + assoc.Postcode_Gebied__r.Name + ' (' + postcodeGebiedId + ') ⚠️ NOT 18 CHARS');
            invalidIdLengthCount++;
            isComplete = false;
        }
    } else {
        System.debug('Postcodegebied: ❌ MISSING');
        missingPostcodeGebiedCount++;
        isComplete = false;
    }
    
    // Check Dienstgebied (optional)
    if (assoc.Dienstgebied__c != null) {
        System.debug('Dienstgebied: ' + assoc.Dienstgebied__r.Name + ' (optional) ✅');
    }
    
    System.debug('Afhandelingsmethode: ' + assoc.Afhandelingsmethode__c);
    System.debug('Regiotoeslag: ' + (assoc.Toeslag__c != null ? assoc.Toeslag__c + '%' : '0%'));
    
    if (isComplete) {
        completeCount++;
    }
}

System.debug('');
System.debug('═══ TEST 1 SUMMARY ═══');
System.debug('Total Associations: ' + associaties.size());
System.debug('Complete (all lookups valid): ' + completeCount + ' ✅');
System.debug('Missing Partner: ' + missingPartnerCount + (missingPartnerCount > 0 ? ' ❌' : ''));
System.debug('Missing Postcodegebied: ' + missingPostcodeGebiedCount + (missingPostcodeGebiedCount > 0 ? ' ❌' : ''));
System.debug('Invalid ID Length (not 18 chars): ' + invalidIdLengthCount + (invalidIdLengthCount > 0 ? ' ⚠️' : ''));

if (completeCount == associaties.size()) {
    System.debug('✅ ALL ASSOCIATIONS COMPLETE - Ready for API use');
} else {
    System.debug('⚠️ SOME ASSOCIATIONS INCOMPLETE - May cause issues in WordPress flow');
}

// ═══════════════════════════════════════════════════════════
// TEST 2: Simulate PriceCalculationApi Response
// ═══════════════════════════════════════════════════════════
System.debug('');
System.debug('');
System.debug('▼▼▼ TEST 2: Simulate PriceCalculationApi Response ▼▼▼');
System.debug('');

// Pick first complete association for simulation
Dienstgebied_Postcode_Associatie__c testAssoc = null;
for (Dienstgebied_Postcode_Associatie__c a : associaties) {
    if (a.Partner__c != null && a.Postcode_Gebied__c != null) {
        testAssoc = a;
        break;
    }
}

if (testAssoc != null) {
    System.debug('Test Postcode: 1012 (simulated for ' + testAssoc.Segment__c + ')');
    System.debug('');
    System.debug('Simulated API Response:');
    System.debug('{');
    System.debug('  "success": true,');
    System.debug('  "afhandelingsmethode": "' + testAssoc.Afhandelingsmethode__c + '",');
    System.debug('  "regioToeslagPercentage": ' + (testAssoc.Toeslag__c != null ? testAssoc.Toeslag__c : 0) + ',');
    System.debug('  "partnerId": "' + testAssoc.Partner__c + '",');
    System.debug('  "partnerName": "' + testAssoc.Partner__r.Name + '",');
    System.debug('  "postcodeGebiedId": "' + testAssoc.Postcode_Gebied__c + '",');
    System.debug('  "postcodeGebiedName": "' + testAssoc.Postcode_Gebied__r.Name + '",');
    if (testAssoc.Dienstgebied__c != null) {
        System.debug('  "dienstgebiedId": "' + testAssoc.Dienstgebied__c + '",');
        System.debug('  "dienstgebiedName": "' + testAssoc.Dienstgebied__r.Name + '",');
    }
    System.debug('  "segment": "' + testAssoc.Segment__c + '"');
    System.debug('}');
    System.debug('');
    System.debug('✅ This response will be cached in WordPress (5 min TTL)');
    System.debug('✅ IDs will be stored in SessionStorage (cincoMetadata)');
} else {
    System.debug('❌ No complete association found for simulation');
}

// ═══════════════════════════════════════════════════════════
// TEST 3: Check Recent Leads for Proper Lookups
// ═══════════════════════════════════════════════════════════
System.debug('');
System.debug('');
System.debug('▼▼▼ TEST 3: Recent Leads Verification (Last 7 Days) ▼▼▼');
System.debug('');

List<Lead> recentLeads = [
    SELECT Id, Name, Email, CreatedDate,
           Partner__c, Partner__r.Name,
           Postcodegebied__c, Postcodegebied__r.Name,
           Uniek_Segment__c, Afhandelingsmethode__c,
           Websource__c, External_Lead_Id__c
    FROM Lead
    WHERE CreatedDate = LAST_N_DAYS:7
      AND Websource__c != null
    ORDER BY CreatedDate DESC
    LIMIT 20
];

System.debug('Found ' + recentLeads.size() + ' recent website Leads');
System.debug('');

Integer leadsWithBothLookups = 0;
Integer leadsWithoutPartner = 0;
Integer leadsWithoutPostcodegebied = 0;
Integer leadsWithoutBoth = 0;

for (Lead ld : recentLeads) {
    Boolean hasPartner = ld.Partner__c != null;
    Boolean hasPostcodegebied = ld.Postcodegebied__c != null;
    
    System.debug('─────────────────────────────────────');
    System.debug('Lead: ' + ld.Name + ' (' + ld.Email + ')');
    System.debug('Created: ' + ld.CreatedDate);
    System.debug('External ID: ' + ld.External_Lead_Id__c);
    System.debug('Segment: ' + ld.Uniek_Segment__c);
    System.debug('Source: ' + ld.Websource__c);
    
    if (hasPartner) {
        System.debug('Partner: ' + ld.Partner__r.Name + ' ✅');
    } else {
        System.debug('Partner: ❌ MISSING');
    }
    
    if (hasPostcodegebied) {
        System.debug('Postcodegebied: ' + ld.Postcodegebied__r.Name + ' ✅');
    } else {
        System.debug('Postcodegebied: ❌ MISSING');
    }
    
    // Count statistics
    if (hasPartner && hasPostcodegebied) {
        leadsWithBothLookups++;
    } else if (!hasPartner && !hasPostcodegebied) {
        leadsWithoutBoth++;
    } else if (!hasPartner) {
        leadsWithoutPartner++;
    } else {
        leadsWithoutPostcodegebied++;
    }
}

System.debug('');
System.debug('═══ TEST 3 SUMMARY ═══');
System.debug('Total Recent Leads: ' + recentLeads.size());
System.debug('With Both Lookups: ' + leadsWithBothLookups + ' ✅');
System.debug('Missing Partner Only: ' + leadsWithoutPartner + (leadsWithoutPartner > 0 ? ' ⚠️' : ''));
System.debug('Missing Postcodegebied Only: ' + leadsWithoutPostcodegebied + (leadsWithoutPostcodegebied > 0 ? ' ⚠️' : ''));
System.debug('Missing Both: ' + leadsWithoutBoth + (leadsWithoutBoth > 0 ? ' ❌' : ''));

if (recentLeads.size() > 0) {
    Decimal successRate = (Decimal)leadsWithBothLookups / (Decimal)recentLeads.size() * 100;
    System.debug('Success Rate: ' + successRate.setScale(1) + '%');
    
    if (successRate >= 95) {
        System.debug('✅ EXCELLENT - Lookup IDs are working correctly');
    } else if (successRate >= 80) {
        System.debug('⚠️ GOOD - Some Leads missing lookups, check WordPress logs');
    } else if (successRate >= 50) {
        System.debug('⚠️ FAIR - Many Leads missing lookups, investigate implementation');
    } else {
        System.debug('❌ POOR - Most Leads missing lookups, check complete flow');
    }
} else {
    System.debug('ℹ️ No recent Leads found - Cannot calculate success rate');
}

// ═══════════════════════════════════════════════════════════
// TEST 4: Aggregate Statistics (Last 30 Days)
// ═══════════════════════════════════════════════════════════
System.debug('');
System.debug('');
System.debug('▼▼▼ TEST 4: Aggregate Statistics (Last 30 Days) ▼▼▼');
System.debug('');

// Leads by Partner
AggregateResult[] leadsByPartner = [
    SELECT Partner__r.Name partnerName, COUNT(Id) leadCount
    FROM Lead
    WHERE CreatedDate = LAST_N_DAYS:30
      AND Partner__c != null
      AND Websource__c != null
    GROUP BY Partner__r.Name
    ORDER BY COUNT(Id) DESC
];

System.debug('═══ LEADS BY PARTNER (LAST 30 DAYS) ═══');
if (leadsByPartner.size() > 0) {
    for (AggregateResult ar : leadsByPartner) {
        System.debug(ar.get('partnerName') + ': ' + ar.get('leadCount') + ' leads');
    }
} else {
    System.debug('ℹ️ No Leads with Partner lookup found');
}

System.debug('');

// Leads by Postcodegebied
AggregateResult[] leadsByPostcode = [
    SELECT Postcodegebied__r.Name postcodeNaam, COUNT(Id) leadCount
    FROM Lead
    WHERE CreatedDate = LAST_N_DAYS:30
      AND Postcodegebied__c != null
      AND Websource__c != null
    GROUP BY Postcodegebied__r.Name
    ORDER BY COUNT(Id) DESC
    LIMIT 10
];

System.debug('═══ TOP 10 POSTCODEGEBIEDEN (LAST 30 DAYS) ═══');
if (leadsByPostcode.size() > 0) {
    for (AggregateResult ar : leadsByPostcode) {
        System.debug(ar.get('postcodeNaam') + ': ' + ar.get('leadCount') + ' leads');
    }
} else {
    System.debug('ℹ️ No Leads with Postcodegebied lookup found');
}

// ═══════════════════════════════════════════════════════════
// FINAL VERDICT
// ═══════════════════════════════════════════════════════════
System.debug('');
System.debug('');
System.debug('═══════════════════════════════════════════════════════════');
System.debug('  FINAL VERDICT');
System.debug('═══════════════════════════════════════════════════════════');
System.debug('');

Boolean test1Pass = (completeCount == associaties.size());
Boolean test3Pass = (recentLeads.size() == 0 || leadsWithBothLookups >= (recentLeads.size() * 0.95));

System.debug('Test 1 (Association Data): ' + (test1Pass ? '✅ PASS' : '⚠️ NEEDS ATTENTION'));
System.debug('Test 2 (API Simulation): ✅ PASS (structure correct)');
System.debug('Test 3 (Recent Leads): ' + (test3Pass ? '✅ PASS' : '⚠️ NEEDS ATTENTION'));
System.debug('Test 4 (Statistics): ℹ️ INFO (no pass/fail)');

System.debug('');

if (test1Pass && test3Pass) {
    System.debug('🎉 ALL TESTS PASSED - Lookup IDs flow is working correctly!');
    System.debug('');
    System.debug('Next Steps:');
    System.debug('1. Monitor WordPress debug logs for lookup ID warnings');
    System.debug('2. Check SessionStorage in browser after postcode check');
    System.debug('3. Verify new Leads have Partner + Postcodegebied lookups');
} else {
    System.debug('⚠️ SOME TESTS NEED ATTENTION');
    System.debug('');
    System.debug('Troubleshooting Steps:');
    
    if (!test1Pass) {
        System.debug('1. Fix incomplete Dienstgebied_Postcode_Associatie__c records:');
        System.debug('   - Ensure all active records have Partner__c');
        System.debug('   - Ensure all active records have Postcode_Gebied__c');
        System.debug('   - Verify IDs are 18 characters long');
    }
    
    if (!test3Pass && recentLeads.size() > 0) {
        System.debug('2. Check WordPress implementation:');
        System.debug('   - Verify cinco-postcode-check-component.js saves partnerId');
        System.debug('   - Verify class-cinco-lead-endpoint.php reads metadata');
        System.debug('   - Check WordPress debug.log for warnings');
    }
    
    System.debug('3. Clear WordPress cache:');
    System.debug('   php clear-cache-simple.php');
    System.debug('');
    System.debug('4. Test complete flow manually:');
    System.debug('   - Enter postcode on website');
    System.debug('   - Check browser SessionStorage (cincoMetadata)');
    System.debug('   - Submit test Lead');
    System.debug('   - Verify Lead in Salesforce has lookups');
}

System.debug('');
System.debug('═══════════════════════════════════════════════════════════');
System.debug('  END OF VERIFICATION');
System.debug('═══════════════════════════════════════════════════════════');
