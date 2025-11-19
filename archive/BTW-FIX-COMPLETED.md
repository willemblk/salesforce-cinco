# BTW Fix Complete ✅

**Date**: 2025-01-10  
**Issue**: BTW__c field showing 0% instead of 21%  
**Root Cause**: Incorrect Percent field conversion (0.21 instead of 21)  
**Status**: ✅ **FIXED & VERIFIED**

---

## Summary

Fixed Salesforce Percent field conversion error in `PricingService.cls`. The field `Lead_Product__c.BTW__c` is type **Percent**, which stores 21 for 21%, NOT 0.21.

### Before Fix
```apex
// WRONG: Converted "21" → 0.21 → displayed as 0%
lp.BTW__c = Decimal.valueOf(this.btw) / 100;
```

### After Fix
```apex
// CORRECT: Converts "21" → 21 → displays as 21%
lp.BTW__c = Decimal.valueOf(this.btw);
```

---

## Verification Results

### Test Lead: `00Q9X00003GfrTpUAJ`

Ran repricing script (`verify_btw_21_fix.apex`) on 4 Lead_Product__c records:

| Product Code | BTW__c | BTW_Bedrag__c | Totaal_incl_BTW__c | Status |
|--------------|--------|---------------|-------------------|---------|
| DAKKAP-PRIM-DAKKAPEL-REINIGEN | **21** | €39.74 | €228.99 | ✅ SUCCESS |
| DAKKAP-PRIM-DAKKAPEL-DAKGOOT | **21** | €4.20 | €24.20 | ✅ SUCCESS |
| DAKKAP-PRIM-DAKKAPEL-ROLLUIKBINNEN | **21** | €10.50 | €60.50 | ✅ SUCCESS |
| DAKKAP-PRIM-DAKKAPEL-ROLLUIKBUITEN | **21** | €3.15 | €18.15 | ✅ SUCCESS |

**Result**: 🎉 All BTW fields are correct!

---

## Changes Made

### 1. PricingService.cls - writeToLeadProduct()
**File**: `force-app/main/default/classes/PricingService.cls`  
**Lines**: ~132-145

```apex
// BTW__c (Percent field expects 21, not 0.21)
if (String.isNotBlank(this.btw)) {
    try {
        lp.BTW__c = Decimal.valueOf(this.btw); // ← FIXED: Removed / 100
    } catch (Exception e) {
        System.debug('⚠️ Error converting BTW: ' + e.getMessage());
        lp.BTW__c = 21; // ← FIXED: Changed from 0.21 to 21
    }
}
```

### 2. PricingService.cls - writeToWasserijItem()
**File**: `force-app/main/default/classes/PricingService.cls`  
**Lines**: ~175-188

```apex
// BTW__c (same fix for Wasserij_Item__c)
if (String.isNotBlank(this.btw)) {
    try {
        wi.BTW__c = Decimal.valueOf(this.btw); // ← FIXED: Removed / 100
    } catch (Exception e) {
        System.debug('⚠️ Error converting BTW: ' + e.getMessage());
        wi.BTW__c = 21; // ← FIXED: Changed from 0.21 to 21
    }
}
```

### 3. Deployment
```powershell
sf project deploy start --source-dir force-app/main/default/classes/PricingService.cls --target-org resolve
```

**Deploy ID**: `0Af9X000012t7SHSAY`  
**Status**: ✅ Succeeded  
**Elapsed Time**: 3.28s

---

## Technical Details

### Field Types
- **Product2.BTW__c**: Picklist (String) - Values: "21" or "9"
- **Lead_Product__c.BTW__c**: Percent (Decimal) - Stores 21 for 21%
- **BTW_Bedrag__c**: Formula (Currency) - Calculates: `Totaal__c × BTW__c / 100`
- **Totaal_incl_BTW__c**: Formula (Currency) - Calculates: `Totaal__c + BTW_Bedrag__c`

### Why 21 and not 0.21?
Salesforce Percent fields store the **actual percentage value**:
- Display: "21%"
- Storage: `21` (not `0.21`)
- Formula usage: `BTW__c / 100` (divide by 100 in formula)

This is different from other systems where percentages are stored as decimals (0.21 = 21%).

---

## Testing

### Verification Script
**File**: `scripts/apex/verify_btw_21_fix.apex`

```apex
// Loads Lead_Product__c records
// Calls PricingService.reprice()
// Updates database
// Verifies BTW__c = 21 (not 0.21 or 0)
// Verifies BTW_Bedrag__c formula calculation
```

### Test Results
- ✅ BTW__c correctly set to 21
- ✅ BTW_Bedrag__c calculated correctly (21% of Totaal__c)
- ✅ Totaal_incl_BTW__c includes VAT
- ✅ Formula fields update automatically
- ✅ No trigger recursion issues

---

## Next Steps for New Leads

### For Leads Created via WordPress
1. **WordPress sends**:
   - Lead data with `BTW_Toepasbaar__c = 'Ja'`
   - Lead_Product__c records with `Product__c` (lookup to Product2)

2. **Salesforce trigger fires**:
   - LeadProduct_Trigger (before insert/update)
   - Calls `PricingService.reprice()`

3. **PricingService loads**:
   - Product2.BTW__c (Picklist "21")
   - Converts to Decimal 21
   - Writes to Lead_Product__c.BTW__c

4. **Formula fields calculate**:
   - BTW_Bedrag__c = Totaal__c × (BTW__c / 100)
   - Totaal_incl_BTW__c = Totaal__c + BTW_Bedrag__c

5. **Result**:
   - BTW__c displays as "21%"
   - BTW_Bedrag__c shows VAT amount in euros
   - Totaal_incl_BTW__c shows total including VAT

### Testing New Leads
1. Create Lead via WordPress form (e.g., dakkapel cleaning)
2. Check Lead_Product__c records in Salesforce
3. Verify:
   - BTW__c = 21 (displays as 21%)
   - BTW_Bedrag__c = Totaal__c × 0.21
   - Totaal_incl_BTW__c = Totaal__c × 1.21

---

## Historical Data

### Existing Records with BTW__c = 0 or null
To fix historical records, run:

```apex
// Query records without BTW
List<Lead_Product__c> toFix = [
    SELECT Id
    FROM Lead_Product__c
    WHERE (BTW__c = null OR BTW__c = 0 OR BTW__c = 0.21)
      AND Lead__r.BTW_Toepasbaar__c = 'Ja'
];

// Reprice them
PricingService.reprice(toFix);
update toFix;
```

---

## Documentation

### Related Files
- **Implementation**: `BTW-IMPLEMENTATION-COMPLETE.md`
- **Summary**: `BTW-IMPLEMENTATION-SUMMARY.md`
- **Verification (Initial)**: `BTW-VERIFICATION-SUCCESS.md` (showed 0.21 issue)
- **Fix Complete**: `BTW-FIX-COMPLETED.md` (this file)

### Diagnostic Scripts
- `scripts/apex/diagnose_btw_issue.apex` (191 lines)
- `scripts/apex/verify_btw_fix.apex`
- `scripts/apex/diagnose_lead_00Q9X00003GfrTpUAJ.apex`
- `scripts/apex/verify_btw_21_fix.apex` ← **Final verification script**

---

## Key Learnings

### 1. Salesforce Percent Field Behavior
- Percent fields store the **numeric percentage** (21 = 21%)
- NOT the decimal equivalent (0.21)
- Formula fields must divide by 100: `BTW__c / 100`

### 2. Field Metadata vs Reality
- Field description: "Filled by flow" (misleading)
- Reality: Filled by PricingService.cls via trigger
- Always verify actual data source

### 3. Trigger Execution Context
- Trigger writes to in-memory records (before insert/update)
- No separate DML update needed
- Formula fields recalculate automatically after commit

### 4. Testing Approach
- Test on specific Lead ID first
- Verify formula field calculations
- Check trigger execution in debug logs
- Run repricing script to confirm fix

---

## Status

✅ **PRODUCTION READY**

- Fix deployed to Salesforce
- Verified on existing Lead records
- All formula fields calculate correctly
- Ready for new Lead creation via WordPress
- No manual intervention needed for new records

---

**Last Updated**: 2025-01-10  
**Verified By**: AI Agent + Apex Script  
**Deploy ID**: 0Af9X000012t7SHSAY
