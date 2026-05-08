import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service'), backgroundColor: Colors.black, elevation: 0),
      backgroundColor: const Color(0xFF111111),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Terms of Service', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last Updated: March 2026', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            _section('1. Acceptance of Terms', 'By accessing and using TradeGuard Pro, you agree to be bound by these Terms of Service. If you do not agree, please do not use the application.'),
            _section('2. Description of Service', 'TradeGuard Pro provides a locally-stored tracking tool for the US Pattern Day Trader (PDT) 5-day rolling window constraints. TradeGuard Pro offers optional cloud-synchronization functionality.'),
            _section('3. Subscription and Billing', 'TradeGuard Pro is billed on a recurring monthly basis via our designated Merchant of Record (Paddle or Stripe). You may cancel your subscription at any time. Refunds are processed according to our payment processor\'s standard refund policy within 14 days of the initial charge upon reasonable request.'),
            _section('4. Disclaimer of Financial Advice', 'TradeGuard Pro is purely an educational tracking utility. We do not provide financial advice, broker recommendations, or guarantee protection from broker account restrictions. The accuracy of the strike count depends entirely on user input.'),
            _section('5. Data Storage', 'Free users store data exclusively on their local devices. We do not have access to your local data. Pro users authorize Firebase Cloud storage for their metadata to facilitate cross-device syncing.'),
            _section('6. Contact Information', 'If you have any questions about these Terms, contact us at: support@one-terminal.com.'),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF00), foregroundColor: Colors.black),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text('Return to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF00FF00), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), backgroundColor: Colors.black, elevation: 0),
      backgroundColor: const Color(0xFF111111),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Privacy Policy', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last Updated: March 2026', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            _section('1. Information We Collect', 'A. Local Data: If you use the free version, all trade logs and settings are stored natively on your device via SharedPreferences. We cannot read or transmit this data.\n\nB. Pro Data: If you subscribe to TradeGuard Pro, we collect your Google Account email address (via Firebase Auth) and securely store your trade history in Google Firestore strictly for device synchronization.'),
            _section('2. How We Use Your Data', 'Your email is used exclusively as an identity key to link your devices together. Your encrypted trade logs are used strictly to restore your active tracking constraints.'),
            _section('3. Third-Party Services', 'We use Firebase (Google) for database infrastructure and authentication. All payments are securely processed by an external Merchant of Record (such as Paddle or Stripe). TradeGuard Pro never accesses or stores your raw credit card numbers.'),
            _section('4. Data Deletion', 'You have the right to request full deletion of your cloud data at any time. A manual "Wipe Data" button is located in the app drawer to permanently purge your local cache and sever your identity from the database.'),
            _section('5. Contact Us', 'For data privacy requests, contact: support@one-terminal.com.'),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF00), foregroundColor: Colors.black),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text('Return to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF00FF00), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

class PricingScreen extends StatelessWidget {
  const PricingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pricing'), backgroundColor: Colors.black, elevation: 0),
      backgroundColor: const Color(0xFF111111),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pricing Plans', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last Updated: March 2026', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            _buildPriceCard(),
            const SizedBox(height: 24),
            const Text('Billing Policy', style: TextStyle(color: Color(0xFF00FF00), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'TradeGuard Pro is billed monthly. By subscribing, you agree to our 14-day refund policy per our Merchant of Record terms. Digital items are delivered immediately upon successful payment.',
              style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF00), foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TradeGuard Pro', style: TextStyle(color: Color(0xFF00FF00), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('\$4.99 / Month', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          _featureRow('Cloud Synchronization'),
          _featureRow('Multi-Device Support'),
          _featureRow('Encrypted Database Backups'),
          const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'REFUND POLICY: 14-day money-back guarantee for first-time subscribers.',
                style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _featureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          const Icon(Icons.check, color: Color(0xFF00FF00), size: 18),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

class RefundScreen extends StatelessWidget {
  const RefundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refund Policy'), backgroundColor: Colors.black, elevation: 0),
      backgroundColor: const Color(0xFF111111),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Refund Policy', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Last Updated: April 2026', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('14-Day Refund Guarantee', style: TextStyle(color: Color(0xFF00FF00), fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text(
                    'We value our customers and want you to be satisfied with your purchase. As we use Paddle as our Merchant of Record, we adhere to high standards of consumer protection.',
                    style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                      children: [
                        TextSpan(text: 'We offer a ', style: TextStyle(color: Colors.white70)),
                        TextSpan(text: 'full refund within 14 days of purchase', style: TextStyle(color: Color(0xFF00FF00), fontWeight: FontWeight.bold)),
                        TextSpan(text: ' if the service has not been utilized (e.g., no cloud syncs performed), as per ', style: TextStyle(color: Colors.white70)),
                        TextSpan(text: 'Paddle’s Buyer Terms.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'If you have utilized the Pro features but experienced technical difficulties that we were unable to resolve, you may still be eligible for a refund upon review of your request.',
                    style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            _policySection('How to Request a Refund', 'To request a refund, please contact our support team with your order details at: support@one-terminal.com.\n\nAlternatively, you can contact Paddle Support directly via their website to manage your subscription and billing requests.'),
            _policySection('Subscription Cancellation', 'You may cancel your subscription at any time. Cancellation prevents future billing cycles. Your Pro access will remain active until the end of the current billing period.'),
            
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF00), 
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _policySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}
