@RestResource(urlMapping='/cpRegistrationRERA/*')
global without sharing class Lockated_CPRegistration_RERA {
    
    @HttpGet
    global static String doGet(){
        RestRequest req = RestContext.request;
        String cpId = req.requestURI.substring(req.requestURI.lastIndexOf('/')+1);
        if(String.isBlank(cpId))
        	return null;    
        Map<String, Attachment> attMap = getCPAttachments(cpId);
        return JSON.serialize(attMap);
    }
    
	@HttpPost
    global static String doPost(){                
        RestRequest req = RestContext.request;
        system.debug(req.requestBody);
        String jsonBody = req.requestBody.toString();
        cpRegistrationWrapper data = (cpRegistrationWrapper) JSON.deserialize(jsonBody,cpRegistrationWrapper.class);
        
        Map<String, Object> response = new Map<String, Object>();
        
        // Check if CP already exists with same email or PAN
        List<Broker__c> existing = [SELECT Id, Name, RW_Email__c, Broker_Pan_No__c,RW_Mobile_No__c FROM Broker__c WHERE 
            RW_Email__c = :data.email OR Broker_Pan_No__c = :data.panNo OR RW_Mobile_No__c =: data.phone LIMIT 1];
        
        if (!existing.isEmpty()) {
            response.put('status', 'error');
            response.put('message', 'Partner already exists with this email or PAN');
            return JSON.serialize(response);
        }
        
        //If passed validations, insert Broker__c record 
        Broker__c cp = new Broker__c();        
        cp.RW_Email__c = data.email;
        cp.RW_Mobile_No__c = data.phone;
        cp.Broker_Pan_No__c = data.panNo;
        cp.Company_Name_As_per_RERA__c = data.companyName;
        cp.Name = data.fullName;
        if (data.companyName != null) {
            cp.Name = data.companyName;
        } else {
            cp.Name = data.fullName;
        }
        Id CPRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Channel Partner').getRecordTypeId();
        cp.RecordTypeId = CPRecordTypeId;
        cp.RW_RERA_Registration_Number__c = data.reraRegistrationNumber;
        cp.RERA_Valid_till__c = String.isNotBlank(data.reraValidTill) ? Date.valueOf(data.reraValidTill) : null;
        cp.Broker_Type__c = data.partnerType;
        cp.Project__c = data.projectId;	
        cp.Dialing_Country_Code1__c = data.countryCode;
        cp.RW_Is_CC_Applicable__c = data.competencyCert.hasCompetencyCert;
        if(cp.RW_Is_CC_Applicable__c){
             cp.CC_Valid_till__c = String.isNotBlank(data.competencyCert.ccValidTill) ? Date.valueOf(data.competencyCert.ccValidTill) : null;
        }else{
            cp.CC_Scheduled_Exam_Date__c = String.isNotBlank(data.competencyCert.ccScheduledExamDate) ? Date.valueOf(data.competencyCert.ccScheduledExamDate) : null;
        }
        cp.Is_NRI_CP__c = data.isNri;
        if(cp.Is_NRI_CP__c){
            cp.Are_you_NRI__c = 'Yes';
        }else{
            cp.Are_you_NRI__c = 'No';
        }
        cp.RW_Is_GST_Applicable__c = data.isGstApplicable;
        if(cp.RW_Is_GST_Applicable__c){
            cp.RW_GST_Number__c = data.gstNumber;
        }
        cp.Experience__c = data.experience;
        cp.Place_of_Supply__c = data.operationPlace;
        cp.Team_Size__c = data.teamSize;
        cp.Expertise__c = data.expertise; 
        cp.Developers_Worked_For__c = data.developerWorkedFor;
        cp.House_Flat_Company__c = data.address.houseFlatCompany;
        cp.STREET__c = data.address.streetAddress1;
        cp.STR_SUPPL2__c = data.address.streetAddress2;
        cp.STR_SUPPL3__c = data.address.streetAddress3;
        cp.STR_SUPPL1__c = cp.House_Flat_Company__c + ',' + cp.STREET__c;
        cp.Country__c = data.address.country;
        cp.State__c = data.address.stateRegion;
        cp.City__c = data.address.city;
        cp.Pin_Code__c = data.address.zipPinCode;
        cp.Cheque_DD_Favouring_Name__c = data.bankDetails.chequeDdFavouringName;
        cp.Branch_Code__c = data.bankDetails.branchCode;
        cp.IFSC_Code__c = data.bankDetails.bankAccountIfscCode;
        cp.Account_Number__c = data.bankDetails.bankAccountNumber;
        cp.Bank_Name__c = data.bankDetails.bankName;
        cp.Branch_Code__c = data.bankDetails.branchName;	
        
        list<String> approvers = CPRegisterationController.getApprovers(data.projectId);
        if(!approvers.isEmpty()){
            cp.Approver_L1__c = approvers[0];
            cp.Approver_L2__c = approvers[1];
        }        
        cp.Is_T_C_Accepted__c = true;        
        insert cp;
        
        list<ContentVersion> cvlist = new list<ContentVersion>();
        For(Documents d : data.documents){
            system.debug('Attachment -> '+d.attachment);
            system.debug('fileName -> '+d.fileName);
            system.debug('fileType -> '+d.fileType);
            String base64Data = d.attachment;  
            Blob fileBody = EncodingUtil.base64Decode(base64Data);
            
            ContentVersion cv = new ContentVersion(
                VersionData = fileBody,
                PathOnClient = d.fileName + '.' + d.fileType,
                Title = d.fileName
            );
            cvlist.add(cv);
        }
        system.debug('cvlist -> '+cvlist);
        if(!cvlist.isEmpty()){
            insert cvlist;
            
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();            
            for (ContentVersion cv : [Select Id,ContentDocumentId from ContentVersion where Id =: cvlist]) {
                links.add(new ContentDocumentLink(
                    ContentDocumentId = cv.ContentDocumentId,  // link file
                    LinkedEntityId = cp.id,                    // CP record Id
                    ShareType = 'C',                           // Viewer permission
                    Visibility = 'AllUsers'
                ));
            }            
            insert links;
        }
        
        /*String base64Data = data.attachment;  
        Blob fileBody = EncodingUtil.base64Decode(base64Data);
        
        ContentVersion cv = new ContentVersion(
            VersionData = fileBody,
            PathOnClient = data.fileName + '.' + data.fileType,
            Title = data.fileName
        );
        insert cv;*/
        
        
        
        response.put('status', 'success');
        response.put('message', 'Partner registered successfully');
        response.put('cpId', cp.Id);
        
        return JSON.serialize(response);
    }
    
    public static Map<String, Attachment> getCPAttachments(String cpId){        
		//List<Attachment> atts = [SELECT Id, Name, ParentId, ContentType FROM Attachment WHERE ParentId =: cpId];
        List<ContentDocumentLink> cdlList = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =: cpId];
        System.debug('cdlList: ' + cdlList);
        Set<Id> docIds = new Set<Id>();
        Map<String, String> docIdVsCaseId = new Map<String, String>();
        for (ContentDocumentLink cdl : cdlList) {
            docIds.add(cdl.ContentDocumentId);
            docIdVsCaseId.put(cdl.ContentDocumentId, cdl.LinkedEntityId);
        }
        List<ContentVersion> files = new List<ContentVersion>();
        Map<String, String> docIdVsDistribution = new Map<String, String>();
        Map<String, Attachment> attMap = new Map<String, Attachment>();
        if (!docIds.isEmpty()) {
            files = [SELECT Id, Title, FileExtension, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :docIds ];
            List<ContentDocument> docs = [SELECT Id, Title, FileType, LatestPublishedVersionId FROM ContentDocument WHERE Id IN :docIds];
            List<ContentDistribution> dists = [SELECT Id, DistributionPublicUrl, Name, ContentDocumentId FROM ContentDistribution WHERE ContentDocumentId = : docIds];
            for(ContentDistribution dist : dists){
                docIdVsDistribution.put(dist.ContentDocumentId, dist.DistributionPublicUrl);
            }
            for(ContentDocument doc : docs){
                if(docIdVsDistribution.get(doc.Id) != null){
                    Attachment attch = new Attachment();
					attch.attachmentName = doc.Title;                    
                    attch.attachmentType = doc.FileType;
                    attch.url = docIdVsDistribution.get(doc.Id);
                    attMap.put(docIdVsCaseId.get(doc.Id), attch);
                }else{
                    ContentDistribution dist = new ContentDistribution();
                    dist.Name = doc.Title;
                    dist.ContentVersionId = doc.LatestPublishedVersionId;
                    dist.PreferencesAllowViewInBrowser = true;
                    dist.PreferencesAllowOriginalDownload = true;
                    insert dist;
                    ContentDistribution dt = [SELECT Id,DistributionPublicUrl FROM ContentDistribution WHERE Id =: dist.Id];
                    Attachment attch = new Attachment();
                    attch.attachmentName = doc.Title; 
                    attch.attachmentType = doc.FileType;
                    attch.url = dt.DistributionPublicUrl;
                    attMap.put(docIdVsCaseId.get(doc.Id), attch);
                }
            }
        }
        system.debug('attMap -> '+attMap);
        return attMap;
    }   
    
    public class Attachment{
        public String attachmentName;
        public String attachmentType;
        public String url;
    }
    
    global class cpDetailsPost{
        public cpRegistrationWrapper cpCreationRequest;
    }
    
    public class cpRegistrationWrapper {
        public String partnerType;
        public String projectId;
        public String fullName;
        public String email;
        public String phone;
        public String panNo;
        public String countryCode;
        public String companyName;
        public String reraRegistrationNumber;
        public String reraValidTill;
        
        public CompetencyCert competencyCert;
        public Boolean isNri;
        public Boolean isGstApplicable;
        public String gstNumber;
        public String experience;
        public String operationPlace;
        public String avgQuarterBusiness;
        public String teamSize;
        public String expertise;
        public String developerWorkedFor;
        
        public Address address;
        public BankDetails bankDetails;
        public list<Documents> documents;
    }
    
    public class CompetencyCert {
        public Boolean hasCompetencyCert;
        public String ccValidTill;
        public String ccScheduledExamDate;
    }
    
    public class Address {
        public String houseFlatCompany;
        public String streetAddress1;
        public String streetAddress2;
        public String streetAddress3;
        public String country;
        public String stateRegion;
        public String city;
        public String zipPinCode;
    }
    
    public class BankDetails {
        public String chequeDdFavouringName;
        public String branchCode;
        public String bankAccountIfscCode;
        public String bankAccountNumber;
        public String bankName;
        public String branchName;
    }
    
    public class Documents {
        public string fileName;
        public string fileType;
        public string attachment;
    } 
    
    public static Id getProjectId(String projectName){
        list<Project__c> pj = [Select Id from Project__c where Name =: projectName limit 1];
        if(!pj.isEmpty()){
            return pj[0].Id;
        }else{
            return 'No Project Found with this Name';
        }
    }

}