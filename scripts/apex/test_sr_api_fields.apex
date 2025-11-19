// Test SR segment API fields
// Purpose: Verify new Material_Type__c, Photo_Required__c, etc. are returned by PriceCalculationApi

System.debug('🧪 Testing SR segment API fields...');
System.debug('─'.repeat(80));

// Create test request for SR segment
PriceCalculationApi.PriceRequest req = new PriceCalculationApi.PriceRequest();
req.postcode = '1012AB';
req.segment = 'SR';
req.siteId = 'CincoCleaning';
req.products = null; // Request catalog, not price calculation

// Simulate API call
RestRequest restReq = new RestRequest();
RestResponse restResp = new RestResponse();
RestContext.request = restReq;
RestContext.response = restResp;
restReq.requestBody = Blob.valueOf(JSON.serialize(req));

System.debug('📞 Calling PriceCalculationApi.calculatePrice() for SR segment...');
PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice();

System.debug('─'.repeat(80));
System.debug('✅ API Response received');
System.debug('📊 Success: ' + response.success);
System.debug('🛍️  Available Products: ' + response.availableProducts.size());

// Inspect SR products for new fields
Integer srProductCount = 0;
for (PriceCalculationApi.ResponseProduct product : response.availableProducts) {
    if (product.segment == 'SR') {
        srProductCount++;
        System.debug('─'.repeat(80));
        System.debug('🪑 SR Product: ' + product.productCode + ' - ' + product.productNaam);
        System.debug('   ├─ Primary: ' + product.isPrimary);
        System.debug('   ├─ Base Price: €' + product.basePrice);
        System.debug('   ├─ Material Type: ' + product.materialType);
        System.debug('   ├─ Photo Required: ' + product.photoRequired);
        System.debug('   ├─ Photo Min Count: ' + product.photoMinCount);
        System.debug('   ├─ Photo Instructions: ' + (product.photoInstructions != null ? product.photoInstructions.substring(0, Math.min(50, product.photoInstructions.length())) + '...' : 'null'));
        System.debug('   └─ Furniture Type: ' + product.furnitureType);
        
        // Validate critical fields
        if (product.productCode.startsWith('SR-PRIM-MEUBEL')) {
            // Meubel products should have material type and photo requirements
            if (product.materialType == null) {
                System.debug('   ⚠️  WARNING: materialType is null for meubel product');
            }
            if (!product.photoRequired) {
                System.debug('   ⚠️  WARNING: photoRequired is false for meubel product (expected true)');
            }
            if (product.photoMinCount < 2) {
                System.debug('   ⚠️  WARNING: photoMinCount is ' + product.photoMinCount + ' (expected >= 2)');
            }
        } else if (product.productCode.startsWith('SR-PRIM-TAPIJT')) {
            // Tapijt products should NOT require photos
            if (product.photoRequired) {
                System.debug('   ⚠️  WARNING: photoRequired is true for tapijt product (expected false)');
            }
        }
    }
}

System.debug('─'.repeat(80));
System.debug('📈 Summary:');
System.debug('   ├─ Total SR Products: ' + srProductCount);
System.debug('   ├─ Expected Products: 3 primaries (MEUBEL-STOF, MEUBEL-LEER, TAPIJT) + 6 extras');
System.debug('   └─ Bundle Discounts: ' + (response.bundleDiscounts != null ? response.bundleDiscounts.size() : 0));

// Check bundle discounts for SR segment
if (response.bundleDiscounts != null) {
    for (PriceCalculationApi.BundleDiscountRule rule : response.bundleDiscounts) {
        System.debug('   🎁 ' + rule.label + ' (' + rule.segment + ')');
    }
}

System.debug('─'.repeat(80));
System.debug('✅ SR API Field Test Complete');
