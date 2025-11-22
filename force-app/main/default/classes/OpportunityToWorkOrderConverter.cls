public with sharing class OpportunityToWorkOrderConverter {

    private static final String WORK_ORDER_RECORD_TYPE_NAME = 'Wasserij';
    private static final String WASSERIJ_ITEM_RECORD_TYPE_NAME = 'WI_Wasserij';
    private static Map<String, Id> recordTypeIdCache = new Map<String, Id>();
    // Internal flag to prevent endless re-enqueue when running from the async reprocessor
    private static Boolean ASYNC_REPROCESS_CONTEXT = false;

    public class Request {
        @InvocableVariable(required=true)
        public Id opportunityId;
    }

    public class Response {
        @InvocableVariable
        public Id opportunityId;

        @InvocableVariable
        public Id werkOrderId;

        @InvocableVariable
        public Integer createdItems;

        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String message;
    }

    private class AggregatedResult {
        Id opportunityId;
        Id werkOrderId;
        Id werkOrderRecordTypeId;
        Integer createdItems = 0;
        Boolean success = true;
        List<String> messages = new List<String>();
    }

    @InvocableMethod
    public static List<Response> convert(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        // Collect mappings for photo propagation
        Map<Id, Id> opportunityIdToWerkOrderIdForPhotos = new Map<Id, Id>();
        Map<Id, Id> oliIdToWasserijItemIdForPhotos = new Map<Id, Id>();

        Map<Id, List<Integer>> opportunityToIndexes = new Map<Id, List<Integer>>();
        Map<Id, AggregatedResult> aggregates = new Map<Id, AggregatedResult>();

        for (Integer idx = 0; idx < requests.size(); idx++) {
            Request req = requests[idx];
            Response resp = new Response();
            responses.add(resp);

            if (req == null || req.opportunityId == null) {
                resp.success = false;
                resp.message = 'OpportunityId is verplicht.';
                continue;
            }

            resp.opportunityId = req.opportunityId;
            if (!opportunityToIndexes.containsKey(req.opportunityId)) {
                opportunityToIndexes.put(req.opportunityId, new List<Integer>());
                AggregatedResult agg = new AggregatedResult();
                agg.opportunityId = req.opportunityId;
                aggregates.put(req.opportunityId, agg);
            }
            opportunityToIndexes.get(req.opportunityId).add(idx);
        }

        if (aggregates.isEmpty()) {
            return responses;
        }

        Set<Id> opportunityIds = aggregates.keySet();
        Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>([
                 SELECT Id, Name, AccountId, Partner__c, Postcodegebied__c, Uniek_Segment__c,
                   Ophaalstraat__c, Ophaaladres_Toevoeging__c, Ophaalpostcode__c, Ophaalplaats__c,
                     Afleverstraat__c, Afleveradres_Toevoeging__c, Afleverpostcode__c, Afleverplaats__c,
                     Dienst_Postcode_Associatie__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]);

        Set<Id> accountIds = new Set<Id>();
        for (Opportunity oppValue : opportunityMap.values()) {
            if (oppValue.AccountId != null) {
                accountIds.add(oppValue.AccountId);
            }
        }

        Map<Id, Account> accountMap = new Map<Id, Account>();
        if (!accountIds.isEmpty()) {
            accountMap = new Map<Id, Account>([
                SELECT Id, IsPersonAccount, PersonContactId, Standaard_Contact_Werk_Order__c
                FROM Account
                WHERE Id IN :accountIds
            ]);
        }

        Id werkOrderRecordTypeId = getRecordTypeId(Werk_Order__c.SObjectType, WORK_ORDER_RECORD_TYPE_NAME);
        Id wasserijItemRecordTypeId = getRecordTypeId(Wasserij_Item__c.SObjectType, WASSERIJ_ITEM_RECORD_TYPE_NAME);

        Map<Id, Werk_Order__c> existingWorkOrders = new Map<Id, Werk_Order__c>();
        for (Werk_Order__c wo : [
            SELECT Id, Opportunity__c, RecordTypeId, Partner__c, Postcodegebied__c, Uniek_Segment__c,
                   Ander_Ophaaladres__c, Ophaaladres1__Street__s, Ophaaladres1__PostalCode__s, Ophaaladres1__City__s,
                   Contactpersoon__c, Dienst_Postcode_Associatie__c
            FROM Werk_Order__c
            WHERE Opportunity__c IN :opportunityIds
        ]) {
            existingWorkOrders.put(wo.Opportunity__c, wo);
        }

        if (werkOrderRecordTypeId == null) {
            for (AggregatedResult agg : aggregates.values()) {
                agg.success = false;
                agg.messages.add('Record type "' + WORK_ORDER_RECORD_TYPE_NAME + '" niet gevonden voor Werk_Order__c.');
            }
        }
        if (wasserijItemRecordTypeId == null) {
            for (AggregatedResult agg : aggregates.values()) {
                agg.success = false;
                agg.messages.add('Record type "' + WASSERIJ_ITEM_RECORD_TYPE_NAME + '" niet gevonden voor Wasserij_Item__c.');
            }
        }

        List<Werk_Order__c> workOrdersToInsert = new List<Werk_Order__c>();
        List<Id> workOrderOpportunityOrder = new List<Id>();
        List<Werk_Order__c> workOrdersToUpdate = new List<Werk_Order__c>();
        Map<Id, Account> accountUpdates = new Map<Id, Account>();
        Map<Id, Set<Id>> accountIdToOppIds = new Map<Id, Set<Id>>();

        for (Id oppId : opportunityIds) {
            AggregatedResult agg = aggregates.get(oppId);
            Opportunity opp = opportunityMap.get(oppId);
            if (opp == null) {
                agg.success = false;
                agg.messages.add('Opportunity niet gevonden.');
                continue;
            }

            Account relatedAccount = (opp.AccountId != null) ? accountMap.get(opp.AccountId) : null;
            Id contactPersonId = resolveWorkOrderContactId(relatedAccount);

            Boolean useAlternatePickup = hasAlternatePickupAddress(opp);
            if (useAlternatePickup && opp.AccountId != null) {
                Account accUpdate = accountUpdates.get(opp.AccountId);
                if (accUpdate == null) {
                    accUpdate = new Account(Id = opp.AccountId);
                    accountUpdates.put(accUpdate.Id, accUpdate);
                }
                accUpdate.BillingStreet = normalizeBlankToNull(opp.Afleverstraat__c);
                accUpdate.BillingPostalCode = normalizeBlankToNull(opp.Afleverpostcode__c);
                accUpdate.BillingCity = normalizeBlankToNull(opp.Afleverplaats__c);
                try { accUpdate.put('BillingAddress_toevoeging__c', normalizeBlankToNull(opp.Afleveradres_Toevoeging__c)); } catch (Exception ignore) {}
                if (!accountIdToOppIds.containsKey(opp.AccountId)) {
                    accountIdToOppIds.put(opp.AccountId, new Set<Id>());
                }
                accountIdToOppIds.get(opp.AccountId).add(opp.Id);
            }

            Werk_Order__c existing = existingWorkOrders.get(oppId);
            if (existing != null) {
                agg.werkOrderId = existing.Id;
                agg.werkOrderRecordTypeId = existing.RecordTypeId;
                if (existing.Id != null && opp.Id != null && !opportunityIdToWerkOrderIdForPhotos.containsKey(opp.Id)) {
                    opportunityIdToWerkOrderIdForPhotos.put(opp.Id, existing.Id);
                }
                Boolean needsUpdate = false;
                if (existing.Partner__c != opp.Partner__c) {
                    existing.Partner__c = opp.Partner__c;
                    needsUpdate = true;
                }
                if (existing.Postcodegebied__c != opp.Postcodegebied__c) {
                    existing.Postcodegebied__c = opp.Postcodegebied__c;
                    needsUpdate = true;
                }
                if (existing.Uniek_Segment__c != opp.Uniek_Segment__c) {
                    existing.Uniek_Segment__c = opp.Uniek_Segment__c;
                    needsUpdate = true;
                }
                try {
                    if (existing.Dienst_Postcode_Associatie__c != opp.Dienst_Postcode_Associatie__c) {
                        existing.Dienst_Postcode_Associatie__c = opp.Dienst_Postcode_Associatie__c;
                        needsUpdate = true;
                    }
                } catch (Exception ignore) {}
                if (contactPersonId != null) {
                    try {
                        if (existing.Contactpersoon__c != contactPersonId) {
                            existing.Contactpersoon__c = contactPersonId;
                            needsUpdate = true;
                        }
                    } catch (Exception ignore) {}
                }
                // Sync address additions from Opportunity onto existing Werk Order
                try {
                    if (existing.Ophaaladres_Toevoeging__c != opp.Ophaaladres_Toevoeging__c) {
                        existing.Ophaaladres_Toevoeging__c = opp.Ophaaladres_Toevoeging__c;
                        needsUpdate = true;
                    }
                } catch (Exception ignore) {}
                try {
                    if (existing.Afleveradres_Toevoeging__c != opp.Afleveradres_Toevoeging__c) {
                        existing.Afleveradres_Toevoeging__c = opp.Afleveradres_Toevoeging__c;
                        needsUpdate = true;
                    }
                } catch (Exception ignore) {}
                if (useAlternatePickup) {
                    if (applyAlternatePickupAddress(existing, opp)) {
                        needsUpdate = true;
                    }
                }
                if (needsUpdate) {
                    workOrdersToUpdate.add(existing);
                }
                continue;
            }

            Werk_Order__c workOrder = new Werk_Order__c();
            // Prefer setting RecordType first so picklist validations use the correct record type
            if (werkOrderRecordTypeId != null) {
                workOrder.RecordTypeId = werkOrderRecordTypeId;
            }
            workOrder.Opportunity__c = opp.Id;
            workOrder.Account__c = opp.AccountId;
            workOrder.Partner__c = opp.Partner__c;
            workOrder.Postcodegebied__c = opp.Postcodegebied__c;
            workOrder.Uniek_Segment__c = opp.Uniek_Segment__c;
            try { workOrder.Dienst_Postcode_Associatie__c = opp.Dienst_Postcode_Associatie__c; } catch (Exception ignore) {}
            // Set status for Wasserij record type
            try { workOrder.Werk_Order_Status__c = 'Ophalen plannen'; } catch (Exception ignore) {}
            // Copy address additions from Opportunity
            try { workOrder.Ophaaladres_Toevoeging__c = opp.Ophaaladres_Toevoeging__c; } catch (Exception ignore) {}
            try { workOrder.Afleveradres_Toevoeging__c = opp.Afleveradres_Toevoeging__c; } catch (Exception ignore) {}
            // Set bypass flag to prevent heavy after-save flow paths on Werk Order during conversion
            try { workOrder.Automation_Bypass__c = true; } catch (Exception ignore) {}
            if (useAlternatePickup) {
                applyAlternatePickupAddress(workOrder, opp);
            }
            if (contactPersonId != null) {
                try { workOrder.Contactpersoon__c = contactPersonId; } catch (Exception ignore) {}
            }
            workOrdersToInsert.add(workOrder);
            workOrderOpportunityOrder.add(oppId);
        }

        if (!accountUpdates.isEmpty()) {
            List<Account> accountsPending = new List<Account>(accountUpdates.values());
            Database.SaveResult[] accountResults = Database.update(accountsPending, false);
            for (Integer i = 0; i < accountResults.size(); i++) {
                if (accountResults[i].isSuccess()) {
                    continue;
                }
                Account accRef = accountsPending[i];
                Set<Id> relatedOppIds = accountIdToOppIds.get(accRef.Id);
                if (relatedOppIds == null) {
                    continue;
                }
                for (Id relatedOppId : relatedOppIds) {
                    AggregatedResult agg = aggregates.get(relatedOppId);
                    if (agg == null) {
                        continue;
                    }
                    agg.success = false;
                    agg.messages.add('Bijwerken factuuradres mislukt: ' + collectErrors(accountResults[i].getErrors()));
                }
            }
        }

        if (!workOrdersToInsert.isEmpty()) {
            Database.SaveResult[] woResults = Database.insert(workOrdersToInsert, false);
            for (Integer i = 0; i < woResults.size(); i++) {
                Database.SaveResult sr = woResults[i];
                Id oppId = workOrderOpportunityOrder[i];
                AggregatedResult agg = aggregates.get(oppId);
                if (sr.isSuccess()) {
                    agg.werkOrderId = sr.getId();
                    agg.werkOrderRecordTypeId = werkOrderRecordTypeId;
                    Id oppIdInserted = oppId;
                    if (oppIdInserted != null && agg.werkOrderId != null) {
                        opportunityIdToWerkOrderIdForPhotos.put(oppIdInserted, agg.werkOrderId);
                    }
                } else {
                    agg.success = false;
                    agg.messages.add('Werk order insert mislukt: ' + collectErrors(sr.getErrors()));
                }
            }
        }

        if (!workOrdersToUpdate.isEmpty()) {
            Database.SaveResult[] updateResults = Database.update(workOrdersToUpdate, false);
            for (Integer i = 0; i < updateResults.size(); i++) {
                Database.SaveResult sr = updateResults[i];
                Id oppId = workOrdersToUpdate[i].Opportunity__c;
                AggregatedResult agg = aggregates.get(oppId);
                if (agg == null) {
                    continue;
                }
                if (!sr.isSuccess()) {
                    agg.success = false;
                    agg.messages.add('Werk order bijwerken mislukt: ' + collectErrors(sr.getErrors()));
                }
            }
        }

        List<OpportunityLineItem> opportunityLineItems = [
            SELECT Id, OpportunityId, Quantity, Description,
                   PricebookEntryId, PricebookEntry.Product2Id, PricebookEntry.Product2.Product_Category__c,
                   Product2Id, Product2.Product_Category__c,
                   Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, Gerelateerd_Product__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :opportunityIds
        ];

        // Build the set of Werk Order IDs from aggregates (existing or newly inserted)
        Set<Id> workOrderIds = new Set<Id>();
        for (AggregatedResult a : aggregates.values()) {
            if (a.werkOrderId != null) workOrderIds.add(a.werkOrderId);
        }

        // Before creating/updating Wasserij Items, enable bypass on related Werk Orders to avoid ping-pong flows
        if (!workOrderIds.isEmpty()) {
            List<Werk_Order__c> bypassOnList = new List<Werk_Order__c>();
            for (Id woId : workOrderIds) {
                Werk_Order__c woUpd = new Werk_Order__c(Id = woId);
                try { woUpd.Automation_Bypass__c = true; } catch (Exception ignore) {}
                bypassOnList.add(woUpd);
            }
            Database.SaveResult[] bypassOnResults = Database.update(bypassOnList, false);
            for (Integer i = 0; i < bypassOnResults.size(); i++) {
                if (!bypassOnResults[i].isSuccess()) {
                    Database.Error[] errs = bypassOnResults[i].getErrors();
                    for (AggregatedResult agg : aggregates.values()) {
                        if (workOrderIds.contains(agg.werkOrderId)) {
                            agg.success = false;
                            agg.messages.add('Werk order bypass inschakelen mislukt: ' + collectErrors(errs));
                        }
                    }
                }
            }
        }
        Map<String, Wasserij_Item__c> existingByLineItemId = new Map<String, Wasserij_Item__c>();
        if (!workOrderIds.isEmpty()) {
            for (Wasserij_Item__c wiExisting : [
                SELECT Id, Werk_Order__c, Line_Item_Id__c, Gerelateerd_Wasserij_Item__c
                FROM Wasserij_Item__c
                WHERE Werk_Order__c IN :workOrderIds
            ]) {
                if (String.isNotBlank(wiExisting.Line_Item_Id__c)) {
                    existingByLineItemId.put(wiExisting.Line_Item_Id__c, wiExisting);
                }
            }
        }

        List<Wasserij_Item__c> itemsToInsert = new List<Wasserij_Item__c>();
        List<Id> itemOpportunityOrder = new List<Id>();
        Map<Id, Wasserij_Item__c> oliToItem = new Map<Id, Wasserij_Item__c>();
        List<Wasserij_Item__c> itemsToUpdate = new List<Wasserij_Item__c>();
        Map<Id, Id> oliToOpportunity = new Map<Id, Id>();
        Map<Id, Id> childToParentOli = new Map<Id, Id>();
        Map<Id, Integer> oppToUpdatedItemCount = new Map<Id, Integer>();

        for (OpportunityLineItem oli : opportunityLineItems) {
            AggregatedResult agg = aggregates.get(oli.OpportunityId);
            if (agg == null || agg.werkOrderId == null) {
                continue;
            }

            String oliCategory = getOpportunityLineItemCategory(oli);
            Boolean isPackageLine = isPackageCategory(oliCategory);

            // Check if a Wasserij item for this OLI already exists (idempotent behavior)
            Wasserij_Item__c existing = existingByLineItemId.get((String)oli.Id);
            if (existing != null) {
                // Update existing to reflect current OLI details
                Wasserij_Item__c upd = new Wasserij_Item__c(
                    Id = existing.Id,
                    Product__c = determineProductId(oli),
                    Aantal__c = oli.Quantity,
                    Lengte__c = oli.Lengte_cm__c,
                    Breedte__c = oli.Breedte_cm__c,
                    Diameter__c = oli.Diameter_cm__c
                );
                // Mark as automation-driven to let flows skip heavy after-save paths (guard against ping-pong)
                try { upd.Created_By_Flow__c = true; } catch (Exception ignore) {}
                if (String.isNotBlank(oli.Description)) {
                    upd.Opmerkingen__c = oli.Description;
                }
                if (agg.werkOrderRecordTypeId != null && agg.werkOrderRecordTypeId == werkOrderRecordTypeId && wasserijItemRecordTypeId != null) {
                    upd.RecordTypeId = wasserijItemRecordTypeId;
                }
                itemsToUpdate.add(upd);
                oliToItem.put(oli.Id, existing);
                oliToOpportunity.put(oli.Id, oli.OpportunityId);
                Integer updateCounter = oppToUpdatedItemCount.containsKey(oli.OpportunityId) ? oppToUpdatedItemCount.get(oli.OpportunityId) : 0;
                oppToUpdatedItemCount.put(oli.OpportunityId, updateCounter + 1);
                if (existing.Id != null) {
                    oliIdToWasserijItemIdForPhotos.put(oli.Id, existing.Id);
                }
                if (oli.Gerelateerd_Product__c != null) {
                    childToParentOli.put(oli.Id, oli.Gerelateerd_Product__c);
                }
                continue;
            }

            // Create new Wasserij item for this OLI
            Wasserij_Item__c item = new Wasserij_Item__c();
            item.Werk_Order__c = agg.werkOrderId;
            item.Product__c = determineProductId(oli);
            item.Aantal__c = oli.Quantity;
            item.Lengte__c = oli.Lengte_cm__c;
            item.Breedte__c = oli.Breedte_cm__c;
            item.Diameter__c = oli.Diameter_cm__c;
            item.Line_Item_Id__c = (String)oli.Id;
            // Mark as automation-driven to let flows skip heavy after-save paths (guard against ping-pong)
            try { item.Created_By_Flow__c = true; } catch (Exception ignore) {}
            if (oli.Gerelateerd_Product__c != null) {
                item.Gerelateerd_Line_Item_Id__c = (String)oli.Gerelateerd_Product__c;
            }
            if (String.isNotBlank(oli.Description)) {
                item.Opmerkingen__c = oli.Description;
            }
            if (agg.werkOrderRecordTypeId != null && agg.werkOrderRecordTypeId == werkOrderRecordTypeId && wasserijItemRecordTypeId != null) {
                item.RecordTypeId = wasserijItemRecordTypeId;
            }
            itemsToInsert.add(item);
            itemOpportunityOrder.add(oli.OpportunityId);
            oliToItem.put(oli.Id, item);
            oliToOpportunity.put(oli.Id, oli.OpportunityId);
            // Map will be completed after insert when we have IDs; capture OLI now for later correlation
            if (oli.Gerelateerd_Product__c != null) {
                childToParentOli.put(oli.Id, oli.Gerelateerd_Product__c);
            } else if (isPackageLine) {
                AggregatedResult warnAgg = aggregates.get(oli.OpportunityId);
                if (warnAgg != null) {
                    warnAgg.messages.add('Package opportunity product ' + oli.Id + ' mist een gekoppelde primaire regel (Gerelateerd_Product__c). Item wordt als zelfstandig regel aangemaakt.');
                }
            }
        }

        if (!itemsToInsert.isEmpty()) {
            // Suppress trigger-driven reprice during bulk creation; we'll reprice once per WO at the end
            TriggerRecursionGuard.setRunning('WasserijItem_Trigger');
            Database.SaveResult[] wiResults = Database.insert(itemsToInsert, false);
            for (Integer i = 0; i < wiResults.size(); i++) {
                Database.SaveResult sr = wiResults[i];
                Id oppId = itemOpportunityOrder[i];
                AggregatedResult agg = aggregates.get(oppId);
                if (sr.isSuccess()) {
                    agg.createdItems++;
                    // Resolve inserted Wasserij item ID for OLI mapping (match by temporary object reference index)
                    Wasserij_Item__c insertedRef = itemsToInsert[i];
                    if (insertedRef != null && insertedRef.Line_Item_Id__c != null) {
                        // Line_Item_Id__c stores the OpportunityLineItem Id (String cast earlier)
                        oliIdToWasserijItemIdForPhotos.put((Id)insertedRef.Line_Item_Id__c, sr.getId());
                    }
                } else {
                    agg.success = false;
                    agg.messages.add('Wasserij item insert mislukt: ' + collectErrors(sr.getErrors()));
                }
            }
            TriggerRecursionGuard.setNotRunning('WasserijItem_Trigger');
        }

        if (!itemsToUpdate.isEmpty()) {
            TriggerRecursionGuard.setRunning('WasserijItem_Trigger');
            Database.SaveResult[] wiUpdateResults = Database.update(itemsToUpdate, false);
            // No increment of createdItems for updates; record any errors to aggregates
            for (Integer i = 0; i < wiUpdateResults.size(); i++) {
                if (!wiUpdateResults[i].isSuccess()) {
                    Database.Error[] errs = wiUpdateResults[i].getErrors();
                    // We don't have direct mapping to opp here; log a generic message
                    for (AggregatedResult agg : aggregates.values()) {
                        agg.success = false;
                        agg.messages.add('Wasserij item bijwerken mislukt: ' + collectErrors(errs));
                    }
                }
            }
            TriggerRecursionGuard.setNotRunning('WasserijItem_Trigger');
        }

        // If we had OLI but did not create or update any Wasserij items, surface a diagnostic hint
        Map<Id, Integer> oppToOliCount = new Map<Id, Integer>();
        for (OpportunityLineItem oli : opportunityLineItems) {
            Integer c = oppToOliCount.containsKey(oli.OpportunityId) ? oppToOliCount.get(oli.OpportunityId) : 0;
            oppToOliCount.put(oli.OpportunityId, c + 1);
        }
        Set<Id> oppsNeedingReprocess = new Set<Id>();
        for (AggregatedResult agg : aggregates.values()) {
            Integer oliCount = oppToOliCount.get(agg.opportunityId);
            if (agg.werkOrderId != null && oliCount != null && oliCount > 0 && agg.createdItems == 0 && itemsToUpdate.isEmpty()) {
                agg.messages.add('Geen Wasserij items aangemaakt of bijgewerkt ondanks ' + oliCount + ' opportunity producten. Controleer validatieregels/recordtypes.');
                oppsNeedingReprocess.add(agg.opportunityId);
            }
            // Also reprocess when no OLIs were found yet (timing), we'll run again after commit
            if (agg.werkOrderId != null && (oliCount == null || oliCount == 0)) {
                oppsNeedingReprocess.add(agg.opportunityId);
            }
        }

        // Asynchronous follow-up: if items could not be created (no OLIs yet or timing), enqueue a reprocess after commit
        if (!ASYNC_REPROCESS_CONTEXT && !oppsNeedingReprocess.isEmpty()) {
            System.enqueueJob(new OpportunityToWorkOrderReprocessor(oppsNeedingReprocess, 1));
            for (AggregatedResult agg : aggregates.values()) {
                if (oppsNeedingReprocess.contains(agg.opportunityId)) {
                    agg.messages.add('Wasserij items worden asynchroon aangemaakt na conversie.');
                }
            }
        }

        // Link extras to their primary Wasserij items once the records have IDs.
        if (!childToParentOli.isEmpty()) {
            List<Wasserij_Item__c> relationshipUpdates = new List<Wasserij_Item__c>();
            List<Id> relationshipChildOliOrder = new List<Id>();
            for (Id childOliId : childToParentOli.keySet()) {
                Id parentOliId = childToParentOli.get(childOliId);
                // Resolve child/parent items from either this run or existing records
                Wasserij_Item__c childItem = oliToItem.get(childOliId);
                if (childItem == null) childItem = existingByLineItemId.get((String)childOliId);
                Wasserij_Item__c parentItem = oliToItem.get(parentOliId);
                if (parentItem == null) parentItem = existingByLineItemId.get((String)parentOliId);
                Id oppId = oliToOpportunity.get(childOliId);
                AggregatedResult agg = (oppId != null) ? aggregates.get(oppId) : null;
                if (childItem == null || childItem.Id == null) {
                    if (agg != null) {
                        agg.success = false;
                        agg.messages.add('Gerelateerd Wasserij item kan niet gekoppeld worden voor opportunity line item ' + childOliId + '.');
                    }
                    continue;
                }
                if (parentItem == null || parentItem.Id == null) {
                    if (agg != null) {
                        agg.success = false;
                        agg.messages.add('Gerelateerd Wasserij item ontbreekt voor koppeling (opportunity line item ' + childOliId + ').');
                    }
                    continue;
                }
                // Only update relationship if not already set
                if (childItem.Gerelateerd_Wasserij_Item__c != parentItem.Id) {
                    Wasserij_Item__c relUpd = new Wasserij_Item__c(
                        Id = childItem.Id,
                        Gerelateerd_Wasserij_Item__c = parentItem.Id
                    );
                    // Mark as automation-driven to let flows skip heavy after-save paths
                    try { relUpd.Created_By_Flow__c = true; } catch (Exception ignore) {}
                    relationshipUpdates.add(relUpd);
                    relationshipChildOliOrder.add(childOliId);
                }
            }
            if (!relationshipUpdates.isEmpty()) {
                TriggerRecursionGuard.setRunning('WasserijItem_Trigger');
                Database.SaveResult[] relationshipResults = Database.update(relationshipUpdates, false);
                for (Integer i = 0; i < relationshipResults.size(); i++) {
                    Database.SaveResult sr = relationshipResults[i];
                    if (!sr.isSuccess()) {
                        Id childOliId = relationshipChildOliOrder[i];
                        Id oppId = oliToOpportunity.get(childOliId);
                        AggregatedResult agg = (oppId != null) ? aggregates.get(oppId) : null;
                        if (agg != null) {
                            agg.success = false;
                            agg.messages.add('Koppelen gerelateerd Wasserij item mislukt: ' + collectErrors(sr.getErrors()));
                        }
                    }
                }
                TriggerRecursionGuard.setNotRunning('WasserijItem_Trigger');
            }
        }

        // Final: Perform a single reprice per Werk Order to populate pricing fields, without triggering recursion
        if (!workOrderIds.isEmpty()) {
            for (Id woId : workOrderIds) {
                try {
                    List<SObject> priced = PricingService.repriceWerkorder(woId);
                    if (priced != null && !priced.isEmpty()) {
                        // Set guard flag on Wasserij items so flows can skip expensive paths
                        for (Integer i = 0; i < priced.size(); i++) {
                            SObject sobj = priced[i];
                            if (sobj != null && String.valueOf(sobj.getSObjectType()) == 'Wasserij_Item__c') {
                                try { sobj.put('Created_By_Flow__c', true); } catch (Exception ignore) {}
                            }
                        }
                        TriggerRecursionGuard.setRunning('WasserijItem_Trigger');
                        try {
                            update priced;
                        } finally {
                            TriggerRecursionGuard.setNotRunning('WasserijItem_Trigger');
                        }
                    }
                } catch (Exception e) {
                    // Attribute error to any aggregate sharing this work order
                    for (AggregatedResult agg : aggregates.values()) {
                        if (agg.werkOrderId == woId) {
                            agg.success = false;
                            agg.messages.add('Prijsberekening mislukt voor werkorder ' + woId + ': ' + e.getMessage());
                        }
                    }
                }
            }
        }

        // After all processing, disable bypass flag again on related Werk Orders
        if (!workOrderIds.isEmpty()) {
            List<Werk_Order__c> bypassOffList = new List<Werk_Order__c>();
            for (Id woId : workOrderIds) {
                Werk_Order__c woUpd = new Werk_Order__c(Id = woId);
                try { woUpd.Automation_Bypass__c = false; } catch (Exception ignore) {}
                bypassOffList.add(woUpd);
            }
            Database.SaveResult[] bypassOffResults = Database.update(bypassOffList, false);
            for (Integer i = 0; i < bypassOffResults.size(); i++) {
                if (!bypassOffResults[i].isSuccess()) {
                    Database.Error[] errs = bypassOffResults[i].getErrors();
                    for (AggregatedResult agg : aggregates.values()) {
                        if (workOrderIds.contains(agg.werkOrderId)) {
                            agg.success = false;
                            agg.messages.add('Werk order bypass uitschakelen mislukt: ' + collectErrors(errs));
                        }
                    }
                }
            }
        }

        // Finally: trigger confirmation only when Wasserij items are fully processed and no reprocess is pending
        // Confirmation is now scheduled asynchronously so after-save automation can run with complete data
        Set<Id> werkOrdersPendingConfirmation = new Set<Id>();
        for (AggregatedResult agg : aggregates.values()) {
            Boolean hasWasserijItems = (agg.createdItems != null && agg.createdItems > 0);
            if (!hasWasserijItems) {
                Integer updatedCount = oppToUpdatedItemCount.get(agg.opportunityId);
                hasWasserijItems = updatedCount != null && updatedCount > 0;
            }
            if (agg.success == true && agg.werkOrderId != null && agg.werkOrderRecordTypeId == werkOrderRecordTypeId && hasWasserijItems) {
                werkOrdersPendingConfirmation.add(agg.werkOrderId);
                agg.messages.add('Bevestigingen worden aangezet zodra het werkorder klaar is (asynchroon).');
            }
        }
        if (!werkOrdersPendingConfirmation.isEmpty()) {
            try {
                System.enqueueJob(new WerkOrderConfirmationJob(werkOrdersPendingConfirmation));
            } catch (Exception ex) {
                for (AggregatedResult agg : aggregates.values()) {
                    if (agg.werkOrderId != null && werkOrdersPendingConfirmation.contains(agg.werkOrderId)) {
                        agg.success = false;
                        agg.messages.add('Bevestigingen asynchroon plannen mislukt: ' + ex.getMessage());
                    }
                }
            }
        }

        for (Id oppId : opportunityIds) {
            AggregatedResult agg = aggregates.get(oppId);
            List<Integer> indexes = opportunityToIndexes.get(oppId);
            if (indexes == null) {
                continue;
            }

            for (Integer idx : indexes) {
                Response resp = responses[idx];
                resp.opportunityId = oppId;
                resp.werkOrderId = agg.werkOrderId;
                resp.createdItems = agg.createdItems;
                resp.success = agg.success;
                resp.message = agg.messages.isEmpty() ? 'Conversie geslaagd.' : String.join(agg.messages, ' | ');
            }
        }

        // Bulk photo propagation (non-fatal). Errors appended as messages.
        System.debug(LoggingLevel.WARN, '📸 OppToWOConverter: opportunityIdToWerkOrderIdForPhotos size=' + opportunityIdToWerkOrderIdForPhotos.size());
        System.debug(LoggingLevel.WARN, '📸 OppToWOConverter: oliIdToWasserijItemIdForPhotos size=' + oliIdToWasserijItemIdForPhotos.size());
        if (!opportunityIdToWerkOrderIdForPhotos.isEmpty()) {
            try {
                PhotoCopyService.copyOpportunityPhotosToWerkOrders(opportunityIdToWerkOrderIdForPhotos);
            } catch (Exception e) {
                for (Response r : responses) {
                    if (r != null && r.opportunityId != null && opportunityIdToWerkOrderIdForPhotos.containsKey(r.opportunityId)) {
                        r.message = (r.message == null ? '' : r.message + ' | ') + 'Opportunity foto kopie mislukt: ' + e.getMessage();
                    }
                }
            }
        }
        if (!oliIdToWasserijItemIdForPhotos.isEmpty()) {
            try {
                PhotoCopyService.copyOpportunityLineItemPhotos(oliIdToWasserijItemIdForPhotos);
            } catch (Exception e) {
                for (Response r : responses) {
                    if (r != null && r.werkOrderId != null) {
                        r.message = (r.message == null ? '' : r.message + ' | ') + 'Opportunity product foto kopie mislukt: ' + e.getMessage();
                    }
                }
            }
        }

        return responses;
    }

    // Helper for the async queueable to run conversion in a mode that won't re-enqueue itself
    public static void runInAsyncReprocessContext(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) return;
        List<Request> reqs = new List<Request>();
        for (Id oppId : opportunityIds) {
            Request r = new Request();
            r.opportunityId = oppId;
            reqs.add(r);
        }
        ASYNC_REPROCESS_CONTEXT = true;
        try {
            convert(reqs);
        } finally {
            ASYNC_REPROCESS_CONTEXT = false;
        }
    }

    private static Boolean hasAlternatePickupAddress(Opportunity opp) {
        if (opp == null) {
            return false;
        }
        String pickupStreet = normalizeStreet(opp.Ophaalstraat__c);
        String deliveryStreet = normalizeStreet(opp.Afleverstraat__c);
        if (pickupStreet == null || deliveryStreet == null) {
            return false;
        }
        return pickupStreet != deliveryStreet;
    }

    private static Boolean applyAlternatePickupAddress(Werk_Order__c workOrder, Opportunity opp) {
        if (workOrder == null || opp == null) {
            return false;
        }
        Boolean changed = false;
        changed = setBooleanField(workOrder, 'Ander_Ophaaladres__c', true) || changed;
        changed = setStringField(workOrder, 'Ophaaladres1__Street__s', opp.Ophaalstraat__c) || changed;
        changed = setStringField(workOrder, 'Ophaaladres1__PostalCode__s', opp.Ophaalpostcode__c) || changed;
        changed = setStringField(workOrder, 'Ophaaladres1__City__s', opp.Ophaalplaats__c) || changed;
        return changed;
    }

    private static Id resolveWorkOrderContactId(Account account) {
        if (account == null) {
            return null;
        }
        if (account.IsPersonAccount && account.PersonContactId != null) {
            return account.PersonContactId;
        }
        if (account.Standaard_Contact_Werk_Order__c != null) {
            return account.Standaard_Contact_Werk_Order__c;
        }
        return null;
    }

    private static String normalizeStreet(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed == '' ? null : trimmed.toLowerCase();
    }

    private static Boolean setStringField(SObject record, String fieldName, String newValue) {
        if (record == null || String.isBlank(fieldName)) {
            return false;
        }
        String normalized = normalizeBlankToNull(newValue);
        String currentValue = (String)record.get(fieldName);
        if ((currentValue == null && normalized == null) || (currentValue != null && currentValue.equals(normalized))) {
            return false;
        }
        record.put(fieldName, normalized);
        return true;
    }

    private static Boolean setBooleanField(SObject record, String fieldName, Boolean newValue) {
        if (record == null || String.isBlank(fieldName)) {
            return false;
        }
        Boolean currentValue = (Boolean)record.get(fieldName);
        if ((currentValue == null && newValue == null) || (currentValue != null && newValue != null && currentValue.equals(newValue))) {
            return false;
        }
        record.put(fieldName, newValue);
        return true;
    }

    private static String normalizeBlankToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed == '' ? null : trimmed;
    }

    private static Id determineProductId(OpportunityLineItem oli) {
        if (oli.PricebookEntry != null && oli.PricebookEntry.Product2Id != null) {
            return oli.PricebookEntry.Product2Id;
        }
        return oli.Product2Id;
    }

    private static String getOpportunityLineItemCategory(OpportunityLineItem oli) {
        if (oli == null) {
            return null;
        }
        String category;
        try {
            if (oli.PricebookEntry != null && oli.PricebookEntry.Product2 != null && String.isNotBlank(oli.PricebookEntry.Product2.Product_Category__c)) {
                category = oli.PricebookEntry.Product2.Product_Category__c;
            } else if (oli.Product2 != null && String.isNotBlank(oli.Product2.Product_Category__c)) {
                category = oli.Product2.Product_Category__c;
            } else {
                category = null;
            }
        } catch (Exception ignore) {
            category = null;
        }
        return category;
    }

    private static Boolean isPackageCategory(String category) {
        return equalsIgnoreCase(category, 'Package');
    }

    private static Boolean equalsIgnoreCase(String left, String right) {
        return left != null && right != null && left.equalsIgnoreCase(right);
    }

    private static Id getRecordTypeId(Schema.SObjectType sObjectType, String recordTypeName) {
        if (sObjectType == null || String.isBlank(recordTypeName)) {
            return null;
        }
        String sobjectName = sObjectType.getDescribe().getName();
        String cacheKey = sobjectName + ':' + recordTypeName.toLowerCase();
        if (!recordTypeIdCache.containsKey(cacheKey)) {
            List<RecordType> recordTypes = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = :sobjectName
                  AND (DeveloperName = :recordTypeName OR Name = :recordTypeName)
                LIMIT 1
            ];
            recordTypeIdCache.put(cacheKey, recordTypes.isEmpty() ? null : recordTypes[0].Id);
        }
        return recordTypeIdCache.get(cacheKey);
    }

    private static String collectErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) {
            return 'Onbekende fout';
        }
        List<String> parts = new List<String>();
        for (Database.Error err : errors) {
            parts.add(err.getMessage());
        }
        return String.join(parts, ' | ');
    }
}