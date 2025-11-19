Id oppId = Id.valueOf('0069X00000StoP3QAJ');
Opportunity o = [SELECT Id, Name, Amount, Partner__c, Partner__r.Name, Uniek_Segment__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
System.debug('🧾 Opp: ' + o.Id + ' ' + o.Name + ' | Amount=' + o.Amount + ' | Partner=' + o.Partner__r.Name + ' | Segment=' + o.Uniek_Segment__c);

Date today = Date.today();
List<Partner_Commission_Structure__c> pcs = [
    SELECT Id, Name, Partner__c, Partner__r.Name, Segment__c, Commission_Type__c, Commission_Value__c,
           Geldig_van__c, Geldig_tot__c, Lead_Type__c, SystemModstamp
    FROM Partner_Commission_Structure__c
    WHERE Partner__c = :o.Partner__c
      AND Segment__c = :o.Uniek_Segment__c
      AND (Geldig_van__c = null OR Geldig_van__c <= :today)
      AND (Geldig_tot__c = null OR Geldig_tot__c >= :today)
    ORDER BY Geldig_van__c DESC, SystemModstamp DESC
];

System.debug('🔎 Matching PCS records: ' + pcs.size());
for (Partner_Commission_Structure__c r : pcs) {
    System.debug(' - ' + r.Name + ' | Type=' + r.Commission_Type__c + ' | Value=' + r.Commission_Value__c + ' | Start=' + r.Geldig_van__c + ' | End=' + r.Geldig_tot__c + ' | LeadType=' + r.Lead_Type__c);
}

// Simulate current selection logic
Partner_Commission_Structure__c selected;
for (Partner_Commission_Structure__c r : pcs) {
    if (selected == null) { selected = r; continue; }
    Date curStart = selected.Geldig_van__c;
    Date newStart = r.Geldig_van__c;
    if (newStart != null && (curStart == null || newStart > curStart)) {
        selected = r;
    } else if (curStart == newStart && r.SystemModstamp > selected.SystemModstamp) {
        selected = r;
    }
}
System.debug('✅ Selected (current logic): ' + (selected != null ? selected.Name + ' | ' + selected.Commission_Type__c + ' ' + selected.Commission_Value__c : 'none'));

// Proposed precedence: prefer Fixed over Percentage when dates overlap or tie
Partner_Commission_Structure__c selectedPreferFixed;
for (Partner_Commission_Structure__c r : pcs) {
    if (selectedPreferFixed == null) { selectedPreferFixed = r; continue; }
    // If types differ, prefer Fixed
    if (selectedPreferFixed.Commission_Type__c != r.Commission_Type__c) {
        if (r.Commission_Type__c == 'Fixed') {
            selectedPreferFixed = r;
            continue;
        }
    }
    Date curStart = selectedPreferFixed.Geldig_van__c;
    Date newStart = r.Geldig_van__c;
    if (newStart != null && (curStart == null || newStart > curStart)) {
        selectedPreferFixed = r;
    } else if (curStart == newStart && r.SystemModstamp > selectedPreferFixed.SystemModstamp) {
        selectedPreferFixed = r;
    }
}
System.debug('✅ Selected (prefer Fixed): ' + (selectedPreferFixed != null ? selectedPreferFixed.Name + ' | ' + selectedPreferFixed.Commission_Type__c + ' ' + selectedPreferFixed.Commission_Value__c : 'none'));
