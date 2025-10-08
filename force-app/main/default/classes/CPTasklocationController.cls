public with sharing class CPTasklocationController {
    // @AuraEnabled
    // public static void updateTaskLocation(Id taskId, Decimal latitude, Decimal longitude) {
    //     Task taskToUpdate = [SELECT Id, CP_Meeting_Address__Latitude__s, CP_Meeting_Address__Longitude__s 
    //                          FROM Task WHERE Id = :taskId LIMIT 1];
    //     taskToUpdate.CP_Meeting_Address__Latitude__s = latitude;
    //     taskToUpdate.CP_Meeting_Address__Longitude__s = longitude;
    //     update taskToUpdate;
    // }
    @AuraEnabled
    public static void updateTaskLocation(Id taskId, Decimal latitude, Decimal longitude) {
        // Get the sObject type dynamically
        String objectType = taskId.getSObjectType().getDescribe().getName();

        // Check if it’s a supported object (Task or Event)
        if (objectType == 'Task' || objectType == 'Event') {
            // Build a dynamic query
            String query = 'SELECT Id, CP_Meeting_Address__Latitude__s, CP_Meeting_Address__Longitude__s ' +
                        'FROM ' + objectType + ' WHERE Id = :taskId LIMIT 1';
            SObject recordToUpdate = Database.query(query);
            
            recordToUpdate.put('CP_Meeting_Address__Latitude__s', latitude);
            recordToUpdate.put('CP_Meeting_Address__Longitude__s', longitude);
            
            update recordToUpdate;
        } else {
            throw new AuraHandledException('Unsupported object type: ' + objectType);
        }
    }
    @AuraEnabled(cacheable=true)
    public static Task getTaskById(Id taskId) {
        // Ensure the fields are accessible and are queried
        return [SELECT CP_Meeting_Address__Latitude__s, CP_Meeting_Address__Longitude__s,Status
                FROM Task
                WHERE Id = :taskId
                LIMIT 1];
    }
}