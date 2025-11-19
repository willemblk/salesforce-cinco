public class TriggerRecursionGuard {
    
    private static Set<String> runningTriggers = new Set<String>();
    
    public static Boolean isRunning(String triggerName) {
        return runningTriggers.contains(triggerName);
    }
    
    public static void setRunning(String triggerName) {
        runningTriggers.add(triggerName);
    }
    
    public static void setNotRunning(String triggerName) {
        runningTriggers.remove(triggerName);
    }
    
    public static void reset() {
        runningTriggers.clear();
    }
}