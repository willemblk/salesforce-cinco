trigger OpportunityLineItem_Trigger on OpportunityLineItem (after insert, after update, after delete, after undelete) {

    if (TriggerRecursionGuard.isRunning('OpportunityLineItem_Trigger')) {
        return;
    }

    Set<Id> opportunityIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (OpportunityLineItem item : Trigger.new) {
            if (item.OpportunityId != null) opportunityIds.add(item.OpportunityId);
        }
    }
    if (Trigger.isDelete) {
        for (OpportunityLineItem item : Trigger.old) {
            if (item.OpportunityId != null) opportunityIds.add(item.OpportunityId);
        }
    }

    if (!opportunityIds.isEmpty()) {
        List<OpportunityLineItem> itemsToUpdate = new List<OpportunityLineItem>();

        for (Id oppId : opportunityIds) {
            // Roep de service aan, die nu een lijst teruggeeft
            itemsToUpdate.addAll((List<OpportunityLineItem>) PricingService.repriceOpportunity(oppId));
        }

        if (!itemsToUpdate.isEmpty()) {
            TriggerRecursionGuard.setRunning('OpportunityLineItem_Trigger');
            try {
                update itemsToUpdate;
            } finally {
                TriggerRecursionGuard.setNotRunning('OpportunityLineItem_Trigger');
            }
        }
    }
}