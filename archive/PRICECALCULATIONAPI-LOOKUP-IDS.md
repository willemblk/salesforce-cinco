# PriceCalculationApi - Lookup IDs Implementation

**Date**: 2025-01-08  
**Version**: 1.5.0  
**Status**: ✅ Complete - Ready for Testing

---

## 🎯 Objective

Update `PriceCalculationApi.cls` to return **Salesforce Lookup IDs** from postcode check (Step 1), so WordPress can directly populate Lead fields during submission (Step 3).

### Fields Added to API Response
1. **`segment`** → `Lead.Uniek_Segment__c` (Text: "Wasserij", "SR", "Dakkapel")
2. **`partnerId`** → `Lead.Partner__c` (Account lookup - 18 chars)
3. **`postcodeGebiedId`** → `Lead.Postcodegebied__c` (Postcodegebied__c lookup - 18 chars)
4. **`dienstgebiedId`** → `Lead.Dienstgebied__c` (Optional - for reporting)

---

## ✅ Changes Made

### 1. PriceResponse Class Updated

**File**: `PriceCalculationApi.cls` (lines ~42-56)

```apex
// NEW: Lookup IDs for Lead population (WordPress → Salesforce)
@AuraEnabled public String segment;              // Uniek_Segment__c (Text: "Wasserij", "SR", "Dakkapel")
@AuraEnabled public String partnerId;            // Partner__c lookup (Account Id - 18 chars)
@AuraEnabled public String postcodeGebiedId;     // Postcodegebied__c lookup (Postcodegebied__c Id - 18 chars)
@AuraEnabled public String dienstgebiedId;       // Dienstgebied__c lookup (optional - for reporting)

// NEW: Display names for debugging/logging (optional)
@AuraEnabled public String partnerName;          // Partner__r.Name
@AuraEnabled public String postcodeGebiedName;   // Postcodegebied__r.Name
@AuraEnabled public String dienstgebiedName;     // Dienstgebied__r.Name
```

---

### 2. SOQL Query Enhanced

**File**: `PriceCalculationApi.cls` (lines ~265-284)

**Before**:
```apex
List<Dienstgebied_Postcode_Associatie__c> associaties = [
    SELECT Id, Afhandelingsmethode__c, Postcode_Gebied__r.Name, Segment__c, Toeslag__c
    FROM Dienstgebied_Postcode_Associatie__c 
    WHERE Postcode_Gebied__r.Postcode_Begin__c <= :postcodeNum 
      AND Postcode_Gebied__r.Postcode_Einde__c >= :postcodeNum
      AND Segment__c = :segment
    LIMIT 1
];
```

**After**:
```apex
List<Dienstgebied_Postcode_Associatie__c> associaties = [
    SELECT Id, 
           Afhandelingsmethode__c, 
           Segment__c,                                      // For Lead.Uniek_Segment__c
           Toeslag__c,                                      // For regioToeslag percentage
           Postcode_Gebied__c,                              // For Lead.Postcodegebied__c lookup
           Postcode_Gebied__r.Name,                         // Display name
           Postcode_Gebied__r.Postcode_Begin__c,            // For postcode range matching
           Postcode_Gebied__r.Postcode_Einde__c,            // For postcode range matching
           Dienstgebied__c,                                 // For Lead.Dienstgebied__c lookup (optional)
           Dienstgebied__r.Name,                            // Display name
           Dienstgebied__r.Partner__c,                      // For Lead.Partner__c lookup
           Dienstgebied__r.Partner__r.Name                  // Partner display name
    FROM Dienstgebied_Postcode_Associatie__c 
    WHERE Postcode_Gebied__r.Postcode_Begin__c <= :postcodeNum 
      AND Postcode_Gebied__r.Postcode_Einde__c >= :postcodeNum
      AND Segment__c = :segment
    LIMIT 1
];
```

**Performance**: No impact - all fields are on related records already queried.

---

### 3. Response Population Added

**File**: `PriceCalculationApi.cls` (lines ~195-210)

```apex
// ▼▼▼ NEW: POPULATE LOOKUP IDS FOR LEAD CREATION ▼▼▼
// These fields are sent back to WordPress and used to populate Lead fields
response.segment = associatie.Segment__c;                                  // For Lead.Uniek_Segment__c
response.partnerId = associatie.Dienstgebied__r.Partner__c;                // For Lead.Partner__c (Account lookup)
response.postcodeGebiedId = associatie.Postcode_Gebied__c;                 // For Lead.Postcodegebied__c lookup
response.dienstgebiedId = associatie.Dienstgebied__c;                      // For Lead.Dienstgebied__c lookup (optional)

// Display names for logging/debugging (optional)
response.partnerName = associatie.Dienstgebied__r.Partner__r.Name;
response.postcodeGebiedName = associatie.Postcode_Gebied__r.Name;
response.dienstgebiedName = associatie.Dienstgebied__r.Name;

System.debug('🔗 Lookup IDs populated:');
System.debug('   Segment: ' + response.segment);
System.debug('   Partner: ' + response.partnerName + ' (' + response.partnerId + ')');
System.debug('   Postcodegebied: ' + response.postcodeGebiedName + ' (' + response.postcodeGebiedId + ')');
System.debug('   Dienstgebied: ' + response.dienstgebiedName + ' (' + response.dienstgebiedId + ')');
// ▲▲▲ END LOOKUP POPULATION ▲▲▲
```

---

## 📊 API Response Example

### Request (Step 1: Postcode Check)
```json
POST /services/apexrest/v1/calculatePrice/
{
  "postcode": "1012AB",
  "segment": "Wasserij",
  "siteId": "CincoCleaning",
  "products": null
}
```

### Response (NEW Fields Added)
```json
{
  "success": true,
  "afhandelingsmethode": "Directe Prijs (Order)",
  "regioToeslagPercentage": 25,
  
  // NEW: Lookup IDs for Lead population
  "segment": "Wasserij",
  "partnerId": "001xx000003DxpzAAC",
  "postcodeGebiedId": "a00xx000003GfTgAAK",
  "dienstgebiedId": "a01xx000003HkYsAAK",
  
  // NEW: Display names (optional)
  "partnerName": "Cinco Cleaning Partner Amsterdam",
  "postcodeGebiedName": "Amsterdam Centrum (1000-1099)",
  "dienstgebiedName": "Dienstgebied Amsterdam",
  
  // Existing fields
  "availableProducts": [...],
  "bundleDiscounts": [...]
}
```

---

## 🔍 Testing

### Test Script Location
**File**: `scripts/apex/test_api_lookup_ids.apex`

### How to Run
1. Open Developer Console in Salesforce
2. Debug > Open Execute Anonymous Window
3. Paste script from `test_api_lookup_ids.apex`
4. Click "Execute"
5. Check debug logs for results

### Test Scenarios
1. **Test 1**: Postcode check returns catalog + lookup IDs
2. **Test 2**: Lead can be created with returned IDs
3. **Test 3**: Multiple segments return correct data

### Expected Results
```
✅ TEST 1 PASSED: All lookup IDs returned correctly
   segment: Wasserij
   partnerId: 001xx000003DxpzAAC (18 chars)
   postcodeGebiedId: a00xx000003GfTgAAK (18 chars)

✅ TEST 2 PASSED: Lead created successfully
   Lead Id: 00Qxx000001AbcdEAC
   Uniek_Segment__c: Wasserij
   Partner: Cinco Cleaning Partner Amsterdam
   Postcodegebied: Amsterdam Centrum (1000-1099)

✅ TEST 3: Segment match correct for all tested segments
```

---

## 🚀 Deployment Instructions

### Prerequisites
- [ ] Salesforce Org authenticated
- [ ] Deploy script ready (`sf project deploy start`)

### Deployment Steps

```powershell
# Navigate to Salesforce project
cd "c:\Users\wblok\Projecten\SalesforceProjecten\salesforce-pricing-engine\salesforce-pricing-engine"

# Deploy updated class
sf project deploy start --source-dir force-app/main/default/classes/PriceCalculationApi.cls

# Verify deployment
sf project deploy report

# Run test script
sf apex run --file scripts/apex/test_api_lookup_ids.apex
```

### Verification Queries

```apex
// Check recent API responses (via debug logs)
// Look for: "🔗 Lookup IDs populated:"

// Verify Dienstgebied_Postcode_Associatie__c has required data
List<Dienstgebied_Postcode_Associatie__c> associations = [
    SELECT Id, Segment__c, 
           Postcode_Gebied__c, Postcode_Gebied__r.Name,
           Dienstgebied__c, Dienstgebied__r.Name,
           Dienstgebied__r.Partner__c, Dienstgebied__r.Partner__r.Name
    FROM Dienstgebied_Postcode_Associatie__c
    WHERE Segment__c = 'Wasserij'
    LIMIT 5
];

for (Dienstgebied_Postcode_Associatie__c assoc : associations) {
    System.debug('Postcodegebied: ' + assoc.Postcode_Gebied__r.Name);
    System.debug('Partner: ' + assoc.Dienstgebied__r.Partner__r.Name);
}
```

---

## 📋 Next Steps (WordPress Integration)

### Step 2: Update WordPress Frontend
**File**: `cinco-postcode-check-component.js`

```javascript
// In redirectToMainForm() method
const metadata = {
    postcode: result.postcode,
    segment: result.segment,              // NEW: From API
    afhandeling: result.afhandelingsmethode || 'Order',
    regioToeslag: result.regioToeslagPercentage,
    
    // NEW: SF Lookup IDs
    partnerId: result.partnerId || null,
    postcodeGebiedId: result.postcodeGebiedId || null,
    dienstgebiedId: result.dienstgebiedId || null,
    
    // Optional: Display names for debugging
    partnerName: result.partnerName || null,
    postcodeGebiedName: result.postcodeGebiedName || null
};

window.CincoUtils.Storage.save('cincoMetadata', metadata);
```

### Step 3: Update WordPress Backend
**File**: `class-cinco-lead-endpoint.php`

```php
$metadata = $request->get_param('metadata');

$leadData = array(
    'FirstName' => $firstName,
    'LastName' => $lastName,
    'Email' => $email,
    'PostalCode' => $postcode,
    
    // NEW: Populate from metadata
    'Uniek_Segment__c' => sanitize_text_field($metadata['segment']),
    'Partner__c' => sanitize_text_field($metadata['partnerId']),
    'Postcodegebied__c' => sanitize_text_field($metadata['postcodeGebiedId'])
);

// Validate SF Ids are 18 characters
foreach (['Partner__c', 'Postcodegebied__c'] as $field) {
    if (!empty($leadData[$field]) && strlen($leadData[$field]) !== 18) {
        error_log("Invalid $field Id: " . $leadData[$field]);
        $leadData[$field] = null;
    }
}
```

---

## 🔍 Troubleshooting

### Issue: `partnerId` is null
**Cause**: `Dienstgebied__c` record has no `Partner__c` lookup  
**Fix**: Update Dienstgebied record to include Partner

```apex
// Find Dienstgebied without Partner
List<Dienstgebied__c> missing = [
    SELECT Id, Name
    FROM Dienstgebied__c
    WHERE Partner__c = null
];

// Update with correct Partner
for (Dienstgebied__c d : missing) {
    d.Partner__c = '001xx000003DxpzAAC'; // Replace with actual Partner Id
}
update missing;
```

### Issue: `postcodeGebiedId` is null
**Cause**: `Dienstgebied_Postcode_Associatie__c` has no `Postcode_Gebied__c` lookup  
**Fix**: Verify junction object data integrity

```apex
// Check associations without Postcodegebied
List<Dienstgebied_Postcode_Associatie__c> missing = [
    SELECT Id, Segment__c
    FROM Dienstgebied_Postcode_Associatie__c
    WHERE Postcode_Gebied__c = null
];

System.debug('Found ' + missing.size() + ' associations without Postcodegebied');
```

### Issue: SOQL query error
**Cause**: Field doesn't exist on object  
**Fix**: Verify custom fields exist:
- `Dienstgebied__c.Partner__c` (Lookup to Account)
- `Lead.Uniek_Segment__c` (Text 255)
- `Lead.Partner__c` (Lookup to Account)
- `Lead.Postcodegebied__c` (Lookup to Postcodegebied__c)

---

## 📚 Related Documentation

- **Implementation Overview**: `README.md` (Salesforce pricing engine)
- **WordPress Integration**: `FASE-4-FRONTEND-API-INTEGRATION-COMPLETE.md`
- **Loading Overlay**: `LOADING-OVERLAY-IMPLEMENTATION.md`
- **Copilot Instructions**: `.github/copilot-instructions.md`

---

## ✅ Success Criteria

- [ ] API response includes all 4 lookup IDs
- [ ] Lookup IDs are valid 18-character Salesforce IDs
- [ ] Test script passes all 3 tests
- [ ] WordPress can save IDs to SessionStorage
- [ ] Lead creation uses IDs correctly
- [ ] PricingService can use Lead lookups for regiotoeslag

---

**Status**: ✅ Salesforce Implementation Complete  
**Next**: WordPress Frontend & Backend Updates  
**Version**: 1.5.0  
**Last Updated**: 2025-01-08
