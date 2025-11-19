# Pricing Field Structure Guide

## Overzicht Velden

De pricing engine gebruikt een cleane scheiding tussen basis prijsberekening en korting:

### Basis Pricing Velden
- **`Verkoopprijs__c`** - Prijs per eenheid (€/m²)
- **`Aantal__c`** - Aantal eenheden (m²)
- **`Totale_Prijs__c`** - Basis prijs VOOR korting (Aantal × Verkoopprijs)

### Korting Velden
- **`Korting__c`** - Kortingspercentage (%)
- **`Korting_bedrag__c`** - Absolute kortingsbedrag in euro's

### Eindprijs Veld
- **`Totaal__c`** - **FORMULA FIELD** = `Totale_Prijs__c - Korting_bedrag__c`

## Rekenlogica

### Stap 1: Basis Prijs Berekening
```apex
item.Totale_Prijs__c = item.Aantal__c * item.Verkoopprijs__c;
```

### Stap 2: Korting Berekening
```apex
if (item.Korting__c != null && item.Korting__c > 0) {
    item.Korting_bedrag__c = item.Totale_Prijs__c * (item.Korting__c / 100);
} else {
    item.Korting_bedrag__c = 0;
}
```

### Stap 3: Eindprijs (Formula Field)
```
Totaal__c = Totale_Prijs__c - Korting_bedrag__c
```

## Voordelen van deze Structuur

1. **Transparantie**: Klant ziet duidelijk basis prijs en korting
2. **Flexibiliteit**: Korting kan apart aangepast worden
3. **Auditability**: Alle berekeningen zijn traceerbaar
4. **Performance**: Formula field berekent automatisch eindprijs
5. **Maintenance**: Cleane scheiding tussen logica

## Voorbeeld

```
Vloerkleed: 4m² × €25/m² = €100,00 (Totale_Prijs__c)
Bundelkorting: 5% van €100,00 = €5,00 (Korting_bedrag__c)
Eindprijs: €100,00 - €5,00 = €95,00 (Totaal__c)
```

## Formula Field Setup

In Salesforce Admin → Object Manager → Wasserij_Item__c → Fields:

```
Field Label: Totaal
API Name: Totaal__c
Data Type: Formula (Currency)
Formula: Totale_Prijs__c - Korting_bedrag__c
```

## Test Scenario's

1. **Zonder korting**: Totaal__c = Totale_Prijs__c
2. **Met bundelkorting**: Totaal__c = Totale_Prijs__c - berekende korting
3. **Korting wegvallen**: Korting_bedrag__c wordt 0, Totaal__c = Totale_Prijs__c

## Code Locaties

- **Pricing Logic**: `PricingService.cls` → `transferResultsToItem` method
- **Trigger**: `WasserijItem_Trigger.trigger`
- **Tests**: `scripts/apex/test_kortingsbedrag.apex`