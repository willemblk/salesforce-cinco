@isTest
private class PricingService_Test_Fixed {

    @testSetup
    static void makeData(){
        Product2 vloerkleedProduct = new Product2(
            Name='Test Vloerkleed',
            ProductCode='VLRK-TEST',
            IsActive=true,
            Segment__c = 'Wasserij',
            Selectie_Producttype__c = 'Primair'
        );
        insert vloerkleedProduct;

        Prijsmanagement__c vloerkleedRule = new Prijsmanagement__c(
            Product__c = vloerkleedProduct.Id,
            Eenheidsprijs__c = 24.38,
            Minimale_prijs__c = 90.91,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert vloerkleedRule;

        PricebookEntry standardPrice = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = vloerkleedProduct.Id,
            UnitPrice = 1.00,
            IsActive = true
        );
        insert standardPrice;

        Lead testLead = new Lead(LastName='Test Klant', Company='Test BV');
        insert testLead;
        
        // Setup voor Wasserij_Item tests
        Account testAccount = new Account(Name='Test Account');
        insert testAccount;
        
        Werk_Order__c testWerkOrder = new Werk_Order__c(Account__c = testAccount.Id);
        insert testWerkOrder;
    }

    @isTest
    static void testLeadProductBasicPricing() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        Lead_Product__c lp = new Lead_Product__c(
            Lead__c = testLead.Id, 
            Product__c = vloerkleedProduct.Id, 
            SKU__c = 'VLRK-TEST', 
            Lengte_cm__c = 100, 
            Breedte_cm__c = 100
        );
        
        Test.startTest();
        insert lp;
        Test.stopTest();
        
        Lead_Product__c result = [SELECT Totale_Prijs__c, Verkoopprijs__c FROM Lead_Product__c WHERE Id =: lp.Id];
        System.assertNotEquals(null, result.Totale_Prijs__c, 'Totale_Prijs should be calculated');
        System.assertNotEquals(null, result.Verkoopprijs__c, 'Verkoopprijs should be calculated');
    }

    @isTest
    static void testLeadProductRegioToeslag() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Update Lead met Amsterdam postcode voor regiotoeslag
        testLead.PostalCode = '1012 AB';
        update testLead;
        
        Test.startTest();
        
        Lead_Product__c leadProduct = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Aantal__c = 2
        );
        
        insert leadProduct;
        
        Test.stopTest();
        
        Lead_Product__c result = [
            SELECT Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c, Aantal__c
            FROM Lead_Product__c 
            WHERE Id = :leadProduct.Id
        ];
        
        // Basic validation
        System.assertNotEquals(null, result.Verkoopprijs__c, 'Verkoopprijs should be calculated');
        System.assertNotEquals(null, result.Totale_Prijs__c, 'Totale_Prijs should be calculated');
        
        // Basic validation: Totale_Prijs should be Verkoopprijs * Aantal  
        if (result.Verkoopprijs__c != null && result.Aantal__c != null) {
            Decimal expectedTotal = result.Verkoopprijs__c * result.Aantal__c;
            System.assertEquals(expectedTotal.setScale(2), result.Totale_Prijs__c.setScale(2), 
                               'Totale_Prijs should equal Verkoopprijs * Aantal');
        }
    }

    @isTest
    static void testLeadProductCrossItemUpdates() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Create eerste product
        Lead_Product__c firstProduct = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST-1',
            Lengte_cm__c = 100,
            Breedte_cm__c = 100  // 1m²
        );
        insert firstProduct;
        
        Test.startTest();
        
        // Create tweede product - dit zou cross-item updates moeten triggeren
        Lead_Product__c secondProduct = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST-2',
            Lengte_cm__c = 200,
            Breedte_cm__c = 200  // 4m²
        );
        insert secondProduct;
        
        Test.stopTest();
        
        // Query alle producten voor deze Lead
        List<Lead_Product__c> allProducts = [
            SELECT Id, SKU__c, Oppervlakte_m__c, Aantal__c, Verkoopprijs__c 
            FROM Lead_Product__c 
            WHERE Lead__c = :testLead.Id
        ];
        
        // Verify beide producten bestaan
        System.assertEquals(2, allProducts.size(), 'Should have 2 Lead Products');
        
        // Verify oppervlakte berekening
        for (Lead_Product__c lp : allProducts) {
            if (lp.Oppervlakte_m__c != null) {
                System.assertEquals(lp.Oppervlakte_m__c, lp.Aantal__c, 'Aantal should equal Oppervlakte for carpets');
            }
        }
    }

    @isTest
    static void testWasserijItemBasicPricing() {
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        
        // Maak Wasserij Item aan (vloerkleed) - ZONDER SKU__c
        Wasserij_Item__c wi = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 200,
            Breedte__c = 300
        );

        Test.startTest();
        insert wi;
        Test.stopTest();

        Wasserij_Item__c result = [
            SELECT Verkoopprijs__c, Totale_Prijs__c, Oppervlakte_m__c, Aantal__c
            FROM Wasserij_Item__c 
            WHERE Id = :wi.Id
        ];
        
        System.assertNotEquals(null, result.Verkoopprijs__c, 'Verkoopprijs should be calculated');
        System.assertNotEquals(null, result.Totale_Prijs__c, 'Totale_Prijs should be calculated');
    }
}