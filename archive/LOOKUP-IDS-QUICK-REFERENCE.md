# Quick Reference: API Lookup IDs

## 🎯 What Changed?

`PriceCalculationApi.cls` now returns **4 lookup IDs** for WordPress Lead creation:

| Field | Type | Purpose |
|-------|------|---------|
| `segment` | Text | → `Lead.Uniek_Segment__c` |
| `partnerId` | SF Id (18) | → `Lead.Partner__c` |
| `postcodeGebiedId` | SF Id (18) | → `Lead.Postcodegebied__c` |
| `dienstgebiedId` | SF Id (18) | → `Lead.Dienstgebied__c` (optional) |

---

## 📦 API Response Example

```json
{
  "segment": "Wasserij",
  "partnerId": "001xx000003DxpzAAC",
  "postcodeGebiedId": "a00xx000003GfTgAAK",
  "dienstgebiedId": "a01xx000003HkYsAAK",
  "partnerName": "Cinco Cleaning Partner Amsterdam",
  "postcodeGebiedName": "Amsterdam Centrum (1000-1099)"
}
```

---

## 🚀 Deploy & Test

```powershell
# Deploy
cd "c:\Users\wblok\Projecten\SalesforceProjecten\salesforce-pricing-engine\salesforce-pricing-engine"
sf project deploy start --source-dir force-app/main/default/classes/PriceCalculationApi.cls

# Test
sf apex run --file scripts/apex/test_api_lookup_ids.apex
```

---

## ✅ Expected Test Output

```
✅ TEST 1 PASSED: All lookup IDs returned correctly
   segment: Wasserij
   partnerId: 001xx... (18 chars)
   postcodeGebiedId: a00xx... (18 chars)

✅ TEST 2 PASSED: Lead created with lookup fields
✅ TEST 3 PASSED: Multiple segments work correctly
```

---

## 📋 Next Steps

1. ✅ **Salesforce**: Done! (`PriceCalculationApi.cls` updated)
2. ⏳ **WordPress Frontend**: Update `cinco-postcode-check-component.js`
3. ⏳ **WordPress Backend**: Update `class-cinco-lead-endpoint.php`
4. ⏳ **End-to-End Test**: Postcode → Config → Submit → Verify Lead

---

**Full Documentation**: `PRICECALCULATIONAPI-LOOKUP-IDS.md`
