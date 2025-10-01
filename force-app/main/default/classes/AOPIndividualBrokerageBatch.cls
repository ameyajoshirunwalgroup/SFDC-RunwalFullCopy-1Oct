public with sharing class AOPIndividualBrokerageBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private String processType; // 'BY_END_DATE' or 'BY_FY'
    private String targetFY;
    private Date targetDate;
    private Date executionDate; // Automatically set to today's date when batch runs
    
    // Constructor for processing by FY
    public AOPIndividualBrokerageBatch(String financialYear) {
        this.processType = 'BY_FY';
        this.targetFY = financialYear;
        this.executionDate = Date.today(); // Always use today's date automatically
    }
    
    // Constructor for processing by end date
    public AOPIndividualBrokerageBatch(Date endDate) {
        this.processType = 'BY_END_DATE';
        this.targetDate = endDate;
        this.executionDate = Date.today(); // Always use today's date automatically
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT Id, Name, Channel_Partner__c, Start_Date__c, End_Date__c, ' +
                      'Commitment_max__c, ' +
                      'Channel_Partner__r.Name, Channel_Partner__r.Account__c ' +
                      'FROM AOP__c ' +
                      'WHERE Commitment_max__c != null ' +
                      'AND Channel_Partner__c != null ';
        
        if (processType == 'BY_END_DATE') {
            query += 'AND End_Date__c = :targetDate ';
        } else if (processType == 'BY_FY') {
            Date fyStart = getFYStart(targetFY);
            Date fyEnd = getFYEnd(targetFY);
            query += 'AND Start_Date__c <= :fyEnd AND End_Date__c >= :fyStart ';
        }
        
        query += 'ORDER BY Channel_Partner__c, End_Date__c';
        
        System.debug(' AOP Query: ' + query);
        System.debug(' Batch Execution Date: ' + Date.today() + ' (will compare against each AOP period individually)');
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<AOP__c> aopScope) {
        System.debug(' Processing ' + aopScope.size() + ' AOP records');
        
        List<Brokerage__c> brokeragesToInsert = new List<Brokerage__c>();
        
        for (AOP__c aop : aopScope) {
            try {
                processIndividualAOP(aop, brokeragesToInsert);
            } catch (Exception e) {
                System.debug(' Error processing AOP ' + aop.Id + ': ' + e.getMessage());
            }
        }
        
        // Insert brokerage records
        if (!brokeragesToInsert.isEmpty()) {
            try {
                insert brokeragesToInsert;
                System.debug(' Inserted ' + brokeragesToInsert.size() + ' brokerage records');
            } catch (Exception e) {
                System.debug(' Error inserting brokerage records: ' + e.getMessage());
                throw e;
            }
        }
    }
    
    private void processIndividualAOP(AOP__c aop, List<Brokerage__c> brokerages) {
        System.debug(' Processing AOP: ' + aop.Name + ' | CP: ' + aop.Channel_Partner__r.Name);
        System.debug('AOP Period: ' + aop.Start_Date__c + ' to ' + aop.End_Date__c);
        System.debug(' Max Commitment: ' + aop.Commitment_max__c);
        
        // Determine payout timing based on execution date vs AOP period
        PayoutTiming payoutTiming = determinePayoutTiming(aop);
        System.debug(' Payout Timing: ' + payoutTiming);
        
        // Get eligible bookings for this AOP period with AOP_Scheme matching
        DateTime aopStartDateTime = DateTime.newInstance(aop.Start_Date__c, Time.newInstance(0, 0, 0, 0));
        DateTime aopEndDateTime = DateTime.newInstance(aop.End_Date__c, Time.newInstance(23, 59, 59, 999));
        
        List<Booking__c> eligibleBookings = [
            SELECT Id, Name, Opportunity__c, BrokerIId__c, BrokerIId__r.Account__c, 
                   Agreement_Value_for_brokers__c, Project__c, Booking_Date__c, Tower__c, 
                   X5_Received__c, RW_X9_99_Received__c, Status__c, RW_Registration_Done__c, 
                   Brokerage_Scheme__c, Is_Special_Brokerage_Scheme__c, Type_Of_Client_Formula__c, 
                   RW_Registration_Date__c, Type_of_Client__c, Source_of_Booking__c, AOP_Scheme__c,
                   Brokerage_Summary__c, Brokerage_Summary__r.Id, Brokerage_Summary__r.Name
            FROM Booking__c
            WHERE BrokerIId__c = :aop.Channel_Partner__c
              AND BrokerIId__c != null
              AND AOP_Scheme__c = :aop.Id
              AND Booking_Date__c >= :aopStartDateTime
              AND Booking_Date__c <= :aopEndDateTime
              AND (RW_X9_99_Received__c = true OR X5_Received__c = true)
              AND Status__c = 'Booking Confirmed'
              AND RW_Registration_Done__c = 'Yes'
              AND Brokerage_Summary__c != null // Only bookings with existing summary
        ];
        
        System.debug(' Found ' + eligibleBookings.size() + ' eligible bookings with matching AOP scheme and existing summary');
        
        if (eligibleBookings.isEmpty()) {
            System.debug('️ No eligible bookings found for AOP: ' + aop.Name);
            return;
        }
        
        // FIXED: Calculate total combined value for ALL bookings to determine slab
        Decimal totalCombinedBookingValue = 0;
        Decimal totalCombinedAVForBrokerage = 0;
        
        for (Booking__c booking : eligibleBookings) {
            Decimal avForBrokerage = booking.Agreement_Value_for_brokers__c ?? 0;
            totalCombinedBookingValue += avForBrokerage;
            totalCombinedAVForBrokerage += avForBrokerage;
        }
        
        System.debug(' TOTAL COMBINED VALUES FOR SLAB CALCULATION:');
        System.debug('   - Combined Booking Value: ' + totalCombinedBookingValue);
        System.debug('   - Combined AV for Brokerage: ' + totalCombinedAVForBrokerage);
        
        // Group bookings by their Brokerage Summary
        Map<Id, List<Booking__c>> bookingsBySummary = new Map<Id, List<Booking__c>>();
        Map<Id, Brokerage_Summary__c> summaryMap = new Map<Id, Brokerage_Summary__c>();

        Set<Id> summaryIds = new Set<Id>();
        
        for (Booking__c booking : eligibleBookings) {
            if (!bookingsBySummary.containsKey(booking.Brokerage_Summary__c)) {
                bookingsBySummary.put(booking.Brokerage_Summary__c, new List<Booking__c>());
            }
            bookingsBySummary.get(booking.Brokerage_Summary__c).add(booking);
            summaryIds.add(booking.Brokerage_Summary__c);
        }
        
        // Query and populate summaryMap
        List<Brokerage_Summary__c> summariesList = [
            SELECT Id, Name, AOP__c 
            FROM Brokerage_Summary__c 
            WHERE Id IN :summaryIds
        ];
        
        for (Brokerage_Summary__c summary : summariesList) {
            summaryMap.put(summary.Id, summary);
        }
        
        updateSummaryAOPMapping(summaryMap.values(), aop.Id);
        System.debug(' Bookings grouped into ' + bookingsBySummary.size() + ' summary records');
        
        // Calculate individual summary values for logging
        Map<Id, Decimal> totalAVBySummary = new Map<Id, Decimal>();
        Map<Id, Decimal> totalBookingValueBySummary = new Map<Id, Decimal>();
        
        for (Id summaryId : bookingsBySummary.keySet()) {
            Decimal totalAVForBrokerage = 0;
            Decimal totalBookingValue = 0;
            
            for (Booking__c booking : bookingsBySummary.get(summaryId)) {
                Decimal avForBrokerage = booking.Agreement_Value_for_brokers__c ?? 0;
                totalAVForBrokerage += avForBrokerage;
                totalBookingValue += avForBrokerage;
            }
            
            totalAVBySummary.put(summaryId, totalAVForBrokerage);
            totalBookingValueBySummary.put(summaryId, totalBookingValue);
            
            System.debug(' Summary ' + summaryId + ': Individual AV = ' + totalAVForBrokerage + ', Individual Booking Value = ' + totalBookingValue);
        }
        
        // Get AOP slabs
        List<AOP_Slab__c> aopSlabs = [
            SELECT Id, AOP__c, Lower_Limit__c, Upper_Limit__c, Brokerage_Rate__c, Priority__c, Slab_Name__c
            FROM AOP_Slab__c
            WHERE AOP__c = :aop.Id
            ORDER BY Priority__c ASC, Lower_Limit__c ASC
        ];
        
        if (aopSlabs.isEmpty()) {
            System.debug('️ No slabs found for AOP: ' + aop.Name);
            return;
        }
        
        // FIXED: Find assigned slab based on TOTAL COMBINED booking value
        AOP_Slab__c assignedSlab = findAssignedSlab(aop, aopSlabs, totalCombinedBookingValue);
        if (assignedSlab == null) {
            System.debug(' No assigned slab found for TOTAL combined booking value: ' + totalCombinedBookingValue);
            return;
        }
        
        System.debug(' ASSIGNED SLAB (based on combined value ' + totalCombinedBookingValue + '): ' + assignedSlab.Lower_Limit__c + '-' + assignedSlab.Upper_Limit__c + ' @ ' + assignedSlab.Brokerage_Rate__c + '%');
        
        // Check existing brokerage payments for ALL bookings
        BrokeragePaymentSummary paymentSummary = checkExistingBrokeragePayments(aop, eligibleBookings);
        
        // Apply payout logic based on timing, COMBINED booking values, and existing brokerage records
        PayoutResult payoutResult = calculatePayouts(totalCombinedBookingValue, totalCombinedAVForBrokerage, assignedSlab, aopSlabs, payoutTiming, paymentSummary);
        
        if (payoutResult.totalPayableAmount == 0) {
            System.debug('️ No brokerage payable for this AOP');
            return;
        }
        
        System.debug(' COMBINED PAYOUT CALCULATION COMPLETE:');
        System.debug('   - Timing: ' + payoutTiming);
        if (payoutResult.isInterimTriggered) {
            System.debug('   - Total Rate: ' + (payoutResult.rateApplied * 2) + '% (split: ' + payoutResult.rateApplied + '% now, ' + payoutResult.rateApplied + '% final)');
        } else {
            System.debug('   - Single Payout Rate: ' + payoutResult.rateApplied + '%');
        }
        System.debug('   - Total Payable Amount: ' + payoutResult.totalPayableAmount);
        
        // Process each summary group with the SAME rate (derived from combined calculation)
        for (Id summaryId : bookingsBySummary.keySet()) {
            List<Booking__c> summaryBookings = bookingsBySummary.get(summaryId);
            System.debug(' Creating brokerage records for summary ' + summaryId + ' with ' + summaryBookings.size() + ' bookings using rate: ' + payoutResult.rateApplied + '%');
            
            // Create brokerage records with the rate from combined calculation
            createBrokerageRecords(summaryBookings, aop, payoutResult, brokerages, payoutTiming, summaryId);
        }
    }
    
    private void updateSummaryAOPMapping(List<Brokerage_Summary__c> summaries, Id aopId) {
        List<Brokerage_Summary__c> summariesToUpdate = new List<Brokerage_Summary__c>();
        
        for (Brokerage_Summary__c summary : summaries) {
            // Only update if AOP is not already set or needs to be changed
            if (summary.AOP__c != aopId) {
                summary.AOP__c = aopId;
                summariesToUpdate.add(summary);
                System.debug(' Mapping AOP ' + aopId + ' to summary ' + summary.Name);
            }
        }
        
        if (!summariesToUpdate.isEmpty()) {
            try {
                update summariesToUpdate;
                System.debug(' Successfully updated AOP mapping for ' + summariesToUpdate.size() + ' summary records');
            } catch (Exception e) {
                System.debug(' Error updating AOP mapping for summaries: ' + e.getMessage());
            }
        }
    } 
    
    // Check existing brokerage payments for specific bookings
    private BrokeragePaymentSummary checkExistingBrokeragePayments(AOP__c aop, List<Booking__c> eligibleBookings) {
        BrokeragePaymentSummary summary = new BrokeragePaymentSummary();
        
        // Get existing brokerage records for these specific bookings and this channel partner
        Set<Id> bookingIds = new Set<Id>();
        for (Booking__c booking : eligibleBookings) {
            bookingIds.add(booking.Id);
        }
        
        List<Brokerage__c> existingBrokerages = [
            SELECT Id, Booking__c, Brokerage__c, Brokerage_Amount__c, Brokerage_Type__c, 
                   Channel_Partner__c, CreatedDate, Name, Brokerage_Summary__c
            FROM Brokerage__c 
            WHERE Channel_Partner__c = :aop.Channel_Partner__c
              AND Booking__c IN :bookingIds
              AND (Brokerage_Type__c = 'AOP Brokerage' 
                   OR Brokerage_Type__c = 'AOP Interim Brokerage' 
                   OR Brokerage_Type__c = 'AOP Final Brokerage')
            ORDER BY CreatedDate
        ];
        
        System.debug(' Found ' + existingBrokerages.size() + ' existing AOP brokerage records for these bookings');
        
        // Analyze existing brokerage payments from Brokerage__c records
        for (Brokerage__c brokerage : existingBrokerages) {
            Decimal amount = brokerage.Brokerage_Amount__c ?? 0;
            Decimal rate = brokerage.Brokerage__c ?? 0;
            
            summary.totalAmountPaid += amount;
            summary.totalRatePaid += rate;
            
            if (brokerage.Brokerage_Type__c == 'AOP Interim Brokerage') {
                summary.hasInterimPayment = true;
                summary.interimAmountPaid += amount;
                summary.interimRatePaid += rate;
                summary.interimRecordCount++;
            } else if (brokerage.Brokerage_Type__c == 'AOP Final Brokerage') {
                summary.hasFinalPayment = true;
                summary.finalAmountPaid += amount;
                summary.finalRatePaid += rate;
                summary.finalRecordCount++;
            } else if (brokerage.Brokerage_Type__c == 'AOP Brokerage') {
                summary.hasFullPayment = true;
                summary.fullAmountPaid += amount;
                summary.fullRatePaid += rate;
                summary.fullRecordCount++;
            }
            
            System.debug('    Brokerage Record: ' + brokerage.Name + ' | Type: ' + brokerage.Brokerage_Type__c + ' | Rate: ' + rate + '% | Amount: ' + amount);
        }
        
        System.debug(' Brokerage Payment Summary from existing records:');
        System.debug('   - Interim Payments: ' + summary.hasInterimPayment + ' (Records: ' + summary.interimRecordCount + ', Rate: ' + summary.interimRatePaid + '%, Amount: ' + summary.interimAmountPaid + ')');
        System.debug('   - Final Payments: ' + summary.hasFinalPayment + ' (Records: ' + summary.finalRecordCount + ', Rate: ' + summary.finalRatePaid + '%, Amount: ' + summary.finalAmountPaid + ')');
        System.debug('   - Full Payments: ' + summary.hasFullPayment + ' (Records: ' + summary.fullRecordCount + ', Rate: ' + summary.fullRatePaid + '%, Amount: ' + summary.fullAmountPaid + ')');
        System.debug('   - Total Paid: Rate ' + summary.totalRatePaid + '%, Amount: ' + summary.totalAmountPaid);
        
        return summary;
    }
    
    // Determine payout timing based on TODAY'S date vs each individual AOP period
    private PayoutTiming determinePayoutTiming(AOP__c aop) {
        Date today = Date.today(); // Get today's date for comparison
        
        System.debug(' Today: ' + today + ' | AOP Period: ' + aop.Start_Date__c + ' to ' + aop.End_Date__c);
        
        // Check if today is at the end of AOP period (last day or after)
        if (today >= aop.End_Date__c) {
            System.debug(' Final payout timing - today is at/after AOP end date');
            return PayoutTiming.FINAL_ONLY;
        }
        
        // Check if today is during the middle of AOP period
        if (today > aop.Start_Date__c && today < aop.End_Date__c) {
            System.debug(' Interim payout timing - today is during AOP period');
            return PayoutTiming.INTERIM_ELIGIBLE;
        }
        
        // If today is before AOP start, treat as interim eligible for future processing
        System.debug(' Early timing - today is before AOP start, treating as interim eligible');
        return PayoutTiming.INTERIM_ELIGIBLE;
    }
    
    private AOP_Slab__c findAssignedSlab(AOP__c aop, List<AOP_Slab__c> slabs, Decimal totalBookingValue) {
        if (slabs.isEmpty()) return null;

        // First, try to find slab where totalBookingValue fits
        for (AOP_Slab__c slab : slabs) {
            if (totalBookingValue >= slab.Lower_Limit__c && totalBookingValue <= slab.Upper_Limit__c) {
                return slab; 
            }
        }

        // If totalBookingValue exceeds highest slab, return highest slab
        AOP_Slab__c highestSlab = slabs[slabs.size() - 1];
        if (totalBookingValue > highestSlab.Upper_Limit__c) {
            return highestSlab; 
        }

        // Fall back to commitment max based assignment
        for (AOP_Slab__c slab : slabs) {
            if (aop.Commitment_max__c >= slab.Lower_Limit__c && aop.Commitment_max__c <= slab.Upper_Limit__c) {
                return slab; 
            }
        }

        return null;
    }
    
    // Calculate payouts with correct percentage handling using COMBINED values
    private PayoutResult calculatePayouts(Decimal totalCombinedBookingValue, Decimal totalCombinedAVForBrokerage, 
                                        AOP_Slab__c assignedSlab, List<AOP_Slab__c> allSlabs, PayoutTiming timing, BrokeragePaymentSummary paymentSummary) {
        PayoutResult result = new PayoutResult();
        
        System.debug(' Calculating payouts with timing: ' + timing);
        System.debug('   Assigned slab upper limit: ' + assignedSlab.Upper_Limit__c);
        System.debug('   TOTAL COMBINED booking value: ' + totalCombinedBookingValue);
        
        // First, check if payment is already complete based on existing Brokerage__c records
        if (paymentSummary.hasFullPayment) {
            System.debug(' Full payment already made via Brokerage__c records - no additional payout needed');
            result.totalPayableAmount = 0;
            return result;
        }
        
        // Check if COMBINED booking value qualifies for the assigned slab
        Boolean qualifiesForAssignedSlab = totalCombinedBookingValue >= assignedSlab.Upper_Limit__c;
        Decimal expectedTotalRate = assignedSlab.Brokerage_Rate__c ?? 0;
        
        // Check for downgrades if not qualifying for assigned slab
        if (!qualifiesForAssignedSlab && totalCombinedBookingValue < assignedSlab.Lower_Limit__c) {
            AOP_Slab__c lowerSlab = findOneLevelLowerSlab(assignedSlab, allSlabs);
            if (lowerSlab != null && totalCombinedBookingValue >= lowerSlab.Lower_Limit__c && totalCombinedBookingValue <= lowerSlab.Upper_Limit__c) {
                expectedTotalRate = lowerSlab.Brokerage_Rate__c ?? 0;
                result.isDowngradeApplied = true;
                System.debug('️ Downgrade applied based on COMBINED value - using lower slab rate: ' + expectedTotalRate + '%');
            } else {
                System.debug(' No qualifying slab found for COMBINED booking value: ' + totalCombinedBookingValue);
                result.totalPayableAmount = 0;
                return result;
            }
        }
        
        Decimal expectedTotalAmount = (totalCombinedAVForBrokerage * expectedTotalRate) / 100;
        System.debug(' Expected Total (based on combined values): Rate ' + expectedTotalRate + '%, Amount: ' + expectedTotalAmount);
        
        if (timing == PayoutTiming.INTERIM_ELIGIBLE && qualifiesForAssignedSlab) {
            // Interim scenario - check existing Brokerage__c records
            if (paymentSummary.hasInterimPayment) {
                System.debug(' Interim payment already exists in Brokerage__c records - no additional interim payout');
                result.totalPayableAmount = 0;
                return result;
            }
            
            // Calculate interim payout (50% of total rate)
            result.isInterimTriggered = true;
            result.rateApplied = expectedTotalRate / 2; // 50% of total rate (e.g., 2% becomes 1%)
            result.totalPayableAmount = expectedTotalAmount / 2; // 50% of total amount
            result.interimPayout = result.totalPayableAmount;
            result.remainingAmount = expectedTotalAmount / 2; // Remaining 50%
            
            System.debug(' Interim payout: ' + result.rateApplied + '% rate, ' + result.totalPayableAmount + ' amount');
            System.debug(' Remaining for final: ' + (expectedTotalRate / 2) + '% rate, ' + result.remainingAmount + ' amount');
            
        } else if (timing == PayoutTiming.FINAL_ONLY) {
            // Final scenario - check existing Brokerage__c records
            if (paymentSummary.hasInterimPayment && !paymentSummary.hasFinalPayment) {
                // Has interim in Brokerage__c, needs final payment (remaining 50%)
                result.isFinalPayoutOnly = true;
                result.rateApplied = expectedTotalRate / 2; // Remaining 50% of rate
                result.totalPayableAmount = expectedTotalAmount / 2; // Remaining 50% of amount
                result.finalPayout = result.totalPayableAmount;
                
                System.debug(' Final payout (remaining 50%): ' + result.rateApplied + '% rate, ' + result.totalPayableAmount + ' amount');
                
            } else if (!paymentSummary.hasInterimPayment && !paymentSummary.hasFinalPayment && !paymentSummary.hasFullPayment) {
                // No previous payments in Brokerage__c records - full payout at end
                result.rateApplied = expectedTotalRate;
                result.totalPayableAmount = expectedTotalAmount;
                result.finalPayout = result.totalPayableAmount;
                
                System.debug(' Full payout at end: ' + result.rateApplied + '% rate, ' + result.totalPayableAmount + ' amount');
                
            } else if (paymentSummary.hasFinalPayment) {
                System.debug(' Final payment already exists in Brokerage__c records - no additional payout needed');
                result.totalPayableAmount = 0;
                return result;
            }
            
        } else {
            // Doesn't qualify for interim or other scenarios
            result = calculateFinalPayoutOnly(totalCombinedBookingValue, totalCombinedAVForBrokerage, assignedSlab, allSlabs, paymentSummary);
        }
        
        // Final validation - ensure we don't overpay based on existing Brokerage__c records
        Decimal totalPaidSoFar = paymentSummary.totalAmountPaid;
        if (totalPaidSoFar + result.totalPayableAmount > expectedTotalAmount) {
            Decimal adjustedAmount = expectedTotalAmount - totalPaidSoFar;
            System.debug('️ Adjusting payout to prevent overpayment based on Brokerage__c records: ' + result.totalPayableAmount + ' → ' + adjustedAmount);
            result.totalPayableAmount = Math.max(0, adjustedAmount);
        }
        
        return result;
    }
    
    private PayoutResult calculateFinalPayoutOnly(Decimal totalBookingValue, Decimal totalAVForBrokerage,
                                                AOP_Slab__c assignedSlab, List<AOP_Slab__c> allSlabs, BrokeragePaymentSummary paymentSummary) {
        PayoutResult result = new PayoutResult();
        
        // Check if already paid based on existing Brokerage__c records
        if (paymentSummary.hasFullPayment || (paymentSummary.hasInterimPayment && paymentSummary.hasFinalPayment)) {
            System.debug(' Payment already complete based on existing Brokerage__c records');
            result.totalPayableAmount = 0;
            return result;
        }
        
        // Check if within assigned slab range
        if (totalBookingValue >= assignedSlab.Lower_Limit__c && totalBookingValue <= assignedSlab.Upper_Limit__c) {
            result.rateApplied = assignedSlab.Brokerage_Rate__c ?? 0;
            Decimal expectedAmount = (totalAVForBrokerage * result.rateApplied) / 100;
            result.totalPayableAmount = expectedAmount - paymentSummary.totalAmountPaid;
            result.finalPayout = result.totalPayableAmount;
            System.debug(' Within assigned slab range - paying remaining: ' + result.totalPayableAmount + ' (Expected: ' + expectedAmount + ', Already paid: ' + paymentSummary.totalAmountPaid + ')');
            
        } else if (totalBookingValue < assignedSlab.Lower_Limit__c) {
            // Check for one level lower slab
            AOP_Slab__c lowerSlab = findOneLevelLowerSlab(assignedSlab, allSlabs);
            
            if (lowerSlab != null && totalBookingValue >= lowerSlab.Lower_Limit__c && totalBookingValue <= lowerSlab.Upper_Limit__c) {
                result.rateApplied = lowerSlab.Brokerage_Rate__c ?? 0;
                Decimal expectedAmount = (totalAVForBrokerage * result.rateApplied) / 100;
                result.totalPayableAmount = expectedAmount - paymentSummary.totalAmountPaid;
                result.finalPayout = result.totalPayableAmount;
                result.isDowngradeApplied = true;
                System.debug(' Lower slab applied - paying remaining: ' + result.totalPayableAmount + ' (Expected: ' + expectedAmount + ', Already paid: ' + paymentSummary.totalAmountPaid + ')');
            } else {
                result.totalPayableAmount = 0;
                System.debug(' No qualifying slab found');
            }
        } else if (totalBookingValue >= assignedSlab.Upper_Limit__c) {
            // Exceeds upper limit but no interim was triggered (final payout scenario)
            result.rateApplied = assignedSlab.Brokerage_Rate__c ?? 0;
            Decimal expectedAmount = (totalAVForBrokerage * result.rateApplied) / 100;
            result.totalPayableAmount = expectedAmount - paymentSummary.totalAmountPaid;
            result.finalPayout = result.totalPayableAmount;
            System.debug(' Exceeds slab limit - paying remaining: ' + result.totalPayableAmount + ' (Expected: ' + expectedAmount + ', Already paid: ' + paymentSummary.totalAmountPaid + ')');
        } else {
            result.totalPayableAmount = 0;
            System.debug(' No qualifying condition met');
        }
        
        // Ensure we don't pay negative amounts
        result.totalPayableAmount = Math.max(0, result.totalPayableAmount);
        
        return result;
    }
    
    private AOP_Slab__c findOneLevelLowerSlab(AOP_Slab__c currentSlab, List<AOP_Slab__c> allSlabs) {
        // Build a map of slabs by numeric value extracted from Slab_Name__c
        Map<Integer, AOP_Slab__c> slabByNumber = new Map<Integer, AOP_Slab__c>();
        for (AOP_Slab__c slab : allSlabs) {
            if (slab.Slab_Name__c != null) {
                // Extract number part (e.g., "Slab 3" → 3)
                String numStr = slab.Slab_Name__c.replaceAll('[^0-9]', '');
                if (String.isNotBlank(numStr)) {
                    Integer slabNum = Integer.valueOf(numStr);
                    slabByNumber.put(slabNum, slab);
                }
            }
        }

        // Get current slab number
        if (currentSlab.Slab_Name__c == null) return null;
        String currentNumStr = currentSlab.Slab_Name__c.replaceAll('[^0-9]', '');
        if (String.isBlank(currentNumStr)) return null;
        
        Integer currentNum = Integer.valueOf(currentNumStr);

        // Step down through lower slabs until we find one
        for (Integer i = currentNum - 1; i >= 1; i--) {
            if (slabByNumber.containsKey(i)) {
                return slabByNumber.get(i); // immediate lower slab
            }
        }
        return null;
    }
    
    // Modified method to use existing summary ID
    private void createBrokerageRecords(List<Booking__c> bookings, AOP__c aop, PayoutResult payoutResult, 
                                      List<Brokerage__c> brokerages, PayoutTiming timing, Id summaryId) {
        
        if (payoutResult.isInterimTriggered && timing == PayoutTiming.INTERIM_ELIGIBLE) {
            Decimal interimRate = payoutResult.rateApplied; 
            createBrokerageRecordsForPayout(bookings, aop, interimRate, 'AOP Interim Brokerage', brokerages, summaryId);
            System.debug(' Created interim brokerage records linked to summary: ' + summaryId);
            
        } else if (payoutResult.isFinalPayoutOnly && timing == PayoutTiming.FINAL_ONLY) {
            Decimal finalRate = payoutResult.rateApplied; 
            createBrokerageRecordsForPayout(bookings, aop, finalRate, 'AOP Final Brokerage', brokerages, summaryId);
            System.debug(' Created final brokerage records (remaining 50%) linked to summary: ' + summaryId);
            
        } else {
            // Create single full payout records
            createBrokerageRecordsForPayout(bookings, aop, payoutResult.rateApplied, 'AOP Brokerage', brokerages, summaryId);
            System.debug(' Created full brokerage records linked to summary: ' + summaryId);
        }
    }
    
    // Modified method to link to existing summary
    private void createBrokerageRecordsForPayout(List<Booking__c> bookings, AOP__c aop, Decimal rate, String brokerageType, List<Brokerage__c> brokerages, Id summaryId) {
        for (Booking__c booking : bookings) {
            Decimal bookingAV = booking.Agreement_Value_for_brokers__c ?? 0;
            Decimal bookingBrokerageAmount = (bookingAV * rate) / 100;
            
            Brokerage__c brokerageRecord = new Brokerage__c(
                Name = brokerageType,
                Booking__c = booking.Id,
                Channel_Partner__c = aop.Channel_Partner__c,
                Brokerage_Type__c = brokerageType,
                AOP_Brokerage__c  = rate,
                Status__c = 'Due',
                Brokerage_Amount__c = bookingBrokerageAmount,
                Brokerage_Summary__c = summaryId // Link to existing summary
            );
            brokerages.add(brokerageRecord);
        }
    }

    public void finish(Database.BatchableContext bc) {
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, CompletedDate
                           FROM AsyncApexJob WHERE Id = :bc.getJobId()];
        
        System.debug(' AOP Individual Brokerage Batch completed');
        System.debug('Job Status: ' + job.Status);
        System.debug(' Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
        System.debug(' Errors: ' + job.NumberOfErrors);
        System.debug(' Completed: ' + job.CompletedDate);
    }
    
    private enum PayoutTiming {
        INTERIM_ELIGIBLE,  
        FINAL_ONLY       
    }
    
    private class BrokeragePaymentSummary {
        public Decimal totalAmountPaid = 0;
        public Decimal totalRatePaid = 0;
        public Boolean hasInterimPayment = false;
        public Boolean hasFinalPayment = false;
        public Boolean hasFullPayment = false;
        public Decimal interimAmountPaid = 0;
        public Decimal interimRatePaid = 0;
        public Decimal finalAmountPaid = 0;
        public Decimal finalRatePaid = 0;
        public Decimal fullAmountPaid = 0;
        public Decimal fullRatePaid = 0;
        public Integer interimRecordCount = 0;
        public Integer finalRecordCount = 0;
        public Integer fullRecordCount = 0;
    }
    
    private class PayoutResult {
        public Decimal interimPayout = 0;
        public Decimal finalPayout = 0;
        public Decimal totalPayableAmount = 0;
        public Decimal remainingAmount = 0; 
        public Decimal rateApplied = 0;
        public Boolean isInterimTriggered = false;
        public Boolean isDowngradeApplied = false;
        public Boolean isFinalPayoutOnly = false; 
    }
    
    // Date utility methods
    private Date getFYStart(String fy) {
        if (String.isBlank(fy)) {
            throw new IllegalArgumentException('Financial year cannot be blank');
        }
        String cleaned = fy.replace('FY', '').trim();
        String[] parts = cleaned.split('-');
        Integer startYear = Integer.valueOf(parts[0]);
        return Date.newInstance(startYear, 4, 1);
    }

    private Date getFYEnd(String fy) {
        if (String.isBlank(fy)) {
            throw new IllegalArgumentException('Financial year cannot be blank');
        }
        String cleaned = fy.replace('FY', '').trim();
        String[] parts = cleaned.split('-');
        Integer endYear;
        if (parts.size() > 1 && String.isNotBlank(parts[1])) {
            endYear = Integer.valueOf(parts[1]);
            if (endYear < 100) {
                endYear += 2000;
            }
        } else {
            endYear = Integer.valueOf(parts[0]) + 1;
        }
        return Date.newInstance(endYear, 3, 31);
    }
}