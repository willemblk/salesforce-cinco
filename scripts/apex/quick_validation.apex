// Quick validation script - check if our PricingService changes are working
System.debug('=== QUICK VALIDATION ===');

// Check if we can find some existing Lead_Product__c records
List<Lead_Product__c> existing = [SELECT Id, Lead__c, Product__c, Verkoopprijs__c, Regiotoeslag__c FROM Lead_Product__c LIMIT 5];
System.debug('Found ' + existing.size() + ' existing Lead_Product__c records');

// Check if our methods exist and are accessible
try {
    List<Lead_Product__c> emptyList = new List<Lead_Product__c>();
    PricingService.calculateInitialPrices(emptyList);
    System.debug('✅ calculateInitialPrices method is accessible');
} catch (Exception e) {
    System.debug('❌ Error calling calculateInitialPrices: ' + e.getMessage());
}

try {
    List<Lead_Product__c> emptyList = new List<Lead_Product__c>();
    PricingService.recalculatePricesAfterDeletionLeadProducts(emptyList);
    System.debug('✅ recalculatePricesAfterDeletionLeadProducts method is accessible');
} catch (Exception e) {
    System.debug('❌ Error calling recalculatePricesAfterDeletionLeadProducts: ' + e.getMessage());
}

// Check if TriggerRecursionGuard is working
System.debug('TriggerRecursionGuard CrossItemUpdate running: ' + TriggerRecursionGuard.isRunning('CrossItemUpdate'));
System.debug('TriggerRecursionGuard DeletionRecalculation running: ' + TriggerRecursionGuard.isRunning('DeletionRecalculation'));

System.debug('=== VALIDATION COMPLETE ===');