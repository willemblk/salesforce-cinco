// Test script om de extra producten in Salesforce te diagnosticeren
// Dit script controleert waarom de extras niet worden gelinkt aan primary products

System.debug('=== EXTRA PRODUCTS DIAGNOSIS TEST ===');

// Test 1: Check alle Wasserij producten en hun relaties
System.debug('');
System.debug('Test 1: Alle Wasserij producten in Salesforce...');

try {
    List<Product2> allWasserijProducts = [
        SELECT Id, Name, ProductCode, Primaryproduct__c, Gerelateerd_hoofdproduct__c,
               Segment__c, Beschikbare_Websites__c, IsActive
        FROM Product2 
        WHERE Segment__c = 'Wasserij' 
          AND IsActive = true
        ORDER BY Primaryproduct__c DESC, Name ASC
    ];
    
    System.debug('Found ' + allWasserijProducts.size() + ' total Wasserij products');
    
    List<Product2> primaries = new List<Product2>();
    List<Product2> extras = new List<Product2>();
    
    for (Product2 p : allWasserijProducts) {
        System.debug('Product: ' + p.ProductCode + ' | Primary: ' + p.Primaryproduct__c + 
                   ' | Related: ' + p.Gerelateerd_hoofdproduct__c + 
                   ' | Websites: ' + p.Beschikbare_Websites__c);
        
        if (p.Primaryproduct__c == true) {
            primaries.add(p);
        } else {
            extras.add(p);
        }
    }
    
    System.debug('');
    System.debug('Primary products: ' + primaries.size());
    for (Product2 p : primaries) {
        System.debug('  🎯 ' + p.ProductCode + ' - ' + p.Name + ' (ID: ' + p.Id + ')');
    }
    
    System.debug('');
    System.debug('Extra products: ' + extras.size());
    for (Product2 p : extras) {
        System.debug('  ⚙️ ' + p.ProductCode + ' - ' + p.Name + ' → ' + p.Gerelateerd_hoofdproduct__c);
    }
    
} catch (Exception e) {
    System.debug('❌ Test 1 FAILED: ' + e.getMessage());
}

// Test 2: Check filtering op CincoCleaning website
System.debug('');
System.debug('Test 2: Products gefilterd op CincoCleaning...');

try {
    String siteId = 'CincoCleaning';
    
    List<Product2> filteredProducts = [
        SELECT Id, Name, ProductCode, Primaryproduct__c, Gerelateerd_hoofdproduct__c,
               Segment__c, Beschikbare_Websites__c
        FROM Product2 
        WHERE Segment__c = 'Wasserij' 
          AND IsActive = true
          AND Beschikbare_Websites__c INCLUDES (:siteId)
        ORDER BY Primaryproduct__c DESC, Name ASC
    ];
    
    System.debug('Found ' + filteredProducts.size() + ' products for CincoCleaning');
    
    Map<Id, Product2> primaryMap = new Map<Id, Product2>();
    List<Product2> filteredExtras = new List<Product2>();
    
    for (Product2 p : filteredProducts) {
        if (p.Primaryproduct__c == true) {
            primaryMap.put(p.Id, p);
            System.debug('  🎯 PRIMARY: ' + p.ProductCode + ' - ' + p.Name + ' (ID: ' + p.Id + ')');
        } else {
            filteredExtras.add(p);
            System.debug('  ⚙️ EXTRA: ' + p.ProductCode + ' - ' + p.Name + ' → ' + p.Gerelateerd_hoofdproduct__c);
        }
    }
    
    System.debug('');
    System.debug('Linking analysis:');
    Integer successfulLinks = 0;
    for (Product2 extra : filteredExtras) {
        if (extra.Gerelateerd_hoofdproduct__c != null && primaryMap.containsKey(extra.Gerelateerd_hoofdproduct__c)) {
            Product2 linkedPrimary = primaryMap.get(extra.Gerelateerd_hoofdproduct__c);
            System.debug('  ✅ ' + extra.ProductCode + ' → ' + linkedPrimary.ProductCode + ' (WILL BE LINKED)');
            successfulLinks++;
        } else if (extra.Gerelateerd_hoofdproduct__c == null) {
            System.debug('  ❌ ' + extra.ProductCode + ' → NULL (NO PARENT DEFINED)');
        } else {
            System.debug('  ❌ ' + extra.ProductCode + ' → ' + extra.Gerelateerd_hoofdproduct__c + ' (PARENT NOT FOUND IN FILTERED RESULTS)');
        }
    }
    
    System.debug('');
    System.debug('Summary:');
    System.debug('- Primary products for CincoCleaning: ' + primaryMap.size());
    System.debug('- Extra products for CincoCleaning: ' + filteredExtras.size());
    System.debug('- Successful links: ' + successfulLinks);
    System.debug('- Expected total in response: ' + (primaryMap.size() + successfulLinks));
    
} catch (Exception e) {
    System.debug('❌ Test 2 FAILED: ' + e.getMessage());
}

// Test 3: Check Beschikbare_Websites__c field values
System.debug('');
System.debug('Test 3: Beschikbare_Websites__c field analysis...');

try {
    List<Product2> allProducts = [
        SELECT Id, Name, ProductCode, Beschikbare_Websites__c
        FROM Product2 
        WHERE Segment__c = 'Wasserij' 
          AND IsActive = true
    ];
    
    Set<String> allWebsiteValues = new Set<String>();
    Integer productsWithCinco = 0;
    Integer productsWithoutWebsites = 0;
    
    for (Product2 p : allProducts) {
        if (String.isBlank(p.Beschikbare_Websites__c)) {
            productsWithoutWebsites++;
            System.debug('  ⚠️ ' + p.ProductCode + ' has NO website values');
        } else {
            if (p.Beschikbare_Websites__c.contains('CincoCleaning')) {
                productsWithCinco++;
            }
            String[] websites = p.Beschikbare_Websites__c.split(';');
            for (String website : websites) {
                allWebsiteValues.add(website.trim());
            }
            System.debug('  ✅ ' + p.ProductCode + ' websites: ' + p.Beschikbare_Websites__c);
        }
    }
    
    System.debug('');
    System.debug('Website field summary:');
    System.debug('- Products with CincoCleaning: ' + productsWithCinco);
    System.debug('- Products without website values: ' + productsWithoutWebsites);
    System.debug('- All website values found: ' + String.join(new List<String>(allWebsiteValues), ', '));
    
} catch (Exception e) {
    System.debug('❌ Test 3 FAILED: ' + e.getMessage());
}

System.debug('');
System.debug('=== DIAGNOSIS COMPLETE ===');