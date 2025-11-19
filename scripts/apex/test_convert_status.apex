LeadStatus openStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = false LIMIT 1];
Lead leadRecord = new Lead(
    FirstName = 'Status',
    LastName = 'Check',
    Company = 'Test Co',
    Status = openStatus.MasterLabel
);
insert leadRecord;

Database.LeadConvert lc = new Database.LeadConvert();
lc.setLeadId(leadRecord.Id);
Database.LeadConvertResult result = Database.convertLead(lc);
System.debug('Success -> ' + result.isSuccess());
if (!result.isSuccess()) {
    for (Database.Error err : result.getErrors()) {
        System.debug('Error: ' + err.getStatusCode() + ' | ' + err.getMessage());
    }
}
