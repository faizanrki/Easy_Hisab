/// Public contracts and types exported by the Sales module.
/// Unrelated modules import ONLY this file.
library;

export 'domain/sale.dart'
    show Sale, SaleLine, SaleType, SaleStatus, SyncStatus;
export 'domain/sale_repository.dart' show SaleRepository;
export 'presentation/sale_providers.dart'
    show saleRepositoryProvider, recentSalesProvider, customerSalesProvider;
