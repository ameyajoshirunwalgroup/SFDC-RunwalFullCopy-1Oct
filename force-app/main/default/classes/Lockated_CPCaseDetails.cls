@RestResource(urlMapping='/cpCaseDetails/*')
global without sharing class Lockated_CPCaseDetails {
	
    @HttpGet
    global static void checkCaseDetails() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        res.addHeader('Content-Type', 'application/json');

        FinalResponse finalResponse = new FinalResponse();
        
        try {
            // Get brokerId parameter
            String brokerId = req.params.get('brokerId');
            
            // Validate input
            if (String.isBlank(brokerId)) {
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(new ErrorResponse('Missing required parameter: brokerId')));
                return;
            }

            // Fetch related Cases
            List<Case> brokerCases = [
                SELECT CaseNumber, Subject, Status, Opportunity__r.Name,
                       Case_Category__c, Case_Sub_Category__c, CreatedDate, Description
                FROM Case
                WHERE Opportunity__r.RW_Broker__c = :brokerId
                ORDER BY CreatedDate DESC limit 5
            ];

            // If no records found
            if (brokerCases.isEmpty()) {
                res.statusCode = 404;
                res.responseBody = Blob.valueOf(JSON.serialize(new ErrorResponse('No cases found for the provided brokerId.')));
                return;
            }

            // Dynamic status mapping
            Map<String, List<CaseResponse>> statusMap = new Map<String, List<CaseResponse>>();
            List<CaseResponse> allCases = new List<CaseResponse>();

            for (Case c : brokerCases) {
                CaseResponse caseRes = new CaseResponse();
                caseRes.caseNumber = c.CaseNumber;
                caseRes.subject = c.Subject;
                caseRes.status = c.Status;
                caseRes.opportunityName = c.Opportunity__r != null ? c.Opportunity__r.Name : null;
                caseRes.caseCategory = c.Case_Category__c;
                caseRes.caseSubCategory = c.Case_Sub_Category__c;
                caseRes.createdDate = c.CreatedDate;
                caseRes.description = (c.Description != null && c.Description.length() > 1000)
                    ? c.Description.substring(0, 1000) + '...'
                    : c.Description;

                // Add to All list
                allCases.add(caseRes);

                // Add to dynamic status list
                if (!statusMap.containsKey(c.Status)) {
                    statusMap.put(c.Status, new List<CaseResponse>());
                }
                statusMap.get(c.Status).add(caseRes);
            }

            //Add "All" category separately
            statusMap.put('All', allCases);

            //Create category list dynamically (sorted alphabetically, All first)
            List<String> categoryList = new List<String>{'All'};
            for (String key : statusMap.keySet()) {
                if (key != 'All') categoryList.add(key);
            }

            //Final response
            finalResponse.category = categoryList;
            finalResponse.tickets = statusMap;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(finalResponse));
        } 
        catch (Exception e) {
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new ErrorResponse('Unexpected error occurred: ' + e.getMessage())));
        }
    }

    //Wrapper for final response
    global class FinalResponse {
        public List<String> category;
        public Map<String, List<CaseResponse>> tickets;
    }

    //Wrapper for case data
    global class CaseResponse {
        public String caseNumber;
        public String subject;
        public String status;
        public String opportunityName;
        public String caseCategory;      
        public String caseSubCategory;  
        public Datetime createdDate;  
        public String description;
    }

    //Wrapper for error response
    global class ErrorResponse {
        public String message;
        public ErrorResponse(String msg) {
            this.message = msg;
        }
    }
}