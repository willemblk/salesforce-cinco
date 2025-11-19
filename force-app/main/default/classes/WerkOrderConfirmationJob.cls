public with sharing class WerkOrderConfirmationJob implements Queueable {
    private final Set<Id> werkOrderIds;

    public WerkOrderConfirmationJob(Set<Id> werkOrderIds) {
        this.werkOrderIds = (werkOrderIds == null) ? new Set<Id>() : new Set<Id>(werkOrderIds);
    }

    public void execute(QueueableContext context) {
        if (werkOrderIds == null || werkOrderIds.isEmpty()) {
            return;
        }

        List<Werk_Order__c> toConfirm = [
            SELECT Id, Bevestigingen_sturen__c, Automation_Bypass__c
            FROM Werk_Order__c
            WHERE Id IN :werkOrderIds
        ];

        if (toConfirm.isEmpty()) {
            return;
        }

        List<Werk_Order__c> updates = new List<Werk_Order__c>();
        Set<Id> bypassToggled = new Set<Id>();
        for (Werk_Order__c wo : toConfirm) {
            if (wo.Bevestigingen_sturen__c != true) {
                Werk_Order__c updateRecord = new Werk_Order__c(Id = wo.Id);
                updateRecord.Bevestigingen_sturen__c = true;
                if (wo.Automation_Bypass__c != true) {
                    updateRecord.Automation_Bypass__c = true;
                    bypassToggled.add(wo.Id);
                }
                updates.add(updateRecord);
            }
        }

        if (updates.isEmpty()) {
            return;
        }

        try {
            Database.update(updates, false);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'WerkOrderConfirmationJob failed for ' + updates.size() + ' records: ' + ex.getMessage());
            return;
        }

        if (bypassToggled.isEmpty()) {
            return;
        }

        List<Werk_Order__c> revertBypass = new List<Werk_Order__c>();
        for (Id woId : bypassToggled) {
            Werk_Order__c revert = new Werk_Order__c(Id = woId);
            revert.Automation_Bypass__c = false;
            revertBypass.add(revert);
        }
        try {
            Database.update(revertBypass, false);
        } catch (Exception ex) {
            System.debug(LoggingLevel.WARN, 'WerkOrderConfirmationJob bypass revert failed for ' + revertBypass.size() + ' records: ' + ex.getMessage());
        }
    }
}
