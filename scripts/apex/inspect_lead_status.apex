List<LeadStatus> statuses = [SELECT MasterLabel, ApiName, IsConverted, IsClosed, SortOrder, IsDefault FROM LeadStatus ORDER BY SortOrder];
for (LeadStatus status : statuses) {
    System.debug(status.ApiName + ' | ' + status.MasterLabel + ' | converted=' + status.IsConverted + ' | closed=' + status.IsClosed + ' | default=' + status.IsDefault);
}
