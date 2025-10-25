/**
 * @description Integration layer responsible for handling the API callout 
 * to the external exchange rates service.
 */
public with sharing class ExchangeRate_API {

    // Named Credential setup eliminates hardcoding the URL and secures the endpoint.
    private static final String NAMED_CREDENTIAL_NAME = 'callout:ExchangeRatesAPI';
    // Access Key should be stored securely in a Custom Metadata Type or Custom Setting
    // for true flexibility, but we'll use a constant for this fix:
    

    /**
     * @description Determines if the current execution context is a Sandbox or Scratch Org 
     * by querying the Organization object. This is the standard, most reliable Apex method.
     * @return True if in a sandbox environment, False otherwise (Production/Developer).
     */
    private static Boolean isSandbox() {
        // Query the Organization object to get the official environment type
        Organization orgInfo = [SELECT IsSandbox FROM Organization LIMIT 1];
        return orgInfo.IsSandbox;
    }

    /**
     * @description Retrieves the Access Key from the Custom Metadata Type ExchangeRateData__mdt,
     * matching the environment based on the IsSandbox__c field.
     * @return The API access key string.
     * @throws AuraHandledException If the metadata record for the current environment is not found.
     */
    private static String getAccessKey() {
    Boolean inSandbox = isSandbox();
    
    // FIX: Assign the query result to a List<ExchangeRateData__mdt>
    List<ExchangeRateData__mdt> keyDataList = [
        SELECT Access_Key__c 
        FROM ExchangeRateData__mdt 
        WHERE IsSandbox__c = :inSandbox
        LIMIT 1
    ];

    // Check if the list is empty instead of checking the SObject for null
    if (keyDataList.isEmpty() || String.isBlank(keyDataList[0].Access_Key__c)) {
        String environment = inSandbox ? 'Sandbox' : 'Production';
        // Improved exception message to clearly guide the admin to the missing config
        throw new AuraHandledException('Configuration Error: API Access Key not found in Custom Metadata for the ' + environment + ' environment. Check the IsSandbox__c field setting.');
    }

    // Return the key from the first (and only) element in the list
    return keyDataList[0].Access_Key__c;
}

    /**
     * @description Fetches exchange rates relative to the API's base (EUR) and calculates 
     * the cross-rate between the source and target currencies.
     * @param baseCurrency The current currency of the bike (e.g., USD).
     * @param targetCurrency The desired currency (e.g., SEK).
     * @return The Decimal exchange rate (base -> target).
     * @throws AuraHandledException If the API callout fails.
     */
    public static Decimal getRate(String baseCurrency, String targetCurrency) {
        if (baseCurrency.toUpperCase() == targetCurrency.toUpperCase()) {
            return 1.0;
        }

        // Retrieve the Access Key dynamically based on environment
        String accessKey = getAccessKey();

        HttpRequest req = new HttpRequest();
        // Use the Named Credential URL and append the path and query parameters
        String endpoint = NAMED_CREDENTIAL_NAME + '/v1/latest' + 
                          '?access_key=' + accessKey + 
                          '&symbols=' + baseCurrency + ',' + targetCurrency;
        
        req.setEndpoint(endpoint);
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
                    // Formula: Rate(Base -> Target) = Rate(EUR -> Target) / Rate(EUR -> Base)
                    Decimal exchangeRate = rateTargetInEUR / rateBaseInEUR;
                    return exchangeRate.setScale(6, RoundingMode.HALF_UP);
                }
            } else {
                throw new AuraHandledException('API Call Failed: Check API key and service status.');
            }
        } else {
            throw new AuraHandledException('HTTP Error: ' + res.getStatusCode() + ' - ' + res.getStatus());
        }
        
        return null;
    }
}