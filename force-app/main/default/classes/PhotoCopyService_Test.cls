@IsTest
private class PhotoCopyService_Test {

    @TestSetup
    static void setupData() {
        Account a = new Account(Name = 'Test PA', PersonEmail = 'lead@test.com');
        insert a;

        Lead l = new Lead(LastName = 'Test', Company = 'Comp', Email = 'lead@test.com', Status = 'Open - Not Contacted');
        insert l;

        // Minimal product & pricebook for OLI creation
        Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        if (std.IsActive == false) { std.IsActive = true; update std; }
        Product2 p = new Product2(Name = 'P1', IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = std.Id, Product2Id = p.Id, UnitPrice = 10, IsActive = true);
        insert pbe;

        // Lead Product
        Lead_Product__c lp = new Lead_Product__c(Lead__c = l.Id, Product__c = p.Id, Aantal__c = 1);
        insert lp;

        // Photos on Lead and Lead Product (explicitly test NULL and false for Copied_Forward__c)
        insert new Foto__c(Lead__c = l.Id, URL__c = 'u1', Beschrijving__c = 'lead1', Is_Public__c = true, Copied_Forward__c = null);
        insert new Foto__c(Lead__c = l.Id, URL__c = 'u1b', Beschrijving__c = 'lead2', Is_Public__c = false, Copied_Forward__c = false);
        insert new Foto__c(Lead_Product__c = lp.Id, URL__c = 'u2', Beschrijving__c = 'lp1', Is_Public__c = true, Copied_Forward__c = null);
    }

    @IsTest
    static void testLeadAndLeadProductPhotoCopy() {
        Lead l = [SELECT Id, Email, Status FROM Lead LIMIT 1];

        Test.startTest();
        // Convert Lead to Opportunity using the existing converter
        LeadToOpportunityConverter.Request r = new LeadToOpportunityConverter.Request();
        r.leadId = l.Id;
        List<LeadToOpportunityConverter.Response> resp = LeadToOpportunityConverter.convert(new List<LeadToOpportunityConverter.Request>{ r });
        Test.stopTest();

        System.assertEquals(1, resp.size(), 'one response');
        System.assertEquals(true, resp[0].success, 'conversion success');
        Id oppId = resp[0].opportunityId;
        System.assertNotEquals(null, oppId, 'opportunity created');

        // Lead photos should now exist on Opportunity (expect 2: one NULL, one false)
        List<Foto__c> oppPhotos = [SELECT Id, Opportunity__c, Beschrijving__c, Bron__c FROM Foto__c WHERE Opportunity__c = :oppId];
        System.assertEquals(2, oppPhotos.size(), 'copied 2 lead photos to opp');
        for (Foto__c fp : oppPhotos) {
            System.assert(fp.Bron__c.contains('lead'), 'Bron contains "lead"');
        }

        // Original lead photos should be marked Copied_Forward__c = true
        List<Foto__c> originalLeadPhotos = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE Lead__c = :l.Id];
        System.assertEquals(2, originalLeadPhotos.size(), '2 original lead photos');
        for (Foto__c fp : originalLeadPhotos) {
            System.assertEquals(true, fp.Copied_Forward__c, 'Copied_Forward__c marked true');
        }

        // Lead Product photos should now exist on OLI
        System.assert(!resp[0].opportunityLineItemIds.isEmpty(), 'oli created');
        Set<Id> oliIds = new Set<Id>(resp[0].opportunityLineItemIds);
        List<Foto__c> oliPhotos = [SELECT Id, OpportunityLineItem__c, Bron__c FROM Foto__c WHERE OpportunityLineItem__c IN :oliIds];
        System.assertEquals(1, oliPhotos.size(), 'copied 1 lead product photo to oli');
        System.assert(oliPhotos[0].Bron__c.contains('lead product'), 'Bron contains "lead product"');

        // Original lead product photos should be marked
        Lead_Product__c lp = [SELECT Id FROM Lead_Product__c LIMIT 1];
        List<Foto__c> originalLpPhotos = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE Lead_Product__c = :lp.Id];
        System.assertEquals(1, originalLpPhotos.size(), '1 original lp photo');
        System.assertEquals(true, originalLpPhotos[0].Copied_Forward__c, 'LP photo marked copied');

        // Idempotency: running again should not duplicate, since we mark Copied_Forward__c
        LeadToOpportunityConverter.Request r2 = new LeadToOpportunityConverter.Request();
        r2.leadId = l.Id;
        List<LeadToOpportunityConverter.Response> resp2 = LeadToOpportunityConverter.convert(new List<LeadToOpportunityConverter.Request>{ r2 });
        Integer countAfter = [SELECT COUNT() FROM Foto__c WHERE Opportunity__c = :oppId];
        System.assertEquals(oppPhotos.size(), countAfter, 'no duplicate opp photos');
    }

    @IsTest
    static void testDirectLeadPhotoService() {
        // Direct service method test
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today(), Pricebook2Id = std.Id);
        insert opp;

        Map<Id, Id> leadToOppMap = new Map<Id, Id>{ l.Id => opp.Id };

        Test.startTest();
        PhotoCopyService.copyLeadPhotosToOpportunities(leadToOppMap);
        Test.stopTest();

        List<Foto__c> copied = [SELECT Id, Opportunity__c FROM Foto__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(2, copied.size(), 'direct service copied 2 photos');

        // Mark check
        List<Foto__c> src = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE Lead__c = :l.Id];
        for (Foto__c f : src) {
            System.assertEquals(true, f.Copied_Forward__c, 'src marked copied');
        }
    }

    @IsTest
    static void testDirectLeadProductPhotoService() {
        // Direct service method test
        Lead_Product__c lp = [SELECT Id FROM Lead_Product__c LIMIT 1];
        Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(Name = 'Test Opp2', StageName = 'Prospecting', CloseDate = Date.today(), Pricebook2Id = std.Id);
        insert opp;
        Product2 p = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :p.Id LIMIT 1];
        OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 10);
        insert oli;

        Map<Id, Id> lpToOliMap = new Map<Id, Id>{ lp.Id => oli.Id };

        Test.startTest();
        PhotoCopyService.copyLeadProductPhotosToOpportunityLineItems(lpToOliMap);
        Test.stopTest();

        List<Foto__c> copied = [SELECT Id, OpportunityLineItem__c FROM Foto__c WHERE OpportunityLineItem__c = :oli.Id];
        System.assertEquals(1, copied.size(), 'direct service copied 1 lp photo');

        // Mark check
        List<Foto__c> src = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE Lead_Product__c = :lp.Id];
        System.assertEquals(1, src.size(), '1 src lp photo');
        System.assertEquals(true, src[0].Copied_Forward__c, 'lp photo marked copied');
    }

    @IsTest
    static void testOpportunityToWorkOrderPhotoCopy() {
        // Test Opportunity → Werk_Order1__c photo copy
        Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(Name = 'Test Opp WO', StageName = 'Prospecting', CloseDate = Date.today(), Pricebook2Id = std.Id);
        insert opp;

        // Add photos to Opportunity
        insert new Foto__c(Opportunity__c = opp.Id, URL__c = 'opp1', Beschrijving__c = 'opp foto', Copied_Forward__c = null);
        insert new Foto__c(Opportunity__c = opp.Id, URL__c = 'opp2', Beschrijving__c = 'opp foto2', Copied_Forward__c = false);

        // Create Werk_Order1__c
        Werk_Order1__c wo = new Werk_Order1__c(Name = 'WO1', Opportunity__c = opp.Id);
        insert wo;

        Map<Id, Id> oppToWoMap = new Map<Id, Id>{ opp.Id => wo.Id };

        Test.startTest();
        PhotoCopyService.copyOpportunityPhotosToWerkOrders(oppToWoMap);
        Test.stopTest();

        List<Foto__c> woPhotos = [SELECT Id, Werk_Order1__c, Bron__c FROM Foto__c WHERE Werk_Order1__c = :wo.Id];
        System.assertEquals(2, woPhotos.size(), 'copied 2 opp photos to werkorder');
        for (Foto__c fp : woPhotos) {
            System.assert(fp.Bron__c.contains('opportunity'), 'Bron contains "opportunity"');
        }

        // Source should be marked
        List<Foto__c> srcOpp = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE Opportunity__c = :opp.Id AND Werk_Order1__c = null];
        System.assertEquals(2, srcOpp.size(), '2 original opp photos');
        for (Foto__c f : srcOpp) {
            System.assertEquals(true, f.Copied_Forward__c, 'opp photo marked copied');
        }
    }

    @IsTest
    static void testOLIToWasserijItemPhotoCopy() {
        // Test OpportunityLineItem → Wasserij_Item__c photo copy
        Pricebook2 std = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
        Opportunity opp = new Opportunity(Name = 'Test Opp WI', StageName = 'Prospecting', CloseDate = Date.today(), Pricebook2Id = std.Id);
        insert opp;
        Product2 p = [SELECT Id FROM Product2 LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Product2Id = :p.Id LIMIT 1];
        OpportunityLineItem oli = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 10);
        insert oli;

        // Add photo to OLI
        insert new Foto__c(OpportunityLineItem__c = oli.Id, URL__c = 'oli1', Beschrijving__c = 'oli foto', Copied_Forward__c = null);

        // Create Werk_Order1__c and Wasserij_Item__c
        Werk_Order1__c wo = new Werk_Order1__c(Name = 'WO2', Opportunity__c = opp.Id);
        insert wo;
        Wasserij_Item__c wi = new Wasserij_Item__c(Werk_Order1__c = wo.Id, Line_Item_Id__c = oli.Id);
        insert wi;

        Map<Id, Id> oliToWiMap = new Map<Id, Id>{ oli.Id => wi.Id };

        Test.startTest();
        PhotoCopyService.copyOpportunityLineItemPhotos(oliToWiMap);
        Test.stopTest();

        List<Foto__c> wiPhotos = [SELECT Id, Wasserij_item__c, Bron__c FROM Foto__c WHERE Wasserij_item__c = :wi.Id];
        System.assertEquals(1, wiPhotos.size(), 'copied 1 oli photo to wasserij item');
        System.assert(wiPhotos[0].Bron__c.contains('opportunity product'), 'Bron contains "opportunity product"');

        // Source should be marked
        List<Foto__c> srcOli = [SELECT Id, Copied_Forward__c FROM Foto__c WHERE OpportunityLineItem__c = :oli.Id AND Wasserij_item__c = null];
        System.assertEquals(1, srcOli.size(), '1 original oli photo');
        System.assertEquals(true, srcOli[0].Copied_Forward__c, 'oli photo marked copied');
    }

    @IsTest
    static void testEmptyMaps() {
        // Null/empty map should return early without errors
        Test.startTest();
        PhotoCopyService.copyLeadPhotosToOpportunities(null);
        PhotoCopyService.copyLeadPhotosToOpportunities(new Map<Id, Id>());
        PhotoCopyService.copyLeadProductPhotosToOpportunityLineItems(null);
        PhotoCopyService.copyLeadProductPhotosToOpportunityLineItems(new Map<Id, Id>());
        PhotoCopyService.copyOpportunityPhotosToWerkOrders(null);
        PhotoCopyService.copyOpportunityPhotosToWerkOrders(new Map<Id, Id>());
        PhotoCopyService.copyOpportunityLineItemPhotos(null);
        PhotoCopyService.copyOpportunityLineItemPhotos(new Map<Id, Id>());
        Test.stopTest();
        // Should complete without errors
        System.assert(true, 'empty maps handled');
    }
}
