import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

/// Major Turkish banks offered in the Bank Name dropdown. Order here is not
/// significant — the dropdown displays them alphabetically sorted.
const List<String> kTurkishBanks = [
  'Ziraat Bankası',
  'Türkiye İş Bankası',
  'Garanti BBVA',
  'Akbank',
  'Yapı Kredi',
  'Halkbank',
  'VakıfBank',
  'QNB',
  'DenizBank',
  'TEB',
  'ING Türkiye',
  'Kuveyt Türk',
  'Albaraka Türk',
  'Türkiye Finans',
  'Şekerbank',
  'Fibabanka',
  'Anadolubank',
  'Odea Bank',
  'Burgan Bank',
  'ICBC Turkey',
];

/// Maps legacy/informal free-text bank names (as previously saved through
/// the plain TextField this page used to have) to their canonical
/// kTurkishBanks entry, so old data can still be shown as a valid dropdown
/// selection. Keys are matched case-insensitively.
const Map<String, String> _kBankNameAliases = {
  'ziraat': 'Ziraat Bankası',
  'ziraat bankasi': 'Ziraat Bankası',
  'ziraat bankası': 'Ziraat Bankası',
  'isbank': 'Türkiye İş Bankası',
  'is bankasi': 'Türkiye İş Bankası',
  'iş bankası': 'Türkiye İş Bankası',
  'türkiye iş bankası': 'Türkiye İş Bankası',
  'turkiye is bankasi': 'Türkiye İş Bankası',
  'garanti': 'Garanti BBVA',
  'garantibbva': 'Garanti BBVA',
  'garanti bankasi': 'Garanti BBVA',
  'akbank': 'Akbank',
  'yapikredi': 'Yapı Kredi',
  'yapi kredi': 'Yapı Kredi',
  'yapı kredi': 'Yapı Kredi',
  'halk': 'Halkbank',
  'halkbank': 'Halkbank',
  'halk bankasi': 'Halkbank',
  'vakif': 'VakıfBank',
  'vakifbank': 'VakıfBank',
  'vakıfbank': 'VakıfBank',
  'vakıf': 'VakıfBank',
  'qnb': 'QNB',
  'qnb finansbank': 'QNB',
  'finansbank': 'QNB',
  'deniz': 'DenizBank',
  'denizbank': 'DenizBank',
  'teb': 'TEB',
  'ing': 'ING Türkiye',
  'ing turkiye': 'ING Türkiye',
  'ing türkiye': 'ING Türkiye',
  'kuveyt turk': 'Kuveyt Türk',
  'kuveyt türk': 'Kuveyt Türk',
  'kuveytturk': 'Kuveyt Türk',
  'albaraka': 'Albaraka Türk',
  'albaraka turk': 'Albaraka Türk',
  'albaraka türk': 'Albaraka Türk',
  'turkiye finans': 'Türkiye Finans',
  'türkiye finans': 'Türkiye Finans',
  'sekerbank': 'Şekerbank',
  'şekerbank': 'Şekerbank',
  'fibabanka': 'Fibabanka',
  'anadolubank': 'Anadolubank',
  'odeabank': 'Odea Bank',
  'odea bank': 'Odea Bank',
  'burgan': 'Burgan Bank',
  'burgan bank': 'Burgan Bank',
  'icbc': 'ICBC Turkey',
  'icbc turkey': 'ICBC Turkey',
};

/// Resolves a stored bank name (canonical or legacy free-text) to an exact
/// kTurkishBanks entry, or null if it can't be confidently matched — in
/// which case the dropdown is left unselected rather than guessing wrong.
String? normalizeBankName(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return null;

  if (kTurkishBanks.contains(value)) return value;

  final key = value.toLowerCase();
  final alias = _kBankNameAliases[key];
  if (alias != null) return alias;

  for (final bank in kTurkishBanks) {
    if (bank.toLowerCase() == key) return bank;
  }

  return null;
}

/// Shared "Bank Account" settings page, reachable from every business
/// sector's Settings surface. Reads/writes the canonical, sector-agnostic
/// businesses/{businessId}.payment field via the updateBusinessBankAccount
/// Cloud Function, which performs the same validation used at registration.
///
/// This is a payout destination for real money — the visual design is
/// intentionally calm, precise and unambiguous rather than decorative.
class BankAccountSettingsPage extends StatefulWidget {
  final String businessId;

  /// Testing seam only. Production callers never pass this — it defaults
  /// to the real FirebaseFirestore.instance, so behavior is unchanged.
  final FirebaseFirestore? firestore;

  const BankAccountSettingsPage({
    super.key,
    required this.businessId,
    this.firestore,
  });

  @override
  State<BankAccountSettingsPage> createState() =>
      _BankAccountSettingsPageState();
}

class _BankAccountSettingsPageState extends State<BankAccountSettingsPage> {
  static const String _region = 'europe-west3';
  static final RegExp _ibanRegex = RegExp(r'^TR\d{24}$');
  static const int _ibanMaxLength = 26; // TR + 24 digits
  static const double _maxContentWidth = 640;

  final _formKey = GlobalKey<FormState>();
  final _accountHolderController = TextEditingController();
  final _ibanController = TextEditingController();
  final _billingInfoController = TextEditingController();
  final List<String> _sortedBanks = List<String>.from(kTurkishBanks)..sort();

  String? _selectedBank;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _ibanController.dispose();
    _billingInfoController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final firestore = widget.firestore ?? FirebaseFirestore.instance;

      final docRef = firestore.collection('businesses').doc(widget.businessId);
      final snap = await docRef.get();

      final rawData = snap.data();
      final rawPayment = rawData?['payment'];

      final data = snap.data() ?? <String, dynamic>{};
      final payment = (data['payment'] as Map?)?.cast<String, dynamic>() ?? {};

      // Read the canonical fields first. A missing/null value simply stays
      // an empty string here — nothing is ever written back during load.
      String? accountHolder = payment['accountHolder']?.toString();
      String? bankName = payment['bankName']?.toString();
      String? iban = payment['iban']?.toString();
      String? billingInfo = payment['billingInfo']?.toString();

      final hasCanonicalData =
          (accountHolder != null && accountHolder.trim().isNotEmpty) ||
          (iban != null && iban.trim().isNotEmpty);

      // Canonical field is empty — pre-fill from the legacy veterinary
      // registration data only. This never writes anything; the value only
      // moves into the canonical payment field once the user presses Save.
      if (!hasCanonicalData) {
        final sectorData =
            (data['sectorData'] as Map?)?.cast<String, dynamic>() ?? {};
        final veterinary =
            (sectorData['veterinary'] as Map?)?.cast<String, dynamic>() ?? {};
        final partnershipPayment =
            (veterinary['partnershipPayment'] as Map?)
                ?.cast<String, dynamic>() ??
            {};

        accountHolder = partnershipPayment['financialContactPerson']
            ?.toString();
        iban = partnershipPayment['iban']?.toString();
        billingInfo = partnershipPayment['billingInformation']?.toString();
        // The legacy vet form never collected a bank name — bankName stays
        // null here and must be filled in explicitly on first save.
      }

      final normalizedBank = normalizeBankName(bankName);
      debugPrint(
        '[BankAccountSettingsPage] raw bankName="$bankName" '
        'normalized bankName="$normalizedBank" '
        'isExactBankListMember=${kTurkishBanks.contains(normalizedBank)}',
      );

      if (!mounted) return;
      setState(() {
        _accountHolderController.text = accountHolder ?? '';
        _ibanController.text = _IbanInputFormatter.group(iban ?? '');
        _billingInfoController.text = billingInfo ?? '';
        // Normalizes both already-canonical names and legacy free-text
        // values (e.g. "ziraat") to an exact kTurkishBanks entry. Leaves
        // the dropdown unselected rather than guessing if it can't match.
        _selectedBank = normalizedBank;
      });
      debugPrint(
        '[BankAccountSettingsPage] _selectedBank assigned = "$_selectedBank"',
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        AppLocalizations.of(context)!.errorOccurred(e.toString()),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.businessRegisterRequired;
    }
    return null;
  }

  String? _ibanValidator(String? value) {
    final l10n = AppLocalizations.of(context)!;
    final normalized = _normalizeIban(value);
    if (normalized.isEmpty) return l10n.businessRegisterRequired;
    if (!_ibanRegex.hasMatch(normalized)) return l10n.bankAccountIbanInvalid;
    return null;
  }

  String _normalizeIban(String? value) {
    return (value ?? '').replaceAll(' ', '').toUpperCase();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() => _saving = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: _region,
      ).httpsCallable('updateBusinessBankAccount');

      await callable.call({
        'businessId': widget.businessId,
        'accountHolder': _accountHolderController.text.trim(),
        'bankName': _selectedBank ?? '',
        'iban': _normalizeIban(_ibanController.text),
        'billingInfo': _billingInfoController.text.trim(),
      });

      if (!mounted) return;
      _showSuccessSnackBar(l10n.bankAccountSaveSuccess);

      // The save succeeded — close the page and return to the caller
      // automatically. `true` tells a caller that depends on the updated
      // bank account data (e.g. a payout screen) to refresh.
      Navigator.of(context).pop(true);
      return;
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(l10n.errorOccurred(e.message ?? e.code));
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(l10n.errorOccurred(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.success,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: AppTheme.body(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.danger,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: AppTheme.body(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      helperMaxLines: 2,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.card),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: BorderSide(color: AppTheme.danger.withValues(alpha: 0.6)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!_loading) {
      debugPrint(
        '[BankAccountSettingsPage] build() selected dropdown value='
        '"$_selectedBank"',
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text(l10n.bankAccountSettingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: _loading
                ? const _BankAccountSkeleton()
                : Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: [
                        _HeaderCard(
                          title: l10n.bankAccountSettingsTitle,
                          subtitle: l10n.bankAccountSettingsSubtitle,
                        ),
                        const SizedBox(height: 16),
                        _InfoNotice(message: l10n.bankAccountInfoNotice),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusCard,
                            ),
                            boxShadow: AppTheme.cardShadow(opacity: 0.06),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.bankAccountSectionTitle,
                                style: AppTheme.h2(),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _accountHolderController,
                                textInputAction: TextInputAction.next,
                                decoration: _fieldDecoration(
                                  label: l10n.bankAccountHolderLabel,
                                  icon: LucideIcons.user,
                                ),
                                validator: _requiredValidator,
                              ),
                              const SizedBox(height: 18),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedBank,
                                isExpanded: true,
                                decoration: _fieldDecoration(
                                  label: l10n.bankAccountBankNameLabel,
                                  icon: LucideIcons.building2,
                                ),
                                items: _sortedBanks
                                    .map(
                                      (bank) => DropdownMenuItem<String>(
                                        value: bank,
                                        child: Text(
                                          bank,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _selectedBank = value);
                                },
                                validator: (value) =>
                                    (value == null || value.isEmpty)
                                    ? AppLocalizations.of(
                                        context,
                                      )!.businessRegisterRequired
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _ibanController,
                                textInputAction: TextInputAction.next,
                                textCapitalization:
                                    TextCapitalization.characters,
                                keyboardType: TextInputType.visiblePassword,
                                style: const TextStyle(
                                  fontFeatures: [FontFeature.tabularFigures()],
                                  letterSpacing: 1.1,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9 ]'),
                                  ),
                                  _IbanInputFormatter(),
                                ],
                                decoration: _fieldDecoration(
                                  label: l10n.bankAccountIbanLabel,
                                  icon: LucideIcons.creditCard,
                                  helperText: l10n.bankAccountIbanInvalid,
                                ),
                                validator: _ibanValidator,
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _billingInfoController,
                                maxLines: 3,
                                minLines: 2,
                                textInputAction: TextInputAction.done,
                                decoration: _fieldDecoration(
                                  label: l10n.bankAccountBillingInfoLabel,
                                  icon: LucideIcons.receipt,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(LucideIcons.checkCircle2),
                            label: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(l10n.save, style: AppTheme.button()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Formats raw IBAN characters into groups of 4 for display
/// (TR93 0001 0024 2287 0318 3350 02) while the caller is responsible for
/// normalizing (stripping spaces, uppercasing) before validation/storage.
class _IbanInputFormatter extends TextInputFormatter {
  static String group(String raw) {
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final buffer = StringBuffer();
    for (var i = 0; i < clean.length; i++) {
      if (i != 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final clean = newValue.text.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );

    final capped = clean.length > _BankAccountSettingsPageState._ibanMaxLength
        ? clean.substring(0, _BankAccountSettingsPageState._ibanMaxLength)
        : clean;

    final formatted = group(capped);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.cardShadow(opacity: 0.14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.landmark, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.h2(color: Colors.white)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: AppTheme.caption(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  final String message;

  const _InfoNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shieldCheck, color: AppTheme.card, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTheme.body(
                color: AppTheme.textDark.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight, dependency-free loading skeleton mirroring the page's real
/// layout, shown while the business document is being fetched.
class _BankAccountSkeleton extends StatelessWidget {
  const _BankAccountSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _ShimmerBox(height: 92, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 16),
        _ShimmerBox(height: 64, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow(opacity: 0.04),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(height: 18, width: 140),
              const SizedBox(height: 20),
              _ShimmerBox(height: 56),
              const SizedBox(height: 18),
              _ShimmerBox(height: 56),
              const SizedBox(height: 18),
              _ShimmerBox(height: 56),
              const SizedBox(height: 18),
              _ShimmerBox(height: 80),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ShimmerBox(height: 52, borderRadius: BorderRadius.circular(14)),
      ],
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  const _ShimmerBox({required this.height, this.width, this.borderRadius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.35,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius:
              widget.borderRadius ?? BorderRadius.circular(AppTheme.radius),
        ),
      ),
    );
  }
}
