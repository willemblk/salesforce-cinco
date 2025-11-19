@IsTest
private class OpportunityToWorkOrderConverterTest {

    @IsTest
    static void convertCreatesWorkOrderAndItems() {
        Id werkOrderRecordTypeId = getRecordTypeIdByName('Werk_Order__c', 'Wasserij');
        Id wasserijItemRecordTypeId = getRecordTypeIdByName('Wasserij_Item__c', 'WI_Wasserij');
        System.assertNotEquals(null, werkOrderRecordTypeId, 'Record Type "Wasserij" voor Werk_Order__c ontbreekt.');
        System.assertNotEquals(null, wasserijItemRecordTypeId, 'Record Type "WI_Wasserij" voor Wasserij_Item__c ontbreekt.');

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Account accountRecord = new Account(Name = 'Test Account');
        insert accountRecord;

        Contact defaultContact = new Contact(FirstName = 'Default', LastName = 'Contact', AccountId = accountRecord.Id);
        insert defaultContact;

        accountRecord.Standaard_Contact_Werk_Order__c = defaultContact.Id;
        update accountRecord;

        Account partnerAccount = new Account(Name = 'Partner Account');
        insert partnerAccount;

        Id postcodeAreaId = createPostcodeRange('Area 1011', 1000, 1099);

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            Pricebook2Id = standardPricebookId,
            Partner__c = partnerAccount.Id,
            Postcodegebied__c = postcodeAreaId,
            Uniek_Segment__c = 'Wasserij'
        );
        insert opp;

        Product2 product = new Product2(Name = 'Test Product', IsActive = true, Segment__c = 'Wasserij');
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 50,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 50,
            Description = 'Test item'
        );
        oli.Lengte_cm__c = 200;
        oli.Breedte_cm__c = 100;
        oli.Diameter_cm__c = 0;
        insert oli;

        Product2 extraProduct = new Product2(Name = 'Extra Product', IsActive = true, Segment__c = 'Wasserij');
        insert extraProduct;

        PricebookEntry extraPbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = extraProduct.Id,
            UnitPrice = 20,
            IsActive = true
        );
        insert extraPbe;

        OpportunityLineItem extraOli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = extraPbe.Id,
            Quantity = 1,
            UnitPrice = 20,
            Description = 'Gerelateerde service'
        );
        extraOli.Gerelateerd_Product__c = oli.Id;
        insert extraOli;

        OpportunityToWorkOrderConverter.Request request = new OpportunityToWorkOrderConverter.Request();
        request.opportunityId = opp.Id;

        Test.startTest();
        List<OpportunityToWorkOrderConverter.Response> responses = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Er wordt één response verwacht.');
        OpportunityToWorkOrderConverter.Response response = responses[0];
        System.assertEquals(true, response.success, response.message);
        System.assertEquals(opp.Id, response.opportunityId, 'OpportunityId in response komt niet overeen.');
        System.assertNotEquals(null, response.werkOrderId, 'Werkorder Id ontbreekt in response.');
        System.assertEquals(2, response.createdItems, 'Aantal aangemaakte Wasserij Items klopt niet.');

        Werk_Order__c werkOrder = [
            SELECT Opportunity__c, Account__c, Partner__c, Postcodegebied__c, Uniek_Segment__c, RecordTypeId, Contactpersoon__c, Bevestigingen_sturen__c
            FROM Werk_Order__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];
        System.assertEquals(opp.Id, werkOrder.Opportunity__c);
        System.assertEquals(accountRecord.Id, werkOrder.Account__c);
    System.assertEquals(partnerAccount.Id, werkOrder.Partner__c);
    System.assertEquals(postcodeAreaId, werkOrder.Postcodegebied__c);
        System.assertEquals('Wasserij', werkOrder.Uniek_Segment__c);
        System.assertEquals(werkOrderRecordTypeId, werkOrder.RecordTypeId);
        System.assertEquals(defaultContact.Id, werkOrder.Contactpersoon__c, 'Contactpersoon moet standaard contact volgen.');
        System.assertEquals(true, werkOrder.Bevestigingen_sturen__c, 'Bevestigingen moeten na volledige conversie aanstaan. Response: ' + response.message);

        List<Wasserij_Item__c> items = [
            SELECT Id, Werk_Order__c, Product__c, Aantal__c, Lengte__c, Breedte__c, Diameter__c,
                   Gerelateerd_Wasserij_Item__c, Opmerkingen__c, RecordTypeId
            FROM Wasserij_Item__c
            WHERE Werk_Order__c = :werkOrder.Id
        ];
        System.assertEquals(2, items.size(), 'Onverwacht aantal Wasserij Items.');

        Wasserij_Item__c primaryItem;
        Wasserij_Item__c relatedItem;
        for (Wasserij_Item__c itemRecord : items) {
            if (itemRecord.Gerelateerd_Wasserij_Item__c == null) {
                primaryItem = itemRecord;
            } else {
                relatedItem = itemRecord;
            }
            System.assertEquals(wasserijItemRecordTypeId, itemRecord.RecordTypeId);
        }

        System.assertNotEquals(null, primaryItem, 'Primair Wasserij item ontbreekt.');
        System.assertEquals(product.Id, primaryItem.Product__c);
        System.assertEquals(Decimal.valueOf(2), primaryItem.Aantal__c);
        System.assertEquals(Decimal.valueOf(200), primaryItem.Lengte__c);
        System.assertEquals(Decimal.valueOf(100), primaryItem.Breedte__c);
        System.assertEquals(Decimal.valueOf(0), primaryItem.Diameter__c);

        System.assertNotEquals(null, relatedItem, 'Gerelateerd Wasserij item ontbreekt.');
        System.assertEquals(extraProduct.Id, relatedItem.Product__c);
        System.assertEquals(primaryItem.Id, relatedItem.Gerelateerd_Wasserij_Item__c);
        System.assertEquals('Gerelateerde service', relatedItem.Opmerkingen__c);
    }

    @IsTest
    static void convertDelaysConfirmationUntilItemsExist() {
        System.assertNotEquals(null, getRecordTypeIdByName('Werk_Order__c', 'Wasserij'), 'Werk order recordtype ontbreekt.');

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Account accountRecord = new Account(Name = 'Delay Account');
        insert accountRecord;

        Opportunity opp = new Opportunity(
            Name = 'Delay Opp',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(2),
            Pricebook2Id = standardPricebookId,
            Uniek_Segment__c = 'Wasserij'
        );
        insert opp;

        Product2 product = new Product2(Name = 'Delay Product', IsActive = true, Segment__c = 'Wasserij');
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 40,
            IsActive = true
        );
        insert pbe;

        OpportunityToWorkOrderConverter.Request request = new OpportunityToWorkOrderConverter.Request();
        request.opportunityId = opp.Id;

        Test.startTest();
        List<OpportunityToWorkOrderConverter.Response> firstRunResponse = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ request });

        Werk_Order__c woAfterFirstRun = [
            SELECT Id, Bevestigingen_sturen__c
            FROM Werk_Order__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];
        System.assertEquals(false, woAfterFirstRun.Bevestigingen_sturen__c, 'Bevestigingen mogen niet worden aangezet zonder Wasserij items.');

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 40
        );
        insert oli;

        List<OpportunityToWorkOrderConverter.Response> secondRunResponse = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ request });
        Test.stopTest();

        Werk_Order__c woAfterSecondRun = [
            SELECT Id, Bevestigingen_sturen__c
            FROM Werk_Order__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];
        System.assertEquals(true, woAfterSecondRun.Bevestigingen_sturen__c, 'Bevestigingen moeten pas aan wanneer Wasserij items aanwezig zijn. Responses: ' +
            (firstRunResponse.isEmpty() ? 'first run empty' : firstRunResponse[0].message) + ' / ' +
            (secondRunResponse.isEmpty() ? 'second run empty' : secondRunResponse[0].message));

        Integer wasserijItemCount = [SELECT COUNT() FROM Wasserij_Item__c WHERE Werk_Order__c = :woAfterSecondRun.Id];
        System.assertEquals(1, wasserijItemCount, 'Na tweede run moet er een Wasserij item bestaan.');
    }

    @IsTest
    static void convertSetsAlternatePickupAddressWhenDifferent() {
        Id werkOrderRecordTypeId = getRecordTypeIdByName('Werk_Order__c', 'Wasserij');
        System.assertNotEquals(null, werkOrderRecordTypeId, 'Werk order recordtype ontbreekt.');

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Account accountRecord = new Account(
            Name = 'Address Account',
            BillingStreet = 'Old Billing 1',
            BillingPostalCode = '0000AA',
            BillingCity = 'Old City'
        );
        insert accountRecord;

        Opportunity opp = new Opportunity(
            Name = 'Alt Address Opp',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(4),
            Pricebook2Id = standardPricebookId,
            Uniek_Segment__c = 'Wasserij',
            Ophaalstraat__c = 'Pickup Straat',
            Ophaaladres_Toevoeging__c = '12B',
            Ophaalpostcode__c = '1011AA',
            Ophaalplaats__c = 'Amsterdam',
            Afleverstraat__c = 'Delivery Straat',
            Afleveradres_Toevoeging__c = '88',
            Afleverpostcode__c = '1022BB',
            Afleverplaats__c = 'Rotterdam'
        );
        insert opp;

        Product2 product = new Product2(Name = 'Address Product', IsActive = true, Segment__c = 'Wasserij');
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 15,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 15
        );
        insert oli;

        OpportunityToWorkOrderConverter.Request request = new OpportunityToWorkOrderConverter.Request();
        request.opportunityId = opp.Id;

        Test.startTest();
        List<OpportunityToWorkOrderConverter.Response> responses = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success, responses[0].message);

        Account refreshedAccount = [
            SELECT BillingStreet, BillingPostalCode, BillingCity
            FROM Account
            WHERE Id = :accountRecord.Id
        ];
        System.assertEquals('Delivery Straat\n88', refreshedAccount.BillingStreet, 'BillingStreet moet afleveradres bevatten.');
        System.assertEquals('1022BB', refreshedAccount.BillingPostalCode);
        System.assertEquals('Rotterdam', refreshedAccount.BillingCity);

        Werk_Order__c werkOrder = [
            SELECT Ander_Ophaaladres__c, Ophaaladres1__Street__s, Ophaaladres_toevoeging__c, Ophaaladres1__PostalCode__s, Ophaaladres1__City__s
            FROM Werk_Order__c
            WHERE Opportunity__c = :opp.Id
        ];
        System.assertEquals(true, werkOrder.Ander_Ophaaladres__c, 'Ander ophaaladres moet aangevinkt zijn.');
        System.assertEquals('Pickup Straat', werkOrder.Ophaaladres1__Street__s);
        System.assertEquals('12B', werkOrder.Ophaaladres_toevoeging__c);
        System.assertEquals('1011AA', werkOrder.Ophaaladres1__PostalCode__s);
        System.assertEquals('Amsterdam', werkOrder.Ophaaladres1__City__s);
    }

    @IsTest
    static void convertSetsContactFromPersonAccount() {
        Id werkOrderRecordTypeId = getRecordTypeIdByName('Werk_Order__c', 'Wasserij');
        System.assertNotEquals(null, werkOrderRecordTypeId, 'Werk order recordtype ontbreekt.');

        if (!Account.SObjectType.getDescribe().isPersonAccountEnabled()) {
            System.debug('Skipping convertSetsContactFromPersonAccount test because Person Accounts are not enabled in this org.');
            return;
        }

        Id personAccountRecordTypeId = getPersonAccountRecordTypeId();
        if (personAccountRecordTypeId == null) {
            System.assert(true, 'Person Accounts not enabled; test skipped.');
            return;
        }

        try {
            Id standardPricebookId = Test.getStandardPricebookId();
            update new Pricebook2(Id = standardPricebookId, IsActive = true);

            Account personAccount = new Account(
                RecordTypeId = personAccountRecordTypeId,
                FirstName = 'Persoon',
                LastName = 'Account',
                PersonEmail = 'persoon@example.com'
            );
            insert personAccount;

            Account personAccountWithContact = [
                SELECT PersonContactId
                FROM Account
                WHERE Id = :personAccount.Id
            ];
            System.assertNotEquals(null, personAccountWithContact.PersonContactId, 'Person Account contact ontbreekt.');

            Opportunity opp = new Opportunity(
                Name = 'Person Opp',
                AccountId = personAccount.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(7),
                Pricebook2Id = standardPricebookId,
                Uniek_Segment__c = 'Wasserij'
            );
            insert opp;

            Product2 product = new Product2(Name = 'Person Product', IsActive = true, Segment__c = 'Wasserij');
            insert product;

            PricebookEntry pbe = new PricebookEntry(
                Pricebook2Id = standardPricebookId,
                Product2Id = product.Id,
                UnitPrice = 25,
                IsActive = true
            );
            insert pbe;

            OpportunityLineItem oli = new OpportunityLineItem(
                OpportunityId = opp.Id,
                PricebookEntryId = pbe.Id,
                Quantity = 1,
                UnitPrice = 25
            );
            insert oli;

            OpportunityToWorkOrderConverter.Request request = new OpportunityToWorkOrderConverter.Request();
            request.opportunityId = opp.Id;

            Test.startTest();
            List<OpportunityToWorkOrderConverter.Response> responses = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ request });
            Test.stopTest();

            System.assertEquals(true, responses[0].success, responses[0].message);

            Werk_Order__c werkOrder = [
                SELECT Contactpersoon__c
                FROM Werk_Order__c
                WHERE Opportunity__c = :opp.Id
            ];
            System.assertEquals(personAccountWithContact.PersonContactId, werkOrder.Contactpersoon__c, 'Person Account contact moet worden overgenomen.');
        } catch (DmlException ex) {
            if (ex.getMessage() != null && ex.getMessage().contains('Record Type ID')) {
                System.debug('Skipping convertSetsContactFromPersonAccount test because Person Account record type assignments are not valid in this org: ' + ex.getMessage());
                return;
            }
            throw ex;
        }
    }

    @IsTest
    static void convertReusesExistingWorkOrder() {
        Id werkOrderRecordTypeId = getRecordTypeIdByName('Werk_Order__c', 'Wasserij');
        Id wasserijItemRecordTypeId = getRecordTypeIdByName('Wasserij_Item__c', 'WI_Wasserij');
        System.assertNotEquals(null, werkOrderRecordTypeId, 'Record Type "Wasserij" voor Werk_Order__c ontbreekt.');
        System.assertNotEquals(null, wasserijItemRecordTypeId, 'Record Type "WI_Wasserij" voor Wasserij_Item__c ontbreekt.');

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Account accountRecord = new Account(Name = 'Reuse Account');
        insert accountRecord;

        Account partnerAccount = new Account(Name = 'Reuse Partner');
        insert partnerAccount;

    Id newPostcodeAreaId = createPostcodeRange('Area 2020', 2000, 2099);

    Id oldPostcodeAreaId = createPostcodeRange('Area OLD', 9000, 9099);

        Opportunity opp = new Opportunity(
            Name = 'Reuse Opportunity',
            AccountId = accountRecord.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Pricebook2Id = standardPricebookId,
            Partner__c = partnerAccount.Id,
            Postcodegebied__c = newPostcodeAreaId,
            Uniek_Segment__c = 'Wasserij',
            Ophaalstraat__c = 'Pickup Nieuw',
            Ophaaladres_Toevoeging__c = '3',
            Ophaalpostcode__c = '2000AB',
            Ophaalplaats__c = 'Haarlem',
            Afleverstraat__c = 'Delivery Nieuw',
            Afleveradres_Toevoeging__c = '5',
            Afleverpostcode__c = '2010CD',
            Afleverplaats__c = 'Leiden'
        );
        insert opp;

        Product2 product = new Product2(Name = 'Reuse Product', IsActive = true, Segment__c = 'Wasserij');
        insert product;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = product.Id,
            UnitPrice = 30,
            IsActive = true
        );
        insert pbe;

        OpportunityLineItem oli = new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 3,
            UnitPrice = 30,
            Description = 'Reusable item'
        );
        insert oli;

        Werk_Order__c existingWorkOrder = new Werk_Order__c(
            Opportunity__c = opp.Id,
            Account__c = accountRecord.Id,
            Partner__c = null,
            Postcodegebied__c = oldPostcodeAreaId,
            Uniek_Segment__c = 'SR',
            RecordTypeId = werkOrderRecordTypeId,
            Ander_Ophaaladres__c = false,
            Ophaaladres1__Street__s = 'Oud Pickup',
            Ophaaladres_toevoeging__c = '1',
            Ophaaladres1__PostalCode__s = '9999ZZ',
            Ophaaladres1__City__s = 'Oud Plaats'
        );
        insert existingWorkOrder;

        OpportunityToWorkOrderConverter.Request request = new OpportunityToWorkOrderConverter.Request();
        request.opportunityId = opp.Id;

        Test.startTest();
        List<OpportunityToWorkOrderConverter.Response> responses = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        OpportunityToWorkOrderConverter.Response response = responses[0];
        System.assertEquals(true, response.success, response.message);
        System.assertEquals(existingWorkOrder.Id, response.werkOrderId, 'Bestaande werkorder moet hergebruikt worden.');
        System.assertEquals(1, response.createdItems, 'Verwacht aantal Wasserij Items komt niet overeen.');

        Integer workOrderCount = [SELECT COUNT() FROM Werk_Order__c WHERE Opportunity__c = :opp.Id];
        System.assertEquals(1, workOrderCount, 'Er had geen tweede werkorder aangemaakt mogen worden.');

        Werk_Order__c refreshedWorkOrder = [
            SELECT Partner__c, Postcodegebied__c, Uniek_Segment__c,
                   Ander_Ophaaladres__c, Ophaaladres1__Street__s, Ophaaladres_toevoeging__c, Ophaaladres1__PostalCode__s, Ophaaladres1__City__s
            FROM Werk_Order__c
            WHERE Id = :existingWorkOrder.Id
        ];
        System.assertEquals(partnerAccount.Id, refreshedWorkOrder.Partner__c, 'Partner moet worden bijgewerkt.');
    System.assertEquals(newPostcodeAreaId, refreshedWorkOrder.Postcodegebied__c, 'Postcodegebied moet worden bijgewerkt.');
        System.assertEquals('Wasserij', refreshedWorkOrder.Uniek_Segment__c, 'Uniek segment moet worden bijgewerkt.');
        System.assertEquals(true, refreshedWorkOrder.Ander_Ophaaladres__c, 'Ander ophaaladres moet true zijn.');
        System.assertEquals('Pickup Nieuw', refreshedWorkOrder.Ophaaladres1__Street__s);
        System.assertEquals('3', refreshedWorkOrder.Ophaaladres_toevoeging__c);
        System.assertEquals('2000AB', refreshedWorkOrder.Ophaaladres1__PostalCode__s);
        System.assertEquals('Haarlem', refreshedWorkOrder.Ophaaladres1__City__s);

        List<Wasserij_Item__c> items = [
            SELECT RecordTypeId, Werk_Order__c
            FROM Wasserij_Item__c
            WHERE Werk_Order__c = :existingWorkOrder.Id
        ];
        System.assertEquals(1, items.size(), 'Verwacht één Wasserij item.');
        System.assertEquals(wasserijItemRecordTypeId, items[0].RecordTypeId);
    }

    @IsTest
    static void convertIsIdempotent_NoDuplicateItemsOnSecondRun() {
        Id werkOrderRecordTypeId = getRecordTypeIdByName('Werk_Order__c', 'Wasserij');
        Id wasserijItemRecordTypeId = getRecordTypeIdByName('Wasserij_Item__c', 'WI_Wasserij');
        System.assertNotEquals(null, werkOrderRecordTypeId, 'Record Type "Wasserij" voor Werk_Order__c ontbreekt.');
        System.assertNotEquals(null, wasserijItemRecordTypeId, 'Record Type "WI_Wasserij" voor Wasserij_Item__c ontbreekt.');

        Id standardPricebookId = Test.getStandardPricebookId();
        update new Pricebook2(Id = standardPricebookId, IsActive = true);

        Account acc = new Account(Name = 'Idempotent Acc');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Idempotent Opp',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(3),
            Pricebook2Id = standardPricebookId,
            Uniek_Segment__c = 'Wasserij'
        );
        insert opp;

        Product2 p1 = new Product2(Name = 'Kleed 1', IsActive = true, Segment__c = 'Wasserij');
        Product2 p2 = new Product2(Name = 'Kleed extra', IsActive = true, Segment__c = 'Wasserij');
        insert new List<Product2>{ p1, p2 };

        PricebookEntry pbe1 = new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = p1.Id, UnitPrice = 10, IsActive = true);
        PricebookEntry pbe2 = new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = p2.Id, UnitPrice = 5, IsActive = true);
        insert new List<PricebookEntry>{ pbe1, pbe2 };

        OpportunityLineItem oli1 = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe1.Id, Quantity = 1, UnitPrice = 10);
        oli1.Lengte_cm__c = 100; oli1.Breedte_cm__c = 50; oli1.Diameter_cm__c = 0;
        insert oli1;

        OpportunityLineItem oli2 = new OpportunityLineItem(OpportunityId = opp.Id, PricebookEntryId = pbe2.Id, Quantity = 1, UnitPrice = 5);
        oli2.Gerelateerd_Product__c = oli1.Id;
        insert oli2;

        OpportunityToWorkOrderConverter.Request req = new OpportunityToWorkOrderConverter.Request();
        req.opportunityId = opp.Id;

        Test.startTest();
        List<OpportunityToWorkOrderConverter.Response> r1 = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ req });
        // Second run should not create duplicates
        List<OpportunityToWorkOrderConverter.Response> r2 = OpportunityToWorkOrderConverter.convert(new List<OpportunityToWorkOrderConverter.Request>{ req });
        Test.stopTest();

        System.assertEquals(true, r1[0].success, r1[0].message);
        System.assertEquals(true, r2[0].success, r2[0].message);

        Id woId = r2[0].werkOrderId;
        List<Wasserij_Item__c> items = [
            SELECT Id, RecordTypeId, Line_Item_Id__c, Gerelateerd_Wasserij_Item__c
            FROM Wasserij_Item__c
            WHERE Werk_Order__c = :woId
        ];
        System.assertEquals(2, items.size(), 'Converter should be idempotent and not create duplicates.');
        // Validate the Line_Item_Id__c mapping exists for both OLIs
        Set<String> lineIds = new Set<String>();
        for (Wasserij_Item__c wi : items) {
            System.assertEquals(wasserijItemRecordTypeId, wi.RecordTypeId);
            System.assertNotEquals(null, wi.Line_Item_Id__c, 'Line_Item_Id__c must be set.');
            lineIds.add(wi.Line_Item_Id__c);
        }
        System.assertEquals(new Set<String>{ (String)oli1.Id, (String)oli2.Id }, lineIds, 'Each Wasserij item should map to its OLI.');
    }

    private static Id getRecordTypeIdByName(String sobjectApiName, String recordTypeName) {
        Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(sobjectApiName);
        if (sobjectType == null) {
            return null;
        }
        Schema.DescribeSObjectResult describeResult = sobjectType.getDescribe();
        Map<String, Schema.RecordTypeInfo> recordTypesByName = describeResult.getRecordTypeInfosByName();
        if (recordTypesByName.containsKey(recordTypeName)) {
            return recordTypesByName.get(recordTypeName).getRecordTypeId();
        }
        Map<String, Schema.RecordTypeInfo> recordTypesByDeveloperName = describeResult.getRecordTypeInfosByDeveloperName();
        if (recordTypesByDeveloperName.containsKey(recordTypeName)) {
            return recordTypesByDeveloperName.get(recordTypeName).getRecordTypeId();
        }
        return null;
    }

    private static Id getPersonAccountRecordTypeId() {
        Schema.DescribeSObjectResult accountDescribe = Account.SObjectType.getDescribe();
        for (Schema.RecordTypeInfo info : accountDescribe.getRecordTypeInfos()) {
            if (info.isPersonType() && info.isAvailable()) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }

    private static Id createPostcodeRange(String name, Integer startValue, Integer endValue) {
        Postcode_Range__c range = new Postcode_Range__c(
            Name = name,
            Postcode_Begin__c = startValue,
            Postcode_Einde__c = endValue
        );
        insert range;
        return range.Id;
    }
}