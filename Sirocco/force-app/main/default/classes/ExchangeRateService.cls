public with sharing class ExchangeRateService {

    private static final String API_KEY = 'd1ea859ddd672fd99cd53597cadfbc73';
    private static final String ENDPOINT = 'https://api.exchangeratesapi.io/v1/latest';
    private static final String BASE_API_CURRENCY = 'EUR';


    @AuraEnabled(cacheable=true)
    public static Decimal getRate(String baseCurrency, String targetCurrency) {
        if (baseCurrency.toUpperCase() == targetCurrency.toUpperCase()) {
            return 1.0;
        }

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT + '?access_key=' + API_KEY + '&symbols=' + baseCurrency + ',' + targetCurrency);
        req.setMethod('GET');
        req.setTimeout(60000); 

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            if (results.containsKey('success') && (Boolean)results.get('success')) {
                Map<String, Object> rates = (Map<String, Object>) results.get('rates');

                Decimal rateTargetInEUR = (Decimal) rates.get(targetCurrency.toUpperCase());
                Decimal rateBaseInEUR = (Decimal) rates.get(baseCurrency.toUpperCase());

                if (rateTargetInEUR != null && rateBaseInEUR != null && rateBaseInEUR != 0) {

                    Decimal exchangeRate = rateTargetInEUR / rateBaseInEUR;
                    
                    return exchangeRate.setScale(6, RoundingMode.HALF_UP);
                }
            } else {
                System.debug('API call failed: ' + res.getBody());
                throw new AuraHandledException('Exchange rate API call failed.');
            }
        } else {
            throw new AuraHandledException('HTTP Error: ' + res.getStatusCode() + ' - ' + res.getStatus());
        }
        
        return null;
    }


    @AuraEnabled
    public static void updateBikeAndPartsPrices(Id bikeId, String newCurrency, Decimal exchangeRate) {
        Bike__c bike = [SELECT Id, Price__c, (SELECT Id, Price__c FROM Parts__r) 
                        FROM Bike__c 
                        WHERE Id = :bikeId 
                        LIMIT 1];

        Decimal oldBikePrice = bike.Price__c != null ? bike.Price__c : 0;
        
        bike.Price__c = (oldBikePrice * exchangeRate).setScale(2, RoundingMode.HALF_UP);
        bike.Currency__c = newCurrency;

        List<SObject> recordsToUpdate = new List<SObject>{bike};
        
        List<Part__c> partsToUpdate = new List<Part__c>();
        if (bike.Parts__r != null) {
            for (Part__c part : bike.Parts__r) {
                Decimal oldPartPrice = part.Price__c != null ? part.Price__c : 0;
                
                part.Price__c = (oldPartPrice * exchangeRate).setScale(2, RoundingMode.HALF_UP);
                partsToUpdate.add(part);
            }
            recordsToUpdate.addAll(partsToUpdate);
        }

        if (!recordsToUpdate.isEmpty()) {
            try {
                update recordsToUpdate;
            } catch (DmlException e) {
                throw new AuraHandledException('Database Error: Failed to update records: ' + e.getDmlMessage(0));
            }
        }
    }

}