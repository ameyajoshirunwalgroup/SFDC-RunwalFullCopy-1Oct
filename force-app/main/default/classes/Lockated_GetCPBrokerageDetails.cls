@RestResource(urlMapping='/cpGetBrokerageDetails/*')
global without sharing class Lockated_GetCPBrokerageDetails {
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
                list<InvDetails> blist = new list<InvDetails>();
                list<InvDetails> llist = new list<InvDetails>();
                list<InvDetails> alist = new list<InvDetails>();
                Details details = new Details();
                Decimal totalPaid = 0;
                Decimal Base = 0;
                Decimal Ladder = 0;
                Decimal AOP = 0;
                list<Brokerage_Invoice__c> invlist = [Select id,Booking__c,Invoice_Amount__c,Total_Amount_Paid__c,Brokerage_Lookup__r.Brokerage_Type__c,
                                                      Customer_Name__c,Project__c,Total_Agreement_Value__c,Brokerage_In_Rs__c,Invoice_Date__c,Invoice_Number__c                                                   
                                                      from Brokerage_Invoice__c  where Channel_Partner__c =: cpId and Status__c = 'Paid' and SAP_Document_No__c != null];
                if(!invlist.isEmpty()){                    
                    for(Brokerage_Invoice__c i : invlist){
                        InvDetails b = new InvDetails();
                        InvDetails l = new InvDetails();
                        InvDetails a = new InvDetails();
                        totalPaid += i.Total_Amount_Paid__c;
                        if(i.Brokerage_Lookup__r.Brokerage_Type__c == 'Base Brokerage'){                            
                            assignInvDetails(b,i);
                            blist.add(b);          
                            
                            Base += i.Total_Amount_Paid__c;
                        } else if(i.Brokerage_Lookup__r.Brokerage_Type__c == 'Additional Brokerage'){
                            assignInvDetails(l,i);
                            llist.add(l);  
                            
                            Ladder += i.Total_Amount_Paid__c;
                        } 
                    }
                    system.debug('blist - '+blist);
                    system.debug('llist - '+llist);
                    details.BaseDetails = blist;
                    details.LadderDetails = llist;
                    resp.totalPaid = totalPaid;
                    resp.Base = Base;
                    resp.Ladder = Ladder;
                    resp.AOP = AOP;
                    resp.details = details;
                    res.responseBody = Blob.valueOf(JSON.serialize(resp));
                    res.statusCode = 200;
                }
                
              
            }catch(exception e){
                errorResult.put('status', 'error');
                errorResult.put('message', e.getMessage() + ';  ' + e.getStackTraceString());
                res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
                res.statusCode = 400;
            }
            
        }
    }
    
    private static void assignInvDetails(InvDetails i, Brokerage_Invoice__c b){
        i.customerName = b.Customer_Name__c;
        i.projectName = b.Project__c;
        i.avValueForBrokerage = b.Total_Agreement_Value__c;
        i.brokerageAmount = b.Brokerage_In_Rs__c;
        i.paidDate = b.Invoice_Date__c;
        i.invoiceNo = b.Invoice_Number__c;
        i.statementUrl = null;
    }
    
    global class ResponseWrapper {
        public decimal invoiceStatus;
        public decimal totalPaid;
        public decimal base;
        public decimal ladder;
        public decimal aop;
        public Details details;        
    }
    
    public class Details{
        public list<InvDetails> BaseDetails;
        public list<InvDetails> LadderDetails;
        public list<InvDetails> AOPDetails;
    }
    
    public class InvDetails{
        public String customerName;
        public String projectName;
        public Decimal avValueForBrokerage;
        public Decimal brokerageAmount;
        public Date paidDate;
        public String invoiceNo;
        public String statementUrl;
    }
    
    
    public class Ladder{
        public String ladderSchemeName;
        public String projectName;
        public String startDate;
        public String endDate;
        public String bookingsEligible;
        public Decimal brokerageAmount;
        public Date paidDate;
        public String statementUrl;
    }
    
    public class AOP{
        public String fyOfAopScheme;
        public String aopAmount;
        public String achievedRevenue;
        public String runwalEntity;
        public String avForBrokerageInEntity;
        public String brokerageAmount;
        public Date paidDate;
        public String statementUrl;
    }
    
}