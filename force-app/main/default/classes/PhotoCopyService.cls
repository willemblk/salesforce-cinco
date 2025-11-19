public inherited sharing class PhotoCopyService {

    /**
     * Copy Lead-level photos to their converted Opportunities.
     * Map: Lead Id -> Opportunity Id
     */
    public static void copyLeadPhotosToOpportunities(Map<Id, Id> leadIdToOppId) {
        if (leadIdToOppId == null || leadIdToOppId.isEmpty()) {
            System.debug(LoggingLevel.WARN, '⚠️ Lead→Opp: SKIPPED - map is null or empty');
            return;
        }
        System.debug(LoggingLevel.WARN, '💰 Lead→Opp: START - map size=' + leadIdToOppId.size());
        System.debug(LoggingLevel.WARN, '💰 Lead→Opp: Lead IDs: ' + leadIdToOppId.keySet());
        System.debug(LoggingLevel.WARN, '💰 Lead→Opp: Opp IDs: ' + leadIdToOppId.values());
        
        List<Foto__c> src = [
            SELECT Id, Name, Lead__c, URL__c, Full_URL__c, Beschrijving__c, Categorie__c,
                   Bron__c, Sort_Order__c, Is_Public__c, Copied_Forward__c
            FROM Foto__c
            WHERE Lead__c IN :leadIdToOppId.keySet()
            AND (Copied_Forward__c = false OR Copied_Forward__c = NULL)
            ORDER BY Sort_Order__c ASC, CreatedDate ASC
        ];
        System.debug(LoggingLevel.WARN, '💰 Lead→Opp: QUERY returned ' + src.size() + ' photos');
        for (Foto__c f : src) {
            System.debug(LoggingLevel.DEBUG, '  Photo: ' + f.Id + ' | Lead: ' + f.Lead__c + ' | Copied_Forward__c: ' + f.Copied_Forward__c);
        }
        if (src.isEmpty()) {
            System.debug(LoggingLevel.WARN, '⚠️ Lead→Opp: NO PHOTOS FOUND - exiting early');
            return;
        }
        
        List<Foto__c> toInsert = new List<Foto__c>();
        List<Id> srcOrder = new List<Id>();
        for (Foto__c f : src) {
            Id oppId = leadIdToOppId.get(f.Lead__c);
            if (oppId == null) {
                System.debug(LoggingLevel.WARN, '⚠️ Lead→Opp: SKIPPED photo ' + f.Id + ' - no Opp mapping for Lead ' + f.Lead__c);
                continue;
            }
            Foto__c n = new Foto__c();
            n.Opportunity__c = oppId;
            n.Name         = String.isBlank(f.Name) ? 'Foto' : f.Name;
            n.URL__c        = f.URL__c;
            n.Full_URL__c   = f.Full_URL__c;
            n.Beschrijving__c = f.Beschrijving__c;
            n.Categorie__c  = f.Categorie__c;
            n.Bron__c       = String.isBlank(f.Bron__c) ? 'Overgenomen van lead' : f.Bron__c;
            n.Sort_Order__c = f.Sort_Order__c;
            n.Is_Public__c  = f.Is_Public__c;
            toInsert.add(n);
            srcOrder.add(f.Id);
            System.debug(LoggingLevel.DEBUG, '  Prepared new photo for Opp ' + oppId + ' from source ' + f.Id);
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.WARN, '⚠️ Lead→Opp: NO PHOTOS TO INSERT after mapping - exiting');
            return;
        }
        System.debug(LoggingLevel.WARN, '💰 Lead→Opp: INSERTING ' + toInsert.size() + ' new photos');

        Database.SaveResult[] results = Database.insert(toInsert, false);
        Set<Id> successSrcIds = new Set<Id>();
        List<String> errors = new List<String>();
        Integer successCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult r = results[i];
            if (r.isSuccess()) {
                if (i < srcOrder.size()) successSrcIds.add(srcOrder[i]);
                successCount++;
                System.debug(LoggingLevel.DEBUG, '  ✅ INSERT SUCCESS: new photo ' + r.getId() + ' from source ' + (i < srcOrder.size() ? srcOrder[i] : 'unknown'));
            } else {
                String errMsg = collectErrors(r.getErrors());
                errors.add(errMsg);
                System.debug(LoggingLevel.ERROR, '  ❌ INSERT FAILED for index ' + i + ': ' + errMsg);
                if (r.getErrors() != null) {
                    for (Database.Error err : r.getErrors()) {
                        System.debug(LoggingLevel.ERROR, '     StatusCode: ' + err.getStatusCode() + ' | Fields: ' + err.getFields());
                    }
                }
            }
        }
        System.debug(LoggingLevel.WARN, '💰 Lead→Opp: INSERT complete - ' + successCount + ' success, ' + errors.size() + ' failed');
        
        if (!successSrcIds.isEmpty()) {
            List<Foto__c> toMark = new List<Foto__c>();
            for (Foto__c f : src) {
                if (successSrcIds.contains(f.Id)) {
                    toMark.add(new Foto__c(Id = f.Id, Copied_Forward__c = true));
                }
            }
            if (!toMark.isEmpty()) {
                System.debug(LoggingLevel.WARN, '💰 Lead→Opp: MARKING ' + toMark.size() + ' source photos as Copied_Forward__c=true');
                Database.SaveResult[] markResults = Database.update(toMark, false);
                Integer markSuccess = 0;
                for (Database.SaveResult sr : markResults) {
                    if (sr.isSuccess()) {
                        markSuccess++;
                    } else {
                        System.debug(LoggingLevel.ERROR, '  ❌ MARK FAILED: ' + collectErrors(sr.getErrors()));
                    }
                }
                System.debug(LoggingLevel.WARN, '💰 Lead→Opp: MARKED ' + markSuccess + ' of ' + toMark.size() + ' successfully');
            }
        } else {
            System.debug(LoggingLevel.WARN, '⚠️ Lead→Opp: NO SUCCESS - nothing to mark');
        }
        if (!errors.isEmpty()) {
            String errorMsg = 'Lead→Opportunity foto kopie fouten: ' + String.join(errors, ' | ');
            System.debug(LoggingLevel.ERROR, '❌ ' + errorMsg);
            throw new AuraHandledException(errorMsg);
        }
        System.debug(LoggingLevel.WARN, '✅ Lead→Opp: COMPLETE - ' + successCount + ' photos copied and marked');
    }

    // Local helper to format Database.Error[] into a single message
    private static String collectErrors(Database.Error[] errors) {
        if (errors == null || errors.isEmpty()) return 'Onbekende fout';
        List<String> parts = new List<String>();
        for (Database.Error err : errors) {
            if (err == null) continue;
            String msg = err.getMessage();
            if (String.isBlank(msg)) msg = String.valueOf(err.getStatusCode());
            parts.add(msg);
        }
        return String.join(parts, ' | ');
    }

    /**
     * Copy Lead Product photos to Opportunity Line Items.
     * Map: Lead_Product__c Id -> OpportunityLineItem Id
     */
    public static void copyLeadProductPhotosToOpportunityLineItems(Map<Id, Id> leadProdIdToOliId) {
        if (leadProdIdToOliId == null || leadProdIdToOliId.isEmpty()) {
            System.debug(LoggingLevel.WARN, '⚠️ LeadProd→OLI: SKIPPED - map is null or empty');
            return;
        }
        System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: START - map size=' + leadProdIdToOliId.size());
        System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: LeadProduct IDs: ' + leadProdIdToOliId.keySet());
        System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: OLI IDs: ' + leadProdIdToOliId.values());
        
        List<Foto__c> src = [
            SELECT Id, Name, Lead_Product__c, URL__c, Full_URL__c, Beschrijving__c, Categorie__c,
                   Bron__c, Sort_Order__c, Is_Public__c, Copied_Forward__c
            FROM Foto__c
            WHERE Lead_Product__c IN :leadProdIdToOliId.keySet()
            AND (Copied_Forward__c = false OR Copied_Forward__c = NULL)
            ORDER BY Sort_Order__c ASC, CreatedDate ASC
        ];
        System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: QUERY returned ' + src.size() + ' photos');
        for (Foto__c f : src) {
            System.debug(LoggingLevel.DEBUG, '  Photo: ' + f.Id + ' | LeadProduct: ' + f.Lead_Product__c + ' | Copied_Forward__c: ' + f.Copied_Forward__c);
        }
        if (src.isEmpty()) {
            System.debug(LoggingLevel.WARN, '⚠️ LeadProd→OLI: NO PHOTOS FOUND - exiting early');
            return;
        }
        
        List<Foto__c> toInsert = new List<Foto__c>();
        List<Id> srcOrder = new List<Id>();
        for (Foto__c f : src) {
            Id oliId = leadProdIdToOliId.get(f.Lead_Product__c);
            if (oliId == null) {
                System.debug(LoggingLevel.WARN, '⚠️ LeadProd→OLI: SKIPPED photo ' + f.Id + ' - no OLI mapping for LeadProduct ' + f.Lead_Product__c);
                continue;
            }
            Foto__c n = new Foto__c();
            n.OpportunityLineItem__c = oliId;
            n.Name         = String.isBlank(f.Name) ? 'Foto' : f.Name;
            n.URL__c        = f.URL__c;
            n.Full_URL__c   = f.Full_URL__c;
            n.Beschrijving__c = f.Beschrijving__c;
            n.Categorie__c  = f.Categorie__c;
            n.Bron__c       = String.isBlank(f.Bron__c) ? 'Overgenomen van lead product' : f.Bron__c;
            n.Sort_Order__c = f.Sort_Order__c;
            n.Is_Public__c  = f.Is_Public__c;
            toInsert.add(n);
            srcOrder.add(f.Id);
            System.debug(LoggingLevel.DEBUG, '  Prepared new photo for OLI ' + oliId + ' from source ' + f.Id);
        }
        if (toInsert.isEmpty()) {
            System.debug(LoggingLevel.WARN, '⚠️ LeadProd→OLI: NO PHOTOS TO INSERT after mapping - exiting');
            return;
        }
        System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: INSERTING ' + toInsert.size() + ' new photos');

        Database.SaveResult[] results = Database.insert(toInsert, false);
        Set<Id> successSrcIds = new Set<Id>();
        List<String> errors = new List<String>();
        Integer successCount = 0;
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult r = results[i];
            if (r.isSuccess()) {
                if (i < srcOrder.size()) successSrcIds.add(srcOrder[i]);
                successCount++;
                System.debug(LoggingLevel.DEBUG, '  ✅ INSERT SUCCESS: new photo ' + r.getId() + ' from source ' + (i < srcOrder.size() ? srcOrder[i] : 'unknown'));
            } else {
                String errMsg = collectErrors(r.getErrors());
                errors.add(errMsg);
                System.debug(LoggingLevel.ERROR, '  ❌ INSERT FAILED for index ' + i + ': ' + errMsg);
                if (r.getErrors() != null) {
                    for (Database.Error err : r.getErrors()) {
                        System.debug(LoggingLevel.ERROR, '     StatusCode: ' + err.getStatusCode() + ' | Fields: ' + err.getFields());
                    }
                }
            }
        }
        System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: INSERT complete - ' + successCount + ' success, ' + errors.size() + ' failed');
        
        if (!successSrcIds.isEmpty()) {
            List<Foto__c> toMark = new List<Foto__c>();
            for (Foto__c f : src) {
                if (successSrcIds.contains(f.Id)) {
                    toMark.add(new Foto__c(Id = f.Id, Copied_Forward__c = true));
                }
            }
            if (!toMark.isEmpty()) {
                System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: MARKING ' + toMark.size() + ' source photos as Copied_Forward__c=true');
                Database.SaveResult[] markResults = Database.update(toMark, false);
                Integer markSuccess = 0;
                for (Database.SaveResult sr : markResults) {
                    if (sr.isSuccess()) {
                        markSuccess++;
                    } else {
                        System.debug(LoggingLevel.ERROR, '  ❌ MARK FAILED: ' + collectErrors(sr.getErrors()));
                    }
                }
                System.debug(LoggingLevel.WARN, '💰 LeadProd→OLI: MARKED ' + markSuccess + ' of ' + toMark.size() + ' successfully');
            }
        } else {
            System.debug(LoggingLevel.WARN, '⚠️ LeadProd→OLI: NO SUCCESS - nothing to mark');
        }
        if (!errors.isEmpty()) {
            String errorMsg = 'Lead product→OLI foto kopie fouten: ' + String.join(errors, ' | ');
            System.debug(LoggingLevel.ERROR, '❌ ' + errorMsg);
            throw new AuraHandledException(errorMsg);
        }
        System.debug(LoggingLevel.WARN, '✅ LeadProd→OLI: COMPLETE - ' + successCount + ' photos copied and marked');
    }

    /**
     * Copy Opportunity-level photos to Werk Orders.
     * Map: Opportunity Id -> Werk_Order1__c Id
     */
    public static void copyOpportunityPhotosToWerkOrders(Map<Id, Id> oppIdToWoId) {
        if (oppIdToWoId == null || oppIdToWoId.isEmpty()) return;
        System.debug(LoggingLevel.WARN, '💰 Opp→WerkOrder: map size=' + oppIdToWoId.size());
        List<Foto__c> src = [
            SELECT Id, Name, Opportunity__c, URL__c, Full_URL__c, Beschrijving__c, Categorie__c,
                   Bron__c, Sort_Order__c, Is_Public__c, Copied_Forward__c
            FROM Foto__c
            WHERE Opportunity__c IN :oppIdToWoId.keySet()
            AND (Copied_Forward__c = false OR Copied_Forward__c = NULL)
            ORDER BY Sort_Order__c ASC, CreatedDate ASC
        ];
        System.debug(LoggingLevel.WARN, '💰 Opp→WerkOrder: src size=' + src.size());
        if (src.isEmpty()) return;
        List<Foto__c> toInsert = new List<Foto__c>();
        List<Id> srcOrder = new List<Id>();
        for (Foto__c f : src) {
            Id woId = oppIdToWoId.get(f.Opportunity__c);
            if (woId == null) continue;
            Foto__c n = new Foto__c();
            n.Werk_Order1__c = woId;
            n.Name         = String.isBlank(f.Name) ? 'Foto' : f.Name;
            n.URL__c        = f.URL__c;
            n.Full_URL__c   = f.Full_URL__c;
            n.Beschrijving__c = f.Beschrijving__c;
            n.Categorie__c  = f.Categorie__c;
            n.Bron__c       = String.isBlank(f.Bron__c) ? 'Overgenomen van opportunity' : f.Bron__c;
            n.Sort_Order__c = f.Sort_Order__c;
            n.Is_Public__c  = f.Is_Public__c;
            toInsert.add(n);
            srcOrder.add(f.Id);
        }
        if (toInsert.isEmpty()) return;
        System.debug(LoggingLevel.WARN, '💰 Opp→WerkOrder: toInsert size=' + toInsert.size());

        Database.SaveResult[] results = Database.insert(toInsert, false);
        Set<Id> successSrcIds = new Set<Id>();
        List<String> errors = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult r = results[i];
            if (r.isSuccess()) {
                if (i < srcOrder.size()) successSrcIds.add(srcOrder[i]);
            } else {
                errors.add(collectErrors(r.getErrors()));
            }
        }
        if (!successSrcIds.isEmpty()) {
            List<Foto__c> toMark = new List<Foto__c>();
            for (Foto__c f : src) {
                if (successSrcIds.contains(f.Id)) {
                    toMark.add(new Foto__c(Id = f.Id, Copied_Forward__c = true));
                }
            }
            if (!toMark.isEmpty()) Database.update(toMark, false);
        }
        if (!errors.isEmpty()) {
            throw new AuraHandledException('Opportunity→Werkorder foto kopie fouten: ' + String.join(errors, ' | '));
        }
    }

    /**
     * Copy Opportunity Line Item photos to Wasserij Items (line-level).
     * Map: OpportunityLineItem Id -> Wasserij_Item__c Id
     */
    public static void copyOpportunityLineItemPhotos(Map<Id, Id> oliIdToWasserijItemId) {
        if (oliIdToWasserijItemId == null || oliIdToWasserijItemId.isEmpty()) return;
        System.debug(LoggingLevel.WARN, '💰 OLI→WasserijItem: map size=' + oliIdToWasserijItemId.size());
        List<Foto__c> src = [
            SELECT Id, Name, OpportunityLineItem__c, URL__c, Full_URL__c, Beschrijving__c, Categorie__c,
                   Bron__c, Sort_Order__c, Is_Public__c, Copied_Forward__c
            FROM Foto__c
            WHERE OpportunityLineItem__c IN :oliIdToWasserijItemId.keySet()
            AND (Copied_Forward__c = false OR Copied_Forward__c = NULL)
            ORDER BY Sort_Order__c ASC, CreatedDate ASC
        ];
        System.debug(LoggingLevel.WARN, '💰 OLI→WasserijItem: src size=' + src.size());
        if (src.isEmpty()) return;
        List<Foto__c> toInsert = new List<Foto__c>();
        List<Id> srcOrder = new List<Id>();
        for (Foto__c f : src) {
            Id wiId = oliIdToWasserijItemId.get(f.OpportunityLineItem__c);
            if (wiId == null) continue;
            Foto__c n = new Foto__c();
            n.Wasserij_item__c = wiId;
            n.Name         = String.isBlank(f.Name) ? 'Foto' : f.Name;
            n.URL__c        = f.URL__c;
            n.Full_URL__c   = f.Full_URL__c;
            n.Beschrijving__c = f.Beschrijving__c;
            n.Categorie__c  = f.Categorie__c;
            n.Bron__c       = String.isBlank(f.Bron__c) ? 'Overgenomen van opportunity product' : f.Bron__c;
            n.Sort_Order__c = f.Sort_Order__c;
            n.Is_Public__c  = f.Is_Public__c;
            toInsert.add(n);
            srcOrder.add(f.Id);
        }
        if (toInsert.isEmpty()) return;
        System.debug(LoggingLevel.WARN, '💰 OLI→WasserijItem: toInsert size=' + toInsert.size());

        Database.SaveResult[] results = Database.insert(toInsert, false);
        Set<Id> successSrcIds = new Set<Id>();
        List<String> errors = new List<String>();
        for (Integer i = 0; i < results.size(); i++) {
            Database.SaveResult r = results[i];
            if (r.isSuccess()) {
                if (i < srcOrder.size()) successSrcIds.add(srcOrder[i]);
            } else {
                errors.add(collectErrors(r.getErrors()));
            }
        }
        if (!successSrcIds.isEmpty()) {
            List<Foto__c> toMark = new List<Foto__c>();
            for (Foto__c f : src) {
                if (successSrcIds.contains(f.Id)) {
                    toMark.add(new Foto__c(Id = f.Id, Copied_Forward__c = true));
                }
            }
            if (!toMark.isEmpty()) Database.update(toMark, false);
        }
        if (!errors.isEmpty()) {
            throw new AuraHandledException('OLI→Wasserij item foto kopie fouten: ' + String.join(errors, ' | '));
        }
    }
}
