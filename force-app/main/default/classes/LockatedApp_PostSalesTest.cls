@isTest
public class LockatedApp_PostSalesTest {
    
    @isTest
    public static void test1(){
        
        String recordTypeId  = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account a = new Account();
        a.RecordTypeID=recordTypeId ;
        a.FirstName ='TestAccount1';
        a.LastName ='TestAccount2';
        a.PersonEmail = 'wc@email.com';
        a.City__c='TestCity';
        a.RW_Zip_Code__c = '999999';
        a.State__c ='Karnataka';
        a.Country__c ='India';
        a.Mobile_No__c = '9876543212';
        a.Alternate_Email__c = 'wc1@email.com';
        a.Gender__c='Male';
        a.Salutation = 'Mr.';
        a.Birth_Date__c = System.today().addYears(-20);   
        insert a;
        
        Project__c objpr = new Project__c();
        objpr.RW_Project_Code__c = 'T31';
        objpr.Name = 'Runwal Bliss';
        objpr.RDS_Short_Name__c = 'T';
        objpr.Start_Date__c = System.today().addDays(-5);
        objpr.RDS_Interest_Rate__c = 12;
        objpr.SAPMaterial_Code__c = '1211';
        objpr.RW_Project_Location_Videos_Link__c='test';
        objpr.RW_Project_Brochure_PublicUrl__c='test1';
        objpr.RW_SAP_Company_Code__c='5245';
        insert objpr;
        
        Tower__c t = UniversalTestClassSetup.setuptower(objpr.Id,'A','Residential');
        
        Project_Unit__c objPU1 = new Project_Unit__c();    
        objPU1.Name = 'TestFive';     
        objPU1.Unit_SAP_Code__c ='1R000333';
        objPU1.RW_Project__c = objpr.Id;
        objPU1.RW_Param1__c = '5';
        objPU1.UnitNo__c ='TestFive';
        objPU1.RW_Unit_status__c='Available';
        objPU1.RW_Booking_Date__c = system.Today();
        objPU1.Actual_Area_value__c = 2218;
        objPU1.New_Floor__c = '8';
        objPU1.RW_Param4__c ='A-4546';
        objPU1.TowerName__c = t.Id;
        objPU1.Carpet_Area__c = 10;
        objPU1.Saleable_Area__c=2218;
        objPU1.Single_car_park_Earmarked__c = 0;
        objPU1.Single_Open_Earmarked__c = 0;
        objPU1.Tandem_Open_Earmarked__c = 0;
        objPU1.Tandem_car_park_Earmarked__c = 0;
        objPU1.Tandem_Open_Earmarked__c = 0;
        objPU1.MLCP_Earmarked__c = 0;
        objPU1.Stack__c = 0;
        insert objPU1;
        
        Opportunity oppRec= new Opportunity();
        oppRec.RW_Project__c=objpr.id;
        oppRec.Name='Test 1';
        oppRec.RW_Email__c=a.PersonEmail;
        oppRec.StageName='Unit Booked';
        oppRec.CloseDate=system.today();
        oppRec.Status__c ='Active';
        oppRec.AccountId = a.Id;
        oppRec.Sales_Manager__c = 'SM2@g.com';
        oppRec.Sourcing_Manager__c='Aniket Sapre';
        oppRec.RW_Sourcing_Head__c='Adrian Dsouza';
        oppRec.RW_Sales_Associate__c='Karthik Chettiar';
        oppRec.RW_Closing_Head__c='Karthik Chettiar';
        oppRec.Walkin_Source__c='Direct';
        oppRec.SAP_Customer_Number__c='0020006618';
        oppRec.SalesOrder_Number__c='3010005457';
        oppRec.RW_Mobile_No__c = '1234567890';
        insert oppRec;
        
        Quotation__c q = new Quotation__c();
        q.Name = 'Q010101';
        q.Quote_Status__c = 'Valid';
        q.Prepared_Date__c = System.today();
        q.Project__c = objpr.Id;
        q.Project_Unit__c = objPU1.Id;
        q.FloorNo__c = 11;
        q.Opportunity__c = oppRec.Id;
        q.Appartment_Configuration__c = '1 BHK';
        q.Carpet_Area_Sq_Ft__c = 1200;
        q.Token_Amount__c =110000;
        q.ST_Token_Amount__c = 1000;
        q.Allow_booking_without_full_token__c = TRUE;
        q.Agreement_Value__c = 60422880;
        q.Agreement_Value_ST__c = 2537761;
        q.Other_Charges_Category_1__c = 'Other Charges';
        q.Other_Charges_Amount_1__c = 1000;
        q.Other_Charges_Category_2__c = 'Other Charges';
        q.Other_Charges_Amount_2__c = 1000;
        q.Other_Charges_Category_3__c = 'Other Charges';
        q.Other_Charges_Amount_3__c = 1000;
        q.Other_Charges_Category_4__c = 'Other Charges';
        q.Other_Charges_Amount_4__c = 1000;
        q.Other_Charges_Category_5__c = 'Other Charges';
        q.Other_Charges_Amount_5__c = 1000;
        q.Other_Charges_Category_6__c = 'Other Charges';
        q.Other_Charges_Amount_6__c = 1000;
        q.Other_Charges_Category_7__c = 'Other Charges';
        q.Other_Charges_Amount_7__c = 1000;
        q.Other_Charges_Category_8__c = 'Other Charges';
        q.Other_Charges_Amount_8__c = 1000;
        q.Other_Charges_Category_9__c = 'Other Charges';
        q.Other_Charges_Amount_9__c = 1000;
        q.Other_Charges_Category_10__c = 'Other Charges';
        q.Other_Charges_Amount_10__c = 1000;
        q.Other_Charges_Category_11__c = 'Other Charges';
        q.Other_Charges_Amount_11__c = 1000;
        q.Other_Charges_Category_12__c = 'Other Charges';
        q.Other_Charges_Amount_12__c = 1000;
        q.Other_Charges_Category_13__c = 'Other Charges';
        q.Other_Charges_Amount_13__c = 1000;
        q.Other_Charges_Category_14__c = 'Other Charges';
        q.Other_Charges_Amount_14__c = 1000;
        q.Other_Charges_Category_15__c = 'Other Charges';
        q.Other_Charges_Amount_15__c = 1000;
        q.Other_Charges_Category_16__c = 'Other Charges';
        q.Other_Charges_Amount_16__c = 1000;
        //q.Tandem_car_park_Additional__c = 1;
        //q.Tandem_Open_Additional__c= 1;
        //q.Single_car_park_Additional__c= 1;
        //q.Single_Open_Additional__c = 1;
        //q.Stack_Additional__c = 1;
        //q.MLCP_Additional__c = null;
        insert q;
        
        
        Booking__c objBking = new Booking__c();
        objBking.Customer__c = oppRec.Id;
        objBking.Project__c = objpr.Id;
        objBking.Opportunity__c = oppRec.Id;
        objBking.Unit_No__c = objPU1.id;
        objBking.Quotation__c = q.Id;
        objBking.Booking_Date__c = Date.today();
        objBking.Status__c ='Booking Confirmed';
        objBking.RW_Total_Receipt_Amount_Received__c = 1000;
        objBking.RW_Total_Receipt_Discount_Recieved__c = 0;
        objBking.Primary_Applicant_Email__c = 'test@mail.com';
        insert objBking;
        
        List<Applicant_Details__c> appList = new List<Applicant_Details__c>();
        Applicant_Details__c app1 = new Applicant_Details__c();
        app1.Applicant_Number__c = 'Primary Applicant';
        app1.PancardNo__c = 'ASFER5665G';
        app1.Address_Proof_Number__c = '125365478589';
        app1.Booking__c = objBking.id;
        appList.add(app1);
        
        Applicant_Details__c app2 = new Applicant_Details__c();
        app2.Applicant_Number__c = 'Secondary Applicant';
        app2.Last_Name__c = 'Test';
        app2.PancardNo__c = 'ASFER5665G';
        app2.Address_Proof_Number__c = '125365478589';
        app2.Booking__c = objBking.Id;
        appList.add(app2);
        insert appList;
        
        RW_Demand__c dem = new RW_Demand__c();
        dem.RW_Demand_Status__c = 'Due';
        dem.Booking__c = objBking.Id;
        dem.RW_Demand_Milestone__c = 'Booking Amount';
        insert dem;
        
        RW_Payment_Details__c rec = new RW_Payment_Details__c();
        rec.RW_Booking__c = objBking.Id;
        rec.RW_Payment_Amount__c = 1000;
        insert rec;
        
        Test.startTest();
        
        RestRequest req1 = new RestRequest(); 
        RestResponse res1 = new RestResponse();
        req1.requestURI = 'https://runwal--fullcopy.sandbox.my.salesforce.com/services/apexrest/customerDetails/'+objBking.Id; 
        req1.httpMethod = 'Get';
        req1.addHeader('Content-Type', 'application/json'); 
        RestContext.request = req1;
        RestContext.response = res1;
        LockatedApp_PostSales.doGet();
        
        Test.stopTest();
        
        
    }
}