import 'package:flutter/material.dart';
import 'dart:io';
import 'dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';


class DogViewPage extends StatefulWidget {
  final Dog dog;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;

  const DogViewPage({
    super.key,
    required this.dog,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  _DogViewPageState createState() => _DogViewPageState();
}

class _DogViewPageState extends State<DogViewPage> {
  bool _isLiked = false;
  bool _isDisliked = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _isLiked = false;
    _isDisliked = false;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) _isDisliked = false;
    });
  }

  void _toggleDislike() {
    setState(() {
      _isDisliked = !_isDisliked;
      if (_isDisliked) _isLiked = false;
    });
  }

  void _startChat() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.dogViewChatStarted)),
    );
  }

  Future<void> _scheduleDate() async {
    final l10n = AppLocalizations.of(context)!;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = pickedDate;
          _selectedTime = pickedTime;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.dogViewPlayDateScheduled(
                pickedDate.day.toString(),
                pickedDate.month.toString(),
                pickedDate.year.toString(),
                pickedTime.format(context),
              ),
            ),
          ),
        );
      }
    }
  }

  void _adoptDog() {
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.dogViewAdoptionRequest)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    bool isFavorite = widget.favoriteDogs.contains(widget.dog);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dog.name),
        backgroundColor: Colors.pink[400],
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: () {
                      if (widget.dog.imagePaths.isNotEmpty) {
                        final path = widget.dog.imagePaths[0];
                        if (path.startsWith('assets/')) {
                          return Image.asset(
                            path,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.pets, size: 250, color: Colors.white);
                            },
                          );
                        } else {
                          return Image.file(
                            File(path),
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.pets, size: 250, color: Colors.white);
                            },
                          );
                        }
                      }
                      return Image.asset(
                        'assets/image/dog1.jpg',
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.pets, size: 250, color: Colors.white);
                        },
                      );
                    }(),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  color: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${l10n.dogViewNameLabel} ${widget.dog.name}',
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewBreedLabel} ${widget.dog.breed}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewAgeLabel} ${widget.dog.age}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewGenderLabel} ${widget.dog.gender}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewHealthLabel} ${widget.dog.healthStatus}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewNeuteredLabel} ${widget.dog.isNeutered ? l10n.dogViewYes : l10n.dogViewNo}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewDescriptionLabel} ${widget.dog.description}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewTraitsLabel} ${widget.dog.traits.join(", ")}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewOwnerGenderLabel} ${widget.dog.ownerGender}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${l10n.dogViewAvailableLabel} ${widget.dog.isAvailableForAdoption ? l10n.dogViewYes : l10n.dogViewNo}',
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // فقط برای سگ‌هایی که متعلق به کاربر نیستن، آیکون‌ها رو نمایش بده
                if (!widget.dog.isOwner) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color: _isLiked ? Colors.green : Colors.white,
                        ),
                        onPressed: _toggleLike,
                        tooltip: l10n.dogViewLikeTooltip,
                      ),
                      IconButton(
                        icon: Icon(
                          _isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                          color: _isDisliked ? Colors.red : Colors.white,
                        ),
                        onPressed: _toggleDislike,
                        tooltip: l10n.dogViewDislikeTooltip,
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.white,
                        ),
                        onPressed: () {
                          widget.onToggleFavorite(widget.dog);
                        },
                        tooltip: l10n.dogViewAddFavoriteTooltip,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat, color: Colors.white),
                        onPressed: _startChat,
                        tooltip: l10n.dogViewChatTooltip,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // فقط برای سگ‌هایی که متعلق به کاربر نیستن، دکمه Schedule Date رو نمایش بده
                    if (!widget.dog.isOwner)
                      ElevatedButton(
                        onPressed: _scheduleDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.dogViewScheduleDate),
                      ),
                    if (widget.dog.isAvailableForAdoption)
                      ElevatedButton(
                        onPressed: _adoptDog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(l10n.dogViewAdoption),
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