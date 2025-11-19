// Test script voor Regiotoeslag functionaliteit
// Gebruik: Anonymous Apex in Developer Console

System.debug('=== REGIOTOESLAG TEST START ===');

try {
    // Stap 1: Zoek bestaande test data
    Product2 vloerkleedProduct = [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'VLRK%' LIMIT 1];
    System.debug('Found product: ' + vloerkleedProduct.ProductCode);
    
    Account testAccount = [SELECT Id FROM Account LIMIT 1];
    System.debug('Found account: ' + testAccount.Id);
    
    // Stap 2: Maak een nieuwe werk order
    Werk_Order__c testWerkOrder = new Werk_Order__c(
        Account__c = testAccount.Id,
        Name = 'Test Regiotoeslag Order'
    );
    insert testWerkOrder;
    System.debug('Created work order: ' + testWerkOrder.Id);
    
    // Stap 3: Setup postcode gebied (Amsterdam Centrum zoals in je test setup)
    Postcode_Range__c postcodeGebied;
    try {
        postcodeGebied = [SELECT Id FROM Postcode_Range__c WHERE Id = 'a2p9X000000dz49QAA' LIMIT 1];
        System.debug('Found existing postcode gebied: ' + postcodeGebied.Id);
    } catch (Exception e) {
        // Maak nieuwe postcode range als deze niet bestaat
        postcodeGebied = new Postcode_Range__c(
            Name = 'Amsterdam Centrum Test',
            Postcode_Begin__c = 1011,
            Postcode_Einde__c = 1019
        );
        insert postcodeGebied;
        System.debug('Created new postcode gebied: ' + postcodeGebied.Id);
    }
    
    // Stap 4: Update werk order met postcode en segment
    testWerkOrder.Postcodegebied__c = postcodeGebied.Id;
    testWerkOrder.Uniek_Segment__c = 'Wasserij';
    update testWerkOrder;
    System.debug('Updated work order with postcode and segment');
    
    // Stap 5: Verify regiotoeslag setup
    List<Dienstgebied_Postcode_Associatie__c> toeslagen = [
        SELECT Id, Postcode_Gebied__c, Segment__c, Toeslag__c, Regiotoeslag__c
        FROM Dienstgebied_Postcode_Associatie__c
        WHERE Postcode_Gebied__c = :postcodeGebied.Id
        AND Regiotoeslag__c = true
    ];
    
    if (toeslagen.isEmpty()) {
        System.debug('❌ No regional surcharge associations found! Creating test data...');
        
        // Maak test partner en dienst
        Account partner = new Account(Name = 'Test Partner Regiotoeslag');
        insert partner;
        
        Dienstgebied__c dienst = new Dienstgebied__c(
            Name = 'Test Wasserij Dienst',
            Segment__c = 'Wasserij'
        );
        insert dienst;
        
        // Maak regiotoeslag associatie
        Dienstgebied_Postcode_Associatie__c toeslag = new Dienstgebied_Postcode_Associatie__c(
            Partner__c = partner.Id,
            Postcode_Gebied__c = postcodeGebied.Id,
            Dienstgebied__c = dienst.Id,
            Regiotoeslag__c = true,
            Toeslag__c = 10
        );
        insert toeslag;
        System.debug('✅ Created test regional surcharge: 10%');
    } else {
        for (Dienstgebied_Postcode_Associatie__c toeslag : toeslagen) {
            System.debug('✅ Found surcharge: ' + toeslag.Segment__c + ' = ' + toeslag.Toeslag__c + '%');
        }
    }
    
    // Stap 6: Maak wasserij item om regiotoeslag te testen
    Wasserij_Item__c item = new Wasserij_Item__c(
        Werk_Order__c = testWerkOrder.Id,
        Product__c = vloerkleedProduct.Id,
        Lengte__c = 200,
        Breedte__c = 300  // 6m²
    );
    
    System.debug('--- CREATING WASSERIJ ITEM ---');
    insert item;
    System.debug('✅ Wasserij item created: ' + item.Id);
    
    // Stap 7: Verify results
    Wasserij_Item__c result = [
        SELECT Id, Aantal__c, Verkoopprijs__c, Totale_Prijs__c, Regiotoeslag__c,
               Product__r.ProductCode, Werk_Order__r.Postcodegebied__c, Werk_Order__r.Uniek_Segment__c
        FROM Wasserij_Item__c 
        WHERE Id = :item.Id
    ];
    
    System.debug('=== RESULTS ===');
    System.debug('Product: ' + result.Product__r.ProductCode);
    System.debug('Oppervlakte: ' + result.Aantal__c + ' m²');
    System.debug('Verkoopprijs: €' + result.Verkoopprijs__c + ' per m²');
    System.debug('Totale prijs: €' + result.Totale_Prijs__c);
    System.debug('Regiotoeslag: ' + result.Regiotoeslag__c + '%');
    System.debug('Work Order Postcode: ' + result.Werk_Order__r.Postcodegebied__c);
    System.debug('Work Order Segment: ' + result.Werk_Order__r.Uniek_Segment__c);
    
    // Validation
    if (result.Regiotoeslag__c != null && result.Regiotoeslag__c > 0) {
        System.debug('✅ SUCCESS: Regional surcharge applied: ' + result.Regiotoeslag__c + '%');
        
        // Calculate expected vs actual
        Decimal basePrice = 24.38; // Base price from pricing rules
        Decimal expectedPrice = basePrice * (1 + (result.Regiotoeslag__c / 100));
        System.debug('Expected price with surcharge: €' + expectedPrice);
        System.debug('Actual price: €' + result.Verkoopprijs__c);
        
        if (Math.abs(expectedPrice - result.Verkoopprijs__c) < 0.01) {
            System.debug('✅ PRICE CALCULATION CORRECT');
        } else {
            System.debug('❌ PRICE CALCULATION INCORRECT');
        }
    } else {
        System.debug('❌ WARNING: No regional surcharge applied');
        System.debug('Check if Dienstgebied_Postcode_Associatie__c exists for this postcode+segment combination');
    }
    
    // Clean up (optional)
    System.debug('--- CLEANUP ---');
    delete item;
    delete testWerkOrder;
    System.debug('✅ Cleanup completed');
    
} catch (Exception e) {
    System.debug('❌ ERROR: ' + e.getMessage());
    System.debug('Stack trace: ' + e.getStackTraceString());
}

System.debug('=== REGIOTOESLAG TEST END ===');