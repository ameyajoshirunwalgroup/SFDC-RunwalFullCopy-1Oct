@RestResource(urlMapping='/cpCaseDetails/*')
global without sharing class Lockated_CPCaseDetails {
	
    @HttpGet
    global static List<CaseResponse> checkCaseDetails(){
        
        RestRequest req = RestContext.request;
        String brokerId = req.params.get('brokerId');

        List<CaseResponse> responseList = new List<CaseResponse>();

        if (!String.isBlank(brokerId)) {
            List<Case> brokerCases = [
                SELECT CaseNumber, Subject, Status, Opportunity__r.Name,Case_Category__c,Case_Sub_Category__c,CreatedDate
                FROM Case
                WHERE Opportunity__r.RW_Broker__c = :brokerId
            ];

            for (Case c : brokerCases) {
                CaseResponse res = new CaseResponse();
                res.caseNumber = c.CaseNumber;
                res.subject = c.Subject;
                res.status = c.Status;
                res.opportunityName = c.Opportunity__r.Name;
                res.caseCategory = c.Case_Category__c;           
                res.caseSubCategory = c.Case_Sub_Category__c;   
                res.createdDate = c.CreatedDate;    
                responseList.add(res);
            }
        }

        return responseList; 
		
        
    }
    global class CaseResponse {
        public String caseNumber;
        public String subject;
        public String status;
        public String opportunityName;
        public String caseCategory;      
        public String caseSubCategory;  
        public DateTime createdDate;     
    }
}