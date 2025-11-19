List<PartnerCommissionCalculator.Request> reqs = new List<PartnerCommissionCalculator.Request>();
PartnerCommissionCalculator.Request r = new PartnerCommissionCalculator.Request();
r.opportunityId = Id.valueOf('0069X00000StoP3QAJ');
reqs.add(r);
List<PartnerCommissionCalculator.Result> results = PartnerCommissionCalculator.calculate(reqs);
System.debug('RESULT: success=' + results[0].success + ' msg=' + results[0].message + ' amount=' + results[0].commissionAmount);
Opportunity o=[SELECT Commission_Amount__c FROM Opportunity WHERE Id=:r.opportunityId];
System.debug('NEW COMMISSION=' + o.Commission_Amount__c);
