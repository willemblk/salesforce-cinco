@IsTest
private class LeadToOpportunityConverterTest {

    @IsTest
    static void convertLeadWithExtrasAndPackage() {
        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Product2 primaryProduct = new Product2(
            Name = 'Primary Service',
            ProductCode = 'PRIM-001',
            IsActive = true,
            Segment__c = 'SR',
            Product_Category__c = 'Primary'
        );
        Product2 extraProduct = new Product2(
            Name = 'Extra Service',
            ProductCode = 'EXTRA-001',
            IsActive = true,
            Segment__c = 'SR',
            Product_Category__c = 'Extra'
        );
        Product2 packageProduct = new Product2(
            Name = 'Package Service',
            ProductCode = 'PKG-001',
            IsActive = true,
            Segment__c = 'SR',
            Product_Category__c = 'Package'
        );
        insert new List<Product2>{ primaryProduct, extraProduct, packageProduct };

        insert new List<PricebookEntry>{
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = primaryProduct.Id, UnitPrice = 100, IsActive = true),
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = extraProduct.Id, UnitPrice = 25, IsActive = true),
            new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = packageProduct.Id, UnitPrice = 150, IsActive = true)
        };

        PricebookEntry primaryEntry = [
            SELECT UnitPrice
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :primaryProduct.Id AND IsActive = true
            LIMIT 1
        ];
        System.assertEquals(100, primaryEntry.UnitPrice, 'Unit price van prijsboek entry is onverwacht.');

        LeadStatus openStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false LIMIT 1];

        Lead leadRecord = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Lead Company',
            Status = openStatus.MasterLabel,
            Email = 'testlead@example.com',
            Ophaaladres_Toevoeging__c = 'achterzijde',
            Afleveradres_Toevoeging__c = 'balie links'
        );
        insert leadRecord;

        Lead_Product__c primaryLeadProduct = new Lead_Product__c(
            Lead__c = leadRecord.Id,
            Product__c = primaryProduct.Id,
            Aantal__c = 2,
            Totale_Prijs__c = 200,
            Bijzonderheden__c = 'Hoofd product',
            Lengte_cm__c = 200,
            Breedte_cm__c = 150
        );
        insert primaryLeadProduct;

        Lead_Product__c extraLeadProduct = new Lead_Product__c(
            Lead__c = leadRecord.Id,
            Product__c = extraProduct.Id,
            Gerelateerd_Product__c = primaryLeadProduct.Id,
            Aantal__c = 1,
            Totale_Prijs__c = 25,
            Bijzonderheden__c = 'Extra onderhoud',
            Lengte_cm__c = 50,
            Breedte_cm__c = 40,
            Diameter_cm__c = 30
        );
        insert extraLeadProduct;

        Lead_Product__c packageLeadProduct = new Lead_Product__c(
            Lead__c = leadRecord.Id,
            Product__c = packageProduct.Id,
            Gerelateerd_Product__c = primaryLeadProduct.Id,
            Aantal__c = 1,
            Totale_Prijs__c = 150,
            Bijzonderheden__c = 'Premium pakket'
        );
        insert packageLeadProduct;

        LeadToOpportunityConverter.Request request = new LeadToOpportunityConverter.Request();
        request.leadId = leadRecord.Id;
        request.oppStageName = 'Qualification';

        Test.startTest();
        List<LeadToOpportunityConverter.Response> responses = LeadToOpportunityConverter.convert(new List<LeadToOpportunityConverter.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Er wordt één response verwacht.');
        LeadToOpportunityConverter.Response response = responses[0];
    System.assertEquals(true, response.success, 'Conversie zou moeten slagen. ' + response.message);
        System.assertNotEquals(null, response.opportunityId, 'Opportunity Id ontbreekt.');
        System.assertEquals(3, response.opportunityLineItemIds.size(), 'Er moeten drie opportunity line items zijn.');

        Opportunity opportunityRecord = [
            SELECT StageName, Pricebook2Id, Ophaaladres_Toevoeging__c, Afleveradres_Toevoeging__c
            FROM Opportunity
            WHERE Id = :response.opportunityId
        ];
        System.assertEquals('Qualification', opportunityRecord.StageName, 'Stage is niet correct ingesteld.');
        System.assertEquals(standardPricebookId, opportunityRecord.Pricebook2Id, 'Prijsboek is niet correct ingesteld.');
        System.assertEquals('achterzijde', opportunityRecord.Ophaaladres_Toevoeging__c, 'Ophaaladres toevoeging is niet overgenomen.');
        System.assertEquals('balie links', opportunityRecord.Afleveradres_Toevoeging__c, 'Afleveradres toevoeging is niet overgenomen.');

        List<OpportunityLineItem> opportunityLineItems = [
            SELECT Id, Quantity, UnitPrice, Description, Gerelateerd_Product__c,
                   Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, PricebookEntry.Product2Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :response.opportunityId
        ];
        System.assertEquals(3, opportunityLineItems.size(), 'De opportunity moet drie regels hebben.');
        OpportunityLineItem primaryOli;
        List<OpportunityLineItem> childOlis = new List<OpportunityLineItem>();
        for (OpportunityLineItem oli : opportunityLineItems) {
            if (oli.Gerelateerd_Product__c == null) {
                primaryOli = oli;
            } else {
                childOlis.add(oli);
            }
        }
        System.assertNotEquals(null, primaryOli, 'Primair opportunity product ontbreekt.');
        System.assertEquals(2, childOlis.size(), 'Er moeten twee gerelateerde producten zijn.');
        OpportunityLineItem extraOli;
        OpportunityLineItem packageOli;
        for (OpportunityLineItem child : childOlis) {
            System.assertEquals(primaryOli.Id, child.Gerelateerd_Product__c, 'Child regel moet aan primaire regel gekoppeld zijn.');
            System.assertEquals(true, child.Description != null && child.Description.startsWith('[EXTRA]'), 'Child beschrijving mist [EXTRA] prefix.');
            if (child.PricebookEntry != null && child.PricebookEntry.Product2Id == extraProduct.Id) {
                extraOli = child;
            } else if (child.PricebookEntry != null && child.PricebookEntry.Product2Id == packageProduct.Id) {
                packageOli = child;
            }
        }
        System.assertNotEquals(null, extraOli, 'Extra opportunity regel ontbreekt.');
        System.assertNotEquals(null, packageOli, 'Package opportunity regel ontbreekt.');
        System.assertEquals(2, primaryOli.Quantity, 'Hoeveelheid van primaire regel klopt niet.');
        System.assertEquals(100, primaryOli.UnitPrice, 'Unit price van primaire regel klopt niet.');
        System.assertEquals('[EXTRA] Extra onderhoud', extraOli.Description, 'Beschrijving van extra regel mist prefix.');
        System.assertEquals('[EXTRA] Premium pakket', packageOli.Description, 'Beschrijving van package regel mist prefix.');
        System.assertEquals(primaryLeadProduct.Lengte_cm__c, primaryOli.Lengte_cm__c, 'Lengte van primaire regel is onjuist.');
        System.assertEquals(primaryLeadProduct.Breedte_cm__c, primaryOli.Breedte_cm__c, 'Breedte van primaire regel is onjuist.');
        System.assertEquals(extraLeadProduct.Lengte_cm__c, extraOli.Lengte_cm__c, 'Lengte van extra regel is onjuist.');
        System.assertEquals(extraLeadProduct.Breedte_cm__c, extraOli.Breedte_cm__c, 'Breedte van extra regel is onjuist.');
        System.assertEquals(extraLeadProduct.Diameter_cm__c, extraOli.Diameter_cm__c, 'Diameter van extra regel is onjuist.');
    }

    @IsTest
    static void convertLeadTwiceIsIdempotent() {
        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Product2 primaryProduct = new Product2(
            Name = 'Primary Service',
            ProductCode = 'PRIM-002',
            IsActive = true,
            Segment__c = 'SR'
        );
        insert primaryProduct;

        insert new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = primaryProduct.Id, UnitPrice = 50, IsActive = true);

        LeadStatus openStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false LIMIT 1];
        Lead leadRecord = new Lead(
            FirstName = 'Idem',
            LastName = 'Potent',
            Company = 'Acme BV',
            Status = openStatus.MasterLabel
        );
        insert leadRecord;

        Lead_Product__c lp = new Lead_Product__c(
            Lead__c = leadRecord.Id,
            Product__c = primaryProduct.Id,
            Aantal__c = 3,
            Totale_Prijs__c = 150
        );
        insert lp;

        LeadToOpportunityConverter.Request req = new LeadToOpportunityConverter.Request();
        req.leadId = leadRecord.Id;

        // First conversion
        Test.startTest();
        List<LeadToOpportunityConverter.Response> first = LeadToOpportunityConverter.convert(new List<LeadToOpportunityConverter.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, first.size());
        System.assertEquals(true, first[0].success, 'Eerste conversie moet slagen.');
        System.assertEquals(1, first[0].opportunityLineItemIds.size(), 'Er moet 1 OLI zijn na eerste run.');

        Id oppId = first[0].opportunityId;
        Integer oliCountAfterFirst = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :oppId];
        System.assertEquals(1, oliCountAfterFirst, 'Er moet 1 OLI bestaan na eerste run.');

        // Second conversion (should not create duplicates)
        Test.startTest();
        List<LeadToOpportunityConverter.Response> second = LeadToOpportunityConverter.convert(new List<LeadToOpportunityConverter.Request>{ req });
        Test.stopTest();
        System.assertEquals(1, second.size());
        System.assertEquals(true, second[0].success, 'Tweede conversie moet slagen.');
        Integer oliCountAfterSecond = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :oppId];
        System.assertEquals(1, oliCountAfterSecond, 'Aantal OLI mag niet verdubbelen na tweede run.');
    }
}