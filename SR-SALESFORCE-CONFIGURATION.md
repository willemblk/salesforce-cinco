# SR (Spot Reinigen) - Salesforce Configuration Guide

**Last Updated**: October 7, 2025  
**API Version**: 64.0  
**Status**: ✅ Production Ready

---

## Table of Contents
1. [Overview](#overview)
2. [Data Model](#data-model)
3. [Product Configuration](#product-configuration)
4. [Price Management](#price-management)
5. [API Implementation](#api-implementation)
6. [Testing & Validation](#testing--validation)
7. [Maintenance](#maintenance)

---

## Overview

### What is SR in Salesforce?

SR (Spot Reinigen) is a service segment in the Cinco pricing engine where cleaning is performed on-site at the customer's location. This document describes the Salesforce configuration required to support SR products.

### Key Principles

1. **Product2 = Product Catalog**: All available SR products are stored as Product2 records
2. **Prijsmanagement__c = Active Pricing**: Current pricing per product with date validity
3. **Prijsstaffel__c = Tiered Pricing** (optional): Volume-based pricing tiers
4. **PriceCalculationApi.cls = REST API**: Exposes products and pricing to WordPress frontend

### SR Services Supported

1. **SR Meubel** - Furniture cleaning on-site
   - Bank (met/zonder kussens), Fauteuil, Hoekbank, Eetkamerstoel, Bureaustoel
   - Priced per zitplaats (seat)
   
2. **SR Tapijt** - Carpet cleaning on-site
   - Vast tapijt: Fixed carpets priced per m²
   - Tapijt trap: Stair carpets priced per trede (step)

---

## Data Model

### Object Relationships

```
Product2 (Standard)
    ↓ Lookup
Prijsmanagement__c (Custom)
    ↓ Master-Detail
Prijsstaffel__c (Custom) [Optional]

Lead (Standard)
    ↓ Lookup
Lead_Product__c (Custom)
    ↓ Lookup
Product2 (Standard)
```

### Field Requirements

#### Product2 (Standard Object)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ProductCode` | Text(255) | ✅ Yes | Unique identifier (e.g., `SR-PRIM-TAPIJT-PLAT`) |
| `Name` | Text(255) | ✅ Yes | Display name (e.g., "Vast tapijt") |
| `IsActive` | Checkbox | ✅ Yes | Must be true for API to return product |
| `Segment__c` | Text(50) | ✅ Yes | Must be 'SR' for SR products |
| `Site_Identifier__c` | Text(50) | ❌ No | Optional filter for multi-site (e.g., 'CincoCleaning') |
| `Description` | Long Text | ❌ No | Internal notes |

#### Prijsmanagement__c (Custom Object)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Product__c` | Lookup(Product2) | ✅ Yes | Which product this price applies to |
| `Eenheidsprijs__c` | Currency | ✅ Yes | Base price per unit (excl. BTW, excl. regiotoeslag) |
| `Price_Type__c` | Picklist | ✅ Yes | 'Normaal', 'Staffel Cumulatief', 'Staffel Trede' |
| `Actief__c` | Checkbox | ✅ Yes | Must be true for price to be used |
| `Geldig_vanaf__c` | Date | ✅ Yes | Start date (usually today) |
| `Geldig_tot__c` | Date | ❌ No | End date (null = no expiry) |
| `Minimaleprijs__c` | Currency | ❌ No | Minimum price (for discount calculations) |

#### Prijsstaffel__c (Custom Object) - OPTIONAL

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Prijsmanagement__c` | Master-Detail(Prijsmanagement__c) | ✅ Yes | Parent price record |
| `Ondergrens__c` | Number | ✅ Yes | Lower bound (e.g., 1) |
| `Bovengrens__c` | Number | ✅ Yes | Upper bound (e.g., 10) |
| `Eenheidsprijs__c` | Currency | ✅ Yes | Price per unit for this tier |

**Note**: SR products currently use flat pricing (no tiers). Staffel support is available but not actively used.

#### Lead_Product__c (Custom Object)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Lead__c` | Lookup(Lead) | ✅ Yes | Parent lead |
| `Product__c` | Lookup(Product2) | ✅ Yes | Which product was ordered |
| `Aantal__c` | Number(16,2) | ✅ Yes | **Quantity in product units** (seats, m², or treden) |
| `Verkoopprijs__c` | Currency | ✅ Yes | Unit price (incl. regiotoeslag, excl. BTW) |
| `Totale_Prijs__c` | Currency | ✅ Yes | Subtotal (Aantal × Verkoopprijs, excl. BTW) |
| `SKU__c` | Text(255) | ✅ Yes | ProductCode for reference |
| `Bijzonderheden__c` | Long Text | ❌ No | Customer notes |

**CRITICAL**: `Aantal__c` must be mapped correctly per product type:
- **SR Meubel**: Number of zitplaatsen (seats)
- **SR Tapijt PLAT**: Area in m²
- **SR Tapijt TRAP**: Number of treden (steps)

---

## Product Configuration

### SR Meubel Products

#### Create Products

```apex
// Execute in Developer Console or Anonymous Apex
List<Product2> products = new List<Product2>();

products.add(new Product2(
    ProductCode = 'SR-PRIM-MEUBEL-BANKMK',
    Name = 'Bank (met losse kussens)',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,  // Available for all sites
    Description = 'Meubel reinigen ter plekke - Bank met losse kussens'
));

products.add(new Product2(
    ProductCode = 'SR-PRIM-MEUBEL-BANKZK',
    Name = 'Bank (zonder losse kussens)',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,
    Description = 'Meubel reinigen ter plekke - Bank zonder losse kussens'
));

products.add(new Product2(
    ProductCode = 'SR-PRIM-MEUBEL-FAUTEUIL',
    Name = 'Fauteuil',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,
    Description = 'Meubel reinigen ter plekke - Fauteuil (1 zitplaats)'
));

products.add(new Product2(
    ProductCode = 'SR-PRIM-MEUBEL-HOEKBANK',
    Name = 'Hoekbank',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,
    Description = 'Meubel reinigen ter plekke - Hoekbank'
));

products.add(new Product2(
    ProductCode = 'SR-PRIM-MEUBEL-EETKAMERSTOEL',
    Name = 'Eetkamerstoel',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,
    Description = 'Meubel reinigen ter plekke - Eetkamerstoel'
));

products.add(new Product2(
    ProductCode = 'SR-PRIM-MEUBEL-BUREAUSTOEL',
    Name = 'Bureaustoel',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,
    Description = 'Meubel reinigen ter plekke - Bureaustoel'
));

insert products;

System.debug('✅ Created ' + products.size() + ' SR Meubel products');
```

#### Create Prices

```apex
// Create price records for SR Meubel products
// Prices are per zitplaats (seat)

Map<String, Id> productMap = new Map<String, Id>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'SR-PRIM-MEUBEL%']) {
    productMap.put(p.ProductCode, p.Id);
}

List<Prijsmanagement__c> prices = new List<Prijsmanagement__c>();

// Bank met losse kussens - €50 per seat
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-MEUBEL-BANKMK'),
    Eenheidsprijs__c = 50.00,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

// Bank zonder losse kussens - €45 per seat
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-MEUBEL-BANKZK'),
    Eenheidsprijs__c = 45.00,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

// Fauteuil - €27.50 per seat
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-MEUBEL-FAUTEUIL'),
    Eenheidsprijs__c = 27.50,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

// Hoekbank - €50 per seat
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-MEUBEL-HOEKBANK'),
    Eenheidsprijs__c = 50.00,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

// Eetkamerstoel - €22.50 per seat
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-MEUBEL-EETKAMERSTOEL'),
    Eenheidsprijs__c = 22.50,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

// Bureaustoel - €22.50 per seat
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-MEUBEL-BUREAUSTOEL'),
    Eenheidsprijs__c = 22.50,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

insert prices;

System.debug('✅ Created ' + prices.size() + ' SR Meubel price records');
```

### SR Tapijt Products

#### Create Products

```apex
// Execute in Developer Console or Anonymous Apex
List<Product2> products = new List<Product2>();

// Vast tapijt (per m²)
products.add(new Product2(
    ProductCode = 'SR-PRIM-TAPIJT-PLAT',
    Name = 'Vast tapijt',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,  // Available for all sites
    Description = 'Vast tapijt reinigen ter plekke - Prijs per m²'
));

// Tapijt trap (per trede)
products.add(new Product2(
    ProductCode = 'SR-PRIM-TAPIJT-TRAP',
    Name = 'Tapijt trap',
    IsActive = true,
    Segment__c = 'SR',
    Site_Identifier__c = null,
    Description = 'Tapijt trap reinigen ter plekke - Prijs per trede'
));

insert products;

System.debug('✅ Created ' + products.size() + ' SR Tapijt products');
```

#### Create Prices

```apex
// Create price records for SR Tapijt products

Map<String, Id> productMap = new Map<String, Id>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'SR-PRIM-TAPIJT%']) {
    productMap.put(p.ProductCode, p.Id);
}

List<Prijsmanagement__c> prices = new List<Prijsmanagement__c>();

// Vast tapijt - €5.00 per m²
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-TAPIJT-PLAT'),
    Eenheidsprijs__c = 5.00,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

// Tapijt trap - €7.50 per trede
prices.add(new Prijsmanagement__c(
    Product__c = productMap.get('SR-PRIM-TAPIJT-TRAP'),
    Eenheidsprijs__c = 7.50,
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
));

insert prices;

System.debug('✅ Created ' + prices.size() + ' SR Tapijt price records');
```

---

## Price Management

### Updating Prices

**Use Case**: Increase "Vast tapijt" price from €5.00 to €5.50

```apex
// 1. Find the current active price
Prijsmanagement__c currentPrice = [
    SELECT Id, Eenheidsprijs__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode = 'SR-PRIM-TAPIJT-PLAT'
      AND Actief__c = true
    LIMIT 1
];

// 2. Deactivate current price or set end date
currentPrice.Actief__c = false;
// OR
currentPrice.Geldig_tot__c = Date.today().addDays(-1);
update currentPrice;

// 3. Create new price record
Prijsmanagement__c newPrice = new Prijsmanagement__c(
    Product__c = currentPrice.Product__c,
    Eenheidsprijs__c = 5.50,  // New price
    Price_Type__c = 'Normaal',
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),
    Geldig_tot__c = null
);
insert newPrice;

System.debug('✅ Price updated: €5.00 → €5.50');
```

### Price History

```apex
// Query price history for a product
List<Prijsmanagement__c> history = [
    SELECT Eenheidsprijs__c, Geldig_vanaf__c, Geldig_tot__c, Actief__c
    FROM Prijsmanagement__c
    WHERE Product__r.ProductCode = 'SR-PRIM-TAPIJT-PLAT'
    ORDER BY Geldig_vanaf__c DESC
];

for (Prijsmanagement__c p : history) {
    System.debug('€' + p.Eenheidsprijs__c + ' | ' + 
                 p.Geldig_vanaf__c + ' → ' + 
                 (p.Geldig_tot__c != null ? p.Geldig_tot__c : 'Present') +
                 ' | Active: ' + p.Actief__c);
}
```

### Bulk Price Updates

```apex
// Increase all SR Meubel prices by 10%
List<Prijsmanagement__c> prices = [
    SELECT Id, Eenheidsprijs__c, Product__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
      AND Product__r.ProductCode LIKE 'SR-PRIM-MEUBEL%'
      AND Actief__c = true
];

List<Prijsmanagement__c> newPrices = new List<Prijsmanagement__c>();
List<Prijsmanagement__c> oldPrices = new List<Prijsmanagement__c>();

for (Prijsmanagement__c p : prices) {
    // Deactivate old price
    p.Actief__c = false;
    oldPrices.add(p);
    
    // Create new price (+10%)
    Prijsmanagement__c newPrice = new Prijsmanagement__c(
        Product__c = p.Product__c,
        Eenheidsprijs__c = p.Eenheidsprijs__c * 1.10,
        Price_Type__c = 'Normaal',
        Actief__c = true,
        Geldig_vanaf__c = Date.today(),
        Geldig_tot__c = null
    );
    newPrices.add(newPrice);
}

update oldPrices;
insert newPrices;

System.debug('✅ Updated ' + newPrices.size() + ' SR Meubel prices (+10%)');
```

---

## API Implementation

### PriceCalculationApi.cls

**Location**: `force-app/main/default/classes/PriceCalculationApi.cls`

**Endpoint**: `/services/apexrest/v1/calculatePrice`

**Method**: POST

### API Request Structure

#### Step 1: Get Product Catalog

```json
POST /services/apexrest/v1/calculatePrice
Content-Type: application/json

{
  "postcode": "1012AB",
  "segment": "SR",
  "siteId": "CincoCleaning"
}
```

**Note**: No `products` array = catalog request

### API Response Structure

```json
{
  "success": true,
  "availableProducts": [
    {
      "productCode": "SR-PRIM-MEUBEL-BANKMK",
      "productName": "Bank (met losse kussens)",
      "isPrimary": true,
      "basePrice": 50.00,
      "bundelkortingToepasbaar": false,
      "staffelPricing": [],
      "pricePerUnit": "/zitplaats",
      "extraPrices": {}
    },
    {
      "productCode": "SR-PRIM-TAPIJT-PLAT",
      "productName": "Vast tapijt",
      "isPrimary": true,
      "basePrice": 5.00,
      "bundelkortingToepasbaar": false,
      "staffelPricing": [],
      "pricePerUnit": "/m²",
      "extraPrices": {}
    },
    {
      "productCode": "SR-PRIM-TAPIJT-TRAP",
      "productName": "Tapijt trap",
      "isPrimary": true,
      "basePrice": 7.50,
      "bundelkortingToepasbaar": false,
      "staffelPricing": [],
      "pricePerUnit": "/trede",
      "extraPrices": {}
    }
  ],
  "bundleDiscounts": [],
  "regioToeslagPercentage": 50,
  "afhandelingsmethode": "Directe Prijs (Order)"
}
```

### Key API Logic

#### Product Query

```apex
// In buildProductCatalog() method
List<Product2> products = [
    SELECT Id, ProductCode, Name, Segment__c, 
           Bundelkorting_toepasbaar__c, Site_Identifier__c
    FROM Product2
    WHERE IsActive = true
      AND Segment__c = :segment  // 'SR'
      AND (Site_Identifier__c = :siteId OR Site_Identifier__c = null)
    ORDER BY ProductCode
];
```

**Filtering Logic**:
1. `IsActive = true` - Only active products
2. `Segment__c = 'SR'` - Only SR products
3. `Site_Identifier__c` - If siteId provided, filter by site OR null (available for all)

#### Price Query

```apex
// Get product IDs
Set<Id> productIds = new Set<Id>();
for (Product2 p : products) {
    productIds.add(p.Id);
}

// Query active prices
Map<Id, Prijsmanagement__c> priceMap = new Map<Id, Prijsmanagement__c>();
for (Prijsmanagement__c pm : [
    SELECT Product__c, Product__r.ProductCode, 
           Eenheidsprijs__c, Price_Type__c
    FROM Prijsmanagement__c
    WHERE Product__c IN :productIds
      AND Actief__c = true
      AND Geldig_vanaf__c <= TODAY
      AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
]) {
    priceMap.put(pm.Product__c, pm);
}
```

**Filtering Logic**:
1. `Actief__c = true` - Must be active
2. `Geldig_vanaf__c <= TODAY` - Valid from date has passed
3. `Geldig_tot__c >= TODAY OR null` - Not expired

#### Staffel Query (Optional)

```apex
// If Price_Type__c = 'Staffel Cumulatief' or 'Staffel Trede'
Map<String, List<Prijsstaffel__c>> staffelMap = new Map<String, List<Prijsstaffel__c>>();

for (Prijsstaffel__c ps : [
    SELECT Prijsmanagement__r.Product__r.ProductCode,
           Ondergrens__c, Bovengrens__c, Eenheidsprijs__c
    FROM Prijsstaffel__c
    WHERE Prijsmanagement__c IN :priceIds
    ORDER BY Ondergrens__c ASC
]) {
    String productCode = ps.Prijsmanagement__r.Product__r.ProductCode;
    if (!staffelMap.containsKey(productCode)) {
        staffelMap.put(productCode, new List<Prijsstaffel__c>());
    }
    staffelMap.get(productCode).add(ps);
}
```

**Note**: SR products currently don't use staffel, but API supports it.

### Testing API with cURL

```powershell
# Get OAuth token first
$token = "YOUR_SALESFORCE_ACCESS_TOKEN"

# Call API
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

$body = @{
    postcode = "1012AB"
    segment = "SR"
    siteId = "CincoCleaning"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "https://your-instance.salesforce.com/services/apexrest/v1/calculatePrice" -Method POST -Headers $headers -Body $body

# Check response
$response.availableProducts | Format-Table productCode, productName, basePrice
```

---

## Testing & Validation

### 1. Product Configuration Check

**Script**: `scripts/apex/check_sr_products.apex`

```apex
// Check all SR products are configured correctly
List<Product2> products = [
    SELECT Id, ProductCode, Name, IsActive, Segment__c
    FROM Product2
    WHERE Segment__c = 'SR'
    ORDER BY ProductCode
];

System.debug('📦 Found ' + products.size() + ' SR products:');
for (Product2 p : products) {
    System.debug('  - ' + p.ProductCode + ': ' + p.Name + ' (Active: ' + p.IsActive + ')');
}

// Expected: 7 products (6 meubel + 2 tapijt = 8 total)
```

### 2. Price Configuration Check

**Script**: `scripts/apex/check_sr_pricing.apex`

```apex
// Check all SR products have active prices
List<Prijsmanagement__c> prices = [
    SELECT Product__r.ProductCode, Eenheidsprijs__c, Price_Type__c, 
           Actief__c, Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
      AND Actief__c = true
    ORDER BY Product__r.ProductCode
];

System.debug('💰 Found ' + prices.size() + ' active SR price records:');
for (Prijsmanagement__c p : prices) {
    System.debug('  - ' + p.Product__r.ProductCode + ': €' + p.Eenheidsprijs__c + 
                 ' (' + p.Price_Type__c + ')');
}

// Check for products without prices
Set<Id> productsWithPrices = new Set<Id>();
for (Prijsmanagement__c p : prices) {
    productsWithPrices.add(p.Product__c);
}

List<Product2> productsWithoutPrices = [
    SELECT ProductCode, Name
    FROM Product2
    WHERE Segment__c = 'SR'
      AND IsActive = true
      AND Id NOT IN :productsWithPrices
];

if (productsWithoutPrices.isEmpty()) {
    System.debug('✅ All active SR products have prices');
} else {
    System.debug('❌ ' + productsWithoutPrices.size() + ' products without prices:');
    for (Product2 p : productsWithoutPrices) {
        System.debug('  - ' + p.ProductCode + ': ' + p.Name);
    }
}
```

### 3. API Response Validation

**Script**: `scripts/apex/test_sr_api.apex`

```apex
// Test API response for SR segment
RestRequest req = new RestRequest();
RestResponse res = new RestResponse();

req.requestBody = Blob.valueOf('{"postcode":"1012AB","segment":"SR","siteId":"CincoCleaning"}');

RestContext.request = req;
RestContext.response = res;

// Call API
PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice();

// Validate response
System.debug('✅ API Response:');
System.debug('  - Success: ' + response.success);
System.debug('  - Products: ' + response.availableProducts.size());
System.debug('  - RegioToeslag: ' + response.regioToeslagPercentage + '%');

// Check each product has basePrice
for (PriceCalculationApi.ProductInfo p : response.availableProducts) {
    System.debug('  - ' + p.productCode + ': €' + p.basePrice);
    
    if (p.basePrice == null || p.basePrice == 0) {
        System.debug('    ⚠️ WARNING: Product has no price!');
    }
}
```

### 4. Lead_Product__c Mapping Test

**Scenario**: Create test Lead_Product__c records to verify Aantal__c mapping

```apex
// Create test lead
Lead testLead = new Lead(
    FirstName = 'Test',
    LastName = 'SR Product',
    Company = 'Test Company',
    Email = 'test@example.com'
);
insert testLead;

// Get product IDs
Map<String, Id> productMap = new Map<String, Id>();
for (Product2 p : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode LIKE 'SR-PRIM%']) {
    productMap.put(p.ProductCode, p.Id);
}

List<Lead_Product__c> testProducts = new List<Lead_Product__c>();

// Test 1: SR Meubel - 3 seats
testProducts.add(new Lead_Product__c(
    Lead__c = testLead.Id,
    Product__c = productMap.get('SR-PRIM-MEUBEL-BANKMK'),
    Aantal__c = 3,  // 3 zitplaatsen
    Verkoopprijs__c = 50.00,
    Totale_Prijs__c = 150.00,
    SKU__c = 'SR-PRIM-MEUBEL-BANKMK'
));

// Test 2: SR Tapijt PLAT - 10 m²
testProducts.add(new Lead_Product__c(
    Lead__c = testLead.Id,
    Product__c = productMap.get('SR-PRIM-TAPIJT-PLAT'),
    Aantal__c = 10.0,  // 10 m²
    Verkoopprijs__c = 5.00,
    Totale_Prijs__c = 50.00,
    SKU__c = 'SR-PRIM-TAPIJT-PLAT'
));

// Test 3: SR Tapijt TRAP - 15 treden
testProducts.add(new Lead_Product__c(
    Lead__c = testLead.Id,
    Product__c = productMap.get('SR-PRIM-TAPIJT-TRAP'),
    Aantal__c = 15,  // 15 treden
    Verkoopprijs__c = 7.50,
    Totale_Prijs__c = 112.50,
    SKU__c = 'SR-PRIM-TAPIJT-TRAP'
));

insert testProducts;

System.debug('✅ Created ' + testProducts.size() + ' test Lead_Product__c records');

// Verify
List<Lead_Product__c> created = [
    SELECT Name, Product__r.ProductCode, Aantal__c, SKU__c
    FROM Lead_Product__c
    WHERE Lead__c = :testLead.Id
];

for (Lead_Product__c lp : created) {
    System.debug('  - ' + lp.Product__r.ProductCode + 
                 ': Aantal__c = ' + lp.Aantal__c);
}

// Cleanup
delete testProducts;
delete testLead;
```

---

## Maintenance

### Regular Tasks

#### Monthly: Price Review

```apex
// Check for outdated prices
List<Prijsmanagement__c> oldPrices = [
    SELECT Product__r.ProductCode, Eenheidsprijs__c, 
           Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
      AND Actief__c = true
      AND Geldig_vanaf__c < LAST_N_MONTHS:6
    ORDER BY Geldig_vanaf__c ASC
];

System.debug('📅 Prices older than 6 months: ' + oldPrices.size());
for (Prijsmanagement__c p : oldPrices) {
    System.debug('  - ' + p.Product__r.ProductCode + 
                 ': €' + p.Eenheidsprijs__c + 
                 ' (Since: ' + p.Geldig_vanaf__c + ')');
}
```

#### Quarterly: Orphaned Products

```apex
// Find active products without prices
List<Product2> orphanedProducts = [
    SELECT Id, ProductCode, Name
    FROM Product2
    WHERE IsActive = true
      AND Segment__c = 'SR'
      AND Id NOT IN (
          SELECT Product__c 
          FROM Prijsmanagement__c 
          WHERE Actief__c = true
      )
];

if (orphanedProducts.isEmpty()) {
    System.debug('✅ No orphaned products');
} else {
    System.debug('⚠️ ' + orphanedProducts.size() + ' products without active prices:');
    for (Product2 p : orphanedProducts) {
        System.debug('  - ' + p.ProductCode + ': ' + p.Name);
    }
}
```

#### Yearly: Price Audit

```apex
// Compare prices year-over-year
Date oneYearAgo = Date.today().addYears(-1);

Map<String, Decimal> currentPrices = new Map<String, Decimal>();
Map<String, Decimal> oldPrices = new Map<String, Decimal>();

// Current prices
for (Prijsmanagement__c p : [
    SELECT Product__r.ProductCode, Eenheidsprijs__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
      AND Actief__c = true
]) {
    currentPrices.put(p.Product__r.ProductCode, p.Eenheidsprijs__c);
}

// Prices from 1 year ago
for (Prijsmanagement__c p : [
    SELECT Product__r.ProductCode, Eenheidsprijs__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
      AND Geldig_vanaf__c <= :oneYearAgo
      AND (Geldig_tot__c >= :oneYearAgo OR Geldig_tot__c = null)
]) {
    oldPrices.put(p.Product__r.ProductCode, p.Eenheidsprijs__c);
}

// Compare
System.debug('📊 Price changes (year-over-year):');
for (String productCode : currentPrices.keySet()) {
    Decimal current = currentPrices.get(productCode);
    Decimal old = oldPrices.get(productCode);
    
    if (old != null && old != current) {
        Decimal change = ((current - old) / old) * 100;
        System.debug('  - ' + productCode + ': €' + old + ' → €' + current + 
                     ' (' + change.setScale(1) + '%)');
    }
}
```

### Backup & Recovery

#### Backup Price Configuration

```apex
// Export current price configuration as CSV
List<Prijsmanagement__c> prices = [
    SELECT Product__r.ProductCode, Eenheidsprijs__c, Price_Type__c,
           Actief__c, Geldig_vanaf__c, Geldig_tot__c
    FROM Prijsmanagement__c
    WHERE Product__r.Segment__c = 'SR'
    ORDER BY Product__r.ProductCode
];

String csv = 'ProductCode,Eenheidsprijs,Price_Type,Actief,Geldig_vanaf,Geldig_tot\n';
for (Prijsmanagement__c p : prices) {
    csv += p.Product__r.ProductCode + ',' +
           p.Eenheidsprijs__c + ',' +
           p.Price_Type__c + ',' +
           p.Actief__c + ',' +
           p.Geldig_vanaf__c + ',' +
           (p.Geldig_tot__c != null ? p.Geldig_tot__c : '') + '\n';
}

System.debug(csv);

// Save to file or send via email
// Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
// ...
```

#### Restore Prices from Backup

```apex
// Restore prices from CSV backup
// Parse CSV and create Prijsmanagement__c records
// (Implementation depends on backup format)
```

---

## Best Practices

### 1. Always Use Date-Based Price Validity

```apex
// ✅ CORRECT: Set start date
Prijsmanagement__c price = new Prijsmanagement__c(
    Product__c = productId,
    Eenheidsprijs__c = 50.00,
    Actief__c = true,
    Geldig_vanaf__c = Date.today(),  // Always set
    Geldig_tot__c = null  // null = no expiry
);

// ❌ WRONG: No start date
Prijsmanagement__c price = new Prijsmanagement__c(
    Product__c = productId,
    Eenheidsprijs__c = 50.00,
    Actief__c = true
    // Geldig_vanaf__c missing!
);
```

### 2. Never Delete Old Prices

```apex
// ✅ CORRECT: Deactivate old price
Prijsmanagement__c oldPrice = [SELECT Id FROM Prijsmanagement__c WHERE Id = :priceId];
oldPrice.Actief__c = false;
oldPrice.Geldig_tot__c = Date.today().addDays(-1);
update oldPrice;

// ❌ WRONG: Delete price record
delete oldPrice;  // Loses price history!
```

### 3. Always Test API After Price Changes

```apex
// After updating prices, test API response
RestRequest req = new RestRequest();
req.requestBody = Blob.valueOf('{"postcode":"1012AB","segment":"SR"}');
RestContext.request = req;
RestContext.response = new RestResponse();

PriceCalculationApi.PriceResponse response = PriceCalculationApi.calculatePrice();

// Verify new prices are returned
for (PriceCalculationApi.ProductInfo p : response.availableProducts) {
    System.debug(p.productCode + ': €' + p.basePrice);
}
```

### 4. Document Price Changes

```apex
// Add comment to Prijsmanagement__c object
// Or use custom field: Wijziging_Reden__c (Text Area)

Prijsmanagement__c newPrice = new Prijsmanagement__c(
    Product__c = productId,
    Eenheidsprijs__c = 55.00,
    // Wijziging_Reden__c = 'Annual price increase - 10%',
    Actief__c = true,
    Geldig_vanaf__c = Date.today()
);
```

---

## Deployment Checklist

### Initial Setup
- [ ] All SR Product2 records created
- [ ] All products have `IsActive = true`
- [ ] All products have `Segment__c = 'SR'`
- [ ] All products have unique `ProductCode`
- [ ] All Prijsmanagement__c records created
- [ ] All prices have `Actief__c = true`
- [ ] All prices have `Geldig_vanaf__c` set
- [ ] PriceCalculationApi.cls deployed
- [ ] API tested with Postman/cURL

### Pre-Production
- [ ] Test API with `/services/apexrest/v1/calculatePrice`
- [ ] Verify response contains all SR products
- [ ] Verify all products have `basePrice > 0`
- [ ] Test Lead_Product__c creation with correct `Aantal__c`
- [ ] Verify pricing calculation (basePrice × quantity)

### Production
- [ ] Monitor API usage (Setup → API Usage Metrics)
- [ ] Monitor error logs (Setup → Debug Logs)
- [ ] Set up price change alerts
- [ ] Document current prices in wiki/confluence

---

## Support

### Common Issues

**Issue**: API returns empty `availableProducts` array

**Solution**:
1. Check Product2 records: `SELECT Id, IsActive FROM Product2 WHERE Segment__c = 'SR'`
2. Verify `IsActive = true`
3. Check `Site_Identifier__c` matches request `siteId`

**Issue**: Product returned but `basePrice = 0`

**Solution**:
1. Check Prijsmanagement__c: `SELECT Actief__c, Eenheidsprijs__c FROM Prijsmanagement__c WHERE Product__r.ProductCode = 'SR-PRIM-XXX'`
2. Verify `Actief__c = true`
3. Verify `Geldig_vanaf__c <= TODAY`
4. Verify `Geldig_tot__c >= TODAY OR null`

**Issue**: Lead_Product__c has wrong `Aantal__c`

**Solution**:
1. Check WordPress mapping in `class-cinco-lead-endpoint.php`
2. Verify SKU matches ProductCode
3. Check error logs: `tail -f wp-content/debug.log | grep "Cinco SF"`

### Diagnostic Scripts

All diagnostic scripts are located in: `scripts/apex/`

- `check_sr_products.apex` - List all SR products
- `check_sr_pricing.apex` - List all SR prices with validation
- `test_sr_api.apex` - Test API response
- `check_lead_products.apex` - Verify Lead_Product__c mapping

---

**Version**: 1.0.0  
**Last Updated**: October 7, 2025  
**Maintained By**: Salesforce Development Team

*For WordPress integration, see: `cinco-offerte-systeem/SR-IMPLEMENTATION-GUIDE.md`*
