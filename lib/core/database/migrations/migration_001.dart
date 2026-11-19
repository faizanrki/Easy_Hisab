import 'package:sqflite/sqflite.dart';

/// Version 1 schema: every table from the EasyHisab specification.
///
/// Conventions:
/// * `id` columns are UUID text generated on the device.
/// * Money columns end in `_paisa` and are INTEGER (never REAL).
/// * Quantities end in `_milli` (thousandths of a unit).
/// * Timestamps end in `_at` and are INTEGER UTC milliseconds since epoch.
/// * Every tenant-owned row carries `shop_id`; composite foreign keys make it
///   impossible to attach a sale/payment to another shop's customer.
/// * Posted financial rows are never deleted; corrections use reversals.
Future<void> migration001(DatabaseExecutor db) async {
  final batch = db.batch();

  batch.execute('''
    CREATE TABLE users (
      id            TEXT PRIMARY KEY,
      firebase_uid  TEXT UNIQUE,
      display_name  TEXT NOT NULL,
      email         TEXT,
      phone         TEXT,
      created_at    INTEGER NOT NULL,
      updated_at    INTEGER NOT NULL
    )''');

  batch.execute('''
    CREATE TABLE shops (
      id                    TEXT PRIMARY KEY,
      owner_uid             TEXT,
      name                  TEXT NOT NULL CHECK (length(trim(name)) > 0),
      address               TEXT,
      contact_phone         TEXT,
      business_verification TEXT NOT NULL DEFAULT 'unverified'
                            CHECK (business_verification IN ('unverified','pending','verified')),
      created_at            INTEGER NOT NULL,
      updated_at            INTEGER NOT NULL
    )''');

  batch.execute('''
    CREATE TABLE shop_members (
      id          TEXT PRIMARY KEY,
      shop_id     TEXT NOT NULL REFERENCES shops(id),
      user_uid    TEXT NOT NULL,
      role        TEXT NOT NULL CHECK (role IN ('owner','staff')),
      created_at  INTEGER NOT NULL,
      UNIQUE (shop_id, user_uid)
    )''');

  batch.execute('''
    CREATE TABLE customers (
      id               TEXT PRIMARY KEY,
      shop_id          TEXT NOT NULL REFERENCES shops(id),
      name             TEXT NOT NULL CHECK (length(trim(name)) > 0),
      name_search      TEXT NOT NULL,
      phone            TEXT,
      email            TEXT,
      linked_auth_uid  TEXT,
      archived_at      INTEGER,
      created_at       INTEGER NOT NULL,
      updated_at       INTEGER NOT NULL,
      UNIQUE (id, shop_id)
    )''');
  batch.execute(
      'CREATE INDEX idx_customers_shop_name ON customers(shop_id, name_search)');
  batch.execute(
      'CREATE INDEX idx_customers_shop_phone ON customers(shop_id, phone)');

  batch.execute('''
    CREATE TABLE products (
      id                TEXT PRIMARY KEY,
      shop_id           TEXT NOT NULL REFERENCES shops(id),
      name              TEXT NOT NULL CHECK (length(trim(name)) > 0),
      name_search       TEXT NOT NULL,
      unit              TEXT NOT NULL,
      unit_price_paisa  INTEGER NOT NULL CHECK (unit_price_paisa >= 0),
      archived_at       INTEGER,
      created_at        INTEGER NOT NULL,
      updated_at        INTEGER NOT NULL,
      UNIQUE (id, shop_id)
    )''');
  batch.execute(
      'CREATE INDEX idx_products_shop_name ON products(shop_id, name_search)');

  batch.execute('''
    CREATE TABLE sales (
      id                TEXT PRIMARY KEY,
      shop_id           TEXT NOT NULL,
      customer_id       TEXT NOT NULL,
      receipt_no        TEXT NOT NULL,
      sale_type         TEXT NOT NULL CHECK (sale_type IN ('credit','paid')),
      total_paisa       INTEGER NOT NULL,
      status            TEXT NOT NULL DEFAULT 'posted'
                        CHECK (status IN ('posted','reversed')),
      reverses_sale_id  TEXT REFERENCES sales(id),
      note              TEXT,
      created_at        INTEGER NOT NULL,
      due_at            INTEGER,
      sync_status       TEXT NOT NULL DEFAULT 'pending'
                        CHECK (sync_status IN ('pending','accepted','rejected')),
      UNIQUE (id, shop_id),
      UNIQUE (shop_id, receipt_no),
      FOREIGN KEY (customer_id, shop_id) REFERENCES customers(id, shop_id)
    )''');
  batch.execute(
      'CREATE INDEX idx_sales_customer_date ON sales(shop_id, customer_id, created_at)');
  batch.execute('CREATE INDEX idx_sales_shop_date ON sales(shop_id, created_at)');

  batch.execute('''
    CREATE TABLE sale_items (
      id                TEXT PRIMARY KEY,
      sale_id           TEXT NOT NULL REFERENCES sales(id),
      product_id        TEXT REFERENCES products(id),
      description       TEXT NOT NULL,
      unit              TEXT NOT NULL,
      quantity_milli    INTEGER NOT NULL CHECK (quantity_milli > 0),
      unit_price_paisa  INTEGER NOT NULL CHECK (unit_price_paisa >= 0),
      line_total_paisa  INTEGER NOT NULL,
      position          INTEGER NOT NULL
    )''');
  batch.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');

  batch.execute('''
    CREATE TABLE payments (
      id                   TEXT PRIMARY KEY,
      shop_id              TEXT NOT NULL,
      customer_id          TEXT NOT NULL,
      amount_paisa         INTEGER NOT NULL CHECK (amount_paisa > 0),
      method               TEXT,
      sale_id              TEXT REFERENCES sales(id),
      status               TEXT NOT NULL DEFAULT 'posted'
                           CHECK (status IN ('posted','reversed')),
      reverses_payment_id  TEXT REFERENCES payments(id),
      note                 TEXT,
      created_at           INTEGER NOT NULL,
      sync_status          TEXT NOT NULL DEFAULT 'pending'
                           CHECK (sync_status IN ('pending','accepted','rejected')),
      FOREIGN KEY (customer_id, shop_id) REFERENCES customers(id, shop_id)
    )''');
  batch.execute(
      'CREATE INDEX idx_payments_customer_date ON payments(shop_id, customer_id, created_at)');

  batch.execute('''
    CREATE TABLE payment_allocations (
      id               TEXT PRIMARY KEY,
      payment_id       TEXT NOT NULL REFERENCES payments(id),
      sale_id          TEXT NOT NULL REFERENCES sales(id),
      allocated_paisa  INTEGER NOT NULL CHECK (allocated_paisa > 0)
    )''');

  batch.execute('''
    CREATE TABLE customer_links (
      id           TEXT PRIMARY KEY,
      shop_id      TEXT NOT NULL,
      customer_id  TEXT NOT NULL,
      auth_uid     TEXT NOT NULL,
      status       TEXT NOT NULL
                   CHECK (status IN ('requested','approved','rejected','revoked')),
      requested_at INTEGER NOT NULL,
      approved_at  INTEGER,
      revoked_at   INTEGER,
      FOREIGN KEY (customer_id, shop_id) REFERENCES customers(id, shop_id)
    )''');

  batch.execute('''
    CREATE TABLE reminders (
      id           TEXT PRIMARY KEY,
      shop_id      TEXT NOT NULL,
      customer_id  TEXT NOT NULL,
      due_at       INTEGER NOT NULL,
      status       TEXT NOT NULL DEFAULT 'open'
                   CHECK (status IN ('open','shared','done','cancelled')),
      created_at   INTEGER NOT NULL,
      FOREIGN KEY (customer_id, shop_id) REFERENCES customers(id, shop_id)
    )''');

  batch.execute('''
    CREATE TABLE sync_queue (
      operation_id  TEXT PRIMARY KEY,
      shop_id       TEXT NOT NULL REFERENCES shops(id),
      entity_type   TEXT NOT NULL,
      entity_id     TEXT NOT NULL,
      operation     TEXT NOT NULL,
      payload       TEXT NOT NULL,
      attempts      INTEGER NOT NULL DEFAULT 0,
      sync_status   TEXT NOT NULL DEFAULT 'pending'
                    CHECK (sync_status IN ('pending','in_flight','accepted','retryable_failed','rejected')),
      last_error    TEXT,
      created_at    INTEGER NOT NULL,
      updated_at    INTEGER NOT NULL
    )''');
  batch.execute(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(sync_status, created_at)');

  batch.execute('''
    CREATE TABLE backup_history (
      id              TEXT PRIMARY KEY,
      drive_file_id   TEXT,
      schema_version  INTEGER NOT NULL,
      sha256          TEXT,
      result          TEXT NOT NULL CHECK (result IN ('success','failed')),
      error           TEXT,
      created_at      INTEGER NOT NULL
    )''');

  batch.execute('''
    CREATE TABLE audit_log (
      id           TEXT PRIMARY KEY,
      shop_id      TEXT,
      actor_uid    TEXT,
      action       TEXT NOT NULL,
      record_type  TEXT NOT NULL,
      record_id    TEXT NOT NULL,
      details      TEXT,
      created_at   INTEGER NOT NULL
    )''');

  // Financial history and the audit trail are append-only.
  for (final table in ['sales', 'sale_items', 'payments', 'audit_log']) {
    batch.execute('''
      CREATE TRIGGER trg_${table}_no_delete BEFORE DELETE ON $table
      BEGIN SELECT RAISE(ABORT, '$table rows are append-only'); END''');
  }
  // Amounts on posted money records can never be silently edited.
  batch.execute('''
    CREATE TRIGGER trg_sales_amount_immutable BEFORE UPDATE OF total_paisa, customer_id, shop_id ON sales
    BEGIN SELECT RAISE(ABORT, 'posted sale amounts are immutable; use a reversal'); END''');
  batch.execute('''
    CREATE TRIGGER trg_sale_items_immutable BEFORE UPDATE ON sale_items
    BEGIN SELECT RAISE(ABORT, 'sale items are immutable'); END''');
  batch.execute('''
    CREATE TRIGGER trg_payments_amount_immutable BEFORE UPDATE OF amount_paisa, customer_id, shop_id ON payments
    BEGIN SELECT RAISE(ABORT, 'posted payment amounts are immutable; use a reversal'); END''');

  await batch.commit(noResult: true);
}
