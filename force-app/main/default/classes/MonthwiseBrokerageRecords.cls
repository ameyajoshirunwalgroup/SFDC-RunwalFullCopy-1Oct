public class MonthwiseBrokerageRecords implements Database.Batchable<SObject>, Database.Stateful {

private Integer processedInvoices = 0;
private Integer createdCPBrokerages = 0;
private List<String> errorMessages = new List<String>();

public Database.QueryLocator start(Database.BatchableContext bc) {
    System.debug('=== MONTHWISE BROKERAGE RECORDS BATCH START ===');
    System.debug('Processing Current Month Invoices');
    // Fetch metadata record
    Batch_Query_Config__mdt config = [
        SELECT SOQL_Query__c
        FROM Batch_Query_Config__mdt
        WHERE DeveloperName = 'QueryForMonthwiseBrokerageInvoice'
        LIMIT 1
    ];        
        String query = config != null && String.isNotBlank(config.SOQL_Query__c)
                ? config.SOQL_Query__c
                : 'SELECT Id, Booking__c, Booking__r.Tower__r.Legal_Entity__c, ' +
                    'Channel_Partner__c, Invoice_Amount__c, CreatedDate, ' +
                    'Brokerage_Lookup__r.Name, ' +
                    'Booking__r.Name, Channel_Partner__r.Name ' +
                    'FROM Brokerage_Invoice__c ' +
                    'WHERE Brokerage_Lookup__r.Name = \'Additional Brokerage\' ' +
                    'AND CreatedDate = THIS_MONTH ' +
                    'AND Booking__r.Tower__r.Legal_Entity__c != null ' +
                    'AND Channel_Partner__c != null ' +
                    'AND CP_Brokerage__c = null';

System.debug('Query from Metadata: ' + query);

return Database.getQueryLocator(query);
}

public void execute(Database.BatchableContext bc, List<Brokerage_Invoice__c> invoices) {
    System.debug('=== EXECUTE METHOD START ===');
    System.debug('Processing ' + invoices.size() + ' invoices in this batch');
    
    if (invoices.isEmpty()) {
        System.debug('No invoices to process in this batch');
        return;
    }
    
    try {
        Map<String, GroupedInvoiceData> groupedData = new Map<String, GroupedInvoiceData>();
        
        for (Brokerage_Invoice__c inv : invoices) {
            String legalEntityId = inv.Booking__r.Tower__r.Legal_Entity__c;
            String channelPartnerId = inv.Channel_Partner__c;
            String groupKey = legalEntityId + '-' + channelPartnerId;
            
            if (!groupedData.containsKey(groupKey)) {
                groupedData.put(groupKey, new GroupedInvoiceData(legalEntityId, channelPartnerId));
            }
            
            GroupedInvoiceData data = groupedData.get(groupKey);
            data.addInvoice(inv);
            
            System.debug('Invoice ' + inv.Id + ' | Amount: ' + inv.Invoice_Amount__c + 
                            ' | CP: ' + inv.Channel_Partner__r.Name + 
                            ' | Booking: ' + inv.Booking__r.Name);
        }
        
        System.debug('Grouped into ' + groupedData.size() + ' Legal Entity-CP combinations');
        
        List<CP_Brokerage__c> cpBrokerageRecords = new List<CP_Brokerage__c>();
        
        Date today = System.today();
        String currentMonthString = today.year() + '-' + String.valueOf(today.month()).leftPad(2, '0');
        
        for (String groupKey : groupedData.keySet()) {
            GroupedInvoiceData data = groupedData.get(groupKey);
            
            CP_Brokerage__c cpBrokerage = new CP_Brokerage__c(
                Legal_Entity__c = data.legalEntityId,
                Channel_Partner__c = data.channelPartnerId,
                Month__c = currentMonthString, 
                Total_Brokerage__c = data.totalAmount,
                Brokerage_Type__c='Additional Brokerage',
                CP_Invoice_Clearing_L1__c = invoices[0].CP_Invoice_Clearing_L1__c,
                CP_Invoice_Clearing_L2__c = invoices[0].CP_Invoice_Clearing_L1__c,

                CP_Invoice_Approver_L1__c = invoices[0].CP_Invoice_Approver_L2__c,
                CP_Invoice_Approver_L2__c = invoices[0].CP_Invoice_Approver_L3__c,
                CP_Invoice_Approver_L3__c = invoices[0].CP_Invoice_Approver_L4__c,
                CP_Invoice_Approver_L4__c = invoices[0].CP_Invoice_Approver_L5__c,
                CP_MIS__c = invoices[0].CP_Invoice_Approver_L1__c

            );
            
            cpBrokerageRecords.add(cpBrokerage);
            
            System.debug('Creating CP_Brokerage: Legal Entity=' + data.legalEntityId + 
                            ' | CP=' + data.channelPartnerId + 
                            ' | Month=' + currentMonthString +
                            ' | Total=' + data.totalAmount + 
                            ' | Count=' + data.invoiceIds.size());
        }
        
        if (!cpBrokerageRecords.isEmpty()) {
            insert cpBrokerageRecords;
            createdCPBrokerages += cpBrokerageRecords.size();
            System.debug('Successfully inserted ' + cpBrokerageRecords.size() + ' CP_Brokerage records');
        }
        
        List<Brokerage_Invoice__c> invoicesToUpdate = new List<Brokerage_Invoice__c>();
        Integer recordIndex = 0;
        
        for (String groupKey : groupedData.keySet()) {
            GroupedInvoiceData data = groupedData.get(groupKey);
            CP_Brokerage__c cpBrokerage = cpBrokerageRecords[recordIndex++];
            
            for (Id invoiceId : data.invoiceIds) {
                invoicesToUpdate.add(new Brokerage_Invoice__c(
                    Id = invoiceId,
                    CP_Brokerage__c = cpBrokerage.Id
                ));
            }
        }
        
        if (!invoicesToUpdate.isEmpty()) {
            update invoicesToUpdate;
            processedInvoices += invoicesToUpdate.size();
            System.debug('Successfully updated ' + invoicesToUpdate.size() + ' invoices with CP_Brokerage links');
        }
        
    } catch (Exception e) {
        String errorMsg = 'Error in execute method: ' + e.getMessage() + ' | Line: ' + e.getLineNumber();
        System.debug('ERROR: ' + errorMsg);
        errorMessages.add(errorMsg);
        throw e; 
    }
    
    System.debug('=== EXECUTE METHOD END ===');
}

public void finish(Database.BatchableContext bc) {
    System.debug('=== MONTHWISE BROKERAGE BATCH FINISH ===');
    
    // Get job statistics
    AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
                        TotalJobItems, CompletedDate, ExtendedStatus
                        FROM AsyncApexJob WHERE Id = :bc.getJobId()];
    
    System.debug('Job Status: ' + job.Status);
    System.debug('Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
    System.debug('Errors: ' + job.NumberOfErrors);
    System.debug('Extended Status: ' + job.ExtendedStatus);
    System.debug('Completed: ' + job.CompletedDate);
    
    // Custom statistics
    System.debug('=== PROCESSING SUMMARY ===');
    Date today = System.today();
    // String currentMonth = today.format('MMMM yyyy');
    //    /    System.debug('Processed Month: ' + currentMonth + ' (' + today.year() + '-' + String.valueOf(today.month()).leftPad(2, '0') + ')');
    System.debug('Total Invoices Processed: ' + processedInvoices);
    System.debug('CP_Brokerage Records Created: ' + createdCPBrokerages);
    System.debug('Error Count: ' + errorMessages.size());
    
    if (!errorMessages.isEmpty()) {
        System.debug('=== ERRORS ENCOUNTERED ===');
        for (String error : errorMessages) {
            System.debug('ERROR: ' + error);
        }
    }
    
    // Optional: Send email notification
    if (job.Status == 'Completed' && job.NumberOfErrors == 0) {
        System.debug('SUCCESS: Monthwise brokerage batch completed successfully!');
        // sendSuccessEmail();
    } else {
        System.debug('WARNING: Monthwise brokerage batch completed with errors or failures');
        // sendErrorEmail(job, errorMessages);
    }
    
    System.debug('=== BATCH PROCESSING COMPLETE ===');
}

// Helper class to group invoice data
private class GroupedInvoiceData {
    public String legalEntityId;
    public String channelPartnerId;
    public Decimal totalAmount = 0;
    public List<Id> invoiceIds = new List<Id>();
    public Integer invoiceCount = 0;
    
    public GroupedInvoiceData(String legalEntity, String channelPartner) {
        this.legalEntityId = legalEntity;
        this.channelPartnerId = channelPartner;
    }
    
    public void addInvoice(Brokerage_Invoice__c invoice) {
        this.totalAmount += (invoice.Invoice_Amount__c ?? 0);
        this.invoiceIds.add(invoice.Id);
        this.invoiceCount++;
    }
}

// Optional email notification methods
private void sendSuccessEmail() {
    // Implementation for success notification
    System.debug('Sending success notification email...');
}

private void sendErrorEmail(AsyncApexJob job, List<String> errors) {
    // Implementation for error notification
    System.debug('Sending error notification email...');
}
}