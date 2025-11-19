// Query Product2 to check field names for SR products
System.debug('🔍 Checking Product2 fields for SR segment...');

List<Product2> srProducts = [
    SELECT Id, Name, ProductCode, 
           Segment__c, Primaryproduct__c
    FROM Product2 
    WHERE Segment__c = 'SR' 
      AND IsActive = true
    LIMIT 3
];

System.debug('Found ' + srProducts.size() + ' SR products');

// Get all fields using describe
Schema.DescribeSObjectResult productDescribe = Product2.SObjectType.getDescribe();
Map<String, Schema.SObjectField> fieldMap = productDescribe.fields.getMap();

System.debug('─'.repeat(80));
System.debug('🔍 Searching for custom fields related to SR/Material/Photo/Furniture:');
System.debug('─'.repeat(80));

List<String> srRelatedFields = new List<String>();
for (String fieldName : fieldMap.keySet()) {
    String lowerFieldName = fieldName.toLowerCase();
    if (lowerFieldName.contains('material') || 
        lowerFieldName.contains('photo') || 
        lowerFieldName.contains('furniture') ||
        lowerFieldName.contains('sr') ||
        lowerFieldName.contains('image') ||
        lowerFieldName.contains('picture')) {
        
        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
        srRelatedFields.add(fieldName);
        System.debug('   ✓ ' + fieldDescribe.getLabel() + ' (' + fieldName + ') - Type: ' + fieldDescribe.getType());
    }
}

if (srRelatedFields.isEmpty()) {
    System.debug('   ❌ No SR-related custom fields found on Product2 object');
    System.debug('   💡 The fields Material_Type__c, Photo_Required__c, etc. need to be created in Salesforce');
} else {
    System.debug('─'.repeat(80));
    System.debug('Found ' + srRelatedFields.size() + ' potentially relevant fields');
}

System.debug('─'.repeat(80));
System.debug('Expected field names for SR segment:');
System.debug('   • Material_Type__c (Picklist: Stof, Leer, Beide)');
System.debug('   • Photo_Required__c (Checkbox)');
System.debug('   • Photo_Min_Count__c (Number)');
System.debug('   • Photo_Instructions__c (Long Text Area)');
System.debug('   • Furniture_Type__c (Picklist)');
