@isTest
public class PriceCalculationApi_Test {
    
    @TestSetup
    static void makeData() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test Postcode Range
        Postcode_Range__c postcodeRange = new Postcode_Range__c(
            Name = 'Amsterdam Test',
            Postcode_Begin__c = 1000,
            Postcode_Einde__c = 1099
        );
        insert postcodeRange;
        
        // Create test Service Association
        Dienstgebied_Postcode_Associatie__c association = new Dienstgebied_Postcode_Associatie__c(
            Postcode_Gebied__c = postcodeRange.Id,
            Segment__c = 'Wasserij',
            Afhandelingsmethode__c = 'Directe Prijs (Order)',
            Actief__c = true
        );
        insert association;
        
        // Create test Products
        Product2 primaryProduct = new Product2(
            Name = 'Test Vloerkleed Reiniging',
            ProductCode = 'VLRK-TEST-PRIM',
            IsActive = true,
            Primaryproduct__c = true,
            Segment__c = 'Wasserij',
            Oppervlakte_Berekening_Nodig__c = true,
            Bundelkorting_Toepasbaar__c = true,
            BTW__c = '21'
        );
        insert primaryProduct;
        
        Product2 extraProduct = new Product2(
            Name = 'Test Vezelbeschermer',
            ProductCode = 'VLRK-EX-TEST',
            IsActive = true,
            Primaryproduct__c = false,
            Segment__c = 'Wasserij',
            Gerelateerd_hoofdproduct__c = primaryProduct.Id,
            BTW__c = '21'
        );
        insert extraProduct;
        
        // Create pricing policy
        Prijsmanagement__c policy = new Prijsmanagement__c(
            Product__c = primaryProduct.Id,
            Eenheidsprijs__c = 29.50,
            Minimale_prijs__c = 110.00,
            Price_Type__c = 'Normaal',
            Actief__c = true,
            Geldig_vanaf__c = Date.today().addDays(-30),
            Geldig_tot__c = Date.today().addDays(30)
        );
        insert policy;
        
        // Create bundle discount rule
        // Note: This would typically be metadata, but for testing we assume it exists
    }
    
    @isTest
    static void testCalculatePrice_NoProducts_ReturnsProductCatalog() {
        // Arrange
        PriceCalculationApi.PriceRequest request = new PriceCalculationApi.PriceRequest();
        request.postcode = '1012AB';
        request.segment = 'Wasserij';
        request.products = new List<PriceCalculationApi.RequestLine>();
        
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        // Act
        PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice(request);
        
        Test.stopTest();
        
        // Assert
        System.assert(response.success, 'Response should be successful');
        System.assertEquals('Directe Prijs (Order)', response.afhandelingsmethode, 
                          'Should return correct handling method');
        System.assert(response.availableProducts != null && !response.availableProducts.isEmpty(), 
                     'Should return available products');
        
        // Find primary product in catalog
        Boolean foundPrimary = false;
        for (PriceCalculationApi.ResponseProduct prod : response.availableProducts) {
            if (prod.productCode == 'VLRK-TEST-PRIM') {
                foundPrimary = true;
                System.assert(prod.isPrimary, 'Primary product should be marked as primary');
                System.assert(prod.oppervlakteBerekenin__c, 'Should indicate area calculation needed');
                System.assert(prod.bundelkortingToepasbaar, 'Should indicate bundle discount applicable');
            }
        }
        System.assert(foundPrimary, 'Should find the test primary product in catalog');
    }
    
    @isTest
    static void testCalculatePrice_WithProducts_ReturnsCalculatedPrices() {
        // Arrange
        PriceCalculationApi.PriceRequest request = new PriceCalculationApi.PriceRequest();
        request.postcode = '1012AB';
        request.segment = 'Wasserij';
        request.products = new List<PriceCalculationApi.RequestLine>();
        
        PriceCalculationApi.RequestLine line = new PriceCalculationApi.RequestLine();
        line.productCode = 'VLRK-TEST-PRIM';
        line.quantity = 4.5; // 4.5 m²
        line.lengthCm = 200;
        line.widthCm = 225;
        request.products.add(line);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        // Act
        PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice(request);
        
        Test.stopTest();
        
        // Assert
        System.assert(response.success, 'Response should be successful: ' + response.errorMessage);
        System.assertEquals('Directe Prijs (Order)', response.afhandelingsmethode, 
                          'Should return correct handling method');
        System.assert(response.calculatedLines != null && !response.calculatedLines.isEmpty(), 
                     'Should return calculated lines');
        
        // Check first calculated line
        PriceCalculationApi.ResponseLine calcLine = response.calculatedLines[0];
        System.assertEquals('VLRK-TEST-PRIM', calcLine.productCode, 'Should match requested product');
        System.assertEquals(4.5, calcLine.oppervlakte, 'Should calculate correct area');
        System.assert(calcLine.verkoopprijs > 0, 'Should have calculated unit price');
        System.assert(calcLine.totalePrijs > 0, 'Should have calculated total price');
        
        // Check totals
        System.assert(response.subTotaal > 0, 'Should have positive subtotal');
        System.assert(response.btwTotaal > 0, 'Should have calculated BTW');
        System.assert(response.eindTotaal > response.subTotaal, 'Final total should include BTW');
        System.assert(String.isNotBlank(response.calculationId), 'Should have calculation ID');
    }
    
    @isTest
    static void testCalculatePrice_InvalidPostcode_ReturnsError() {
        // Arrange
        PriceCalculationApi.PriceRequest request = new PriceCalculationApi.PriceRequest();
        request.postcode = '9999AB'; // Non-existent postcode
        request.segment = 'Wasserij';
        request.products = new List<PriceCalculationApi.RequestLine>();
        
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        // Act
        PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice(request);
        
        Test.stopTest();
        
        // Assert
        System.assert(!response.success, 'Response should indicate failure');
        System.assert(response.errorMessage.contains('geen geschikte partner'), 
                     'Should return appropriate error message');
    }
    
    @isTest
    static void testCalculatePrice_MissingPostcode_ReturnsError() {
        // Arrange
        PriceCalculationApi.PriceRequest request = new PriceCalculationApi.PriceRequest();
        request.segment = 'Wasserij';
        request.products = new List<PriceCalculationApi.RequestLine>();
        
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        // Act
        PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice(request);
        
        Test.stopTest();
        
        // Assert
        System.assert(!response.success, 'Response should indicate failure');
        System.assert(response.errorMessage.contains('postcode is required'), 
                     'Should return appropriate validation error');
    }
    
    @isTest
    static void testCalculatePrice_WithExtraProducts_ReturnsRelatedCalculations() {
        // Arrange
        PriceCalculationApi.PriceRequest request = new PriceCalculationApi.PriceRequest();
        request.postcode = '1012AB';
        request.segment = 'Wasserij';
        request.products = new List<PriceCalculationApi.RequestLine>();
        
        // Primary product
        PriceCalculationApi.RequestLine primaryLine = new PriceCalculationApi.RequestLine();
        primaryLine.productCode = 'VLRK-TEST-PRIM';
        primaryLine.quantity = 4.0;
        primaryLine.lengthCm = 200;
        primaryLine.widthCm = 200;
        request.products.add(primaryLine);
        
        // Extra product
        PriceCalculationApi.RequestLine extraLine = new PriceCalculationApi.RequestLine();
        extraLine.productCode = 'VLRK-EX-TEST';
        extraLine.quantity = 4.0;
        extraLine.relatedProductCode = 'VLRK-TEST-PRIM';
        request.products.add(extraLine);
        
        // Set up REST context
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(JSON.serialize(request));
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        // Act
        PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice(request);
        
        Test.stopTest();
        
        // Assert
        System.assert(response.success, 'Response should be successful: ' + response.errorMessage);
        System.assertEquals(2, response.calculatedLines.size(), 'Should return both primary and extra lines');
        
        // Find primary and extra lines
        PriceCalculationApi.ResponseLine primaryResp = null;
        PriceCalculationApi.ResponseLine extraResp = null;
        
        for (PriceCalculationApi.ResponseLine line : response.calculatedLines) {
            if (line.productCode == 'VLRK-TEST-PRIM') {
                primaryResp = line;
            } else if (line.productCode == 'VLRK-EX-TEST') {
                extraResp = line;
            }
        }
        
        System.assertNotEquals(null, primaryResp, 'Should find primary product response');
        System.assertNotEquals(null, extraResp, 'Should find extra product response');
        System.assert(primaryResp.isPrimary, 'Primary product should be marked as primary');
        System.assert(!extraResp.isPrimary, 'Extra product should not be marked as primary');
        System.assertEquals('VLRK-TEST-PRIM', extraResp.relatedProductCode, 
                          'Extra should reference primary product');
    }
    
    @isTest 
    static void testCalculatePrice_NullRequest_ReturnsError() {
        // Set up REST context with null request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        // Act
        PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice(null);
        
        Test.stopTest();
        
        // Assert
        System.assert(!response.success, 'Response should indicate failure');
        System.assert(response.errorMessage.contains('request body is null'), 
                     'Should return appropriate error message');
        System.assert(String.isNotBlank(response.calculationId), 'Should still have calculation ID');
    }
}