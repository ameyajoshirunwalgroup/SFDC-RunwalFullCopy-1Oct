public class trgOppHandler {

    public static void addAopTypeAndCpCategory(List<Opportunity> cpOppList){
        
        Set<String> projects = new Set<String>();
        Set<String> cps = new Set<String>();
        for(Opportunity opp : cpOppList){
            projects.add(opp.RW_Project__c);
            cps.add(opp.RW_Walkin_Channel_Partner__c);
        }
        
        //List<CP_Category__c> cpCategoryList = [SELECT Id,Name,Category__c,Channel_Partner__c,Project__c FROM CP_Category__c WHERE Project__c =: projects AND Channel_Partner__c =: cps AND Category__c != null];
        Map<String,String> categoryMap = new Map<String, String>();
        Map<Id, Broker__c> brokers;
        if(cps.size() > 0){
            for(CP_Category__c cat : [SELECT Id,Name,Category__c,Channel_Partner__c,Project__c FROM CP_Category__c WHERE Project__c =: projects AND Channel_Partner__c =: cps AND Category__c != null]){
                categoryMap.put(cat.Project__c + '_' + cat.Channel_Partner__c, cat.Category__c);
            }
            brokers = new Map<Id, Broker__c>([SELECT Id,AOP_Type__c FROM Broker__c WHERE Id =: cps]);
        }
        
               
        for(Opportunity opp : cpOppList){
            if(!categoryMap.isEmpty()){
                opp.CP_Category__c = categoryMap.get(opp.RW_Project__c + '_' + opp.RW_Walkin_Channel_Partner__c);
            }
            if(!brokers.isEmpty() && brokers.get(opp.RW_Walkin_Channel_Partner__c) != null){
                opp.AOP_Type__c = brokers.get(opp.RW_Walkin_Channel_Partner__c).AOP_Type__c;
            }
        }
    }
    
    public static void updateReferralCustDetails(List<Opportunity> refOppList){
        /*
        Set<String> custRefs = new Set<String>();
        for(Opportunity opp : refOppList){
            custRefs.add(opp.RW_Walkin_Customer_Reference__c);
        }
        */
        //List<Opportunity> lstOpp = [Select Id,StageName,RW_Booking_Date_Opp__c, Name,SAP_Customer_Number__c,AccountId,RW_Project_Unit__c /*Customer_Reference_Opportunity__c*/ From Opportunity Where AccountId=: custRefs AND StageName =:'Unit Booked'  ORDER BY RW_Booking_Date_Opp__c DESC ];
        /*Map<String, Opportunity> refOppMap = new Map<String, Opportunity>();
        if(custRefs.size() > 0){
            for(Opportunity opp : [Select Id,StageName,RW_Booking_Date_Opp__c, Name,SAP_Customer_Number__c,AccountId,RW_Project_Unit__c,Customer_Reference_Opportunity__c From Opportunity Where AccountId=: custRefs AND StageName =:'Unit Booked'  ORDER BY RW_Booking_Date_Opp__c DESC ]){
                refOppMap.put(opp.AccountId, opp);
            }
        }
        
        for(Opportunity opp : refOppList){
            if(refOppMap.get(opp.RW_Walkin_Customer_Reference__c) != null){
                opp.Customer_reference_SAP_Code__c = refOppMap.get(opp.RW_Walkin_Customer_Reference__c).SAP_Customer_Number__c;
                opp.Customer_reference_Booked_Unit__c = refOppMap.get(opp.RW_Walkin_Customer_Reference__c).RW_Project_Unit__c;
                opp.Customer_Reference_Opportunity__c = refOppMap.get(opp.RW_Walkin_Customer_Reference__c).Id;
            }
        }*/
        
    }
    
  /*  public static void updateCustRefOpp(Map<Id,Id> oppIdVsrefBookedUnitIds){
        system.debug('Inside updateCustRefOpp');
        Map<Id,Id> custRefUnitIdsVsOppIds = new Map<Id,Id>();
        list<Opportunity> opplist = new list<Opportunity>();
        list<Project_Unit__c> pulist = [Select Id,RW_Customer__c from Project_Unit__c where Id in: oppIdVsrefBookedUnitIds.values()];
        if(!pulist.isEmpty()){
            For(Project_Unit__c pu: pulist){
                custRefUnitIdsVsOppIds.put(pu.Id,pu.RW_Customer__c);
            }
        }
        if(!custRefUnitIdsVsOppIds.isEmpty()){
            system.debug('Inside custRefUnitIdsVsOppIds');
            For(Id oppId : oppIdVsrefBookedUnitIds.keySet()){
                Opportunity opp = new Opportunity();
                opp.Id = oppId;
                opp.Customer_Reference_Opportunity__c = custRefUnitIdsVsOppIds.get(oppIdVsrefBookedUnitIds.get(oppId));
            }
        }
    }*/
    
    // Added by Prashant 01-08-2025 START
    public static void updateCustRefOpp(Map<Id, Id> oppIdVsrefBookedUnitIds,Map<Id, Opportunity> newMap) {
        system.debug('Inside updateCustRefOpp');
        Map<Id, Id> custRefUnitIdsVsOppIds = new Map<Id, Id>();
        List<Project_Unit__c> pulist = [SELECT Id, RW_Customer__c  FROM Project_Unit__c WHERE Id IN :oppIdVsrefBookedUnitIds.values()];
        
        for (Project_Unit__c pu : pulist) {
            custRefUnitIdsVsOppIds.put(pu.Id, pu.RW_Customer__c);
        }
        
        for (Id oppId : oppIdVsrefBookedUnitIds.keySet()) {            
            if (custRefUnitIdsVsOppIds.get(oppIdVsrefBookedUnitIds.get(oppId)) != null && newMap.containsKey(oppId)) {
                newMap.get(oppId).Customer_Reference_Opportunity__c = custRefUnitIdsVsOppIds.get(oppIdVsrefBookedUnitIds.get(oppId));
            }
        }
    }
    // Added by Prashant 01-08-2025 END

}