public with sharing class WerkOrderTokenService {
    // Ensure each work order carries a token before persistence
    public static void ensureTokens(List<Werk_Order__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        for (Werk_Order__c wo : records) {
            if (String.isBlank(wo.Route_Keuze_Token__c)) {
                wo.Route_Keuze_Token__c = generateToken();
            }
        }
    }

    private static String generateToken() {
        Long randomSeed = Crypto.getRandomLong();
        Blob digest = Crypto.generateDigest('SHA-256', Blob.valueOf(String.valueOf(randomSeed)));
        String hex = EncodingUtil.convertToHex(digest);
        return hex.substring(0, 36);
    }
}
