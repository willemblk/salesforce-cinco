trigger WerkOrderTokenTrigger on Werk_Order__c (before insert, before update) {
    if (TriggerRecursionGuard.isRunning('WerkOrderTokenTrigger')) {
        return;
    }

    TriggerRecursionGuard.setRunning('WerkOrderTokenTrigger');
    try {
        WerkOrderTokenService.ensureTokens(Trigger.new);
    } finally {
        TriggerRecursionGuard.setNotRunning('WerkOrderTokenTrigger');
    }
}
