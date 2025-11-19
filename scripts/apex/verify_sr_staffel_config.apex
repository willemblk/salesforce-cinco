// ===================================================================
// VERIFY SR STAFFEL PRICING CONFIGURATION
// ===================================================================
// Purpose: Check if Prijsstaffel__c records exist for SR-PRIM-MEUBEL
//          and verify API returns staffel pricing correctly
// Expected: 2+ staffel tiers with proper ondergrens/bovengrens/eenheidsprijs
// ===================================================================

System.debug('\n' + '='.repeat(70));
System.debug('🔍 SR STAFFEL PRICING VERIFICATION');
System.debug('='.repeat(70) + '\n');

// ===================================================================
// STEP 1: Find SR-PRIM-MEUBEL Product
// ===================================================================
System.debug('📦 Step 1: Looking for SR-PRIM-MEUBEL product...\n');

List<Product2> products = [
    SELECT Id, ProductCode, Name, Segment__c
    FROM Product2
    WHERE ProductCode LIKE 'SR-PRIM%' OR ProductCode = 'SR-MEUBEL'
    LIMIT 10
];

if (products.isEmpty()) {
    System.debug('❌ No SR products found!');
    System.debug('   Please create Product2 with ProductCode = "SR-PRIM-MEUBEL"');
} else {
    System.debug('✅ Found ' + products.size() + ' SR product(s):');
    for (Product2 p : products) {
        System.debug('   • ' + p.ProductCode + ' - ' + p.Name + ' (Segment: ' + p.Segment__c + ')');
    }
    System.debug('');
}

// ===================================================================
// STEP 2: Find Prijsmanagement__c for SR products
// ===================================================================
System.debug('💰 Step 2: Checking Prijsmanagement__c records...\n');

List<Prijsmanagement__c> priceRules = [
    SELECT Id, Product__r.ProductCode, Product__c, Eenheidsprijs__c, 
           Actief__c, Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode LIKE 'SR%'
      AND Actief__c = true
      AND Geldig_vanaf__c <= TODAY
      AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
];

if (priceRules.isEmpty()) {
    System.debug('❌ No active Prijsmanagement__c found for SR products!');
    System.debug('   Action Required:');
    System.debug('   1. Navigate to Prijsmanagement tab in Salesforce');
    System.debug('   2. Create new record:');
    System.debug('      - Product: SR-PRIM-MEUBEL');
    System.debug('      - Eenheidsprijs: 80.00');
    System.debug('      - Actief: ✓');
    System.debug('      - Geldig vanaf: Today');
    System.debug('');
} else {
    System.debug('✅ Found ' + priceRules.size() + ' active price rule(s):');
    for (Prijsmanagement__c pm : priceRules) {
        System.debug('   • ' + pm.Product__r.ProductCode + ':');
        System.debug('     - ID: ' + pm.Id);
        System.debug('     - Base Price: €' + pm.Eenheidsprijs__c);
        System.debug('     - Valid: ' + pm.Geldig_vanaf__c + ' → ' + 
                    (pm.Geldig_tot__c != null ? String.valueOf(pm.Geldig_tot__c) : 'indefinite'));
    }
    System.debug('');
}

// ===================================================================
// STEP 3: Check Prijsstaffel__c records
// ===================================================================
System.debug('📊 Step 3: Checking Prijsstaffel__c records...\n');

List<Prijsstaffel__c> staffels = [
    SELECT Id, Name, Prijsmanagement__r.Product__r.ProductCode,
           Ondergrens__c, Bovengrens__c, Eenheidsprijs__c, Vaste_Prijs__c
    FROM Prijsstaffel__c
    WHERE Prijsmanagement__r.Product__r.ProductCode LIKE 'SR%'
    ORDER BY Prijsmanagement__r.Product__r.ProductCode, Ondergrens__c ASC
];

if (staffels.isEmpty()) {
    System.debug('⚠️ No Prijsstaffel__c records found!');
    System.debug('   This means SR pricing will use fallback (hard-coded €75/€65/€55)');
    System.debug('');
    System.debug('   To enable Salesforce staffel pricing:');
    System.debug('   1. Navigate to Prijsstaffel tab');
    System.debug('   2. Create Tier 1:');
    System.debug('      - Prijsmanagement: [Select SR price rule]');
    System.debug('      - Ondergrens: 1');
    System.debug('      - Bovengrens: 3');
    System.debug('      - Eenheidsprijs: 80.00');
    System.debug('   3. Create Tier 2:');
    System.debug('      - Prijsmanagement: [Select SR price rule]');
    System.debug('      - Ondergrens: 4');
    System.debug('      - Bovengrens: 999');
    System.debug('      - Eenheidsprijs: 60.00');
    System.debug('');
} else {
    System.debug('✅ Found ' + staffels.size() + ' staffel tier(s):');
    
    Map<String, List<Prijsstaffel__c>> staffelsByProduct = new Map<String, List<Prijsstaffel__c>>();
    for (Prijsstaffel__c s : staffels) {
        String productCode = s.Prijsmanagement__r.Product__r.ProductCode;
        if (!staffelsByProduct.containsKey(productCode)) {
            staffelsByProduct.put(productCode, new List<Prijsstaffel__c>());
        }
        staffelsByProduct.get(productCode).add(s);
    }
    
    for (String productCode : staffelsByProduct.keySet()) {
        System.debug('\n   📦 ' + productCode + ':');
        for (Prijsstaffel__c s : staffelsByProduct.get(productCode)) {
            String priceInfo = s.Eenheidsprijs__c != null 
                ? '€' + s.Eenheidsprijs__c + '/unit'
                : '€' + s.Vaste_Prijs__c + ' fixed';
            System.debug('      • ' + s.Name);
            System.debug('        Range: ' + s.Ondergrens__c + '-' + s.Bovengrens__c + ' units');
            System.debug('        Price: ' + priceInfo);
        }
    }
    System.debug('');
}

// ===================================================================
// STEP 4: Test API Response
// ===================================================================
System.debug('🌐 Step 4: Testing PriceCalculationApi response...\n');

// Prepare mock request
PriceCalculationApi.PriceRequest req = new PriceCalculationApi.PriceRequest();
req.postcode = '1012AB';
req.segment = 'SR';
req.products = new List<PriceCalculationApi.RequestLine>();
req.siteId = 'CincoCleaning';

// Mock REST context
RestRequest restReq = new RestRequest();
RestResponse restResp = new RestResponse();
RestContext.request = restReq;
RestContext.response = restResp;
restReq.requestBody = Blob.valueOf(JSON.serialize(req));

// Call API
PriceCalculationApi.PriceResponse resp;
try {
    resp = PriceCalculationApi.calculatePrice();
} catch (Exception e) {
    System.debug('❌ API Error: ' + e.getMessage());
    System.debug('   Stack Trace: ' + e.getStackTraceString());
    return;
}

if (!resp.success) {
    System.debug('❌ API returned error: ' + resp.errorMessage);
    return;
}

// Check for SR products in response
Boolean foundSrProduct = false;
for (PriceCalculationApi.ResponseProduct prod : resp.availableProducts) {
    if (prod.productCode.contains('SR')) {
        foundSrProduct = true;
        
        System.debug('✅ API Response for ' + prod.productCode + ':');
        System.debug('   • Product Name: ' + prod.productNaam);
        System.debug('   • Is Primary: ' + prod.isPrimary);
        System.debug('   • Base Price: €' + prod.basePrice);
        System.debug('   • Staffel Tiers: ' + 
                    (prod.staffelPricing != null ? String.valueOf(prod.staffelPricing.size()) : '0'));
        
        if (prod.staffelPricing != null && !prod.staffelPricing.isEmpty()) {
            System.debug('\n   📊 Staffel Pricing Details:');
            for (PriceCalculationApi.StaffelTier tier : prod.staffelPricing) {
                String priceInfo = tier.eenheidsprijs != null 
                    ? '€' + tier.eenheidsprijs + '/unit'
                    : '€' + tier.vastePrijs + ' fixed';
                System.debug('      • Tier: ' + tier.ondergrens + '-' + tier.bovengrens + ' units');
                System.debug('        Price: ' + priceInfo);
            }
        } else {
            System.debug('   ⚠️ No staffel pricing in API response');
            System.debug('   → Frontend will use fallback pricing (€75/€65/€55)');
        }
        System.debug('');
    }
}

if (!foundSrProduct) {
    System.debug('⚠️ No SR products in API response');
    System.debug('   Possible causes:');
    System.debug('   • Product not active (IsActive = false)');
    System.debug('   • Product not assigned to segment "SR"');
    System.debug('   • Site_Identifier__c filtering excludes product');
    System.debug('');
}

// ===================================================================
// STEP 5: Summary & Recommendations
// ===================================================================
System.debug('\n' + '='.repeat(70));
System.debug('📋 SUMMARY & NEXT STEPS');
System.debug('='.repeat(70) + '\n');

Integer issues = 0;

// Check 1: Product exists
if (products.isEmpty()) {
    System.debug('❌ Issue 1: No SR products found');
    System.debug('   Action: Create Product2 with ProductCode = "SR-PRIM-MEUBEL"');
    issues++;
} else {
    System.debug('✅ Products found: ' + products.size());
}

// Check 2: Price rule exists
if (priceRules.isEmpty()) {
    System.debug('❌ Issue 2: No active Prijsmanagement__c');
    System.debug('   Action: Create price rule for SR-PRIM-MEUBEL');
    issues++;
} else {
    System.debug('✅ Price rules found: ' + priceRules.size());
}

// Check 3: Staffel tiers exist
if (staffels.isEmpty()) {
    System.debug('⚠️ Issue 3: No Prijsstaffel__c records');
    System.debug('   Impact: Frontend will use fallback pricing');
    System.debug('   Action: Create 2+ staffel tiers for dynamic pricing');
    issues++;
} else {
    System.debug('✅ Staffel tiers found: ' + staffels.size());
}

// Check 4: API returns data
if (!foundSrProduct) {
    System.debug('❌ Issue 4: API does not return SR products');
    System.debug('   Action: Check product IsActive flag and segment assignment');
    issues++;
} else {
    System.debug('✅ API returns SR product(s)');
}

System.debug('\n' + '-'.repeat(70));
if (issues == 0) {
    System.debug('🎉 All checks passed! SR staffel pricing is fully configured.');
    System.debug('   Next: Test in browser at /configuratie/?segment=SR');
} else {
    System.debug('⚠️ Found ' + issues + ' issue(s) to resolve.');
    System.debug('   Review the actions above and re-run this script.');
}
System.debug('='.repeat(70) + '\n');
