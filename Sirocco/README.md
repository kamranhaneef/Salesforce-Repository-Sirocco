
-----

## 1\. GitHub `README.md` (Deployment & Structure) 🛠️

This file tells the reviewer how to clone the project, deploy it, and find the relevant code files.

````markdown
# Salesforce Developer Test: Bike Currency Converter 🚴‍♂️

This repository contains the solution for the Sirocco Salesforce Developer Test. The solution implements a currency conversion feature for a custom `Bike` object and its related `Part` records, utilizing an external exchange rate API callout.

## Solution Overview

The core requirement is met using the following components:

| Component | Type | Purpose |
| :--- | :--- | :--- |
| `Bike__c` & `Part__c` | Custom Objects | Stores product and replacement part data with price and currency. |
| `ExchangeRateService` | Apex Class | Handles the secure callout to the external Exchange Rate API and calculates the cross-rate needed for conversion. |
| `bikeCurrencyChanger` | LWC (Quick Action) | Provides the UI on the Bike Record Page to select a new target currency and trigger the price update. |

## Deployment Instructions

These steps assume you have the Salesforce CLI installed and a target scratch org or Developer Edition Org ready.

### Step 1: Clone the Repository

Clone the project to your local machine:

```bash
git clone [Your Repository URL]
cd [Repository-Name]
````

### Step 2: Authorize Your Salesforce Org

Log into the target Salesforce environment (e.g., your Trial or Scratch Org):

```bash
sf org login web -a TestOrg
```

### Step 3: Deploy Metadata

Deploy all project components (Objects, Fields, Apex, LWC) to the authorized org:

```bash
sf project deploy start -d force-app
```

### Step 4: Configure Remote Site Setting (Mandatory)

The Apex callout requires the external domain to be whitelisted for security.

1.  In Salesforce Setup, navigate to **Security** $\rightarrow$ **Remote Site Settings**.
2.  Click **New Remote Site**.
3.  Set **Remote Site Name:** `ExchangeRatesAPI`
4.  Set **Remote Site URL:** `https://api.exchangeratesapi.io`
5.  Click **Save**.

-----

## 2\. Test Execution `README.md` (Manual Steps) ⚙️

This file is designed for the non-technical reviewer, guiding them through the test scenario for verification.

```markdown
# Test Execution Guide: Bike Currency Conversion 💸

Thank you for reviewing my submission for the Salesforce Developer Test. This guide provides the step-by-step process to verify the implemented currency conversion functionality.

## Core Functionality

The solution adds a **"Change Currency"** button (Lightning Action) to the Bike record. This button opens an LWC that:
1.  Takes a new target currency (e.g., SEK).
2.  Calls an external API to get the necessary exchange rate.
3.  Updates the **Price** and **Currency** fields on the parent Bike record.
4.  Updates the **Price** field on all related **Part** records using the same exchange rate.

## Test Scenario Steps

Please ensure the metadata has been deployed and the Remote Site Setting is configured before starting this scenario.

### Step 1: Create a Base Record

1.  Use the **App Launcher** (9 dots) and navigate to the **Bikes** tab (or search for 'Bike').
2.  Click **New**.
3.  Set the initial values:
    * **Name:** `Mountain Pro X`
    * **Price:** `1000.00`
    * **Currency:** `USD` (or your chosen base currency)
4.  Click **Save**.

### Step 2: Create Related Parts

1.  On the newly created Bike record, scroll down to the **Parts** related list.
2.  Click **New** to create two part records:
    * **Part 1 Name:** `High-End Tires`, **Price:** `250.00`
    * **Part 2 Name:** `Handlebar Grip`, **Price:** `50.00`
3.  Confirm you have one Bike record (USD 1000.00) and two related Part records (USD 250.00 and USD 50.00).

### Step 3: Execute the Currency Change

1.  On the Bike record, click the **`Change Currency`** button (located in the top-right actions menu).
2.  The Lightning Web Component modal will appear.
3.  In the input field, enter a new currency code, e.g., **`SEK`**.
4.  Click the **`Update currency`** button.

### Step 4: Verification

1.  Upon success, a toast message will appear, and the modal will close.
2.  **Verify the Bike Record:**
    * The **Currency** field should now be **`SEK`**.
    * The **Price** field should show the new, calculated SEK value (e.g., if the USD to SEK rate is 11.06, the new price should be ~**`11,060.00`**).
3.  **Verify the Part Records:**
    * Refresh the page or inspect the related list.
    * The **High-End Tires** price should be updated to $\approx$**`2765.00`** (250 \* 11.06).
    * The **Handlebar Grip** price should be updated to $\approx$**`553.00`** (50 \* 11.06).

This confirms the API callout was successful and the prices were correctly converted and updated across the related records via the Apex logic.
```