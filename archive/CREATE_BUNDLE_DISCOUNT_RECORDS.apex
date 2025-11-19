/**
 * Create Bundle Discount Custom Metadata Type Records
 * 
 * Uitvoeren in Salesforce Developer Console om test records aan te maken
 */

System.debug('=== CREATING BUNDLE DISCOUNT TEST RECORDS ===');
System.debug('');

// We can't create Custom Metadata Type records via Apex in runtime
// This script provides the setup instructions

System.debug('📋 MANUAL SETUP REQUIRED:');
System.debug('');
System.debug('Go to Setup > Custom Metadata Types > Bundle Discount > Manage Records');
System.debug('');
System.debug('Create the following records:');
System.debug('');

System.debug('🎁 RECORD 1: Wasserij 2 Items Discount');
System.debug('- Label: "Rug 2 Items – 5%"');
System.debug('- Bundle Discount Name: "Rug_2_Items_5"');
System.debug('- Min Count: 2');
System.debug('- Discount Percent: 0.0500');
System.debug('- Segment: "Wasserij"');
System.debug('- Active: true');
System.debug('- Min Aantal Threshold: 3.00');
System.debug('');

System.debug('🎁 RECORD 2: Wasserij 3 Items Discount');
System.debug('- Label: "Rug 3 Items – 10%"');
System.debug('- Bundle Discount Name: "Rug_3_Items_10"');
System.debug('- Min Count: 3');
System.debug('- Discount Percent: 0.1000');
System.debug('- Segment: "Wasserij"');
System.debug('- Active: true');
System.debug('- Min Aantal Threshold: 3.00');
System.debug('');

System.debug('🎁 RECORD 3: SR 2 Items Discount');
System.debug('- Label: "SR 2 Services – 7%"');
System.debug('- Bundle Discount Name: "SR_2_Services_7"');
System.debug('- Min Count: 2');
System.debug('- Discount Percent: 0.0700');
System.debug('- Segment: "SR"');
System.debug('- Active: true');
System.debug('- Min Aantal Threshold: null (empty)');
System.debug('');

System.debug('After creating these records, test the API with:');
System.debug('');
System.debug('🧪 Test API Call:');
System.debug('POST /services/apexrest/v1/calculatePrice/');
System.debug('{');
System.debug('  "postcode": "1012AB",');
System.debug('  "segment": "Wasserij",');
System.debug('  "siteId": "CincoCleaning",');
System.debug('  "products": []');
System.debug('}');
System.debug('');

System.debug('Expected Response should include:');
System.debug('{');
System.debug('  "success": true,');
System.debug('  "bundleDiscounts": [');
System.debug('    {');
System.debug('      "label": "Rug 2 Items – 5%",');
System.debug('      "bundleName": "Rug_2_Items_5",');
System.debug('      "minCount": 2,');
System.debug('      "discountPercent": 0.05,');
System.debug('      "segment": "Wasserij",');
System.debug('      "active": true,');
System.debug('      "minAantalThreshold": 3.0');
System.debug('    },');
System.debug('    {');
System.debug('      "label": "Rug 3 Items – 10%",');
System.debug('      "bundleName": "Rug_3_Items_10",');
System.debug('      "minCount": 3,');
System.debug('      "discountPercent": 0.10,');
System.debug('      "segment": "Wasserij",');
System.debug('      "active": true,');
System.debug('      "minAantalThreshold": 3.0');
System.debug('    }');
System.debug('  ]');
System.debug('}');
System.debug('');

System.debug('=== SETUP INSTRUCTIONS COMPLETE ===');