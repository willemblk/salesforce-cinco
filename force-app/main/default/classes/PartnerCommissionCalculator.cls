public with sharing class PartnerCommissionCalculator {

    public class Request {
        @InvocableVariable(required=true)
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable
        public Id opportunityId;

        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String message;

        @InvocableVariable
        public Decimal commissionAmount;
    }

    @InvocableMethod(label='Calculate Partner Commission' description='Calculates and writes Commission_Amount__c on Opportunities using Partner_Commission_Structure__c rules.')
    public static List<Result> calculate(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        // Collect Opportunity Ids
        Set<Id> oppIds = new Set<Id>();
        for (Request r : requests) {
            Result res = new Result();
            res.opportunityId = (r != null) ? r.opportunityId : null;
            results.add(res);
            if (r != null && r.opportunityId != null) {
                oppIds.add(r.opportunityId);
            } else {
                res.success = false;
                res.message = 'opportunityId is verplicht';
            }
        }
        if (oppIds.isEmpty()) {
            return results;
        }

        // Load Opportunities
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>([
            SELECT Id, Amount, Partner__c, Uniek_Segment__c, Referrer_Code__c
            FROM Opportunity WHERE Id IN :oppIds
        ]);

        // Gather Partner and Segment sets
        Set<Id> partnerIds = new Set<Id>();
        Set<String> segments = new Set<String>();
        for (Opportunity o : oppMap.values()) {
            if (o.Partner__c != null) partnerIds.add(o.Partner__c);
            if (String.isNotBlank(o.Uniek_Segment__c)) segments.add(o.Uniek_Segment__c);
        }

        // If nothing to match, update results and return
        if (partnerIds.isEmpty() || segments.isEmpty()) {
            // Clear commission on all opportunities in this call
            List<Opportunity> toUpdate = new List<Opportunity>();
            for (Result r : results) {
                Opportunity o = oppMap.get(r.opportunityId);
                if (o == null) continue;
                o.Commission_Amount__c = null;
                // Also clear revenue share fields when we cannot compute
                o.Referrer_Partner__c = null;
                o.Referrer_Share__c = null;
                o.Cinco_Share__c = null;
                toUpdate.add(o);
                r.success = true;
                r.commissionAmount = null;
                r.message = 'Geen partner/segment om te matchen; commissie gewist.';
            }
            if (!toUpdate.isEmpty()) update toUpdate;
            return results;
        }

        Date today = Date.today();

        // Load all potentially relevant commission structures in one bulk query
        List<Partner_Commission_Structure__c> structures = [
            SELECT Id, Partner__c, Segment__c, Commission_Type__c, Commission_Value__c,
                   Geldig_van__c, Geldig_tot__c, Lead_Type__c, SystemModstamp
            FROM Partner_Commission_Structure__c
            WHERE Partner__c IN :partnerIds
              AND Segment__c IN :segments
              AND (Geldig_van__c = null OR Geldig_van__c <= :today)
              AND (Geldig_tot__c = null OR Geldig_tot__c >= :today)
        ];

        // Prepare revenue share: gather referral codes and load active Partner_Referral_Code__c
        Set<String> referralCodes = new Set<String>();
        for (Opportunity o : oppMap.values()) {
            if (o.Referrer_Code__c != null && String.isNotBlank(o.Referrer_Code__c.trim())) {
                referralCodes.add(o.Referrer_Code__c.trim());
            }
        }
        Map<String, Partner_Referral_Code__c> referralByCodeLower = new Map<String, Partner_Referral_Code__c>();
        if (!referralCodes.isEmpty()) {
            for (Partner_Referral_Code__c prc : [
                SELECT Id, Code__c, Active__c, Partner__c
                FROM Partner_Referral_Code__c
                WHERE Active__c = true AND Code__c IN :referralCodes
            ]) {
                if (prc.Code__c != null) {
                    referralByCodeLower.put(prc.Code__c.trim().toLowerCase(), prc);
                }
            }
        }

        // Build best-match index: partner|segment -> best record (latest Geldig_van__c; tie-breaker SystemModstamp)
        Map<String, Partner_Commission_Structure__c> bestByKey = new Map<String, Partner_Commission_Structure__c>();
        for (Partner_Commission_Structure__c pcs : structures) {
            String key = String.valueOf(pcs.Partner__c) + '|' + pcs.Segment__c;
            if (!bestByKey.containsKey(key)) {
                bestByKey.put(key, pcs);
            } else {
                Partner_Commission_Structure__c cur = bestByKey.get(key);
                Date curStart = cur.Geldig_van__c;
                Date newStart = pcs.Geldig_van__c;
                if (newStart == null && curStart != null) {
                    // Keep current with a definite start date
                    continue;
                }
                if (newStart != null && (curStart == null || newStart > curStart)) {
                    bestByKey.put(key, pcs);
                } else if (curStart == newStart && pcs.SystemModstamp > cur.SystemModstamp) {
                    // Tie-breaker by last modified
                    bestByKey.put(key, pcs);
                }
            }
        }

        // Compute commissions and revenue share
        List<Opportunity> oppUpdates = new List<Opportunity>();
        for (Result r : results) {
            Opportunity o = oppMap.get(r.opportunityId);
            if (o == null) {
                r.success = false;
                r.message = 'Opportunity niet gevonden';
                continue;
            }
            Decimal amount = o.Amount;
            if (o.Partner__c == null || String.isBlank(o.Uniek_Segment__c) || amount == null) {
                o.Commission_Amount__c = null;
                // Revenue share is based on Commission_Amount__c; since commission cannot be computed, clear shares
                o.Referrer_Partner__c = null;
                o.Referrer_Share__c = null;
                o.Cinco_Share__c = null;
                oppUpdates.add(o);
                r.success = true;
                r.commissionAmount = null;
                r.message = 'Ontbrekende gegevens (Partner/Segment/Amount); commissie gewist.';
                continue;
            }

            String key = String.valueOf(o.Partner__c) + '|' + o.Uniek_Segment__c;
            Partner_Commission_Structure__c pcs = bestByKey.get(key);
            if (pcs == null || String.isBlank(pcs.Commission_Type__c) || pcs.Commission_Value__c == null) {
                o.Commission_Amount__c = null;
                // Revenue share must be based on commission; clear shares if no commission
                o.Referrer_Partner__c = null;
                o.Referrer_Share__c = null;
                o.Cinco_Share__c = null;
                oppUpdates.add(o);
                r.success = true;
                r.commissionAmount = null;
                r.message = 'Geen passende commissie-structuur gevonden; commissie gewist.';
                continue;
            }

            Decimal computed;
            String type = normalizeCommissionType(pcs.Commission_Type__c);
            if (type == 'percentage') {
                computed = (amount * (pcs.Commission_Value__c / 100)).setScale(2, System.RoundingMode.HALF_UP);
            } else if (type == 'fixed') {
                computed = pcs.Commission_Value__c.setScale(2, System.RoundingMode.HALF_UP);
            } else {
                // Unknown type; clear
                o.Commission_Amount__c = null;
                // Revenue share must be based on commission; clear shares if no commission
                o.Referrer_Partner__c = null;
                o.Referrer_Share__c = null;
                o.Cinco_Share__c = null;
                oppUpdates.add(o);
                r.success = true;
                r.commissionAmount = null;
                r.message = 'Onbekend Commissietype: ' + pcs.Commission_Type__c + '; commissie gewist.';
                continue;
            }

            o.Commission_Amount__c = computed;

            // Revenue share: compute when we have a valid, active referral code and a commission amount
            if (o.Referrer_Code__c != null && String.isNotBlank(o.Referrer_Code__c.trim()) && o.Commission_Amount__c != null) {
                Partner_Referral_Code__c prc = referralByCodeLower.get(o.Referrer_Code__c.trim().toLowerCase());
                if (prc != null && prc.Partner__c != null) {
                    Decimal shareBase = o.Commission_Amount__c;
                    Decimal refShare = (shareBase * 0.70).setScale(2, System.RoundingMode.HALF_UP);
                    Decimal cincoShare = (shareBase - refShare).setScale(2, System.RoundingMode.HALF_UP);
                    o.Referrer_Partner__c = prc.Partner__c;
                    o.Referrer_Share__c = refShare;
                    o.Cinco_Share__c = cincoShare;
                } else {
                    o.Referrer_Partner__c = null;
                    o.Referrer_Share__c = null;
                    o.Cinco_Share__c = null;
                }
            } else {
                o.Referrer_Partner__c = null;
                o.Referrer_Share__c = null;
                o.Cinco_Share__c = null;
            }
            oppUpdates.add(o);
            r.success = true;
            r.commissionAmount = computed;
            r.message = 'Commissie berekend.';
        }

        if (!oppUpdates.isEmpty()) {
            update oppUpdates;
        }

        return results;
    }

    // Map translated or human-friendly commission type labels to canonical keywords used by the calculator.
    private static String normalizeCommissionType(String rawType) {
        if (String.isBlank(rawType)) {
            return null;
        }

        String normalized = rawType.trim().toLowerCase();

        if (normalized.contains('perc')) {
            return 'percentage';
        }

        if (normalized.contains('vast') || normalized.contains('fixed') || normalized.contains('bedrag') || normalized.contains('amount')) {
            return 'fixed';
        }

        return null;
    }
}
