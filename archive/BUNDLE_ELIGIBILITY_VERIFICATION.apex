/**
 * VERIFICATION TEST: Bundle Discount + Bundelkorting_Toepasbaar Integration
 * 
 * This test verifies:
 * 1. Bundle_Discount__mdt records exist and are active
 * 2. Product2.Bundelkorting_Toepasbaar__c is correctly set
 * 3. PricingService bundle discount logic respects the checkbox
 */

System.debug('=== BUNDLE DISCOUNT + ELIGIBILITY VERIFICATION ===');

try {
    // Step 1: Check Bundle_Discount__mdt records
    List<Bundle_Discount__mdt> bundleRules = [
        SELECT Label, DeveloperName, Min_Count__c, Discount_Percent__c, 
               Segment__c, Active__c, Min_Aantal_Threshold__c
        FROM Bundle_Discount__mdt
        WHERE Active__c = true
        ORDER BY Segment__c, Min_Count__c DESC
    ];
    
    System.debug('📊 Found ' + bundleRules.size() + ' active bundle discount rules:');
    for (Bundle_Discount__mdt rule : bundleRules) {
        System.debug('  🎁 ' + rule.Segment__c + ': ' + rule.Label + 
                    ' (Min: ' + rule.Min_Count__c + 
                    ', Discount: ' + (rule.Discount_Percent__c * 100) + '%, ' +
                    'Threshold: ' + rule.Min_Aantal_Threshold__c + ')');
    }
    
    if (bundleRules.isEmpty()) {
        System.debug('❌ ERROR: No active Bundle_Discount__mdt records found!');
        System.debug('💡 Create records in Setup > Custom Metadata Types > Bundle Discount');
    }
    
    // Step 2: Check Product2 Bundelkorting_Toepasbaar settings
    List<Product2> wasserijProducts = [
        SELECT Id, ProductCode, Name, Segment__c, Primaryproduct__c, Bundelkorting_Toepasbaar__c
        FROM Product2
        WHERE Segment__c = 'Wasserij' 
        AND IsActive = true
        ORDER BY Primaryproduct__c DESC, ProductCode
    ];
    
    System.debug('');
    System.debug('🧪 Found ' + wasserijProducts.size() + ' Wasserij products:');
    
    Integer eligibleCount = 0;
    Integer notEligibleCount = 0;
    
    for (Product2 product : wasserijProducts) {
        String status = product.Bundelkorting_Toepasbaar__c ? '✅ ELIGIBLE' : '❌ NOT ELIGIBLE';
        String type = product.Primaryproduct__c ? 'Primary' : 'Extra';
        
        System.debug('  ' + status + ' | ' + type + ' | ' + product.ProductCode + ' - ' + product.Name);
        
        if (product.Bundelkorting_Toepasbaar__c) {
            eligibleCount++;
        } else {
            notEligibleCount++;
        }
    }
    
    System.debug('');
    System.debug('📈 Summary:');
    System.debug('  ✅ Bundle Eligible Products: ' + eligibleCount);
    System.debug('  ❌ Not Bundle Eligible Products: ' + notEligibleCount);
    
    // Step 3: Test expected configurations
    System.debug('');
    System.debug('🔍 Checking expected product configurations:');
    
    // Check Vloerkleed (should be eligible)
    Product2 vloerkleed = [
        SELECT ProductCode, Bundelkorting_Toepasbaar__c 
        FROM Product2 
        WHERE ProductCode LIKE 'VLRK%' 
        AND IsActive = true 
        LIMIT 1
    ];
    
    if (vloerkleed != null) {
        if (vloerkleed.Bundelkorting_Toepasbaar__c) {
            System.debug('  ✅ Vloerkleed (' + vloerkleed.ProductCode + ') is correctly marked as bundle eligible');
        } else {
            System.debug('  ❌ WARNING: Vloerkleed (' + vloerkleed.ProductCode + ') should be bundle eligible!');
        }
    }
    
    // Check Kussen (should NOT be eligible)
    List<Product2> kussens = [
        SELECT ProductCode, Bundelkorting_Toepasbaar__c 
        FROM Product2 
        WHERE ProductCode LIKE 'KUSSEN%' 
        AND IsActive = true 
        LIMIT 3
    ];
    
    for (Product2 kussen : kussens) {
        if (!kussen.Bundelkorting_Toepasbaar__c) {
            System.debug('  ✅ Kussen (' + kussen.ProductCode + ') is correctly marked as NOT bundle eligible');
        } else {
            System.debug('  ❌ WARNING: Kussen (' + kussen.ProductCode + ') should NOT be bundle eligible!');
        }
    }
    
    // Check Extras (should NOT be eligible)
    List<Product2> extras = [
        SELECT ProductCode, Bundelkorting_Toepasbaar__c 
        FROM Product2 
        WHERE (ProductCode LIKE '%EX%' OR ProductCode LIKE '%MOT%')
        AND Segment__c = 'Wasserij'
        AND IsActive = true 
        LIMIT 5
    ];
    
    for (Product2 extra : extras) {
        if (!extra.Bundelkorting_Toepasbaar__c) {
            System.debug('  ✅ Extra (' + extra.ProductCode + ') is correctly marked as NOT bundle eligible');
        } else {
            System.debug('  ❌ WARNING: Extra (' + extra.ProductCode + ') should NOT be bundle eligible!');
        }
    }
    
    // Step 4: Test API integration
    System.debug('');
    System.debug('🧪 Testing PriceCalculationApi integration...');
    
    String testJson = '{"postcode": "1012AB", "segment": "Wasserij", "siteId": "CincoCleaning", "products": []}';
    RestRequest testReq = new RestRequest();
    testReq.requestBody = Blob.valueOf(testJson);
    RestContext.request = testReq;
    
    PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice();
    
    if (response.success) {
        System.debug('✅ API call successful');
        System.debug('  Bundle Discounts: ' + (response.bundleDiscounts != null ? response.bundleDiscounts.size() : 'null'));
        System.debug('  Primary Products: ' + (response.primaryProducts != null ? response.primaryProducts.size() : 'null'));
        
        if (response.bundleDiscounts != null && response.bundleDiscounts.size() > 0) {
            System.debug('🎉 SUCCESS: Bundle discounts are being returned by API!');
            for (PriceCalculationApi.BundleDiscountRule rule : response.bundleDiscounts) {
                System.debug('  🎁 API Rule: ' + rule.label + ' (' + (rule.discountPercent * 100) + '%)');
            }
        } else {
            System.debug('⚠️ WARNING: No bundle discounts returned by API');
        }
        
        if (response.primaryProducts != null && response.primaryProducts.size() > 0) {
            System.debug('📦 Product bundelkortingToepasbaar settings in API response:');
            for (PriceCalculationApi.ResponseProduct prod : response.primaryProducts) {
                System.debug('  ' + prod.productCode + ': bundelkortingToepasbaar=' + prod.bundelkortingToepasbaar);
            }
        }
        
    } else {
        System.debug('❌ API call failed: ' + response.errorMessage);
    }
    
} catch (Exception e) {
    System.debug('❌ Test failed: ' + e.getMessage());
    System.debug('Stack: ' + e.getStackTraceString());
}

System.debug('=== VERIFICATION COMPLETE ===');