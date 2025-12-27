// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get userNotLoggedIn => 'User not logged in. Redirecting to login...';

  @override
  String errorLoadingUserInfo(Object error) {
    return 'Error loading user info: $error';
  }

  @override
  String errorLoadingDogs(Object error) {
    return 'Error loading dogs: $error';
  }

  @override
  String get usernameCannotBeEmpty => 'Username cannot be empty';

  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully';

  @override
  String errorUpdatingDog(Object error) {
    return 'Error updating dog: $error';
  }

  @override
  String errorDeletingAccount(Object error) {
    return 'Error deleting account: $error';
  }

  @override
  String get accountDeleted => 'Account deleted.';

  @override
  String errorDuringLogout(Object error) {
    return 'Error during logout: $error';
  }

  @override
  String adoptionRequestSent(Object dogName) {
    return 'Adoption request sent for $dogName!';
  }

  @override
  String get myProfile => 'My Profile';

  @override
  String get userProfile => 'User Profile';

  @override
  String get profileInformation => 'Profile Information';

  @override
  String get myDogs => 'My Dogs';

  @override
  String get dogsAvailableForAdoption => 'Dogs Available for Adoption';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get username => 'Username';

  @override
  String get email => 'Email';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get enterPhoneNumberOptional => 'Enter phone number (optional)';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmation => 'Are you sure you want to delete your account? This action cannot be undone.';

  @override
  String get updateProfile => 'Update Profile';

  @override
  String get editProfileTooltip => 'Edit Profile';

  @override
  String get deleteAccountTooltip => 'Delete Account';

  @override
  String get logoutTooltip => 'Logout';

  @override
  String get noDogsAvailableForAdoption => 'No dogs available for adoption.';

  @override
  String get unknownUser => 'Unknown User';

  @override
  String get notProvided => 'Not Provided';

  @override
  String get noDogsAddedYet => 'No dogs added yet.';

  @override
  String get appTitle => 'Barky Matches';

  @override
  String get loadingUserData => 'Loading user data...';

  @override
  String get welcomeToBarkyMatches => 'Welcome to Barky Matches!';

  @override
  String get welcomeTo => 'Welcome to';

  @override
  String get barkyMatches => 'Barky Matches!';

  @override
  String welcomeBack(Object username) {
    return 'Welcome back, $username!';
  }

  @override
  String helloMessage(Object username) {
    return 'Hello, $username!';
  }

  @override
  String get signInTitle => 'Sign In';

  @override
  String get signUpTitle => 'Sign Up';

  @override
  String get signInButton => 'Sign In';

  @override
  String get signUpButton => 'Sign Up';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get emailLabel => 'Email';

  @override
  String get usernameLabel => 'Username';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get rememberMeLabel => 'Remember Me';

  @override
  String get forgotPasswordLabel => 'Forgot Password?';

  @override
  String get termsAndConditionsLabel => 'I accept the Terms and Conditions';

  @override
  String get receiveNewsLabel => 'Receive news and updates';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get emailInvalid => 'Please enter a valid email';

  @override
  String get usernameRequired => 'Please enter your username';

  @override
  String get phoneRequired => 'Please enter your phone number';

  @override
  String get phoneMinDigits => 'Phone number must be at least 10 digits';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get passwordValidation => 'Password must be at least 8 characters, including both letters and numbers';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get termsRequired => 'You must agree to the Terms and Conditions';

  @override
  String get forgotPasswordDialogTitle => 'Forgot Password';

  @override
  String get forgotPasswordDialogMessage => 'Please enter your email to reset your password.';

  @override
  String get sendButton => 'Send';

  @override
  String passwordResetSent(Object email) {
    return 'Password reset email sent to $email';
  }

  @override
  String get noAccountSignUp => 'Don’t have an account? Sign Up';

  @override
  String get haveAccountSignIn => 'Already have an account? Sign In';

  @override
  String get userNotFound => 'No user found with this email. Please register.';

  @override
  String get incorrectPassword => 'Incorrect password. Please try again.';

  @override
  String get fillAllFields => 'Please fill all fields correctly';

  @override
  String errorOccurred(Object error) {
    return 'An error occurred: $error';
  }

  @override
  String get verifyEmailTitle => 'Verify Your Email';

  @override
  String verificationCodeSent(Object email) {
    return 'A verification code has been sent to $email';
  }

  @override
  String get enterCodeLabel => 'Enter 6-digit Code';

  @override
  String get verifyButton => 'Verify';

  @override
  String get signInToAccessPlaymate => 'Please Sign In to access Playmate';

  @override
  String get signInToFindFriends => 'Please Sign In to find friends';

  @override
  String get addYourDog => 'Add Your Dog';

  @override
  String get nameLabel => 'Name *';

  @override
  String get pleaseEnterDogName => 'Please enter your dog\'s name';

  @override
  String get selectBreedHint => 'Select Breed';

  @override
  String get pleaseSelectBreed => 'Please select a breed';

  @override
  String get ageLabel => 'Age *';

  @override
  String get pleaseEnterDogAge => 'Please enter your dog\'s age';

  @override
  String get pleaseEnterValidAge => 'Please enter a valid age';

  @override
  String get selectGenderHint => 'Select Gender';

  @override
  String get pleaseSelectGender => 'Please select a gender';

  @override
  String get selectHealthStatusHint => 'Select Health Status';

  @override
  String get pleaseSelectHealthStatus => 'Please select a health status';

  @override
  String get neuteredLabel => 'Neutered *';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get pleaseSpecifyNeutered => 'Please specify if the dog is neutered';

  @override
  String get traitsLabel => 'Traits *';

  @override
  String get pleaseSelectAtLeastOneTrait => 'Please select at least one trait';

  @override
  String get selectOwnerGenderHint => 'Owner Gender';

  @override
  String get pleaseSelectOwnerGender => 'Please select your gender';

  @override
  String get uploadImagesLabel => 'Upload Images';

  @override
  String get pickFromGallery => 'Pick from Gallery';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get availableForAdoption => 'Available for Adoption';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get descriptionPlaceholder => 'Enter a description here...';

  @override
  String get colorLabel => 'Color';

  @override
  String get weightLabel => 'Weight (kg)';

  @override
  String get selectCollarTypeHint => 'Select Collar Type';

  @override
  String get clothingColorLabel => 'Clothing Color';

  @override
  String get lostLocationLabel => 'Lost Location *';

  @override
  String get foundLocationLabel => 'Found Location *';

  @override
  String get contactInfoLabel => 'Contact Info *';

  @override
  String get editDog => 'Edit Dog';

  @override
  String get save => 'Save';

  @override
  String dogNameExists(Object name) {
    return 'A dog with the name $name already exists!';
  }

  @override
  String get locationRequired => 'Location is required to add a dog.';

  @override
  String errorUploadingImage(Object error) {
    return 'Error uploading image: $error';
  }

  @override
  String errorAddingDog(Object error) {
    return 'Error adding dog: $error';
  }

  @override
  String get pleaseFillRequiredFields => 'Please fill all required fields correctly';

  @override
  String get addDogButton => 'Add Dog';

  @override
  String get dogDetailsAddTitle => 'Add Dog';

  @override
  String get dogDetailsEditTitle => 'Edit Dog';

  @override
  String get dogDetailsNameLabel => 'Name';

  @override
  String get dogDetailsAgeLabel => 'Age';

  @override
  String get dogDetailsDescriptionLabel => 'Description';

  @override
  String get dogDetailsGenderLabel => 'Gender:';

  @override
  String get dogDetailsHealthLabel => 'Health Status:';

  @override
  String get dogDetailsTraitsLabel => 'Traits:';

  @override
  String get dogDetailsOwnerGenderLabel => 'Owner Gender:';

  @override
  String get dogDetailsGenderMale => 'Male';

  @override
  String get dogDetailsGenderFemale => 'Female';

  @override
  String get dogDetailsHealthHealthy => 'Healthy';

  @override
  String get dogDetailsHealthNeedsCare => 'Needs Care';

  @override
  String get dogDetailsHealthUnderTreatment => 'Under Treatment';

  @override
  String get dogDetailsOwnerGenderPreferNotToSay => 'Prefer not to say';

  @override
  String get dogDetailsPickImageButton => 'Pick Image';

  @override
  String get dogDetailsAddButton => 'Add Dog';

  @override
  String get dogDetailsUpdateButton => 'Update Dog';

  @override
  String get dogDetailsNeuteredLabel => 'Neutered:';

  @override
  String get dogDetailsAdoptionLabel => 'Available for Adoption:';

  @override
  String dogDetailsNameExistsError(Object name) {
    return 'A dog with the name $name already exists!';
  }

  @override
  String get editDogPermissionDenied => 'You do not have permission to edit this dog.';

  @override
  String get editDogEnterName => 'Please enter the dog\'s name';

  @override
  String get editDogEnterValidAge => 'Please enter a valid age';

  @override
  String get editDogOwnerGenderMale => 'Male';

  @override
  String get editDogOwnerGenderFemale => 'Female';

  @override
  String get editDogOwnerGenderOther => 'Other';

  @override
  String get findPlaymateTitle => 'Find a Playmate';

  @override
  String get noDogsMatchFilters => 'No dogs match your filters.';

  @override
  String get adjustFiltersSuggestion => 'Try adjusting your filters or increasing the distance.';

  @override
  String get anyGender => 'Any';

  @override
  String distanceLabel(Object distance) {
    return 'Distance: $distance km';
  }

  @override
  String get resetFiltersButton => 'Reset Filters';

  @override
  String get moreFiltersButton => 'More Filters';

  @override
  String get filterByBreed => 'Filter by Breed';

  @override
  String get filterByGender => 'Filter by Gender';

  @override
  String get filterByAge => 'Filter by Age';

  @override
  String get filterByNeuteredStatus => 'Filter by Neutered Status';

  @override
  String get selectNeuteredStatusHint => 'Select Neutered Status';

  @override
  String get filterByHealthStatus => 'Filter by Health Status';

  @override
  String get upgradeToPremiumForMoreFilters => 'Upgrade to Premium for more filters!';

  @override
  String get apply => 'Apply';

  @override
  String get favoritesPageTitle => 'Favorite Dogs';

  @override
  String get noFavoriteDogsYet => 'No favorite dogs yet!';

  @override
  String get addFavoriteSuggestion => 'Go back to the home page and add some dogs to your favorites.';

  @override
  String get removeFavoriteTooltip => 'Remove Favorite';

  @override
  String get schedulePlaydate => 'Schedule Playdate';

  @override
  String get selectDateAndTime => 'Select Date and Time';

  @override
  String get pickDate => 'Pick Date';

  @override
  String get pickTime => 'Pick Time';

  @override
  String get selectYourDogHint => 'Select your dog';

  @override
  String get selectFriendsDogHint => 'Select friend\'s dog';

  @override
  String get selectYourDog => 'Select Your Dog';

  @override
  String get selectFriendsDog => 'Select Friend\'s Dog';

  @override
  String get pleaseLoginToSchedulePlaydate => 'Please log in to schedule a playdate';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get enterLocation => 'Enter location (e.g., Latitude: 41.0103, Longitude: 28.6724 or address)';

  @override
  String get pickOnMap => 'Pick on Map';

  @override
  String get quickLocations => 'Quick Locations';

  @override
  String get parkA => 'Park A';

  @override
  String get parkB => 'Park B';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get pleaseSelectBothDogs => 'Please select both dogs';

  @override
  String get pleaseLoginToCreateRequest => 'Please log in to create a request';

  @override
  String playdateRequestMessage(Object requesterDog, Object requestedDog) {
    return '$requesterDog wants to play with $requestedDog!';
  }

  @override
  String get requestCreatedSuccess => 'Request created successfully';

  @override
  String errorCreatingRequest(Object error) {
    return 'Error creating request: $error';
  }

  @override
  String playdateScheduled(Object dogName, Object dateTime, Object location) {
    return 'Playdate with $dogName scheduled for $dateTime at $location!';
  }

  @override
  String get newPlaydateRequest => 'New Playdate Request!';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog wants to play with $requestedDog!';
  }

  @override
  String removedFromFavorites(Object dogName) {
    return '$dogName removed from favorites!';
  }

  @override
  String addedToFavorites(Object dogName) {
    return '$dogName added to favorites!';
  }

  @override
  String errorTogglingFavorite(Object error) {
    return 'Error toggling favorite: $error';
  }

  @override
  String chatWithOwner(Object dogName) {
    return 'Chat with $dogName\'s owner!';
  }

  @override
  String errorSchedulingPlaydate(Object error) {
    return 'Error scheduling playdate: $error';
  }

  @override
  String get viewEditDogDetails => 'View/Edit Dog Details';

  @override
  String editNotAllowed(Object dogName) {
    return 'No edit permission for $dogName, onDogUpdated is empty';
  }

  @override
  String editDialogOpen(Object dogName) {
    return 'Edit dialog already open or editing in progress for $dogName';
  }

  @override
  String openingEditDialog(Object dogName) {
    return 'Opening EditDogDialog for $dogName';
  }

  @override
  String dogUpdatedInDialog(Object dogName) {
    return '$dogName updated in dialog';
  }

  @override
  String dialogPopped(Object dogName) {
    return 'Dialog successfully popped for $dogName';
  }

  @override
  String updatedDogReturned(Object dogName) {
    return 'Updated dog returned from dialog: $dogName';
  }

  @override
  String errorInShowDialog(Object dogName, Object error) {
    return 'showDialog error for $dogName: $error';
  }

  @override
  String dialogClosed(Object isEditing, Object isDialogOpen) {
    return 'Dialog closed, isEditing: $isEditing, isDialogOpen: $isDialogOpen';
  }

  @override
  String widgetNotMounted(Object isDialogOpen) {
    return 'Widget not mounted, reset isDialogOpen to: $isDialogOpen';
  }

  @override
  String removedDislike(Object dogName) {
    return 'Dislike removed for $dogName!';
  }

  @override
  String addedDislike(Object dogName) {
    return '$dogName disliked!';
  }

  @override
  String dislikeNotificationFailed(Object message) {
    return 'Dislike notification failed: $message';
  }

  @override
  String ensureNotificationsEnabled(Object dogName) {
    return 'Please ensure notifications are enabled for $dogName\'s owner.';
  }

  @override
  String failedToDislike(Object message) {
    return 'Failed to dislike: $message';
  }

  @override
  String errorSendingDislike(Object error) {
    return 'Error sending dislike notification: $error';
  }

  @override
  String disposing(Object dogName) {
    return 'Disposing for $dogName';
  }

  @override
  String resetIsDialogOpen(Object isDialogOpen) {
    return 'Reset isDialogOpen during cancel: $isDialogOpen';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get playdateRequests => 'Playdate Requests';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get noPlaydateRequests => 'No playdate requests yet.';

  @override
  String get accept => 'Accept';

  @override
  String get reject => 'Reject';

  @override
  String get status => 'Status';

  @override
  String get delete => 'Delete';

  @override
  String get rejectConfirmation => 'Reject Confirmation';

  @override
  String get areYouSure => 'Are you sure you want to reject this request?';

  @override
  String get notificationDeleted => 'Notification deleted';

  @override
  String errorDeletingNotification(Object error) {
    return 'Error deleting notification: $error';
  }

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get playdateRequestsSection => 'Playdate Requests';

  @override
  String get noTitle => 'No Title';

  @override
  String get noBody => 'No Body';

  @override
  String get newLikeTitle => 'New Like!';

  @override
  String newLikeBody(Object username, Object dogName) {
    return '$username liked your dog $dogName!';
  }

  @override
  String get newPlayDateRequestTitle => 'New Playdate Request!';

  @override
  String newPlayDateRequestBody(Object dogName) {
    return 'You have a new playdate request from $dogName.';
  }

  @override
  String get playDateCanceledTitle => 'PlayDate Request Canceled';

  @override
  String playDateCanceledBody(Object dogName) {
    return 'The playdate request with $dogName has been canceled.';
  }

  @override
  String get playDateAcceptedTitle => 'PlayDate Request Accepted!';

  @override
  String playDateAcceptedBodyRequester(Object dogName) {
    return 'You accepted the playdate request with $dogName';
  }

  @override
  String playDateAcceptedBodyRequested(Object dogName, Object dateTime) {
    return '$dogName accepted your playdate request with $dogName at $dateTime';
  }

  @override
  String get playDateRejectedTitle => 'PlayDate Request Rejected';

  @override
  String playDateRejectedBodyRequester(Object dogName) {
    return 'You rejected the playdate request with $dogName';
  }

  @override
  String playDateRejectedBodyRequested(Object dogName) {
    return '$dogName rejected your playdate request with $dogName';
  }

  @override
  String errorLoadingNotifications(Object error) {
    return 'Error updating notifications: $error';
  }

  @override
  String errorInitializingOrLoadingRequests(Object error) {
    return 'Error initializing or loading requests: $error';
  }

  @override
  String errorLoadingRequests(Object error) {
    return 'Error loading requests: $error';
  }

  @override
  String errorLoadingSpecificRequest(Object error) {
    return 'Error loading specific request: $error';
  }

  @override
  String errorLoadingNotificationsStream(Object error) {
    return 'Error loading notifications stream: $error';
  }

  @override
  String errorLoadingRequestsStream(Object error) {
    return 'Error loading requests stream: $error';
  }

  @override
  String errorUpdatingStatus(Object error) {
    return 'Error updating status: $error';
  }

  @override
  String errorUpdatingStatusUnexpected(Object error) {
    return 'Unexpected error updating status: $error';
  }

  @override
  String get pleaseLoginToRespond => 'Please log in to respond to requests';

  @override
  String requestStatusUpdated(Object status) {
    return 'Request $status successfully';
  }

  @override
  String errorRespondingToRequest(Object error) {
    return 'Error responding to request: $error';
  }

  @override
  String errorRespondingToRequestUnexpected(Object error) {
    return 'Unexpected error responding to request: $error';
  }

  @override
  String get pleaseLoginToAccept => 'Please log in to accept requests';

  @override
  String get requestAcceptedSuccess => 'Request accepted and added to playdates list.';

  @override
  String errorAcceptingRequest(Object error) {
    return 'Error accepting request: $error';
  }

  @override
  String errorAcceptingRequestUnexpected(Object error) {
    return 'Unexpected error accepting request: $error';
  }

  @override
  String get pleaseLoginToReject => 'Please log in to reject requests';

  @override
  String get requestRejectedSuccess => 'Request rejected';

  @override
  String errorRejectingRequest(Object error) {
    return 'Error rejecting request: $error';
  }

  @override
  String errorRejectingRequestUnexpected(Object error) {
    return 'Unexpected error rejecting request: $error';
  }

  @override
  String get failedToScheduleReminder => 'Failed to schedule reminder. Check permissions.';

  @override
  String get scheduledLabel => 'Scheduled:';

  @override
  String get locationLabel => 'Location:';

  @override
  String get unknownStatus => 'unknown';

  @override
  String get unknownTime => 'Unknown time';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours hr ago';
  }

  @override
  String daysAgo(Object days) {
    return '$days d ago';
  }

  @override
  String get notScheduled => 'Not scheduled';

  @override
  String get upcomingPlaydateTitle => 'Upcoming Playdate';

  @override
  String upcomingPlaydateBodyRequester(Object dogName) {
    return 'You have a playdate in 2 hours with $dogName!';
  }

  @override
  String upcomingPlaydateBodyRequested(Object dogName) {
    return 'You have a playdate in 2 hours with $dogName!';
  }

  @override
  String get appFeatures => 'With our app, you can:';

  @override
  String get appFeaturesMessage => 'With our app, you can:';

  @override
  String get playmateService => 'Playmate';

  @override
  String get vetServices => 'Vet Services';

  @override
  String get adoptionService => 'Adoption';

  @override
  String get dogTrainingService => 'Dog Training';

  @override
  String get dogParkService => 'Dog Park';

  @override
  String get findFriendsService => 'Find Friends';

  @override
  String get getStarted => 'Get Started';

  @override
  String get dogTraining => 'Dog Training';

  @override
  String get dogPark => 'Dog Park';

  @override
  String get findFriends => 'Find Friends';

  @override
  String get dogTrainingComingSoon => 'Dog Training Coming Soon!';

  @override
  String get lostDogsComingSoon => 'Lost Dogs Coming Soon!';

  @override
  String get petShopsComingSoon => 'Pet Shops Coming Soon!';

  @override
  String get hospitalsComingSoon => 'Hospitals Coming Soon!';

  @override
  String get findFriendsComingSoon => 'Find Friends Coming Soon!';

  @override
  String get menuTitle => 'Menu';

  @override
  String get homeMenuItem => 'Home';

  @override
  String get myDogsMenuItem => 'My Dogs';

  @override
  String get favoritesMenuItem => 'Favorites';

  @override
  String get adoptionCenterMenuItem => 'Adoption Center';

  @override
  String get dogParkMenuItem => 'Dog Park';

  @override
  String get reportLostDogMenuItem => 'Report Lost Dog';

  @override
  String get lostDogsMenuItem => 'Lost Dogs';

  @override
  String get reportFoundDogMenuItem => 'Report Found Dog';

  @override
  String get foundDogsMenuItem => 'Found Dogs';

  @override
  String get petShopsMenuItem => 'Pet Shops';

  @override
  String get hospitalsMenuItem => 'Hospitals';

  @override
  String get logoutMenuItem => 'Logout';

  @override
  String get filterDogsMenuItem => 'Filter Dogs';

  @override
  String get homeNavItem => 'Home';

  @override
  String get favoritesNavItem => 'Favorites';

  @override
  String get visitVetNavItem => 'Visit Vet';

  @override
  String get playdateNavItem => 'Playdate';

  @override
  String get profileNavItem => 'Profile';

  @override
  String get notificationsTooltip => 'Notifications';

  @override
  String get chatTooltip => 'Chat';

  @override
  String get chatNotImplemented => 'Chat functionality not implemented yet';

  @override
  String get dogParkTitle => 'Dog Parks';

  @override
  String dogParkDateLabel(Object date) {
    return 'Date: $date';
  }

  @override
  String get dogParkLoadMarkers => 'Load Park Markers';

  @override
  String get dogParkMoveToMarkers => 'Move to Markers';

  @override
  String get dogParkPermissionDenied => 'Location permission denied. Please enable it in settings.';

  @override
  String get dogParkBackgroundPermissionDenied => 'Background location permission denied. Some features may be limited.';

  @override
  String get dogParkLocationServicesDisabled => 'Location services are disabled.';

  @override
  String get dogParkEnableLocationServices => 'Please enable location services to continue.';

  @override
  String get dogParkPermissionDeniedPermanent => 'Location permission permanently denied.';

  @override
  String get dogParkPermissionsDenied => 'Location permissions are permanently denied. Please enable them from settings.';

  @override
  String dogParkLocationError(Object error) {
    return 'Error getting location: $error';
  }

  @override
  String get dogParkPermissionRequired => 'Location permission is required to show nearby dog parks.';

  @override
  String get dogParkBackgroundRecommended => 'Background location permission is recommended. Please enable it in settings.';

  @override
  String get dogParkSettingsAction => 'Settings';

  @override
  String dogParkDistanceLabel(Object distance) {
    return 'Distance: $distance km';
  }

  @override
  String get dogViewTitle => 'Dog Details';

  @override
  String get dogViewNameLabel => 'Name:';

  @override
  String get dogViewBreedLabel => 'Breed:';

  @override
  String get dogViewAgeLabel => 'Age:';

  @override
  String get dogViewGenderLabel => 'Gender:';

  @override
  String get dogViewHealthLabel => 'Health:';

  @override
  String get dogViewNeuteredLabel => 'Neutered:';

  @override
  String get dogViewDescriptionLabel => 'Description:';

  @override
  String get dogViewTraitsLabel => 'Traits:';

  @override
  String get dogViewOwnerGenderLabel => 'Owner Gender:';

  @override
  String get dogViewAvailableLabel => 'Available for Adoption:';

  @override
  String get dogViewYes => 'Yes';

  @override
  String get dogViewNo => 'No';

  @override
  String get dogViewLikeTooltip => 'Like';

  @override
  String get dogViewDislikeTooltip => 'Dislike';

  @override
  String get dogViewAddFavoriteTooltip => 'Add to Favorite';

  @override
  String get dogViewChatTooltip => 'Chat';

  @override
  String get dogViewScheduleDate => 'Schedule Date';

  @override
  String get dogViewAdoption => 'Adoption';

  @override
  String get dogViewChatStarted => 'Chat started!';

  @override
  String dogViewPlayDateScheduled(Object day, Object month, Object year, Object time) {
    return 'Play date scheduled for $day/$month/$year at $time!';
  }

  @override
  String get dogViewAdoptionRequest => 'Adoption request sent!';

  @override
  String get dogInfoTitle => 'Dog Information';

  @override
  String get dogInfoBreedLabel => 'Breed:';

  @override
  String get dogInfoAgeLabel => 'Age:';

  @override
  String get dogInfoGenderLabel => 'Gender:';

  @override
  String get dogInfoHealthLabel => 'Health Status:';

  @override
  String get dogInfoNeuteredLabel => 'Neutered:';

  @override
  String get dogInfoDescriptionLabel => 'Description:';

  @override
  String get dogInfoTraitsLabel => 'Traits:';

  @override
  String get dogInfoOwnerGenderLabel => 'Owner Gender:';

  @override
  String get dogInfoYes => 'Yes';

  @override
  String get dogInfoNo => 'No';

  @override
  String get dogInfoLikeTooltip => 'Like';

  @override
  String get dogInfoDislikeTooltip => 'Dislike';

  @override
  String get dogInfoChatTooltip => 'Chat';

  @override
  String get dogInfoAddFavoriteTooltip => 'Add to Favorite';

  @override
  String get dogInfoSchedulePlaydateTooltip => 'Schedule Playdate';

  @override
  String dogInfoPlaydateScheduled(Object dogName) {
    return 'Scheduled a play date with $dogName!';
  }

  @override
  String dogInfoLiked(Object dogName) {
    return 'Liked $dogName!';
  }

  @override
  String dogInfoDisliked(Object dogName) {
    return 'Disliked $dogName!';
  }

  @override
  String dogInfoChatWithOwner(Object dogName) {
    return 'Chat with $dogName\'s owner!';
  }

  @override
  String dogInfoRemovedFavorite(Object dogName) {
    return 'Removed $dogName from favorites!';
  }

  @override
  String dogInfoAddedFavorite(Object dogName) {
    return 'Added $dogName to favorites!';
  }

  @override
  String get noDogsFound => 'No Dogs Found';

  @override
  String get noDogsForUser => 'No dogs found for this user.';

  @override
  String get dogsOfThisUser => 'Dogs of this User';

  @override
  String get playDateStatus_pending => 'Pending';

  @override
  String get playDateStatus_accepted => 'Accepted';

  @override
  String get playDateStatus_rejected => 'Rejected';

  @override
  String get locationServicesDisabled => 'Location services are disabled. Using default location.';

  @override
  String get locationPermissionRequired => 'Location permission is required. Using default location.';

  @override
  String get locationPermissionPermanentlyDenied => 'Location permission is permanently denied. Using default location.';

  @override
  String errorGettingLocation(Object error) {
    return 'Error getting location: $error';
  }

  @override
  String errorLoadingData(Object error) {
    return 'Error loading data: $error';
  }

  @override
  String errorLoadingOffers(Object error) {
    return 'Error loading offers: $error';
  }

  @override
  String errorApplyingFilters(Object error) {
    return 'Error applying filters: $error';
  }

  @override
  String get notificationChannelName => 'High Importance Notifications';

  @override
  String get notificationChannelDescription => 'This channel is used for important notifications.';

  @override
  String get openAppAction => 'Open App';

  @override
  String get dismissAction => 'Dismiss';

  @override
  String get adoptionCenter => 'Adoption Center';

  @override
  String get traitEnergetic => 'Energetic';

  @override
  String get traitPlayful => 'Playful';

  @override
  String get traitCalm => 'Calm';

  @override
  String get traitLoyal => 'Loyal';

  @override
  String get traitFriendly => 'Friendly';

  @override
  String get traitProtective => 'Protective';

  @override
  String get traitIntelligent => 'Intelligent';

  @override
  String get traitAffectionate => 'Affectionate';

  @override
  String get traitCurious => 'Curious';

  @override
  String get traitIndependent => 'Independent';

  @override
  String get traitShy => 'Shy';

  @override
  String get traitTrained => 'Trained';

  @override
  String get traitSocial => 'Social';

  @override
  String get traitGoodWithKids => 'Good with kids';

  @override
  String get breedAfghanHound => 'Afghan Hound';

  @override
  String get breedAiredaleTerrier => 'Airedale Terrier';

  @override
  String get breedAkita => 'Akita';

  @override
  String get breedAlaskanMalamute => 'Alaskan Malamute';

  @override
  String get breedAmericanBulldog => 'American Bulldog';

  @override
  String get breedAmericanPitBullTerrier => 'Pit Bull';

  @override
  String get breedAustralianCattleDog => 'Australian Cattle Dog';

  @override
  String get breedAustralianShepherd => 'Australian Shepherd';

  @override
  String get breedBassetHound => 'Basset Hound';

  @override
  String get breedBeagle => 'Beagle';

  @override
  String get breedBelgianMalinois => 'Belgian Malinois';

  @override
  String get breedBerneseMountainDog => 'Bernese Mountain Dog';

  @override
  String get breedBichonFrise => 'Bichon Frise';

  @override
  String get breedBloodhound => 'Bloodhound';

  @override
  String get breedBorderCollie => 'Border Collie';

  @override
  String get breedBostonTerrier => 'Boston Terrier';

  @override
  String get breedBoxer => 'Boxer';

  @override
  String get breedBulldog => 'Bulldog';

  @override
  String get breedBullmastiff => 'Bullmastiff';

  @override
  String get breedCairnTerrier => 'Cairn Terrier';

  @override
  String get breedCaneCorso => 'Cane Corso';

  @override
  String get breedCavalierKingCharlesSpaniel => 'Cavalier King Charles Spaniel';

  @override
  String get breedChihuahua => 'Chihuahua';

  @override
  String get breedChowChow => 'Chow Chow';

  @override
  String get breedCockerSpaniel => 'Cocker Spaniel';

  @override
  String get breedCollie => 'Collie';

  @override
  String get breedDachshund => 'Dachshund';

  @override
  String get breedDalmatian => 'Dalmatian';

  @override
  String get breedDobermanPinscher => 'Doberman Pinscher';

  @override
  String get breedEnglishSpringerSpaniel => 'English Springer Spaniel';

  @override
  String get breedFrenchBulldog => 'French Bulldog';

  @override
  String get breedGermanShepherd => 'German Shepherd';

  @override
  String get breedGermanShorthairedPointer => 'German Shorthaired Pointer';

  @override
  String get breedGoldenRetriever => 'Golden Retriever';

  @override
  String get breedGreatDane => 'Great Dane';

  @override
  String get breedGreatPyrenees => 'Great Pyrenees';

  @override
  String get breedHavanese => 'Havanese';

  @override
  String get breedIrishSetter => 'Irish Setter';

  @override
  String get breedIrishWolfhound => 'Irish Wolfhound';

  @override
  String get breedJackRussellTerrier => 'Jack Russell Terrier';

  @override
  String get breedLabradorRetriever => 'Labrador Retriever';

  @override
  String get breedLhasaApso => 'Lhasa Apso';

  @override
  String get breedMaltese => 'Maltese';

  @override
  String get breedMastiff => 'Mastiff';

  @override
  String get breedMiniatureSchnauzer => 'Miniature Schnauzer';

  @override
  String get breedNewfoundland => 'Newfoundland';

  @override
  String get breedPapillon => 'Papillon';

  @override
  String get breedPekingese => 'Pekingese';

  @override
  String get breedPomeranian => 'Pomeranian';

  @override
  String get breedPoodle => 'Poodle';

  @override
  String get breedPug => 'Pug';

  @override
  String get breedRottweiler => 'Rottweiler';

  @override
  String get breedSaintBernard => 'Saint Bernard';

  @override
  String get breedSamoyed => 'Samoyed';

  @override
  String get breedShetlandSheepdog => 'Shetland Sheepdog';

  @override
  String get breedShihTzu => 'Shih Tzu';

  @override
  String get breedSiberianHusky => 'Siberian Husky';

  @override
  String get breedStaffordshireBullTerrier => 'Staffordshire Bull Terrier';

  @override
  String get breedVizsla => 'Vizsla';

  @override
  String get breedWeimaraner => 'Weimaraner';

  @override
  String get breedWestHighlandWhiteTerrier => 'West Highland White Terrier';

  @override
  String get breedYorkshireTerrier => 'Yorkshire Terrier';

  @override
  String get settings => 'Settings';

  @override
  String get playdateRequestsTitle => 'Playdate Requests & Notifications';

  @override
  String get sendRequestButton => 'Send Request';

  @override
  String get confirmLocation => 'Confirm Location';

  @override
  String get cancelButton => 'Cancel Action';

  @override
  String get editDogHealthHealthy => 'Healthy';

  @override
  String get editDogHealthNeedsCare => 'Needs Care';

  @override
  String get editDogHealthUnderTreatment => 'Under Treatment';

  @override
  String get noDogFoundForAccount => 'No dog found for your account. Please add a dog first.';

  @override
  String get pleaseSelectYourDog => 'Please select one of your dogs';

  @override
  String get cannotScheduleWithOwnDog => 'You cannot schedule a playdate with your own dog.';

  @override
  String get cannotScheduleWithTempUser => 'Cannot schedule a playdate with a temporary user.';

  @override
  String playdateRequestFor(Object dogName) {
    return 'Playdate request for $dogName';
  }

  @override
  String get forAdoption => 'For Adoption';

  @override
  String get neutered => 'Neutered';

  @override
  String get notNeutered => 'Not Neutered';

  @override
  String get pleaseSelectDogForPlaydate => 'Please select one of your dogs for playdate';

  @override
  String get years => 'years';

  @override
  String get breed => 'Breed';

  @override
  String get gender => 'Gender';

  @override
  String get healthStatus => 'Health Status';

  @override
  String get neuteredStatus => 'Neutered Status';

  @override
  String get description => 'Description';

  @override
  String get traits => 'Traits';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String get newFavoriteTitle => 'New Favorite!';

  @override
  String newFavoriteBody(Object userName, Object dogName) {
    return '$userName added your dog $dogName to favorites!';
  }

  @override
  String get likes => 'Likes';

  @override
  String get removeDislike => 'Remove Dislike';

  @override
  String get dislike => 'Dislike';

  @override
  String errorTogglingDislike(Object error) {
    return 'Error toggling dislike: $error';
  }

  @override
  String get sending => 'Sending...';

  @override
  String get schedulePlayDate => 'Schedule Play Date';

  @override
  String get chat => 'Chat';

  @override
  String get adoptDog => 'Adopt Dog';

  @override
  String errorSendingDislikeNotification(Object error) {
    return 'Error sending dislike notification: $error';
  }

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get healthHealthy => 'Healthy';

  @override
  String get healthNeedsCare => 'Needs Care';

  @override
  String get healthUnderTreatment => 'Under Treatment';

  @override
  String get dogDetailsHealthSick => 'Needs Care';

  @override
  String get dogDetailsHealthRecovering => 'Under Treatment';

  @override
  String get noImageSelected => 'No image selected.';

  @override
  String get unknownGender => 'Unknown Gender';

  @override
  String get unknownBreed => 'Unknown Breed';

  @override
  String get unknownTrait => 'Unknown Trait';

  @override
  String get noTraits => 'No traits available';

  @override
  String get simpleTestPageTitle => 'Simple Test Page';

  @override
  String get simpleTestPageMessage => 'This is a simple test page.';

  @override
  String likedBy(Object likers) {
    return 'Liked by: $likers';
  }

  @override
  String get locationNotAcquired => 'Location not acquired. Please try again.';

  @override
  String get retryLocation => 'Retry Location';

  @override
  String get addLike => 'Like this dog';

  @override
  String get removeLike => 'Unlike this dog';

  @override
  String addedLike(Object dogName) {
    return 'You liked $dogName!';
  }

  @override
  String removedLike(Object dogName) {
    return 'You unliked $dogName!';
  }

  @override
  String errorTogglingLike(Object error) {
    return 'Error toggling like: $error';
  }

  @override
  String get errorNoOwnerFound => 'No valid owner found for this dog';
}
