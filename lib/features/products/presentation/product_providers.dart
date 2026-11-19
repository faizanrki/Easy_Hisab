import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../../core/contracts/product_lookup_port.dart';
import '../../shop/shop_public.dart';
import '../application/archive_product.dart';
import '../application/create_product.dart';
import '../application/get_products.dart';
import '../application/update_product.dart';
import '../data/sqlite_product_repository.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteProductRepository(db, ids);
});

final productLookupPortProvider = Provider<ProductLookupPort>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteProductRepository(db, ids);
});

final createProductUseCaseProvider = Provider<CreateProduct>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final ids = ref.watch(idGeneratorProvider);
  final clock = ref.watch(clockProvider);
  return CreateProduct(repo, ids, clock);
});

final updateProductUseCaseProvider = Provider<UpdateProduct>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return UpdateProduct(repo, clock);
});

final archiveProductUseCaseProvider = Provider<ArchiveProduct>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return ArchiveProduct(repo, clock);
});

final getProductsUseCaseProvider = Provider<GetProducts>((ref) {
  final repo = ref.watch(productRepositoryProvider);
  return GetProducts(repo);
});

class ProductFilter {
  const ProductFilter({this.query = '', this.includeArchived = false});
  final String query;
  final bool includeArchived;

  ProductFilter copyWith({String? query, bool? includeArchived}) =>
      ProductFilter(
        query: query ?? this.query,
        includeArchived: includeArchived ?? this.includeArchived,
      );

  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.query == query &&
      other.includeArchived == includeArchived;

  @override
  int get hashCode => Object.hash(query, includeArchived);
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilter>(
  ProductFilterNotifier.new,
);

class ProductFilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void updateFilter({String? query, bool? includeArchived}) {
    state = state.copyWith(query: query, includeArchived: includeArchived);
  }
}

final productListProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return [];

  final filter = ref.watch(productFilterProvider);
  final getProducts = ref.watch(getProductsUseCaseProvider);

  return getProducts.execute(
    shopId: shopContext.shopId,
    searchQuery: filter.query,
    includeArchived: filter.includeArchived,
  );
});

final productDetailProvider =
    FutureProvider.autoDispose.family<Product?, String>((ref, productId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return null;

  final getProducts = ref.watch(getProductsUseCaseProvider);
  return getProducts.getById(
    shopId: shopContext.shopId,
    productId: productId,
  );
});
