@isTest
public class MonthwiseBrokerageRecordsTest {

    @testSetup
    static void setupTestData() {
        Project__c P1 = new Project__c( Name='Project1');
        insert P1;
        
        // Create Legal Entity (on Tower)
        Legal_Entity__c legalEntity = new Legal_Entity__c(Name = 'Test Legal Entity');
                      
        insert legalEntity;

        // Create Tower with Legal Entity
        Tower__c tower = new Tower__c(
            Name = 'Test Tower',
            ProjectName__c =P1.Id,
            Legal_Entity__c = legalEntity.Id
        );
        insert tower;

        // Create Channel Partner
        Broker__c channelPartner = new Broker__c(Name = 'Test broker');
        insert channelPartner;

        // Create Booking
        Booking__c booking = new Booking__c(
         //   Name = 'Test Booking',
            Tower__c = tower.Id
        );
        insert booking;
        
        Brokerage_Summary__c summary = new Brokerage_Summary__c(
        
    );
    insert summary;

        
        Brokerage__c brokerage = new Brokerage__c(
        Name = 'Additional Brokerage',
            Brokerage_Summary__c=summary.id
          
    );
    insert brokerage;

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u1 = new User(
            Alias = 'testu',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'unique_testuser' + DateTime.now().getTime() + '@example.com'
        );
        insert u1;


        // Create invoices for THIS_MONTH
        List<Brokerage_Invoice__c> invoices = new List<Brokerage_Invoice__c>();
        for (Integer i = 0; i < 3; i++) {
            invoices.add(new Brokerage_Invoice__c(
                Booking__c = booking.Id,
                Channel_Partner__c = channelPartner.Id,
                Invoice_Amount__c = 1000 + i,
                Brokerage_In_Rs__c =989 +1,
                Brokerage__c =0.5,
                CP_Invoice_Clearing_L1__c= u1.id,
                CP_Invoice_Clearing_L2__c =u1.id,
                Total_Agreement_Value__c= 123456 +i,
                Brokerage_Lookup__c = brokerage.Id
            ));
        }
        insert invoices;
    }

   
     @isTest
    static void testMonthwiseBrokerageBatch() {
        Test.startTest();
        // Use a larger scope to ensure only one execute runs
        MonthwiseBrokerageRecords batch = new MonthwiseBrokerageRecords();
        Database.executeBatch(batch, 200);
        Test.stopTest();

        // Verify CP_Brokerage__c created
     
   
}
}