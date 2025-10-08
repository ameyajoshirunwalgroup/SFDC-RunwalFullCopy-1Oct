@RestResource(urlMapping='/cpAuth/*')
global without sharing class Lockated_CPAuth {
    
    @HttpGet
    global static void doGet(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        String cpId = req.params.get('id'); 
        String email = req.params.get('email');  
        String phone = req.params.get('phone'); 
        list<Broker__c> brlist = new list<Broker__c>();
        Map<String, Object> result = new Map<String, Object>();
        try{
            String baseQuery = 'SELECT Id,Country__c,STREET__c,STR_SUPPL2__c,Sourcing_Manager__r.Name,Sourcing_Manager__r.Email,Sourcing_Manager__r.MobilePhone,STR_SUPPL3__c,Cheque_DD_Favouring_Name__c,Branch_Code__c,IFSC_Code__c,Account_Number__c,Bank_Name__c,Broker_Type__c,NAME_MIDDLE__c,Dialing_Country_Code1__c,Company_Name_As_per_RERA__c,RERA_Valid_till__c,Are_you_NRI__c,RW_GST_Number__c,Experience__c,Team_Size__c,House_Flat_Company__c,CC_Scheduled_Exam_Date__c,CC_Valid_till__c, Name,OwnerId, RecordTypeId, CreatedById, LastModifiedById, Representative_Name__c, RW_Email__c, RW_Mobile_No__c, RW_Broker_Number__c, Address__c, Broker_Pan_No__c, City__c, Pin_Code__c, RW_RERA_Registration_Number__c, RW_Is_GST_Applicable__c, RW_Is_RERA_Applicable__c, Is_NRI_CP__c, SAP_CP_Code__c, Locality__c, Zone__c, Individual_CP__c, NAME_FIRST__c, NAME_LAST__c, RW_CreateFromIRIS__c, RW_IRIS_Sync__c, Unregistered_Channel_Partner__c, Place_of_Supply__c, Account__c, Approver_L1__c, Approver_L2__c, Channel_Partner_From_CP_Portal__c, Country_2__c, Is_T_C_Accepted__c, Project__c, Registration_Complete__c, State_Code__c, State_2__c, Activate_CP_Portal__c, Data_Error_Fixed__c, Deactivated__c, days_from_creation__c, Latest_RERA_Upload_Processed__c, Latest_CC_Upload_Processed__c, Valid_RERA_certificate__c, Valid_competency_certificate__c, RW_Is_CC_Applicable__c FROM Broker__c';
            
            List<String> whereClauses = new List<String>();
            if (String.isNotBlank(cpId)) {
                whereClauses.add('Id = :cpId');
            }
            if (String.isNotBlank(email) && String.isNotBlank(phone)) {
                whereClauses.add('(RW_Email__c = :email OR RW_Mobile_No__c = :phone)');
            } else if (String.isNotBlank(email)) {
                whereClauses.add('RW_Email__c = :email');
            } else if (String.isNotBlank(phone)) {
                whereClauses.add('RW_Mobile_No__c = :phone');
            }
            
            String query = baseQuery;
            if (!whereClauses.isEmpty()) {
                query += ' WHERE ' + String.join(whereClauses, ' AND ');
            } else {
                result.put('status', 'error');
                result.put('message', 'Please provide email or phone.');
                res.responseBody = Blob.valueOf(JSON.serialize(result));
                res.statusCode = 400;
                return;
            }
            
            System.debug('Final Query => ' + query);
            
            brlist = Database.query(query);
            system.debug('brlist -> '+brlist);
            if (!brlist.isEmpty()) {
                CPDetailsWrapper cp = new CPDetailsWrapper();
                cp.basicDetails = new GetBasicDetails();
                cp.address = new Address();
                cp.bankDetails = new BankDetails();
                cp.documents = new list<Attachment>();
                cp.sourcingManagerDetails = new SourcingManagerDet();
                cp.id = brlist[0].Id;
                cp.basicDetails.channelPartnerType = brlist[0].Broker_Type__c;
                cp.basicDetails.project = brlist[0].Project__c;
                cp.basicDetails.fullName = brlist[0].NAME_FIRST__c + ' ' + brlist[0].NAME_MIDDLE__c + ' ' + brlist[0].NAME_LAST__c;
                cp.basicDetails.emailAddress = brlist[0].RW_Email__c;
                cp.basicDetails.mobileNo = brlist[0].RW_Mobile_No__c;
                cp.basicDetails.panNo = brlist[0].Broker_Pan_No__c;
                cp.basicDetails.countryCode = brlist[0].Dialing_Country_Code1__c;
                cp.basicDetails.companyName = brlist[0].Company_Name_As_per_RERA__c;
                cp.basicDetails.reraNo = brlist[0].RW_RERA_Registration_Number__c;
                cp.basicDetails.reraValidTill = String.valueOf(brlist[0].RERA_Valid_till__c);
                cp.basicDetails.hasCompetencyCert = brlist[0].RW_Is_CC_Applicable__c == true ? 'Yes' : 'No';
                cp.basicDetails.ccValidTill = String.valueOf(brlist[0].CC_Valid_till__c);
                cp.basicDetails.ccScheduledExamDate = String.valueOf(brlist[0].CC_Scheduled_Exam_Date__c);
                cp.basicDetails.nri = brlist[0].Are_you_NRI__c;
                cp.basicDetails.gstApplicable = brlist[0].RW_Is_GST_Applicable__c == true ? 'Yes' : 'No';
                cp.basicDetails.gstNo = brlist[0].RW_GST_Number__c;
                cp.basicDetails.experience = brlist[0].Experience__c;
                cp.basicDetails.placeOfOperation = brlist[0].Place_of_Supply__c;
                //cp.basicDetails.averageQuarterlyBusiness = brlist[0].;
                cp.basicDetails.teamSize = brlist[0].Team_Size__c;
                
                cp.address.houseFlatCompany = brlist[0].House_Flat_Company__c;
                cp.address.country = brlist[0].Country__c;    
                cp.address.streetAddress1 = brlist[0].STREET__c;
                cp.address.streetAddress2 = brlist[0].STR_SUPPL2__c;
                cp.address.streetAddress3 = brlist[0].STR_SUPPL3__c;
                cp.address.city = brlist[0].City__c;
                cp.address.zipPinCode = brlist[0].Pin_Code__c;
                
                cp.bankDetails.chequeDdFavouringName = brlist[0].Cheque_DD_Favouring_Name__c;
                cp.bankDetails.branchCode = brlist[0].Branch_Code__c;
                cp.bankDetails.bankAccountIfscCode = brlist[0].IFSC_Code__c;
                cp.bankDetails.bankAccountNumber = brlist[0].Account_Number__c;
                cp.bankDetails.bankName = brlist[0].Bank_Name__c;
                cp.bankDetails.branchName = brlist[0].Branch_Code__c;
                
                if(brlist[0].Sourcing_Manager__c != null){
                    cp.sourcingManagerDetails.fullName = brlist[0].Sourcing_Manager__r.Name;
                    cp.sourcingManagerDetails.emailAddress = brlist[0].Sourcing_Manager__r.Email;
                    cp.sourcingManagerDetails.mobileNumber = brlist[0].Sourcing_Manager__r.MobilePhone;
                }
                    
                cp.documents = getCPAttachments(cp.id);
                
                
                res.responseBody = Blob.valueOf(JSON.serialize(cp));
                res.statusCode = 200;
            } else {
                result.put('status', 'error');
                result.put('message', 'No Broker found for given details.');
                res.responseBody = Blob.valueOf(JSON.serialize(result));
                res.statusCode = 404;
            }
            
        } catch (Exception e) {
            result.put('status', 'error');
            result.put('message', e.getMessage() + ';  ' + e.getStackTraceString());
            res.responseBody = Blob.valueOf(JSON.serialize(result));
            res.statusCode = 500;
        }
        
        //Map<String, Attachment> attMap = getCPAttachments(cpId);
        //return JSON.serialize(attMap);
        
    }
    
    @HttpPost
    global static void doPost(){                
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        system.debug(req.requestBody);
        String cptype = req.params.get('cptype');
        system.debug('cptype -> '+cptype);
        String jsonBody = req.requestBody.toString();
        Map<String, Object> response = new Map<String, Object>();
        if(cptype == 'CP'){
            response = handleCP(jsonBody);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200;
        } else if(cptype == 'TempCP'){
            response = handleTempCP(jsonBody);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.statusCode = 200;
        }
        else {
            Map<String, Object> errorResult = new Map<String, Object>();
            errorResult.put('status', 'error');
            errorResult.put('message', 'Please enter a valid CP type');
            res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
            res.statusCode = 400;
        }
        
    }
    
    public static Map<String,Object> handleCP(String jsonBody){
        
        cpRegistrationWrapper data = (cpRegistrationWrapper) JSON.deserialize(jsonBody,cpRegistrationWrapper.class);
        
        Map<String, Object> response = new Map<String, Object>();
        
        // Check if CP already exists with same email or PAN
        List<Broker__c> existing = [SELECT Id, Name, RW_Email__c, Broker_Pan_No__c,RW_Mobile_No__c FROM Broker__c WHERE 
                                    RW_Email__c = :data.email OR Broker_Pan_No__c = :data.panNo OR RW_Mobile_No__c =: data.phone LIMIT 1];
        
        if (!existing.isEmpty()) {
            response.put('status', 'error');
            response.put('message', 'Partner already exists with this email, PAN or Mobile');
            return response;
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
        cp.RW_Is_CC_Applicable__c = data.hasCompetencyCert;
        if(cp.RW_Is_CC_Applicable__c){
            cp.CC_Valid_till__c = String.isNotBlank(data.ccValidTill) ? Date.valueOf(data.ccValidTill) : null;
        }else{
            cp.CC_Scheduled_Exam_Date__c = String.isNotBlank(data.ccScheduledExamDate) ? Date.valueOf(data.ccScheduledExamDate) : null;
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
                    ContentDocumentId = cv.ContentDocumentId, 
                    LinkedEntityId = cp.id,  
                    ShareType = 'V',     
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
        
        return response;
    }
    
    public static Map<String,Object> handleTempCP(String jsonBody){
        
        tempCPWrapper data = (tempCPWrapper) JSON.deserialize(jsonBody,tempCPWrapper.class);
        
        Map<String, Object> response = new Map<String, Object>();
        
        // Check if CP already exists with same email or PAN
        List<Broker__c> existing = [SELECT Id, Name, RW_Email__c, Broker_Pan_No__c,RW_Mobile_No__c FROM Broker__c WHERE 
                                    RW_Email__c = :data.email OR Broker_Pan_No__c = :data.panNo OR RW_Mobile_No__c =: data.phone LIMIT 1];
        
        if (!existing.isEmpty()) {
            response.put('status', 'error');
            response.put('message', 'Partner already exists with this email, PAN or Mobile');
            return response;
        }
        
        //If passed validations, insert Broker__c record 
        Broker__c cp = new Broker__c();        
        cp.NAME_FIRST__c = data.firstName;
        cp.NAME_MIDDLE__c = data.middleName;
        cp.NAME_LAST__c = data.lastName;
        if (cp.NAME_MIDDLE__c != null) {
            cp.Name = data.firstName + ' ' + data.middleName + ' ' + data.lastName;
        } else {
            cp.Name = data.firstName + ' ' + data.lastName;
        }
        cp.RW_Email__c = data.email;
        cp.Broker_Pan_No__c = data.panno;
        cp.Company_Name__c = data.companyName;
        cp.RW_Mobile_No__c = data.phone;
        Id tempRecordTypeId = Schema.SObjectType.Broker__c.getRecordTypeInfosByName().get('Temp Channel Partner').getRecordTypeId();
        cp.RecordTypeId = tempRecordTypeId;     
        //cp.Sourcing_Manager__c = UserInfo.getUserId();
        
        insert cp;      
        
        response.put('status', 'success');
        response.put('message', 'Temporary Partner created successfully');
        response.put('cpId', cp.Id);
        
        return response;
    }
    
    public static list<Attachment> getCPAttachments(String cpId) {        
        list<Attachment> attMaplist = new list<Attachment>();
        
        // Step 1: Get all files linked to the Channel Partner record
        List<ContentDocumentLink> cdlList = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :cpId
        ];
        
        if (cdlList.isEmpty()) {
            System.debug('⚠️ No documents linked to: ' + cpId);
            return attMaplist;
        }
        
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : cdlList) {
            docIds.add(cdl.ContentDocumentId);
        }
        
        // Step 2: Get ContentDocument + Latest Version
        List<ContentDocument> docs = [
            SELECT Id, Title, FileType, LatestPublishedVersionId 
            FROM ContentDocument 
            WHERE Id IN :docIds
        ];
        
        // Step 3: Get existing ContentDistributions for these docs
        Map<Id, String> docIdVsDistribution = new Map<Id, String>();
        for (ContentDistribution dist : [
            SELECT ContentDocumentId, DistributionPublicUrl 
            FROM ContentDistribution 
            WHERE ContentDocumentId IN :docIds
        ]) {
            docIdVsDistribution.put(dist.ContentDocumentId, dist.DistributionPublicUrl);
        }
        
        // Step 4: Loop through docs, generate new distribution if needed
        List<ContentDistribution> newDists = new List<ContentDistribution>();
        for (ContentDocument doc : docs) {
            if (!docIdVsDistribution.containsKey(doc.Id)) {
                ContentDistribution dist = new ContentDistribution();
                dist.Name = doc.Title;
                dist.ContentVersionId = doc.LatestPublishedVersionId;
                dist.PreferencesAllowViewInBrowser = true;
                dist.PreferencesAllowOriginalDownload = true;
                newDists.add(dist);
            }
        }
        
        if (!newDists.isEmpty()) {
            insert newDists;
            for (ContentDistribution dist : [
                SELECT ContentDocumentId, DistributionPublicUrl 
                FROM ContentDistribution 
                WHERE Id IN :newDists
            ]) {
                docIdVsDistribution.put(dist.ContentDocumentId, dist.DistributionPublicUrl);
            }
        }
        
        // Step 5: Build attachment map (key = Document Id)
        for (ContentDocument doc : docs) {
            Attachment att = new Attachment();
            att.attachmentName = doc.Title;
            att.attachmentType = doc.FileType;
            att.url = docIdVsDistribution.get(doc.Id);
            att.attachmentId = doc.Id;
            attMaplist.add(att);
        }
        
        System.debug('✅ attMaplist => ' + attMaplist);
        for(Attachment key:attMaplist){
            system.debug('Key -> '+key);
        }
        return attMaplist;
    }
    
    
    public class Attachment{
        public String attachmentId;
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
        public Boolean hasCompetencyCert;
        public String ccValidTill;
        public String ccScheduledExamDate;
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
    
    public class CPDetailsWrapper {
        public String id;
        public GetBasicDetails basicDetails;
        public SourcingManagerDet sourcingManagerDetails;
        public Address address;
        public BankDetails bankDetails;
        public list<Attachment> documents;
    }
        
        public class GetBasicDetails {
            public String channelPartnerType;
            public String project;
            public String fullName;
            public String emailAddress;
            public String mobileNo;
            public String panNo;
            public String countryCode;
            public String companyName;
            public String reraNo;
            public String reraValidTill;
            public String hasCompetencyCert;
            public String ccValidTill;
            public String ccScheduledExamDate;
            public String nri;
            public String gstApplicable;
            public String gstNo;
            public String experience;
            public String placeOfOperation;
            public String averageQuarterlyBusiness;
            public String teamSize;
        }
        
    public class SourcingManagerDet{
        public String fullName;
        public String mobileNumber;
        public String emailAddress;
    }
        
   
    
    public class tempCPWrapper {
        public String companyName;
        public String firstName;
        public String middleName;
        public String lastName;
        public String phone;
        public String email;
        public String panNo;
        public String aadhaarNo;
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