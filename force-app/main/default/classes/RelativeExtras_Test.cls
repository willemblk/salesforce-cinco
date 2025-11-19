@isTest
private class RelativeExtras_Test {

    @testSetup
    static void seed() {
        // Minimal test setup: create a Lead to host lines
        insert new Lead(LastName = 'RelExtra Tester', Company = 'Test Co');
    }

    @isTest
    static void testRelativeExtraSimple() {
        Lead host = [SELECT Id FROM Lead WHERE LastName = 'RelExtra Tester' LIMIT 1];

        // Primary product (unit €22) marked as primary
        Product2 primary = new Product2(
            Name = 'RelPrim',
            ProductCode = 'RELPRIM-01',
            IsActive = true,
            Segment__c = 'Wasserij',
            Primaryproduct__c = true
        );
        insert primary;

        Prijsmanagement__c primaryPolicy = new Prijsmanagement__c(
            Product__c = primary.Id,
            Eenheidsprijs__c = 22,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert primaryPolicy;

        // Extra product with 25% relative
        Product2 extra = new Product2(
            Name = 'RelExtra',
            ProductCode = 'RELEX-25',
            IsActive = true,
            Segment__c = 'Wasserij',
            Primaryproduct__c = false
        );
        insert extra;

        Prijsmanagement__c extraPolicy = new Prijsmanagement__c(
            Product__c = extra.Id,
            Relatieve_prijs__c = 25,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert extraPolicy;

        // Build lines: primary qty=4, and a related extra (qty will be overridden to 1)
        Lead_Product__c lpPrimary = new Lead_Product__c(
            Lead__c = host.Id,
            Product__c = primary.Id,
            SKU__c = 'RELPRIM-01',
            Aantal__c = 4
        );

        Lead_Product__c lpExtra = new Lead_Product__c(
            Lead__c = host.Id,
            Product__c = extra.Id,
            SKU__c = 'RELEX-25',
            Gerelateerd_Product__c = primary.Id,
            Aantal__c = 3
        );

        // Call pricing engine directly (no trigger dependency)
        List<SObject> priced = PricingService.reprice(new List<SObject>{ lpPrimary, lpExtra });

        // Extract results from returned objects
        Lead_Product__c p = null, x = null;
        for (SObject so : priced) {
            Lead_Product__c lp = (Lead_Product__c)so;
            if (lp.SKU__c == 'RELPRIM-01') p = lp; else x = lp;
        }

        System.assertNotEquals(null, p, 'Primary should be present');
        System.assertNotEquals(null, x, 'Extra should be present');

        Decimal primaryNet = (p.Totale_Prijs__c != null ? p.Totale_Prijs__c : 0) - (p.Korting_bedrag__c != null ? p.Korting_bedrag__c : 0);
        System.assertEquals(88.00, primaryNet.setScale(2), 'Primary net should be 22*4 = 88');

        Decimal expectedExtra = (primaryNet * 0.25).setScale(2);
        System.assertEquals(1, x.Aantal__c, 'Relative extra should enforce Aantal=1');
        System.assertEquals(expectedExtra, x.Verkoopprijs__c.setScale(2), 'Extra unit equals 25% of primary net');
        System.assertEquals(expectedExtra, x.Totale_Prijs__c.setScale(2), 'Extra line equals unit (Aantal=1)');
        System.assertEquals(null, x.Korting__c, 'Relative extra should have no discount');
    }

    @isTest
    static void testRelativeExtraFollowsMinimum() {
        Lead host = [SELECT Id FROM Lead WHERE LastName = 'RelExtra Tester' LIMIT 1];

        // Primary with order minimum via Minimale_prijs__c on policy
        Product2 primary = new Product2(
            Name = 'RelPrimMin',
            ProductCode = 'RELPRIM-MIN',
            IsActive = true,
            Segment__c = 'Wasserij',
            Primaryproduct__c = true
        );
        insert primary;

        Prijsmanagement__c primaryPolicy = new Prijsmanagement__c(
            Product__c = primary.Id,
            Eenheidsprijs__c = 10,
            Minimale_prijs__c = 100,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert primaryPolicy;

        Product2 extra = new Product2(
            Name = 'RelExtra20',
            ProductCode = 'RELEX-20',
            IsActive = true,
            Segment__c = 'Wasserij',
            Primaryproduct__c = false
        );
        insert extra;

        Prijsmanagement__c extraPolicy = new Prijsmanagement__c(
            Product__c = extra.Id,
            Relatieve_prijs__c = 20,
            Geldig_vanaf__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(365)
        );
        insert extraPolicy;

        Lead_Product__c lpPrimary = new Lead_Product__c(
            Lead__c = host.Id,
            Product__c = primary.Id,
            SKU__c = 'RELPRIM-MIN',
            Aantal__c = 2 // normal would be 20; minimum enforces 100 total → unit 50
        );

        Lead_Product__c lpExtra = new Lead_Product__c(
            Lead__c = host.Id,
            Product__c = extra.Id,
            SKU__c = 'RELEX-20',
            Gerelateerd_Product__c = primary.Id,
            Aantal__c = 10 // will be forced to 1
        );

        List<SObject> priced = PricingService.reprice(new List<SObject>{ lpPrimary, lpExtra });

        Lead_Product__c p = null, x = null;
        for (SObject so : priced) {
            Lead_Product__c lp = (Lead_Product__c)so;
            if (lp.SKU__c == 'RELPRIM-MIN') p = lp; else x = lp;
        }

        System.assertNotEquals(null, p, 'Primary should be present');
        System.assertNotEquals(null, x, 'Extra should be present');

        Decimal primaryNet = (p.Totale_Prijs__c != null ? p.Totale_Prijs__c : 0) - (p.Korting_bedrag__c != null ? p.Korting_bedrag__c : 0);
        System.assertEquals(100.00, primaryNet.setScale(2), 'Primary net should be uplifted to 100');

        Decimal expectedExtra = (primaryNet * 0.20).setScale(2);
        System.assertEquals(1, x.Aantal__c, 'Relative extra should enforce Aantal=1');
        System.assertEquals(expectedExtra, x.Verkoopprijs__c.setScale(2), 'Extra should be 20% of primary net after minimum uplift');
        System.assertEquals(expectedExtra, x.Totale_Prijs__c.setScale(2), 'Extra line equals unit (Aantal=1)');
    }
}