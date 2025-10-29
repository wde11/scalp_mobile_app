import 'package:flutter/foundation.dart';
import '../models/transaction.dart';

class TransactionService extends ChangeNotifier {
  Transaction? _activeTransaction;

  Transaction? get activeTransaction => _activeTransaction;

  bool get hasActiveTransaction => _activeTransaction != null && _activeTransaction!.isActive;

  void setActiveTransaction(Transaction? transaction) {
    _activeTransaction = transaction;
    notifyListeners();
  }

  void clearActiveTransaction() {
    _activeTransaction = null;
    notifyListeners();
  }

  void updateSellerLocation(double latitude, double longitude, String address) {
    if (_activeTransaction != null) {
      // This would typically update the transaction in your database
      notifyListeners();
    }
  }
}
