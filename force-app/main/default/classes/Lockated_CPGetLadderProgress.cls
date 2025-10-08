@RestResource(urlMapping='/cpGetLadderProgress/*')
global without sharing class Lockated_CPGetLadderProgress {
    @HttpGet
    global static void doGet() {
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
                list<Booking__c> blist = [Select id,Brokerage_Scheme__c,Status__c,Additional_Brokerage_Accrued_Dashboards__c,Base_Brokerage_Accrued_Dashboards__c from Booking__c where 
                                          BrokerIId__c =: cpId and Status__c = 'Booking Confirmed' and Source_of_Booking__c ='Channel Partner' and 
                                          Brokerage_Scheme__c != null order by CreatedDate desc];
                Map<String,list<Booking__c>> schIdVsBkMap = new Map<String,list<Booking__c>>();
                list<Brokerage_Slab__c> bslist = [Select Id,Name,Brokerage_Scheme__c,Brokerage_Scheme__r.Slab_Type__c,To__c,From__c,Brokerage_Scheme__r.Type__c,Total_Brokerage_for_Local_Bookings__c,Total_Brokerage_for_OS_NRI__c from Brokerage_Slab__c where Brokerage_Scheme__r.Approval_Status__c = 'Approved by Level 2' order by Brokerage_Scheme__c , From__c];
                list<Brokerage_scheme__c> bschlist =  [Select Id from Brokerage_Scheme__c where Approval_Status__c = 'Approved by Level 2' and Id ='a2aJ40000008kfWIAQ' order by createddate desc];
                Map<String,list<Brokerage_Slab__c>> schIdVsBrkSlabMap = new Map<String,list<Brokerage_Slab__c>>();
                for(Brokerage_Scheme__c bs :bschlist){
                    //Assign scheme vs Bookings in Map
                    schIdVsBkMap.put(bs.Id,new list<Booking__c>());  
                    schIdVsBrkSlabMap.put(bs.Id,new list<Brokerage_Slab__c>()); 
                    for(Booking__c b : blist){
                        if(b.Brokerage_Scheme__c == bs.Id){
                            schIdVsBkMap.get(bs.Id).add(b);
                        }
                    }
                    //Assigning scheme vs Brokerage Slabs Map
                    for(Brokerage_Slab__c br : bslist){
                        if(br.Brokerage_Scheme__c == bs.Id){
                            schIdVsBrkSlabMap.get(bs.Id).add(br);
                        }
                    }
                    
                }
                
                for(String key : schIdVsBkMap.keyset()){
                    system.debug('Bookings ->>>> '+ 'Key -> '+ key + ' Value -> '+schIdVsBkMap.get(key).size());
                    system.debug('Brokerage Slabs ->>>> '+ 'Key -> '+ key + ' Value -> '+schIdVsBrkSlabMap.get(key));                    
                    Decimal Earnedsofar = 0;
                    for(Booking__c b : schIdVsBkMap.get(key)){
                        Decimal TotalBrokerageEarned = (b.Base_Brokerage_Accrued_Dashboards__c != null ? b.Base_Brokerage_Accrued_Dashboards__c : 0) + (b.Additional_Brokerage_Accrued_Dashboards__c != null ? b.Additional_Brokerage_Accrued_Dashboards__c : 0);
                        Earnedsofar += TotalBrokerageEarned;
                        //system.debug('Base_Brokerage_Accrued_Dashboards__c -> '+b.Base_Brokerage_Accrued_Dashboards__c);
                        //system.debug('Additional_Brokerage_Accrued_Dashboards__c -> '+b.Additional_Brokerage_Accrued_Dashboards__c);
                    }
                    system.debug('Earned So Far ->>> '+Earnedsofar);
                    Brokerage_Slab__c currentSlab;
                    Brokerage_Slab__c nextSlab;
                    Brokerage_Slab__c topSlab = schIdVsBrkSlabMap.get(key)[schIdVsBrkSlabMap.get(key).size() - 1];
                    if(schIdVsBrkSlabMap.get(key)[0].Brokerage_Scheme__r.Slab_Type__c == 'Count'){                       
                        
                        for(Integer i = 0; i < schIdVsBrkSlabMap.get(key).size(); i++) {
                            Brokerage_Slab__c slab = schIdVsBrkSlabMap.get(key)[i];
                            
                            if(slab.From__c <= schIdVsBkMap.get(key).size() && (slab.To__c == null || slab.To__c >= schIdVsBkMap.get(key).size())) {
                                currentSlab = slab;
                                
                                if(i + 1 < schIdVsBrkSlabMap.get(key).size()) {
                                    nextSlab = schIdVsBrkSlabMap.get(key)[i + 1];
                                }
                                break;
                            }
                        }
                        
                        //Current Slab
                        Decimal currentSlabBrokerage;
                        if (currentSlab.Brokerage_Scheme__r.Type__c == 'Local') {
                            currentSlabBrokerage = currentSlab.Total_Brokerage_for_Local_Bookings__c;
                        } else if (currentSlab.Brokerage_Scheme__r.Type__c == 'NRI') {
                            currentSlabBrokerage = currentSlab.Total_Brokerage_for_OS_NRI__c;
                        } else if (currentSlab.Brokerage_Scheme__r.Type__c == 'Both') {
                            currentSlabBrokerage = (currentSlab.Total_Brokerage_for_Local_Bookings__c != null) ? currentSlab.Total_Brokerage_for_Local_Bookings__c : currentSlab.Total_Brokerage_for_OS_NRI__c;
                        }
                        
                        //Next Slab
                        Decimal nextSlabBrokerage;
                        if (nextSlab.Brokerage_Scheme__r.Type__c == 'Local') {
                            nextSlabBrokerage = nextSlab.Total_Brokerage_for_Local_Bookings__c;
                        } else if (nextSlab.Brokerage_Scheme__r.Type__c == 'NRI') {
                            nextSlabBrokerage = nextSlab.Total_Brokerage_for_OS_NRI__c;
                        } else if (nextSlab.Brokerage_Scheme__r.Type__c == 'Both') {
                            nextSlabBrokerage = (nextSlab.Total_Brokerage_for_Local_Bookings__c != null) ? nextSlab.Total_Brokerage_for_Local_Bookings__c : nextSlab.Total_Brokerage_for_OS_NRI__c;
                        }
                        
                        //Top Slab
                        Decimal topSlabBrokerage;
                        if (topSlab.Brokerage_Scheme__r.Type__c == 'Local') {
                            topSlabBrokerage = topSlab.Total_Brokerage_for_Local_Bookings__c;
                        } else if (topSlab.Brokerage_Scheme__r.Type__c == 'NRI') {
                            topSlabBrokerage = topSlab.Total_Brokerage_for_OS_NRI__c;
                        } else if (topSlab.Brokerage_Scheme__r.Type__c == 'Both') {
                            topSlabBrokerage = (topSlab.Total_Brokerage_for_Local_Bookings__c != null) ? topSlab.Total_Brokerage_for_Local_Bookings__c : topSlab.Total_Brokerage_for_OS_NRI__c;
                        }
                        
                        system.debug('Current :  ' + schIdVsBkMap.get(key).size() + ' Bookings - ' + currentSlabBrokerage + '% Brokerage');
                        system.debug('Next :  ' + 'Do ' + (nextSlab.From__c - schIdVsBkMap.get(key).size())  + ' more to reach ' + nextSlabBrokerage + '%');
                        system.debug('Top :  ' + 'Do ' + (topSlab.From__c - schIdVsBkMap.get(key).size())  + ' more to reach ' + topSlabBrokerage + '%');
	                        
                    }
                    if(schIdVsBrkSlabMap.get(key)[0].Brokerage_Scheme__r.Slab_Type__c == 'Value'){
                        Decimal totalAV = 0;
                        for(Booking__c b : schIdVsBkMap.get(key)){
                            totalAV += b.Agreement_Value_for_brokers__c;
                        }
                        
                        for(Integer i = 0; i < schIdVsBrkSlabMap.get(key).size(); i++) {
                            Brokerage_Slab__c slab = schIdVsBrkSlabMap.get(key)[i];
                            
                            if(slab.From__c <= totalAV  && (slab.To__c == null || slab.To__c >= totalAV)) {
                                currentSlab = slab;
                                
                                if(i + 1 < schIdVsBrkSlabMap.get(key).size()) {
                                    nextSlab = schIdVsBrkSlabMap.get(key)[i + 1];
                                }
                                break;
                            }
                        }
                        
                        //Current Slab
                        Decimal currentSlabBrokerage;
                        if (currentSlab.Brokerage_Scheme__r.Type__c == 'Local') {
                            currentSlabBrokerage = currentSlab.Total_Brokerage_for_Local_Bookings__c;
                        } else if (currentSlab.Brokerage_Scheme__r.Type__c == 'NRI') {
                            currentSlabBrokerage = currentSlab.Total_Brokerage_for_OS_NRI__c;
                        } else if (currentSlab.Brokerage_Scheme__r.Type__c == 'Both') {
                            currentSlabBrokerage = (currentSlab.Total_Brokerage_for_Local_Bookings__c != null) ? currentSlab.Total_Brokerage_for_Local_Bookings__c : currentSlab.Total_Brokerage_for_OS_NRI__c;
                        }
                        
                        //Next Slab
                        Decimal nextSlabBrokerage;
                        if (nextSlab.Brokerage_Scheme__r.Type__c == 'Local') {
                            nextSlabBrokerage = nextSlab.Total_Brokerage_for_Local_Bookings__c;
                        } else if (nextSlab.Brokerage_Scheme__r.Type__c == 'NRI') {
                            nextSlabBrokerage = nextSlab.Total_Brokerage_for_OS_NRI__c;
                        } else if (nextSlab.Brokerage_Scheme__r.Type__c == 'Both') {
                            nextSlabBrokerage = (nextSlab.Total_Brokerage_for_Local_Bookings__c != null) ? nextSlab.Total_Brokerage_for_Local_Bookings__c : nextSlab.Total_Brokerage_for_OS_NRI__c;
                        }
                        
                        //Top Slab
                        Decimal topSlabBrokerage;
                        if (topSlab.Brokerage_Scheme__r.Type__c == 'Local') {
                            topSlabBrokerage = topSlab.Total_Brokerage_for_Local_Bookings__c;
                        } else if (topSlab.Brokerage_Scheme__r.Type__c == 'NRI') {
                            topSlabBrokerage = topSlab.Total_Brokerage_for_OS_NRI__c;
                        } else if (topSlab.Brokerage_Scheme__r.Type__c == 'Both') {
                            topSlabBrokerage = (topSlab.Total_Brokerage_for_Local_Bookings__c != null) ? topSlab.Total_Brokerage_for_Local_Bookings__c : topSlab.Total_Brokerage_for_OS_NRI__c;
                        }
                        system.debug('Current :  ' + totalAV + ' Bookings - ' + currentSlabBrokerage + '% Brokerage');
                        system.debug('Next :  ' + 'Do ' + (nextSlab.From__c - totalAV)  + ' more to reach ' + nextSlabBrokerage + '%');
                        system.debug('Top :  ' + 'Do ' + (topSlab.From__c - totalAV)  + ' more to reach ' + topSlabBrokerage + '%');   
                    }
                }
                
            }catch(exception e){
                errorResult.put('status', 'error');
                errorResult.put('message', e.getMessage() + ';  ' + e.getStackTraceString());
                res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                res.statusCode = 500;
            }
            
        }
    }
    
    public class resWrapper{
        public list<LadderDetails> ladderDetails;
    }
    
    public class LadderDetails{
        public String schemeName;
        public String startDate;
        public String endDate;
        public String type;
        public list<BookingDetails> bookingDetails;
    }
    
    public class BookingDetails{
        public CustomerDetails customerDetails;
        public BookingSummary bookingSummary;
        public FinancialDetails financialDetails;
    }
    
    public class CustomerDetails{
        public String name;
        public String contactNo;
        public String emailId;
        public String coApplicantName;
    }
    
    public class BookingSummary{
        public String projectName;
        public String unit;
        public String bookingDate;
        public String bookingId;
        public String status;
    }
    
    public class FinancialDetails{
        public Decimal agreementValue;
        public Decimal percentagePaid;
        public String registrationStatus;
        public String brokerageStatus;///????
    }
        
}