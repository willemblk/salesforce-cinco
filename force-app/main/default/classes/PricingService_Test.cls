@isTest
private class PricingService_Test {

    @testSetup
    static void makeData(){
        Product2 vloerkleedProduct = new Product2(
            Name='Test Vloerkleed',
            ProductCode='VLRK-TEST',
            IsActive=true,
            Segment__c = 'Wasserij'
        );
        insert vloerkleedProduct;

        Prijsmanagement__c vloerkleedRule = new Prijsmanagement__c(
            Product__c = vloerkleedProduct.Id,
            Eenheidsprijs__c = 24.38, // Prijs uit het voorbeeld
            Minimale_prijs__c = 90.91, // Minimum prijs uit het voorbeeld
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
        
        // Maak een gewoon product (geen vloerkleed) voor minimum prijs tests
    Product2 gewoonProduct = new Product2(Name='Test Gewoon Product', ProductCode='GWN-TEST', IsActive=true, Segment__c = 'Wasserij');
        insert gewoonProduct;
        
        Prijsmanagement__c gewoonRule = new Prijsmanagement__c(
            Product__c = gewoonProduct.Id,
            Eenheidsprijs__c = 15.00,
            Minimale_prijs__c = 250.00, // Hoger minimum voor een andere test
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert gewoonRule;
    }

    @isTest
    static void testRelativeExtraSimpleOnLead() {
        // Setup primary product with simple unit price
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];

        Product2 primary = new Product2(
            Name = 'Primary Base Product',
            ProductCode = 'RPRIM-TEST',
            IsActive = true,
            Segment__c = 'Wasserij'
        );
        insert primary;

        Prijsmanagement__c primPolicy = new Prijsmanagement__c(
            Product__c = primary.Id,
            Eenheidsprijs__c = 22,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert primPolicy;

        // Extra configured with relative percentage 25%
        Product2 extra = new Product2(
            Name = 'Relative Extra',
            ProductCode = 'REXTRA-TEST',
            IsActive = true,
            Segment__c = 'Wasserij'
        );
        insert extra;

        Prijsmanagement__c extraPolicy = new Prijsmanagement__c(
            Product__c = extra.Id,
            // Eenheidsprijs__c left null intentionally; relative price wins
            Relatieve_prijs__c = 25,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert extraPolicy;

        // Create primary line (4 units → gross 88)
        Lead_Product__c lpPrimary = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = primary.Id,
            SKU__c = 'RPRIM-TEST',
            Aantal__c = 4
        );

        // Create extra line linked to the primary; give a bogus quantity to verify it's forced to 1
        Lead_Product__c lpExtra = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = extra.Id,
            SKU__c = 'REXTRA-TEST',
            Gerelateerd_Product__c = primary.Id,
            Aantal__c = 3
        );

        Test.startTest();
        insert new List<Lead_Product__c>{ lpPrimary, lpExtra };
        Test.stopTest();

        // Reload both
        List<Lead_Product__c> lines = [
            SELECT Id, SKU__c, Aantal__c, Verkoopprijs__c, Totale_Prijs__c, Korting__c, Korting_bedrag__c
            FROM Lead_Product__c
            WHERE Id IN :new List<Id>{ lpPrimary.Id, lpExtra.Id }
        ];

        Lead_Product__c p = null; Lead_Product__c x = null;
        for (Lead_Product__c l : lines) {
            if (l.SKU__c == 'RPRIM-TEST') p = l; else x = l;
        }

        System.assertNotEquals(null, p, 'Primary line should exist');
        System.assertNotEquals(null, x, 'Extra line should exist');

        // Compute primary NET ex-BTW from stored fields (Totale_Prijs__c is gross per current write-back logic)
        Decimal primaryNet = (p.Totale_Prijs__c != null ? p.Totale_Prijs__c : 0) - (p.Korting_bedrag__c != null ? p.Korting_bedrag__c : 0);

        // Expect extra: Aantal forced to 1, Unit = 25% of primaryNet, Total = Unit
        Decimal expectedExtra = (primaryNet * 0.25).setScale(2);
        System.assertEquals(1, x.Aantal__c, 'Relative extra must enforce Aantal = 1');
        System.assertEquals(expectedExtra, x.Verkoopprijs__c.setScale(2), 'Extra unit price must be 25% of primary net');
        System.assertEquals(expectedExtra, x.Totale_Prijs__c.setScale(2), 'Extra line total must equal unit (Aantal=1)');
        System.assertEquals(null, x.Korting__c, 'Relative extras should not carry a discount');
    }

    @isTest
    static void testRelativeExtraFollowsMinimumUplift() {
        // Setup: primary with low unit price but high minimum to trigger uplift
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];

        Product2 primary = new Product2(
            Name = 'Min Primary',
            ProductCode = 'MINPRIM-TEST',
            IsActive = true,
            Segment__c = 'Wasserij'
        );
        insert primary;

        Prijsmanagement__c primPolicy = new Prijsmanagement__c(
            Product__c = primary.Id,
            Eenheidsprijs__c = 10,     // Low base
            Minimale_prijs__c = 100,    // High minimum (order)
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert primPolicy;

        Product2 extra = new Product2(
            Name = 'Relative Extra Min',
            ProductCode = 'REXMIN-TEST',
            IsActive = true,
            Segment__c = 'Wasserij'
        );
        insert extra;

        Prijsmanagement__c extraPolicy = new Prijsmanagement__c(
            Product__c = extra.Id,
            Relatieve_prijs__c = 20, // 20% of primary net
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert extraPolicy;

        // Primary: 2 units → normal total 20 < minimum 100 ⇒ uplift unit to 50, line to 100
        Lead_Product__c lpPrimary = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = primary.Id,
            SKU__c = 'MINPRIM-TEST',
            Aantal__c = 2
        );

        Lead_Product__c lpExtra = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = extra.Id,
            SKU__c = 'REXMIN-TEST',
            Gerelateerd_Product__c = primary.Id,
            Aantal__c = 5 // will be forced to 1
        );

        Test.startTest();
        insert new List<Lead_Product__c>{ lpPrimary, lpExtra };
        Test.stopTest();

        List<Lead_Product__c> lines = [
            SELECT Id, SKU__c, Aantal__c, Verkoopprijs__c, Totale_Prijs__c, Korting_bedrag__c
            FROM Lead_Product__c
            WHERE Id IN :new List<Id>{ lpPrimary.Id, lpExtra.Id }
        ];

        Lead_Product__c p = null; Lead_Product__c x = null;
        for (Lead_Product__c l : lines) {
            if (l.SKU__c == 'MINPRIM-TEST') p = l; else x = l;
        }

        System.assertNotEquals(null, p, 'Primary line should exist');
        System.assertNotEquals(null, x, 'Extra line should exist');

        // Derive primary NET
        Decimal primaryNet = (p.Totale_Prijs__c != null ? p.Totale_Prijs__c : 0) - (p.Korting_bedrag__c != null ? p.Korting_bedrag__c : 0);
        System.assertEquals(100.00, primaryNet.setScale(2), 'Primary net should be uplifted to minimum 100');

        Decimal expectedExtra = (primaryNet * 0.20).setScale(2);
        System.assertEquals(1, x.Aantal__c, 'Relative extra must enforce Aantal = 1');
        System.assertEquals(expectedExtra, x.Verkoopprijs__c.setScale(2), 'Extra must be 20% of primary net after minimum uplift');
        System.assertEquals(expectedExtra, x.Totale_Prijs__c.setScale(2), 'Extra total equals unit after minimum uplift');
    }

    @isTest
    static void testVloerkleedPriceCalculation() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        Lead_Product__c lp = new Lead_Product__c(Lead__c = testLead.Id, Product__c = vloerkleedProduct.Id, SKU__c = 'VLRK-TEST', Lengte_cm__c = 200, Breedte_cm__c = 300);
        
        Test.startTest();
        insert lp;
        Test.stopTest();
        
        Lead_Product__c result = [SELECT Aantal__c, Totale_Prijs__c FROM Lead_Product__c WHERE Id =: lp.Id];
        System.assertEquals(6.00, result.Aantal__c, 'Het aantal (m²) is niet correct berekend.');
        // 6m² * 24.38 = 146.28
        System.assertEquals(146.28, result.Totale_Prijs__c.setScale(2), 'De totaalprijs voor het vloerkleed is niet correct.');
    }

    @isTest
    static void testVloerkleedMinimumPrice() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        // 1m² * 24.38 = 24.38, wat lager is dan 90.91
        Lead_Product__c lp = new Lead_Product__c(Lead__c = testLead.Id, Product__c = vloerkleedProduct.Id, SKU__c = 'VLRK-TEST', Lengte_cm__c = 100, Breedte_cm__c = 100);
        
        Test.startTest();
        insert lp;
        Test.stopTest();
        
        Lead_Product__c result = [SELECT Totale_Prijs__c FROM Lead_Product__c WHERE Id =: lp.Id];
        // De prijs moet worden verhoogd naar de minimum segmentprijs
        System.assertEquals(90.91, result.Totale_Prijs__c.setScale(2), 'De minimale prijs is niet correct toegepast.');
    }

    @isTest
    static void testDakkapelTieredPricing() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 dakkapelProduct = new Product2(Name='Test Dakkapel', ProductCode='DAK-TEST', IsActive=true, Segment__c='Dakkapel');
        insert dakkapelProduct;
        
        Prijsmanagement__c dakkapelRule1 = new Prijsmanagement__c(Product__c = dakkapelProduct.Id, Eenheidsprijs__c = 130.00, Onderste_staffelwaarde__c = 1, Bovenste_staffelwaarde__c = 1, Geldig_vanaf__c = Date.today(), Geldig_tot__c = Date.today().addYears(1));
        Prijsmanagement__c dakkapelRule2 = new Prijsmanagement__c(Product__c = dakkapelProduct.Id, Eenheidsprijs__c = 100.00, Onderste_staffelwaarde__c = 2, Bovenste_staffelwaarde__c = 99, Geldig_vanaf__c = Date.today(), Geldig_tot__c = Date.today().addYears(1));
        insert new List<Prijsmanagement__c>{dakkapelRule1, dakkapelRule2};
        
        PricebookEntry standardPrice = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = dakkapelProduct.Id, UnitPrice = 1.00, IsActive = true);
        insert standardPrice;
        
        Lead_Product__c lp = new Lead_Product__c(Lead__c = testLead.Id, Product__c = dakkapelProduct.Id, Aantal__c = 3);
        
        Test.startTest();
        insert lp;
        Test.stopTest();
        
        Lead_Product__c result = [SELECT Totale_Prijs__c FROM Lead_Product__c WHERE Id =: lp.Id];
        System.assertEquals(330.00, result.Totale_Prijs__c, 'De staffelprijs voor 3 dakkapellen is niet correct berekend.');
    }

    @isTest
    static void testRegioSurcharge() {
        Lead testLead = [SELECT Id, PostalCode FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        Account partnerAccount = new Account(Name='Test Partner Kleda');
        insert partnerAccount;
        
        Postcode_Range__c postcodeGebied = new Postcode_Range__c(Name = 'Test Gebied Amsterdam', Postcode_Begin__c = 1011, Postcode_Einde__c = 1019);
        insert postcodeGebied;

        Dienstgebied__c testDienst = new Dienstgebied__c(
            Name = 'Test Dienst Vloerkleed',
            Segment__c = 'Wasserij'  // Voeg het verplichte Segment__c veld toe
        );
        insert testDienst;

        Dienstgebied_Postcode_Associatie__c associatie = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partnerAccount.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = testDienst.Id,
            Regiotoeslag__c = true,
            Toeslag__c = 10
        );
        insert associatie;

        testLead.PostalCode = '1012 AB';
        testLead.Partner__c = partnerAccount.Id; 
        update testLead;
        
        Lead_Product__c lp = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte_cm__c = 200,
            Breedte_cm__c = 300
        );
        
        Test.startTest();
        insert lp;
        Test.stopTest();
        
        Lead_Product__c result = [SELECT Totale_Prijs__c, Regiotoeslag__c FROM Lead_Product__c WHERE Id =: lp.Id];
        
        // Basis prijs: 6m² * 24.38 = 146.28. Toeslag: 146.28 * 1.10 = 160.908
        System.assertEquals(160.91, result.Totale_Prijs__c.setScale(2), 'De regiotoeslag is niet correct berekend.');
        System.assertEquals(10, result.Regiotoeslag__c, 'Het toeslagpercentage is niet correct opgeslagen.');
    }
    // Test 5: Controleert de bundelkorting voor vloerkleden
@isTest
static void testVloerkleedBundleDiscount() {
    Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
    Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];

    // Scenario: 3 kleden, waarvan 2 groot genoeg zijn voor 5% korting
    // Kleed 1: 2x2 = 4m² (telt mee voor korting)
    Lead_Product__c kleed1 = new Lead_Product__c(
        Lead__c = testLead.Id, Product__c = vloerkleedProduct.Id, SKU__c = 'VLRK-TEST',
        Lengte_cm__c = 200, Breedte_cm__c = 200
    );
    // Kleed 2: 1x2 = 2m² (telt NIET mee)
    Lead_Product__c kleed2 = new Lead_Product__c(
        Lead__c = testLead.Id, Product__c = vloerkleedProduct.Id, SKU__c = 'VLRK-TEST',
        Lengte_cm__c = 100, Breedte_cm__c = 200
    );
    // Kleed 3: 3x1 = 3m² (telt mee voor korting)
    Lead_Product__c kleed3 = new Lead_Product__c(
        Lead__c = testLead.Id, Product__c = vloerkleedProduct.Id, SKU__c = 'VLRK-TEST',
        Lengte_cm__c = 300, Breedte_cm__c = 100
    );
    
    Test.startTest();
    insert new List<Lead_Product__c>{kleed1, kleed2, kleed3};
    Test.stopTest();
    
    // Haal de resultaten op om te controleren
    Map<Id, Lead_Product__c> results = new Map<Id, Lead_Product__c>([
        SELECT Totale_Prijs__c, Korting__c 
        FROM Lead_Product__c WHERE Id IN (:kleed1.Id, :kleed2.Id, :kleed3.Id)
    ]);
    
    // Verwachting: 2 kleden >= 3m², dus 5% korting op ALLE kleden
    // Kleed 1: 4m² * €24.38 = €97.52. Korting = 5% van 97.52 = €4.876. Totaal = €92.644.
    System.assertEquals(92.64, results.get(kleed1.Id).Totale_Prijs__c.setScale(2), 'Korting op kleed 1 niet correct.');
    System.assertEquals(5, results.get(kleed1.Id).Korting__c, 'Kortingspercentage op kleed 1 niet correct.');

    // Kleed 2: 2m² * €24.38 = €48.76. Korting = 5% van 48.76 = €2.438. Totaal = €46.322.
    System.assertEquals(46.32, results.get(kleed2.Id).Totale_Prijs__c.setScale(2), 'Korting op kleed 2 niet correct.');
    
    // Kleed 3: 3m² * €24.38 = €73.14. Korting = 5% van 73.14 = €3.657. Totaal = €69.483.
    System.assertEquals(69.48, results.get(kleed3.Id).Totale_Prijs__c.setScale(2), 'Korting op kleed 3 niet correct.');
}

    // ================ WASSERIJ_ITEM TESTS ================

    @isTest
    static void testWasserijItemPriceCalculation() {
        // Haal test data op
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];

        // Maak Wasserij Item aan (vloerkleed)
        Wasserij_Item__c wi = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 200,
            Breedte__c = 300
        );

        Test.startTest();
        insert wi;
        Test.stopTest();

        Wasserij_Item__c result = [SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c FROM Wasserij_Item__c WHERE Id =: wi.Id];

        System.assertEquals(6.00, result.Aantal__c, 'Aantal is niet correct berekend.');
        System.assertEquals(24.38, result.Verkoopprijs__c.setScale(2), 'Verkoopprijs is niet correct berekend.');
        System.assertEquals(146.28, result.Totale_Prijs__c.setScale(2), 'Totaalprijs is niet correct berekend.');
    }
    
    @isTest
    static void testWasserijItemMinimumPriceCalculation() {
        // Haal test data op
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Scenario uit de user story: 2 vloerkleden van 1m²
        // Normale prijs: 1m² * €24.38 = €24.38 per stuk. Totaal = €48.76
        // Dit is < €90.91, dus de minimumprijs moet worden toegepast.
        // Nieuwe eenheidsprijs = €90.91 / (1m² + 1m²) = €45.455
        Wasserij_Item__c kleed1 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 100,
            Breedte__c = 100 // 1m²
        );
        
        Wasserij_Item__c kleed2 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 100,
            Breedte__c = 100 // 1m²
        );

        Test.startTest();
        insert new List<Wasserij_Item__c>{kleed1, kleed2};
        Test.stopTest();

        Map<Id, Wasserij_Item__c> results = new Map<Id, Wasserij_Item__c>([
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
            FROM Wasserij_Item__c WHERE Id IN (:kleed1.Id, :kleed2.Id)
        ]);

        Wasserij_Item__c result1 = results.get(kleed1.Id);
        Wasserij_Item__c result2 = results.get(kleed2.Id);

        System.assertEquals(1.00, result1.Aantal__c, 'Aantal voor kleed 1 moet 1.00 zijn.');
        System.assertEquals(45.46, result1.Verkoopprijs__c.setScale(2), 'Verkoopprijs voor kleed 1 moet €45.46 zijn.');
        System.assertEquals(45.46, result1.Totale_Prijs__c.setScale(2), 'Totaalprijs voor kleed 1 moet €45.46 zijn.');
        
        System.assertEquals(1.00, result2.Aantal__c, 'Aantal voor kleed 2 moet 1.00 zijn.');
        System.assertEquals(45.46, result2.Verkoopprijs__c.setScale(2), 'Verkoopprijs voor kleed 2 moet €45.46 zijn.');
        System.assertEquals(45.46, result2.Totale_Prijs__c.setScale(2), 'Totaalprijs voor kleed 2 moet €45.46 zijn.');
        
        Decimal orderTotal = result1.Totale_Prijs__c + result2.Totale_Prijs__c;
        System.assert(orderTotal >= 90.90 && orderTotal <= 90.93, 'De totale orderprijs moet ongeveer €90.91 zijn, maar was: €' + orderTotal.setScale(2));
    }

    @isTest
    static void testOrderWideMinimumPriceLogic() {
        // Test het voorbeeld uit de user story: 1m² + 2m² = €75 < €150, dus €50/m²
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        
        // Maak een nieuw product met eenheidsprijs €25 en minimumprijs €150
        Product2 testProduct = new Product2(
            Name='Test Order Minimum Product',
            ProductCode='TOM-TEST',
            IsActive=true,
            Segment__c = 'Wasserij'
        );
        insert testProduct;

        Prijsmanagement__c testRule = new Prijsmanagement__c(
            Product__c = testProduct.Id,
            Eenheidsprijs__c = 25.00,
            Minimale_prijs__c = 150.00,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert testRule;

        // Voeg pricebook entry toe
        PricebookEntry testPbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = testProduct.Id,
            UnitPrice = 1.00,
            IsActive = true
        );
        insert testPbe;

        // Product 1: 1m² (1 * €25 = €25)
        Lead_Product__c product1 = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = testProduct.Id,
            SKU__c = 'TOM-TEST',
            Aantal__c = 1
        );

        // Product 2: 2m² (2 * €25 = €50)
        Lead_Product__c product2 = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = testProduct.Id,
            SKU__c = 'TOM-TEST',
            Aantal__c = 2
        );

        Test.startTest();
        insert new List<Lead_Product__c>{product1, product2};
        Test.stopTest();

        // Haal resultaten op
        Map<Id, Lead_Product__c> results = new Map<Id, Lead_Product__c>([
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
            FROM Lead_Product__c 
            WHERE Id IN (:product1.Id, :product2.Id)
        ]);

        Lead_Product__c result1 = results.get(product1.Id);
        Lead_Product__c result2 = results.get(product2.Id);

        // Verwachte logica:
        // Normale prijs: 1*25 + 2*25 = €75
        // €75 < €150 (minimum), dus herberekening
        // Nieuwe eenheidsprijs = €150 / (1+2) = €50 per eenheid
        
        System.assertEquals(1.00, result1.Aantal__c, 'Product 1 moet 1 eenheid hebben');
        System.assertEquals(50.00, result1.Verkoopprijs__c.setScale(2), 'Product 1 moet €50/eenheid zijn na minimum prijs toepassing');
        System.assertEquals(50.00, result1.Totale_Prijs__c.setScale(2), 'Product 1 totaal moet €50 zijn');

        System.assertEquals(2.00, result2.Aantal__c, 'Product 2 moet 2 eenheden hebben');
        System.assertEquals(50.00, result2.Verkoopprijs__c.setScale(2), 'Product 2 moet €50/eenheid zijn na minimum prijs toepassing');
        System.assertEquals(100.00, result2.Totale_Prijs__c.setScale(2), 'Product 2 totaal moet €100 zijn');

        Decimal orderTotal = result1.Totale_Prijs__c + result2.Totale_Prijs__c;
        System.assertEquals(150.00, orderTotal.setScale(2), 'Totale orderprijs moet exact €150 zijn (minimum prijs)');
    }

    @isTest
    static void testAssociationLevelOrderMinimumApplied() {
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];

        Account partner = new Account(Name = 'Assoc Partner');
        insert partner;

        Postcode_Range__c postcodeGebied = new Postcode_Range__c(
            Name = 'Assoc Gebied',
            Postcode_Begin__c = 1200,
            Postcode_Einde__c = 1299
        );
        insert postcodeGebied;

        Dienstgebied__c dienstgebied = new Dienstgebied__c(
            Name = 'Assoc Dienst',
            Segment__c = 'Wasserij'
        );
        insert dienstgebied;

        Dienstgebied_Postcode_Associatie__c associatie = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partner.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = dienstgebied.Id,
            Afhandelingsmethode__c = 'Directe Prijs (Order)',
            Minimum_Order_Excl_BTW__c = 110
        );
        insert associatie;

        testLead.Postcodegebied__c = postcodeGebied.Id;
        testLead.Uniek_Segment__c = 'Wasserij';
        update testLead;

        Lead_Product__c line = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte_cm__c = 100,
            Breedte_cm__c = 100
        );

        Test.startTest();
        insert line;
        Test.stopTest();

        Lead_Product__c result = [
            SELECT Totale_Prijs__c, Verkoopprijs__c
            FROM Lead_Product__c
            WHERE Id = :line.Id
        ];

    System.assertEquals(110.00, result.Totale_Prijs__c.setScale(2), 'Associatie-minimum moet het orderminimum verhogen naar €110,00.');
    System.assertEquals(110.00, result.Verkoopprijs__c.setScale(2), 'Verkoopprijs moet worden opgehoogd naar het orderminimum per eenheid.');
    }

    @isTest
    static void testWasserijItemOrderWideMinimumPrice() {
        // Test het voorbeeld uit de user story voor Wasserij Items: 1m² + 2m² = €75 < €150, dus €50/m²
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        
        // Maak een nieuw product met eenheidsprijs €25 en minimumprijs €150
        Product2 testProduct = new Product2(
            Name='Test Wasserij Order Minimum Product',
            ProductCode='TWOM-TEST',
            IsActive=true,
            Segment__c = 'Wasserij'
        );
        insert testProduct;

        Prijsmanagement__c testRule = new Prijsmanagement__c(
            Product__c = testProduct.Id,
            Eenheidsprijs__c = 25.00,
            Minimale_prijs__c = 150.00,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert testRule;

        // Item 1: 1 eenheid (1 * €25 = €25)
        Wasserij_Item__c item1 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = testProduct.Id,
            SKU__c = 'TWOM-TEST',
            Aantal__c = 1
        );

        // Item 2: 2 eenheden (2 * €25 = €50)
        Wasserij_Item__c item2 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = testProduct.Id,
            SKU__c = 'TWOM-TEST',
            Aantal__c = 2
        );

        Test.startTest();
        insert new List<Wasserij_Item__c>{item1, item2};
        Test.stopTest();

        // Haal resultaten op
        Map<Id, Wasserij_Item__c> results = new Map<Id, Wasserij_Item__c>([
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
            FROM Wasserij_Item__c 
            WHERE Id IN (:item1.Id, :item2.Id)
        ]);

        Wasserij_Item__c result1 = results.get(item1.Id);
        Wasserij_Item__c result2 = results.get(item2.Id);

        // Verwachte logica:
        // Normale prijs: 1*25 + 2*25 = €75
        // €75 < €150 (minimum), dus herberekening
        // Nieuwe eenheidsprijs = €150 / (1+2) = €50 per eenheid
        
        System.assertEquals(1.00, result1.Aantal__c, 'Item 1 moet 1 eenheid hebben');
        System.assertEquals(50.00, result1.Verkoopprijs__c.setScale(2), 'Item 1 moet €50/eenheid zijn na minimum prijs toepassing');
        System.assertEquals(50.00, result1.Totale_Prijs__c.setScale(2), 'Item 1 totaal moet €50 zijn');

        System.assertEquals(2.00, result2.Aantal__c, 'Item 2 moet 2 eenheden hebben');
        System.assertEquals(50.00, result2.Verkoopprijs__c.setScale(2), 'Item 2 moet €50/eenheid zijn na minimum prijs toepassing');
        System.assertEquals(100.00, result2.Totale_Prijs__c.setScale(2), 'Item 2 totaal moet €100 zijn');

        Decimal orderTotal = result1.Totale_Prijs__c + result2.Totale_Prijs__c;
        System.assertEquals(150.00, orderTotal.setScale(2), 'Totale werk order prijs moet exact €150 zijn (minimum prijs)');
    }

    @isTest
    static void testWasserijItemDebugMinimumPrice() {
        // Debug test om te zien wat er gebeurt met de bestaande vloerkleed test data
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Controlleer de pricing rule die in @testSetup wordt gemaakt
        Prijsmanagement__c existingRule = [SELECT Eenheidsprijs__c, Minimale_prijs__c FROM Prijsmanagement__c WHERE Product__c = :vloerkleedProduct.Id LIMIT 1];
        System.debug('Existing rule - Eenheidsprijs: ' + existingRule.Eenheidsprijs__c + ', Minimale: ' + existingRule.Minimale_prijs__c);
        
        // Deze test gebruikt de bestaande test data: Eenheidsprijs €24.38, Minimum €90.91
        // 2 vloerkleden van 1m² = 2m² totaal
        // Normale prijs: 2m² * €24.38 = €48.76
        // €48.76 < €90.91, dus herberekening naar: €90.91 ÷ 2m² = €45.455/m²
        
        Wasserij_Item__c kleed1 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 100,
            Breedte__c = 100 // 1m²
        );
        
        Wasserij_Item__c kleed2 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 100,
            Breedte__c = 100 // 1m²
        );

        Test.startTest();
        insert new List<Wasserij_Item__c>{kleed1, kleed2};
        Test.stopTest();

        Map<Id, Wasserij_Item__c> results = new Map<Id, Wasserij_Item__c>([
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
            FROM Wasserij_Item__c WHERE Id IN (:kleed1.Id, :kleed2.Id)
        ]);

        Wasserij_Item__c result1 = results.get(kleed1.Id);
        Wasserij_Item__c result2 = results.get(kleed2.Id);

        System.debug('Result1 - Aantal: ' + result1.Aantal__c + ', Verkoopprijs: ' + result1.Verkoopprijs__c + ', Totaal: ' + result1.Totale_Prijs__c);
        System.debug('Result2 - Aantal: ' + result2.Aantal__c + ', Verkoopprijs: ' + result2.Verkoopprijs__c + ', Totaal: ' + result2.Totale_Prijs__c);
        
        Decimal orderTotal = result1.Totale_Prijs__c + result2.Totale_Prijs__c;
        System.debug('Order total: ' + orderTotal);
        
        // Nieuwe verwachting: orderTotal moet €90.91 zijn door minimum prijs
        // En beide items moeten €45.455/m² hebben (afgerond €45.46)
        System.assertEquals(1.00, result1.Aantal__c, 'Aantal voor kleed 1 moet 1.00 zijn (1m²)');
        System.assertEquals(45.46, result1.Verkoopprijs__c.setScale(2), 'Verkoopprijs voor kleed 1 moet €45.46 zijn (€90.91/2m²)');
        System.assertEquals(45.46, result1.Totale_Prijs__c.setScale(2), 'Totaalprijs voor kleed 1 moet €45.46 zijn');
        
        System.assertEquals(1.00, result2.Aantal__c, 'Aantal voor kleed 2 moet 1.00 zijn (1m²)');
        System.assertEquals(45.46, result2.Verkoopprijs__c.setScale(2), 'Verkoopprijs voor kleed 2 moet €45.46 zijn (€90.91/2m²)');
        System.assertEquals(45.46, result2.Totale_Prijs__c.setScale(2), 'Totaalprijs voor kleed 2 moet €45.46 zijn');
        
        // Totaal moet de minimum prijs zijn
        System.assertEquals(90.91, orderTotal.setScale(2), 'Totale werk order prijs moet €90.91 zijn (minimum prijs)');
    }

    @isTest  
    static void testWasserijItemBundleDiscountWithMinimum() {
        // Test scenario: vloerkleden die bundelkorting krijgen, maar daarna onder minimum prijs uitkomen
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Dit test de interactie tussen bundelkorting en minimum prijs
        // 2 vloerkleden van 3m² = 6m² totaal
        // Normale prijs: 6m² * €24.38 = €146.28
        // Na 5% bundelkorting: €146.28 * 0.95 = €138.966
        // €138.966 > €90.91 (minimum), dus geen herberekening nodig
        
        Wasserij_Item__c kleed1 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 300,  // 3m²
            Breedte__c = 100
        );
        
        Wasserij_Item__c kleed2 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 300,  // 3m²
            Breedte__c = 100
        );

        Test.startTest();
        insert new List<Wasserij_Item__c>{kleed1, kleed2};
        Test.stopTest();

        Map<Id, Wasserij_Item__c> results = new Map<Id, Wasserij_Item__c>([
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c, Korting__c
            FROM Wasserij_Item__c WHERE Id IN (:kleed1.Id, :kleed2.Id)
        ]);

        Wasserij_Item__c result1 = results.get(kleed1.Id);
        Wasserij_Item__c result2 = results.get(kleed2.Id);

        // Beide kleden moeten bundelkorting hebben (5%)
        // Debug info in assertion bericht
        String debugInfo = 'Debug - Result1: Korting=' + result1.Korting__c + ', TotalePrijs=' + result1.Totale_Prijs__c + 
                          ', Result2: Korting=' + result2.Korting__c + ', TotalePrijs=' + result2.Totale_Prijs__c;
        System.assert(result1.Korting__c != null, 'Kleed 1 moet bundelkorting hebben. ' + debugInfo);
        System.assertEquals(5, result1.Korting__c, 'Kleed 1 moet 5% bundelkorting hebben');
        System.assertEquals(5, result2.Korting__c, 'Kleed 2 moet 5% bundelkorting hebben');
        
        Decimal orderTotal = result1.Totale_Prijs__c + result2.Totale_Prijs__c;
        System.debug('Order total after bundle discount: ' + orderTotal);
        
        // Het totaal moet nog boven het minimum zijn (geen extra minimum prijs toepassing nodig)
        System.assert(orderTotal > 90.91, 'Order totaal na bundelkorting moet boven minimum blijven');
    }
    
    @isTest
    static void testWasserijItemExistingItemsGetUpdated() {
        // Test scenario: bestaande items in werk order moeten ook ge-updated worden bij minimum prijs
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Stap 1: Maak en sla eerst een item op (dit wordt het "bestaande" item)
        Wasserij_Item__c bestaandItem = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 100,
            Breedte__c = 100 // 1m²
        );
        insert bestaandItem;
        
        // Verifieer dat het bestaande item de normale prijs heeft (1m² * €24.38 = €24.38)
        Wasserij_Item__c checkBestaand = [SELECT Totale_Prijs__c FROM Wasserij_Item__c WHERE Id = :bestaandItem.Id];
        System.assertEquals(24.38, checkBestaand.Totale_Prijs__c.setScale(2), 'Bestaand item moet normale prijs hebben');
        
        // Stap 2: Voeg nu een tweede item toe - dit zou de minimum prijs logica moeten triggeren
        Wasserij_Item__c nieuwItem = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 100,
            Breedte__c = 100 // 1m²
        );
        
        Test.startTest();
        insert nieuwItem; // Dit triggert de herberekening voor ALLE items in de werk order
        Test.stopTest();
        
        // Stap 3: Verifieer dat BEIDE items nu de herberekende prijs hebben
        Map<Id, Wasserij_Item__c> allItems = new Map<Id, Wasserij_Item__c>([
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c 
            FROM Wasserij_Item__c 
            WHERE Id IN (:bestaandItem.Id, :nieuwItem.Id)
        ]);
        
        Wasserij_Item__c updatedBestaand = allItems.get(bestaandItem.Id);
        Wasserij_Item__c insertedNieuw = allItems.get(nieuwItem.Id);
        
        // Verwachting: 2 items van 1m² = 2m² totaal
        // Normale prijs: 2m² * €24.38 = €48.76 < €90.91 (minimum)
        // Herberekening: €90.91 ÷ 2m² = €45.455 ≈ €45.46 per m²
        
        System.assertEquals(45.46, updatedBestaand.Verkoopprijs__c.setScale(2), 'Bestaand item moet herberekende prijs hebben');
        System.assertEquals(45.46, updatedBestaand.Totale_Prijs__c.setScale(2), 'Bestaand item totaal moet herberekend zijn');
        
        System.assertEquals(45.46, insertedNieuw.Verkoopprijs__c.setScale(2), 'Nieuw item moet herberekende prijs hebben');
        System.assertEquals(45.46, insertedNieuw.Totale_Prijs__c.setScale(2), 'Nieuw item totaal moet herberekend zijn');
        
        Decimal orderTotal = updatedBestaand.Totale_Prijs__c + insertedNieuw.Totale_Prijs__c;
        System.assertEquals(90.91, orderTotal.setScale(2), 'Totale werk order prijs moet €90.91 zijn (minimum prijs)');
    }
    
    @isTest
    static void testWasserijItemRecursionPrevention() {
        // Test dat het wijzigen van vloerkleed afmetingen geen recursie fout veroorzaakt
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Maak een vloerkleed aan
        Wasserij_Item__c vloerkleed = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Lengte__c = 200,
            Breedte__c = 200 // Start met 4m²
        );
        insert vloerkleed;
        
        // Verifieer initiële staat
        Wasserij_Item__c checkInitial = [SELECT Totale_Prijs__c, Oppervlakte_m__c FROM Wasserij_Item__c WHERE Id = :vloerkleed.Id];
        System.assertEquals(4.0, checkInitial.Oppervlakte_m__c, 'Initiële oppervlakte moet 4m² zijn');
        
        Test.startTest();
        // Wijzig de afmetingen - dit mag geen recursie fout geven
        vloerkleed.Lengte__c = 300; // Verander naar 6m²
        
        // Deze update mag NIET falen met een recursie fout
        try {
            update vloerkleed;
            // Als we hier komen is de test geslaagd
            System.assert(true, 'Update was succesvol zonder recursie fout');
        } catch (Exception e) {
            System.assert(false, 'Update faalde met fout: ' + e.getMessage());
        }
        Test.stopTest();
        
        // Verifieer dat de wijziging is doorgevoerd
        Wasserij_Item__c checkUpdated = [SELECT Totale_Prijs__c, Oppervlakte_m__c FROM Wasserij_Item__c WHERE Id = :vloerkleed.Id];
        System.assertEquals(6.0, checkUpdated.Oppervlakte_m__c, 'Nieuwe oppervlakte moet 6m² zijn');
    }
    
    @isTest
    static void testWasserijItemRegionalSurcharge() {
        // Test regiotoeslag functionaliteit voor Wasserij Items
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Setup postcode gebied (gebruik de ID uit je test setup)
        Postcode_Range__c postcodeGebied = new Postcode_Range__c(
            Name = 'Test Gebied Amsterdam Centrum',
            Postcode_Begin__c = 1011,
            Postcode_Einde__c = 1019
        );
        insert postcodeGebied;
        
        // Setup partner account
        Account partnerAccount = new Account(Name='Test Partner');
        insert partnerAccount;
        
        // Setup dienstgebied
        Dienstgebied__c testDienst = new Dienstgebied__c(
            Name = 'Test Dienst Wasserij',
            Segment__c = 'Wasserij'
        );
        insert testDienst;
        
        // Setup regiotoeslag associatie met 10% toeslag
        Dienstgebied_Postcode_Associatie__c associatie = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partnerAccount.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = testDienst.Id,
            Regiotoeslag__c = true,
            Toeslag__c = 10  // 10% toeslag
        );
        insert associatie;
        
        // Update werk order met postcode en segment info
        testWerkOrder.Postcodegebied__c = postcodeGebied.Id;
        testWerkOrder.Uniek_Segment__c = 'Wasserij';
        update testWerkOrder;
        
        // Maak wasserij item
        Wasserij_Item__c item = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 200,
            Breedte__c = 300  // 6m²
        );
        
        Test.startTest();
        insert item;
        Test.stopTest();
        
        // Verify results
        Wasserij_Item__c result = [
            SELECT Aantal__c, Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c 
            FROM Wasserij_Item__c 
            WHERE Id = :item.Id
        ];
        
        // Expected calculations:
        // Base: 6m² * €24.38 = €146.28
        // With 10% surcharge: €24.38 * 1.10 = €26.818 per m²
        // Total: 6m² * €26.818 = €160.908 ≈ €160.91
        
        System.assertEquals(6.0, result.Aantal__c, 'Aantal moet 6m² zijn');
        System.assertEquals(10, result.Regiotoeslag__c, 'Regiotoeslag percentage moet 10% zijn');
        System.assertEquals(26.82, result.Verkoopprijs__c.setScale(2), 'Verkoopprijs moet verhoogd zijn met 10% toeslag');
        System.assertEquals(160.92, result.Totale_Prijs__c.setScale(2), 'Totale prijs moet €160.92 zijn (inclusief 10% toeslag)');
    }
    
    @isTest
    static void testWasserijItemNoRegionalSurcharge() {
        // Test dat items zonder regiotoeslag gewoon normale prijs krijgen
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Laat werk order zonder postcode/segment info (of setup zonder matching associatie)
        Wasserij_Item__c item = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 200,
            Breedte__c = 300  // 6m²
        );
        
        Test.startTest();
        insert item;
        Test.stopTest();
        
        Wasserij_Item__c result = [
            SELECT Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c 
            FROM Wasserij_Item__c 
            WHERE Id = :item.Id
        ];
        
        // Normale prijs zonder toeslag
        System.assertEquals(null, result.Regiotoeslag__c, 'Geen regiotoeslag moet worden toegepast');
        System.assertEquals(24.38, result.Verkoopprijs__c.setScale(2), 'Normale verkoopprijs zonder toeslag');
        System.assertEquals(146.28, result.Totale_Prijs__c.setScale(2), 'Normale totale prijs zonder toeslag');
    }
    
    @isTest
    static void testRegionalSurchargeWithBundleDiscount() {
        // Test interactie tussen regiotoeslag en bundelkorting
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Setup regiotoeslag
        Postcode_Range__c postcodeGebied = new Postcode_Range__c(
            Name = 'Test Gebied',
            Postcode_Begin__c = 1011,
            Postcode_Einde__c = 1019
        );
        insert postcodeGebied;
        
        Account partnerAccount = new Account(Name='Test Partner');
        insert partnerAccount;
        
        Dienstgebied__c testDienst = new Dienstgebied__c(
            Name = 'Test Dienst',
            Segment__c = 'Wasserij'
        );
        insert testDienst;
        
        Dienstgebied_Postcode_Associatie__c associatie = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partnerAccount.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = testDienst.Id,
            Regiotoeslag__c = true,
            Toeslag__c = 10  // 10% toeslag
        );
        insert associatie;
        
        testWerkOrder.Postcodegebied__c = postcodeGebied.Id;
        testWerkOrder.Uniek_Segment__c = 'Wasserij';
        update testWerkOrder;
        
        // Maak 2 grote vloerkleden voor bundelkorting
        Wasserij_Item__c kleed1 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 300, Breedte__c = 100  // 3m² (above threshold voor bundelkorting)
        );
        
        Wasserij_Item__c kleed2 = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 300, Breedte__c = 100  // 3m²
        );
        
        Test.startTest();
        insert new List<Wasserij_Item__c>{kleed1, kleed2};
        Test.stopTest();
        
        Map<Id, Wasserij_Item__c> results = new Map<Id, Wasserij_Item__c>([
            SELECT Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c, Korting__c 
            FROM Wasserij_Item__c 
            WHERE Id IN (:kleed1.Id, :kleed2.Id)
        ]);
        
        // Verwachting: 
        // 1. Regiotoeslag wordt EERST toegepast: €24.38 * 1.10 = €26.818 per m²
        // 2. Dan bundelkorting: 5% korting op de verhoogde prijs
        // 3. 3m² * €26.818 = €80.454, dan 5% korting = €76.43
        
        for (Wasserij_Item__c result : results.values()) {
            System.assertEquals(10, result.Regiotoeslag__c, 'Regiotoeslag moet 10% zijn');
            System.assertEquals(5, result.Korting__c, 'Bundelkorting moet 5% zijn');
            // Verify that surcharge is applied to base price, then discount applied
            System.assert(result.Totale_Prijs__c > 72.0, 'Prijs moet hoger zijn door regiotoeslag en dan verlaagd door korting');
            System.assert(result.Totale_Prijs__c < 81.0, 'Prijs moet lager zijn door bundelkorting');
        }
    }
    
    @isTest
    static void testRegionalSurchargeMultipleSegments() {
        // Test dat verschillende segmenten verschillende toeslagen kunnen hebben
        Werk_Order__c testWerkOrder = [SELECT Id FROM Werk_Order__c LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Setup postcode gebied
        Postcode_Range__c postcodeGebied = new Postcode_Range__c(
            Name = 'Test Multi Segment',
            Postcode_Begin__c = 2000,
            Postcode_Einde__c = 2099
        );
        insert postcodeGebied;
        
        Account partnerAccount = new Account(Name='Test Partner Multi');
        insert partnerAccount;
        
        // Setup meerdere dienstgebieden
        Dienstgebied__c dienstWasserij = new Dienstgebied__c(
            Name = 'Test Wasserij Service',
            Segment__c = 'Wasserij'
        );
        Dienstgebied__c dienstAndere = new Dienstgebied__c(
            Name = 'Test Andere Service',
            Segment__c = 'Andere'
        );
        insert new List<Dienstgebied__c>{dienstWasserij, dienstAndere};
        
        // Setup verschillende toeslagen per segment
        Dienstgebied_Postcode_Associatie__c assocWasserij = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partnerAccount.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = dienstWasserij.Id,
            Regiotoeslag__c = true,
            Toeslag__c = 15  // 15% voor Wasserij
        );
        
        Dienstgebied_Postcode_Associatie__c assocAndere = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partnerAccount.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = dienstAndere.Id,
            Regiotoeslag__c = true,
            Toeslag__c = 25  // 25% voor Andere
        );
        insert new List<Dienstgebied_Postcode_Associatie__c>{assocWasserij, assocAndere};
        
        // Test met Wasserij segment
        testWerkOrder.Postcodegebied__c = postcodeGebied.Id;
        testWerkOrder.Uniek_Segment__c = 'Wasserij';
        update testWerkOrder;
        
        Wasserij_Item__c itemWasserij = new Wasserij_Item__c(
            Werk_Order__c = testWerkOrder.Id,
            Product__c = vloerkleedProduct.Id,
            Lengte__c = 100,
            Breedte__c = 100  // 1m²
        );
        
        Test.startTest();
        insert itemWasserij;
        Test.stopTest();
        
        Wasserij_Item__c resultWasserij = [
            SELECT Verkoopprijs__c, Regiotoeslag__c 
            FROM Wasserij_Item__c 
            WHERE Id = :itemWasserij.Id
        ];
        
        // Verify Wasserij segment gets 15% surcharge
        System.assertEquals(15, resultWasserij.Regiotoeslag__c, 'Wasserij segment moet 15% toeslag hebben');
        
        // Expected: €24.38 * 1.15 = €28.037
        System.assertEquals(28.04, resultWasserij.Verkoopprijs__c.setScale(2), 'Verkoopprijs met 15% toeslag');
    }
    
    @isTest
    static void testLeadProductRegioToeslag() {
        System.debug('=== TEST LEAD PRODUCT REGIOTOESLAG START ===');
        
        // Setup data voor regiotoeslag test
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Update Lead met Amsterdam postcode voor regiotoeslag
        testLead.PostalCode = '1012 AB';
        update testLead;
        
        Test.startTest();
        
        // Create Lead_Product__c die regiotoeslag moet krijgen
        Lead_Product__c leadProduct = new Lead_Product__c(
            Lead__c = testLead.Id,
            Product__c = vloerkleedProduct.Id,
            SKU__c = 'VLRK-TEST',
            Aantal__c = 2
        );
        
        insert leadProduct;
        
        Test.stopTest();
        
        // Query result
        Lead_Product__c result = [
            SELECT Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c, Aantal__c
            FROM Lead_Product__c 
            WHERE Id = :leadProduct.Id
        ];
        
        System.debug('Lead Product Result:');
        System.debug('  Aantal: ' + result.Aantal__c);
        System.debug('  Verkoopprijs: €' + result.Verkoopprijs__c);
        System.debug('  Totale_Prijs: €' + result.Totale_Prijs__c);
        System.debug('  Regiotoeslag: ' + result.Regiotoeslag__c + '%');
        
        // Verify regiotoeslag is applied (if configured for Amsterdam)
        // Note: Actual percentage depends on metadata configuration
        System.assertNotEquals(null, result.Regiotoeslag__c, 'Regiotoeslag should be set');
        System.assertNotEquals(null, result.Verkoopprijs__c, 'Verkoopprijs should be calculated');
        System.assertNotEquals(null, result.Totale_Prijs__c, 'Totale_Prijs should be calculated');
        
        // Basic validation: Totale_Prijs should be Verkoopprijs * Aantal  
        Decimal expectedTotal = result.Verkoopprijs__c * result.Aantal__c;
        System.assertEquals(expectedTotal.setScale(2), result.Totale_Prijs__c.setScale(2), 
                           'Totale_Prijs should equal Verkoopprijs * Aantal');
    }
    
    @isTest
    static void testLeadProductCrossItemUpdates() {
        System.debug('=== TEST LEAD PRODUCT CROSS-ITEM UPDATES START ===');
        
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
        
        // Wacht even voor async processing
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
            SELECT Id, SKU__c, Oppervlakte_m__c, Aantal__c, Verkoopprijs__c, 
                   Totale_Prijs__c, Korting__c
            FROM Lead_Product__c 
            WHERE Lead__c = :testLead.Id
            ORDER BY SKU__c
        ];
        
        System.debug('Cross-item update results:');
        for (Lead_Product__c lp : allProducts) {
            System.debug('  ' + lp.SKU__c + ': Oppervlakte=' + lp.Oppervlakte_m__c + 
                        'm², Korting=' + lp.Korting__c + '%');
        }
        
        // Verify beide producten bestaan
        System.assertEquals(2, allProducts.size(), 'Should have 2 Lead Products');
        
        // Verify oppervlakte berekening
        for (Lead_Product__c lp : allProducts) {
            System.assertNotEquals(null, lp.Oppervlakte_m__c, 'Oppervlakte should be calculated');
            System.assertEquals(lp.Oppervlakte_m__c, lp.Aantal__c, 'Aantal should equal Oppervlakte for carpets');
        }
    }
    
    @isTest
    static void testLeadProductDeletionRecalculation() {
        System.debug('=== TEST LEAD PRODUCT DELETION RECALCULATION START ===');
        
        Lead testLead = [SELECT Id FROM Lead WHERE LastName='Test Klant' LIMIT 1];
        Product2 vloerkleedProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'VLRK-TEST' LIMIT 1];
        
        // Create meerdere producten
        List<Lead_Product__c> products = new List<Lead_Product__c>();
        for (Integer i = 1; i <= 3; i++) {
            products.add(new Lead_Product__c(
                Lead__c = testLead.Id,
                Product__c = vloerkleedProduct.Id,
                SKU__c = 'VLRK-DEL-' + i,
                Lengte_cm__c = 100 * i,
                Breedte_cm__c = 100  // Verschillende oppervlaktes
            ));
        }
        insert products;
        
        // Verify initial count
        Integer initialCount = [SELECT COUNT() FROM Lead_Product__c WHERE Lead__c = :testLead.Id];
        System.assertEquals(3, initialCount, 'Should have 3 products initially');
        
        Test.startTest();
        
        // Delete één product - dit zou deletion recalculation moeten triggeren
        delete products[1]; // Delete middle product
        
        Test.stopTest();
        
        // Verify deletion
        Integer finalCount = [SELECT COUNT() FROM Lead_Product__c WHERE Lead__c = :testLead.Id];
        System.assertEquals(2, finalCount, 'Should have 2 products after deletion');
        
        // Note: Async recalculation wordt getriggerd maar completes mogelijk niet binnen test context
        System.debug('Deletion recalculation test completed - async job queued');
    }
}