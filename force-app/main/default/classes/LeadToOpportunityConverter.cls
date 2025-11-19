global with sharing class LeadToOpportunityConverter {

    private static final String DEFAULT_STAGE = 'Qualification';
    private static final String OPPORTUNITY_LINE_TRIGGER_GUARD = 'OpportunityLineItem_Trigger';
    private static Id cachedStandardPricebookId;
    private static List<String> cachedConvertedLeadStatuses;

    // Cache Account field describe map to safely set fields that may not exist in all orgs
    private static Map<String, Schema.SObjectField> ACCOUNT_FIELD_MAP;
    private static Map<String, Schema.SObjectField> getAccountFieldMap() {
        if (ACCOUNT_FIELD_MAP == null) {
            ACCOUNT_FIELD_MAP = Account.SObjectType.getDescribe().fields.getMap();
        }
        return ACCOUNT_FIELD_MAP;
    }
    private static void safePutAccount(Account acc, String fieldApiName, Object value) {
        if (acc == null || value == null) return;
        if (value instanceof String && String.isBlank((String)value)) return;
        Map<String, Schema.SObjectField> fmap = getAccountFieldMap();
        if (fmap != null && fmap.containsKey(fieldApiName)) {
            acc.put(fieldApiName, value);
        }
    }

    global class Request {
        @InvocableVariable(required=true)
        public Id leadId;

        @InvocableVariable
        public Id pricebook2Id;

        @InvocableVariable
        public String oppStageName;

        @InvocableVariable
        public Id opportunityRecordTypeId;

    @InvocableVariable
    public String convertedStatus;
    }

    global class Response {
        public Response() {
            opportunityLineItemIds = new List<Id>();
        }

        @InvocableVariable
        public Id leadId;

        @InvocableVariable
        public Id opportunityId;

        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public List<Id> opportunityLineItemIds;
    }

    @InvocableMethod
    global static List<Response> convert(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        // Accumulate mappings for bulk photo copy after conversion finishes
        Map<Id, Id> leadIdToOpportunityIdForPhotos = new Map<Id, Id>();
        Map<Id, Id> leadProductIdToOliIdForPhotos = new Map<Id, Id>();

        Map<Id, List<Integer>> leadToIndexes = new Map<Id, List<Integer>>();
        Map<Id, Id> leadToRequestedPricebook = new Map<Id, Id>();
        Set<Id> leadIds = new Set<Id>();

        for (Integer idx = 0; idx < requests.size(); idx++) {
            Request req = requests[idx];
            Response resp = new Response();
            responses.add(resp);

            if (req == null || req.leadId == null) {
                resp.success = false;
                resp.message = 'LeadId is verplicht.';
                continue;
            }

            resp.leadId = req.leadId;
            leadIds.add(req.leadId);
            if (!leadToIndexes.containsKey(req.leadId)) {
                leadToIndexes.put(req.leadId, new List<Integer>());
                if (req.pricebook2Id != null) {
                    leadToRequestedPricebook.put(req.leadId, req.pricebook2Id);
                }
            }
            leadToIndexes.get(req.leadId).add(idx);
            if (!leadToRequestedPricebook.containsKey(req.leadId) && req.pricebook2Id != null) {
                leadToRequestedPricebook.put(req.leadId, req.pricebook2Id);
            }
        }

        if (leadIds.isEmpty()) {
            return responses;
        }

        Map<Id, Lead> leadMap = new Map<Id, Lead>([
         SELECT Id, IsConverted, ConvertedOpportunityId, ConvertedAccountId, ConvertedContactId,
             Company, FirstName, LastName, Name, Status, Email,
             Phone, MobilePhone, Fax, Website, Title, LeadSource,
             Street, City, State, PostalCode, Country,
             Ophaaladres_Toevoeging__c, Afleveradres_Toevoeging__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        // Preload matching Person Accounts by Lead email (case-insensitive) to attach conversion to existing accounts
        // Keyed by lowercase email for easy lookup
        Map<String, Account> personAccountByEmailLower = new Map<String, Account>();
        Set<String> leadEmails = new Set<String>();
        for (Lead l : leadMap.values()) {
            if (l != null && String.isNotBlank(l.Email)) {
                leadEmails.add(l.Email);
            }
        }
        if (!leadEmails.isEmpty()) {
            // Order by LastModifiedDate DESC so we pick the most recently updated account in case of duplicates
            for (Account pa : [
                SELECT Id, IsPersonAccount, PersonEmail, PersonContactId, LastModifiedDate
                FROM Account
                WHERE IsPersonAccount = true AND PersonEmail IN :leadEmails
                ORDER BY LastModifiedDate DESC
            ]) {
                String key = pa.PersonEmail != null ? pa.PersonEmail.toLowerCase() : null;
                if (key != null && !personAccountByEmailLower.containsKey(key)) {
                    personAccountByEmailLower.put(key, pa);
                }
            }
        }

        // Build bulk updates to sync new Lead info onto matched Person Accounts
        Map<Id, Account> accountUpdatesById = new Map<Id, Account>();
        Map<Id, List<Id>> accountIdToLeadIds = new Map<Id, List<Id>>();
        Map<Id, List<String>> preWarningsByLead = new Map<Id, List<String>>();
        for (Lead l : leadMap.values()) {
            if (l == null || String.isBlank(l.Email)) continue;
            Account match = personAccountByEmailLower.get(l.Email.toLowerCase());
            if (match == null) continue;

            Account upd = accountUpdatesById.get(match.Id);
            if (upd == null) {
                upd = new Account(Id = match.Id);
                accountUpdatesById.put(match.Id, upd);
            }

            // Only set when Lead has a value; avoid overwriting with nulls
            // Name: for Person Accounts, set FirstName/LastName so Account Name reflects the new person name
            safePutAccount(upd, 'FirstName', l.FirstName);
            safePutAccount(upd, 'LastName', l.LastName);
            safePutAccount(upd, 'PersonEmail', l.Email);
            safePutAccount(upd, 'Phone', l.Phone);
            safePutAccount(upd, 'PersonMobilePhone', l.MobilePhone);
            safePutAccount(upd, 'Fax', l.Fax);
            safePutAccount(upd, 'Website', l.Website);
            safePutAccount(upd, 'PersonTitle', l.Title);
            safePutAccount(upd, 'PersonLeadSource', l.LeadSource);

            safePutAccount(upd, 'PersonMailingStreet', l.Street);
            safePutAccount(upd, 'PersonMailingCity', l.City);
            safePutAccount(upd, 'PersonMailingState', l.State);
            safePutAccount(upd, 'PersonMailingPostalCode', l.PostalCode);
            safePutAccount(upd, 'PersonMailingCountry', l.Country);

            // Also update Billing Address on the Account to reflect the new address
            safePutAccount(upd, 'BillingStreet', l.Street);
            safePutAccount(upd, 'BillingCity', l.City);
            safePutAccount(upd, 'BillingState', l.State);
            safePutAccount(upd, 'BillingPostalCode', l.PostalCode);
            safePutAccount(upd, 'BillingCountry', l.Country);
            safePutAccount(upd, 'Ophaaladres_Toevoeging__c', l.Ophaaladres_Toevoeging__c);
            safePutAccount(upd, 'Afleveradres_Toevoeging__c', l.Afleveradres_Toevoeging__c);

            if (!accountIdToLeadIds.containsKey(match.Id)) {
                accountIdToLeadIds.put(match.Id, new List<Id>());
            }
            accountIdToLeadIds.get(match.Id).add(l.Id);
        }

        if (!accountUpdatesById.isEmpty()) {
            Database.SaveResult[] accUpdateResults = Database.update(accountUpdatesById.values(), false);
            for (Integer i = 0; i < accUpdateResults.size(); i++) {
                Database.SaveResult sr = accUpdateResults[i];
                Id accId = sr.getId();
                if (!sr.isSuccess()) {
                    String err = collectErrors(sr.getErrors());
                    List<Id> relatedLeads = accountIdToLeadIds.get(accId);
                    if (relatedLeads != null) {
                        for (Id lid : relatedLeads) {
                            if (!preWarningsByLead.containsKey(lid)) preWarningsByLead.put(lid, new List<String>());
                            preWarningsByLead.get(lid).add('Account bijwerken mislukt: ' + err);
                        }
                    }
                }
            }
        }

        Map<String, Schema.SObjectField> leadProductFields = Lead_Product__c.SObjectType.getDescribe().fields.getMap();
        Boolean hasUnitPriceField = leadProductFields.containsKey('Eenheidsprijs__c');
        Boolean hasSalesPriceField = leadProductFields.containsKey('Verkoopprijs__c');

    String leadProductQuery = 'SELECT Id, Lead__c, Product__c, Gerelateerd_Product__c, Aantal__c, Totale_Prijs__c, Bijzonderheden__c, Lengte_cm__c, Breedte_cm__c, Diameter_cm__c';
        if (hasUnitPriceField) {
            leadProductQuery += ', Eenheidsprijs__c';
        }
        if (hasSalesPriceField) {
            leadProductQuery += ', Verkoopprijs__c';
        }
        leadProductQuery += ' FROM Lead_Product__c WHERE Lead__c IN :leadIds ORDER BY CreatedDate ASC';
        List<Lead_Product__c> leadProducts = Database.query(leadProductQuery);
        Map<Id, List<Lead_Product__c>> leadToProducts = new Map<Id, List<Lead_Product__c>>();
        Set<Id> productIds = new Set<Id>();
        for (Lead_Product__c lp : leadProducts) {
            if (!leadToProducts.containsKey(lp.Lead__c)) {
                leadToProducts.put(lp.Lead__c, new List<Lead_Product__c>());
            }
            leadToProducts.get(lp.Lead__c).add(lp);
            if (lp.Product__c != null) {
                productIds.add(lp.Product__c);
            }
        }

        Id standardPricebookId;
        try {
            standardPricebookId = getStandardPricebookId();
        } catch (Exception ex) {
            for (List<Integer> indexes : leadToIndexes.values()) {
                propagateFailure(responses, indexes, null, 'Standaard prijsboek ontbreekt: ' + ex.getMessage());
            }
            return responses;
        }

        Map<Id, Id> leadToPricebookId = new Map<Id, Id>();
        Set<Id> pricebookIds = new Set<Id>();
        for (Id leadId : leadIds) {
            Id pbId = leadToRequestedPricebook.containsKey(leadId) ? leadToRequestedPricebook.get(leadId) : null;
            if (pbId == null) {
                pbId = standardPricebookId;
            }
            leadToPricebookId.put(leadId, pbId);
            if (pbId != null) {
                pricebookIds.add(pbId);
            }
        }

        Map<Id, Map<Id, PricebookEntry>> pricebookProductMap = new Map<Id, Map<Id, PricebookEntry>>();
        if (!pricebookIds.isEmpty() && !productIds.isEmpty()) {
            for (PricebookEntry entry : [
                SELECT Id, Pricebook2Id, Product2Id, UnitPrice, IsActive
                FROM PricebookEntry
                WHERE Pricebook2Id IN :pricebookIds
                  AND Product2Id IN :productIds
                  AND IsActive = true
            ]) {
                if (!pricebookProductMap.containsKey(entry.Pricebook2Id)) {
                    pricebookProductMap.put(entry.Pricebook2Id, new Map<Id, PricebookEntry>());
                }
                pricebookProductMap.get(entry.Pricebook2Id).put(entry.Product2Id, entry);
            }
        }

        for (Id leadId : leadIds) {
            List<Integer> indexes = leadToIndexes.get(leadId);
            Response headResponse = responses[indexes[0]];
            headResponse.leadId = leadId;

            Lead leadRecord = leadMap.get(leadId);
            if (leadRecord == null) {
                propagateFailure(responses, indexes, null, 'Lead niet gevonden.');
                continue;
            }

            Request primaryRequest = getRequestValue(requests, indexes[0]);
            List<String> warnings = new List<String>();
            // Include any pre-collected account update warnings for this lead
            if (preWarningsByLead.containsKey(leadId)) {
                warnings.addAll(preWarningsByLead.get(leadId));
            }
            Boolean overallSuccess = true;
            Id opportunityId;

            try {
                if (leadRecord.IsConverted && leadRecord.ConvertedOpportunityId != null) {
                    opportunityId = leadRecord.ConvertedOpportunityId;
                } else {
                    List<String> statusOptions = buildConvertedStatusOrderForLead(primaryRequest, leadRecord);
                    if (statusOptions.isEmpty()) {
                        overallSuccess = false;
                        warnings.add('Geen converted statuses beschikbaar om te gebruiken.');
                    } else {
                        Boolean converted = false;
                        for (String statusOption : statusOptions) {
                            Database.LeadConvert lc = new Database.LeadConvert();
                            lc.setLeadId(leadId);
                            lc.setConvertedStatus(statusOption);
                            lc.setDoNotCreateOpportunity(false);
                            lc.setSendNotificationEmail(false);
                            lc.setOpportunityName(resolveOpportunityName(leadRecord));

                            // If a Person Account exists with the same email as the Lead, convert into that account
                            if (String.isNotBlank(leadRecord.Email)) {
                                String emailKey = leadRecord.Email.toLowerCase();
                                Account match = personAccountByEmailLower.get(emailKey);
                                if (match != null) {
                                    lc.setAccountId(match.Id);
                                    // Attach to the existing person contact if available
                                    if (match.PersonContactId != null) {
                                        lc.setContactId(match.PersonContactId);
                                    }
                                }
                            }

                            Database.LeadConvertResult convertResult;
                            try {
                                convertResult = Database.convertLead(lc);
                            } catch (Exception ex) {
                                if (isInvalidConvertedStatusException(ex)) {
                                    // Ignore and try next allowed converted status without warning noise
                                    continue;
                                }
                                throw ex;
                            }

                            if (!convertResult.isSuccess()) {
                                overallSuccess = false;
                                warnings.add(collectErrors(convertResult.getErrors()));
                                break;
                            }

                            opportunityId = convertResult.getOpportunityId();
                            converted = true;
                            break;
                        }

                        if (!converted || opportunityId == null) {
                            overallSuccess = false;
                            if (opportunityId == null) {
                                warnings.add('Conversie gaf geen opportunity terug.');
                            }
                        }
                    }
                }
            } catch (Exception ex) {
                overallSuccess = false;
                warnings.add('Conversie mislukt: ' + ex.getMessage());
            }

            if (opportunityId == null) {
                propagateFailure(responses, indexes, null, String.join(warnings, ' | '));
                continue;
            }

            // Capture lead->opportunity mapping for later photo copy (avoid duplicate inserts if already converted)
            if (opportunityId != null && !leadIdToOpportunityIdForPhotos.containsKey(leadId)) {
                leadIdToOpportunityIdForPhotos.put(leadId, opportunityId);
            }

            Opportunity opportunityRecord = [
                SELECT Id, StageName, Pricebook2Id, RecordTypeId,
                       Ophaaladres_Toevoeging__c, Afleveradres_Toevoeging__c
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];

            String stageToApply = (primaryRequest != null && String.isNotBlank(primaryRequest.oppStageName))
                ? primaryRequest.oppStageName
                : DEFAULT_STAGE;
            Id desiredRecordType = (primaryRequest != null) ? primaryRequest.opportunityRecordTypeId : null;
            Id desiredPricebook = leadToPricebookId.get(leadId);

            Boolean opportunityChanged = false;
            if (String.isNotBlank(stageToApply) && stageToApply != opportunityRecord.StageName) {
                opportunityRecord.StageName = stageToApply;
                opportunityChanged = true;
            }
            if (desiredRecordType != null && desiredRecordType != opportunityRecord.RecordTypeId) {
                opportunityRecord.RecordTypeId = desiredRecordType;
                opportunityChanged = true;
            }
            if (desiredPricebook != null && desiredPricebook != opportunityRecord.Pricebook2Id) {
                opportunityRecord.Pricebook2Id = desiredPricebook;
                opportunityChanged = true;
            }
            if (opportunityRecord.Ophaaladres_Toevoeging__c != leadRecord.Ophaaladres_Toevoeging__c) {
                opportunityRecord.Ophaaladres_Toevoeging__c = leadRecord.Ophaaladres_Toevoeging__c;
                opportunityChanged = true;
            }
            if (opportunityRecord.Afleveradres_Toevoeging__c != leadRecord.Afleveradres_Toevoeging__c) {
                opportunityRecord.Afleveradres_Toevoeging__c = leadRecord.Afleveradres_Toevoeging__c;
                opportunityChanged = true;
            }
            if (opportunityChanged) {
                update opportunityRecord;
            }

            // Enable bypass on Opportunity to prevent heavy after-save flow paths during product insert/pricing
            Boolean oppBypassEnabled = false;
            try {
                SObject oppBypass = new Opportunity(Id = opportunityId);
                oppBypass.put('Automation_Bypass__c', true);
                Database.SaveResult[] oppByOn = Database.update(new List<SObject>{ oppBypass }, false);
                oppBypassEnabled = (!oppByOn.isEmpty() && oppByOn[0].isSuccess());
            } catch (Exception ignore) {
                // Field may not exist or update not allowed; proceed without bypass
            }

            // Idempotency: if this opportunity already has any line items, skip creating duplicates.
            Integer existingOliCount = [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :opportunityId];
            if (existingOliCount > 0) {
                // Reprice only if active pricing policies exist for any products on this opportunity.
                try {
                    Set<Id> existingProductIds = new Set<Id>();
                    for (AggregateResult ar : [
                        SELECT PricebookEntry.Product2Id pid, COUNT(Id) c
                        FROM OpportunityLineItem
                        WHERE OpportunityId = :opportunityId
                        GROUP BY PricebookEntry.Product2Id
                    ]) {
                        Id pid = (Id)ar.get('pid');
                        if (pid != null) existingProductIds.add(pid);
                    }
                    if (!existingProductIds.isEmpty() && hasActivePoliciesForProducts(existingProductIds)) {
                        List<SObject> pricedExisting = PricingService.repriceOpportunity(opportunityId);
                        if (pricedExisting != null && !pricedExisting.isEmpty()) {
                            TriggerRecursionGuard.setRunning(OPPORTUNITY_LINE_TRIGGER_GUARD);
                            try {
                                update pricedExisting;
                            } finally {
                                TriggerRecursionGuard.setNotRunning(OPPORTUNITY_LINE_TRIGGER_GUARD);
                            }
                        }
                    }
                } catch (Exception e) {
                    // Do not fail conversion for pricing errors; report as warning
                    warnings.add('Prijsberekening (bestaande regels) mislukte: ' + e.getMessage());
                }

                // Disable bypass again after repricing existing items
                if (oppBypassEnabled) {
                    try {
                        SObject oppBypassOff = new Opportunity(Id = opportunityId);
                        oppBypassOff.put('Automation_Bypass__c', false);
                        Database.update(new List<SObject>{ oppBypassOff }, false);
                    } catch (Exception ignore) {}
                }

                headResponse.opportunityId = opportunityId;
                headResponse.success = warnings.isEmpty();
                headResponse.message = warnings.isEmpty()
                    ? 'Opportunity heeft al producten; aanmaken overgeslagen.'
                    : 'Opportunity heeft al producten; aanmaken overgeslagen. ' + String.join(warnings, ' | ');
                propagateResult(responses, headResponse, indexes);
                continue; // Process next lead request
            }

            List<Lead_Product__c> productsForLead = leadToProducts.containsKey(leadId)
                ? leadToProducts.get(leadId)
                : new List<Lead_Product__c>();

            Map<Id, PricebookEntry> productToEntry = pricebookProductMap.containsKey(desiredPricebook)
                ? pricebookProductMap.get(desiredPricebook)
                : new Map<Id, PricebookEntry>();

            List<Lead_Product__c> primaryLeadProducts = new List<Lead_Product__c>();
            List<Lead_Product__c> extraLeadProducts = new List<Lead_Product__c>();
            for (Lead_Product__c lp : productsForLead) {
                if (lp.Gerelateerd_Product__c == null) {
                    primaryLeadProducts.add(lp);
                } else {
                    extraLeadProducts.add(lp);
                }
            }

            Map<Id, Id> leadProductToOliId = new Map<Id, Id>();
            List<OpportunityLineItem> primaryItems = new List<OpportunityLineItem>();
            List<Id> primaryLeadProductIds = new List<Id>();

            for (Lead_Product__c lp : primaryLeadProducts) {
                PricebookEntry entry = (lp.Product__c != null) ? productToEntry.get(lp.Product__c) : null;
                OpportunityLineItem oli = buildOpportunityLineItem(lp, entry, opportunityId, desiredPricebook, hasUnitPriceField, hasSalesPriceField, warnings);
                if (oli != null) {
                    primaryItems.add(oli);
                    primaryLeadProductIds.add(lp.Id);
                }
            }

            Database.SaveResult[] primaryResults = insertOpportunityLineItems(primaryItems);
            for (Integer i = 0; i < primaryResults.size(); i++) {
                Database.SaveResult sr = primaryResults[i];
                if (sr.isSuccess()) {
                    Id oliId = sr.getId();
                    headResponse.opportunityLineItemIds.add(oliId);
                    leadProductToOliId.put(primaryLeadProductIds[i], oliId);
                    // Map for photo copy
                    leadProductIdToOliIdForPhotos.put(primaryLeadProductIds[i], oliId);
                } else {
                    overallSuccess = false;
                    warnings.add(collectErrors(sr.getErrors()));
                }
            }

            List<OpportunityLineItem> extraItems = new List<OpportunityLineItem>();
            List<Id> extraLeadProductIds = new List<Id>();

            for (Lead_Product__c lp : extraLeadProducts) {
                Id parentLeadProductId = lp.Gerelateerd_Product__c;
                Id parentOliId = leadProductToOliId.get(parentLeadProductId);
                if (parentOliId == null) {
                    warnings.add('Geen primary opportunity product voor extra lead product ' + lp.Id + '.');
                    continue;
                }

                PricebookEntry entry = (lp.Product__c != null) ? productToEntry.get(lp.Product__c) : null;
                OpportunityLineItem oli = buildOpportunityLineItem(lp, entry, opportunityId, desiredPricebook, hasUnitPriceField, hasSalesPriceField, warnings);
                if (oli == null) {
                    continue;
                }

                oli.Gerelateerd_Product__c = parentOliId;
                extraItems.add(oli);
                extraLeadProductIds.add(lp.Id);
            }

            Database.SaveResult[] extraResults = insertOpportunityLineItems(extraItems);
            for (Integer i = 0; i < extraResults.size(); i++) {
                Database.SaveResult sr = extraResults[i];
                if (sr.isSuccess()) {
                    Id oliId = sr.getId();
                    headResponse.opportunityLineItemIds.add(oliId);
                    leadProductToOliId.put(extraLeadProductIds[i], oliId);
                    leadProductIdToOliIdForPhotos.put(extraLeadProductIds[i], oliId);
                } else {
                    overallSuccess = false;
                    warnings.add(collectErrors(sr.getErrors()));
                }
            }

            // Execute a single explicit reprice only if there are active pricing policies for the products we inserted.
            try {
                Set<Id> insertedProductIds = new Set<Id>();
                for (OpportunityLineItem oli : primaryItems) {
                    if (oli.PricebookEntryId != null) {
                        // Resolve Product2 via provided Pricebook mapping
                        PricebookEntry pbe = pricebookProductMap.get(desiredPricebook) != null ? pricebookProductMap.get(desiredPricebook).get(oli.PricebookEntry.Product2Id) : null;
                    }
                }
                // Simpler: collect from lead products we used
                for (Lead_Product__c lpUsed : primaryLeadProducts) { if (lpUsed.Product__c != null) insertedProductIds.add(lpUsed.Product__c); }
                for (Lead_Product__c lpUsed : extraLeadProducts) { if (lpUsed.Product__c != null) insertedProductIds.add(lpUsed.Product__c); }

                if (!insertedProductIds.isEmpty() && hasActivePoliciesForProducts(insertedProductIds)) {
                    List<SObject> priced = PricingService.repriceOpportunity(opportunityId);
                    if (priced != null && !priced.isEmpty()) {
                        TriggerRecursionGuard.setRunning(OPPORTUNITY_LINE_TRIGGER_GUARD);
                        try {
                            update priced;
                        } finally {
                            TriggerRecursionGuard.setNotRunning(OPPORTUNITY_LINE_TRIGGER_GUARD);
                        }
                    }
                }
            } catch (Exception e) {
                overallSuccess = false;
                warnings.add('Prijsberekening voor opportunity mislukt: ' + e.getMessage());
            }

            // Disable bypass again after inserts and repricing
            if (oppBypassEnabled) {
                try {
                    SObject oppBypassOff = new Opportunity(Id = opportunityId);
                    oppBypassOff.put('Automation_Bypass__c', false);
                    Database.update(new List<SObject>{ oppBypassOff }, false);
                } catch (Exception ignore) {}
            }

            if (headResponse.opportunityLineItemIds.isEmpty()) {
                warnings.add('Geen opportunity products om toe te voegen.');
            }

            headResponse.opportunityId = opportunityId;
            headResponse.success = overallSuccess;
            headResponse.message = warnings.isEmpty() ? 'Conversie geslaagd.' : String.join(warnings, ' | ');

            propagateResult(responses, headResponse, indexes);
        }

        // Bulk photo copy operations (do not block overall success; append warnings if failures)
        System.debug(LoggingLevel.WARN, '📸 LeadConverter: leadIdToOpportunityIdForPhotos size=' + leadIdToOpportunityIdForPhotos.size());
        System.debug(LoggingLevel.WARN, '📸 LeadConverter: leadProductIdToOliIdForPhotos size=' + leadProductIdToOliIdForPhotos.size());
        if (!leadIdToOpportunityIdForPhotos.isEmpty()) {
            try {
                PhotoCopyService.copyLeadPhotosToOpportunities(leadIdToOpportunityIdForPhotos);
            } catch (Exception e) {
                // Attach non-fatal warning to all responses for affected leads
                for (Response r : responses) {
                    if (r != null && r.leadId != null && leadIdToOpportunityIdForPhotos.containsKey(r.leadId)) {
                        r.message = (r.message == null ? '' : r.message + ' | ') + 'Lead foto kopie mislukt: ' + e.getMessage();
                    }
                }
            }
        }
        if (!leadProductIdToOliIdForPhotos.isEmpty()) {
            try {
                PhotoCopyService.copyLeadProductPhotosToOpportunityLineItems(leadProductIdToOliIdForPhotos);
            } catch (Exception e) {
                for (Response r : responses) {
                    if (r != null && r.opportunityLineItemIds != null && !r.opportunityLineItemIds.isEmpty()) {
                        r.message = (r.message == null ? '' : r.message + ' | ') + 'Lead product foto kopie mislukt: ' + e.getMessage();
                    }
                }
            }
        }

        return responses;
    }

    // Determine if any active pricing policies exist for given products (in-range and active)
    private static Boolean hasActivePoliciesForProducts(Set<Id> productIds) {
        if (productIds == null || productIds.isEmpty()) return false;
        Integer cnt = [
            SELECT COUNT()
            FROM Prijsmanagement__c
            WHERE Product__c IN :productIds
              AND Actief__c = true
              AND Geldig_vanaf__c <= TODAY
              AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
        ];
        return cnt > 0;
    }

    private static Request getRequestValue(List<Request> requests, Integer index) {
        return (index != null && index < requests.size()) ? requests[index] : null;
    }

    private static void propagateFailure(List<Response> responses, List<Integer> indexes, Id opportunityId, String message) {
        if (indexes == null || indexes.isEmpty()) {
            return;
        }
        Response head = responses[indexes[0]];
        head.opportunityId = opportunityId;
        head.success = false;
        head.message = message;
        propagateResult(responses, head, indexes);
    }

    private static void propagateResult(List<Response> responses, Response source, List<Integer> indexes) {
        if (indexes == null || indexes.isEmpty()) {
            return;
        }
        for (Integer idx : indexes) {
            Response target = responses[idx];
            target.leadId = source.leadId;
            target.opportunityId = source.opportunityId;
            target.success = source.success;
            target.message = source.message;
            target.opportunityLineItemIds = new List<Id>(source.opportunityLineItemIds);
        }
    }

    private static Database.SaveResult[] insertOpportunityLineItems(List<OpportunityLineItem> items) {
        if (items == null || items.isEmpty()) {
            return new List<Database.SaveResult>();
        }
        Boolean guardActive = false;
        try {
            TriggerRecursionGuard.setRunning(OPPORTUNITY_LINE_TRIGGER_GUARD);
            guardActive = true;
            return Database.insert(items, false);
        } finally {
            if (guardActive) {
                TriggerRecursionGuard.setNotRunning(OPPORTUNITY_LINE_TRIGGER_GUARD);
            }
        }
    }

    private static OpportunityLineItem buildOpportunityLineItem(
        Lead_Product__c leadProduct,
        PricebookEntry pricebookEntry,
        Id opportunityId,
        Id pricebookId,
        Boolean hasUnitPriceField,
        Boolean hasSalesPriceField,
        List<String> warnings
    ) {
        if (leadProduct.Product__c == null) {
            warnings.add('Lead product ' + leadProduct.Id + ' heeft geen gekoppeld product.');
            return null;
        }
        if (pricebookEntry == null) {
            warnings.add('Geen actieve pricebook entry voor product ' + leadProduct.Product__c + ' in prijsboek ' + pricebookId + '.');
            return null;
        }

        Decimal quantity = (leadProduct.Aantal__c != null && leadProduct.Aantal__c > 0) ? leadProduct.Aantal__c : 1;
        Decimal unitPrice;
        if (hasUnitPriceField) {
            unitPrice = (Decimal) leadProduct.get('Eenheidsprijs__c');
        }
        if ((unitPrice == null || unitPrice == 0) && hasSalesPriceField) {
            unitPrice = (Decimal) leadProduct.get('Verkoopprijs__c');
        }
        if ((unitPrice == null || unitPrice == 0) && leadProduct.Totale_Prijs__c != null && quantity != 0) {
            unitPrice = leadProduct.Totale_Prijs__c.divide(quantity, 6);
        }
        if (unitPrice == null || unitPrice == 0) {
            unitPrice = pricebookEntry.UnitPrice;
        }
        if (unitPrice == null || unitPrice == 0) {
            warnings.add('Geen geldige prijs voor lead product ' + leadProduct.Id + '.');
            return null;
        }

        String description = leadProduct.Bijzonderheden__c;
        if (leadProduct.Gerelateerd_Product__c != null) {
            description = String.isNotBlank(description) ? '[EXTRA] ' + description : '[EXTRA]';
        }

        OpportunityLineItem oli = new OpportunityLineItem();
        oli.OpportunityId = opportunityId;
        oli.PricebookEntryId = pricebookEntry.Id;
        oli.Quantity = quantity;
        oli.UnitPrice = unitPrice;
        if (String.isNotBlank(description)) {
            oli.Description = description;
        }
        if (leadProduct.Lengte_cm__c != null) {
            oli.Lengte_cm__c = leadProduct.Lengte_cm__c;
        }
        if (leadProduct.Breedte_cm__c != null) {
            oli.Breedte_cm__c = leadProduct.Breedte_cm__c;
        }
        if (leadProduct.Diameter_cm__c != null) {
            oli.Diameter_cm__c = leadProduct.Diameter_cm__c;
        }

        return oli;
    }

    private static String collectErrors(Database.Error[] errors) {
        List<String> parts = new List<String>();
        for (Database.Error err : errors) {
            parts.add(err.getMessage());
        }
        return String.join(parts, ' | ');
    }

    private static Id getStandardPricebookId() {
        if (cachedStandardPricebookId == null) {
            List<Pricebook2> books = [SELECT Id, IsActive FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (books.isEmpty()) {
                throw new AuraHandledException('Geen standaard prijsboek gevonden.');
            }
            Pricebook2 standardBook = books[0];
            if (!standardBook.IsActive) {
                standardBook.IsActive = true;
                update standardBook;
            }
            cachedStandardPricebookId = standardBook.Id;
        }
        return cachedStandardPricebookId;
    }

    private static List<String> getConvertedLeadStatuses() {
        if (cachedConvertedLeadStatuses == null) {
            List<LeadStatus> statuses = [SELECT ApiName FROM LeadStatus WHERE IsConverted = true ORDER BY SortOrder ASC];
            cachedConvertedLeadStatuses = new List<String>();
            for (LeadStatus status : statuses) {
                if (String.isNotBlank(status.ApiName)) {
                    cachedConvertedLeadStatuses.add(status.ApiName);
                }
            }
        }
        return cachedConvertedLeadStatuses;
    }

    private static List<String> buildConvertedStatusOrderForLead(Request request, Lead leadRecord) {
        // Build a list of allowed converted statuses, prioritizing:
        // 1) request.convertedStatus if it is a valid converted status
        // 2) the lead's current Status if it is a valid converted status
        // 3) remaining allowed converted statuses in org order
        List<String> allowed = getConvertedLeadStatuses();
        Set<String> allowedLc = new Set<String>();
        for (String s : allowed) if (String.isNotBlank(s)) allowedLc.add(s.toLowerCase());

        Set<String> seen = new Set<String>();
        List<String> ordered = new List<String>();

        if (request != null && String.isNotBlank(request.convertedStatus) && allowedLc.contains(request.convertedStatus.toLowerCase())) {
            ordered.add(request.convertedStatus);
            seen.add(request.convertedStatus.toLowerCase());
        }

        if (leadRecord != null && String.isNotBlank(leadRecord.Status) && allowedLc.contains(leadRecord.Status.toLowerCase()) && !seen.contains(leadRecord.Status.toLowerCase())) {
            ordered.add(leadRecord.Status);
            seen.add(leadRecord.Status.toLowerCase());
        }

        for (String s : allowed) {
            String key = s != null ? s.toLowerCase() : null;
            if (key != null && !seen.contains(key)) {
                ordered.add(s);
                seen.add(key);
            }
        }
        return ordered;
    }

    private static Boolean isInvalidConvertedStatusException(Exception ex) {
        if (ex instanceof DmlException) {
            DmlException dml = (DmlException) ex;
            for (Integer i = 0; i < dml.getNumDml(); i++) {
                if (String.valueOf(dml.getDmlStatusCode(i)) == 'INVALID_STATUS') {
                    return true;
                }
            }
        }
        return false;
    }

    private static String resolveOpportunityName(Lead leadRecord) {
        if (leadRecord == null) {
            return 'Nieuwe Opportunity';
        }
        if (!String.isBlank(leadRecord.Company)) {
            return leadRecord.Company;
        }
        String nameParts = String.join(new List<String>{leadRecord.FirstName, leadRecord.LastName}, ' ').trim();
        if (!String.isBlank(nameParts)) {
            return nameParts;
        }
        if (!String.isBlank(leadRecord.Name)) {
            return leadRecord.Name;
        }
        return 'Nieuwe Opportunity';
    }
}