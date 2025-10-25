@isTest
private class PriceUpdate_Service_Test {
    
   public class MockRateResponse implements HttpCalloutMock {
        public String getRateMockBody;
        
        public MockRateResponse(String baseCurrency, String targetCurrency) {
            this.getRateMockBody = '{"success":true,"base":"EUR","date":"2025-10-14","rates":{' +
                                   '"' + baseCurrency + '": 1.05,' +
                                   '"' + targetCurrency + '": 12.60,' +
                                   '"EUR": 1' +
                                   '}}';
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(getRateMockBody);
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        // Create Bike record (initial currency: USD, Price: $1000)
        Bike__c bike = new Bike__c(
            Currency__c = 'USD', 
            Price__c = 1000.00
        );
        insert bike;
        
        // Create related Part records
        List<Part__c> parts = new List<Part__c>();
        parts.add(new Part__c(
            Bike__c = bike.Id, 
            Price__c = 150.00,
            Currency__c = 'USD' // Added currency field initialization
        ));
        parts.add(new Part__c(
            Bike__c = bike.Id, 
            Price__c = 250.00,
            Currency__c = 'USD' // Added currency field initialization
        ));
        insert parts;
    }
    
    @isTest
    static void testGetRate_Success() {
        // ... (Test.setMock and assertions for ExchangeRate_API.getRate) ...
        // Note: The LWC now calls PriceUpdate_Service.getExchangeRate, which delegates to ExchangeRate_API.getRate
        String baseCurrency = 'USD';
        String targetCurrency = 'SEK';
        
        Test.setMock(HttpCalloutMock.class, new MockRateResponse(baseCurrency, targetCurrency));

        Test.startTest();
        // Call the service method exposed to LWC
        Decimal exchangeRate = PriceUpdate_Service.getExchangeRate(baseCurrency, targetCurrency);
        Test.stopTest();

        // 12.60 / 1.05 = 12.00
        System.assertEquals(12.00, exchangeRate, 'Exchange rate should be correctly calculated.');
    }

    @isTest
    static void testUpdatePrices_Success() {
        // Arrange
        Bike__c bike = [SELECT Id FROM Bike__c LIMIT 1];
        Id bikeId = bike.Id;
        String newCurrency = 'SEK';
        Decimal exchangeRate = 12.00; 

        Test.startTest();
        // Call the DML update method
        PriceUpdate_Service.updateBikeAndPartsPrices(bikeId, newCurrency, exchangeRate);
        Test.stopTest();

        // Assert Bike Update
        Bike__c updatedBike = [SELECT Id, Currency__c, Price__c FROM Bike__c WHERE Id = :bikeId];
        System.assertEquals('SEK', updatedBike.Currency__c, 'Bike currency should be updated to SEK.');
        System.assertEquals(12000.00, updatedBike.Price__c, 'Bike price should be updated to 12000.00.');
        
        // Assert Part Update (Checking both Price and Currency)
        List<Part__c> updatedParts = [SELECT Price__c, Currency__c FROM Part__c WHERE Bike__c = :bikeId ORDER BY Price__c ASC];
        System.assertEquals(1800.00, updatedParts[0].Price__c, 'First part price (150) should be 1800.00.');
        System.assertEquals('SEK', updatedParts[0].Currency__c, 'First part currency should be updated to SEK.');

        System.assertEquals(3000.00, updatedParts[1].Price__c, 'Second part price (250) should be 3000.00.');
        System.assertEquals('SEK', updatedParts[1].Currency__c, 'Second part currency should be updated to SEK.');
    }

    @isTest
    static void testUpdatePrices_NoParts() {
        Bike__c soloBike = new Bike__c(
            Currency__c = 'USD', 
            Price__c = 500.00
        );
        insert soloBike;
        
        Id bikeId = soloBike.Id;
        String newCurrency = 'EUR';
        Decimal exchangeRate = 0.95; 

        Test.startTest();
        PriceUpdate_Service.updateBikeAndPartsPrices(bikeId, newCurrency, exchangeRate);
        Test.stopTest();

        Bike__c updatedBike = [SELECT Id, Currency__c, Price__c FROM Bike__c WHERE Id = :bikeId];
        System.assertEquals('EUR', updatedBike.Currency__c, 'Solo Bike currency should be updated to EUR.');
        System.assertEquals(475.00, updatedBike.Price__c, 'Solo Bike price should be 475.00 (500 * 0.95).');
        
        Integer partCount = [SELECT COUNT() FROM Part__c WHERE Bike__c = :bikeId];
        System.assertEquals(0, partCount, 'No parts should exist for this bike.');
    }

    // I need to update the following... (testGetRate_CalloutFailure and testUpdatePrices_NoParts methods go here, I need to update them to call PriceUpdate_Service) ...
}