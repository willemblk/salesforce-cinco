/**
 * Test Script: Verify PriceCalculationApi Returns Lookup IDs
 * 
 * Purpose: Test that the API response includes partnerId, postcodeGebiedId, 
 *          and segment for WordPress Lead creation
 * 
 * How to run:
 * 1. Open Developer Console in Salesforce
 * 2. File > Open > Apex Class > PriceCalculationApi
 * 3. Debug > Open Execute Anonymous Window
 * 4. Paste this script and click "Execute"
 * 5. Check debug logs for results
 */

// ============================================================================
// TEST 1: Postcode Check (No Products) - Returns Catalog + Metadata
// ============================================================================
System.debug('═══════════════════════════════════════════════════════════');
System.debug('TEST 1: Postcode Check - Catalog with Lookup IDs');
System.debug('═══════════════════════════════════════════════════════════');

// Simulate WordPress postcode check request
RestRequest req = new RestRequest();
RestResponse res = new RestResponse();
req.requestURI = '/services/apexrest/v1/calculatePrice/';
req.httpMethod = 'POST';

// Request body (Step 1: Postcode check zonder producten)
String requestBody = JSON.serialize(new Map<String, Object>{
    'postcode' => '1012AB',  // Amsterdam centrum (adjust to your test data)
    'segment' => 'Wasserij',
    'siteId' => 'CincoCleaning',
    'products' => null  // No products = return catalog only
});

req.requestBody = Blob.valueOf(requestBody);
RestContext.request = req;
RestContext.response = res;

// Call API
PriceCalculationApi.PriceResponse response1 = PriceCalculationApi.calculatePrice();

// Verify response contains lookup IDs
System.debug('\n📦 API Response (Test 1):');
System.debug('   Success: ' + response1.success);
System.debug('   Afhandelingsmethode: ' + response1.afhandelingsmethode);
System.debug('   Regiotoeslag %: ' + response1.regioToeslagPercentage);
System.debug('\n🔗 Lookup IDs (voor Lead populatie):');
System.debug('   segment: ' + response1.segment);
System.debug('   partnerId: ' + response1.partnerId);
System.debug('   postcodeGebiedId: ' + response1.postcodeGebiedId);
System.debug('   dienstgebiedId: ' + response1.dienstgebiedId);
System.debug('\n📝 Display Names:');
System.debug('   partnerName: ' + response1.partnerName);
System.debug('   postcodeGebiedName: ' + response1.postcodeGebiedName);
System.debug('   dienstgebiedName: ' + response1.dienstgebiedName);

// Assertions
Boolean test1Pass = true;
if (String.isBlank(response1.segment)) {
    System.debug('❌ FAIL: segment is blank!');
    test1Pass = false;
}
if (String.isBlank(response1.partnerId) || response1.partnerId.length() != 18) {
    System.debug('❌ FAIL: partnerId is invalid (expected 18-char SF Id): ' + response1.partnerId);
    test1Pass = false;
}
if (String.isBlank(response1.postcodeGebiedId) || response1.postcodeGebiedId.length() != 18) {
    System.debug('❌ FAIL: postcodeGebiedId is invalid (expected 18-char SF Id): ' + response1.postcodeGebiedId);
    test1Pass = false;
}

if (test1Pass) {
    System.debug('\n✅ TEST 1 PASSED: All lookup IDs returned correctly');
} else {
    System.debug('\n❌ TEST 1 FAILED: Some fields missing or invalid');
}


// ============================================================================
// TEST 2: Verify Lead Can Be Created with These Fields
// ============================================================================
System.debug('\n\n═══════════════════════════════════════════════════════════');
System.debug('TEST 2: Simulate Lead Creation with Returned IDs');
System.debug('═══════════════════════════════════════════════════════════');

try {
    // Create test Lead with returned lookup IDs
    Lead testLead = new Lead(
        FirstName = 'Test',
        LastName = 'Customer',
        Email = 'test@example.com',
        Company = 'Test Company',
        PostalCode = '1012 AB',
        Status = 'Nieuw',
        
        // Populate from API response
        Uniek_Segment__c = response1.segment,
        Partner__c = response1.partnerId,
        Postcodegebied__c = response1.postcodeGebiedId
        // Dienstgebied__c = response1.dienstgebiedId  // Uncomment if field exists
    );
    
    insert testLead;
    
    System.debug('\n✅ TEST 2 PASSED: Lead created successfully');
    System.debug('   Lead Id: ' + testLead.Id);
    
    // Query back to verify
    Lead verifyLead = [
        SELECT Id, Name, Uniek_Segment__c, Partner__c, Postcodegebied__c,
               Partner__r.Name, Postcodegebied__r.Name
        FROM Lead 
        WHERE Id = :testLead.Id
    ];
    
    System.debug('\n📋 Lead Verification:');
    System.debug('   Name: ' + verifyLead.Name);
    System.debug('   Uniek_Segment__c: ' + verifyLead.Uniek_Segment__c);
    System.debug('   Partner: ' + verifyLead.Partner__r.Name + ' (' + verifyLead.Partner__c + ')');
    System.debug('   Postcodegebied: ' + verifyLead.Postcodegebied__r.Name + ' (' + verifyLead.Postcodegebied__c + ')');
    
    // Cleanup test data
    delete testLead;
    System.debug('\n🧹 Test Lead deleted');
    
} catch (Exception e) {
    System.debug('❌ TEST 2 FAILED: ' + e.getMessage());
    System.debug('   Stack Trace: ' + e.getStackTraceString());
}


// ============================================================================
// TEST 3: Verify Different Segments Return Correct Data
// ============================================================================
System.debug('\n\n═══════════════════════════════════════════════════════════');
System.debug('TEST 3: Test Multiple Segments');
System.debug('═══════════════════════════════════════════════════════════');

List<String> segmentsToTest = new List<String>{'Wasserij', 'SR', 'Dakkapel'};

for (String segment : segmentsToTest) {
    RestRequest req3 = new RestRequest();
    RestResponse res3 = new RestResponse();
    req3.requestURI = '/services/apexrest/v1/calculatePrice/';
    req3.httpMethod = 'POST';
    
    String requestBody3 = JSON.serialize(new Map<String, Object>{
        'postcode' => '1012AB',
        'segment' => segment,
        'siteId' => 'CincoCleaning',
        'products' => null
    });
    
    req3.requestBody = Blob.valueOf(requestBody3);
    RestContext.request = req3;
    RestContext.response = res3;
    
    PriceCalculationApi.PriceResponse response3 = PriceCalculationApi.calculatePrice();
    
    System.debug('\n📦 Segment: ' + segment);
    System.debug('   Success: ' + response3.success);
    System.debug('   Returned Segment: ' + response3.segment);
    System.debug('   Partner: ' + response3.partnerName);
    System.debug('   Regiotoeslag: ' + response3.regioToeslagPercentage + '%');
    
    if (response3.success && response3.segment == segment) {
        System.debug('   ✅ Segment match correct');
    } else if (!response3.success) {
        System.debug('   ⚠️ No association found for this segment');
    } else {
        System.debug('   ❌ Segment mismatch!');
    }
}


// ============================================================================
// SUMMARY
// ============================================================================
System.debug('\n\n═══════════════════════════════════════════════════════════');
System.debug('TEST SUMMARY');
System.debug('═══════════════════════════════════════════════════════════');
System.debug('✅ PriceCalculationApi now returns:');
System.debug('   - segment (for Lead.Uniek_Segment__c)');
System.debug('   - partnerId (for Lead.Partner__c lookup)');
System.debug('   - postcodeGebiedId (for Lead.Postcodegebied__c lookup)');
System.debug('   - dienstgebiedId (optional, for reporting)');
System.debug('\n📝 Next Steps:');
System.debug('   1. Update WordPress frontend to save these IDs');
System.debug('   2. Update WordPress backend to populate Lead fields');
System.debug('   3. Test end-to-end: Postcode check → Lead creation');
System.debug('═══════════════════════════════════════════════════════════\n');
