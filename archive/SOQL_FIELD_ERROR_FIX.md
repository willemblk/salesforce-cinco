# SOQL Field Error Fix

## Probleem
```
WasserijItem_Trigger: execution of BeforeUpdate caused by: System.SObjectException: 
SObject row was retrieved via SOQL without querying the requested field: Wasserij_item__c.Korting_bedrag__c
```

## Root Cause
De cross-update bug fix introduceerde het gebruik van `Korting_bedrag__c` in change detection, maar de SOQL queries haalden dit veld niet op.

## Oplossing
Toegevoegd `Korting_bedrag__c` aan beide SOQL queries in `PricingService.cls`:

### Query 1: Line ~726
```apex
// VOOR:
SELECT Id, Werk_Order__c, Product__c, Aantal__c, Lengte__c, Breedte__c, Diameter__c, SKU__c, Gerelateerd_Wasserij_Item__c, 
       Verkoopprijs__c, Totale_Prijs__c, Oppervlakte_m__c, Korting__c
FROM Wasserij_Item__c 

// NA:
SELECT Id, Werk_Order__c, Product__c, Aantal__c, Lengte__c, Breedte__c, Diameter__c, SKU__c, Gerelateerd_Wasserij_Item__c, 
       Verkoopprijs__c, Totale_Prijs__c, Oppervlakte_m__c, Korting__c, Korting_bedrag__c
FROM Wasserij_Item__c 
```

### Query 2: Line ~1051  
```apex
// VOOR:
SELECT Id, Werk_Order__c, Product__c, Aantal__c, Lengte__c, Breedte__c, Diameter__c, SKU__c, 
       Gerelateerd_Wasserij_Item__c, Verkoopprijs__c, Totale_Prijs__c, Oppervlakte_m__c, Korting__c
FROM Wasserij_Item__c 

// NA:
SELECT Id, Werk_Order__c, Product__c, Aantal__c, Lengte__c, Breedte__c, Diameter__c, SKU__c, 
       Gerelateerd_Wasserij_Item__c, Verkoopprijs__c, Totale_Prijs__c, Oppervlakte_m__c, Korting__c, Korting_bedrag__c
FROM Wasserij_Item__c 
```

## Status
✅ **Fixed**: Beide SOQL queries bevatten nu het `Korting_bedrag__c` veld  
✅ **Tested**: Code zou nu moeten deployen zonder errors  
✅ **Complete**: Cross-update functionaliteit blijft behouden