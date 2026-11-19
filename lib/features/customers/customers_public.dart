/// Public contracts and types exported by the Customers module.
/// Unrelated modules (Sales, Payments, etc.) import ONLY this file.
library;

export '../../core/contracts/customer_lookup_port.dart';
export 'domain/customer.dart' show Customer, CustomerDetails;
export 'presentation/customer_providers.dart'
    show customerLookupPortProvider, customerListProvider;
