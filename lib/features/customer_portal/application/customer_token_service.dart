import 'dart:math';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_transaction.dart';

/// Service managing rotating receipt access tokens and Shop ID resolution.
///
/// Features:
/// 1. Each shop has a human-friendly unique Shop Code (e.g. SHOP-4F29A1).
/// 2. Each customer has an active 6-digit access token (e.g. 849201).
/// 3. Posting a new sale rotates the customer token, immediately expiring the previous one.
/// 4. Customers can view their ledger without any mobile phone number by providing Shop ID + Token.
class CustomerTokenService {
  const CustomerTokenService(this._db);

  final DatabaseTransactionPort _db;

  static String formatShopCode(String shopId) {
    final clean = shopId.replaceAll('-', '').toUpperCase();
    final suffix = clean.length >= 6 ? clean.substring(0, 6) : clean.padRight(6, '0');
    return 'SHOP-$suffix';
  }

  /// Generates a rotating 6-digit access token for a customer in a shop.
  /// Automatically invalidates any previously issued token for this customer.
  Future<String> rotateToken({
    required String shopId,
    required String customerId,
  }) async {
    final rng = Random();
    final newToken = (100000 + rng.nextInt(900000)).toString();

    // 1. Look up any existing active token for this customer
    final existing = await _db.executor.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['active_token:$shopId:$customerId'],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final oldToken = existing.first['value'] as String?;
      if (oldToken != null && oldToken.isNotEmpty) {
        // Remove old reverse lookup so it expires immediately
        await _db.executor.delete(
          'app_settings',
          where: 'key = ?',
          whereArgs: ['cust_token:$shopId:$oldToken'],
        );
      }
    }

    // 2. Save new token mappings
    await _db.executor.insert(
      'app_settings',
      {
        'key': 'active_token:$shopId:$customerId',
        'value': newToken,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _db.executor.insert(
      'app_settings',
      {
        'key': 'cust_token:$shopId:$newToken',
        'value': customerId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return newToken;
  }

  /// Retrieves the current active token for a customer, or generates one if not yet created.
  Future<String> getOrGenerateToken({
    required String shopId,
    required String customerId,
  }) async {
    final rows = await _db.executor.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['active_token:$shopId:$customerId'],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final token = rows.first['value'] as String?;
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }

    return rotateToken(shopId: shopId, customerId: customerId);
  }

  /// Resolves a shop and customer using [shopCodeOrId] and [token].
  /// Returns null if the shop is not found or the token is invalid/expired.
  Future<ResolvedCustomerToken?> resolve({
    required String shopCodeOrId,
    required String token,
  }) async {
    final cleanInput = shopCodeOrId
        .trim()
        .toUpperCase()
        .replaceAll('SHOP-', '')
        .replaceAll('-', '')
        .replaceAll('_', '');

    if (cleanInput.isEmpty) return null;

    final cleanToken = token.trim().replaceAll('TKN-', '').replaceAll('#', '');
    if (cleanToken.isEmpty) return null;

    // 1. Find shop by exact ID or 6-character code prefix
    final allShops = await _db.executor.query('shops');
    Map<String, Object?>? matchedShopRow;

    for (final row in allShops) {
      final id = (row['id'] as String)
          .replaceAll('-', '')
          .replaceAll('_', '')
          .toUpperCase();
      if (id == cleanInput || id.startsWith(cleanInput)) {
        matchedShopRow = row;
        break;
      }
    }

    if (matchedShopRow == null) return null;

    final realShopId = matchedShopRow['id'] as String;
    final shopName = matchedShopRow['name'] as String;
    final shopPhone = matchedShopRow['contact_phone'] as String?;

    // 2. Check token in app_settings
    final tokenRows = await _db.executor.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['cust_token:$realShopId:$cleanToken'],
      limit: 1,
    );

    if (tokenRows.isEmpty) return null;

    final customerId = tokenRows.first['value'] as String?;
    if (customerId == null || customerId.isEmpty) return null;

    // 3. Verify customer exists in shop
    final customerRows = await _db.executor.query(
      'customers',
      where: 'id = ? AND shop_id = ?',
      whereArgs: [customerId, realShopId],
      limit: 1,
    );

    if (customerRows.isEmpty) return null;

    final customerName = customerRows.first['name'] as String;

    // 4. Compute outstanding balance directly (credit sales - payments)
    final salesResult = await _db.executor.rawQuery(
      '''
      SELECT COALESCE(SUM(total_paisa), 0) AS total, MAX(created_at) AS last_at
      FROM sales
      WHERE shop_id = ? AND customer_id = ? AND status = 'posted' AND sale_type = 'credit'
      ''',
      [realShopId, customerId],
    );
    final paymentsResult = await _db.executor.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_paisa), 0) AS total
      FROM payments
      WHERE shop_id = ? AND customer_id = ? AND status = 'posted'
      ''',
      [realShopId, customerId],
    );
    final salesPaisa = (salesResult.first['total'] as num?)?.toInt() ?? 0;
    final paymentsPaisa = (paymentsResult.first['total'] as num?)?.toInt() ?? 0;
    final lastAtMs = (salesResult.first['last_at'] as num?)?.toInt();

    return ResolvedCustomerToken(
      balancePaisa: salesPaisa - paymentsPaisa,
      lastBillAt: lastAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastAtMs, isUtc: true)
          : null,
      shopId: realShopId,
      shopCode: formatShopCode(realShopId),
      shopName: shopName,
      shopPhone: shopPhone,
      customerId: customerId,
      customerName: customerName,
      token: cleanToken,
    );
  }
}

class ResolvedCustomerToken {
  const ResolvedCustomerToken({
    required this.shopId,
    required this.shopCode,
    required this.shopName,
    required this.customerId,
    required this.customerName,
    required this.token,
    this.shopPhone,
    this.balancePaisa = 0,
    this.lastBillAt,
  });

  /// Outstanding udhar in paisa (positive = customer owes, negative = advance).
  final int balancePaisa;
  final DateTime? lastBillAt;

  final String shopId;
  final String shopCode;
  final String shopName;
  final String? shopPhone;
  final String customerId;
  final String customerName;
  final String token;
}
