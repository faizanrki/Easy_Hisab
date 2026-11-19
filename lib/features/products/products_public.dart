/// Public contracts and types exported by the Products catalog module.
/// Unrelated modules (Sales, Receipts) import ONLY this file.
library;

export '../../core/contracts/product_lookup_port.dart';
export 'domain/product.dart'
    show Product, ProductDetails, StandardGroceryUnits;
export 'presentation/product_providers.dart'
    show productLookupPortProvider, productListProvider;
