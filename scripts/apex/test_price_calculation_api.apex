// Test script voor PriceCalculationApi
// Gebruik: Anonymous Apex in Developer Console

System.debug('=== PRICE CALCULATION API TEST START ===');

try {
    // Test 1: Product Catalog Request (geen producten, alleen postcode check)
    System.debug('--- TEST 1: Product Catalog Request ---');
    
    PriceCalculationApi.PriceRequest catalogRequest = new PriceCalculationApi.PriceRequest();
    catalogRequest.postcode = '1012AB';
    catalogRequest.segment = 'Wasserij';
    catalogRequest.products = new List<PriceCalculationApi.RequestLine>();
    
    PriceCalculationApi.PriceResponse catalogResponse = PriceCalculationApi.calculatePrice(catalogRequest);
    
    if (catalogResponse.success) {
        System.debug('✅ Catalog request successful');
        System.debug('Afhandelingsmethode: ' + catalogResponse.afhandelingsmethode);
        System.debug('Available products: ' + catalogResponse.availableProducts.size());
        
        for (PriceCalculationApi.ResponseProduct prod : catalogResponse.availableProducts) {
            System.debug('  Product: ' + prod.productCode + ' - ' + prod.productNaam + ' (Primary: ' + prod.isPrimary + ')');
            if (prod.extras != null && !prod.extras.isEmpty()) {
                System.debug('    Extras: ' + prod.extras.size());
                for (PriceCalculationApi.ResponseProduct extra : prod.extras) {
                    System.debug('      - ' + extra.productCode + ' - ' + extra.productNaam);
                }
            }
        }
    } else {
        System.debug('❌ Catalog request failed: ' + catalogResponse.errorMessage);
    }
    
    System.debug('');
    
    // Test 2: Price Calculation Request
    System.debug('--- TEST 2: Price Calculation Request ---');
    
    PriceCalculationApi.PriceRequest priceRequest = new PriceCalculationApi.PriceRequest();
    priceRequest.postcode = '1012AB';
    priceRequest.segment = 'Wasserij';
    priceRequest.products = new List<PriceCalculationApi.RequestLine>();
    
    // Zoek een actief product voor de test
    List<Product2> testProducts = [
        SELECT Id, ProductCode, Name, Primaryproduct__c
        FROM Product2 
        WHERE Segment__c = 'Wasserij' 
          AND IsActive = true 
          AND Primaryproduct__c = true
        LIMIT 1
    ];
    
    if (!testProducts.isEmpty()) {
        Product2 testProduct = testProducts[0];
        System.debug('Using test product: ' + testProduct.ProductCode + ' - ' + testProduct.Name);
        
        // Maak een test product line
        PriceCalculationApi.RequestLine line = new PriceCalculationApi.RequestLine();
        line.productCode = testProduct.ProductCode;
        line.quantity = 4.5; // 4.5 m² voor vloerkleed
        line.lengthCm = 200;
        line.widthCm = 225;
        priceRequest.products.add(line);
        
        PriceCalculationApi.PriceResponse priceResponse = PriceCalculationApi.calculatePrice(priceRequest);
        
        if (priceResponse.success) {
            System.debug('✅ Price calculation successful');
            System.debug('Calculation ID: ' + priceResponse.calculationId);
            System.debug('Afhandelingsmethode: ' + priceResponse.afhandelingsmethode);
            
            System.debug('Calculated Lines: ' + priceResponse.calculatedLines.size());
            for (PriceCalculationApi.ResponseLine calcLine : priceResponse.calculatedLines) {
                System.debug('  Line: ' + calcLine.productCode + ' - ' + calcLine.productName);
                System.debug('    Quantity: ' + calcLine.quantity);
                System.debug('    Area: ' + calcLine.oppervlakte + ' m²');
                System.debug('    Unit Price: €' + calcLine.verkoopprijs);
                System.debug('    Gross Total: €' + calcLine.totalePrijs);
                System.debug('    Discount: ' + calcLine.kortingPercentage + '% (€' + calcLine.kortingBedrag + ')');
                System.debug('    Net Total: €' + calcLine.nettoTotaal);
                System.debug('    BTW: €' + calcLine.btwBedrag);
                System.debug('    Total Inc BTW: €' + calcLine.totaalIncBtw);
                System.debug('    Regional Surcharge: ' + calcLine.regioToeslagPercentage + '%');
            }
            
            System.debug('Order Totals:');
            System.debug('  Subtotal: €' + priceResponse.subTotaal);
            System.debug('  Total Discount: €' + priceResponse.totalKortingBedrag);
            System.debug('  Regional Surcharge: €' + priceResponse.regioToeslagBedrag);
            System.debug('  BTW Total: €' + priceResponse.btwTotaal);
            System.debug('  Final Total: €' + priceResponse.eindTotaal);
            if (String.isNotBlank(priceResponse.appliedBundleDiscount)) {
                System.debug('  Applied Bundle Discount: ' + priceResponse.appliedBundleDiscount);
            }
            
        } else {
            System.debug('❌ Price calculation failed: ' + priceResponse.errorMessage);
        }
    } else {
        System.debug('⚠️ No test products found for segment Wasserij');
    }
    
    System.debug('');
    
    // Test 3: Invalid Postcode
    System.debug('--- TEST 3: Invalid Postcode Test ---');
    
    PriceCalculationApi.PriceRequest invalidRequest = new PriceCalculationApi.PriceRequest();
    invalidRequest.postcode = '9999ZZ'; // Non-existent postcode
    invalidRequest.segment = 'Wasserij';
    invalidRequest.products = new List<PriceCalculationApi.RequestLine>();
    
    PriceCalculationApi.PriceResponse invalidResponse = PriceCalculationApi.calculatePrice(invalidRequest);
    
    if (!invalidResponse.success) {
        System.debug('✅ Invalid postcode correctly rejected: ' + invalidResponse.errorMessage);
    } else {
        System.debug('❌ Invalid postcode was incorrectly accepted');
    }
    
    System.debug('');
    
    // Test 4: Missing Required Fields
    System.debug('--- TEST 4: Missing Required Fields Test ---');
    
    PriceCalculationApi.PriceRequest emptyRequest = new PriceCalculationApi.PriceRequest();
    // Don't set postcode or segment
    
    PriceCalculationApi.PriceResponse emptyResponse = PriceCalculationApi.calculatePrice(emptyRequest);
    
    if (!emptyResponse.success) {
        System.debug('✅ Empty request correctly rejected: ' + emptyResponse.errorMessage);
    } else {
        System.debug('❌ Empty request was incorrectly accepted');
    }

} catch (Exception e) {
    System.debug('❌ Test failed with exception: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

System.debug('=== PRICE CALCULATION API TEST END ===');