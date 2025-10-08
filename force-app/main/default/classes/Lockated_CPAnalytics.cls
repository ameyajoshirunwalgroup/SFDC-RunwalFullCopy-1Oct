@RestResource(urlMapping='/cpAnalytics/*')
global without sharing class Lockated_CPAnalytics {
    @HttpGet
    global static ResponseWrapper doGet(){
        RestRequest req = RestContext.request;
        String cpId = req.params.get('cpId'); 
        if(String.isBlank(cpId))
        	return null;        
        Id CPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Channel Partner').getRecordTypeId();
        Id TempCPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Temp Channel Partner').getRecordTypeId();
        list<Broker__c> brs = [Select Id,RecordTypeId from Broker__c where Id =: cpId limit 1];
        
        // Query active leads
        Integer activeLeadsCount = 0;        
        if(brs[0].RecordTypeId == CPRecordTypeId){
            activeLeadsCount = [
                SELECT COUNT()
                FROM Lead where IsActive__c = true
                and (Walkin_Channel_Partner__c = :cpId OR RW_Broker__c =: cpId)
                AND (LeadSource = 'Channel Partner' OR Walkin_Source__c = 'Channel Partner')                     
            ];
        } else if(brs[0].RecordTypeId == TempCPRecordTypeId){
            activeLeadsCount = [
                SELECT COUNT()
                FROM Lead where IsActive__c = true
                and (Walkin_Channel_Partner__c = :cpId OR RW_Broker__c =: cpId)
                AND (LeadSource = 'Temp Channel Partner' OR Walkin_Source__c = 'Temp Channel Partner')
            ];
        }
        
        // Query Walkin Opportunities
        Integer activeOppsCount = 0;        
        if(brs[0].RecordTypeId == CPRecordTypeId){
            activeOppsCount = [
                SELECT COUNT()
                FROM Opportunity where
                RW_Walkin_Channel_Partner__c  = : cpId 
                AND Walkin_Source__c  = 'Channel Partner'
            ];
        } else if(brs[0].RecordTypeId == TempCPRecordTypeId){
            activeOppsCount = [
                SELECT COUNT()
                FROM Opportunity where
                RW_Walkin_Channel_Partner__c  = : cpId 
                AND Walkin_Source__c  = 'Temp Channel Partner'
            ];
        }
        
        // Query Bookings
        Decimal salesValue = 0;
        Decimal salesValueCurrentYear = 0;
        Integer activeBookingsCount = 0;
        List<SalesDetail> salesDetails = new List<SalesDetail>();
        list<Booking__c> blist = [SELECT Id,Name,Agreement_Value_for_brokers__c,Booking_Date__c,Source_of_Booking__c,Status__c,Unit_Type__c,Unit_No__r.Name,Tower__r.Name,Project__r.Name,Opportunity__r.Name
                                  FROM Booking__c where 
                                  (Source_of_Booking__c ='Channel Partner' OR Source_of_Booking__c ='Temp Channel Partner')  and BrokerIId__c =: cpId Order by CreatedDate Desc];
        if(!blist.isEmpty()){            
            Date today = Date.today();
            Integer year = today.year();
            Integer fyStartYear;
            Integer fyEndYear;
            if (today.month() >= 4) {
                fyStartYear = year;
                fyEndYear   = year + 1;
            } else {
                fyStartYear = year - 1;
                fyEndYear   = year;
            }
            Date fyStartDate = Date.newInstance(fyStartYear, 4, 1);
            Date fyEndDate   = Date.newInstance(fyEndYear, 3, 31); 
            System.debug('FY Start: ' + fyStartDate);
            System.debug('FY End: '   + fyEndDate);
            for(Booking__c b : blist){
                if(brs[0].RecordTypeId == CPRecordTypeId && b.Status__c == 'Booking Confirmed' && b.Source_of_Booking__c =='Channel Partner'){
                    activeBookingsCount += 1;
                    salesValue += b.Agreement_Value_for_brokers__c;
                    if(b.Booking_Date__c >= fyStartDate && b.Booking_Date__c <= fyEndDate ){
                        salesValueCurrentYear += b.Agreement_Value_for_brokers__c;
                    }
                }else if(brs[0].RecordTypeId == TempCPRecordTypeId && b.Source_of_Booking__c == 'Temp Channel Partner'){
                    activeBookingsCount += 1;
                    salesValue += b.Agreement_Value_for_brokers__c;
                    if(b.Booking_Date__c >= fyStartDate && b.Booking_Date__c <= fyEndDate ){
                        salesValueCurrentYear += b.Agreement_Value_for_brokers__c;
                    }
                }
                
                SalesDetail sd = new SalesDetail();
                sd.bookingId = b.Name;
                sd.customerName = (b.Opportunity__c != null) ? b.Opportunity__r.Name : null;
                sd.projectName = (b.Project__c != null) ? b.Project__r.Name : null;
                sd.tower = (b.Tower__c != null) ? b.Tower__r.Name : null;
                sd.unitNo = (b.Unit_No__c != null) ? b.Unit_No__r.Name : null;
                sd.unitType = (b.Unit_Type__c != null) ? b.Unit_Type__c : null;
                sd.bookingDate = Date.valueof(b.Booking_Date__c);
                sd.salesValue = b.Agreement_Value_for_brokers__c;
                salesDetails.add(sd);
            }
        }
        
        ResponseWrapper res = new ResponseWrapper();
        res.summary = new Summary();
        res.summary.noOfActiveLeads = activeLeadsCount;
        res.summary.noOfWalkins = activeOppsCount;
        res.summary.totalBookings = activeBookingsCount;
        res.summary.salesValueCurrentYear = salesValueCurrentYear;
        res.salesDetails = salesDetails;
        
        return res;        
    }
    
    public class Summary {
        public Integer noOfActiveLeads;
        public Integer noOfWalkins;
        public Integer totalBookings;
        public Decimal salesValueCurrentYear;
    }
    
     public class SalesDetail {
        public String bookingId;
        public String customerName; 
        public String projectName;
        public String tower ;
        public String unitNo ;
        public String unitType ;
        public Date bookingDate ;
        public Decimal salesValue;
    }
    
    global class ResponseWrapper {
        public Summary summary;
        public List<SalesDetail> salesDetails;
    }
    
}