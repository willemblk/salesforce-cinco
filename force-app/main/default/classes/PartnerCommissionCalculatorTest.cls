@IsTest
private class PartnerCommissionCalculatorTest {

    @TestSetup
    static void setupData() {
        // Create a Partner Account
        Account partner = new Account(Name = 'Partner A');
        insert partner;

        // Commission structures
        Partner_Commission_Structure__c percentRule = new Partner_Commission_Structure__c(
            Partner__c = partner.Id,
            Segment__c = 'Wasserij',
            Commission_Type__c = 'percentage',
            Commission_Value__c = 10, // 10%
            Geldig_van__c = Date.today().addDays(-10),
            Geldig_tot__c = Date.today().addDays(10)
        );
        insert percentRule;

        Partner_Commission_Structure__c fixedRule = new Partner_Commission_Structure__c(
            Partner__c = partner.Id,
            Segment__c = 'SR',
            Commission_Type__c = 'Vast bedrag',
            Commission_Value__c = 250,
            Geldig_van__c = Date.today().addDays(-5),
            Geldig_tot__c = Date.today().addDays(30)
        );
        insert fixedRule;


        // Expired rule should be ignored
        Partner_Commission_Structure__c expiredRule = new Partner_Commission_Structure__c(
            Partner__c = partner.Id,
            Segment__c = 'Wasserij',
            Commission_Type__c = 'Percentage',
            Commission_Value__c = 99,
            Geldig_van__c = Date.today().addDays(-100),
            Geldig_tot__c = Date.today().addDays(-1)
        );
        insert expiredRule;

        // Create Opportunities in two segments
        Opportunity opp1 = new Opportunity(
            Name = 'Opp Wasserij 1',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Amount = 1000,
            Partner__c = partner.Id,
            Uniek_Segment__c = 'Wasserij'
        );
        Opportunity opp2 = new Opportunity(
            Name = 'Opp SR 1',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15),
            Amount = 800,
            Partner__c = partner.Id,
            Uniek_Segment__c = 'SR'
        );
        insert new List<Opportunity>{ opp1, opp2 };
    }

    @IsTest
    static void calculatesPercentageAndFixed() {
        List<Opportunity> opps = [SELECT Id, Commission_Amount__c FROM Opportunity WHERE Name IN ('Opp Wasserij 1','Opp SR 1') ORDER BY Name ASC];
        System.assertEquals(2, opps.size());

        List<PartnerCommissionCalculator.Request> reqs = new List<PartnerCommissionCalculator.Request>();
        for (Opportunity o : opps) {
            PartnerCommissionCalculator.Request r = new PartnerCommissionCalculator.Request();
            r.opportunityId = o.Id;
            reqs.add(r);
        }

        Test.startTest();
        List<PartnerCommissionCalculator.Result> results = PartnerCommissionCalculator.calculate(reqs);
        Test.stopTest();

        System.assertEquals(2, results.size());

        Map<Id, Opportunity> refreshed = new Map<Id, Opportunity>([
            SELECT Id, Commission_Amount__c, Amount, Uniek_Segment__c FROM Opportunity WHERE Id IN :new Map<Id, Opportunity>(opps).keySet()
        ]);

        // Wasserij -> 10% of 1000 = 100
        for (PartnerCommissionCalculator.Result res : results) {
            Opportunity o = refreshed.get(res.opportunityId);
            if (o.Uniek_Segment__c == 'Wasserij') {
                System.assertEquals(100, o.Commission_Amount__c, 'Wasserij commissie moet 100 zijn.');
            } else if (o.Uniek_Segment__c == 'SR') {
                System.assertEquals(250, o.Commission_Amount__c, 'SR commissie moet 250 zijn.');
            }
            System.assertEquals(true, res.success, 'Result success expected.');
        }
    }

    @IsTest
    static void clearsWhenNoMatchOrMissingData() {
        // Create partner-less or missing segment opp
        Opportunity noPartner = new Opportunity(
            Name = 'No Partner', StageName = 'Prospecting', CloseDate = Date.today().addDays(10), Amount = 500
        );
        Opportunity noSegment = new Opportunity(
            Name = 'No Segment', StageName = 'Prospecting', CloseDate = Date.today().addDays(10), Amount = 500,
            Partner__c = [SELECT Id FROM Account LIMIT 1].Id
        );
        insert new List<Opportunity>{ noPartner, noSegment };

        List<PartnerCommissionCalculator.Request> reqs = new List<PartnerCommissionCalculator.Request>();
        for (Opportunity o : [SELECT Id FROM Opportunity WHERE Name IN ('No Partner','No Segment')]) {
            PartnerCommissionCalculator.Request r = new PartnerCommissionCalculator.Request();
            r.opportunityId = o.Id;
            reqs.add(r);
        }

        Test.startTest();
        List<PartnerCommissionCalculator.Result> results = PartnerCommissionCalculator.calculate(reqs);
        Test.stopTest();

        Map<Id, Opportunity> refreshed = new Map<Id, Opportunity>([
            SELECT Id, Commission_Amount__c FROM Opportunity WHERE Id IN :new Map<Id, Opportunity>([SELECT Id FROM Opportunity WHERE Name IN ('No Partner','No Segment')]).keySet()
        ]);

        for (PartnerCommissionCalculator.Result res : results) {
            Opportunity o = refreshed.get(res.opportunityId);
            System.assertEquals(null, o.Commission_Amount__c, 'Commission should be cleared when no match or missing data.');
        }
    }

    @IsTest
    static void noStructureAndAmountNullAndLatestStartDate() {
        Account p = [SELECT Id FROM Account LIMIT 1];

        // Opp with partner+segment but no commission structure -> should clear (use valid segment without structures: Dakkapel)
        Opportunity noRule = new Opportunity(
            Name = 'No Rule Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(5),
            Amount = 500, Partner__c = p.Id, Uniek_Segment__c = 'Dakkapel'
        );
        // Opp with amount null -> should clear
        Opportunity amountNull = new Opportunity(
            Name = 'Amount Null Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(5),
            Amount = null, Partner__c = p.Id, Uniek_Segment__c = 'Dakkapel'
        );
        insert new List<Opportunity>{ noRule, amountNull };

        // Also create a partner B with two overlapping rules on an allowed segment and ensure the latest start date wins
        Account partnerB = new Account(Name = 'Partner B');
        insert partnerB;
        Partner_Commission_Structure__c older = new Partner_Commission_Structure__c(
            Partner__c = partnerB.Id,
            Segment__c = 'Wasserij',
            Commission_Type__c = 'Percentage',
            Commission_Value__c = 5,
            Geldig_van__c = Date.today().addDays(-10),
            Geldig_tot__c = Date.today().addDays(10)
        );
        Partner_Commission_Structure__c newer = new Partner_Commission_Structure__c(
            Partner__c = partnerB.Id,
            Segment__c = 'Wasserij',
            Commission_Type__c = 'Percentage',
            Commission_Value__c = 7,
            Geldig_van__c = Date.today().addDays(-1),
            Geldig_tot__c = Date.today().addDays(10)
        );
        insert new List<Partner_Commission_Structure__c>{ older, newer };

        Opportunity tieOpp = new Opportunity(
            Name = 'TieSeg Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(7),
            Amount = 100, Partner__c = partnerB.Id, Uniek_Segment__c = 'Wasserij'
        );
        insert tieOpp;

        List<PartnerCommissionCalculator.Request> reqs = new List<PartnerCommissionCalculator.Request>();
        for (Opportunity ox : [SELECT Id FROM Opportunity WHERE Name IN ('No Rule Opp','Amount Null Opp','TieSeg Opp')]) {
            PartnerCommissionCalculator.Request r = new PartnerCommissionCalculator.Request();
            r.opportunityId = ox.Id;
            reqs.add(r);
        }

        Test.startTest();
        List<PartnerCommissionCalculator.Result> results = PartnerCommissionCalculator.calculate(reqs);
        Test.stopTest();

        Map<Id, Opportunity> refreshed = new Map<Id, Opportunity>([
            SELECT Id, Commission_Amount__c, Name FROM Opportunity WHERE Id IN :new Map<Id, Opportunity>([SELECT Id FROM Opportunity WHERE Name IN ('No Rule Opp','Amount Null Opp','TieSeg Opp')]).keySet()
        ]);

        for (PartnerCommissionCalculator.Result res : results) {
            Opportunity ox = refreshed.get(res.opportunityId);
            if (ox.Name == 'TieSeg Opp') {
                System.assertEquals(7, ox.Commission_Amount__c, 'Latest start date rule (7%) should apply to 100 amount.');
            } else {
                System.assertEquals(null, ox.Commission_Amount__c, 'Commission should be cleared when no rule or amount null.');
            }
            System.assertEquals(true, res.success, 'Result success expected.');
        }
    }

    @IsTest
    static void revenueShareCalculatesAndClears() {
        // Prepare a partner for referral
        Account refPartner = new Account(Name = 'Referrer Partner');
        insert refPartner;

        // Active referral code
        Partner_Referral_Code__c activeCode = new Partner_Referral_Code__c(
            Code__c = 'REF-123',
            Active__c = true,
            Partner__c = refPartner.Id
        );
        insert activeCode;

        // Inactive referral code
        Partner_Referral_Code__c inactiveCode = new Partner_Referral_Code__c(
            Code__c = 'REF-OFF',
            Active__c = false,
            Partner__c = refPartner.Id
        );
        insert inactiveCode;

        // Use existing partner from setup for commission structures
        Account partnerForCommission = [SELECT Id FROM Account WHERE Name = 'Partner A' LIMIT 1];

        // Opp with matching active code (should compute shares 70/30 of Amount)
        Opportunity oppActive = new Opportunity(
            Name = 'Opp With Active Code', StageName = 'Prospecting', CloseDate = Date.today().addDays(5),
            Amount = 1000,
            Partner__c = partnerForCommission.Id, // so commission can compute too
            Uniek_Segment__c = 'Wasserij',
            Referrer_Code__c = 'REF-123'
        );
        // Opp with inactive code (should clear shares)
        Opportunity oppInactive = new Opportunity(
            Name = 'Opp With Inactive Code', StageName = 'Prospecting', CloseDate = Date.today().addDays(5),
            Amount = 500,
            Partner__c = partnerForCommission.Id,
            Uniek_Segment__c = 'Wasserij',
            Referrer_Code__c = 'REF-OFF'
        );
        // Opp with no code (shares cleared)
        Opportunity oppNoCode = new Opportunity(
            Name = 'Opp No Code', StageName = 'Prospecting', CloseDate = Date.today().addDays(5),
            Amount = 750,
            Partner__c = partnerForCommission.Id,
            Uniek_Segment__c = 'Wasserij'
        );
        insert new List<Opportunity>{ oppActive, oppInactive, oppNoCode };

        List<PartnerCommissionCalculator.Request> reqs = new List<PartnerCommissionCalculator.Request>();
        for (Opportunity o : [SELECT Id FROM Opportunity WHERE Name IN ('Opp With Active Code','Opp With Inactive Code','Opp No Code')]) {
            PartnerCommissionCalculator.Request r = new PartnerCommissionCalculator.Request();
            r.opportunityId = o.Id;
            reqs.add(r);
        }

        Test.startTest();
        List<PartnerCommissionCalculator.Result> results = PartnerCommissionCalculator.calculate(reqs);
        Test.stopTest();

        List<Opportunity> refreshedList = [
            SELECT Name, Referrer_Partner__c, Referrer_Share__c, Cinco_Share__c, Amount
            FROM Opportunity
            WHERE Name IN ('Opp With Active Code','Opp With Inactive Code','Opp No Code')
        ];
        Map<String, Opportunity> refreshed = new Map<String, Opportunity>();
        for (Opportunity o : refreshedList) { refreshed.put(o.Name, o); }

        Opportunity oa = refreshed.get('Opp With Active Code');
        System.assertEquals(refPartner.Id, oa.Referrer_Partner__c, 'Referrer partner should be set');
        System.assertEquals(70, oa.Referrer_Share__c, '70% of commission (10% of 1000 = 100 -> 70)');
        System.assertEquals(30, oa.Cinco_Share__c, '30% of commission (100 -> 30)');

        Opportunity oi = refreshed.get('Opp With Inactive Code');
        System.assertEquals(null, oi.Referrer_Partner__c, 'Inactive code should not set partner');
        System.assertEquals(null, oi.Referrer_Share__c, 'Inactive code should clear share');
        System.assertEquals(null, oi.Cinco_Share__c, 'Inactive code should clear share');

    Opportunity oppNo = refreshed.get('Opp No Code');
    System.assertEquals(null, oppNo.Referrer_Partner__c, 'No code should not set partner');
    System.assertEquals(null, oppNo.Referrer_Share__c, 'No code should clear share');
    System.assertEquals(null, oppNo.Cinco_Share__c, 'No code should clear share');
    }
}
