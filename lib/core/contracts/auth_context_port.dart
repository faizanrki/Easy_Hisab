/// Identity of the signed-in user, as seen by business modules.
///
/// Until Firebase Auth is added (module 08) the app runs as an anonymous
/// local owner and [currentUid] is null. Business modules depend on this port,
/// never on FirebaseAuth directly.
abstract interface class AuthContextPort {
  String? get currentUid;
}

final class LocalOnlyAuthContext implements AuthContextPort {
  const LocalOnlyAuthContext();

  @override
  String? get currentUid => null;
}
