@RestResource(urlMapping='/v1/appointment/*')
global with sharing class KledaAppointmentRest {

    global class OptionDto {
        public Integer id;
        public String label;
        public String raw;
    }

    global class AppointmentResponse {
        public Boolean success;
        public String message;
        public String errorCode;
        public String status;
        public String phaseType;
        public String customerName;
        public String workOrderNumber;
        public String serviceLabel;
        public String pickupAddress;
        public String deliveryAddress;
        public String pickupNotes;
        public String deliveryNotes;
        public Decimal totalM2;
        public Decimal underlayPrice;
        public Boolean ondertapijtBesteld;
        public List<OptionDto> options;
        public Boolean alreadyChosen;
        public Integer chosenOption;
    }

    global class ChoiceRequest {
        public String token;
        public Integer choice;
        public String notes;
        public String pickupComment;
        public String deliveryComment;
    }

    @HttpGet
    global static AppointmentResponse getAppointment() {
        RestRequest req = RestContext.request;
        String token = req.params.get('token');

        AppointmentResponse res = initResponse();

        if (String.isBlank(token)) {
            res.message = 'Missing token';
            res.errorCode = 'MISSING_TOKEN';
            return res;
        }

        Werk_Order__c wo = findWorkOrderByToken(token, res);
        if (wo == null) {
            return res;
        }

        populatePhaseAndStatus(wo, res);
        if (res.phaseType == null) {
            res.message = 'Work order is in a status that cannot be scheduled.';
            res.errorCode = 'INVALID_STATUS';
            return res;
        }

        String typeParam = req.params.get('type');
        if (typeParam == 'upsell') {
            Set<String> allowedUpsellStatuses = new Set<String>{
                'Aan het reinigen',
                'Terugbrengen plannen',
                'Terugbrengen ingepland'
            };
            if (!allowedUpsellStatuses.contains(wo.Werk_Order_Status__c)) {
                res.success = false;
                res.message = 'Upsell not available for this status.';
                res.errorCode = 'NOT_UPSELLABLE';
                return res;
            }
            res.success = true;
            return res;
        }

        res.options = buildOptions(wo);
        res.alreadyChosen = (wo.Route_Keuze__c != null);
        res.chosenOption = (wo.Route_Keuze__c != null) ? Integer.valueOf(wo.Route_Keuze__c) : null;

        if (!isStatusSchedulable(res.status)) {
            res.success = true;
            res.message = 'This work order can no longer be scheduled.';
            res.errorCode = 'NOT_SCHEDULABLE';
            return res;
        }

        res.success = true;

        String newStatus = getProposalStatus(res.status);
        if (newStatus != null && newStatus != res.status) {
            wo.Werk_Order_Status__c = newStatus;
            update wo;
            res.status = newStatus;
        }

        return res;
    }

    @HttpPost
    global static AppointmentResponse chooseAppointment() {
        AppointmentResponse res = initResponse();

        ChoiceRequest body;
        try {
            body = (ChoiceRequest) JSON.deserialize(RestContext.request.requestBody.toString(), ChoiceRequest.class);
        } catch (Exception ex) {
            res.message = 'Invalid JSON body';
            res.errorCode = 'BAD_REQUEST';
            return res;
        }

        if (body == null || String.isBlank(body.token) || body.choice == null) {
            res.message = 'Missing token or choice';
            res.errorCode = 'MISSING_FIELDS';
            return res;
        }

        Werk_Order__c wo = findWorkOrderByToken(body.token, res);
        if (wo == null) {
            return res;
        }

        populatePhaseAndStatus(wo, res);
        if (res.phaseType == null) {
            res.message = 'Work order is in a status that cannot be scheduled.';
            res.errorCode = 'INVALID_STATUS';
            return res;
        }

        List<OptionDto> opts = buildOptions(wo);
        res.options = opts;
        res.alreadyChosen = (wo.Route_Keuze__c != null);
        res.chosenOption = (wo.Route_Keuze__c != null) ? Integer.valueOf(wo.Route_Keuze__c) : null;

        if (!isStatusSchedulable(res.status)) {
            res.message = 'This work order can no longer be scheduled.';
            res.errorCode = 'NOT_SCHEDULABLE';
            return res;
        }

        if (wo.Route_Keuze__c != null) {
            res.message = 'Appointment already chosen.';
            res.errorCode = 'ALREADY_CHOSEN';
            return res;
        }

        if (body.choice < 1 || body.choice > 3) {
            res.message = 'Choice must be 1, 2 or 3.';
            res.errorCode = 'INVALID_CHOICE';
            return res;
        }

        OptionDto chosen = null;
        for (OptionDto o : opts) {
            if (o.id == body.choice) {
                chosen = o;
                break;
            }
        }
        if (chosen == null) {
            res.message = 'Selected option is not available.';
            res.errorCode = 'OPTION_NOT_AVAILABLE';
            return res;
        }

        applyNotesToWorkOrder(wo, res.phaseType, body);

        wo.Route_Keuze__c = body.choice;
        String scheduledStatus = getScheduledStatus(res.status);
        if (scheduledStatus != null) {
            wo.Werk_Order_Status__c = scheduledStatus;
        }

        update wo;

        res.success = true;
        res.message = 'Appointment confirmed.';
        res.alreadyChosen = true;
        res.chosenOption = body.choice;
        res.status = wo.Werk_Order_Status__c;
        return res;
    }

    private static void applyNotesToWorkOrder(Werk_Order__c wo, String phaseType, ChoiceRequest body) {
        String genericNotes = trimToNull(body.notes);
        String pickupNotes = trimToNull(body.pickupComment);
        String deliveryNotes = trimToNull(body.deliveryComment);

        if (genericNotes != null) {
            if (phaseType == 'pickup') {
                pickupNotes = genericNotes;
            } else if (phaseType == 'delivery') {
                deliveryNotes = genericNotes;
            }
        }

        if (pickupNotes != null) {
            wo.Opmerkingen_Ophalen__c = appendWithSeparator(wo.Opmerkingen_Ophalen__c, pickupNotes);
        }

        if (deliveryNotes != null) {
            wo.Opmerkingen_Aflevering__c = appendWithSeparator(wo.Opmerkingen_Aflevering__c, deliveryNotes);
        }
    }

    private static String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed == '' ? null : trimmed;
    }

    private static String appendWithSeparator(String existingValue, String newValue) {
        String existingTrimmed = trimToNull(existingValue);
        if (existingTrimmed == null) {
            return newValue;
        }

        return existingTrimmed + '\n\n' + newValue;
    }

    private static AppointmentResponse initResponse() {
        AppointmentResponse res = new AppointmentResponse();
        res.success = false;
        res.options = new List<OptionDto>();
        return res;
    }

    private static Werk_Order__c findWorkOrderByToken(String token, AppointmentResponse res) {
        try {
            return [
                  SELECT Id,
                      Name,
                      Klantnaam__c,
                      Werk_Order_Status__c,
                      Route_Optie_1__c,
                      Route_Optie_2__c,
                      Route_Optie_3__c,
                      Route_Keuze__c,
                      Route_Keuze_Token__c,
                      Ophaaladres_formule__c,
                      Afleveradres_formule__c,
                      Opmerkingen_Ophalen__c,
                      Opmerkingen_Aflevering__c,
                      Totaal_m2_vloerkleed__c,
                      Prijs_Ondertapijt__c,
                      Ondertapijt_besteld__c
                FROM Werk_Order__c
                WHERE Route_Keuze_Token__c = :token
                LIMIT 1
            ];
        } catch (QueryException ex) {
            res.message = 'Work order not found for token';
            res.errorCode = 'NOT_FOUND';
            return null;
        }
    }

    private static void populatePhaseAndStatus(Werk_Order__c wo, AppointmentResponse res) {
        res.status = wo.Werk_Order_Status__c;
        res.phaseType = determinePhaseType(res.status);
        res.customerName = wo.Klantnaam__c;
        res.workOrderNumber = wo.Name;
        res.pickupAddress = wo.Ophaaladres_formule__c;
        res.deliveryAddress = wo.Afleveradres_formule__c;
        res.pickupNotes = wo.Opmerkingen_Ophalen__c;
        res.deliveryNotes = wo.Opmerkingen_Aflevering__c;
        res.totalM2 = wo.Totaal_m2_vloerkleed__c;
        res.underlayPrice = wo.Prijs_Ondertapijt__c;
        res.ondertapijtBesteld = wo.Ondertapijt_besteld__c;
    }

    private static String determinePhaseType(String status) {
        if (String.isBlank(status)) {
            return null;
        }

        Set<String> pickup = new Set<String>{
            'Ophalen plannen',
            'Ophaalvoorstel gedaan',
            'Ophaalvoorstel geen reactie',
            'Ophalen ingepland',
            'Opgehaald',
            'Aan het reinigen'
        };

        Set<String> delivery = new Set<String>{
            'Terugbrengen plannen',
            'Aflevervoorstel gedaan',
            'Terugbrengen ingepland',
            'Teruggebracht'
        };

        if (pickup.contains(status)) {
            return 'pickup';
        }
        if (delivery.contains(status)) {
            return 'delivery';
        }
        return null;
    }

    private static Boolean isStatusSchedulable(String status) {
        Set<String> schedulable = new Set<String>{
            'Ophalen plannen',
            'Ophaalvoorstel gedaan',
            'Ophaalvoorstel geen reactie',
            'Terugbrengen plannen',
            'Aflevervoorstel gedaan'
        };
        return schedulable.contains(status);
    }

    private static String getProposalStatus(String currentStatus) {
        if (currentStatus == 'Ophalen plannen') {
            return 'Ophaalvoorstel gedaan';
        }
        if (currentStatus == 'Terugbrengen plannen') {
            return 'Aflevervoorstel gedaan';
        }
        return null;
    }

    private static String getScheduledStatus(String currentStatus) {
        if (currentStatus == 'Ophalen plannen' ||
            currentStatus == 'Ophaalvoorstel gedaan' ||
            currentStatus == 'Ophaalvoorstel geen reactie') {
            return 'Ophalen ingepland';
        }
        if (currentStatus == 'Terugbrengen plannen' ||
            currentStatus == 'Aflevervoorstel gedaan') {
            return 'Terugbrengen ingepland';
        }
        return null;
    }

    private static List<OptionDto> buildOptions(Werk_Order__c wo) {
        List<OptionDto> options = new List<OptionDto>();

        if (!String.isBlank(wo.Route_Optie_1__c)) {
            options.add(buildOption(1, wo.Route_Optie_1__c));
        }
        if (!String.isBlank(wo.Route_Optie_2__c)) {
            options.add(buildOption(2, wo.Route_Optie_2__c));
        }
        if (!String.isBlank(wo.Route_Optie_3__c)) {
            options.add(buildOption(3, wo.Route_Optie_3__c));
        }

        return options;
    }

    private static OptionDto buildOption(Integer id, String value) {
        OptionDto opt = new OptionDto();
        opt.id = id;
        opt.label = value;
        opt.raw = value;
        return opt;
    }
}
