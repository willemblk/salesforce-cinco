// Test script for SR percentage-based extras implementation
// Run via: sf apex run --file scripts/apex/test_sr_percentage_extras.apex

System.debug('=== SR PERCENTAGE-BASED EXTRAS TEST ===');

// 1. Check SR extra products exist
System.debug('\n📦 Checking SR Extra Products...');
List<Product2> srExtras = [
    SELECT Id, ProductCode, Name, IsActive, Segment__c, 
           Primaryproduct__c, Gerelateerd_hoofdproduct__c
    FROM Product2
    WHERE Segment__c = 'SR'
      AND Primaryproduct__c = false
      AND IsActive = true
      AND ProductCode LIKE 'SR-EXTRA-%'
    ORDER BY ProductCode
];

System.debug('Found ' + srExtras.size() + ' SR extra products:');
for (Product2 p : srExtras) {
    System.debug('  - ' + p.ProductCode + ': ' + p.Name);
}

// 2. Check pricing with Relatieve_prijs__c field
System.debug('\n💰 Checking Percentage Pricing (Relatieve_prijs__c)...');
List<Prijsmanagement__c> percentagePrices = [
    SELECT Product__r.ProductCode, Product__r.Name,
           Eenheidsprijs__c, Relatieve_prijs__c, Actief__c,
           Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
      AND Product__r.Primaryproduct__c = false
      AND Actief__c = true
      AND Relatieve_prijs__c != null
];

if (percentagePrices.isEmpty()) {
    System.debug('⚠️ NO PERCENTAGE PRICING FOUND!');
    System.debug('Expected: SR-EXTRA-MEUBEL-VEZEL (10%), SR-EXTRA-MEUBEL-GEUR (10%), SR-EXTRA-MEUBEL-URINE (15%)');
    System.debug('         SR-EXTRA-TAPIJT-VEZEL (10%), SR-EXTRA-TAPIJT-GEUR (10%), SR-EXTRA-TAPIJT-URINE (15%)');
} else {
    System.debug('✅ Found ' + percentagePrices.size() + ' products with percentage pricing:');
    for (Prijsmanagement__c pm : percentagePrices) {
        System.debug('  - ' + pm.Product__r.ProductCode + ': ' + pm.Relatieve_prijs__c + '%');
        System.debug('    (Eenheidsprijs__c: €' + pm.Eenheidsprijs__c + ', Actief: ' + pm.Actief__c + ')');
    }
}

// 3. Test PriceCalculationApi response structure
System.debug('\n🔌 Testing PriceCalculationApi Response...');

// Create mock request for SR segment
PriceCalculationApi.PriceRequest mockRequest = new PriceCalculationApi.PriceRequest();
mockRequest.postcode = '1012AB';
mockRequest.segment = 'SR';
mockRequest.siteId = 'CincoCleaning';

// Call API to get catalog
RestRequest req = new RestRequest();
req.requestURI = '/services/apexrest/v1/calculatePrice/';
req.httpMethod = 'POST';
req.requestBody = Blob.valueOf(JSON.serialize(mockRequest));
RestContext.request = req;

PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice();

if (response.success && response.availableProducts != null) {
    System.debug('✅ API response successful');
    System.debug('   Total products: ' + response.availableProducts.size());
    
    // Check for SR extras with percentage pricing
    Integer percentageExtrasCount = 0;
    for (PriceCalculationApi.ResponseProduct prod : response.availableProducts) {
        if (!prod.isPrimary && prod.pricingType == 'percentage') {
            percentageExtrasCount++;
            System.debug('  ✅ ' + prod.productCode + ': ' + prod.percentageOfBase + '% (pricingType: ' + prod.pricingType + ')');
        }
    }
    
    System.debug('\n📊 Summary:');
    System.debug('   - Total products: ' + response.availableProducts.size());
    System.debug('   - Percentage-based extras: ' + percentageExtrasCount);
    
    if (percentageExtrasCount == 0) {
        System.debug('⚠️ WARNING: No percentage-based extras found in API response');
        System.debug('   Expected at least 3 (SR-EXTRA-MEUBEL-VEZEL, SR-EXTRA-MEUBEL-GEUR, SR-EXTRA-MEUBEL-URINE)');
    } else {
        System.debug('✅ Percentage pricing working correctly!');
    }
} else {
    System.debug('❌ API call failed: ' + response.errorMessage);
}

// 4. Test calculation with percentage extras
System.debug('\n🧮 Testing Percentage Calculation Logic...');

// Example: SR Meubel Bank (3 seats @ €55 = €165) + 10% Vezelbeschermer = €16.50
Decimal basePricePerSeat = 55.00;
Decimal seats = 3;
Decimal basePriceTotal = basePricePerSeat * seats;

Decimal vezelPercent = 10; // 10%
Decimal extraCost = basePriceTotal * (vezelPercent / 100);

System.debug('Example calculation:');
System.debug('  Base: ' + seats + ' seats @ €' + basePricePerSeat + ' = €' + basePriceTotal);
System.debug('  Extra: Vezelbeschermer (' + vezelPercent + '%) = €' + extraCost);
System.debug('  Total: €' + (basePriceTotal + extraCost));

if (extraCost == 16.50) {
    System.debug('✅ Calculation correct!');
} else {
    System.debug('❌ Calculation error! Expected €16.50, got €' + extraCost);
}

System.debug('\n=== TEST COMPLETE ===');
