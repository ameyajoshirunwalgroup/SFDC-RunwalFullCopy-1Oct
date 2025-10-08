@RestResource(urlMapping='/cpCreateCase/*')
global without sharing class Lockated_CPCreateCase {

    @HttpPost
    global static CaseResponse createCase() {
        CaseResponse response = new CaseResponse();
        try {
            // Parse incoming request
            RestRequest req = RestContext.request;
            if (req == null || req.requestBody == null) {
                return buildErrorResponse('Invalid request. Request body is empty.');
            }

            // Deserialize JSON
            CaseRequest input;
            try {
                input = (CaseRequest) JSON.deserialize(req.requestBody.toString(), CaseRequest.class);
            } catch (Exception parseEx) {
                return buildErrorResponse('Invalid JSON format: ' + parseEx.getMessage());
            }

            // Validate required fields
            if (String.isBlank(input.category) || String.isBlank(input.description)) {
                return buildErrorResponse('Missing required fields: category or description.');
            }
			
            Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Channel_Partner_Portal').getRecordTypeId();
            // Create new Case
            Case newCase = new Case();
            newCase.Subject = 'Customer Portal Case';
            newCase.Description = input.description;
            newCase.Case_Category__c = input.category;
            newCase.Case_Sub_Category__c = input.sub_category;
            newCase.RecordTypeId= recordTypeId;
            newCase.Origin = 'Channel Partner Portal';
			
            // If opportunity is provided, tag related fields
            if (String.isNotBlank(input.opportunityId)) {
                Opportunity opp = getOpportunityWithRelated(input.opportunityId);
                if (opp != null) {
                    newCase.Opportunity__c = opp.Id;
                    if (opp.AccountId != null) newCase.AccountId = opp.AccountId;
                    if (opp.RW_Project__c != null) newCase.RW_Project__c = opp.RW_Project__c;
                } else {
                    return buildErrorResponse('Invalid Opportunity Id: ' + input.opportunityId);
                }
            }

            insert newCase;
			
            // Upload attachment if provided
            if (!String.isBlank(input.attachment)) {
                String fileName = String.isNotBlank(input.attachmentName) ? input.attachmentName : 'CaseAttachment_' + Datetime.now().format('yyyyMMddHHmmss') + '.txt';
                uploadAttachment(input.attachment, newCase.Id, fileName);
            }

            // Build success response
            return buildSuccessResponse('Case created successfully: ' + newCase.Id);
        }
        catch (DmlException dmlEx) {
            return buildErrorResponse('Database error: ' + dmlEx.getDmlMessage(0));
        }
        catch (Exception ex) {
            return buildErrorResponse('Unexpected error: ' + ex.getMessage());
        }
    }
    
    // Private Helper Method to get Opportunity 
    private static Opportunity getOpportunityWithRelated(String oppId) {
        try {
            return [
                SELECT Id, AccountId, RW_Project__c
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug('Opportunity fetch failed: ' + e.getMessage());
            return null;
        }
    }
    
    // Private Helper Method for Attachment Upload
    private static void uploadAttachment(String base64File, Id caseId, String fileName) {
        if (String.isBlank(base64File) || caseId == null) return;

        try {
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64File);
            insert cv;

            // Link file to Case
            Id contentDocId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
            ].ContentDocumentId;

            insert new ContentDocumentLink(
                LinkedEntityId = caseId,
                ContentDocumentId = contentDocId,
                ShareType = 'V'
            );
        } catch (Exception ex) {
            // Log only — main method will handle response errors
            System.debug('Attachment upload failed: ' + ex.getMessage());
            throw new AuraHandledException('Attachment upload failed: ' + ex.getMessage());
        }
    }
    
    //Helper: Build Success Response
    private static CaseResponse buildSuccessResponse(String message) {
        CaseResponse res = new CaseResponse();
        res.isSuccess = true;
        res.success_message = message;
        res.error_message = null;
        return res;
    }

    //Helper: Build Error Response
    private static CaseResponse buildErrorResponse(String message) {
        CaseResponse res = new CaseResponse();
        res.isSuccess = false;
        res.success_message = null;
        res.error_message = message;
        return res;
    }
        
    // Request Wrapper
    global class CaseRequest {
        public String brokerId;
        public String opportunityId;
        public String category;
        public String sub_category;
        public String description;
        public String attachmentName;
        public String attachment;
    }

    // Response Wrapper
    global class CaseResponse {
        public Boolean isSuccess;
        public String success_message;
        public String error_message;
    }

}