public with sharing class OpportunityToWorkOrderReprocessor implements Queueable {
    private Set<Id> opportunityIds;
    private Integer attempt;

    public OpportunityToWorkOrderReprocessor(Set<Id> opportunityIds, Integer attempt) {
        this.opportunityIds = (opportunityIds == null) ? new Set<Id>() : new Set<Id>(opportunityIds);
        this.attempt = (attempt == null) ? 1 : attempt;
    }

    public void execute(QueueableContext ctx) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }
        // Prepare requests and reuse the converter's idempotent logic
        List<OpportunityToWorkOrderConverter.Request> reqs = new List<OpportunityToWorkOrderConverter.Request>();
        for (Id oppId : opportunityIds) {
            OpportunityToWorkOrderConverter.Request r = new OpportunityToWorkOrderConverter.Request();
            r.opportunityId = oppId;
            reqs.add(r);
        }
        // Run conversion again after commit so OLIs that were not yet present can be processed
        try {
            OpportunityToWorkOrderConverter.runInAsyncReprocessContext(opportunityIds);
        } catch (Exception ex) {
            // Best-effort: do not throw; alternatively, could implement limited retries
        }
    }
}
