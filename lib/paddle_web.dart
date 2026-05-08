import 'package:flutter/foundation.dart';
import 'dart:js' as js;

void openPaddleCheckout(String priceId) {
  if (kIsWeb) {
    js.context.callMethod('openPaddleCheckout', [priceId]);
  }
}
