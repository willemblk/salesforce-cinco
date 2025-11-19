List<Schema.PicklistEntry> entries = Schema.SObjectType.Lead.fields.getMap().get('Status').getDescribe().getPicklistValues();
for (Schema.PicklistEntry entry : entries) {
    System.debug(entry.getValue() + ' | ' + entry.getLabel() + ' | default=' + entry.isDefaultValue());
}
