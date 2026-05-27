enum DogFilterMode { playdate, adoption, discover }

bool shouldIncludeDog(Map<String, dynamic> data, DogFilterMode mode) {
  final isVisible = data['dogProfileVisible'] == true;
  final isHidden =
      (data['isHidden'] == true) || (data['moderation']?['isHidden'] == true);

  final isAvailable = data['isAvailableForAdoption'] == true;

  if (!isVisible || isHidden) return false;

  switch (mode) {
    case DogFilterMode.playdate:
      return true;

    case DogFilterMode.adoption:
      return isAvailable;

    case DogFilterMode.discover:
      return true;
  }
}
