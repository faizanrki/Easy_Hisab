import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../../core/contracts/active_shop_context.dart';
import '../../../core/contracts/auth_context_port.dart';
import '../application/create_shop.dart';
import '../application/get_active_shop.dart';
import '../application/update_shop.dart';
import '../data/sqlite_shop_repository.dart';
import '../domain/shop.dart';
import '../domain/shop_repository.dart';

/// Provides the auth context. Defaults to local-only until module 08.
final authContextProvider = Provider<AuthContextPort>(
  (ref) => const LocalOnlyAuthContext(),
);

/// Concrete ShopRepository backed by SQLite.
final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteShopRepository(db, ids);
});

final createShopUseCaseProvider = Provider<CreateShop>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  final ids = ref.watch(idGeneratorProvider);
  final clock = ref.watch(clockProvider);
  final auth = ref.watch(authContextProvider);
  return CreateShop(repo, ids, clock, auth);
});

final updateShopUseCaseProvider = Provider<UpdateShop>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final auth = ref.watch(authContextProvider);
  return UpdateShop(repo, clock, auth);
});

final getActiveShopUseCaseProvider = Provider<GetActiveShop>((ref) {
  final repo = ref.watch(shopRepositoryProvider);
  return GetActiveShop(repo);
});

/// Async notifier for the currently active shop.
final activeShopProvider =
    AsyncNotifierProvider<ActiveShopNotifier, Shop?>(ActiveShopNotifier.new);

class ActiveShopNotifier extends AsyncNotifier<Shop?> {
  @override
  Future<Shop?> build() async {
    final useCase = ref.watch(getActiveShopUseCaseProvider);
    return useCase.execute();
  }

  Future<Shop> createShop(ShopDetails details) async {
    state = const AsyncValue.loading();
    final create = ref.read(createShopUseCaseProvider);
    try {
      final shop = await create.execute(details);
      state = AsyncValue.data(shop);
      return shop;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<Shop> updateShop(String shopId, ShopDetails details) async {
    state = const AsyncValue.loading();
    final update = ref.read(updateShopUseCaseProvider);
    try {
      final shop = await update.execute(shopId, details);
      state = AsyncValue.data(shop);
      return shop;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(getActiveShopUseCaseProvider).execute(),
    );
  }
}

/// Lightweight contract for other modules (Sales, Customers, etc.)
final activeShopContextProvider = Provider<ActiveShopContext?>((ref) {
  final activeShop = ref.watch(activeShopProvider).value;
  if (activeShop == null) return null;
  return ActiveShopContext(
    shopId: activeShop.id,
    shopName: activeShop.name,
  );
});
