@RestResource(urlMapping='/cpCustomerAnalytics/*')
global without sharing class Lockated_CPCustomerAnalytics {
    @HttpGet
    global static void doGet()
    {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String cpId = req.params.get('cpId');
        Map<String, Object> errorResult = new Map<String, Object>();
        if(String.isBlank(cpId)){
            errorResult.put('status', 'error');
            errorResult.put('message', 'Please pass valid CP Id');
            res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
            res.statusCode = 400;
        }else{
            try{
                ResponseWrapper resp = new ResponseWrapper();
                list<Broker__c> brs = [Select Id,RecordTypeId from Broker__c where Id =: cpId limit 1];  
                Id CPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Channel Partner').getRecordTypeId();
                Id TempCPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Temp Channel Partner').getRecordTypeId();
                if(!brs.isEmpty()){
                    list<Opportunity> olist = [Select id,Budget_In_Cr__c,Zone__c from Opportunity  where RW_Walkin_Channel_Partner__c =: cpId and Budget_In_Cr__c != null ];
                    if(!olist.isEmpty()){
                        Decimal avgClientBudget = 0;
                        for(Opportunity o:olist){
                            if(brs[0].RecordTypeId == CPRecordTypeId){
                                resp.totalWalkIns += 1;
                                avgClientBudget += o.Budget_In_Cr__c;
                            }else if(brs[0].RecordTypeId == TempCPRecordTypeId){
                                resp.totalWalkIns += 1;
                                avgClientBudget += o.Budget_In_Cr__c;
                            }
                        }
                        resp.avgClientBudget = (avgClientBudget / resp.totalWalkIns).setScale(0, RoundingMode.HALF_UP);

                    }else{
                        errorResult.put('status', 'error');
                        errorResult.put('message', 'No Customer Records Found');
                        res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                        res.statusCode = 400;
                    }
                    list<Booking__c> blist = [Select id from Booking__c where BrokerIId__c =: cpId ];
                    if(!blist.isEmpty()){
                        for(Booking__c b : blist){
                            if(brs[0].RecordTypeId == CPRecordTypeId){
                                resp.totalBookings += 1;
                            }else if(brs[0].RecordTypeId == TempCPRecordTypeId){
                                resp.totalBookings += 1;
                            }
                        }
                    }else{
                        errorResult.put('status', 'error');
                        errorResult.put('message', 'No Booking Records Found');
                        res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                        res.statusCode = 400;
                    }                    
                    res.responseBody = Blob.valueOf(JSON.serialize(resp));
                    res.statusCode = 200;
                }else{
                    errorResult.put('status', 'error');
                    errorResult.put('message', 'No CP Record Found');
                    res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                    res.statusCode = 400;
                }            
            }catch(exception e){
                errorResult.put('status', 'error');
                errorResult.put('message', e.getMessage() + ';  ' + e.getStackTraceString());
                res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                res.statusCode = 400;
            }
        }
    }   
    
    global class ResponseWrapper {
        public Integer totalWalkIns = 0;
        public Integer totalBookings = 0;
        public Decimal avgClientBudget = 0;
        public String activeZones;//??
    } 
}