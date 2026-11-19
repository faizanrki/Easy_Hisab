/// Public contracts and types exported by the Payments module.
/// Unrelated modules import ONLY this file.
library;

export 'domain/payment.dart'
    show
        Payment,
        PaymentAllocation,
        PaymentMethod,
        PaymentStatus,
        PaymentSyncStatus,
        LedgerEntry,
        LedgerEntryType;
export 'domain/payment_repository.dart' show PaymentRepository;
export 'presentation/payment_providers.dart'
    show
        paymentRepositoryProvider,
        customerBalanceProvider,
        customerLedgerProvider,
        recentPaymentsProvider;
