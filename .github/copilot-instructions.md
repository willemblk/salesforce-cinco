# Salesforce Pricing Engine — AI agent quickstart (Updated 2025-11-09)

## Big picture
- Apex, metadata-driven pricing for Wasserij (+ SR) across `Lead_Product__c`, `OpportunityLineItem`, and `Wasserij_Item__c`. WordPress fetches catalog/pricing via REST; Salesforce triggers keep data in sync with strict guards.

## Architecture (why it’s structured this way)
- One engine: `PricingService.cls` converts any line to a generic wrapper → bulk-loads context (`Product2`, active `Prijsmanagement__c` + optional `Prijsstaffel__c`) → computes base price (qty/area, staffel types) → applies regional surcharge (`Dienstgebied_Postcode_Associatie__c`) → applies bundle discount (`Bundle_Discount__mdt`) → enforces order minimums → writes back to source.
- Triggers are “after”, guarded by `TriggerRecursionGuard`, call `PricingService.repriceLead/Opportunity/repriceWerkorder`; no SOQL in loops.

## Entry points and where to look
- REST: `PriceCalculationApi.cls` at POST `/services/apexrest/v1/calculatePrice`.
  - Empty products → returns catalog filtered by `Product2.Beschikbare_Websites__c` INCLUDES `siteId`, plus bundle rules and `regioToeslagPercentage`/order minimums.
  - With products → builds temp `Lead_Product__c` lines and calls `PricingService.reprice(...)`; returns totals and line details.
- Lead conversion: `LeadToOpportunityConverter.cls` (Invocable)
  - Matches/attaches to existing Person Account by Lead email; safely syncs person/billing address fields.
  - Sets Stage/RecordType/Pricebook; toggles `Automation_Bypass__c` during OLI insert; skips creation if OLI already exists.
  - Builds OLIs from `Lead_Product__c` primaries and extras (extras link via `Gerelateerd_Product__c`), then calls a single `PricingService.repriceOpportunity(...)` only when active policies exist (see `hasActivePoliciesForProducts`).
- Triggers: `LeadProduct_Trigger.trigger`, `OpportunityLineItem_Trigger.trigger`, `WasserijItem_Trigger.trigger` → guarded, batch by parent, single DML update.

## Pricing rules to honor (project-specific)
- Staffel types: `Normaal`, `Staffel Cumulatief` (tiers by group volume; supports `Vaste_Prijs`), `Staffel Trede` (distribute qty per tier), `Flat Fee` (force extra qty=1).
- Regional surcharge: only if policy `Regiotoeslag_toepasbaar__c=true` AND association `Regiotoeslag__c=true` with `Toeslag__c>0`; applied to unit and any fixed totals.
- Bundle discount: active `Bundle_Discount__mdt` per segment; eligibility is primary + bundle-eligible items meeting `Min_Aantal_Threshold__c`; highest tier wins; discount mirrors to all lines (incl. extras).
- SR percentage extras: extras use `Relatieve_prijs__c` as % of the PRIMARY gross-before-discount line (already incl. regiotoeslag); extra qty=1; no separate regiotoeslag.
- Order minimums: uplift primary unit prices to meet the highest of product minimums and association minimum; recalc dependent extras afterwards.

## Conventions for agents (do this here)
- Always go through `PricingService` wrappers; keep SOQL bulked and filtered by active/in-range; never query in loops.
- Guard all triggers with `TriggerRecursionGuard`; when bulk-inserting/updating OLIs use guard key `'OpportunityLineItem_Trigger'` and perform one DML per parent group.
- Lead → OLI price resolution: `Eenheidsprijs__c` → `Verkoopprijs__c` → `Totale_Prijs__c / Aantal__c` → fallback `PricebookEntry.UnitPrice`.
- Keep debug logs short and scannable; emojis welcome (💰 load, 📊 staffel, 🎁 bundle, ✅ applied, ⚠️ warn, ❌ error).

## Developer workflow (PowerShell)
- Org login: `sf org login web --alias myorg`
- Deploy one/all: `sf project deploy start --source-dir force-app\main\default\classes\PricingService.cls`; `sf project deploy start --source-dir force-app\main\default\`
- Run Apex tests: `sf apex run test --class-names PricingService_Test,PriceCalculationApi_Test,OpportunityLineItem_Pricing_Test,RelativeExtras_Test --result-format human`
- Handy scripts: `sf apex run --file scripts\apex\check_bundle_metadata.apex`; `sf apex run --file scripts\apex\functional_test_lead_product.apex`; `sf apex run --file scripts\apex\run_reprice_for_leadproduct.apex`
- Format/lint: `npm run prettier`; `npm run prettier:verify`; LWC lint/tests: `npm run lint`; `npm run test:unit`

## Fast checks / pitfalls
- “No price”: verify `Prijsmanagement__c` active/in range, segment matches `Product2.Segment__c`, site filter allows it.
- “Bundle not applied”: check count vs `Min_Count__c`, area vs `Min_Aantal_Threshold__c`, segment, and `Active__c`.
- Lead conversion: invalid converted status is retried with allowed statuses; provide `Request.convertedStatus` to override. Standard Pricebook is auto-activated when missing.
- WordPress integration: API returns 18-char IDs for Partner/Postcodegebied/Dienstgebied; client stores and posts back on Lead creation.

Open first: `force-app/main/default/classes/PricingService.cls`, `force-app/main/default/classes/PriceCalculationApi.cls`, `force-app/main/default/classes/LeadToOpportunityConverter.cls`, `force-app/main/default/triggers/*`, `scripts/apex/check_bundle_metadata.apex`.

More detail in `README.md` and SR docs: `SR-EXTRAS-PERCENTAGE-CONFIGURATION.md`, `SR-SALESFORCE-CONFIGURATION.md`, `SR-OVERVIEW.md`.
