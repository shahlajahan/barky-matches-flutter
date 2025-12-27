import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:flutter/foundation.dart';


class DogInfoPage extends StatelessWidget {
  final Dog dog;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const DogInfoPage({
    super.key,
    required this.dog,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  Future<ImageProvider?> _loadDogImage() async {
    if (dog.imagePaths.isEmpty) {
      if (kDebugMode) {
        print('DogInfoPage - No image paths for ${dog.name}');
      }
      return null;
    }
    try {
      final file = File(dog.imagePaths[0]);
      if (await file.exists()) {
        return FileImage(file);
      }
      if (kDebugMode) {
        print('DogInfoPage - Image file does not exist: ${dog.imagePaths[0]}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('DogInfoPage - Error loading image from path ${dog.imagePaths[0]}: $e');
      }
      return null;
    }
  }

  String _translateGender(BuildContext context, String gender) {
    final l10n = AppLocalizations.of(context);
    if (gender.isEmpty) return l10n?.unknownGender ?? 'Unknown Gender';
    final lowerGender = gender.toLowerCase().trim();
    if (kDebugMode) {
      print('Gender exact: "$gender" -> lower: "$lowerGender"');
    }
    final maleFa = (l10n?.genderMale ?? 'male').toLowerCase();
    final femaleFa = (l10n?.genderFemale ?? 'female').toLowerCase();
    if (lowerGender == maleFa || lowerGender == 'نر' || lowerGender == 'male') {
      return l10n?.genderMale ?? 'Male';
    }
    if (lowerGender == femaleFa || lowerGender == 'ماده' || lowerGender == 'female') {
      return l10n?.genderFemale ?? 'Female';
    }
    return gender;
  }

  String _translateBreed(BuildContext context, String breedKey) {
    final l10n = AppLocalizations.of(context);
    if (breedKey.isEmpty) return l10n?.unknownBreed ?? 'Unknown Breed';
    switch (breedKey) {
      case 'breedAfghanHound':
        return l10n?.breedAfghanHound ?? 'Afghan Hound';
      case 'breedAiredaleTerrier':
        return l10n?.breedAiredaleTerrier ?? 'Airedale Terrier';
      case 'breedAkita':
        return l10n?.breedAkita ?? 'Akita';
      case 'breedAlaskanMalamute':
        return l10n?.breedAlaskanMalamute ?? 'Alaskan Malamute';
      case 'breedAmericanBulldog':
        return l10n?.breedAmericanBulldog ?? 'American Bulldog';
      case 'breedAmericanPitBullTerrier':
        return l10n?.breedAmericanPitBullTerrier ?? 'American Pit Bull Terrier';
      case 'breedAustralianCattleDog':
        return l10n?.breedAustralianCattleDog ?? 'Australian Cattle Dog';
      case 'breedAustralianShepherd':
        return l10n?.breedAustralianShepherd ?? 'Australian Shepherd';
      case 'breedBassetHound':
        return l10n?.breedBassetHound ?? 'Basset Hound';
      case 'breedBeagle':
        return l10n?.breedBeagle ?? 'Beagle';
      case 'breedBelgianMalinois':
        return l10n?.breedBelgianMalinois ?? 'Belgian Malinois';
      case 'breedBerneseMountainDog':
        return l10n?.breedBerneseMountainDog ?? 'Bernese Mountain Dog';
      case 'breedBichonFrise':
        return l10n?.breedBichonFrise ?? 'Bichon Frise';
      case 'breedBloodhound':
        return l10n?.breedBloodhound ?? 'Bloodhound';
      case 'breedBorderCollie':
        return l10n?.breedBorderCollie ?? 'Border Collie';
      case 'breedBostonTerrier':
        return l10n?.breedBostonTerrier ?? 'Boston Terrier';
      case 'breedBoxer':
        return l10n?.breedBoxer ?? 'Boxer';
      case 'breedBulldog':
        return l10n?.breedBulldog ?? 'Bulldog';
      case 'breedBullmastiff':
        return l10n?.breedBullmastiff ?? 'Bullmastiff';
      case 'breedCairnTerrier':
        return l10n?.breedCairnTerrier ?? 'Cairn Terrier';
      case 'breedCaneCorso':
        return l10n?.breedCaneCorso ?? 'Cane Corso';
      case 'breedCavalierKingCharlesSpaniel':
        return l10n?.breedCavalierKingCharlesSpaniel ?? 'Cavalier King Charles Spaniel';
      case 'breedChihuahua':
        return l10n?.breedChihuahua ?? 'Chihuahua';
      case 'breedChowChow':
        return l10n?.breedChowChow ?? 'Chow Chow';
      case 'breedCockerSpaniel':
        return l10n?.breedCockerSpaniel ?? 'Cocker Spaniel';
      case 'breedCollie':
        return l10n?.breedCollie ?? 'Collie';
      case 'breedDachshund':
        return l10n?.breedDachshund ?? 'Dachshund';
      case 'breedDalmatian':
        return l10n?.breedDalmatian ?? 'Dalmatian';
      case 'breedDobermanPinscher':
        return l10n?.breedDobermanPinscher ?? 'Doberman Pinscher';
      case 'breedEnglishSpringerSpaniel':
        return l10n?.breedEnglishSpringerSpaniel ?? 'English Springer Spaniel';
      case 'breedFrenchBulldog':
        return l10n?.breedFrenchBulldog ?? 'French Bulldog';
      case 'breedGermanShepherd':
        return l10n?.breedGermanShepherd ?? 'German Shepherd';
      case 'breedGermanShorthairedPointer':
        return l10n?.breedGermanShorthairedPointer ?? 'German Shorthaired Pointer';
      case 'breedGoldenRetriever':
        return l10n?.breedGoldenRetriever ?? 'Golden Retriever';
      case 'breedGreatDane':
        return l10n?.breedGreatDane ?? 'Great Dane';
      case 'breedGreatPyrenees':
        return l10n?.breedGreatPyrenees ?? 'Great Pyrenees';
      case 'breedHavanese':
        return l10n?.breedHavanese ?? 'Havanese';
      case 'breedIrishSetter':
        return l10n?.breedIrishSetter ?? 'Irish Setter';
      case 'breedIrishWolfhound':
        return l10n?.breedIrishWolfhound ?? 'Irish Wolfhound';
      case 'breedJackRussellTerrier':
        return l10n?.breedJackRussellTerrier ?? 'Jack Russell Terrier';
      case 'breedLabradorRetriever':
        return l10n?.breedLabradorRetriever ?? 'Labrador Retriever';
      case 'breedLhasaApso':
        return l10n?.breedLhasaApso ?? 'Lhasa Apso';
      case 'breedMaltese':
        return l10n?.breedMaltese ?? 'Maltese';
      case 'breedMastiff':
        return l10n?.breedMastiff ?? 'Mastiff';
      case 'breedMiniatureSchnauzer':
        return l10n?.breedMiniatureSchnauzer ?? 'Miniature Schnauzer';
      case 'breedNewfoundland':
        return l10n?.breedNewfoundland ?? 'Newfoundland';
      case 'breedPapillon':
        return l10n?.breedPapillon ?? 'Papillon';
      case 'breedPekingese':
        return l10n?.breedPekingese ?? 'Pekingese';
      case 'breedPomeranian':
        return l10n?.breedPomeranian ?? 'Pomeranian';
      case 'breedPoodle':
        return l10n?.breedPoodle ?? 'Poodle';
      case 'breedPug':
        return l10n?.breedPug ?? 'Pug';
      case 'breedRottweiler':
        return l10n?.breedRottweiler ?? 'Rottweiler';
      case 'breedSaintBernard':
        return l10n?.breedSaintBernard ?? 'Saint Bernard';
      case 'breedSamoyed':
        return l10n?.breedSamoyed ?? 'Samoyed';
      case 'breedShetlandSheepdog':
        return l10n?.breedShetlandSheepdog ?? 'Shetland Sheepdog';
      case 'breedShihTzu':
        return l10n?.breedShihTzu ?? 'Shih Tzu';
      case 'breedSiberianHusky':
        return l10n?.breedSiberianHusky ?? 'Siberian Husky';
      case 'breedStaffordshireBullTerrier':
        return l10n?.breedStaffordshireBullTerrier ?? 'Staffordshire Bull Terrier';
      case 'breedVizsla':
        return l10n?.breedVizsla ?? 'Vizsla';
      case 'breedWeimaraner':
        return l10n?.breedWeimaraner ?? 'Weimaraner';
      case 'breedWestHighlandWhiteTerrier':
        return l10n?.breedWestHighlandWhiteTerrier ?? 'West Highland White Terrier';
      case 'breedYorkshireTerrier':
        return l10n?.breedYorkshireTerrier ?? 'Yorkshire Terrier';
      default:
        final parts = breedKey.split('breed');
        return parts.length > 1 ? parts[1] : breedKey;
    }
  }

  String _translateTrait(BuildContext context, String traitKey) {
    final l10n = AppLocalizations.of(context);
    if (traitKey.isEmpty) return l10n?.unknownTrait ?? 'Unknown Trait';
    final rawToLocalized = {
      'energetic': l10n?.traitEnergetic ?? 'Energetic',
      'playful': l10n?.traitPlayful ?? 'Playful',
      'calm': l10n?.traitCalm ?? 'Calm',
      'loyal': l10n?.traitLoyal ?? 'Loyal',
      'friendly': l10n?.traitFriendly ?? 'Friendly',
      'protective': l10n?.traitProtective ?? 'Protective',
      'intelligent': l10n?.traitIntelligent ?? 'Intelligent',
      'affectionate': l10n?.traitAffectionate ?? 'Affectionate',
      'curious': l10n?.traitCurious ?? 'Curious',
      'independent': l10n?.traitIndependent ?? 'Independent',
      'shy': l10n?.traitShy ?? 'Shy',
      'trained': l10n?.traitTrained ?? 'Trained',
      'social': l10n?.traitSocial ?? 'Social',
      'good with kids': l10n?.traitGoodWithKids ?? 'Good with kids',
      'دوستانه': l10n?.traitFriendly ?? 'Friendly',
      'پر انرژی': l10n?.traitEnergetic ?? 'Energetic',
      'خوب با بچه‌ها': l10n?.traitGoodWithKids ?? 'Good with kids',
    };
    final lowerTrait = traitKey.toLowerCase().trim();
    if (kDebugMode) {
      print('Trait exact: "$traitKey" -> lower: "$lowerTrait"');
    }
    return rawToLocalized[lowerTrait] ?? (traitKey.startsWith('trait') ? traitKey.substring(5) : traitKey);
  }

  String _translateHealthStatus(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    if (status.isEmpty) return l10n?.unknownStatus ?? 'Unknown Status';
    final lowerStatus = status.toLowerCase().trim();
    if (kDebugMode) {
      print('Health Status exact: "$status" -> lower: "$lowerStatus"');
    }
    final healthyFa = (l10n?.healthHealthy ?? 'healthy').toLowerCase();
    final needsFa = (l10n?.healthNeedsCare ?? 'needs care').toLowerCase();
    final underFa = (l10n?.healthUnderTreatment ?? 'under treatment').toLowerCase();
    if (lowerStatus == healthyFa || lowerStatus == 'سالم' || lowerStatus == 'healthy') {
      return l10n?.healthHealthy ?? 'Healthy';
    }
    if (lowerStatus == needsFa || lowerStatus == 'نیاز به مراقبت' || lowerStatus == 'needs care' || lowerStatus == 'needs attention') {
      return l10n?.healthNeedsCare ?? 'Needs Care';
    }
    if (lowerStatus == underFa || lowerStatus == 'در حال درمان' || lowerStatus == 'under treatment') {
      return l10n?.healthUnderTreatment ?? 'Under Treatment';
    }
    if (kDebugMode) {
      print('No match for health status: "$lowerStatus"');
    }
    return status;
  }

  Future<void> _schedulePlaydate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${l10n?.dogInfoPlaydateScheduled ?? 'Playdate scheduled with'} ${dog.name}')),
    );
    if (kDebugMode) {
      print('DogInfoPage - Playdate scheduled for ${dog.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final bool isFavorite = appState.favoriteDogs.contains(dog);
    final l10n = AppLocalizations.of(context);

    if (kDebugMode) {
      print('DogInfoPage - Building UI for dog: ${dog.name}, ID: ${dog.id}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dog.name),
        backgroundColor: Colors.pink[300],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dog.imagePaths.isNotEmpty)
                  FutureBuilder<ImageProvider?>(
                    future: _loadDogImage(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                        return const Icon(Icons.pets, size: 200, color: Colors.white);
                      }
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(
                          image: snapshot.data!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            if (kDebugMode) {
                              print('DogInfoPage - Error loading image for ${dog.name}: $error');
                            }
                            return const Icon(Icons.pets, size: 200, color: Colors.white);
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white.withOpacity(0.9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dog.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.pink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${l10n?.dogInfoBreedLabel ?? 'Breed:'} ${_translateBreed(context, dog.breed)}',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        Text(
                          '${l10n?.dogInfoAgeLabel ?? 'Age:'} ${dog.age}',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        Text(
                          '${l10n?.dogInfoGenderLabel ?? 'Gender:'} ${_translateGender(context, dog.gender)}',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        Text(
                          '${l10n?.dogInfoHealthLabel ?? 'Health Status:'} ${_translateHealthStatus(context, dog.healthStatus)}',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        Text(
                          '${l10n?.dogInfoNeuteredLabel ?? 'Neutered:'} ${dog.isNeutered ? l10n?.dogInfoYes ?? 'Yes' : l10n?.dogInfoNo ?? 'No'}',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n?.dogInfoDescriptionLabel ?? 'Description:',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        Text(
                          dog.description ?? '',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n?.dogInfoTraitsLabel ?? 'Traits:',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        Wrap(
                          spacing: 8.0,
                          children: dog.traits.map((trait) {
                            return Chip(
                              label: Text(_translateTrait(context, trait)),
                              backgroundColor: Colors.pink[100],
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${l10n?.dogInfoOwnerGenderLabel ?? 'Owner Gender:'} ${dog.ownerGender ?? ''}',
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.thumb_up, color: Colors.green),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${l10n?.dogInfoLiked ?? 'You liked'} ${dog.name}')),
                        );
                        if (kDebugMode) {
                          print('DogInfoPage - Liked dog: ${dog.name}');
                        }
                      },
                      tooltip: l10n?.dogInfoLikeTooltip ?? 'Like this dog',
                    ),
                    IconButton(
                      icon: const Icon(Icons.thumb_down, color: Colors.red),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${l10n?.dogInfoDisliked ?? 'You disliked'} ${dog.name}')),
                        );
                        if (kDebugMode) {
                          print('DogInfoPage - Disliked dog: ${dog.name}');
                        }
                      },
                      tooltip: l10n?.dogInfoDislikeTooltip ?? 'Dislike this dog',
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Colors.blue),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${l10n?.dogInfoChatWithOwner ?? 'Chat with'} ${dog.name}\'s owner')),
                        );
                        if (kDebugMode) {
                          print('DogInfoPage - Initiated chat for ${dog.name}');
                        }
                      },
                      tooltip: l10n?.dogInfoChatTooltip ?? 'Chat with owner',
                    ),
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: () {
                        appState.toggleFavorite(dog);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFavorite
                                  ? '${l10n?.dogInfoRemovedFavorite ?? 'Removed'} ${dog.name} ${l10n?.dogInfoRemovedFavorite ?? 'from favorites'}'
                                  : '${l10n?.dogInfoAddedFavorite ?? 'Added'} ${dog.name} ${l10n?.dogInfoAddedFavorite ?? 'to favorites'}',
                            ),
                          ),
                        );
                        if (kDebugMode) {
                          print('DogInfoPage - Toggled favorite for ${dog.name}, isFavorite: $isFavorite');
                        }
                      },
                      tooltip: l10n?.dogInfoAddFavoriteTooltip ?? 'Add to favorites',
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, color: Colors.white),
                      onPressed: () {
                        _schedulePlaydate(context);
                      },
                      tooltip: l10n?.dogInfoSchedulePlaydateTooltip ?? 'Schedule a playdate',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}