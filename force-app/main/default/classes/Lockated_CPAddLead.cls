@RestResource(urlMapping='/cpAddLead/*')
global without sharing class Lockated_CPAddLead {

    // Input Wrapper
    global class LeadInput {
        public String customerName;
        public String mobileNumber;
        public String email;
        public String propertyType;
        public String projectInterested;
        public String cpId;
    }

    // Response Wrapper
    global class LeadResponse {
        public String status;
        public String message;
        public String leadId;
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        LeadResponse response = new LeadResponse();

        try {
            // Deserialize the incoming JSON body
            LeadInput input = (LeadInput)JSON.deserialize(req.requestBody.toString(), LeadInput.class);

            // Validate mandatory fields
            if(String.isBlank(input.customerName) || String.isBlank(input.mobileNumber)) {
                response.status = 'error';
                response.message = 'Customer Name and Mobile Number are required';
                res.statusCode = 400;
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                return;
            }
            List<Broker__c> brlist = [Select Id,RecordTypeId,RecordType.DeveloperName from Broker__c where Id =: input.cpId];
            // Create Lead
            Lead newLead = new Lead();
            newLead.LastName = input.customerName;
            newLead.RW_Mobile_No__c = input.mobileNumber;
            newLead.Email = input.email;
            newLead.RW_Project__c = input.projectInterested;
            newLead.RW_Broker__c = input.cpId;
            if(!brlist.isEmpty() && brlist.size()>0){
                newLead.RW_Broker__c = brlist[0].Id;
                if(brlist[0].RecordType.DeveloperName =='Channel_Partner'){
                 newLead.LeadSource = 'Channel partner';
                }
                if(brlist[0].RecordType.DeveloperName =='Temp_Channel_Partner'){
                 newLead.LeadSource = 'Temp Channel Partner';
                }
                
            }
            

            insert newLead;

            response.status = 'success';
            response.message = 'Lead added successfully';
            response.leadId = newLead.Id;
            res.statusCode = 200; // Created
            res.responseBody = Blob.valueOf(JSON.serialize(response));

        } catch(Exception e) {
            response.status = 'error';
            response.message = e.getMessage();
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(response));
        }
    }
}