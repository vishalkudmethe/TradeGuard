# Google Play Store Billing Setup Guide

To enable **TradeGuard Pro** monthly subscriptions on Android, you must configure the product in your Google Play Console.

## 1. Create the Subscription Product

1. Log in to the [Google Play Console](https://play.google.com/apps/publish).
2. Select your app: **TradeGuard Pro**.
3. In the left menu, navigate to **Monetize** -> **Products** -> **Subscriptions**.
4. Click **Create subscription**.
5. **Product ID**: MUST be `tradeguard_pro_monthly`. (The app code looks for this exact ID).
6. **Name**: `TradeGuard Pro Monthly`.
7. **Description**: `Unlock instant cloud sync, multi-device support, and multi-account tracking.`

## 2. Configure Benefits & Pricing

1. Under **Benefits**, add:
   - "Auto-Sync trades across all devices"
   - "Workstation & Mobile continuity"
   - "Multi-Account Sync"
2. Under **Base plans**, click **Add base plan**.
3. **Base plan ID**: `monthly-plan`.
4. **Type**: `Auto-renewing`.
5. **Price**: Set to `$4.99` (or your local equivalent).
6. Click **Activate base plan**.

## 3. Activate the Subscription

1. Click **Save** at the bottom of the page.
2. Click **Activate** to make the subscription available in the store.

## 4. Troubleshooting

- **Product not found**: Ensure the Product ID matches `tradeguard_pro_monthly` exactly.
- **Store not available**: Make sure you have signed the Google Play Developer Distribution Agreement and your merchant account is active.
- **Testing**: Use a "License Testing" account in the Play Console to test the purchase flow without spending real money.

---
*Note: The app is already configured with the `in_app_purchase` package to handle these transactions automatically once the product is active.*
