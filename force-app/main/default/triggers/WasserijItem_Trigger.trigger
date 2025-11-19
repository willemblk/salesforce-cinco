trigger WasserijItem_Trigger on Wasserij_Item__c (after insert, after update, after delete, after undelete) {
    
    if (TriggerRecursionGuard.isRunning('WasserijItem_Trigger')) {
        return;
    }

    Set<Id> werkOrderIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Wasserij_Item__c item : Trigger.new) {
            if (item.Werk_Order__c != null) werkOrderIds.add(item.Werk_Order__c);
        }
    }
    if (Trigger.isDelete) {
        for (Wasserij_Item__c item : Trigger.old) {
            if (item.Werk_Order__c != null) werkOrderIds.add(item.Werk_Order__c);
        }
    }

    if (!werkOrderIds.isEmpty()) {
        List<Wasserij_Item__c> itemsToUpdate = new List<Wasserij_Item__c>();
        
        for (Id woId : werkOrderIds) {
            // Roep de service aan, die nu een lijst teruggeeft
            itemsToUpdate.addAll((List<Wasserij_Item__c>) PricingService.repriceWerkorder(woId));
        }

        if (!itemsToUpdate.isEmpty()) {
            TriggerRecursionGuard.setRunning('WasserijItem_Trigger');
            try {
                update itemsToUpdate;
            } finally {
                TriggerRecursionGuard.setNotRunning('WasserijItem_Trigger');
            }
        }
    }
}