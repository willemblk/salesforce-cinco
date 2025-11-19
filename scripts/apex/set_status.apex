LeadStatus convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE ApiName = 'Gekwalificeerd' LIMIT 1];
Lead leadRecord = new Lead(FirstName = 'Status', LastName = 'Setter', Company = 'Test Co', Status = convertedStatus.MasterLabel);
insert leadRecord;
System.debug('Inserted lead with status: ' + leadRecord.Status);
