@isTest
private class OpportunityLineItem_Pricing_Test {

    // Deze methode zet alle basisdata klaar die voor elke test nodig is
    @testSetup
    static void makeData(){
        // Maak een test Account en Opportunity aan
        Account testAccount = new Account(Name='Test Klant BV');
        insert testAccount;
        Opportunity testOpp = new Opportunity(
            Name = 'Test Opp Vloerkleed',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addMonths(1)
        );
        insert testOpp;
        
        // Maak een Vloerkleed Product aan
        Product2 vloerkleedProduct = new Product2(
            Name='Test Vloerkleed', 
            ProductCode='VLRK-TEST', 
            IsActive=true,
            Segment__c = 'Wasserij'
        );
        insert vloerkleedProduct;
        
        // Maak de prijsregel voor het vloerkleed
        Prijsmanagement__c vloerkleedRule = new Prijsmanagement__c(
            Product__c = vloerkleedProduct.Id,
            Eenheidsprijs__c = 30.00,
            Minimale_prijs__c = 100.00,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert vloerkleedRule;
        
        // Maak de verplichte standaard prijsboek-regel aan
        PricebookEntry standardPrice = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), 
            Product2Id = vloerkleedProduct.Id,
            UnitPrice = 1.00, // Dummy prijs, onze motor overschrijft dit
            IsActive = true
        );
        insert standardPrice;
    }

    @isTest
    static void testOppProductPriceCalculation() {
        // Haal de data op die we in @testSetup hebben klaargezet
        Opportunity testOpp = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Name='Test Opp Vloerkleed' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :vloerkleedProduct.Id AND Pricebook2Id = :Test.getStandardPricebookId() LIMIT 1];

        // Scenario: voeg een Opportunity Product toe van 2x3 meter
        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = testOpp.Id,
            PricebookEntryId = pbe.Id,
            Product2Id = vloerkleedProduct.Id,
            Quantity = 1, // Start met 1, onze motor moet dit aanpassen naar oppervlakte
            Lengte_cm__c = 200,
            Breedte_cm__c = 300
        );
        
        Test.startTest();
        insert oli;
        Test.stopTest();
        
        // Haal het resultaat op om te controleren
        OpportunityLineItem result = [SELECT Quantity, UnitPrice, TotalPrice, Oppervlakte_m__c FROM OpportunityLineItem WHERE Id =: oli.Id];
        
        // Controleer of de berekeningen kloppen
        System.assertEquals(6.00, result.Quantity, 'De Quantity (m²) is niet correct bijgewerkt.');
        System.assertEquals(30.00, result.UnitPrice, 'De UnitPrice (verkoopprijs) is niet correct berekend.');
        // Verwachting: Totaalprijs = 6 m² * €30/m² = €180
        System.assertEquals(180.00, result.TotalPrice, 'De TotalPrice voor het Opportunity Product is niet correct.');
    }
}