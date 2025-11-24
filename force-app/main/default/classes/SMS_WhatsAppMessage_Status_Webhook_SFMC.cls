@RestResource(urlMapping='/messageStatusWebhook/*')
global class SMS_WhatsAppMessage_Status_Webhook_SFMC {

    @HttpPost
    global static void doPost(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        Map<String, Object> errorResult = new Map<String, Object>();
        String sObjName;
        try{
            system.debug('req: ' + req.requestBody);
            String jsonBody = req.requestBody.toString();
            system.debug('jsonBody: ' + jsonBody);
            RespDetails resData = (RespDetails)JSON.deserialize(jsonBody, RespDetails.class);
            if(resData.recordId != null){
                Id objId  = resData.recordId;
                sObjName = objId.getSObjectType().getDescribe().getName();
                
            }
            if(resData.messageType == 'SMS'){
                SMS_Schedule_SMS_c__c sms = new SMS_Schedule_SMS_c__c();
                sms.Status__c = resData.status;
                sms.Sender_Mobile__c = resData.mobile;
                sms.SMS_Long_text__c = resData.message;
                sms.Message_Sent_from_SFMC__c = true;
                if(sObjName == 'Opportunity'){
                    sms.Opportunity_Lookup__c = resData.recordId;
                }else if(sObjName == 'Lead'){
                    sms.Lead_Lookup__c = resData.recordId;
                }
                insert sms;
            }else if(resData.messageType == 'Whatsapp'){
                WhatsApp_Message_Status__c whatsapp = new WhatsApp_Message_Status__c();
                whatsapp.Status__c = resData.status;
                whatsapp.Mobile_Number__c = resData.mobile;
                whatsapp.Message__c = resData.message;
                whatsapp.Message_Sent_from_SFMC__c = true;
                if(sObjName == 'Opportunity'){
                    whatsapp.Opportunity__c = resData.recordId;
                }else if(sObjName == 'Case'){
                    whatsapp.Case__c = resData.recordId;
                }else if(sObjName == 'Account'){
                    whatsapp.Account__c = resData.recordId;
                }else if(sObjName == 'Lead'){
                    whatsapp.Lead__c = resData.recordId;
                }
                insert whatsapp;
            }
            res.responseBody = Blob.valueOf(JSON.serialize(resData));
            res.statusCode = 200;
        }catch(exception e){
            errorResult.put('status', 'error');
            errorResult.put('message', e.getMessage() + ';  ' + e.getStackTraceString());
            res.responseBody = Blob.valueOf(JSON.serialize(errorResult));
            res.statusCode = 400;
        }
    }
    
    global class RespDetails{
        public String mobile;
        public String status;
        public String recordId;
        public String messageType;
        public String message;
    }
}