public with sharing class CPBrokerageService {
    
    // Wrapper for Flow input
    public class InvoiceInput {
        @InvocableVariable(required=true)
        public Id invoiceId;
    }

    @InvocableMethod(label='Create CP Brokerage from Invoices' description='Groups invoices and creates CP_Brokerage records')
    public static void createFromFlow(List<InvoiceInput> request) {
        Set<Id> invoiceIds = new Set<Id>();
        for (InvoiceInput input : request) {
            if (input.invoiceId != null) {
                invoiceIds.add(input.invoiceId);
            }
        }
        if (!invoiceIds.isEmpty()) {
            createCPBrokerageFromInvoices(invoiceIds);
        }
    }
    
    // Core logic (same as your code)
    public static void createCPBrokerageFromInvoices(Set<Id> invoiceIds) {
        // Step 1: Fetch invoices
        List<Brokerage_Invoice__c> invoices = [
            SELECT Id, Channel_Partner__c, Legal_Entity__c,
                   Brokerage_In_Rs__c, Brokerage_Amt_Post_TDS__c,
                   Brokerage_Lookup__r.Name, Brokerage_Lookup__r.Brokerage_Type__c,
                   Booking__r.Unit_No__r.Legal_Entity__c,Brokerage_Summary__c,
                   CP_Invoice_Approver_L1__c, CP_Invoice_Approver_L2__c,
                   CP_Invoice_Approver_L3__c, CP_Invoice_Approver_L4__c, CP_Invoice_Approver_L5__c,
                   CP_Invoice_Clearing_L1__c, CP_Invoice_Clearing_L2__c,
                    Approval_Status__c, Approval_Status_clearing__c,
                   Date_Approved_by_L1__c, Date_Approved_by_L2__c, Date_Approved_by_L3__c,
                   Date_Approved_by_L4__c, Date_Approved_By_Submitter__c,Brokerage_Summary__r.AOP__c
            FROM Brokerage_Invoice__c
            WHERE Id IN :invoiceIds
        ];
        
        // Step 2: Group invoices
        Map<String, List<Brokerage_Invoice__c>> grouped = new Map<String, List<Brokerage_Invoice__c>>();
        for (Brokerage_Invoice__c inv : invoices) {
            String type = (inv.Brokerage_Lookup__r != null && 
                           inv.Brokerage_Lookup__r.Name == 'AOP Interim Brokerage') 
                           ? 'AOP Interim Brokerage'
                           : (inv.Brokerage_Lookup__r != null ? inv.Brokerage_Lookup__r.Brokerage_Type__c : 'Unknown');
            
            String key = inv.Channel_Partner__c + '-' + 
                         inv.Booking__r.Unit_No__r.Legal_Entity__c + '-' + type;
            
            if (!grouped.containsKey(key)) grouped.put(key, new List<Brokerage_Invoice__c>());
            grouped.get(key).add(inv);
        }
        
        // Step 3: Create CP_Brokerage__c records
        List<CP_Brokerage__c> toInsert = new List<CP_Brokerage__c>();
        Map<String, List<Brokerage_Invoice__c>> groupToInvoices = new Map<String, List<Brokerage_Invoice__c>>();
        
        for (String key : grouped.keySet()) {
            List<Brokerage_Invoice__c> groupInvoices = grouped.get(key);
            Brokerage_Invoice__c first = groupInvoices[0];
            
            Decimal totalBrokerage = 0;
            for (Brokerage_Invoice__c inv : groupInvoices) {
                totalBrokerage += (inv.Brokerage_In_Rs__c != null ? inv.Brokerage_In_Rs__c : 0);
            }
            
            CP_Brokerage__c cpb = new CP_Brokerage__c();
            cpb.Channel_Partner__c = first.Channel_Partner__c;
            cpb.Legal_Entity__c = first.Booking__r.Unit_No__r.Legal_Entity__c;
            cpb.Total_Brokerage__c = totalBrokerage;
            cpb.Invoice_Date__c = Date.today();
          //  cpb.Invoice_Status__c = 'Due';
            cpb.Brokerage_Type__c =first.Brokerage_Lookup__r.Brokerage_Type__c;
            
            // Approver fields
            cpb.CP_Invoice_Approver_L1__c = first.CP_Invoice_Approver_L2__c;
            cpb.CP_Invoice_Approver_L2__c = first.CP_Invoice_Approver_L3__c;
            cpb.CP_Invoice_Approver_L3__c = first.CP_Invoice_Approver_L4__c;
            cpb.CP_Invoice_Approver_L4__c = first.CP_Invoice_Approver_L5__c;
            cpb.CP_MIS__c = first.CP_Invoice_Approver_L1__c;
            
            cpb.CP_Invoice_Clearing_L1__c = first.CP_Invoice_Clearing_L1__c;
            cpb.CP_Invoice_Clearing_L2__c = first.CP_Invoice_Clearing_L2__c;
            cpb.AOP__c=first.Brokerage_Summary__r.AOP__c;
            toInsert.add(cpb);
            groupToInvoices.put(key, groupInvoices);
        }
        
        if (!toInsert.isEmpty()) {
            insert toInsert;
            
            // Step 4: Map inserted headers back to invoices
            Map<String, Id> keyToCPBId = new Map<String, Id>();
            for (Integer i = 0; i < toInsert.size(); i++) {
                CP_Brokerage__c cpb = toInsert[i];
                String key = cpb.Channel_Partner__c + '-' + cpb.Legal_Entity__c + '-' + cpb.Brokerage_Type__c;
                keyToCPBId.put(key, cpb.Id);
            }
            
            List<Brokerage_Invoice__c> toUpdate = new List<Brokerage_Invoice__c>();
            for (String key : groupToInvoices.keySet()) {
                for (Brokerage_Invoice__c inv : groupToInvoices.get(key)) {
                    inv.CP_Brokerage__c = keyToCPBId.get(key);
                    toUpdate.add(inv);
                }
            }
            
            if (!toUpdate.isEmpty()) {
                update toUpdate;
            }
        }
    }
}