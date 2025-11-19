# Regiotoeslag Implementation - Salesforce Backend

## 🎯 Implementatie Overzicht

De regiotoeslag functionaliteit is nu volledig geïmplementeerd in de Salesforce backend. Dit vult de missing link op tussen de reeds bestaande WordPress frontend en de Salesforce pricing logic.

## ✅ Wat Er Is Geïmplementeerd

### 1. PriceResponse Class Update
```apex
global class PriceResponse {
    // ... bestaande velden ...
    @AuraEnabled public Decimal regioToeslagPercentage; // <-- NIEUW
}
```

### 2. Enhanced findPartnerAssociation Method
```apex
// Updated SOQL query om Toeslag__c veld op te halen
SELECT Id, Afhandelingsmethode__c, Postcode_Gebied__r.Name, Segment__c, Toeslag__c
FROM Dienstgebied_Postcode_Associatie__c 
WHERE ... // postcode en segment condities
```

### 3. Regiotoeslag Logic in calculatePrice
```apex
// Na het vinden van de partner associatie:
if (associatie.Toeslag__c != null && associatie.Toeslag__c > 0) {
    response.regioToeslagPercentage = associatie.Toeslag__c;
    System.debug('🏷️ Regiotoeslag gevonden: ' + response.regioToeslagPercentage + '%');
} else {
    response.regioToeslagPercentage = 0;
    System.debug('📍 Geen regiotoeslag voor postcode ' + request.postcode);
}
```

## 🔄 Complete Data Flow

### 1. WordPress Poortwachter → Salesforce
```javascript
// WordPress stuurt postcode check request
fetch('/wp-json/cinco/v1/calculate-price', {
    body: JSON.stringify({
        postcode: '1012AB',
        segment: 'Wasserij',
        siteId: 'CincoCleaning'
    })
})
```

### 2. Salesforce Processing
```apex
// Salesforce zoekt partner associatie
Dienstgebied_Postcode_Associatie__c associatie = findPartnerAssociation('1012AB', 'Wasserij');

// Controleert regiotoeslag
if (associatie.Toeslag__c == 15) {
    response.regioToeslagPercentage = 15;
}
```

### 3. Salesforce → WordPress Response
```json
{
    "success": true,
    "afhandelingsmethode": "Directe Prijs (Order)",
    "regioToeslagPercentage": 15,
    "availableProducts": [...]
}
```

### 4. WordPress Poortwachter Processing
```javascript
// WordPress leest regiotoeslag uit response
if (result.regioToeslagPercentage && result.regioToeslagPercentage > 0) {
    redirectUrl += '&rt=' + result.regioToeslagPercentage;
}
// Result: /offerte/?postcode=1012AB&segment=Wasserij&rt=15
```

### 5. WordPress Main Form
```javascript
// Main form leest rt parameter en past prijzen aan
const urlParams = new URLSearchParams(window.location.search);
const regioToeslag = parseFloat(urlParams.get('rt')) || 0;

// Pricing calculation includes regiotoeslag
finalPrice = basePrice * (1 + regioToeslag / 100);
```

## 📋 Debug Logging

De implementatie bevat uitgebreide debug logging:

```apex
// Partner gevonden met toeslag
🏷️ Regiotoeslag gevonden: 15% voor postcode 1012AB

// Geen toeslag gevonden
📍 Geen regiotoeslag voor postcode 1234AB

// Enhanced partner association logging
Found association: Directe Prijs (Order) for postcode gebied: Amsterdam with toeslag: 15%
```

## 🧪 Testing

### Test Script: `REGIOTOESLAG_IMPLEMENTATION_TEST.apex`
- Test response structure met regioToeslagPercentage
- Check bestaande associaties met Toeslag__c waarden
- Simuleer enhanced partner association logic

### Handmatige Test Flow:
1. Deploy PriceCalculationApi.cls naar Salesforce
2. Test via WordPress poortwachter met een postcode die regiotoeslag heeft
3. Controleer JSON response bevat regioToeslagPercentage
4. Verificeer dat WordPress &rt=X toevoegt aan redirect URL

## 📊 Expected Results

### Voor Implementation:
```
WordPress Poortwachter Response:
{
    "success": true,
    "afhandelingsmethode": "Directe Prijs (Order)",
    // regioToeslagPercentage ontbreekt ❌
}

Redirect URL: /offerte/?postcode=1012AB&segment=Wasserij
```

### Na Implementation:
```
WordPress Poortwachter Response:
{
    "success": true,
    "afhandelingsmethode": "Directe Prijs (Order)",
    "regioToeslagPercentage": 15  // ✅ NU AANWEZIG
}

Redirect URL: /offerte/?postcode=1012AB&segment=Wasserij&rt=15
```

## 🚀 Deployment Steps

1. **Deploy Salesforce Changes:**
   ```bash
   sfdx force:source:deploy -p force-app/main/default/classes/PriceCalculationApi.cls
   ```

2. **Run Test Script:**
   ```bash
   sfdx force:apex:execute -f REGIOTOESLAG_IMPLEMENTATION_TEST.apex
   ```

3. **Verify Integration:**
   - Test via WordPress poortwachter
   - Check JSON response
   - Verify URL parameters

## 🔧 Configuration

Zorg ervoor dat Dienstgebied_Postcode_Associatie__c records het juiste `Toeslag__c` veld hebben ingevuld:

```
Postcode Gebied: Amsterdam (1000-1099)
Segment: Wasserij  
Afhandelingsmethode: Directe Prijs (Order)
Toeslag__c: 15
```

## ✅ Success Criteria

- [ ] PriceResponse bevat regioToeslagPercentage property
- [ ] findPartnerAssociation haalt Toeslag__c veld op
- [ ] calculatePrice vult regioToeslagPercentage in response
- [ ] WordPress poortwachter ontvangt regiotoeslag in JSON
- [ ] WordPress voegt &rt=X toe aan redirect URL
- [ ] Main form past regiotoeslag toe in pricing

De regiotoeslag flow is nu end-to-end geïmplementeerd! 🎉