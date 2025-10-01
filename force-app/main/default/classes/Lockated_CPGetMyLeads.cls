@RestResource(urlMapping='/cpGetMyLeads/*')
global without sharing class Lockated_CPGetMyLeads {
    
    @HttpGet
    global static void doGet() {
       RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String cpId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        Map<String, Object> errorResult = new Map<String, Object>();
        if(String.isBlank(cpId)){
            errorResult.put('status', 'error');
            errorResult.put('message', 'Please pass valid CP Id');
            res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
            res.statusCode = 400;
        }else{
            try{
                ResponseWrapper resp = new ResponseWrapper();
                Id CPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Channel Partner').getRecordTypeId();
                Id TempCPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Temp Channel Partner').getRecordTypeId();                
                list<Broker__c> brlist = [Select Id,RecordTypeId from Broker__c where Id =: cpId];
                if(!brlist.isEmpty()){
                    list<LeadDetails> ActiveLeadDetailslist = new list<LeadDetails>();
                    list<LeadDetails> InactiveLeadDetailslist = new list<LeadDetails>();
                    list<SiteVisitDetails> SiteVisitDetailslist = new list<SiteVisitDetails>();
                    list<BookingDetails> BookingDetailslist = new list<BookingDetails>();
                    if(brlist[0].RecordTypeId == CPRecordTypeId){
                        //Active and Inactive Leads
                        list<lead> leadlist = [Select Id,Name,RW_Mobile_No__c,Email,RW_Project__c,RW_Project__r.Name,Proposed_Visit_Date__c,IsActive__c FROM Lead where 
                                               (Walkin_Channel_Partner__c = :cpId OR RW_Broker__c =: cpId)
                                               AND (LeadSource = 'Channel Partner' OR Walkin_Source__c = 'Channel Partner') ];
                        if(!leadlist.isEmpty()){
                            for(Lead l1 : leadlist ){
                                if(l1.IsActive__c){
                                    LeadDetails l = new LeadDetails();
                                    l.name = l1.Name;
                                    l.mobile = l1.RW_Mobile_No__c;
                                    l.email = l1.Email;
                                    l.project = l1.RW_Project__r.Name;
                                    l.siteVisitDate = Date.valueof(l1.Proposed_Visit_Date__c);
                                    ActiveLeadDetailslist.add(l);
                                }else{
                                    LeadDetails l = new LeadDetails();
                                    l.name = l1.Name;
                                    l.mobile = l1.RW_Mobile_No__c;
                                    l.email = l1.Email;
                                    l.project = l1.RW_Project__r.Name;
                                    l.siteVisitDate = Date.valueof(l1.Proposed_Visit_Date__c);
                                    InactiveLeadDetailslist.add(l);
                                }
                                
                            }
                        }
                        
                        //Site Visits
                        list<Opportunity> opplist = [Select Id,Name,StageName,RW_Mobile_No__c,RW_Email__c,RW_Project__r.Name,Date_Of_Visit__c FROM Opportunity where
                                                     RW_Walkin_Channel_Partner__c  = : cpId 
                                                     AND Walkin_Source__c  = 'Channel Partner'
                                                     AND StageName = 'Site Visit'];
                        if(!opplist.isEmpty()){
                            for(Opportunity o : opplist ){
                                SiteVisitDetails sv = new SiteVisitDetails();
                                sv.oppId = o.id;
                                sv.status = o.StageName;
                                sv.name = o.Name;
                                sv.mobile = o.RW_Mobile_No__c;
                                sv.email = o.RW_Email__c;
                                sv.project = o.RW_Project__r.Name;
                                sv.siteVisitDate = o.Date_Of_Visit__c;
                                SiteVisitDetailslist.add(sv);
                            }
                        }
                        
                        //Bookings
                        list<Booking__c> blist = [SELECT Id,Name,Booking_Date__c,Source_of_Booking__c,Status__c,Project__r.Name,Opportunity__r.Name
                                                     FROM Booking__c where 
                                                     Source_of_Booking__c ='Channel Partner'  and BrokerIId__c =: cpId Order by CreatedDate Desc];
                        if(!blist.isEmpty()){
                            for(Booking__c b1 : blist ){
                                BookingDetails b = new BookingDetails();
                                b.bookingId = b1.id;
                                b.status = b1.Status__c;
                                b.bookingdate = Date.valueof(b1.Booking_Date__c);
                                b.project = b1.Project__r.Name;
                                BookingDetailslist.add(b);
                            }
                        }
                        
                        
                        
                    } else if(brlist[0].RecordTypeId == TempCPRecordTypeId){
                        //Active and Inactive Leads
                        list<lead> leadlist = [Select Id,Name,RW_Mobile_No__c,Email,RW_Project__c,RW_Project__r.Name,Proposed_Visit_Date__c,IsActive__c FROM Lead where 
                                               (Walkin_Channel_Partner__c = :cpId OR RW_Broker__c =: cpId)
                                               AND (LeadSource = 'Temp Channel Partner' OR Walkin_Source__c = 'Temp Channel Partner')];
                        if(!leadlist.isEmpty()){
                            for(Lead l1 : leadlist ){
                                if(l1.IsActive__c){
                                    LeadDetails l = new LeadDetails();
                                    l.name = l1.Name;
                                    l.mobile = l1.RW_Mobile_No__c;
                                    l.email = l1.Email;
                                    l.project = l1.RW_Project__r.Name;
                                    l.siteVisitDate = Date.valueof(l1.Proposed_Visit_Date__c);
                                    ActiveLeadDetailslist.add(l);
                                }else{
                                    LeadDetails l = new LeadDetails();
                                    l.name = l1.Name;
                                    l.mobile = l1.RW_Mobile_No__c;
                                    l.email = l1.Email;
                                    l.project = l1.RW_Project__r.Name;
                                    l.siteVisitDate = Date.valueof(l1.Proposed_Visit_Date__c);
                                    InactiveLeadDetailslist.add(l);
                                }
                            }
                        }
                        
                        //Site Visits
                        list<Opportunity> opplist = [Select Id,Name,StageName,RW_Mobile_No__c,RW_Email__c,RW_Project__r.Name,Date_Of_Visit__c FROM Opportunity where
                                                     RW_Walkin_Channel_Partner__c  = : cpId 
                                                     AND Walkin_Source__c  = 'Temp Channel Partner'
                                                     AND StageName = 'Site Visit'];
                        if(!opplist.isEmpty()){
                            for(Opportunity o : opplist ){
                                SiteVisitDetails sv = new SiteVisitDetails();
                                sv.oppId = o.id;
                                sv.status = o.StageName;
                                sv.name = o.Name;
                                sv.mobile = o.RW_Mobile_No__c;
                                sv.email = o.RW_Email__c;
                                sv.project = o.RW_Project__r.Name;
                                sv.siteVisitDate = o.Date_Of_Visit__c;
                                SiteVisitDetailslist.add(sv);
                            }
                        }
                        
                        //Bookings
                        list<Booking__c> blist = [SELECT Id,Name,Booking_Date__c,Source_of_Booking__c,Status__c,Project__r.Name,Opportunity__r.Name
                                                     FROM Booking__c where 
                                                     Source_of_Booking__c ='Temp Channel Partner'  and BrokerIId__c =: cpId Order by CreatedDate Desc];
                        if(!blist.isEmpty()){
                            for(Booking__c b1 : blist ){
                                BookingDetails b = new BookingDetails();
                                b.bookingId = b1.id;
                                b.status = b1.Status__c;
                                b.bookingdate = Date.valueof(b1.Booking_Date__c);
                                b.project = b1.Project__r.Name;
                                BookingDetailslist.add(b);
                            }
                        }
                    }
                    
                    resp.activeLeadDetails = ActiveLeadDetailslist;
                    resp.inactiveLeadDetails = InactiveLeadDetailslist;
                    resp.siteVisitDetails = SiteVisitDetailslist;
                    resp.bookingDetails = BookingDetailslist;
                    res.responseBody = Blob.valueOf(JSON.serialize(resp));
                    res.statusCode = 200;
                }else{
                    errorResult.put('status', 'error');
                    errorResult.put('message', 'No CP found with this ID');
                    res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                    res.statusCode = 400;
                }
                //return details;
                res.responseBody = Blob.valueOf(JSON.serialize(resp));
                res.statusCode = 200;
            }catch(exception e){
                errorResult.put('status', 'error');
                errorResult.put('message', e.getMessage() + ';  ' + e.getStackTraceString());
                res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                res.statusCode = 400;
            }
            
        }
    }
    
    global class ResponseWrapper {
        public list<LeadDetails> activeLeadDetails;
        public list<LeadDetails> inactiveLeadDetails;
        public list<SiteVisitDetails> siteVisitDetails;
        public list<BookingDetails> bookingDetails;
    }
    
    public class LeadDetails{
        public String name;
        public String mobile;
        public String email;
        public String project;
        public Date siteVisitDate;
        public String inviteCode;//Clearify Needed.
    }
    
    
    public class SiteVisitDetails{
        public String oppId;
        public String status;
        public String name;
        public String mobile;
        public String email;
        public String project;
        public Date siteVisitDate;
    }
    
    public class BookingDetails{
        public String bookingId;
        public String project;
        public Date bookingdate;
        public String status;
    }
    
}