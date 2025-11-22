@RestResource(urlMapping='/v1/calculatePrice/*')
global with sharing class PriceCalculationApi {

    // ----------- 1. DEFINITIES VOOR DATASTRUCTUUR -----------
    // Deze 'wrapper classes' definiëren hoe de data van en naar de website wordt gestructureerd.

    // De volledige aanvraag van de website
    global class PriceRequest {
        @AuraEnabled public String postcode;
        @AuraEnabled public String segment;
        @AuraEnabled public List<RequestLine> products;
        @AuraEnabled public String siteId; // <-- NIEUWE REGEL VOOR MULTI-WEBSITE SUPPORT
    }

    // Eén productregel in de aanvraag
    global class RequestLine {
        @AuraEnabled public String productCode; // bv. 'DAK-PRIM-REINIGING'
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal lengthCm;
        @AuraEnabled public Decimal widthCm;
        @AuraEnabled public Decimal diameterCm;
        @AuraEnabled public Decimal oppervlakteM2; // Voor custom area input
        @AuraEnabled public String relatedProductCode; // For extras relationship
        @AuraEnabled public Map<String, Object> metadata; // For additional data
    }

    // Het volledige antwoord naar de website
    global class PriceResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String afhandelingsmethode; // 'Directe Prijs (Order)' of 'Handmatige Offerte (Quote)'
        @AuraEnabled public List<ResponseProduct> availableProducts;
        @AuraEnabled public List<ResponseLine> calculatedLines;
        @AuraEnabled public Decimal subTotaal;
        @AuraEnabled public Decimal totalKortingBedrag;
        @AuraEnabled public Decimal regioToeslagBedrag;
        @AuraEnabled public Decimal btwTotaal;
        @AuraEnabled public Decimal eindTotaal;
        @AuraEnabled public String calculationId;
        @AuraEnabled public String appliedBundleDiscount;
        @AuraEnabled public Decimal regioToeslagPercentage; // <-- NIEUWE REGEL VOOR REGIOTOESLAG
        @AuraEnabled public List<BundleDiscountRule> bundleDiscounts { get; set; } // <-- NIEUWE REGEL VOOR BUNDLE DISCOUNTS
        @AuraEnabled public List<PackageLineDTO> packages { get; set; } // Optionele pakketten voor Kleda frontend
    @AuraEnabled public Decimal minimumOrderExBtw;      // Order-minimum per postcode/segment
    @AuraEnabled public Decimal minimumOrderInclBtw;    // Display value voor frontend (incl. btw)
        
        // NEW: Lookup IDs for Lead population (WordPress → Salesforce)
        @AuraEnabled public String segment;              // Uniek_Segment__c (Text: "Wasserij", "SR", "Dakkapel")
        @AuraEnabled public String partnerId;            // Partner__c lookup (Account Id - 18 chars)
        @AuraEnabled public String postcodeGebiedId;     // Postcodegebied__c lookup (Postcodegebied__c Id - 18 chars)
        @AuraEnabled public String dienstgebiedId;       // Dienstgebied__c lookup (optional - for reporting)
        
        // NEW: Display names for debugging/logging (optional)
        @AuraEnabled public String partnerName;          // Partner__r.Name
        @AuraEnabled public String postcodeGebiedName;   // Postcodegebied__r.Name
        @AuraEnabled public String dienstgebiedName;     // Dienstgebied__r.Name
    }

    // Eén berekende productregel in het antwoord
    global class ResponseLine {
        @AuraEnabled public String productCode;
        @AuraEnabled public String productName;
        @AuraEnabled public Boolean isPrimary;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal oppervlakte;
        @AuraEnabled public Decimal verkoopprijs;
        @AuraEnabled public Decimal totalePrijs; // Gross amount (before discount)
        @AuraEnabled public Decimal kortingPercentage;
        @AuraEnabled public Decimal kortingBedrag;
        @AuraEnabled public Decimal nettoTotaal; // After discount, before BTW
        @AuraEnabled public Decimal regioToeslagPercentage;
        @AuraEnabled public Decimal btwBedrag;
        @AuraEnabled public Decimal totaalIncBtw;
        @AuraEnabled public String relatedProductCode;
    }
    
    // Eén beschikbaar product (voor de catalogus)
    global class ResponseProduct {
        @AuraEnabled public String productId;
        @AuraEnabled public String productCode;
        @AuraEnabled public String productNaam;
        // NEW: Provide English-cased name fields for WordPress frontend compatibility
        // WordPress UI expects productName/name; keep productNaam for backward compatibility
        @AuraEnabled public String productName;   // Mirrors Product2.Name
        @AuraEnabled public String name;          // Mirrors Product2.Name
        @AuraEnabled public String description;  // Product2.Description for tooltips
    @AuraEnabled public String extraBadge;   // Product2.Extra_Badge__c for marketing badges
        @AuraEnabled public Boolean isPrimary;
        @AuraEnabled public String segment;
        @AuraEnabled public Boolean oppervlakteBerekening; // Voor area calculation
        @AuraEnabled public Boolean bundelkortingToepasbaar;
    @AuraEnabled public Boolean regioToeslagToepasbaar;
        @AuraEnabled public String relatedProductCode; // For extras: ProductCode of parent primary
        @AuraEnabled public Decimal basePrice { get; set; } // Absolute price (legacy)
        @AuraEnabled public Map<String, Decimal> extraPrices { get; set; } // Legacy extra prices
        @AuraEnabled public List<StaffelTier> staffelPricing { get; set; } // Staffel pricing tiers
        @AuraEnabled public List<ResponseProduct> extras = new List<ResponseProduct>(); // Keep for backward compatibility
        
        // ▼▼▼ NEW: PERCENTAGE-BASED PRICING SUPPORT ▼▼▼
        @AuraEnabled public Decimal percentageOfBase { get; set; }  // e.g., 10 for 10%
        @AuraEnabled public String pricingType { get; set; }        // 'percentage' or 'absolute'
        // ▲▲▲ END PERCENTAGE PRICING FIELDS ▲▲▲
        
        // SR segment fields removed - not used in WordPress frontend
    }

    // Eén pakketproduct voor de catalogus (Wasserij rug pakketten)
    global class PackageLineDTO implements Comparable {
        @AuraEnabled public String sku;
        @AuraEnabled public String label;
        @AuraEnabled public String description;
        @AuraEnabled public String pricingType;
        @AuraEnabled public Decimal percentage;
        @AuraEnabled public Decimal price_flat;
        @AuraEnabled public Decimal price_per_m2;
        @AuraEnabled public Integer sortOrder;
        @AuraEnabled public String category;

        // Sorteer pakketten op priority → label zodat JSON stabiel blijft
        public Integer compareTo(Object otherObject) {
            if (otherObject == null) {
                return 1;
            }
            PackageLineDTO other = (PackageLineDTO) otherObject;
            Integer thisOrder = sortOrder != null ? sortOrder : 0;
            Integer otherOrder = other.sortOrder != null ? other.sortOrder : 0;
            if (thisOrder == otherOrder) {
                String thisLabel = label != null ? label : '';
                String otherLabel = other.label != null ? other.label : '';
                Integer insensitiveCompare = thisLabel.toLowerCase().compareTo(otherLabel.toLowerCase());
                return insensitiveCompare != 0 ? insensitiveCompare : thisLabel.compareTo(otherLabel);
            }
            return thisOrder - otherOrder;
        }
    }

    // Bundle discount regel voor frontend
    global class BundleDiscountRule {
        @AuraEnabled public String label;
        @AuraEnabled public String bundleName;
        @AuraEnabled public Integer minCount;
        @AuraEnabled public Decimal discountPercent;
        @AuraEnabled public String segment;
        @AuraEnabled public Boolean active;
        @AuraEnabled public Decimal minAantalThreshold;
    }

    // ▼▼▼ NEW: Staffel pricing tier voor frontend ▼▼▼
    global class StaffelTier {
        @AuraEnabled public Decimal ondergrens;      // Min quantity (e.g., 1, 3, 6)
        @AuraEnabled public Decimal bovengrens;      // Max quantity (e.g., 2, 5, 999)
        @AuraEnabled public Decimal eenheidsprijs;   // Price per unit at this tier
        @AuraEnabled public Decimal vastePrijs;      // Fixed price (if applicable)
        
        public StaffelTier(Decimal onder, Decimal boven, Decimal eenheid, Decimal vast) {
            this.ondergrens = onder;
            this.bovengrens = boven;
            this.eenheidsprijs = eenheid;
            this.vastePrijs = vast;
        }
    }
    // ▲▲▲ END STAFFEL TIER ▲▲▲


    // ----------- 2. HET API-EINDPUNT -----------
    // Dit is de hoofdmethode die de website aanroept via een POST request.

    @HttpPost
    global static PriceResponse calculatePrice() {
        System.debug('=== PRICE CALCULATION API CALLED ===');
        
        // Parse request body manually for HttpPost
        RestRequest req = RestContext.request;
        String requestBody = req.requestBody.toString();
        PriceRequest request;
        
        try {
            request = (PriceRequest) JSON.deserialize(requestBody, PriceRequest.class);
        } catch (Exception e) {
            System.debug('Error parsing request body: ' + e.getMessage());
            return createErrorResponse('Invalid request format: ' + e.getMessage());
        }
        
        System.debug('Request: ' + JSON.serializePretty(request));
        
        PriceResponse response = new PriceResponse();
        response.calculationId = generateCalculationId();

        try {
            // Input validation
            if (request == null) {
                return createErrorResponse('Invalid request: request body is null');
            }

            if (String.isBlank(request.postcode)) {
                return createErrorResponse('Invalid request: postcode is required');
            }

            if (String.isBlank(request.segment)) {
                return createErrorResponse('Invalid request: segment is required');
            }

            System.debug('Processing request for postcode: ' + request.postcode + ', segment: ' + request.segment);

            // Stap A: De "Poortwachter" - Controleer beschikbaarheid
            Dienstgebied_Postcode_Associatie__c associatie = findPartnerAssociation(request.postcode, request.segment);

            if (associatie == null) {
                response.success = false;
                response.errorMessage = 'Helaas hebben wij nog geen geschikte partner in je regio.';
                System.debug('No partner association found for postcode ' + request.postcode + ' and segment ' + request.segment);
                return response;
            }
            
            response.success = true;
            response.afhandelingsmethode = associatie.Afhandelingsmethode__c;
            
            // ▼▼▼ NIEUWE REGIOTOESLAG LOGICA ▼▼▼
            // Als er een toeslag is, voeg deze toe aan de response voor de poortwachter
            if (associatie.Toeslag__c != null && associatie.Toeslag__c > 0) {
                response.regioToeslagPercentage = associatie.Toeslag__c;
                System.debug('🏷️ Regiotoeslag gevonden: ' + response.regioToeslagPercentage + '% voor postcode ' + request.postcode);
            } else {
                response.regioToeslagPercentage = 0;
                System.debug('📍 Geen regiotoeslag voor postcode ' + request.postcode);
            }
            // ▲▲▲ EINDE REGIOTOESLAG LOGICA ▲▲▲

            // ▼▼▼ NIEUW: ORDER-MINIMUM PER ASSOCIATIE ▼▼▼
            if (associatie.Minimum_Order_Excl_BTW__c != null && associatie.Minimum_Order_Excl_BTW__c > 0) {
                response.minimumOrderExBtw = associatie.Minimum_Order_Excl_BTW__c.setScale(2);
                Decimal defaultBtwPercent = 21;
                response.minimumOrderInclBtw = (response.minimumOrderExBtw * (1 + (defaultBtwPercent / 100))).setScale(2, RoundingMode.HALF_UP);
                System.debug('💶 Minimum order (ex btw): €' + response.minimumOrderExBtw + ' | incl. btw: €' + response.minimumOrderInclBtw);
            }
            // ▲▲▲ EINDE ORDER-MINIMUM LOGICA ▲▲▲
            
            // ▼▼▼ NEW: POPULATE LOOKUP IDS FOR LEAD CREATION ▼▼▼
            // These fields are sent back to WordPress and used to populate Lead fields
            response.segment = associatie.Segment__c;                                  // For Lead.Uniek_Segment__c
            response.partnerId = associatie.Partner__c;                                // For Lead.Partner__c (Account lookup)
            response.postcodeGebiedId = associatie.Postcode_Gebied__c;                 // For Lead.Postcodegebied__c lookup
            response.dienstgebiedId = associatie.Dienstgebied__c;                      // For Lead.Dienstgebied__c lookup (optional)
            
            // Display names for logging/debugging (optional)
            response.partnerName = associatie.Partner__r.Name;
            response.postcodeGebiedName = associatie.Postcode_Gebied__r.Name;
            response.dienstgebiedName = associatie.Dienstgebied__r.Name;
            
            System.debug('🔗 Lookup IDs populated:');
            System.debug('   Segment: ' + response.segment);
            System.debug('   Partner: ' + response.partnerName + ' (' + response.partnerId + ')');
            System.debug('   Postcodegebied: ' + response.postcodeGebiedName + ' (' + response.postcodeGebiedId + ')');
            System.debug('   Dienstgebied: ' + response.dienstgebiedName + ' (' + response.dienstgebiedId + ')');
            // ▲▲▲ END LOOKUP POPULATION ▲▲▲
            
            System.debug('Partner found: ' + response.afhandelingsmethode);

            // Laad optionele pakketten voor Wasserij (alleen indien relevant voor segment/site)
            List<PackageLineDTO> packageCatalog = getPackagesForSegment(request.segment, request);
            System.debug('📦 Loaded ' + packageCatalog.size() + ' packages for segment ' + request.segment);

            // Stap B: Stuur de productcatalogus EN bundle discounts terug (als er geen producten zijn om te berekenen)
            if (request.products == null || request.products.isEmpty()) {
                System.debug('No products to calculate - returning product catalog with bundle discounts');
                response.availableProducts = getProductCatalogForSegment(request.segment, request);
                
                // Bundle discount regels toevoegen aan catalogus response
                response.bundleDiscounts = getBundleDiscountRulesForSegment(request.segment);
                System.debug('🎁 Added ' + response.bundleDiscounts.size() + ' bundle discount rules to catalog response');
                response.packages = packageCatalog;
                
                return response;
            }

            System.debug('Calculating prices for ' + request.products.size() + ' product lines');

            // Stap C: De "Rekenmachine" - Bereken de prijzen
            List<Lead_Product__c> tempLeadProducts = convertRequestToLeadProducts(request);
            
            if (tempLeadProducts.isEmpty()) {
                return createErrorResponse('No valid products found for calculation');
            }

            System.debug('Created ' + tempLeadProducts.size() + ' temporary Lead_Product__c records');
            
            // Call the pricing engine
            List<SObject> berekendeRegels = PricingService.reprice(tempLeadProducts);
            System.debug('PricingService completed calculation for ' + berekendeRegels.size() + ' records');
            
            // Stap D: Formatteer het antwoord en bereken de totalen
            response.calculatedLines = formatLinesForResponse(berekendeRegels);
            calculateTotals(berekendeRegels, response);
            
            // Bundle discount regels ook toevoegen bij calculatie response
            response.bundleDiscounts = getBundleDiscountRulesForSegment(request.segment);
            response.packages = packageCatalog;
            
            System.debug('Price calculation completed successfully. Total: €' + response.eindTotaal);
            return response;

        } catch (Exception e) {
            System.debug('Error in PriceCalculationApi: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return createErrorResponse('Calculation error: ' + e.getMessage());
        }
    }


    // ----------- 3. HELPER-METHODES -----------

    // Zoekt een partner voor een postcode en segment
    private static Dienstgebied_Postcode_Associatie__c findPartnerAssociation(String postcode, String segment) {
        if (String.isBlank(postcode) || String.isBlank(segment)) {
            System.debug('Invalid input: postcode or segment is blank');
            return null;
        }
        
        try {
            // Extract numeric part of postcode (first 4 digits)
            String numericPart = postcode.replaceAll('[^0-9]', '');
            if (numericPart.length() < 4) {
                System.debug('Invalid postcode format: ' + postcode);
                return null;
            }
            
            Integer postcodeNum = Integer.valueOf(numericPart.substring(0, 4));
            System.debug('Looking for associations with postcode: ' + postcodeNum + ' and segment: ' + segment);

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
                       Partner__c,                                      // For Lead.Partner__c lookup (on associatie)
                       Partner__r.Name,                                 // Partner display name
                       Minimum_Order_Excl_BTW__c                        // Order-minimum per postcode/segment
                FROM Dienstgebied_Postcode_Associatie__c 
                WHERE Postcode_Gebied__r.Postcode_Begin__c <= :postcodeNum 
                  AND Postcode_Gebied__r.Postcode_Einde__c >= :postcodeNum
                  AND Segment__c = :segment
                LIMIT 1
            ];
            
            if (!associaties.isEmpty()) {
                Dienstgebied_Postcode_Associatie__c result = associaties[0];
                System.debug('Found association: ' + result.Afhandelingsmethode__c + 
                           ' for postcode gebied: ' + result.Postcode_Gebied__r.Name +
                           ' with toeslag: ' + (result.Toeslag__c != null ? result.Toeslag__c + '%' : 'none'));
                return result;
            }
            
            // Return null if no association found
            return null;
            
        } catch (Exception e) {
            System.debug('Error finding partner association: ' + e.getMessage());
            return null;
        }
    }

    // Haalt de volledige productcatalogus op voor een segment
    private static List<ResponseProduct> getProductCatalogForSegment(String segment, PriceRequest request) {
        System.debug('Getting product catalog for segment: ' + segment);
        
        // ▼▼▼ NIEUWE LOGICA VOOR MULTI-WEBSITE FILTERING ▼▼▼
        // Haal de siteId op uit de request. Gebruik een fallback als deze niet is meegegeven.
        // Dit zorgt ervoor dat de code niet breekt als een oude plugin-versie de call doet.
        String siteIdentifier = resolveSiteIdentifier(request);
        System.debug('Filtering catalog for site identifier: ' + siteIdentifier);
        // ▲▲▲ EINDE NIEUWE LOGICA ▲▲▲
        
        Map<Id, ResponseProduct> primaryProducts = new Map<Id, ResponseProduct>();
        List<Product2> extras = new List<Product2>();
        
        // ▼▼▼ Declare flat list for WordPress compatibility ▼▼▼
        List<ResponseProduct> flatProductList = new List<ResponseProduct>();
        // ▲▲▲ End declaration ▲▲▲

        try {
            // ▼▼▼ ENHANCED: Collect all products first, then fetch prices ▼▼▼
            List<Product2> allProducts = new List<Product2>();
            
            // Pas de SOQL-query aan met de nieuwe filterconditie
            for (Product2 p : [
          SELECT Id, Name, ProductCode, Description, Extra_Badge__c, Primaryproduct__c, Gerelateerd_hoofdproduct__c,
              Segment__c, Oppervlakte_Berekening_Nodig__c, Bundelkorting_Toepasbaar__c,
                       Beschikbare_Websites__c
                FROM Product2 
                WHERE Segment__c = :segment 
                  AND IsActive = true
                  AND Beschikbare_Websites__c INCLUDES (:siteIdentifier)
                ORDER BY Primaryproduct__c DESC, Name ASC
            ]) {
                allProducts.add(p);
                
                if (p.Primaryproduct__c == true) {
                    ResponseProduct respProd = new ResponseProduct();
                    respProd.productId = p.Id;
                    respProd.productCode = p.ProductCode;
                    respProd.productNaam = p.Name;
                    // Populate additional name aliases for the WordPress catalog renderer
                    respProd.productName = p.Name;
                    respProd.name = p.Name;
                    respProd.description = p.Description;  // Add description from Salesforce
                    respProd.extraBadge = p.Extra_Badge__c;
                    respProd.isPrimary = true;
                    respProd.segment = p.Segment__c;
                    respProd.oppervlakteBerekening = p.Oppervlakte_Berekening_Nodig__c;
                    respProd.bundelkortingToepasbaar = p.Bundelkorting_Toepasbaar__c;
                    respProd.extras = new List<ResponseProduct>();
                    
                    primaryProducts.put(p.Id, respProd);
                    
                    System.debug('Primary product found for site ' + siteIdentifier + ': ' + p.ProductCode + ' - ' + p.Name);
                } else {
                    extras.add(p);
                    System.debug('Extra product found for site ' + siteIdentifier + ': ' + p.ProductCode + ' - ' + p.Name);
                }
            }
            
            // ▼▼▼ FALLBACK: Als er geen extras gevonden zijn, zoek alle extras die gekoppeld zijn aan onze primary products ▼▼▼
            if (extras.isEmpty() && !primaryProducts.isEmpty()) {
                System.debug('No extras found with website filter. Searching for extras linked to filtered primaries...');
                
                Set<Id> primaryIds = primaryProducts.keySet();
          List<Product2> linkedExtras = [
              SELECT Id, Name, ProductCode, Extra_Badge__c, Primaryproduct__c, Gerelateerd_hoofdproduct__c,
                  Segment__c, Oppervlakte_Berekening_Nodig__c, Bundelkorting_Toepasbaar__c
                    FROM Product2 
                    WHERE Segment__c = :segment 
                      AND IsActive = true
                      AND Primaryproduct__c = false
                      AND Gerelateerd_hoofdproduct__c IN :primaryIds
                ];
                
                for (Product2 linkedExtra : linkedExtras) {
                    extras.add(linkedExtra);
                    allProducts.add(linkedExtra); // Add to allProducts for pricing lookup
                    System.debug('Fallback extra found: ' + linkedExtra.ProductCode + ' → Primary ID: ' + linkedExtra.Gerelateerd_hoofdproduct__c);
                }
                
                System.debug('Found ' + linkedExtras.size() + ' extras via fallback method');
            }
            // ▲▲▲ END FALLBACK ▲▲▲
            
            // ▼▼▼ NEW: DYNAMIC PRICING LOGIC ▼▼▼
            System.debug('💰 Loading dynamic prices for ' + allProducts.size() + ' products...');
            
            // 1. Verzamel alle Product ID's
            Set<Id> productIds = new Set<Id>();
            for(Product2 p : allProducts) {
                productIds.add(p.Id);
            }
            
            // 2. Haal alle actieve prijsregels op voor deze producten in één query
            Map<Id, Prijsmanagement__c> priceMap = new Map<Id, Prijsmanagement__c>();
            Map<Id, Id> productToPriceManagementMap = new Map<Id, Id>(); // Product ID → Prijsmanagement ID
            if (!productIds.isEmpty()) {
                for(Prijsmanagement__c priceRule : [
                    SELECT Id, Product__c, Eenheidsprijs__c, Relatieve_prijs__c, Price_Type__c, Regiotoeslag_toepasbaar__c
                    FROM Prijsmanagement__c 
                    WHERE Product__c IN :productIds 
                      AND Actief__c = true 
                      AND Geldig_vanaf__c <= TODAY 
                      AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
                ]) {
                    priceMap.put(priceRule.Product__c, priceRule);
                    productToPriceManagementMap.put(priceRule.Product__c, priceRule.Id);
                    
                    // Enhanced debug for percentage pricing
                    if (priceRule.Relatieve_prijs__c != null && priceRule.Relatieve_prijs__c > 0) {
                        System.debug('💰 Price found for product ' + priceRule.Product__c + 
                                   ': ' + priceRule.Relatieve_prijs__c + '% (percentage-based)');
                    } else {
                        System.debug('💰 Price found for product ' + priceRule.Product__c + 
                                   ': €' + priceRule.Eenheidsprijs__c + ' (absolute)');
                    }
                }
            }
            
            System.debug('💰 Loaded ' + priceMap.size() + ' active price rules');
            
            // ▼▼▼ NEW: STAFFEL PRICING LOGIC ▼▼▼
            // 3. Haal alle staffel tiers op voor producten met staffel pricing
            Map<Id, List<StaffelTier>> staffelMap = new Map<Id, List<StaffelTier>>(); // Product ID → List of tiers
            if (!productToPriceManagementMap.isEmpty()) {
                Set<Id> priceManagementIds = new Set<Id>(productToPriceManagementMap.values());
                
                for(Prijsstaffel__c staffel : [
                    SELECT Prijsmanagement__c, Ondergrens__c, Bovengrens__c, 
                           Eenheidsprijs__c, Vaste_Prijs__c
                    FROM Prijsstaffel__c 
                    WHERE Prijsmanagement__c IN :priceManagementIds
                    ORDER BY Ondergrens__c ASC
                ]) {
                    // Find which product this staffel belongs to
                    Id productId = null;
                    for(Id pid : productToPriceManagementMap.keySet()) {
                        if(productToPriceManagementMap.get(pid) == staffel.Prijsmanagement__c) {
                            productId = pid;
                            break;
                        }
                    }
                    
                    if(productId != null) {
                        if(!staffelMap.containsKey(productId)) {
                            staffelMap.put(productId, new List<StaffelTier>());
                        }
                        
                        staffelMap.get(productId).add(new StaffelTier(
                            staffel.Ondergrens__c,
                            staffel.Bovengrens__c,
                            staffel.Eenheidsprijs__c,
                            staffel.Vaste_Prijs__c
                        ));
                        
                        System.debug('📊 Staffel tier for product ' + productId + ': ' + 
                                   staffel.Ondergrens__c + '-' + staffel.Bovengrens__c + 
                                   ' = €' + staffel.Eenheidsprijs__c + '/unit');
                    }
                }
                
                System.debug('📊 Loaded staffel pricing for ' + staffelMap.size() + ' products');
            }
            // ▲▲▲ END STAFFEL PRICING LOGIC ▲▲▲
            // ▲▲▲ END DYNAMIC PRICING LOGIC ▲▲▲
            
            // ▼▼▼ APPLY PRICING TO PRIMARY PRODUCTS ▼▼▼
            for (Id primaryId : primaryProducts.keySet()) {
                ResponseProduct rp = primaryProducts.get(primaryId);
                
                // Set dynamic base price
                if (priceMap.containsKey(primaryId)) {
                    Prijsmanagement__c primaryPriceRule = priceMap.get(primaryId);
                    rp.basePrice = primaryPriceRule.Eenheidsprijs__c;
                    rp.regioToeslagToepasbaar = (primaryPriceRule.Regiotoeslag_toepasbaar__c == true);
                    System.debug('💰 Primary ' + rp.productCode + ' base price: €' + rp.basePrice + ' | Regiotoeslag toepasbaar: ' + rp.regioToeslagToepasbaar);
                } else {
                    rp.basePrice = 0; // Fallback
                    rp.regioToeslagToepasbaar = false;
                    System.debug('⚠️ Primary ' + rp.productCode + ' no price found - using €0 fallback');
                }
                
                // Set staffel pricing tiers if available
                if (staffelMap.containsKey(primaryId)) {
                    rp.staffelPricing = staffelMap.get(primaryId);
                    System.debug('📊 Primary ' + rp.productCode + ' has ' + rp.staffelPricing.size() + ' staffel tiers');
                } else {
                    rp.staffelPricing = new List<StaffelTier>(); // Empty list if no staffel
                }
                
                // Initialize extraPrices map
                rp.extraPrices = new Map<String, Decimal>();
            }
            // ▲▲▲ END PRIMARY PRODUCT PRICING ▲▲▲
            
            System.debug('Found ' + primaryProducts.size() + ' primary products and ' + extras.size() + ' extras');
            
            // Enhanced debugging for primary products
            for (Id primaryId : primaryProducts.keySet()) {
                ResponseProduct rp = primaryProducts.get(primaryId);
                System.debug('Primary product ID ' + primaryId + ': ' + rp.productCode + ' - ' + rp.productNaam + ' (€' + rp.basePrice + ')');
            }
            
            // Koppel extra's aan hun hoofdproduct
            Integer linkedExtras = 0;
            for (Product2 extra : extras) {
                System.debug('Processing extra: ' + extra.ProductCode + ' - ' + extra.Name + 
                           ', Gerelateerd_hoofdproduct__c: ' + extra.Gerelateerd_hoofdproduct__c);
                
                if (extra.Gerelateerd_hoofdproduct__c != null && 
                    primaryProducts.containsKey(extra.Gerelateerd_hoofdproduct__c)) {
                    
                    // Haal het parent primary product op
                    ResponseProduct parentPrimary = primaryProducts.get(extra.Gerelateerd_hoofdproduct__c);
                    
                    ResponseProduct extraProd = new ResponseProduct();
                    extraProd.productId = extra.Id;
                    extraProd.productCode = extra.ProductCode;
                    extraProd.productNaam = extra.Name;
                    // Populate additional name aliases for the WordPress catalog renderer
                    extraProd.productName = extra.Name;
                    extraProd.name = extra.Name;
                    extraProd.description = extra.Description;  // Add description from Salesforce
                    extraProd.extraBadge = extra.Extra_Badge__c;
                    extraProd.isPrimary = false;
                    extraProd.segment = extra.Segment__c;
                    extraProd.oppervlakteBerekening = extra.Oppervlakte_Berekening_Nodig__c;
                    extraProd.bundelkortingToepasbaar = extra.Bundelkorting_Toepasbaar__c;
                    
                    // ▼▼▼ DYNAMIC PRICING FOR EXTRAS WITH PERCENTAGE, ABSOLUTE, AND FLAT FEE SUPPORT ▼▼▼
                    if (priceMap.containsKey(extra.Id)) {
                        Prijsmanagement__c priceRule = priceMap.get(extra.Id);
                        String priceType = priceRule.Price_Type__c != null ? priceRule.Price_Type__c : 'Normaal';
                        extraProd.regioToeslagToepasbaar = (priceRule.Regiotoeslag_toepasbaar__c == true);
                        
                        // Determine pricing type based on Price_Type__c and field values
                        if (priceType == 'Flat Fee') {
                            // Flat Fee pricing (e.g., inpakopslag, plastic verpakking)
                            extraProd.basePrice = priceRule.Eenheidsprijs__c;
                            extraProd.pricingType = 'flat';
                            extraProd.percentageOfBase = null;
                            
                            System.debug('💰 Extra ' + extra.ProductCode + ' flat fee: €' + extraProd.basePrice);
                            
                            // Add to parent's extraPrices map
                            parentPrimary.extraPrices.put(extra.ProductCode, extraProd.basePrice);
                        } else if (priceRule.Relatieve_prijs__c != null && priceRule.Relatieve_prijs__c > 0) {
                            // Percentage-based pricing (SR extras: vezelbeschermer, etc.)
                            extraProd.percentageOfBase = priceRule.Relatieve_prijs__c;
                            extraProd.pricingType = 'percentage';
                            extraProd.basePrice = null; // No absolute price for percentage extras
                            
                            System.debug('💰 Extra ' + extra.ProductCode + ' percentage pricing: ' + 
                                       extraProd.percentageOfBase + '% of base product');
                            
                            // Add to parent's extraPrices map (for backward compatibility, use percentage as value)
                            parentPrimary.extraPrices.put(extra.ProductCode, priceRule.Relatieve_prijs__c);
                        } else {
                            // Absolute pricing (per m², per seat, per item - legacy/default)
                            extraProd.basePrice = priceRule.Eenheidsprijs__c;
                            extraProd.pricingType = 'absolute';
                            extraProd.percentageOfBase = null;
                            
                            System.debug('💰 Extra ' + extra.ProductCode + ' absolute price: €' + extraProd.basePrice);
                            
                            // Add to parent's extraPrices map
                            parentPrimary.extraPrices.put(extra.ProductCode, extraProd.basePrice);
                        }
                    } else {
                        // Fallback: no pricing found
                        extraProd.basePrice = 0;
                        extraProd.pricingType = 'absolute';
                        extraProd.percentageOfBase = null;
                        extraProd.regioToeslagToepasbaar = false;
                        
                        System.debug('⚠️ Extra ' + extra.ProductCode + ' no price found - using €0 fallback');
                        parentPrimary.extraPrices.put(extra.ProductCode, 0);
                    }
                    
                    // Initialize extraPrices map for the extra (though it likely won't have sub-extras)
                    extraProd.extraPrices = new Map<String, Decimal>();
                    // ▲▲▲ END DYNAMIC PRICING FOR EXTRAS ▲▲▲
                    
                    // ▼▼▼ CRUCIAL: Set relatedProductCode to parent's ProductCode ▼▼▼
                    extraProd.relatedProductCode = parentPrimary.productCode;
                    // ▲▲▲ This maintains parent-child relationship in flat list ▲▲▲
                    
                    // Still add to nested structure for backward compatibility
                    primaryProducts.get(extra.Gerelateerd_hoofdproduct__c).extras.add(extraProd);
                    linkedExtras++;
                    
                    System.debug('✅ Extra linked: ' + extra.ProductCode + ' → Primary: ' + parentPrimary.productCode + ' (€' + extraProd.basePrice + ') (ID: ' + extra.Gerelateerd_hoofdproduct__c + ')');
                } else {
                    if (extra.Gerelateerd_hoofdproduct__c == null) {
                        System.debug('⚠️ Extra ' + extra.ProductCode + ' has no Gerelateerd_hoofdproduct__c');
                    } else {
                        System.debug('⚠️ Extra ' + extra.ProductCode + ' references non-existent primary: ' + extra.Gerelateerd_hoofdproduct__c);
                    }
                }
            }
            
            System.debug('Successfully linked ' + linkedExtras + ' extras to primary products');
            
            // ▼▼▼ ENHANCED: WordPress-compatible flat list with parent-child relationships ▼▼▼
            // Create flat list where extras have relatedProductCode pointing to their parent
            
            // First, add all primary products (they have no parent)
            for (ResponseProduct primary : primaryProducts.values()) {
                primary.relatedProductCode = null; // Primaries have no parent
                flatProductList.add(primary);
            }
            
            // Then, add all extras as separate items with relatedProductCode set
            for (ResponseProduct primary : primaryProducts.values()) {
                for (ResponseProduct extra : primary.extras) {
                    // The relatedProductCode was already set in the linking logic above
                    flatProductList.add(extra);
                }
            }
            
            // Final count verification - enhanced with relationship info
            Integer totalPrimariesInResponse = 0;
            Integer totalExtrasInResponse = 0;
            
            for (ResponseProduct rp : flatProductList) {
                if (rp.isPrimary) {
                    totalPrimariesInResponse++;
                    System.debug('📦 PRIMARY in response: ' + rp.productCode + ' - ' + rp.productNaam);
                } else {
                    totalExtrasInResponse++;
                    String parentInfo = (rp.relatedProductCode != null) ? ' → Parent: ' + rp.relatedProductCode : ' (no parent)';
                    System.debug('⚙️ EXTRA in response: ' + rp.productCode + ' - ' + rp.productNaam + parentInfo);
                }
            }
            
            System.debug('');
            System.debug('🎯 FINAL RESPONSE SUMMARY:');
            System.debug('- Total primary products: ' + totalPrimariesInResponse);
            System.debug('- Total extra products: ' + totalExtrasInResponse);
            System.debug('- Total products in response: ' + flatProductList.size());
            System.debug('- WordPress will see: Primary=' + totalPrimariesInResponse + ', Extras=' + totalExtrasInResponse);
            System.debug('- Each extra has relatedProductCode pointing to its primary parent ✅');
            // ▲▲▲ END ENHANCED FLAT LIST ▲▲▲
            
        } catch (Exception e) {
            System.debug('Error loading product catalog: ' + e.getMessage());
            // Return empty list on error instead of crashing
            return new List<ResponseProduct>();
        }
        
        // Return the flat list that WordPress expects
        return flatProductList;
    }

    // Haalt optionele Wasserij pakketten op voor de catalogus
    private static List<PackageLineDTO> getPackagesForSegment(String segment, PriceRequest request) {
        List<PackageLineDTO> packages = new List<PackageLineDTO>();
        String wasserijSegment = 'Wasserij';
        if (String.isBlank(segment) || !segment.equalsIgnoreCase(wasserijSegment)) {
            System.debug('Skipping package retrieval for segment ' + segment + ' (only supported for Wasserij).');
            return packages;
        }

        String siteIdentifier = resolveSiteIdentifier(request);
        System.debug('Loading packages for site identifier: ' + siteIdentifier);

        try {
            List<Product2> packageProducts = [
                SELECT Id, Name, ProductCode, Description, Product_Category__c,
                       Segment__c, Beschikbare_Websites__c, Gerelateerd_hoofdproduct__r.ProductCode
                FROM Product2
                WHERE Segment__c = :wasserijSegment
                  AND Product_Category__c = 'Package'
                  AND IsActive = true
                  AND Gerelateerd_hoofdproduct__r.ProductCode = 'WAS-PRIM-VLOERKLEED-REINIGEN'
                  AND Beschikbare_Websites__c INCLUDES (:siteIdentifier)
                ORDER BY Name ASC
            ];

            if (packageProducts.isEmpty()) {
                System.debug('No package products found for site ' + siteIdentifier + '.');
                return packages;
            }

            Set<Id> packageIds = new Set<Id>();
            for (Product2 pkg : packageProducts) {
                packageIds.add(pkg.Id);
            }

            Map<Id, Prijsmanagement__c> policyMap = new Map<Id, Prijsmanagement__c>();
            if (!packageIds.isEmpty()) {
                for (Prijsmanagement__c policy : [
                    SELECT Id, Product__c, Eenheidsprijs__c, Relatieve_prijs__c,
                           Price_Type__c, Policy_Priority__c
                    FROM Prijsmanagement__c
                    WHERE Product__c IN :packageIds
                      AND Actief__c = true
                      AND Geldig_vanaf__c <= TODAY
                      AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
                    ORDER BY Product__c, Policy_Priority__c ASC NULLS LAST, Geldig_vanaf__c DESC
                ]) {
                    if (!policyMap.containsKey(policy.Product__c)) {
                        policyMap.put(policy.Product__c, policy);
                        System.debug('📦 Selected package policy for product ' + policy.Product__c +
                                  ' (priority ' + policy.Policy_Priority__c + ').');
                    } else {
                        System.debug('↪️ Skipped lower priority package policy for product ' + policy.Product__c);
                    }
                }
            }

            for (Product2 pkg : packageProducts) {
                PackageLineDTO dto = new PackageLineDTO();
                dto.sku = pkg.ProductCode;
                dto.label = pkg.Name;
                dto.description = pkg.Description;
                dto.category = pkg.Product_Category__c;
                dto.sortOrder = 0;

                Prijsmanagement__c policy = policyMap.get(pkg.Id);
                if (policy != null) {
                    dto.sortOrder = policy.Policy_Priority__c != null ? policy.Policy_Priority__c.intValue() : 0;
                    String pricingType = determinePackagePricingType(policy);
                    dto.pricingType = pricingType;
                    if (pricingType == 'percentage') {
                        dto.percentage = policy.Relatieve_prijs__c;
                        dto.price_flat = null;
                        dto.price_per_m2 = null;
                    } else if (pricingType == 'flat') {
                        dto.price_flat = policy.Eenheidsprijs__c;
                        dto.percentage = null;
                        dto.price_per_m2 = null;
                    } else {
                        dto.price_per_m2 = policy.Eenheidsprijs__c;
                        dto.percentage = null;
                        dto.price_flat = null;
                    }
                } else {
                    System.debug('⚠️ No active pricing policy found for package ' + pkg.ProductCode);
                }

                packages.add(dto);
            }

            packages.sort();
        } catch (Exception e) {
            System.debug('Error loading packages: ' + e.getMessage());
            return new List<PackageLineDTO>();
        }

        return packages;
    }

    private static String determinePackagePricingType(Prijsmanagement__c policy) {
        if (policy == null) {
            return null;
        }

        String rawType = policy.Price_Type__c != null ? policy.Price_Type__c.toLowerCase() : '';
        if (rawType.contains('flat')) {
            return 'flat';
        }
        if (rawType.contains('percentage')) {
            return 'percentage';
        }
        if (policy.Relatieve_prijs__c != null && policy.Relatieve_prijs__c > 0) {
            return 'percentage';
        }
        return 'per_m2';
    }

    private static String resolveSiteIdentifier(PriceRequest request) {
        if (request != null && !String.isBlank(request.siteId)) {
            return request.siteId;
        }
        return 'CincoCleaning';
    }
    
    // Haalt bundle discount regels op voor een segment
    private static List<BundleDiscountRule> getBundleDiscountRulesForSegment(String segment) {
        System.debug('🎁 Loading bundle discount rules for segment: ' + segment);
        
        List<BundleDiscountRule> bundleRules = new List<BundleDiscountRule>();
        
        try {
            // Query Bundle_Discount__mdt records for the specified segment
            List<Bundle_Discount__mdt> discountRules = [
                SELECT Label, DeveloperName, Min_Count__c, Discount_Percent__c, 
                       Segment__c, Active__c, Min_Aantal_Threshold__c
                FROM Bundle_Discount__mdt
                WHERE Segment__c = :segment
                  AND Active__c = true
                ORDER BY Min_Count__c ASC
            ];
            
            System.debug('🎁 Found ' + discountRules.size() + ' bundle discount rules for segment: ' + segment);
            
            for (Bundle_Discount__mdt rule : discountRules) {
                BundleDiscountRule bundleRule = new BundleDiscountRule();
                bundleRule.label = rule.Label;
                bundleRule.bundleName = rule.DeveloperName;
                bundleRule.minCount = Integer.valueOf(rule.Min_Count__c);
                bundleRule.discountPercent = rule.Discount_Percent__c;
                bundleRule.segment = rule.Segment__c;
                bundleRule.active = rule.Active__c;
                bundleRule.minAantalThreshold = rule.Min_Aantal_Threshold__c;
                
                bundleRules.add(bundleRule);
                
                System.debug('🎁 Bundle rule: ' + rule.Label + 
                            ' - Min Count: ' + rule.Min_Count__c + 
                            ' - Discount: ' + (rule.Discount_Percent__c * 100) + '%' +
                            ' - Min Aantal: ' + rule.Min_Aantal_Threshold__c);
            }
            
        } catch (Exception e) {
            System.debug('Error loading bundle discount rules: ' + e.getMessage());
            // Return empty list instead of failing
            return new List<BundleDiscountRule>();
        }
        
        return bundleRules;
    }
    
    // Converteert de web-aanvraag naar SObjects voor de PricingService
    private static List<Lead_Product__c> convertRequestToLeadProducts(PriceRequest request) {
        List<Lead_Product__c> leadProducts = new List<Lead_Product__c>();
        
        try {
            // Create temporary Lead for context
            Id tempLeadId = generateTempId(Lead.SObjectType);
            
            // Resolve product codes to Product2 IDs
            Set<String> allProductCodes = new Set<String>();
            for (RequestLine line : request.products) {
                allProductCodes.add(line.productCode);
                if (String.isNotBlank(line.relatedProductCode)) {
                    allProductCodes.add(line.relatedProductCode);
                }
            }
            
            Map<String, Id> codeToIdMap = resolveProductCodes(allProductCodes);
            System.debug('Resolved ' + codeToIdMap.size() + ' product codes');
            
            // Convert each request line to Lead_Product__c
            for (RequestLine line : request.products) {
                Id productId = codeToIdMap.get(line.productCode);
                if (productId == null) {
                    System.debug('Warning: Could not resolve product code: ' + line.productCode);
                    continue;
                }
                
                Lead_Product__c tempProduct = new Lead_Product__c();
                tempProduct.Id = generateTempId(Lead_Product__c.SObjectType);
                tempProduct.Lead__c = tempLeadId;
                tempProduct.Product__c = productId;
                tempProduct.Aantal__c = line.quantity != null ? line.quantity : 1;
                
                // Set dimensions
                if (line.lengthCm != null) {
                    tempProduct.Lengte_cm__c = line.lengthCm;
                }
                if (line.widthCm != null) {
                    tempProduct.Breedte_cm__c = line.widthCm;
                }
                if (line.diameterCm != null) {
                    tempProduct.Diameter_cm__c = line.diameterCm;
                }
                if (line.oppervlakteM2 != null) {
                    tempProduct.Oppervlakte_m__c = line.oppervlakteM2;
                }
                
                // Handle related product relationship
                if (String.isNotBlank(line.relatedProductCode)) {
                    Id relatedProductId = codeToIdMap.get(line.relatedProductCode);
                    if (relatedProductId != null) {
                        tempProduct.Gerelateerd_Product__c = relatedProductId;
                    }
                }
                
                leadProducts.add(tempProduct);
            }
            
        } catch (Exception e) {
            System.debug('Error converting request to Lead_Product__c: ' + e.getMessage());
        }
        
        return leadProducts;
    }
    
    // Resolve product codes to Product2 IDs
    private static Map<String, Id> resolveProductCodes(Set<String> productCodes) {
        Map<String, Id> codeMap = new Map<String, Id>();
        
        if (productCodes.isEmpty()) {
            return codeMap;
        }
        
        try {
            List<Product2> products = [
                SELECT Id, ProductCode
                FROM Product2
                WHERE ProductCode IN :productCodes
                  AND IsActive = true
            ];
            
            for (Product2 product : products) {
                codeMap.put(product.ProductCode, product.Id);
            }
            
        } catch (Exception e) {
            System.debug('Error resolving product codes: ' + e.getMessage());
        }
        
        return codeMap;
    }
    
    // Formatteert de berekende regels voor het JSON-antwoord
    private static List<ResponseLine> formatLinesForResponse(List<SObject> records) {
        List<ResponseLine> responseLines = new List<ResponseLine>();
        
        try {
            // Load Product2 data for name resolution
            Set<Id> productIds = new Set<Id>();
            for (SObject record : records) {
                Lead_Product__c lp = (Lead_Product__c) record;
                if (lp.Product__c != null) {
                    productIds.add(lp.Product__c);
                }
                if (lp.Gerelateerd_Product__c != null) {
                    productIds.add(lp.Gerelateerd_Product__c);
                }
            }
            
            Map<Id, Product2> productMap = new Map<Id, Product2>();
            if (!productIds.isEmpty()) {
                productMap = new Map<Id, Product2>([
                    SELECT Id, Name, ProductCode, Primaryproduct__c
                    FROM Product2
                    WHERE Id IN :productIds
                ]);
            }
            
            // Convert each calculated line
            for (SObject record : records) {
                Lead_Product__c lp = (Lead_Product__c) record;
                ResponseLine respLine = new ResponseLine();
                
                Product2 product = productMap.get(lp.Product__c);
                if (product != null) {
                    respLine.productCode = product.ProductCode;
                    respLine.productName = product.Name;
                    respLine.isPrimary = product.Primaryproduct__c;
                }
                
                respLine.quantity = lp.Aantal__c;
                respLine.oppervlakte = lp.Oppervlakte_m__c;
                respLine.verkoopprijs = lp.Verkoopprijs__c;
                respLine.totalePrijs = lp.Totale_Prijs__c; // Gross amount
                respLine.kortingPercentage = lp.Korting__c;
                respLine.kortingBedrag = lp.Korting_bedrag__c;
                respLine.regioToeslagPercentage = lp.Regiotoeslag__c;
                
                // Calculate net amount (after discount, before BTW)
                Decimal netAmount = respLine.totalePrijs != null ? respLine.totalePrijs : 0;
                if (respLine.kortingBedrag != null) {
                    netAmount = netAmount - respLine.kortingBedrag;
                }
                respLine.nettoTotaal = netAmount;
                
                // Calculate BTW using the rate written by PricingService on the Lead Product (fallback 21)
                Decimal btwRate = (lp.BTW__c != null) ? lp.BTW__c : 21;
                respLine.btwBedrag = (netAmount * btwRate / 100).setScale(2, RoundingMode.HALF_UP);
                respLine.totaalIncBtw = netAmount + respLine.btwBedrag;
                
                // Handle related product
                if (lp.Gerelateerd_Product__c != null) {
                    Product2 relatedProduct = productMap.get(lp.Gerelateerd_Product__c);
                    if (relatedProduct != null) {
                        respLine.relatedProductCode = relatedProduct.ProductCode;
                    }
                }
                
                responseLines.add(respLine);
            }
            
        } catch (Exception e) {
            System.debug('Error formatting response lines: ' + e.getMessage());
        }
        
        return responseLines;
    }
    
    // Berekent de totalen voor het JSON-antwoord
    private static void calculateTotals(List<SObject> records, PriceResponse response) {
        Decimal subTotaal = 0;
        Decimal totalKortingBedrag = 0;
        Decimal regioToeslagBedrag = 0;
    Decimal btwTotaal = 0;
        
        try {
            for (SObject record : records) {
                Lead_Product__c lp = (Lead_Product__c) record;
                
                // Add to subtotal (gross amount before discount)
                if (lp.Totale_Prijs__c != null) {
                    subTotaal += lp.Totale_Prijs__c;
                }
                
                // Add discount amount
                if (lp.Korting_bedrag__c != null) {
                    totalKortingBedrag += lp.Korting_bedrag__c;
                }
                
                // Calculate regional surcharge amount (if needed for display)
                if (lp.Regiotoeslag__c != null && lp.Regiotoeslag__c > 0 && lp.Verkoopprijs__c != null && lp.Aantal__c != null) {
                    Decimal baseAmount = lp.Verkoopprijs__c * lp.Aantal__c;
                    Decimal surchargeAmount = baseAmount * (lp.Regiotoeslag__c / 100);
                    regioToeslagBedrag += surchargeAmount;
                }
            }
            
            // Calculate totals based on per-line rounding to avoid 1-2 cent discrepancies
            Decimal netTotaal = 0;
            for (SObject record2 : records) {
                Lead_Product__c lp2 = (Lead_Product__c) record2;
                Decimal gross = lp2.Totale_Prijs__c != null ? lp2.Totale_Prijs__c : 0;
                Decimal discount = lp2.Korting_bedrag__c != null ? lp2.Korting_bedrag__c : 0;
                Decimal netLine = gross - discount;
                netTotaal += netLine;

                Decimal lineBtwRate = (lp2.BTW__c != null) ? lp2.BTW__c : 21;
                Decimal lineBtw = (netLine * lineBtwRate / 100).setScale(2, RoundingMode.HALF_UP);
                btwTotaal += lineBtw;
            }
            
            // Set response totals
            response.subTotaal = subTotaal.setScale(2, RoundingMode.HALF_UP);
            response.totalKortingBedrag = totalKortingBedrag.setScale(2, RoundingMode.HALF_UP);
            response.regioToeslagBedrag = regioToeslagBedrag.setScale(2, RoundingMode.HALF_UP);
            response.btwTotaal = btwTotaal.setScale(2, RoundingMode.HALF_UP);
            response.eindTotaal = (netTotaal + btwTotaal).setScale(2, RoundingMode.HALF_UP);
            
            // Determine applied bundle discount (could be enhanced)
            if (totalKortingBedrag > 0) {
                Decimal avgDiscountRate = (totalKortingBedrag / subTotaal) * 100;
                if (avgDiscountRate >= 14.5) {
                    response.appliedBundleDiscount = '15% Bundelkorting (4+ items)';
                } else if (avgDiscountRate >= 9.5) {
                    response.appliedBundleDiscount = '10% Bundelkorting (3+ items)';
                } else if (avgDiscountRate >= 4.5) {
                    response.appliedBundleDiscount = '5% Bundelkorting (2+ items)';
                }
            }
            
            System.debug('Totals calculated - Subtotal: €' + response.subTotaal + 
                        ', Discount: €' + response.totalKortingBedrag + 
                        ', BTW: €' + response.btwTotaal + 
                        ', Final: €' + response.eindTotaal);
            
        } catch (Exception e) {
            System.debug('Error calculating totals: ' + e.getMessage());
            // Set default values on error
            response.subTotaal = 0;
            response.totalKortingBedrag = 0;
            response.regioToeslagBedrag = 0;
            response.btwTotaal = 0;
            response.eindTotaal = 0;
        }
    }
    
    // Utility methods
    private static PriceResponse createErrorResponse(String message) {
        PriceResponse response = new PriceResponse();
        response.success = false;
        response.errorMessage = message;
        response.calculationId = generateCalculationId();
        return response;
    }
    
    private static String generateCalculationId() {
        return 'CALC_' + DateTime.now().format('yyyyMMdd_HHmmss') + '_' + 
               String.valueOf(Math.round(Math.random() * 10000)).leftPad(4, '0');
    }
    
    private static Id generateTempId(SObjectType sObjType) {
        String keyPrefix = sObjType.getDescribe().getKeyPrefix();
        String fakeIdPrefix = keyPrefix + '0'.repeat(12 - keyPrefix.length());
        String randomSuffix = String.valueOf(Math.round(Math.random() * 1000000)).leftPad(3, '0');
        return Id.valueOf(fakeIdPrefix + randomSuffix);
    }
}