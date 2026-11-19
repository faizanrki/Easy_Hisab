import 'package:uuid/uuid.dart';

/// Generates globally unique record IDs (UUID v4) so records created offline
/// on different devices never collide when they are synced later.
abstract interface class IdGenerator {
  String newId();
}

final class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();
  static const Uuid _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}
