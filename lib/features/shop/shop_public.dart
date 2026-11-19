/// Public contract and access points exported by the Shop feature.
/// Unrelated modules import ONLY this file, never internal mappers or screens.
library;

export '../../core/contracts/active_shop_context.dart';
export 'domain/shop.dart' show Shop, ShopDetails, BusinessVerification;
export 'presentation/shop_providers.dart'
    show activeShopProvider, activeShopContextProvider;
