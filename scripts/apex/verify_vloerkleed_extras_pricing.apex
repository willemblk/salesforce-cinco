/**
 * Verify Vloerkleed Extras Pricing Configuration
 * 
 * Purpose: Check if all vloerkleed extras are correctly configured
 * with Price_Type__c and pricing values
 * 
 * Run: sf apex run --file scripts/apex/verify_vloerkleed_extras_pricing.apex
 */

System.debug('=== VLOERKLEED EXTRAS PRICING VERIFICATION ===\n');

// Get all vloerkleed extras with pricing
List<Prijsmanagement__c> prices = [
    SELECT Product__r.ProductCode, 
           Product__r.Name,
           Price_Type__c, 
           Eenheidsprijs__c, 
           Relatieve_prijs__c,
           Actief__c,
           Geldig_vanaf__c,
           Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode LIKE 'WAS-EXTRA-VLOERKLEED-%'
      AND Actief__c = true
    ORDER BY Product__r.ProductCode
];

System.debug('Found ' + prices.size() + ' active pricing records\n');

// Categorize by pricing type
Integer percentageBased = 0;
Integer flatFee = 0;
Integer perM2 = 0;
Integer missing = 0;

Map<String, String> categorized = new Map<String, String>();

for (Prijsmanagement__c pm : prices) {
    String category = '';
    String priceDisplay = '';
    
    if (pm.Price_Type__c == 'Flat Fee') {
        category = '💵 FLAT FEE';
        priceDisplay = '€' + pm.Eenheidsprijs__c + ' (flat)';
        flatFee++;
    } else if (pm.Relatieve_prijs__c != null && pm.Relatieve_prijs__c > 0) {
        category = '📊 PERCENTAGE';
        priceDisplay = pm.Relatieve_prijs__c + '% of base price';
        percentageBased++;
    } else if (pm.Eenheidsprijs__c != null) {
        category = '📏 PER M²';
        priceDisplay = '€' + pm.Eenheidsprijs__c + '/m²';
        perM2++;
    } else {
        category = '❌ MISSING PRICE';
        priceDisplay = 'No price configured';
        missing++;
    }
    
    System.debug(category + ' | ' + pm.Product__r.ProductCode + ': ' + priceDisplay);
    categorized.put(pm.Product__r.ProductCode, category);
}

System.debug('\n=== SUMMARY ===');
System.debug('Total extras configured: ' + prices.size());
System.debug('  - Flat Fee: ' + flatFee);
System.debug('  - Percentage-based: ' + percentageBased);
System.debug('  - Per m²: ' + perM2);
System.debug('  - Missing price: ' + missing);

// Check for missing products
List<String> expectedExtras = new List<String>{
    'WAS-EXTRA-VLOERKLEED-VEZEL',
    'WAS-EXTRA-VLOERKLEED-GEUR',
    'WAS-EXTRA-VLOERKLEED-MOT',
    'WAS-EXTRA-VLOERKLEED-WATER',
    'WAS-EXTRA-VLOERKLEED-ZIJDE',
    'WAS-EXTRA-VLOERKLEED-INPAKOPSLAG',
    'WAS-EXTRA-VLOERKLEED-INPAKPLASTIC'
};

Set<String> found = new Set<String>();
for (Prijsmanagement__c pm : prices) {
    found.add(pm.Product__r.ProductCode);
}

List<String> missingProducts = new List<String>();
for (String expected : expectedExtras) {
    if (!found.contains(expected)) {
        missingProducts.add(expected);
    }
}

if (!missingProducts.isEmpty()) {
    System.debug('\n⚠️ WARNING: Missing pricing for ' + missingProducts.size() + ' products:');
    for (String missing : missingProducts) {
        System.debug('  - ' + missing);
    }
} else {
    System.debug('\n✅ All expected extras have pricing configured!');
}

// Test API response format
System.debug('\n=== API RESPONSE TEST ===');
System.debug('Testing PriceCalculationApi with sample request...\n');

// Simulate API request
RestRequest req = new RestRequest();
RestResponse res = new RestResponse();
req.requestURI = '/services/apexrest/v1/calculatePrice';
req.httpMethod = 'POST';
req.addHeader('Content-Type', 'application/json');

// Sample request body
Map<String, Object> requestBody = new Map<String, Object>{
    'postcode' => '1012AB',
    'segment' => 'Wasserij',
    'siteId' => 'CincoCleaning'
};

req.requestBody = Blob.valueOf(JSON.serialize(requestBody));

RestContext.request = req;
RestContext.response = res;

// Call API
PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice();

if (response.success) {
    System.debug('✅ API call successful!');
    System.debug('Found ' + response.availableProducts.size() + ' products in response\n');
    
    // Check extra products
    Integer flatFeeCount = 0;
    Integer percentageCount = 0;
    Integer absoluteCount = 0;
    
    for (PriceCalculationApi.ResponseProduct product : response.availableProducts) {
        if (!product.isPrimary && product.productCode.startsWith('WAS-EXTRA-VLOERKLEED-')) {
            String typeInfo = '';
            
            if (product.pricingType == 'flat') {
                typeInfo = '💵 FLAT: €' + product.basePrice;
                flatFeeCount++;
            } else if (product.pricingType == 'percentage') {
                typeInfo = '📊 PERCENTAGE: ' + product.percentageOfBase + '%';
                percentageCount++;
            } else if (product.pricingType == 'absolute') {
                typeInfo = '📏 ABSOLUTE: €' + product.basePrice;
                absoluteCount++;
            } else {
                typeInfo = '❓ UNKNOWN: ' + product.pricingType;
            }
            
            System.debug(product.productCode + ' → ' + typeInfo);
        }
    }
    
    System.debug('\n=== API RESPONSE SUMMARY ===');
    System.debug('  - Flat Fee extras: ' + flatFeeCount);
    System.debug('  - Percentage extras: ' + percentageCount);
    System.debug('  - Absolute extras: ' + absoluteCount);
    
    if (flatFeeCount == 2 && percentageCount == 2 && absoluteCount == 3) {
        System.debug('\n✅ API RESPONSE CORRECT!');
        System.debug('Expected: 2 flat fee, 2 percentage, 3 absolute');
        System.debug('Received: ' + flatFeeCount + ' flat fee, ' + percentageCount + ' percentage, ' + absoluteCount + ' absolute');
    } else {
        System.debug('\n⚠️ API RESPONSE MISMATCH!');
        System.debug('Expected: 2 flat fee, 2 percentage, 3 absolute');
        System.debug('Received: ' + flatFeeCount + ' flat fee, ' + percentageCount + ' percentage, ' + absoluteCount + ' absolute');
    }
} else {
    System.debug('❌ API call failed: ' + response.message);
}

System.debug('\n=== VERIFICATION COMPLETE ===');
