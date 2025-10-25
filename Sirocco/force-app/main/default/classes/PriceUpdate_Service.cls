/**
 * @description Service layer responsible for updating the prices and currency fields 
 * on the Bike and all related Part records.
 */
public with sharing class PriceUpdate_Service {

    /**
     * @description Orchestrates the price update: fetches rate, calculates new prices, and performs DML.
     * This is the method exposed to the Lightning Web Component.
     * @param bikeId The ID of the Bike record to update.
     * @param newCurrency The new currency code to set.
     * @param exchangeRate The calculated conversion rate (e.g., USD to SEK).
     */
    @AuraEnabled
    public static void updateBikeAndPartsPrices(Id bikeId, String newCurrency, Decimal exchangeRate) {
        // Query the Bike and its related Parts
        // Note: The Price__c and Currency__c fields are now Number and Picklist, not Currency type.
        Bike__c bike = [SELECT Id, Price__c, Currency__c, 
                        (SELECT Id, Price__c, Currency__c FROM Parts__r) 
                        FROM Bike__c 
                        WHERE Id = :bikeId 
                        LIMIT 1];

        List<SObject> recordsToUpdate = new List<SObject>();
        
        // 1. Update the Bike Price and Currency
        Decimal oldBikePrice = bike.Price__c != null ? bike.Price__c : 0;
        bike.Price__c = (oldBikePrice * exchangeRate).setScale(2, RoundingMode.HALF_UP);
        bike.Currency__c = newCurrency;
        recordsToUpdate.add(bike);
        
        // 2. Update all related Parts
        if (bike.Parts__r != null) {
            for (Part__c part : bike.Parts__r) {
                Decimal oldPartPrice = part.Price__c != null ? part.Price__c : 0;
                part.Price__c = (oldPartPrice * exchangeRate).setScale(2, RoundingMode.HALF_UP);
                // CRITICAL FIX: Update the Part's Currency__c field as well
                part.Currency__c = newCurrency; 
                recordsToUpdate.add(part);
            }
        }

        // 3. Perform DML (Database Update)
        if (!recordsToUpdate.isEmpty()) {
            try {
                update recordsToUpdate;
            } catch (DmlException e) {
                throw new AuraHandledException('Database Error: Failed to update records: ' + e.getDmlMessage(0));
            }
        }
    }
    
    /**
     * @description Helper method exposed to LWC to initiate the process by getting the rate first.
     * @param baseCurrency The current currency.
     * @param targetCurrency The new currency.
     * @return The calculated exchange rate.
     */
    @AuraEnabled(cacheable=true)
    public static Decimal getExchangeRate(String baseCurrency, String targetCurrency) {
        // Delegate API callout logic to the dedicated integration class
        return ExchangeRate_API.getRate(baseCurrency, targetCurrency);
    }
}