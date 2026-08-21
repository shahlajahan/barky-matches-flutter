import 'partner_intake_context.dart';
import 'partner_intake_session_store_stub.dart'
    if (dart.library.html) 'partner_intake_session_store_web.dart'
    as store;

class PartnerIntakeSessionStore {
  const PartnerIntakeSessionStore._();

  static void save(PartnerIntakeContext context) {
    if (!context.isValid) return;
    store.savePartnerIntakeContext(context.toJson());
  }

  static PartnerIntakeContext? read() {
    return PartnerIntakeContext.tryParse(store.readPartnerIntakeContext());
  }

  static PartnerIntakeContext? take() {
    final context = read();
    if (context == null) {
      store.clearPartnerIntakeContext();
      return null;
    }
    store.clearPartnerIntakeContext();
    return context;
  }

  static void clear() {
    store.clearPartnerIntakeContext();
  }
}
