Opportunity o=[SELECT Id, Name, Amount, Commission_Amount__c, Partner__r.Name, Uniek_Segment__c FROM Opportunity WHERE Id='0069X00000StoP3QAJ' LIMIT 1];
System.debug('COMM: Opp=' + o.Name + ' | Amount=' + o.Amount + ' | Commission_Amount__c=' + o.Commission_Amount__c + ' | Partner=' + o.Partner__r.Name + ' | Segment=' + o.Uniek_Segment__c);
