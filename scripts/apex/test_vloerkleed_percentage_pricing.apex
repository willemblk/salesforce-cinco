// Test Vloerkleed Percentage Pricing Implementation

System.debug('=== TESTING VLOERKLEED PERCENTAGE PRICING ===\n');

// 1. Check Prijsmanagement__c record for WAS-EXTRA-VLOERKLEED-VEZEL
List<Prijsmanagement__c> priceRules = [
    SELECT Product__r.ProductCode, Product__r.Name,
           Relatieve_prijs__c, Eenheidsprijs__c, Actief__c,
           Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode = 'WAS-EXTRA-VLOERKLEED-VEZEL'
      AND Actief__c = true
    LIMIT 1
];

if (priceRules.isEmpty()) {
    System.debug('❌ ERROR: No active Prijsmanagement__c record found for WAS-EXTRA-VLOERKLEED-VEZEL');
    System.debug('   Please create a record with:');
    System.debug('   - Product__c: WAS-EXTRA-VLOERKLEED-VEZEL');
    System.debug('   - Relatieve_prijs__c: 10');
    System.debug('   - Eenheidsprijs__c: null');
    System.debug('   - Actief__c: true');
    System.debug('   - Geldig_vanaf__c: TODAY');
} else {
    Prijsmanagement__c pm = priceRules[0];
    System.debug('✅ Found Prijsmanagement__c record:');
    System.debug('   Product: ' + pm.Product__r.ProductCode + ' (' + pm.Product__r.Name + ')');
    System.debug('   Relatieve_prijs__c: ' + pm.Relatieve_prijs__c);
    System.debug('   Eenheidsprijs__c: ' + pm.Eenheidsprijs__c);
    System.debug('   Actief__c: ' + pm.Actief__c);
    System.debug('   Geldig_vanaf__c: ' + pm.Geldig_vanaf__c);
    System.debug('   Geldig_tot__c: ' + pm.Geldig_tot__c);
    
    // Check if configured correctly
    if (pm.Relatieve_prijs__c != null && pm.Relatieve_prijs__c > 0) {
        if (pm.Eenheidsprijs__c == null) {
            System.debug('\n✅ CORRECT: Percentage pricing configured (Relatieve_prijs__c = ' + pm.Relatieve_prijs__c + '%, Eenheidsprijs__c = null)');
        } else {
            System.debug('\n⚠️ WARNING: Both Relatieve_prijs__c and Eenheidsprijs__c are set!');
            System.debug('   Eenheidsprijs__c should be NULL for percentage pricing');
            System.debug('   Current priority: Eenheidsprijs__c will be used (absolute pricing)');
        }
    } else {
        System.debug('\n❌ ERROR: Relatieve_prijs__c is null or 0!');
        System.debug('   For percentage pricing, set Relatieve_prijs__c to 10 (for 10%)');
    }
}

// 2. Test PriceCalculationApi response
System.debug('\n=== TESTING API RESPONSE ===\n');

RestRequest req = new RestRequest();
RestResponse res = new RestResponse();
RestContext.request = req;
RestContext.response = res;

String requestBody = '{"postcode":"1012AB","segment":"Wasserij","siteId":"CincoCleaning"}';
req.requestBody = Blob.valueOf(requestBody);

PriceCalculationApi.PriceResponse apiResponse = PriceCalculationApi.calculatePrice();

System.debug('API Success: ' + apiResponse.success);

if (!apiResponse.success) {
    System.debug('❌ API Error: ' + apiResponse.errorMessage);
} else {
    System.debug('✅ API returned ' + apiResponse.availableProducts.size() + ' products\n');
    
    // Find the extra product
    PriceCalculationApi.ResponseProduct vezelExtra = null;
    for (PriceCalculationApi.ResponseProduct rp : apiResponse.availableProducts) {
        if (rp.productCode == 'WAS-EXTRA-VLOERKLEED-VEZEL') {
            vezelExtra = rp;
            break;
        }
    }
    
    if (vezelExtra == null) {
        System.debug('❌ ERROR: WAS-EXTRA-VLOERKLEED-VEZEL not found in API response');
    } else {
        System.debug('✅ Found WAS-EXTRA-VLOERKLEED-VEZEL in API response:');
        System.debug('   productCode: ' + vezelExtra.productCode);
        System.debug('   productNaam: ' + vezelExtra.productNaam);
        System.debug('   isPrimary: ' + vezelExtra.isPrimary);
        System.debug('   pricingType: ' + vezelExtra.pricingType);
        System.debug('   percentageOfBase: ' + vezelExtra.percentageOfBase);
        System.debug('   basePrice: ' + vezelExtra.basePrice);
        
        if (vezelExtra.pricingType == 'percentage' && vezelExtra.percentageOfBase != null && vezelExtra.percentageOfBase > 0) {
            System.debug('\n✅ SUCCESS: Percentage pricing is configured correctly!');
            System.debug('   WordPress will calculate: basePrice * ' + vezelExtra.percentageOfBase + '%');
        } else if (vezelExtra.pricingType == 'absolute' && vezelExtra.basePrice != null) {
            System.debug('\n⚠️ WARNING: API returned absolute pricing instead of percentage!');
            System.debug('   Expected: pricingType = "percentage", percentageOfBase = 10');
            System.debug('   Actual: pricingType = "absolute", basePrice = ' + vezelExtra.basePrice);
            System.debug('   Check Prijsmanagement__c: Eenheidsprijs__c should be NULL');
        } else {
            System.debug('\n❌ ERROR: Invalid pricing configuration in API response');
        }
    }
}

System.debug('\n=== TEST COMPLETE ===');
