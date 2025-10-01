@RestResource(urlMapping='/cpGetPicklistValues/*')
global without sharing class Lockated_CPGetPicklistValues {
    
    @HttpGet
    global static ResponseWrapper doGet() {
        ResponseWrapper res = new ResponseWrapper();

        //Get Projects
        /*if (data == 'getProjects') {
            for (Project__c proj : [SELECT Name FROM Project__c WHERE RW_Status__c = 'Active']) {
                res.values.add(proj.Name);
            }
        }*/
        //Get CP Type
        res.getCPType = getPicklistValues('Broker__c', 'Broker_Type__c');
        //Get Experience Values
        res.getCPExperiences = getPicklistValues('Broker__c', 'Experience__c');
        //Get Operation Place Values
        res.getCPOperationPlaces = getPicklistValues('Broker__c', 'Place_of_Supply__c');
        //Get Expertise Values
        res.getCPExpertise = getPicklistValues('Broker__c', 'Expertise__c');
        //Get Developers Worked For Values
        res.getDevelopersWorkedFor = getPicklistValues('Broker__c', 'Developers_Worked_For__c');
        //Get Bank Names
        res.getBankNames = getPicklistValues('Broker__c', 'Bank_Name__c');
        
        return res;
    }
    
    global class ResponseWrapper {
        //public String getProjects;
        public list<String> getCPType;
        public list<String> getCPExperiences;
        public list<String> getCPOperationPlaces;
        public list<String> getCPExpertise;
		public list<String> getDevelopersWorkedFor;
        public list<String> getBankNames;
    }
    
    private static List<String> getPicklistValues(String objectName, String fieldName) {
        Schema.DescribeFieldResult fieldDescribe =
            Schema.getGlobalDescribe().get(objectName)
                  .getDescribe()
                  .fields.getMap().get(fieldName)
                  .getDescribe();
        
        List<String> results = new List<String>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            results.add(entry.getLabel());
        }
        return results;
    }
}