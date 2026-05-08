# Google Play Console Subscription Setup Guide

To resolve the **"Product not found"** error, you must create the subscription product in your Google Play Console.

### Step 1: Navigate to Subscriptions
1. Log in to your [Google Play Console](https://play.google.com/console/).
2. Select your app: **TradeGuard Pro**.
3. In the left-hand menu, scroll down to the **Monetize** section.
4. Expand **Products** and select **Subscriptions**.

### Step 2: Create a New Subscription
1. Click the **Create subscription** button.
2. **Product ID**: Enter `tradeguard_pro_monthly` (This MUST match exactly what is in the code).
3. **Name**: Enter `TradeGuard Pro Monthly`.
4. Click **Create**.

### Step 3: Add a Base Plan
1. Inside the new subscription, scroll down to the **Base plans** section.
2. Click **Add base plan**.
3. **Base plan ID**: Enter `monthly-plan`.
4. **Type**: Select **Auto-renewing**.
5. **Billing period**: Select **Monthly**.
6. **Price and availability**:
   - Click **Set prices**.
   - Select your target regions (e.g., USA).
   - Enter your price: **$4.99**.
7. Click **Save** and then **Activate**.

### Step 4: Finalize & Activate
1. Ensure the Subscription status is **Active**.
2. Wait about **30-60 minutes** for Google's servers to propogate the new product.
3. Restart your app and try the "RENEW PRO" button again.

> [!NOTE]
> If you are testing on a real device, make sure you are logged into the Play Store with a **Tester Account** that is added to your internal testing track.
