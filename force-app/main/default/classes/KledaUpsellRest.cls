@RestResource(urlMapping='/v1/upsell')
global with sharing class KledaUpsellRest {

    global class UpsellRequest {
        public String token;
        public Boolean confirm;
    }

    global class UpsellResponse {
        public Boolean success;
        public String message;
        public String errorCode;
    }

    @HttpPost
    global static UpsellResponse confirmUpsell() {
        UpsellResponse res = new UpsellResponse();
        res.success = false;

        UpsellRequest body;
        try {
            body = (UpsellRequest) JSON.deserialize(RestContext.request.requestBody.toString(), UpsellRequest.class);
        } catch (Exception ex) {
            res.message = 'Invalid JSON body';
            res.errorCode = 'BAD_REQUEST';
            return res;
        }

        if (body == null || String.isBlank(body.token)) {
            res.message = 'Missing token';
            res.errorCode = 'MISSING_TOKEN';
            return res;
        }

        List<Werk_Order__c> wos = [
            SELECT Id, Ondertapijt_besteld__c, Werk_Order_Status__c
            FROM Werk_Order__c
            WHERE Route_Keuze_Token__c = :body.token
            LIMIT 1
        ];

        if (wos.isEmpty()) {
            res.message = 'Work order not found';
            res.errorCode = 'NOT_FOUND';
            return res;
        }

        Werk_Order__c wo = wos[0];

        Set<String> allowedUpsellStatuses = new Set<String>{
            'Aan het reinigen',
            'Terugbrengen plannen',
            'Terugbrengen ingepland'
        };
        if (!allowedUpsellStatuses.contains(wo.Werk_Order_Status__c)) {
             res.message = 'Upsell not available for this status.';
             res.errorCode = 'NOT_UPSELLABLE';
             return res;
        }
        
        Boolean confirmValue = (body.confirm == true);
        Boolean declineValue = (body.confirm == false);

        if (confirmValue || declineValue) {
            Boolean newFlagValue = confirmValue;
            if (wo.Ondertapijt_besteld__c != newFlagValue) {
                wo.Ondertapijt_besteld__c = newFlagValue;
                try {
                    update wo;
                } catch (DmlException e) {
                    res.message = 'Error updating work order: ' + e.getMessage();
                    res.errorCode = 'UPDATE_FAILED';
                    return res;
                }
            }

            res.success = true;
            res.message = confirmValue ? 'Upsell confirmed' : 'Upsell declined';
        } else {
            res.success = true;
            res.message = 'Upsell preference recorded';
        }

        return res;
    }
}
