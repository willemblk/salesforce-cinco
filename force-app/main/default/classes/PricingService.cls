public class PricingService {

    // Constants for magic strings and numbers
    private static final String FLOOR_CARPET_PREFIX = 'VLRK-';

    // NEW: Price Type Constants for new pricing model
    private static final String PRICE_TYPE_NORMAAL = 'Normaal';
    private static final String PRICE_TYPE_STAFFEL_CUMULATIEF = 'Staffel Cumulatief';
    private static final String PRICE_TYPE_STAFFEL_TREDE = 'Staffel Trede';
    private static final String PRICE_TYPE_FLAT_FEE = 'Flat Fee';

    // Cache for bundle discount rules (populated on first use)
    private static List<Bundle_Discount__mdt> bundleDiscountRules;

    // NEW: Enhanced Generic Pricing Wrapper for unified processing
    private class GenericPricingLine {
        // Source data
        public SObject sourceRecord { get; set; }
        public String objectType { get; set; }
        
        // Core identification
        public Id lineId { get; set; }
        public Id parentId { get; set; }
        public Id productId { get; set; }
        
        // Product information (loaded from Product2)
        public String productCode { get; set; }
        public String productSegment { get; set; } // For bundle discount logic
        public String btw { get; set; }
        public Boolean isPrimary { get; set; }
        public Boolean needsAreaCalculation { get; set; }
        public Boolean isBundleEligible { get; set; }
        
        // Quantity fields
        public Decimal aantal { get; set; }
        public Decimal lengthCm { get; set; }
        public Decimal widthCm { get; set; }
        public Decimal diameterCm { get; set; }
        public Decimal oppervlakte { get; set; }
        
        // Relationships
        public Id gerelateerProductId { get; set; }
        public Decimal relatiefPrijsPercentage { get; set; }  // Field-level override
        
        // Pricing policy (from Prijsmanagement__c)
        public Decimal eenheidsprijs { get; set; }
        public Decimal relatiefPercentage { get; set; }  // Policy-level percentage
        public Decimal minimaleprijs { get; set; }
        public String priceType { get; set; }
        public Boolean regioToeslagToepasbaar { get; set; }
        public List<Prijsstaffel__c> staffels { get; set; }
        
        // Calculation results
        public Decimal unitPriceExBtw { get; set; }      // Verkoopprijs__c (final unit price)
        public Decimal lineAmountExBtw { get; set; }     // Totale_Prijs__c
    public Decimal lineAmountBeforeDiscountExBtw { get; set; } // Snapshot before bundle/minimum
        public Decimal btwBedrag { get; set; }           // BTW_Bedrag__c
        public Decimal lineAmountIncBtw { get; set; }    // Totaal_incl_BTW__c
        public Decimal kortingPercentage { get; set; }   // Bundle discount %
        public Decimal kortingBedrag { get; set; }       // Bundle discount amount
        public Decimal regioToeslagPercentage { get; set; }  // Regional surcharge %
    public Decimal associationMinimumExBtw { get; set; } // Order-level minimum per postcode+segment
        
        // Constructor for different object types
        public GenericPricingLine(SObject record) {
            this.sourceRecord = record;
            this.staffels = new List<Prijsstaffel__c>();
            
            // Determine object type and map fields
            if (record instanceof Lead_Product__c) {
                mapFromLeadProduct((Lead_Product__c) record);
            } else if (record instanceof OpportunityLineItem) {
                mapFromOpportunityLineItem((OpportunityLineItem) record);
            } else if (record instanceof Wasserij_Item__c) {
                mapFromWasserijItem((Wasserij_Item__c) record);
            }
        }
        
        private void mapFromLeadProduct(Lead_Product__c lp) {
            this.objectType = 'Lead_Product__c';
            this.lineId = lp.Id;
            this.parentId = lp.Lead__c;
            this.productId = lp.Product__c;
            this.aantal = lp.Aantal__c;
            this.lengthCm = lp.Lengte_cm__c;
            this.widthCm = lp.Breedte_cm__c;
            this.diameterCm = lp.Diameter_cm__c;
            this.oppervlakte = lp.Oppervlakte_m__c;
            this.gerelateerProductId = lp.Gerelateerd_Product__c;
            // Note: Relatieve_Prijs__c field would need to be added to Lead_Product__c
            // this.relatiefPrijsPercentage = lp.Relatieve_Prijs__c;
        }
        
        private void mapFromOpportunityLineItem(OpportunityLineItem oli) {
            this.objectType = 'OpportunityLineItem';
            this.lineId = oli.Id;
            this.parentId = oli.OpportunityId;
            this.productId = oli.Product2Id;
            this.aantal = oli.Quantity;
            this.lengthCm = oli.Lengte_cm__c;
            this.widthCm = oli.Breedte_cm__c;
            this.diameterCm = oli.Diameter_cm__c;
            this.oppervlakte = oli.Oppervlakte_m__c;
            this.gerelateerProductId = oli.Gerelateerd_Product__c;
            this.relatiefPrijsPercentage = oli.Relatieve_Prijs__c;
        }
        
        private void mapFromWasserijItem(Wasserij_Item__c wi) {
            this.objectType = 'Wasserij_Item__c';
            this.lineId = wi.Id;
            this.parentId = wi.Werk_Order__c;
            this.productId = wi.Product__c;
            this.aantal = wi.Aantal__c;
            this.lengthCm = wi.Lengte__c;
            this.widthCm = wi.Breedte__c;
            this.diameterCm = wi.Diameter__c;
            this.oppervlakte = wi.Oppervlakte_m__c;
            this.gerelateerProductId = wi.Gerelateerd_Wasserij_Item__c;
            // Note: Relatieve_Prijs__c field would need to be added to Wasserij_Item__c
            // this.relatiefPrijsPercentage = wi.Relatieve_Prijs__c;
        }
        
        // Write results back to source record
        public void writeBackToSource() {
            if (sourceRecord instanceof Lead_Product__c) {
                writeToLeadProduct((Lead_Product__c) sourceRecord);
            } else if (sourceRecord instanceof OpportunityLineItem) {
                writeToOpportunityLineItem((OpportunityLineItem) sourceRecord);
            } else if (sourceRecord instanceof Wasserij_Item__c) {
                writeToWasserijItem((Wasserij_Item__c) sourceRecord);
            }
        }
        
        private void writeToLeadProduct(Lead_Product__c lp) {
            lp.Aantal__c = this.aantal;
            lp.Oppervlakte_m__c = this.oppervlakte;
            lp.Verkoopprijs__c = this.unitPriceExBtw;
            lp.Regiotoeslag__c = this.regioToeslagPercentage;
            
            // Write BTW percentage (Percent field expects 21, not 0.21)
            if (String.isNotBlank(this.btw)) {
                try {
                    lp.BTW__c = Decimal.valueOf(this.btw); // "21" → 21 for Percent field
                } catch (Exception e) {
                    System.debug('⚠️ Could not parse BTW value: ' + this.btw);
                    lp.BTW__c = 21; // Fallback to 21%
                }
            }
            
            // BTW_Bedrag__c and Totaal_incl_BTW__c are formula fields and calculated automatically
            
            // Sla het kortingsbedrag op zoals het nu is
            if (this.kortingPercentage != null) {
                lp.Korting__c = this.kortingPercentage;
                lp.Korting_bedrag__c = this.kortingBedrag;
            }

            // Reconstructueer de bruto totaalprijs voor opslag in Totale_Prijs__c
            // Dit is het netto bedrag PLUS de berekende korting.
            if (this.kortingBedrag != null && this.kortingBedrag > 0) {
                lp.Totale_Prijs__c = this.lineAmountExBtw + this.kortingBedrag;
            } else {
                lp.Totale_Prijs__c = this.lineAmountExBtw;
            }
        }
        
        private void writeToOpportunityLineItem(OpportunityLineItem oli) {
            oli.Quantity = this.aantal;
            oli.Oppervlakte_m__c = this.oppervlakte;
            
            // Reconstructueer de bruto totaalprijs
            Decimal brutoTotalPrice = this.lineAmountExBtw;
            if (this.kortingBedrag != null && this.kortingBedrag > 0) {
                brutoTotalPrice += this.kortingBedrag;
            }

            // Stel de UnitPrice in op een manier die Salesforce correct laat rekenen
            // Salesforce berekent TotalPrice zelf als UnitPrice * Quantity.
            // We moeten dus de UnitPrice correct instellen.
            if (oli.Quantity != null && oli.Quantity > 0) {
                oli.UnitPrice = brutoTotalPrice / oli.Quantity;
            } else {
                oli.UnitPrice = this.unitPriceExBtw; // Fallback
            }
            // Salesforce vult nu automatisch oli.TotalPrice met de correcte bruto waarde.
            
            oli.Regiotoeslag__c = this.regioToeslagPercentage;

            // Bundelkorting wegschrijven zodat OLI dezelfde rapportage toont als LP/WI
            if (this.kortingPercentage != null) {
                try {
                    oli.Discount = this.kortingPercentage; // Verwacht percentage (bijv. 5 voor 5%)
                } catch (Exception e) {
                    System.debug('⚠️ Kon Discount niet schrijven op OLI: ' + e.getMessage());
                }
                oli.Korting_bedrag__c = this.kortingBedrag; // Valuta: het berekende kortingsbedrag
                System.debug('💰 Bundelkorting toegepast op OLI: ' + this.kortingPercentage + '% | bedrag €' + this.kortingBedrag);
            }

            // Schrijf BTW-gegevens expliciet weg zodat Opportunity rapportages dezelfde waarden tonen als Leads/Werkorders.
            Decimal netLineAmount = this.lineAmountExBtw != null ? this.lineAmountExBtw : 0;
            Decimal parsedBtw = null;

            if (String.isNotBlank(this.btw)) {
                try {
                    parsedBtw = Decimal.valueOf(this.btw);
                } catch (Exception e) {
                    System.debug('⚠️ Could not parse BTW value for OpportunityLineItem: ' + this.btw);
                    parsedBtw = 21; // Fallback consistent met Lead/Wasserij
                }
            }

            oli.BTW__c = parsedBtw;

            Decimal btwPercentageForCalc = parsedBtw != null ? parsedBtw : 0;
            Decimal btwAmount = (netLineAmount * btwPercentageForCalc) / 100;
            // BTW_Bedrag__c and Totaal_incl_BTW__c are formula fields on OpportunityLineItem; do not write them explicitly
            System.debug('✅ OLI BTW set to ' + oli.BTW__c + '%. Formulevelden bepalen BTW_Bedrag__c en Totaal_incl_BTW__c automatisch.');

            // Houd interne state in sync voor eventuele downstream logica
            this.btwBedrag = btwAmount;
            this.lineAmountIncBtw = netLineAmount + btwAmount;
        }
        
        private void writeToWasserijItem(Wasserij_Item__c wi) {
            wi.Aantal__c = this.aantal;
            wi.Oppervlakte_m__c = this.oppervlakte;
            wi.Verkoopprijs__c = this.unitPriceExBtw;
            wi.Regiotoeslag__c = this.regioToeslagPercentage;
            
            // Write BTW percentage (Percent field expects 21, not 0.21)
            if (String.isNotBlank(this.btw)) {
                try {
                    wi.BTW__c = Decimal.valueOf(this.btw); // "21" → 21 for Percent field
                } catch (Exception e) {
                    System.debug('⚠️ Could not parse BTW value: ' + this.btw);
                    wi.BTW__c = 21; // Fallback to 21%
                }
            }
            
            // BTW_Bedrag__c and Totaal_incl_BTW__c are formula fields and calculated automatically
            
            // Sla het kortingsbedrag op zoals het nu is
            if (this.kortingPercentage != null) {
                wi.Korting__c = this.kortingPercentage;
                wi.Korting_bedrag__c = this.kortingBedrag;
            }

            // Reconstructueer de bruto totaalprijs voor opslag in Totale_Prijs__c
            if (this.kortingBedrag != null && this.kortingBedrag > 0) {
                wi.Totale_Prijs__c = this.lineAmountExBtw + this.kortingBedrag;
            } else {
                wi.Totale_Prijs__c = this.lineAmountExBtw;
            }
        }
    }

    // =============================================================================
    // NEW CENTRAL PRICING ENGINE - Single Entry Point
    // =============================================================================
    
    /**
     * Central repricing method - accepts any list of line objects and reprices them
     * This is the new single entry point for all pricing calculations
     */
    public static List<SObject> reprice(List<SObject> lines) {
        if (lines == null || lines.isEmpty()) {
            return lines;
        }
        
        System.debug('=== NEW PRICING ENGINE START ===');
        System.debug('Processing ' + lines.size() + ' lines');
        
        // Step 1: Convert to generic pricing lines
        List<GenericPricingLine> pricingLines = new List<GenericPricingLine>();
        for (SObject line : lines) {
            pricingLines.add(new GenericPricingLine(line));
        }
        
        // Step 2: Load context (policies, staffels, products, regional surcharges)
        loadPricingContext(pricingLines);
        
        // Step 3: Group primaries and extras
        Map<String, List<GenericPricingLine>> primaryGroups = groupPrimariesAndExtras(pricingLines);
        
        // Step 4: Calculate pricing using deterministic order
        calculatePricingDeterministic(pricingLines, primaryGroups);
        
        // Step 5: Write results back to source records
        for (GenericPricingLine pricingLine : pricingLines) {
            pricingLine.writeBackToSource();
        }
        
        System.debug('=== NEW PRICING ENGINE END ===');
        
        return lines;
    }
    
    /**
     * Context-aware repricing methods for Flow integration
     */
    public static List<SObject> repriceLead(Id leadId) {
        List<Lead_Product__c> lines = [
            SELECT Id, Lead__c, Product__c, Product__r.ProductCode, Product__r.BTW__c, Product__r.Primaryproduct__c,
                   Aantal__c, Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, Oppervlakte_m__c,
                   Gerelateerd_Product__c, Verkoopprijs__c, Totale_Prijs__c, Korting__c
            FROM Lead_Product__c 
            WHERE Lead__c = :leadId
        ];
        return reprice(lines);
    }
    
    public static List<SObject> repriceOpportunity(Id opportunityId) {
        List<OpportunityLineItem> lines = [
            SELECT Id, OpportunityId, Product2Id, Product2.ProductCode, Product2.BTW__c, Product2.Primaryproduct__c,
                   Quantity, Lengte_cm__c, Breedte_cm__c, Diameter_cm__c, Oppervlakte_m__c,
                   Gerelateerd_Product__c, UnitPrice, Relatieve_Prijs__c
            FROM OpportunityLineItem 
            WHERE OpportunityId = :opportunityId
        ];
        return reprice(lines);
    }
    
    public static List<SObject> repriceWerkorder(Id werkOrderId) {
        List<Wasserij_Item__c> lines = [
            SELECT Id, Werk_Order__c, Product__c, Product__r.ProductCode, Product__r.BTW__c, Product__r.Primaryproduct__c,
                   Aantal__c, Lengte__c, Breedte__c, Diameter__c, Oppervlakte_m__c,
                   Gerelateerd_Wasserij_Item__c, Verkoopprijs__c, Totale_Prijs__c, Korting__c, Korting_bedrag__c
            FROM Wasserij_Item__c 
            WHERE Werk_Order__c = :werkOrderId
        ];
        return reprice(lines);
    }

    // =============================================================================
    // NEW PRICING CALCULATION METHODS - Private Implementation
    // =============================================================================
    
    private static void loadPricingContext(List<GenericPricingLine> pricingLines) {
        System.debug('=== LOADING PRICING CONTEXT ===');
        System.debug('Loading context for ' + pricingLines.size() + ' pricing lines');
        
        // Collect product IDs
        Set<Id> productIds = new Set<Id>();
        Set<Id> parentIds = new Set<Id>();
        for (GenericPricingLine line : pricingLines) {
            if (line.productId != null) {
                productIds.add(line.productId);
            }
            if (line.parentId != null) {
                parentIds.add(line.parentId);
            }
        }
        
        System.debug('Found ' + productIds.size() + ' unique products and ' + parentIds.size() + ' unique parents');
        
        // Load Product2 data
        Map<Id, Product2> productMap = new Map<Id, Product2>();
        if (!productIds.isEmpty()) {
            try {
                productMap = new Map<Id, Product2>([
                    SELECT Id, ProductCode, BTW__c, Primaryproduct__c, Segment__c, Oppervlakte_Berekening_Nodig__c, Bundelkorting_Toepasbaar__c
                    FROM Product2 
                    WHERE Id IN :productIds
                ]);
                System.debug('Loaded ' + productMap.size() + ' Product2 records');
            } catch (Exception e) {
                System.debug('Error loading Product2 data: ' + e.getMessage());
            }
        }
        
        // Load active policies with enhanced selection logic
        Map<Id, Prijsmanagement__c> policyMap = new Map<Id, Prijsmanagement__c>();
        if (!productIds.isEmpty()) {
            try {
                List<Prijsmanagement__c> policies = [
                    SELECT Id, Product__c, Eenheidsprijs__c, Relatieve_prijs__c, Minimale_prijs__c,
                           Price_Type__c, Segment__c, Regiotoeslag_toepasbaar__c,
                           Geldig_vanaf__c, Geldig_tot__c, Policy_Priority__c
                    FROM Prijsmanagement__c 
                    WHERE Product__c IN :productIds
                    AND Geldig_vanaf__c <= TODAY
                    AND (Geldig_tot__c >= TODAY OR Geldig_tot__c = null)
                    AND Actief__c = true
                    ORDER BY Product__c, Policy_Priority__c ASC NULLS LAST, Geldig_vanaf__c DESC
                ];
                
                System.debug('Found ' + policies.size() + ' active pricing policies');
                
                // Map policies to products (take first/highest priority per product)
                for (Prijsmanagement__c policy : policies) {
                    if (!policyMap.containsKey(policy.Product__c)) {
                        policyMap.put(policy.Product__c, policy);
                        System.debug('Selected policy for product ' + policy.Product__c + ': Type=' + policy.Price_Type__c + 
                                   ', Price=€' + policy.Eenheidsprijs__c + ', MinPrice=€' + policy.Minimale_prijs__c);
                    } else {
                        System.debug('Skipped lower priority policy for product ' + policy.Product__c);
                    }
                }
            } catch (Exception e) {
                System.debug('Error loading pricing policies: ' + e.getMessage());
            }
        }
        
        // Load staffels for policies that need them
        Map<Id, List<Prijsstaffel__c>> staffelMap = new Map<Id, List<Prijsstaffel__c>>();
        Set<Id> policyIds = new Set<Id>();
        for (Prijsmanagement__c policy : policyMap.values()) {
            System.debug('STAFFEL CHECK - Policy ' + policy.Id + ' has Price_Type: "' + policy.Price_Type__c + '"');
            if (policy.Price_Type__c == PRICE_TYPE_STAFFEL_CUMULATIEF || 
                policy.Price_Type__c == PRICE_TYPE_STAFFEL_TREDE) {
                policyIds.add(policy.Id);
                System.debug('✅ Added policy ' + policy.Id + ' to staffel loading list');
            } else {
                System.debug('❌ Policy ' + policy.Id + ' does NOT match staffel types');
            }
        }
        
        System.debug('STAFFEL LOADING - Will load staffels for ' + policyIds.size() + ' policies: ' + policyIds);
        
        if (!policyIds.isEmpty()) {
            try {
                List<Prijsstaffel__c> staffels = [
                    SELECT Id, Prijsmanagement__c, Ondergrens__c, Bovengrens__c, Eenheidsprijs__c, Vaste_Prijs__c
                    FROM Prijsstaffel__c 
                    WHERE Prijsmanagement__c IN :policyIds
                    ORDER BY Prijsmanagement__c, Ondergrens__c ASC
                ];
                
                System.debug('Loaded ' + staffels.size() + ' staffel records for ' + policyIds.size() + ' policies');
                
                for (Prijsstaffel__c staffel : staffels) {
                    if (!staffelMap.containsKey(staffel.Prijsmanagement__c)) {
                        staffelMap.put(staffel.Prijsmanagement__c, new List<Prijsstaffel__c>());
                    }
                    staffelMap.get(staffel.Prijsmanagement__c).add(staffel);
                }
                
                // Debug staffel configurations
                for (Id policyId : staffelMap.keySet()) {
                    List<Prijsstaffel__c> policyStaffels = staffelMap.get(policyId);
                    System.debug('Policy ' + policyId + ' has ' + policyStaffels.size() + ' staffel tiers');
                    for (Prijsstaffel__c staffel : policyStaffels) {
                        System.debug('  Tier: ' + staffel.Ondergrens__c + '-' + 
                                   (staffel.Bovengrens__c != null ? String.valueOf(staffel.Bovengrens__c) : '∞') + 
                                   ' = €' + staffel.Eenheidsprijs__c);
                    }
                }
            } catch (Exception e) {
                System.debug('Error loading staffel data: ' + e.getMessage());
            }
        }
        
    // NEW: Load Regional Surcharges
    Map<Id, Decimal> regionalSurchargeMap = getRegionalSurcharges(pricingLines);

    // NEW: Load order-level minimums from Dienstgebied_Postcode_Associatie__c
    Map<Id, Decimal> associationMinimumMap = getAssociationOrderMinimums(pricingLines);
        
        // Apply loaded data to pricing lines
        Integer linesWithPolicies = 0;
        Integer linesWithProducts = 0;
        for (GenericPricingLine line : pricingLines) {
            // Apply product data
            Product2 product = productMap.get(line.productId);
            if (product != null) {
                line.productCode = product.ProductCode;
                line.productSegment = product.Segment__c;  // NEW: For bundle discount optimization
                line.btw = product.BTW__c;
                line.isPrimary = product.Primaryproduct__c;
                line.needsAreaCalculation = product.Oppervlakte_Berekening_Nodig__c;
                line.isBundleEligible = product.Bundelkorting_Toepasbaar__c;
                
                // Handle related product logic if needed
                // Note: These fields would need to be added to Product2:
                // if (product.Type__c == PRIMARY_PRODUCT_TYPE) {
                //     line.isPrimary = true;
                // }
                // if (product.Gerelateerd_Product__c != null) {
                //     line.gerelateerProductId = product.Gerelateerd_Product__c;
                //     line.relatiefPrijsPercentage = product.Relatief_Prijs_Percentage__c;
                // }
                
                linesWithProducts++;
            } else {
                System.debug('Warning: No Product2 data found for product ' + line.productId);
            }
            
            // Apply policy data
            Prijsmanagement__c policy = policyMap.get(line.productId);
            if (policy != null) {
                line.eenheidsprijs = policy.Eenheidsprijs__c;
                line.relatiefPercentage = policy.Relatieve_prijs__c;
                line.minimaleprijs = policy.Minimale_prijs__c;
                line.priceType = policy.Price_Type__c != null ? policy.Price_Type__c : PRICE_TYPE_NORMAAL;
                line.regioToeslagToepasbaar = policy.Regiotoeslag_toepasbaar__c;
                
                // Apply staffels if needed
                List<Prijsstaffel__c> lineStaffels = staffelMap.get(policy.Id);
                System.debug('STAFFEL ASSIGNMENT - Policy ' + policy.Id + ' has ' + (lineStaffels != null ? lineStaffels.size() : 0) + ' staffels');
                if (lineStaffels != null) {
                    line.staffels = lineStaffels;
                    System.debug('✅ Assigned ' + lineStaffels.size() + ' staffels to line for product ' + line.productId);
                    for (Prijsstaffel__c s : lineStaffels) {
                        System.debug('    Staffel: ' + s.Ondergrens__c + '-' + s.Bovengrens__c + ' = €' + s.Eenheidsprijs__c);
                    }
                } else {
                    System.debug('❌ No staffels found for policy ' + policy.Id);
                }
                
                linesWithPolicies++;
            } else {
                System.debug('Warning: No active pricing policy found for product ' + line.productId);
            }
            
            // Apply regional surcharge percentage to the line
            if (regionalSurchargeMap.containsKey(line.parentId)) {
                line.regioToeslagPercentage = regionalSurchargeMap.get(line.parentId);
            } else {
                line.regioToeslagPercentage = 0; // Default to 0 if no surcharge is found
            }

            // Apply association-level minimum if available
            if (associationMinimumMap.containsKey(line.parentId)) {
                line.associationMinimumExBtw = associationMinimumMap.get(line.parentId);
            } else {
                line.associationMinimumExBtw = 0;
            }
            
            // Calculate area for floor carpets
            calculateAreaGeneric(line);
        }
        
        System.debug('Context application summary:');
        System.debug('  Lines with Product2 data: ' + linesWithProducts + '/' + pricingLines.size());
        System.debug('  Lines with pricing policies: ' + linesWithPolicies + '/' + pricingLines.size());
        System.debug('=== PRICING CONTEXT LOADED ===');
    }
    
    private static void calculateAreaGeneric(GenericPricingLine line) {
        if (line.needsAreaCalculation == true) {
            Decimal area = 0;
            Decimal length = line.lengthCm != null ? line.lengthCm : 0;
            Decimal width = line.widthCm != null ? line.widthCm : 0;
            Decimal diameter = line.diameterCm != null ? line.diameterCm : 0;

            if (length > 0 && width > 0) { 
                area = (length / 100) * (width / 100); 
            } else if (diameter > 0) {
                Decimal radius = diameter / 200;
                area = Math.PI * radius * radius;
            }
            
            if (area > 0) {
                line.oppervlakte = area.setScale(2);
                line.aantal = line.oppervlakte; // For carpets, quantity = area
            }
        }
    }
    
    private static Map<String, List<GenericPricingLine>> groupPrimariesAndExtras(List<GenericPricingLine> pricingLines) {
        System.debug('Grouping primaries and extras...');
        
        Map<String, List<GenericPricingLine>> primaryGroups = new Map<String, List<GenericPricingLine>>();
        List<GenericPricingLine> extras = new List<GenericPricingLine>();

        // Index primaries by both productId and lineId so extras can attach via either reference
        Map<Id, GenericPricingLine> primaryByProductId = new Map<Id, GenericPricingLine>();
        Map<Id, GenericPricingLine> primaryByLineId = new Map<Id, GenericPricingLine>();
        
        // First pass: identify primaries and group them
        for (GenericPricingLine line : pricingLines) {
            if (line.isPrimary == true || line.gerelateerProductId == null) {
                // This is a primary product
                String groupKey = line.parentId + '_' + line.productId;
                if (!primaryGroups.containsKey(groupKey)) {
                    primaryGroups.put(groupKey, new List<GenericPricingLine>());
                }
                primaryGroups.get(groupKey).add(line);
                // Index for later extra attachment
                if (line.productId != null) primaryByProductId.put(line.productId, line);
                if (line.lineId != null) primaryByLineId.put(line.lineId, line);
            } else {
                // This is an extra
                extras.add(line);
            }
        }
        
        // Second pass: attach extras to their primary groups
        for (GenericPricingLine extra : extras) {
            // Try to attach by related Product2 Id first
            String byProductKey = extra.parentId + '_' + extra.gerelateerProductId;
            if (!String.isBlank(byProductKey) && primaryGroups.containsKey(byProductKey)) {
                primaryGroups.get(byProductKey).add(extra);
                continue;
            }

            // If the related reference actually points to the primary LINE Id, resolve its product and attach accordingly
            GenericPricingLine relatedPrimaryByLine = primaryByLineId.get(extra.gerelateerProductId);
            if (relatedPrimaryByLine != null) {
                String key = extra.parentId + '_' + relatedPrimaryByLine.productId;
                if (!primaryGroups.containsKey(key)) {
                    primaryGroups.put(key, new List<GenericPricingLine>());
                }
                primaryGroups.get(key).add(extra);
                continue;
            }

            // Orphaned extra - create a separate group for it
            String orphanKey = 'ORPHAN_' + extra.lineId;
            primaryGroups.put(orphanKey, new List<GenericPricingLine> { extra });
        }
        
        System.debug('Created ' + primaryGroups.size() + ' primary groups');
        return primaryGroups;
    }
    
    private static void calculatePricingDeterministic(List<GenericPricingLine> allLines, Map<String, List<GenericPricingLine>> primaryGroups) {
        System.debug('Starting deterministic pricing calculation...');
        
        // Step 1: Calculate base pricing for each group
        for (String groupKey : primaryGroups.keySet()) {
            List<GenericPricingLine> groupLines = primaryGroups.get(groupKey);
            calculateGroupPricing(groupLines);
        }
        
        // Step 2: Apply bundle discounts (per parent)
        applyBundleDiscountsDeterministic(allLines);
        
        // Step 3: Apply minimum price per order
        applyMinimumPricePerOrder(allLines);
        
        // Step 4: Calculate BTW - TODO: Implement this method
        // calculateBTWForLines(allLines);
        
        System.debug('Deterministic pricing calculation completed');
    }
    
    private static void calculateGroupPricing(List<GenericPricingLine> groupLines) {
        if (groupLines == null || groupLines.isEmpty()) return;
        
        System.debug('Calculating group pricing for ' + groupLines.size() + ' lines');
        
        // Separate primaries and extras
        List<GenericPricingLine> primaries = new List<GenericPricingLine>();
        List<GenericPricingLine> extras = new List<GenericPricingLine>();
        
        for (GenericPricingLine line : groupLines) {
            if (line.isPrimary == true || line.gerelateerProductId == null) {
                primaries.add(line);
            } else {
                extras.add(line);
            }
        }
        
        // Calculate total volume for staffel calculations
        Decimal totalVolume = 0;
        for (GenericPricingLine primary : primaries) {
            if (primary.aantal != null) {
                totalVolume += primary.aantal;
            }
        }
        
        // Process each primary
        for (GenericPricingLine primary : primaries) {
            calculateLinePricing(primary, totalVolume);
        }
        
        // Process extras (based on their primary's final unit price)
        // Before pricing an extra, adjust its Aantal based on business rules and policy type
        for (GenericPricingLine extra : extras) {
            GenericPricingLine primaryLine = findPrimaryForExtra(extra, primaries);
            if (primaryLine != null) {
                // Business rule: when extra is related to a primary, adjust quantity based on Price_Type__c
                // - Normaal: mirror the primary's Aantal (only for non-relative extras)
                // - Flat Fee: force Aantal = 1
                try {
                    Boolean hasRelativePricing = (extra.relatiefPrijsPercentage != null && extra.relatiefPrijsPercentage > 0)
                                              || (extra.relatiefPercentage != null && extra.relatiefPercentage > 0);

                    if (extra.priceType == PRICE_TYPE_FLAT_FEE) {
                        // Flat fee extras are charged once
                        Decimal before = extra.aantal;
                        extra.aantal = 1;
                        System.debug('🔧 Extra qty adjusted for Flat Fee: before=' + before + ' → now=' + extra.aantal);
                    } else if (extra.priceType == PRICE_TYPE_NORMAAL && !hasRelativePricing) {
                        // Normal-priced extras follow the primary quantity
                        Decimal before = extra.aantal;
                        extra.aantal = (primaryLine != null ? (primaryLine.aantal != null ? primaryLine.aantal : 0) : 0);
                        System.debug('🔧 Extra qty mirrored from primary (Normaal): before=' + before + ' → now=' + extra.aantal + ' (primary=' + primaryLine.aantal + ')');
                    }
                } catch (Exception e) {
                    System.debug('⚠️ Could not adjust extra quantity: ' + e.getMessage());
                }
                calculateExtraPricing(extra, primaryLine);
            } else {
                // Orphaned extra - treat as normal product
                calculateLinePricing(extra, extra.aantal != null ? extra.aantal : 0);
            }
        }
    }
    
    private static void calculateLinePricing(GenericPricingLine line, Decimal totalVolume) {
        if (line.aantal == null || line.aantal <= 0) {
            System.debug('Line has no quantity - setting prices to 0');
            line.unitPriceExBtw = 0;
            line.lineAmountExBtw = 0;
            return;
        }
        
        System.debug('=== CALCULATING LINE PRICING ===');
        System.debug('Product: ' + line.productId + ' | Type: ' + line.priceType + ' | Qty: ' + line.aantal + ' | TotalVolume: ' + totalVolume);
        
        Decimal unitPrice = 0;
        
        if (line.priceType == PRICE_TYPE_STAFFEL_CUMULATIEF) {
            if (line.staffels != null && !line.staffels.isEmpty()) {
                // Zoek de juiste staffel op basis van het totale volume
                Prijsstaffel__c matchingTier = getMatchingStaffel(line.staffels, totalVolume);

                if (matchingTier != null) {
                    // NIEUWE LOGICA: Controleer eerst op een Vaste Prijs
                    if (matchingTier.Vaste_Prijs__c != null && matchingTier.Vaste_Prijs__c > 0) {

                        // Pas de vaste prijs direct toe op het totaalbedrag
                        line.lineAmountExBtw = matchingTier.Vaste_Prijs__c;
                        // Bereken de 'effectieve' eenheidsprijs voor weergave
                        unitPrice = (line.aantal > 0) ? line.lineAmountExBtw / line.aantal : 0;
                        System.debug('Staffel Cumulatief (Vaste Prijs): Totaalbedrag €' + line.lineAmountExBtw);

                    } else {
                        // OUDE LOGICA: Gebruik de eenheidsprijs
                        unitPrice = matchingTier.Eenheidsprijs__c != null ? matchingTier.Eenheidsprijs__c : 0;
                        System.debug('Staffel Cumulatief (Eenheidsprijs): Unit price €' + unitPrice);
                    }
                } else {
                    System.debug('Warning: Geen passende staffel gevonden - gebruik eenheidsprijs als fallback');
                    unitPrice = line.eenheidsprijs != null ? line.eenheidsprijs : 0;
                }
            } else {
                System.debug('Warning: Prijstype is Staffel Cumulatief maar er zijn geen staffels gevonden');
                unitPrice = line.eenheidsprijs != null ? line.eenheidsprijs : 0;
            }
        } else if (line.priceType == PRICE_TYPE_STAFFEL_TREDE) {
            // Staffel Trede: distribute quantity across tiers for this specific line
            if (line.staffels != null && !line.staffels.isEmpty()) {
                line.lineAmountExBtw = calculateStaffelTredeAmount(line.staffels, line.aantal);
                unitPrice = (line.aantal > 0) ? line.lineAmountExBtw / line.aantal : 0;
                System.debug('Staffel Trede: Line amount €' + line.lineAmountExBtw + ' | Effective unit price €' + unitPrice);
            } else {
                System.debug('Warning: Staffel Trede type but no staffels found - using eenheidsprijs');
                unitPrice = line.eenheidsprijs != null ? line.eenheidsprijs : 0;
            }
        } else {
            // Normal pricing - use eenheidsprijs directly
            unitPrice = line.eenheidsprijs != null ? line.eenheidsprijs : 0;
            System.debug('Normal pricing: Using eenheidsprijs €' + unitPrice);
        }
        
        // === START DIAGNOSE BLOK: REGIONAL SURCHARGE ===
        System.debug('REGIO DIAGNOSE voor Product ' + line.productId + ':');
        System.debug('  - Toeslag Toepasbaar (van Prijsmanagement__c)? -> ' + line.regioToeslagToepasbaar);
        System.debug('  - Toeslag Percentage (van Parent Object)? -> ' + line.regioToeslagPercentage);

        // Apply regional surcharge if applicable
        if (line.regioToeslagToepasbaar == true && line.regioToeslagPercentage != null && line.regioToeslagPercentage > 0) {
            
            System.debug('  ✅ CONDITIE VOLDAAN. Toeslag wordt nu berekend.');
            Decimal originalUnitPrice = unitPrice;
            Decimal multiplier = 1 + (line.regioToeslagPercentage / 100);
            unitPrice = unitPrice * multiplier;
            
            System.debug('  - Berekening: ' + originalUnitPrice.setScale(4) + ' * ' + multiplier.setScale(4) + ' = ' + unitPrice.setScale(4));
            System.debug('  - NIEUWE UNITPRICE (Verkoopprijs__c) -> ' + unitPrice.setScale(2));
            
            // If we already calculated a fixed total amount (vaste prijs), also apply surcharge to that
            if (line.lineAmountExBtw != null) {
                Decimal originalLineAmount = line.lineAmountExBtw;
                line.lineAmountExBtw = line.lineAmountExBtw * multiplier;
                System.debug('  - Vaste prijs totaal aangepast: ' + originalLineAmount.setScale(2) + ' -> ' + line.lineAmountExBtw.setScale(2));
            }

        } else {
            System.debug('  ❌ CONDITIE NIET VOLDAAN. Toeslag wordt overgeslagen.');
        }
        // === EINDE DIAGNOSE BLOK ===
        
        line.unitPriceExBtw = unitPrice;
        
        // Calculate line amount (if not already calculated by staffel trede or vaste prijs)
        if (line.priceType != PRICE_TYPE_STAFFEL_TREDE && line.lineAmountExBtw == null) {
            line.lineAmountExBtw = unitPrice * line.aantal;
        }

        // Snapshot the gross line amount BEFORE any bundle/minimum discounts (including regiotoeslag)
        line.lineAmountBeforeDiscountExBtw = line.lineAmountExBtw;
        
        System.debug('Final pricing: Unit=€' + line.unitPriceExBtw + ' | Line Total=€' + line.lineAmountExBtw);
        System.debug('=== LINE PRICING COMPLETE ===');
    }
    
    private static Decimal getStaffelCumulatiefPrice(List<Prijsstaffel__c> staffels, Decimal totalVolume) {
        if (staffels == null || staffels.isEmpty() || totalVolume <= 0) {
            System.debug('getStaffelCumulatiefPrice: Invalid input - staffels empty or totalVolume <= 0');
            return 0;
        }
        
        System.debug('Finding staffel tier for totalVolume: ' + totalVolume);
        
        // Find the appropriate tier based on total volume
        // Staffels should be ordered by Ondergrens__c ASC
        Prijsstaffel__c matchingTier = null;
        
        for (Prijsstaffel__c staffel : staffels) {
            Decimal lowerBound = staffel.Ondergrens__c != null ? staffel.Ondergrens__c : 0;
            Decimal upperBound = staffel.Bovengrens__c; // Can be null for unlimited upper tier
            
            System.debug('Checking tier: ' + lowerBound + ' - ' + (upperBound != null ? String.valueOf(upperBound) : '∞') + 
                        ' | Price: €' + staffel.Eenheidsprijs__c);
            
            // Volume must be >= lower bound
            if (totalVolume >= lowerBound) {
                // And either no upper bound (unlimited tier) or volume <= upper bound
                if (upperBound == null || totalVolume <= upperBound) {
                    matchingTier = staffel;
                    break; // First matching tier wins (assumes proper ordering)
                } else if (upperBound != null && totalVolume > upperBound) {
                    // Continue to next tier - this one is too small
                    matchingTier = staffel; // But keep it as fallback
                    continue;
                }
            }
        }
        
        // Use the matching tier or fallback to highest tier
        if (matchingTier != null) {
            Decimal price = matchingTier.Eenheidsprijs__c != null ? matchingTier.Eenheidsprijs__c : 0;
            System.debug('Selected staffel tier: ' + matchingTier.Ondergrens__c + '-' + 
                        (matchingTier.Bovengrens__c != null ? String.valueOf(matchingTier.Bovengrens__c) : '∞') + 
                        ' | Price: €' + price);
            return price;
        }
        
        System.debug('No matching staffel tier found - using fallback');
        return 0;
    }
    
    private static Prijsstaffel__c getMatchingStaffel(List<Prijsstaffel__c> staffels, Decimal totalVolume) {
        if (staffels == null || staffels.isEmpty() || totalVolume <= 0) {
            return null;
        }

        for (Prijsstaffel__c staffel : staffels) {
            Decimal lowerBound = staffel.Ondergrens__c != null ? staffel.Ondergrens__c : 0;
            Decimal upperBound = staffel.Bovengrens__c;

            if (totalVolume >= lowerBound && (upperBound == null || totalVolume <= upperBound)) {
                return staffel; // Gevonden!
            }
        }

        return null; // Geen match
    }
    
    private static Decimal calculateStaffelTredeAmount(List<Prijsstaffel__c> staffels, Decimal quantity) {
        if (staffels == null || staffels.isEmpty() || quantity <= 0) {
            System.debug('calculateStaffelTredeAmount: Invalid input.');
            return 0;
        }

        System.debug('Calculating Staffel Trede amount for quantity: ' + quantity);
        
        Decimal totalAmount = 0;
        Decimal quantityRemaining = quantity;

        // Verwerk elke staffel op volgorde (de query sorteert al op Ondergrens ASC)
        for (Prijsstaffel__c staffel : staffels) {
            if (quantityRemaining <= 0) break; // Stop als we alle aantallen hebben verwerkt

            Decimal lowerBound = staffel.Ondergrens__c != null ? staffel.Ondergrens__c : 1;
            Decimal upperBound = staffel.Bovengrens__c;
            Decimal tierPrice = staffel.Eenheidsprijs__c != null ? staffel.Eenheidsprijs__c : 0;
            
            // Bepaal de 'capaciteit' van deze trede
            Decimal tierCapacity;
            if (upperBound != null) {
                // Voorbeeld: 1-1 -> capaciteit = 1.  5-10 -> capaciteit = 6.
                tierCapacity = upperBound - lowerBound + 1;
            } else {
                // Dit is de laatste, onbegrensde trede. De capaciteit is oneindig.
                tierCapacity = quantityRemaining;
            }

            // Bepaal hoeveel van de resterende hoeveelheid in deze trede past
            Decimal quantityForThisTier = Math.min(quantityRemaining, tierCapacity);

            if (quantityForThisTier > 0) {
                Decimal tierAmount = quantityForThisTier * tierPrice;
                totalAmount += tierAmount;
                quantityRemaining -= quantityForThisTier;
                
                System.debug('  Tier (' + lowerBound + '-' + (upperBound != null ? String.valueOf(upperBound) : '∞') + '): ' +
                             quantityForThisTier + ' units × €' + tierPrice + ' = €' + tierAmount);
            }
        }
        
        System.debug('Total Staffel Trede amount: €' + totalAmount.setScale(2) + ' for ' + quantity + ' units');
        return totalAmount;
    }
    
    private static void calculateExtraPricing(GenericPricingLine extra, GenericPricingLine primaryLine) {
        System.debug('=== CALCULATING EXTRA PRICING ===');
        System.debug('Extra Product: ' + extra.productId + ' | Qty: ' + extra.aantal);
        System.debug('Related Primary: ' + extra.gerelateerProductId + ' | Primary Unit: €' + primaryLine.unitPriceExBtw + ' | Primary Net Line: €' + primaryLine.lineAmountExBtw);

        // Determine relative percentage - field-level override takes precedence over policy-level
        Decimal relativePercentage = 0;
        if (extra.relatiefPrijsPercentage != null && extra.relatiefPrijsPercentage > 0) {
            relativePercentage = extra.relatiefPrijsPercentage;
            System.debug('Using field-level relative percentage: ' + relativePercentage + '%');
        } else if (extra.relatiefPercentage != null && extra.relatiefPercentage > 0) {
            relativePercentage = extra.relatiefPercentage;
            System.debug('Using policy-level relative percentage: ' + relativePercentage + '%');
        } else {
            System.debug('No relative percentage found for extra - falling back to normal pricing');

            // Fallback to normal pricing rules for extras without relative pricing
            // Preserve provided quantity (may be > 0), and use standard line pricing
            Decimal volume = (extra.aantal != null && extra.aantal > 0) ? extra.aantal : 0;
            calculateLinePricing(extra, volume);
            System.debug('=== EXTRA PRICING COMPLETE (fallback normal pricing) ===');
            return;
        }

        // Business rule adjustment: relative extras are a percentage of the PRIMARY'S GROSS line amount
        // BEFORE bundle discounts/minimums, and INCLUDING any regional surcharge applied to that primary.
        // We snapshot this in line.lineAmountBeforeDiscountExBtw during calculateLinePricing.
        Decimal primaryGrossBeforeDiscount = 0;
        if (primaryLine.lineAmountBeforeDiscountExBtw != null && primaryLine.lineAmountBeforeDiscountExBtw > 0) {
            primaryGrossBeforeDiscount = primaryLine.lineAmountBeforeDiscountExBtw;
        } else if (primaryLine.lineAmountExBtw != null && primaryLine.lineAmountExBtw > 0) {
            primaryGrossBeforeDiscount = primaryLine.lineAmountExBtw; // fallback
        } else {
            // Fallback: derive from unit * qty if not present
            Decimal qty = primaryLine.aantal != null ? primaryLine.aantal : 0;
            Decimal unit = primaryLine.unitPriceExBtw != null ? primaryLine.unitPriceExBtw : 0;
            primaryGrossBeforeDiscount = unit * qty;
        }

        // Enforce business rule: relative extras always have Aantal = 1
        extra.aantal = 1;
    // Regiotoeslag is NOT applicable for relative extras (extras themselves keep 0%)
        extra.regioToeslagPercentage = 0;
        // Korting on extras is metadata/reporting only: mirror the primary's discount percentage, but don't apply an additional amount
        extra.kortingPercentage = primaryLine.kortingPercentage; // could be null if no order-level discount
        extra.kortingBedrag = null; // do not apply a separate discount amount on the extra

    // Calculate extra amounts based on percentage of primary gross-before-discount line (incl. regiotoeslag on primary)
    extra.unitPriceExBtw = (primaryGrossBeforeDiscount * (relativePercentage / 100)).setScale(2, RoundingMode.HALF_UP);
        extra.lineAmountExBtw = extra.unitPriceExBtw; // Quantity forced to 1

        System.debug('Extra pricing calculation (relative):');
    System.debug('  Primary Gross Before Discount (ex-BTW): €' + primaryGrossBeforeDiscount);
        System.debug('  Relative %: ' + relativePercentage + '%');
        System.debug('  Extra Unit/Line (Aantal=1): €' + extra.unitPriceExBtw);
        System.debug('=== EXTRA PRICING COMPLETE ===');
    }
    
    private static GenericPricingLine findPrimaryForExtra(GenericPricingLine extra, List<GenericPricingLine> primaries) {
        // Find the primary product that this extra is related to
        for (GenericPricingLine primary : primaries) {
            if (primary.productId == extra.gerelateerProductId || primary.lineId == extra.gerelateerProductId) {
                return primary;
            }
        }
        return null; // No matching primary found
    }
    
    private static void applyMinimumPricePerOrder(List<GenericPricingLine> allLines) {
        System.debug('Applying minimum price per order...');
        
        // Group lines by parent (Lead, Opportunity, Work Order)
        Map<Id, List<GenericPricingLine>> linesByParent = new Map<Id, List<GenericPricingLine>>();
        for (GenericPricingLine line : allLines) {
            if (line.parentId != null) {
                if (!linesByParent.containsKey(line.parentId)) {
                    linesByParent.put(line.parentId, new List<GenericPricingLine>());
                }
                linesByParent.get(line.parentId).add(line);
            }
        }
        
        // Apply minimum price per parent
        for (Id parentId : linesByParent.keySet()) {
            applyMinimumPriceForParent(linesByParent.get(parentId));
        }
        
        System.debug('Minimum price per order applied');
    }
    
    private static void applyMinimumPriceForParent(List<GenericPricingLine> parentLines) {
        // Stap 1: Vind de hoogste minimumprijs van alle primaire producten
        Decimal highestMinimumPrice = 0;
        for (GenericPricingLine line : parentLines) {
            if (line.isPrimary == true && line.minimaleprijs != null && line.minimaleprijs > highestMinimumPrice) {
                highestMinimumPrice = line.minimaleprijs;
            }
        }

        // Combineer met het associatie-minimum (per postcode + segment)
        Decimal associationMinimum = 0;
        for (GenericPricingLine line : parentLines) {
            if (line.associationMinimumExBtw != null && line.associationMinimumExBtw > associationMinimum) {
                associationMinimum = line.associationMinimumExBtw;
            }
        }

        if (associationMinimum > highestMinimumPrice) {
            highestMinimumPrice = associationMinimum;
        }

        if (highestMinimumPrice <= 0) {
            System.debug('No minimum price applicable for this order.');
            return; // Geen minimum, dus we zijn klaar
        }

        // Stap 2: Bereken de huidige totale prijs en het aantal van de primaire producten
        Decimal currentPrimaryTotal = 0;
        Decimal totalPrimaryQuantity = 0;
        List<GenericPricingLine> primaries = new List<GenericPricingLine>();
        for (GenericPricingLine line : parentLines) {
            if (line.isPrimary == true) {
                primaries.add(line);
                if(line.lineAmountExBtw != null) currentPrimaryTotal += line.lineAmountExBtw;
                if(line.aantal != null) totalPrimaryQuantity += line.aantal;
            }
        }

        // Stap 3: Als de huidige prijs lager is dan het minimum, pas een verhoging toe
        if (currentPrimaryTotal < highestMinimumPrice && totalPrimaryQuantity > 0) {
            System.debug('Current total (€' + currentPrimaryTotal + ') is below minimum (€' + highestMinimumPrice + '). Uplifting prices.');
            
            Decimal upliftUnitPrice = highestMinimumPrice / totalPrimaryQuantity;
            
            // Pas de nieuwe eenheidsprijs toe op alle primaire producten
            for (GenericPricingLine primary : primaries) {
                primary.unitPriceExBtw = upliftUnitPrice;
                primary.lineAmountExBtw = upliftUnitPrice * primary.aantal;

                // NIEUW: Reset de korting omdat de uplift deze invalideert
                primary.kortingPercentage = 0;
                primary.kortingBedrag = 0;
            }

            // Herbereken de prijzen van de extra's die bij deze primaries horen
            recalculateExtrasForPrimaries(primaries, parentLines);
        }
    }

    private static Map<Id, Decimal> getAssociationOrderMinimums(List<GenericPricingLine> lines) {
        System.debug('Fetching association-level order minimums...');

        Map<Id, Decimal> parentToMinimum = new Map<Id, Decimal>();
        if (lines == null || lines.isEmpty()) {
            return parentToMinimum;
        }

        // Verzamel unieke parentIds
        Set<Id> parentIds = new Set<Id>();
        for (GenericPricingLine line : lines) {
            if (line.parentId != null) {
                parentIds.add(line.parentId);
            }
        }

        if (parentIds.isEmpty()) {
            return parentToMinimum;
        }

        // Bepaal objecttype van de bron (alle lines in batch zijn van hetzelfde type)
        String lineObjectType = lines[0].objectType;
        if (String.isBlank(lineObjectType) && lines[0].sourceRecord != null) {
            lineObjectType = lines[0].sourceRecord.getSObjectType().getDescribe().getName();
        }

        Map<Id, SObject> parents = new Map<Id, SObject>();
        if (lineObjectType == 'Lead_Product__c') {
            parents.putAll([
                SELECT Id, Postcodegebied__c, Uniek_Segment__c
                FROM Lead
                WHERE Id IN :parentIds
            ]);
        } else if (lineObjectType == 'OpportunityLineItem') {
            parents.putAll([
                SELECT Id, Postcodegebied__c, Uniek_Segment__c
                FROM Opportunity
                WHERE Id IN :parentIds
            ]);
        } else if (lineObjectType == 'Wasserij_Item__c') {
            parents.putAll([
                SELECT Id, Postcodegebied__c, Uniek_Segment__c
                FROM Werk_Order__c
                WHERE Id IN :parentIds
            ]);
        }

        if (parents.isEmpty()) {
            return parentToMinimum;
        }

        Set<Id> postcodeGebiedIds = new Set<Id>();
        Set<String> segmenten = new Set<String>();
        for (SObject parent : parents.values()) {
            Id gebiedId = (Id)parent.get('Postcodegebied__c');
            String segment = (String)parent.get('Uniek_Segment__c');
            if (gebiedId != null && !String.isBlank(segment)) {
                postcodeGebiedIds.add(gebiedId);
                segmenten.add(segment);
            }
        }

        if (postcodeGebiedIds.isEmpty() || segmenten.isEmpty()) {
            return parentToMinimum;
        }

        Map<String, Decimal> keyToMinimum = new Map<String, Decimal>();
        for (Dienstgebied_Postcode_Associatie__c assoc : [
            SELECT Postcode_Gebied__c, Segment__c, Minimum_Order_Excl_BTW__c
            FROM Dienstgebied_Postcode_Associatie__c
            WHERE Minimum_Order_Excl_BTW__c != null AND Minimum_Order_Excl_BTW__c > 0
              AND Postcode_Gebied__c IN :postcodeGebiedIds
              AND Segment__c IN :segmenten
        ]) {
            String key = String.valueOf(assoc.Postcode_Gebied__c) + '|' + assoc.Segment__c;
            Decimal candidate = assoc.Minimum_Order_Excl_BTW__c;
            if (!keyToMinimum.containsKey(key) || (candidate != null && candidate > keyToMinimum.get(key))) {
                keyToMinimum.put(key, candidate);
            }
        }

        if (keyToMinimum.isEmpty()) {
            return parentToMinimum;
        }

        for (Id parentId : parents.keySet()) {
            Id gebiedId = (Id)parents.get(parentId).get('Postcodegebied__c');
            String segment = (String)parents.get(parentId).get('Uniek_Segment__c');
            if (gebiedId != null && !String.isBlank(segment)) {
                String key = String.valueOf(gebiedId) + '|' + segment;
                if (keyToMinimum.containsKey(key)) {
                    parentToMinimum.put(parentId, keyToMinimum.get(key));
                }
            }
        }

        System.debug('Loaded association minimums for ' + parentToMinimum.size() + ' parent records.');
        return parentToMinimum;
    }

    // Voeg deze nieuwe helper-methode toe voor het herberekenen van de extra's
    private static void recalculateExtrasForPrimaries(List<GenericPricingLine> primaries, List<GenericPricingLine> allParentLines) {
        for (GenericPricingLine extra : allParentLines) {
            if (extra.isPrimary == false && extra.gerelateerProductId != null) {
                for (GenericPricingLine primaryLine : primaries) {
                    // Support both reference styles: related to Product2 Id OR to the primary line Id
                    if (extra.gerelateerProductId == primaryLine.productId ||
                        extra.gerelateerProductId == primaryLine.lineId) {
                        calculateExtraPricing(extra, primaryLine);
                    }
                }
            }
        }
    }
    
    private static GenericPricingLine findPrimaryByProductId(Id productId, List<GenericPricingLine> lines) {
        for (GenericPricingLine line : lines) {
            if (line.productId == productId) {
                return line;
            }
        }
        return null; // No matching primary found
    }
    
    private static void applyBundleDiscountsDeterministic(List<GenericPricingLine> allLines) {
        System.debug('Applying bundle discounts (deterministic)...');
        
        // Group lines by parent (Lead, Opportunity, Work Order)
        Map<Id, List<GenericPricingLine>> linesByParent = new Map<Id, List<GenericPricingLine>>();
        for (GenericPricingLine line : allLines) {
            if (line.parentId != null) {
                if (!linesByParent.containsKey(line.parentId)) {
                    linesByParent.put(line.parentId, new List<GenericPricingLine>());
                }
                linesByParent.get(line.parentId).add(line);
            }
        }
        
        System.debug('Found ' + linesByParent.size() + ' parent groups for bundle discount processing');
        
        // Apply bundle discount logic per parent group
        for (Id parentId : linesByParent.keySet()) {
            System.debug('Processing bundle discount for parent: ' + parentId);
            applyBundleDiscountForParent(linesByParent.get(parentId));
        }
        
        System.debug('=== BUNDLE DISCOUNTS APPLIED ===');
    }

    // NEW: Recalculate extras after bundle discounts to reflect updated primary NET amounts
    private static void recalculateExtrasAfterBundle(List<GenericPricingLine> allLines) {
        System.debug('Recalculating extras after bundle discounts...');

        if (allLines == null || allLines.isEmpty()) return;

        // Group lines by parent
        Map<Id, List<GenericPricingLine>> linesByParent = new Map<Id, List<GenericPricingLine>>();
        for (GenericPricingLine line : allLines) {
            if (line.parentId == null) continue;
            if (!linesByParent.containsKey(line.parentId)) {
                linesByParent.put(line.parentId, new List<GenericPricingLine>());
            }
            linesByParent.get(line.parentId).add(line);
        }

        // For each parent, find primaries and recalc related extras
        for (Id parentId : linesByParent.keySet()) {
            List<GenericPricingLine> parentLines = linesByParent.get(parentId);

            // Consider lines marked as primary OR without a related product reference as primaries in this context
            List<GenericPricingLine> primaries = new List<GenericPricingLine>();
            for (GenericPricingLine line : parentLines) {
                if (line.isPrimary == true || line.gerelateerProductId == null) {
                    primaries.add(line);
                }
            }

            if (!primaries.isEmpty()) {
                recalculateExtrasForPrimaries(primaries, parentLines);
            }
        }

        System.debug('Extras recalculated after bundle discounts.');
    }
    
    private static void applyBundleDiscountForParent(List<GenericPricingLine> parentLines) {
        // Step A: Get the segment from the first line (using pre-loaded product data)
        if (parentLines == null || parentLines.isEmpty() || parentLines[0].productId == null) {
            System.debug('No valid lines found for bundle discount processing');
            return;
        }
        
        System.debug('=== PROCESSING BUNDLE DISCOUNT FOR PARENT ===');
        
        // Get segment information from pre-loaded product data (NO SOQL!)
        String segment = parentLines[0].productSegment;

        if (String.isBlank(segment)) {
            System.debug('No segment found for this order. Skipping bundle discount.');
            return;
        }
        
        System.debug('Order segment: ' + segment);
        
        // Step B: Get active bundle discount rules for the correct segment
        List<Bundle_Discount__mdt> rules;
        try {
            rules = [
                SELECT Min_Count__c, Discount_Percent__c, Min_Aantal_Threshold__c 
                FROM Bundle_Discount__mdt 
                WHERE Active__c = true AND Segment__c = :segment
                ORDER BY Min_Count__c DESC // Important: start with the highest requirement!
            ];
        } catch (Exception e) {
            System.debug('Error loading bundle discount rules: ' + e.getMessage());
            return;
        }

        if (rules.isEmpty()) {
            System.debug('No active bundle discount rules found for segment: ' + segment);
            return;
        }
        
        System.debug('Found ' + rules.size() + ' bundle discount rules for segment ' + segment);
        for (Bundle_Discount__mdt rule : rules) {
            System.debug('  Rule: Min ' + rule.Min_Count__c + ' items (threshold: ' + rule.Min_Aantal_Threshold__c + ') = ' + (rule.Discount_Percent__c * 100) + '% discount');
        }

        // Step C: Identify products that qualify for the discount
        List<GenericPricingLine> qualifyingLines = new List<GenericPricingLine>();
        for (GenericPricingLine line : parentLines) {
            // Check both primary product flag and bundle eligibility
            if (line.isPrimary == true && line.isBundleEligible == true) {
                qualifyingLines.add(line);
                System.debug('Qualifying line: Product=' + line.productId + ', Code=' + line.productCode + ', Qty=' + line.aantal + ', Amount=€' + line.lineAmountExBtw);
            } else {
                System.debug('Non-qualifying line: Product=' + line.productId + ', Code=' + line.productCode + ', Primary=' + line.isPrimary);
            }
        }
        
        System.debug('Found ' + qualifyingLines.size() + ' qualifying lines for bundle discount in segment ' + segment);

        // Step D: Determine the highest applicable discount
        for (Bundle_Discount__mdt rule : rules) {
            Integer itemsMeetingThreshold = 0;
            Decimal totalQualifyingAmount = 0;
            
            for (GenericPricingLine line : qualifyingLines) {
                if (line.aantal != null && line.aantal >= rule.Min_Aantal_Threshold__c) {
                    itemsMeetingThreshold++;
                    if (line.lineAmountExBtw != null) {
                        totalQualifyingAmount += line.lineAmountExBtw;
                    }
                }
            }
            
            System.debug('Rule evaluation: ' + itemsMeetingThreshold + ' items meet threshold ' + rule.Min_Aantal_Threshold__c + 
                        ' (need ' + rule.Min_Count__c + '). Total amount: €' + totalQualifyingAmount);
            
            if (itemsMeetingThreshold >= rule.Min_Count__c) {
                // Rule is applicable! Apply discount and stop.
                Decimal discountPercent = rule.Discount_Percent__c * 100; // Convert 0.05 to 5%
                System.debug('✅ BUNDLE DISCOUNT TRIGGERED: ' + discountPercent + '% discount');
                System.debug('   Items meeting threshold: ' + itemsMeetingThreshold + '/' + qualifyingLines.size());
                System.debug('   Threshold requirement: ' + rule.Min_Aantal_Threshold__c);
                System.debug('   Total amount before discount: €' + totalQualifyingAmount);
                
                Decimal totalDiscountAmount = 0;
                
                // 1) Apply the discount to qualifying primaries (eligibility based on rules)
                Set<Id> discountedLineIds = new Set<Id>();
                for (GenericPricingLine line : qualifyingLines) {
                    if (line.lineAmountExBtw != null && line.lineAmountExBtw > 0) {
                        Decimal originalAmount = line.lineAmountExBtw;
                        line.kortingPercentage = discountPercent;
                        line.kortingBedrag = (line.lineAmountExBtw * discountPercent / 100).setScale(2, RoundingMode.HALF_UP);
                        line.lineAmountExBtw = line.lineAmountExBtw - line.kortingBedrag;
                        totalDiscountAmount += line.kortingBedrag;
                        discountedLineIds.add(line.lineId);
                        System.debug('   Line discount applied: Product=' + line.productId +
                                   ' | €' + originalAmount + ' - €' + line.kortingBedrag + ' = €' + line.lineAmountExBtw);
                    }
                }

                // 2) Apply the same discount percent to the rest of the lines in the parent (including extras)
                //    Extras do not contribute to eligibility counts but MUST receive the discount amount as well.
                for (GenericPricingLine line : parentLines) {
                    if (line.lineAmountExBtw == null || line.lineAmountExBtw <= 0) continue;
                    if (discountedLineIds.contains(line.lineId)) continue; // already discounted above

                    Decimal originalAmount = line.lineAmountExBtw;
                    line.kortingPercentage = discountPercent;
                    line.kortingBedrag = (line.lineAmountExBtw * discountPercent / 100).setScale(2, RoundingMode.HALF_UP);
                    line.lineAmountExBtw = line.lineAmountExBtw - line.kortingBedrag;
                    totalDiscountAmount += line.kortingBedrag;
                    System.debug('   Line discount applied (non-qualifying, incl. extras): Product=' + line.productId +
                               ' | €' + originalAmount + ' - €' + line.kortingBedrag + ' = €' + line.lineAmountExBtw);
                }
                
                System.debug('   Total discount amount: €' + totalDiscountAmount);
                System.debug('   New total amount: €' + (totalQualifyingAmount - totalDiscountAmount));
                
                // Important: stop after the first (highest) match.
                // Because we use 'ORDER BY Min_Count__c DESC', the first match is the best.
                return; 
            } else {
                System.debug('❌ Rule not met: only ' + itemsMeetingThreshold + ' items, need ' + rule.Min_Count__c);
            }
        }
        
        System.debug('No bundle discount rule was met for this order.');
        System.debug('=== BUNDLE DISCOUNT PROCESSING COMPLETE ===');
    }


    // =============================================================================
    // BTW CALCULATION LOGIC  
    // =============================================================================
    
    private static void calculateBTWForLines(List<GenericPricingLine> allLines) {
        System.debug('=== CALCULATING BTW ===');
        for (GenericPricingLine line : allLines) {
            if (line.lineAmountExBtw != null && String.isNotBlank(line.btw)) {
                try {
                    Decimal btwPercentage = Decimal.valueOf(line.btw);
                    line.btwBedrag = (line.lineAmountExBtw * btwPercentage / 100).setScale(2, RoundingMode.HALF_UP);
                    line.lineAmountIncBtw = line.lineAmountExBtw + line.btwBedrag;
                } catch (Exception e) {
                    System.debug('Error calculating BTW for line ' + line.lineId + '. BTW value: ' + line.btw);
                    line.btwBedrag = 0;
                    line.lineAmountIncBtw = line.lineAmountExBtw;
                }
            } else {
                line.btwBedrag = 0;
                line.lineAmountIncBtw = line.lineAmountExBtw;
            }
        }
        System.debug('=== BTW CALCULATION COMPLETE ===');
    }

    // =============================================================================
    // REGIONAL SURCHARGE LOGIC
    // =============================================================================
    
    private static Map<Id, Decimal> getRegionalSurcharges(List<GenericPricingLine> lines) {
        System.debug('=== GETTING REGIONAL SURCHARGES ===');
        Map<Id, Decimal> surchargeMap = new Map<Id, Decimal>();
        if (lines.isEmpty()) return surchargeMap;

        String parentObjectType = lines[0].sourceRecord.getSObjectType().getDescribe().getName();
        Set<Id> parentIds = new Set<Id>();
        for(GenericPricingLine line : lines) {
            if(line.parentId != null) parentIds.add(line.parentId);
        }

        if (parentIds.isEmpty()) return surchargeMap;

        // Stap 1: Haal de parent-records op
        Map<Id, SObject> parentRecords = new Map<Id, SObject>();
        if (parentObjectType == 'Lead_Product__c') {
            parentRecords = new Map<Id, SObject>([SELECT Id, Postcodegebied__c, Uniek_Segment__c FROM Lead WHERE Id IN :parentIds]);
        } else if (parentObjectType == 'OpportunityLineItem') {
            parentRecords = new Map<Id, SObject>([SELECT Id, Postcodegebied__c, Uniek_Segment__c FROM Opportunity WHERE Id IN :parentIds]);
        } else if (parentObjectType == 'Wasserij_Item__c') {
            parentRecords = new Map<Id, SObject>([SELECT Id, Postcodegebied__c, Uniek_Segment__c FROM Werk_Order__c WHERE Id IN :parentIds]);
        }

        // Stap 2: Verzamel unieke Postcodegebied IDs en Segmenten
        Set<Id> postcodeGebiedIds = new Set<Id>();
        Set<String> segmenten = new Set<String>();
        for (SObject parent : parentRecords.values()) {
            if (parent.get('Postcodegebied__c') != null && parent.get('Uniek_Segment__c') != null) {
                postcodeGebiedIds.add((Id)parent.get('Postcodegebied__c'));
                segmenten.add((String)parent.get('Uniek_Segment__c'));
            }
        }

        if (postcodeGebiedIds.isEmpty() || segmenten.isEmpty()) {
            return surchargeMap;
        }

        // Stap 3: Query de associaties
        Map<String, Decimal> keyToSurcharge = new Map<String, Decimal>();
        for (Dienstgebied_Postcode_Associatie__c assoc : [
            SELECT Postcode_Gebied__c, Segment__c, Toeslag__c
            FROM Dienstgebied_Postcode_Associatie__c
            WHERE Regiotoeslag__c = true AND Toeslag__c > 0
            AND Postcode_Gebied__c IN :postcodeGebiedIds
            AND Segment__c IN :segmenten
        ]) {
            String key = assoc.Postcode_Gebied__c + '|' + assoc.Segment__c;
            keyToSurcharge.put(key, assoc.Toeslag__c);
        }

        // Stap 4: Map de toeslag terug naar de parentId
        for (Id parentId : parentRecords.keySet()) {
            SObject parent = parentRecords.get(parentId);
            Id postcodeGebiedId = (Id)parent.get('Postcodegebied__c');
            String segment = (String)parent.get('Uniek_Segment__c');

            if (postcodeGebiedId != null && segment != null) {
                String key = postcodeGebiedId + '|' + segment;
                if (keyToSurcharge.containsKey(key)) {
                    surchargeMap.put(parentId, keyToSurcharge.get(key));
                }
            }
        }

        System.debug('Loaded ' + surchargeMap.size() + ' regional surcharges.');
        return surchargeMap;
    }
}


