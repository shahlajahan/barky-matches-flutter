import 'package:flutter/widgets.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
// اضافه کردن برای استفاده از localizations

mixin LocalizationUtils {
  /// لیست نژادها
  List<String> getDogBreeds(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return <String>[
      localizations.breedLabradorRetriever,
      localizations.breedGermanShepherd,
      localizations.breedGoldenRetriever,
      localizations.breedPoodle,
      localizations.breedBulldog,
      localizations.breedBeagle,
      localizations.breedRottweiler,
      localizations.breedDachshund,
      localizations.breedSiberianHusky,
      localizations.breedDobermanPinscher,
      localizations.breedChihuahua,
      localizations.breedBoxer,
      localizations.breedGreatDane,
      localizations.breedMaltese,
      localizations.breedShihTzu,
      localizations.breedCockerSpaniel,
      localizations.breedBorderCollie,
      localizations.breedPomeranian,
      localizations.breedAustralianShepherd,
      localizations.breedAmericanPitBullTerrier,
    ];
  }

  /// لیست ویژگی‌ها/تریت‌ها
  List<String> getDogTraits(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return <String>[
      localizations.traitFriendly,
      localizations.traitEnergetic,
      localizations.traitCalm,
      localizations.traitPlayful,
      localizations.traitGoodWithKids,
      localizations.traitTrained,
      localizations.traitShy,
      localizations.traitProtective,
      localizations.traitSocial,
      localizations.traitIndependent,
    ];
  }
}