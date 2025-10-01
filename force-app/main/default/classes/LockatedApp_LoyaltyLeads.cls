@RestResource(urlMapping='/loyalty/*')
global without sharing class LockatedApp_LoyaltyLeads {
    
    @HttpGet
    global static void doGet(){
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        Map<String, Object> errorResult = new Map<String, Object>();
        String bkgId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        if(String.isBlank(bkgId) || bkgId == 'referrals'){
            errorResult.put('status', 'error');
            errorResult.put('message', 'Please pass valid Booking Id');
            res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
            res.statusCode = 400;
        }else{
            try{
                List<Booking__c> bkg = [SELECT Id, Opportunity__r.Account.Mobile_No__c FROM Booking__c WHERE Id =: bkgId];
                if(bkg.size() > 0){
                    LoyaltyLeads det = new LoyaltyLeads();
                    List<Lead> loyaltyLeads = [SELECT Id, RW_Mobile_No__c,RW_Project__r.Name,RW_Location__c,CreatedDate,RW_Project__r.WhatsApp_Bot_Project_Image_File_Id__c FROM Lead WHERE RW_Mobile_No__c =: bkg[0].Opportunity__r.Account.Mobile_No__c];
                    List<String> projImageIds = new List<String>();
                    for(Lead ld : loyaltyLeads){
                        projImageIds.add(ld.RW_Project__r.WhatsApp_Bot_Project_Image_File_Id__c); 
                    }
                    Map<String, String> projImageLink = new Map<String, String>();
                    if(projImageIds.size() > 0){
                        List<ContentDistribution> distrList = [SELECT Id, Name, DistributionPublicUrl, ContentDocumentId FROM ContentDistribution 
                                                               WHERE ContentDocumentId =: projImageIds];
                        for(ContentDistribution dist : distrList){
                            projImageLink.put(dist.ContentDocumentId, dist.DistributionPublicUrl);
                        }
                    }
                    List<Loyalty> loyaltyList = new List<Loyalty>();
                    for(Lead ld : loyaltyLeads){
                        Loyalty loy = new Loyalty();
                        loy.projectName = ld.RW_Project__r.Name;
                        loy.location = ld.RW_Location__c;
                        loy.enquiredOn = String.valueOf(ld.CreatedDate);
                        loy.imageUrl = projImageLink.get(ld.RW_Project__r.WhatsApp_Bot_Project_Image_File_Id__c);
                        loyaltyList.add(loy);
                    }
                    det.myEnquiries = loyaltyList;
                    //return null;
                    res.responseBody = Blob.valueOf(JSON.serialize(det));
                    res.statusCode = 200;
                }else{
                    errorResult.put('status', 'error');
                    errorResult.put('message', 'Booking record not found');
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
    
    global class LoyaltyLeads{
        public List<Loyalty> myEnquiries;
    }
    
    public class Loyalty{
        public string projectName;
        public string location;
        public string enquiredOn;
        public string imageUrl;
    }
}