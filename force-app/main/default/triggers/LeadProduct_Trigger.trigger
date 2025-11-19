trigger LeadProduct_Trigger on Lead_Product__c (after insert, after update, after delete, after undelete) {

    if (TriggerRecursionGuard.isRunning('LeadProduct_Trigger')) {
        return;
    }

    Set<Id> leadIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Lead_Product__c item : Trigger.new) {
            if (item.Lead__c != null) leadIds.add(item.Lead__c);
        }
    }
    if (Trigger.isDelete) {
        for (Lead_Product__c item : Trigger.old) {
            if (item.Lead__c != null) leadIds.add(item.Lead__c);
        }
    }

    if (!leadIds.isEmpty()) {
        List<Lead_Product__c> itemsToUpdate = new List<Lead_Product__c>();

        for (Id leadId : leadIds) {
            // Roep de service aan, die nu een lijst teruggeeft
            itemsToUpdate.addAll((List<Lead_Product__c>) PricingService.repriceLead(leadId));
        }

        if (!itemsToUpdate.isEmpty()) {
            TriggerRecursionGuard.setRunning('LeadProduct_Trigger');
            try {
                update itemsToUpdate;
            } finally {
                TriggerRecursionGuard.setNotRunning('LeadProduct_Trigger');
            }
        }
    }
}