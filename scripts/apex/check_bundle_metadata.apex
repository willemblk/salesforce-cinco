// Check Bundle Discount Metadata Configuration

System.debug('=== BUNDLE DISCOUNT METADATA CHECK ===');

// Check all bundle discount rules
List<Bundle_Discount__mdt> allRules = [
    SELECT DeveloperName, MasterLabel, Min_Count__c, Discount_Percent__c, Segment__c, Active__c, Min_Aantal_Threshold__c
    FROM Bundle_Discount__mdt 
    ORDER BY Segment__c, Min_Count__c ASC
];

System.debug('Total Bundle Discount rules found: ' + allRules.size());

if (allRules.isEmpty()) {
    System.debug('❌ NO BUNDLE DISCOUNT RULES FOUND!');
    System.debug('You need to create Bundle_Discount__mdt custom metadata records.');
    System.debug('');
    System.debug('Example records needed:');
    System.debug('1. Wasserij 2 items: 5% discount (threshold: 2.95m²)');
    System.debug('2. Wasserij 3 items: 10% discount (threshold: 2.95m²)');
    return;
}

Map<String, List<Bundle_Discount__mdt>> rulesBySegment = new Map<String, List<Bundle_Discount__mdt>>();
for (Bundle_Discount__mdt rule : allRules) {
    if (!rulesBySegment.containsKey(rule.Segment__c)) {
        rulesBySegment.put(rule.Segment__c, new List<Bundle_Discount__mdt>());
    }
    rulesBySegment.get(rule.Segment__c).add(rule);
}

for (String segment : rulesBySegment.keySet()) {
    System.debug('\n--- SEGMENT: ' + segment + ' ---');
    List<Bundle_Discount__mdt> segmentRules = rulesBySegment.get(segment);
    
    for (Bundle_Discount__mdt rule : segmentRules) {
        String status = rule.Active__c ? '✅ ACTIVE' : '❌ INACTIVE';
        System.debug(status + ' | ' + rule.DeveloperName + ' (' + rule.MasterLabel + ')');
        System.debug('   Min Count: ' + rule.Min_Count__c + ' items');
        System.debug('   Discount: ' + (rule.Discount_Percent__c != null ? (rule.Discount_Percent__c * 100) + '%' : 'NULL'));
        System.debug('   Threshold: ' + (rule.Min_Aantal_Threshold__c != null ? rule.Min_Aantal_Threshold__c + 'm²' : 'NULL'));
    }
}

// Check specifically for Wasserij segment
List<Bundle_Discount__mdt> wasserijRules = [
    SELECT DeveloperName, Min_Count__c, Discount_Percent__c, Min_Aantal_Threshold__c
    FROM Bundle_Discount__mdt 
    WHERE Active__c = TRUE AND Segment__c = 'Wasserij'
    ORDER BY Min_Count__c ASC
];

System.debug('\n--- WASSERIJ RULES ANALYSIS ---');
if (wasserijRules.isEmpty()) {
    System.debug('❌ NO ACTIVE WASSERIJ RULES FOUND!');
    System.debug('The bundle discount deletion test will fail without these rules.');
} else {
    System.debug('✅ Found ' + wasserijRules.size() + ' active Wasserij rules:');
    for (Bundle_Discount__mdt rule : wasserijRules) {
        System.debug('- ' + rule.Min_Count__c + ' items → ' + (rule.Discount_Percent__c * 100) + '% discount (threshold: ' + rule.Min_Aantal_Threshold__c + 'm²)');
    }
    
    // Check for common scenarios
    Boolean has2ItemRule = false;
    Boolean has3ItemRule = false;
    
    for (Bundle_Discount__mdt rule : wasserijRules) {
        if (rule.Min_Count__c == 2) has2ItemRule = true;
        if (rule.Min_Count__c == 3) has3ItemRule = true;
    }
    
    System.debug('\n--- SCENARIO COVERAGE ---');
    System.debug('2-item scenario: ' + (has2ItemRule ? '✅ COVERED' : '❌ MISSING'));
    System.debug('3-item scenario: ' + (has3ItemRule ? '✅ COVERED' : '❌ MISSING'));
    
    if (!has2ItemRule || !has3ItemRule) {
        System.debug('⚠️  Missing rules may cause deletion test to fail');
    }
}

System.debug('\n=== METADATA CHECK COMPLETED ===');
