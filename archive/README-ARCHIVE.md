# 📦 Archive - Historical Documentation

**Date**: October 10, 2025  
**Version**: v1.5.0

## 📋 About this Archive

This directory contains historical documentation from the Salesforce Pricing Engine development journey. All files are archived because:

1. **Implementation Complete**: Features are fully implemented and documented in main README
2. **Bugfixes Resolved**: Issues are fixed and solutions are integrated
3. **Debug Scripts**: One-time debugging sessions, no longer needed
4. **Duplication**: Information is consolidated in central documentation

## 📚 Archived Categories

### 🔧 Implementation Notes
- `IMPLEMENTATION-SUMMARY.md` - Overall architecture summary
- `BUNDLE_DISCOUNT_IMPLEMENTATION_COMPLETE.md` - Bundle discount system
- `REGIOTOESLAG_IMPLEMENTATION.md` - Regional surcharge calculation
- `REGIOTOESLAG_BACKEND_IMPLEMENTATION.md` - Backend regiotoeslag logic
- `DYNAMIC_PRICING_IMPLEMENTATION.md` - Dynamic pricing API
- `SR-EXTRAS-IMPLEMENTATION-SUMMARY.md` - SR percentage-based extras

### 🐛 Bugfix Documentation
- `BTW-FIX-COMPLETED.md` - BTW (VAT) calculation fix
- `BTW-VERIFICATION-SUCCESS.md` - BTW verification results
- `SOQL_FIELD_ERROR_FIX.md` - SOQL query field error resolution
- `SOLUTION_SUMMARY.md` - Various bug solutions

### 🧪 Test & Debug Scripts
- `deep_diagnose_pricing.apex` - Deep pricing diagnosis (v7.2.0 debug session)
- `final_dlrs_test.apex` - DLRS compatibility verification (stable)
- `CREATE_BUNDLE_DISCOUNT_RECORDS.apex` - One-time metadata setup
- `BUNDLE_ELIGIBILITY_VERIFICATION.apex` - Bundle eligibility testing
- `diagnose_extra_products.apex` - Extra products debugging

### 📊 Deployment & Verification
- `DEPLOYMENT_CHECKLIST.md` - Deployment steps (integrated in main README)
- `DEPLOYMENT-TEST-RESULTS.md` - Historical test results
- `PRICECALCULATIONAPI-LOOKUP-IDS.md` - Lookup IDs API documentation
- `PRICING_FIELD_STRUCTURE.md` - Field structure reference

### 📄 Status Updates
- `SR_API_UPDATE_STATUS.md` - SR API implementation progress

## 🔍 Where to Find Current Info?

### Main Documentation
- **README.md**: Complete architecture, pricing logic, WordPress integration
- **SR-SALESFORCE-CONFIGURATION.md**: SR data model and configuration
- **SR-EXTRAS-PERCENTAGE-CONFIGURATION.md**: SR percentage-based extras setup
- **SR-OVERVIEW.md**: Cross-workspace SR overview
- **.github/copilot-instructions.md**: AI agent development patterns

### Active Utility Scripts
- `scripts/apex/check_bundle_metadata.apex` - Verify bundle discount metadata
- `scripts/apex/functional_test_lead_product.apex` - Test Lead_Product__c pricing
- `scripts/apex/check_recursion_guard.apex` - Recursion guard status

## 📈 Version History

### v1.5.0 (October 2025) - Current
- WordPress integration complete
- Lookup IDs (Partner__c, Postcodegebied__c) populated
- Bundle discounts metadata-driven
- Regional surcharge calculation
- Multi-step form support

### v1.4.0 (October 2025)
- SR (Spot Reinigen) implementation
- SR Meubel & Tapijt pricing
- Percentage-based extras

### v1.3.0 (September 2025)
- DLRS compatibility
- TriggerRecursionGuard
- Async deletion processing

### v1.2.0 (August 2025)
- Bundle discounts
- Metadata-driven configuration

### v1.1.0 (July 2025)
- Core PricingService
- Wrapper pattern
- OpportunityLineItem support

## ♻️ Archive Maintenance

**Retention Policy**: These files are **permanently preserved** for historical reference but are no longer updated.

**Restore**: If you need content from this archive, copy the relevant section to an active document and update it.

**New Archives**: For future cleanups, add new items with date and version number.

---

**Last Updated**: October 10, 2025  
**Archived By**: Automated cleanup script
