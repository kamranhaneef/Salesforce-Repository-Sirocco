import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

import { getObjectInfo } from 'lightning/uiObjectInfoApi'; 
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

import BIKE_OBJECT from '@salesforce/schema/Bike__c';

import { getRecordNotifyChange } from 'lightning/uiRecordApi'; 

import BIKE_CURRENCY_FIELD from '@salesforce/schema/Bike__c.Currency__c';
import BIKE_PRICE_FIELD from '@salesforce/schema/Bike__c.Price__c';

import getRate from '@salesforce/apex/ExchangeRateService.getRate';
import updateBikeAndPartsPrices from '@salesforce/apex/ExchangeRateService.updateBikeAndPartsPrices';

const fields = [BIKE_CURRENCY_FIELD, BIKE_PRICE_FIELD];

export default class Sirocco_changeCurrency extends LightningElement {
    @api recordId;

    bikeCurrency;
    bikePrice;
    
    // LWC State Variables
    newCurrency = '';
    isLoading = false;

    currencyOptions = []; 

    @wire(getObjectInfo, { objectApiName: BIKE_OBJECT })
    bikeObjectInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$bikeObjectInfo.data.defaultRecordTypeId',
        fieldApiName: BIKE_CURRENCY_FIELD
    })
    wiredPicklistValues({ error, data }) {
        if (data) {
            this.currencyOptions = data.values.map(item => ({
                label: item.label,
                value: item.value
            }));
            
        } else if (error) {
            this.showToast('Error', 'Error retrieving currency options: ' + error.body.message, 'error');
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields })
    wiredBike({ error, data }) {
        if (data) {
            this.bikeCurrency = getFieldValue(data, BIKE_CURRENCY_FIELD);
            this.bikePrice = getFieldValue(data, BIKE_PRICE_FIELD);
            console.log('Bike Currency: ' + this.bikeCurrency + ', Price: ' + this.bikePrice);
            console.log('Record ID: ' + this.recordId);
            console.log('Data: ' + JSON.stringify(data));
            console.log('bikeCurrency: ' + this.bikeCurrency);
        } else if (error) {
            this.showToast('Error', 'Error retrieving Bike data: ' + error.body.message, 'error');
        }
    }
    
    get isSameCurrency() {
        if (!this.bikeCurrency || !this.newCurrency) {
            return false;
        }
        return this.newCurrency === this.bikeCurrency;
    }

    get isButtonDisabled() {
        //return this.isLoading || !this.newCurrency || (this.newCurrency.toUpperCase() === this.bikeCurrency.toUpperCase());
        return this.isLoading || !this.newCurrency || this.isSameCurrency;
    }

    handleCurrencyChange(event) {
        this.newCurrency = event.detail.value ? event.detail.value.toUpperCase() : '';
    }

    async handleUpdateCurrency() {
        this.isLoading = true;
        
        const baseCurrency = this.bikeCurrency;
        const targetCurrency = this.newCurrency;

        if (!baseCurrency || !targetCurrency) {
            this.showToast('Error', 'Current or new currency is missing.', 'error');
            this.isLoading = false;
            return;
        }

        try {
            // 1. Call Apex to get the exchange rate
            const exchangeRate = await getRate({ 
                baseCurrency: baseCurrency, 
                targetCurrency: targetCurrency 
            });

            if (exchangeRate) {
                // 2. Call Apex to update the Bike and all related Parts
                await updateBikeAndPartsPrices({
                    bikeId: this.recordId,
                    newCurrency: targetCurrency,
                    exchangeRate: exchangeRate
                });

                getRecordNotifyChange([{recordId: this.recordId}]);

                this.showToast(
                    'Success', 
                    `Bike and parts prices updated to ${targetCurrency} at a rate of ${exchangeRate}.`, 
                    'success'
                );

                this.dispatchEvent(new CloseActionScreenEvent());

            } else {
                 this.showToast('Error', 'Could not retrieve a valid exchange rate.', 'error');
            }

        } catch (error) {
            this.showToast('Error', 'Update failed: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}