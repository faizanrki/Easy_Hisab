import '../../../core/database/db_transaction.dart';
import '../../../core/domain/entity_id.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/phone_number.dart';
import '../domain/customer_portal_repository.dart';
import '../domain/linked_shop.dart';

final class SqliteCustomerPortalRepository implements CustomerPortalRepository {
  const SqliteCustomerPortalRepository(
    this._db, [
    this._idGen = const UuidIdGenerator(),
  ]);

  final DatabaseTransactionPort _db;
  final IdGenerator _idGen;

  @override
  Future<List<LinkedShopSummary>> getLinkedShops({
    required String customerUid,
    String? phone,
  }) async {
    // If phone is provided, ensure any matching customers are auto-linked
    if (phone != null && phone.trim().isNotEmpty) {
      await linkByPhoneNumber(customerUid: customerUid, phone: phone);
    }

    // Query active/approved links joined with shop and customer info
    final rows = await _db.executor.rawQuery(
      '''
      SELECT 
        l.shop_id,
        l.customer_id,
        l.requested_at,
        l.approved_at,
        s.name AS shop_name,
        s.contact_phone AS shop_phone,
        s.address AS shop_address,
        c.name AS customer_name
      FROM customer_links l
      JOIN shops s ON s.id = l.shop_id
      JOIN customers c ON c.id = l.customer_id AND c.shop_id = l.shop_id
      WHERE l.auth_uid = ? AND l.status IN ('approved', 'requested')
      ORDER BY s.name ASC
      ''',
      [customerUid],
    );

    final result = <LinkedShopSummary>[];

    for (final row in rows) {
      final shopId = row['shop_id'] as String;
      final customerId = row['customer_id'] as String;

      // Calculate balance: posted credit sales total - posted payments total
      final salesResult = await _db.executor.rawQuery(
        '''
        SELECT COALESCE(SUM(total_paisa), 0) AS total
        FROM sales
        WHERE shop_id = ? AND customer_id = ? AND status = 'posted' AND sale_type = 'credit'
        ''',
        [shopId, customerId],
      );
      final salesPaisa = (salesResult.first['total'] as num?)?.toInt() ?? 0;

      final paymentsResult = await _db.executor.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_paisa), 0) AS total
        FROM payments
        WHERE shop_id = ? AND customer_id = ? AND status = 'posted'
        ''',
        [shopId, customerId],
      );
      final paymentsPaisa = (paymentsResult.first['total'] as num?)?.toInt() ?? 0;

      final balancePaisa = salesPaisa - paymentsPaisa;

      final approvedAtMs = row['approved_at'] as int?;
      final requestedAtMs = row['requested_at'] as int? ?? DateTime.now().millisecondsSinceEpoch;
      final linkedAt = DateTime.fromMillisecondsSinceEpoch(
        approvedAtMs ?? requestedAtMs,
        isUtc: true,
      );

      result.add(
        LinkedShopSummary(
          shopId: shopId,
          shopName: row['shop_name'] as String? ?? 'Shop',
          shopPhone: row['shop_phone'] as String?,
          shopAddress: row['shop_address'] as String?,
          customerId: customerId,
          customerName: row['customer_name'] as String? ?? 'Customer',
          balance: Money.paisa(balancePaisa),
          linkedAt: linkedAt,
        ),
      );
    }

    return result;
  }

  @override
  Future<List<CustomerLedgerItem>> getShopLedger({
    required String shopId,
    required String customerId,
  }) async {
    final items = <CustomerLedgerItem>[];

    // Fetch posted sales
    final sales = await _db.executor.rawQuery(
      '''
      SELECT id, shop_id, receipt_no, total_paisa, created_at
      FROM sales
      WHERE shop_id = ? AND customer_id = ? AND status = 'posted' AND sale_type = 'credit'
      ORDER BY created_at DESC
      ''',
      [shopId, customerId],
    );

    for (final row in sales) {
      final receipt = row['receipt_no'] as String?;
      final createdAtMs = row['created_at'] as int;
      items.add(
        CustomerLedgerItem(
          id: row['id'] as String,
          shopId: shopId,
          date: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
          type: 'sale',
          amount: Money.paisa(row['total_paisa'] as int),
          description: receipt != null ? 'Bill #$receipt' : 'Credit Purchase',
          receiptNumber: receipt,
          saleId: row['id'] as String,
        ),
      );
    }

    // Fetch posted payments
    final payments = await _db.executor.rawQuery(
      '''
      SELECT id, shop_id, amount_paisa, created_at, method, note
      FROM payments
      WHERE shop_id = ? AND customer_id = ? AND status = 'posted'
      ORDER BY created_at DESC
      ''',
      [shopId, customerId],
    );

    for (final row in payments) {
      final note = row['note'] as String?;
      final method = row['method'] as String? ?? 'cash';
      final createdAtMs = row['created_at'] as int;
      items.add(
        CustomerLedgerItem(
          id: row['id'] as String,
          shopId: shopId,
          date: DateTime.fromMillisecondsSinceEpoch(createdAtMs, isUtc: true),
          type: 'payment',
          amount: Money.paisa(row['amount_paisa'] as int),
          description: note != null && note.isNotEmpty
              ? note
              : 'Payment (${method.toUpperCase()})',
        ),
      );
    }

    // Sort descending by date
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Future<int> linkByPhoneNumber({
    required String customerUid,
    required String phone,
  }) async {
    final cleanDigits = PhoneNumber.normalize(phone) ?? phone.replaceAll(RegExp(r'\D'), '');
    if (cleanDigits.isEmpty) return 0;

    // Search customers by matching phone digits
    final matches = await _db.executor.rawQuery(
      '''
      SELECT id, shop_id, phone
      FROM customers
      WHERE phone IS NOT NULL AND archived_at IS NULL
      ''',
    );

    int newlyLinked = 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final m in matches) {
      final custPhone = m['phone'] as String?;
      if (custPhone == null) continue;
      final normalizedCustPhone =
          PhoneNumber.normalize(custPhone) ?? custPhone.replaceAll(RegExp(r'\D'), '');

      // Check for exact normalized or suffix match (e.g. 3001234567)
      final phoneSuffix = cleanDigits.length > 9 ? cleanDigits.substring(cleanDigits.length - 9) : cleanDigits;
      if (normalizedCustPhone.contains(phoneSuffix)) {
        final shopId = m['shop_id'] as String;
        final customerId = m['id'] as String;

        // Check if link already exists
        final existing = await _db.executor.rawQuery(
          '''
          SELECT id FROM customer_links
          WHERE shop_id = ? AND customer_id = ? AND auth_uid = ?
          ''',
          [shopId, customerId, customerUid],
        );

        if (existing.isEmpty) {
          final linkId = _idGen.newId();
          await _db.executor.insert('customer_links', {
            'id': linkId,
            'shop_id': shopId,
            'customer_id': customerId,
            'auth_uid': customerUid,
            'status': 'approved',
            'requested_at': nowMs,
            'approved_at': nowMs,
          });
          newlyLinked++;
        }
      }
    }

    return newlyLinked;
  }

  @override
  Future<void> linkAccount({
    required String customerUid,
    required String shopId,
    required String customerId,
  }) async {
    final existing = await _db.executor.rawQuery(
      '''
      SELECT id FROM customer_links
      WHERE shop_id = ? AND customer_id = ? AND auth_uid = ?
      ''',
      [shopId, customerId, customerUid],
    );

    if (existing.isEmpty) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      await _db.executor.insert('customer_links', {
        'id': _idGen.newId(),
        'shop_id': shopId,
        'customer_id': customerId,
        'auth_uid': customerUid,
        'status': 'approved',
        'requested_at': nowMs,
        'approved_at': nowMs,
      });
    }
  }
}
