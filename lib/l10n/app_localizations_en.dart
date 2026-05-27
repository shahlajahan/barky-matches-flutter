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
  String get cartTitle => 'My Cart';

  @override
  String get cartIsEmpty => 'Cart is empty';

  @override
  String get totalLabel => 'Total';

  @override
  String get checkoutButton => 'Checkout';

  @override
  String get checkoutStepAddressTitle => 'Address';

  @override
  String get checkoutStepPaymentTitle => 'Payment';

  @override
  String get checkoutStepConfirmTitle => 'Confirm';

  @override
  String get checkoutDeliveryAddressTitle => 'Delivery Address';

  @override
  String get checkoutFullNameLabel => 'Full Name';

  @override
  String get checkoutFullNameHint => 'Name Surname';

  @override
  String get checkoutPhoneHint => '5XXXXXXXXX';

  @override
  String get checkoutCityLabel => 'City';

  @override
  String get checkoutCityHint => 'Istanbul';

  @override
  String get checkoutDistrictLabel => 'District';

  @override
  String get checkoutDistrictHint => 'Kadikoy';

  @override
  String get checkoutAddressLabel => 'Open Address';

  @override
  String get checkoutAddressHint => 'Full address details';

  @override
  String get checkoutInvoiceDetailsTitle => 'Invoice Details';

  @override
  String get checkoutIndividualOption => 'Individual';

  @override
  String get checkoutCompanyOption => 'Company';

  @override
  String get checkoutIdentityNumberLabel => 'Identity Number';

  @override
  String get checkoutIdentityNumberHint => '11 digits';

  @override
  String get checkoutCompanyNameLabel => 'Company Name';

  @override
  String get checkoutTaxNumberLabel => 'Tax Number';

  @override
  String get checkoutTaxNumberHint => '10 digits';

  @override
  String get checkoutTaxOfficeLabel => 'Tax Office';

  @override
  String get checkoutCargoUpdatesTitle => 'Invoice & Cargo Updates';

  @override
  String get checkoutCargoUpdatesQuestion =>
      'How should we send invoice and cargo tracking updates?';

  @override
  String get checkoutSmsOption => 'SMS';

  @override
  String get checkoutEmailOption => 'Email';

  @override
  String get checkoutSmsEmailOption => 'SMS + Email';

  @override
  String get checkoutAgreementsTitle => 'Agreements';

  @override
  String get checkoutKvkkDisclosure => 'I have read KVKK disclosure';

  @override
  String get checkoutViewButton => 'View';

  @override
  String get checkoutPreInfoForm => 'I accept the pre-information form';

  @override
  String get checkoutDistanceSalesAgreement =>
      'I accept the distance sales agreement';

  @override
  String get checkoutMarketingOptional =>
      'Receive marketing messages (optional)';

  @override
  String get checkoutDeliveryTitle => 'Delivery';

  @override
  String get checkoutPaymentSummaryTitle => 'Payment Summary';

  @override
  String get checkoutSubtotalLabel => 'Subtotal';

  @override
  String get checkoutVatLabel => 'VAT';

  @override
  String get checkoutShippingLabel => 'Shipping';

  @override
  String get checkoutPleaseSelectCargoCompany =>
      'Please select a cargo company';

  @override
  String get checkoutEnterNameSurname => 'Enter name & surname';

  @override
  String get checkoutEnterValidEmail => 'Enter valid email';

  @override
  String get checkoutEnterValidPhone => 'Enter valid phone';

  @override
  String get checkoutEnterCity => 'Enter city';

  @override
  String get checkoutEnterDistrict => 'Enter district';

  @override
  String get checkoutEnterFullAddress => 'Enter full address';

  @override
  String get checkoutEnterValidIdentityNumber => 'Enter valid identity number';

  @override
  String get checkoutEnterCompanyName => 'Enter company name';

  @override
  String get checkoutEnterValidTaxNumber => 'Enter valid tax number';

  @override
  String get checkoutEnterTaxOffice => 'Enter tax office';

  @override
  String get checkoutAcceptRequiredAgreements => 'Accept required agreements';

  @override
  String get checkoutPaymentPageOpenedMessage =>
      'Payment page opened. Complete the payment, then return to the app.';

  @override
  String get checkoutBackButton => 'Back';

  @override
  String get checkoutProceedToPayment => 'Proceed to Payment';

  @override
  String get checkoutContinueButton => 'Continue';

  @override
  String get checkoutPaymentCompletedSuccessfully =>
      'Payment completed successfully';

  @override
  String get checkoutPaymentCancelledOrIncomplete =>
      'Payment was cancelled or not completed';

  @override
  String checkoutFailed(Object error) {
    return 'Checkout failed: $error';
  }

  @override
  String adoptionRequestSent(Object dogName) {
    return 'Adoption request sent for $dogName!';
  }

  @override
  String get adoptionCentersTitle => 'Adoption Centers';

  @override
  String get availableDogsTitle => 'Available Dogs';

  @override
  String get noAdoptionCentersAvailable => 'No adoption centers available';

  @override
  String get noDogsAvailableInThisCenter => 'No dogs available in this center';

  @override
  String get adoptionRequestTitle => 'Adoption Request';

  @override
  String get yourPhone => 'Your Phone';

  @override
  String get whyDoYouWantToAdopt => 'Why do you want to adopt?';

  @override
  String get appointmentTitle => 'Appointment';

  @override
  String get cancelAppointmentButton => 'Cancel Appointment';

  @override
  String get cancelAppointmentTitle => 'Cancel Appointment?';

  @override
  String get cancelAppointmentConfirmation =>
      'Are you sure you want to cancel this appointment?';

  @override
  String get keepAppointmentButton => 'Keep Appointment';

  @override
  String get appointmentCancelled => 'Appointment cancelled';

  @override
  String get cancellationNotAllowed =>
      'Cancellation is not allowed for this appointment.';

  @override
  String get cancelAppointmentFailed =>
      'Could not cancel appointment. Please try again.';

  @override
  String get selectService => 'Select Service';

  @override
  String get selectPet => 'Select Pet';

  @override
  String get dateAndTime => 'Date & Time';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get selectDate => 'Select Date';

  @override
  String get selectTime => 'Select Time';

  @override
  String get appointmentNoteHint => 'Add a note for the clinic...';

  @override
  String get requestAppointment => 'Request Appointment';

  @override
  String get requestSentTitle => 'Request Sent 🐾';

  @override
  String get requestSentMessage =>
      'Your appointment request has been sent to the clinic.';

  @override
  String get okButton => 'OK';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get alreadyBookedAtThisTime =>
      'You already have a booking at this time. Please choose another time.';

  @override
  String get invalidBookingData => 'Invalid booking data. Please try again.';

  @override
  String get serviceDefaultLabel => 'Service';

  @override
  String get ageYearsSuffix => ' years';

  @override
  String get overviewTitle => 'Overview';

  @override
  String get servicesTitle => 'Services';

  @override
  String get reviewsTitle => 'Reviews';

  @override
  String get galleryTitle => 'Gallery';

  @override
  String get shopTitle => 'Shop';

  @override
  String get aboutTitle => 'About';

  @override
  String get workingHoursTitle => 'Working Hours';

  @override
  String get locationTitle => 'Location';

  @override
  String get instagramTitle => 'Instagram';

  @override
  String get noClinicDescriptionAvailable => 'No clinic description available.';

  @override
  String get instagramNotAvailable => 'Instagram not available.';

  @override
  String get workingHoursNotAvailable => 'Working hours not available';

  @override
  String get openStatusOpen => 'Open';

  @override
  String get openStatusClosingSoon => 'Closing soon';

  @override
  String get openStatusClosed => 'Closed';

  @override
  String get mostRelevant => 'Most relevant';

  @override
  String get newest => 'Newest';

  @override
  String get bookAppointment => 'Book Appointment';

  @override
  String get noServicesAvailable => 'No services available';

  @override
  String errorLoadingServices(Object error) {
    return 'Error loading services: $error';
  }

  @override
  String get noServicesProvided => 'No services provided.';

  @override
  String reviewsCountLabel(Object count) {
    return '$count reviews';
  }

  @override
  String get topLabel => 'Top';

  @override
  String get mostHelpful => 'Most helpful';

  @override
  String get couldNotUpdateLike => 'Could not update like';

  @override
  String get justNow => 'Just now';

  @override
  String get noReviewsYet => 'No reviews yet';

  @override
  String get beFirstToReview => 'Be the first to review';

  @override
  String get submit => 'Submit';

  @override
  String get writeAReview => 'Write a review';

  @override
  String get shareYourExperienceHint => 'Share your experience...';

  @override
  String get pleaseWriteSomething => 'Please write something';

  @override
  String get pleaseLoginFirst => 'Please login first';

  @override
  String get alreadyReviewedThisVet => 'You already reviewed this vet';

  @override
  String get errorSubmittingReview => 'Error submitting review';

  @override
  String errorLoadingReviews(Object error) {
    return 'Error loading reviews: $error';
  }

  @override
  String get galleryNotAvailable => 'Gallery not available.';

  @override
  String get noGalleryMediaYet => 'No gallery media yet.';

  @override
  String get shopSectionComingSoon => 'Shop section will be connected here.';

  @override
  String durationMinutesShort(Object minutes) {
    return '$minutes min';
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
  String get usernameLabel => 'Username';

  @override
  String get emailLabel => 'Email';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get enterPhoneNumberOptional => 'Enter phone number (optional)';

  @override
  String get deleteAccount => 'Delete Account';

  @override
  String get deleteAccountConfirmation =>
      'Are you sure you want to delete your account? This action cannot be undone.';

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
  String get appTitle => 'PetSupo';

  @override
  String get loadingUserData => 'Loading user data...';

  @override
  String get welcomeToPetSopu => 'Welcome to PetSopu!';

  @override
  String get welcomeTo => 'Welcome to';

  @override
  String get petSopu => 'PetSopu';

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
  String get termsAndConditionsPrefix => 'I accept the ';

  @override
  String get termsAndConditionsText => 'Terms and Conditions';

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
  String get phoneNumberTooShort => 'Phone number is too short';

  @override
  String get phoneMinDigits => 'Phone number must be at least 10 digits';

  @override
  String get passwordRequired => 'Please enter your password';

  @override
  String get passwordValidation =>
      'Password must be at least 8 characters, including both letters and numbers';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get confirmPasswordRequired => 'Please confirm your password';

  @override
  String get termsRequired => 'You must agree to the Terms and Conditions';

  @override
  String get forgotPasswordDialogTitle => 'Forgot Password';

  @override
  String get forgotPasswordDialogMessage =>
      'Please enter your email to reset your password.';

  @override
  String get sendButton => 'Send';

  @override
  String passwordResetSent(Object email) {
    return 'Password reset email sent to $email';
  }

  @override
  String get emailAddressHint => 'Email address';

  @override
  String get passwordResetEmailSent => 'Password reset email sent 📩';

  @override
  String get noAccountSignUp => 'Don’t have an account? Sign Up';

  @override
  String get haveAccountSignIn => 'Already have an account? Sign In';

  @override
  String get userNotFound => 'No user found with this email. Please register.';

  @override
  String get authUserNotFound => 'User not found';

  @override
  String get pleaseVerifyEmailBeforeSigningIn =>
      'Please verify your email before signing in.';

  @override
  String get userCreationFailed => 'User creation failed';

  @override
  String get verificationEmailCouldNotBeSent =>
      'Verification email could not be sent';

  @override
  String get verificationSessionCouldNotBeCreated =>
      'Verification session could not be created';

  @override
  String get emailAlreadyRegisteredTryLoggingIn =>
      'This email is already registered. Try logging in.';

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
  String get enterVerificationCodeSentToEmail =>
      'Enter the verification code sent to your email';

  @override
  String get pleaseEnterSixDigitCode => 'Please enter the 6-digit code';

  @override
  String get emailVerifiedSuccessfully => 'Email verified successfully';

  @override
  String get invalidVerificationCode => 'Invalid verification code';

  @override
  String verificationCodeSent(Object email) {
    return 'A verification code has been sent to $email';
  }

  @override
  String get enterCodeLabel => 'Enter 6-digit Code';

  @override
  String get verifyButton => 'Verify';

  @override
  String get authWelcomeBackSubtitle => 'Welcome back to BarkyMatches';

  @override
  String get authCreateAccountSubtitle => 'Create your BarkyMatches account';

  @override
  String get sessionExpiredPleaseSignInAgain =>
      'Your session expired. Please sign in again.';

  @override
  String get signInToAccessPlaymate => 'Please Sign In to access Playmate';

  @override
  String get findPlaymates => 'Find Playmates';

  @override
  String get signInToFindFriends => 'Find friends for your pet';

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
  String get photosLabel => 'Photos';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get noMedia => 'No media';

  @override
  String get save => 'Save';

  @override
  String dogNameAlreadyExists(Object name) {
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
  String get pleaseFillRequiredFields =>
      'Please fill all required fields correctly';

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
  String get editDogPermissionDenied =>
      'You do not have permission to edit this dog.';

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
  String get adjustFiltersSuggestion =>
      'Try adjusting your filters or increasing the distance.';

  @override
  String get anyGender => 'Any';

  @override
  String distanceLabel(Object distance) {
    return 'Distance: $distance km';
  }

  @override
  String get resetFiltersButton => 'Reset Filters';

  @override
  String get basketTitle => 'Basket';

  @override
  String basketItemsCount(Object count) {
    return '$count items';
  }

  @override
  String get yourBasketIsEmpty => 'Your basket is empty';

  @override
  String get sellerLabel => 'Seller';

  @override
  String get allProductsTitle => 'All Products';

  @override
  String get sellerProductsTitle => 'Seller Products';

  @override
  String get searchProductsHint => 'Search product, brand, seller...';

  @override
  String get allCategoriesLabel => 'All Categories';

  @override
  String get categoryLabel => 'Category';

  @override
  String get shippingLabel => 'Shipping';

  @override
  String get freeShippingLabel => 'Free shipping';

  @override
  String get sellerPaysCargoLabel => 'Seller pays cargo';

  @override
  String get fixedCargoLabel => 'Fixed cargo';

  @override
  String get calculatedCargoLabel => 'Calculated cargo';

  @override
  String get sortLabel => 'Sort';

  @override
  String get recommendedLabel => 'Recommended';

  @override
  String get priceLowLabel => 'Price low';

  @override
  String get priceHighLabel => 'Price high';

  @override
  String get bestDiscountLabel => 'Best discount';

  @override
  String productsCount(Object count) {
    return '$count products';
  }

  @override
  String get noProductsMatchFilters => 'No products match your filters';

  @override
  String errorLoadingProducts(Object error) {
    return 'Error loading products: $error';
  }

  @override
  String get noActiveProductsFound => 'No active products found';

  @override
  String addedToBasket(Object productName) {
    return '$productName added to basket';
  }

  @override
  String get addButton => 'Add';

  @override
  String get freeCargoLabel => 'Free cargo';

  @override
  String cargoPriceLabel(Object price) {
    return 'Cargo $price';
  }

  @override
  String get cargoCalculatedLabel => 'Cargo calculated';

  @override
  String freeOverLabel(Object price) {
    return 'Free over $price';
  }

  @override
  String vatRateLabel(Object percent) {
    return 'VAT $percent%';
  }

  @override
  String get vatIncludedLabel => 'VAT included';

  @override
  String daysLabel(Object days) {
    return '$days days';
  }

  @override
  String get inStockLabel => 'In stock';

  @override
  String get outOfStockLabel => 'Out';

  @override
  String get subtotalLabel => 'Subtotal';

  @override
  String get moreFiltersButton => 'More Filters';

  @override
  String get petTypeLabel => 'Pet Type';

  @override
  String get petTypeDog => 'Dog';

  @override
  String get petTypeCat => 'Cat';

  @override
  String get petTypeBird => 'Bird';

  @override
  String get petTypeHorse => 'Horse';

  @override
  String get genderOther => 'Other';

  @override
  String get breedPersian => 'Persian';

  @override
  String get breedSiamese => 'Siamese';

  @override
  String get breedMaineCoon => 'Maine Coon';

  @override
  String get breedBritishShorthair => 'British Shorthair';

  @override
  String get breedParrot => 'Parrot';

  @override
  String get breedCanary => 'Canary';

  @override
  String get breedBudgerigar => 'Budgerigar';

  @override
  String get breedArabian => 'Arabian';

  @override
  String get breedThoroughbred => 'Thoroughbred';

  @override
  String get breedMustang => 'Mustang';

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
  String get upgradeToPremiumForMoreFilters =>
      'Upgrade to Premium for more filters!';

  @override
  String get upgradeToPremiumTitle => 'Upgrade to Premium';

  @override
  String get upgradeToPremiumSubtitle =>
      'Unlock advanced features and business tools';

  @override
  String get apply => 'Apply';

  @override
  String get favoritesPageTitle => 'Favorite Dogs';

  @override
  String get noFavoriteDogsYet => 'No favorite dogs yet!';

  @override
  String get addFavoriteSuggestion =>
      'Go back to the home page and add some dogs to your favorites.';

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
  String get pleaseLoginToSchedulePlaydate =>
      'Please log in to schedule a playdate';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get enterLocation =>
      'Enter location (e.g., Latitude: 41.0103, Longitude: 28.6724 or address)';

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
  String get playdateRequestTitle => 'Playdate Request';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog wants to play with $requestedDog!';
  }

  @override
  String playdateRequestNotificationBody(
    Object requesterDog,
    Object requestedDog,
  ) {
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
  String get newPlaydateRequestTitle => 'New Playdate Request!';

  @override
  String newPlaydateRequestBody(Object requesterDog, Object requestedDog) {
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
  String get requestAcceptedSuccess =>
      'Request accepted and added to playdates list.';

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
  String get failedToScheduleReminder =>
      'Failed to schedule reminder. Check permissions.';

  @override
  String get scheduledLabel => 'Scheduled:';

  @override
  String get pleaseLoginToViewPlaydateRequests =>
      'Login to view playdate requests';

  @override
  String get pleaseLoginToSetReminders => 'Please login to set reminders.';

  @override
  String reminderSetForMinutesBefore(Object minutesBefore) {
    return 'Reminder set for $minutesBefore minutes before 🐾';
  }

  @override
  String get failedToSetReminder => 'Failed to set reminder ❌';

  @override
  String get playdateAcceptedCardTitle => 'Playdate Accepted 🐾';

  @override
  String playdateAcceptedCardBody(Object dogName) {
    return '$dogName accepted your playdate request.\nBe happy — a tail-wagging meeting awaits! 🐶💖';
  }

  @override
  String get playdateRejectedCardTitle => 'Playdate Not This Time';

  @override
  String playdateRejectedCardBody(Object dogName) {
    return '$dogName couldn’t accept this time.\nNo worries — try again and keep the paws moving 🐾';
  }

  @override
  String get dogTab => 'Dog';

  @override
  String get reminderTab => 'Reminder';

  @override
  String get playdateTimeNotScheduledYet => '⏳ Playdate time not scheduled yet';

  @override
  String get thirtyMinutesBefore => '30 minutes before';

  @override
  String get oneHourBefore => '1 hour before';

  @override
  String get reminderSet => 'Reminder set ✅';

  @override
  String get viewLocation => 'View location';

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
  String get playmateSearchHint => 'Search dogs...';

  @override
  String get playmateLocationNeededTitle => 'Location needed';

  @override
  String get playmateLocationNeededMessage =>
      'We use your location to show nearby dogs';

  @override
  String get playmateFiltersTitle => 'Filters';

  @override
  String get playmateBreedPremiumHint => 'Breed (Gold)';

  @override
  String get playmateOwnerGenderPremiumHint => 'Owner Gender (Premium)';

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
  String get dogParkTitle => 'Dog Park';

  @override
  String dogParkDateLabel(Object date) {
    return 'Date: $date';
  }

  @override
  String get dogParkLoadMarkers => 'Load Park Markers';

  @override
  String get dogParkMoveToMarkers => 'Move to Markers';

  @override
  String get dogParkPermissionDenied =>
      'Location permission denied. Please enable it in settings.';

  @override
  String get dogParkBackgroundPermissionDenied =>
      'Background location permission denied. Some features may be limited.';

  @override
  String get dogParkLocationServicesDisabled =>
      'Location services are disabled.';

  @override
  String get dogParkEnableLocationServices =>
      'Please enable location services to continue.';

  @override
  String get dogParkPermissionDeniedPermanent =>
      'Location permission permanently denied.';

  @override
  String get dogParkPermissionsDenied =>
      'Location permissions are permanently denied. Please enable them from settings.';

  @override
  String dogParkLocationError(Object error) {
    return 'Error getting location: $error';
  }

  @override
  String get dogParkPermissionRequired =>
      'Location permission is required to show nearby dog parks.';

  @override
  String get dogParkRecommendedBadge => '⭐ Recommended';

  @override
  String get dogParkPremiumBadge => '🔒 Premium';

  @override
  String get dogParkSavedBadge => '❤️ Saved';

  @override
  String get dogParkRecommendedForPlaydates => 'Recommended for Playdates';

  @override
  String get dogParkSavedToFavorites => 'Saved to Favorites';

  @override
  String get dogParkSaveThisPark => 'Save this Park';

  @override
  String get dogParkGetDirections => 'Get Directions';

  @override
  String get dogParkUserNotReadyYet => 'User not ready yet. Please try again.';

  @override
  String get dogParkNeedToAddDogFirst => 'You need to add a dog first';

  @override
  String get dogParkSchedulePlaydateHere => 'Schedule Playdate here';

  @override
  String get dogParkSavedParksTitle => 'Saved Parks';

  @override
  String get dogParkNoSavedParksYet => 'No saved parks yet';

  @override
  String get dogParkFindNearbyParks => 'Find nearby parks';

  @override
  String get dogParkLocationNeededTitle => 'Location needed';

  @override
  String get dogParkUseYourLocationToShowNearbyDogParks =>
      'We use your location to show nearby dog parks';

  @override
  String get allowButton => 'Allow';

  @override
  String get dogParkBackgroundRecommended =>
      'Background location permission is recommended. Please enable it in settings.';

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
  String dogViewPlayDateScheduled(
    Object day,
    Object month,
    Object year,
    Object time,
  ) {
    return 'Play date scheduled for $day/$month/$year at $time!';
  }

  @override
  String get dogViewAdoptionRequest => 'Adoption request sent!';

  @override
  String get distanceUnknown => 'Distance unknown';

  @override
  String boostDogTitle(Object dogName) {
    return 'Boost $dogName';
  }

  @override
  String get boostVisibilityDescription =>
      'Get more visibility in Playmates discovery.';

  @override
  String get boost24HoursTitle => '24 Hours Boost';

  @override
  String get boostQuickVisibilitySubtitle => 'Good for quick visibility';

  @override
  String get boostPrice29 => '₺29';

  @override
  String get boost3DaysTitle => '3 Days Boost';

  @override
  String get boostBetterExposureSubtitle =>
      'Better exposure for active discovery';

  @override
  String get boostPrice69 => '₺69';

  @override
  String get boost7DaysTitle => '7 Days Boost';

  @override
  String get boostBestValueSubtitle => 'Best value for maximum reach';

  @override
  String get boostPrice129 => '₺129';

  @override
  String get boostActivated => 'Boost activated 🚀';

  @override
  String boostFailed(Object error) {
    return 'Boost failed: $error';
  }

  @override
  String get errorOpeningEdit => 'Error opening edit';

  @override
  String get boostBadge => 'BOOSTED';

  @override
  String get boostButton => 'Boost';

  @override
  String get blockComingSoon => 'Block coming soon';

  @override
  String get blockMenuItem => 'Block User';

  @override
  String get sendAdoptionRequest => 'Send Adoption Request';

  @override
  String ownerPrefix(Object owner) {
    return 'Owner: $owner';
  }

  @override
  String get submitComplaintMenuItem => 'Submit Complaint';

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
  String get locationServicesDisabled =>
      'Location services are disabled. Using default location.';

  @override
  String get locationPermissionRequired =>
      'Location permission is required. Using default location.';

  @override
  String get locationPermissionPermanentlyDenied =>
      'Location permission is permanently denied. Using default location.';

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
  String get notificationChannelDescription =>
      'This channel is used for important notifications.';

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
  String get noDogFoundForAccount =>
      'No dog found for your account. Please add a dog first.';

  @override
  String get pleaseSelectYourDog => 'Please select one of your dogs';

  @override
  String get cannotScheduleWithOwnDog =>
      'You cannot schedule a playdate with your own dog.';

  @override
  String get cannotScheduleWithTempUser =>
      'Cannot schedule a playdate with a temporary user.';

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
  String get pleaseSelectDogForPlaydate =>
      'Please select one of your dogs for playdate';

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
  String get playdateSchedulingSubtitle =>
      'Pick date, time, location and dogs for the playdate.';

  @override
  String get errorSelectDateAndTime => 'Please select date and time.';

  @override
  String get errorMissingLocationCoordinates =>
      'Park location coordinates missing.';

  @override
  String get errorPlaydateLeadTime =>
      'Playdate must be scheduled at least 15 minutes in advance.';

  @override
  String get playdateTimeConflict =>
      'This dog already has a playdate around this time 🐾';

  @override
  String coordinatesLatLng(Object lat, Object lng) {
    return 'Lat: $lat, Lng: $lng';
  }

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

  @override
  String get offerHotDeal => '🔥 Hot Deal';

  @override
  String get offerPremiumBadge => 'Premium';

  @override
  String get offerFallbackTitle => 'Special offer for Barky users';

  @override
  String get offerFallbackProvider => 'Partner brand';

  @override
  String get offerUnlock => 'Unlock';

  @override
  String get offerView => 'View';

  @override
  String offerDiscountPercent(Object discount) {
    return '$discount% OFF';
  }

  @override
  String get offerPremiumRequiredTitle => 'Premium Required';

  @override
  String get offerPremiumRequiredMessage =>
      'This offer is only for premium members.';

  @override
  String get offerCancel => 'Cancel';

  @override
  String get offerUpgrade => 'Upgrade';

  @override
  String get offerUnlockingMessage => 'Unlocking your deal...';

  @override
  String get offerChooseContinueTitle => 'Choose where to continue';

  @override
  String get offerChooseContinueSubtitle =>
      'Pick your preferred contact option for this offer.';

  @override
  String get offerOpenWebsite => 'Open Website';

  @override
  String get offerInstagram => 'Instagram';

  @override
  String get playdatesTitle => 'Playdates';

  @override
  String get manageRequests => 'Manage requests';

  @override
  String get adoptionTitle => 'Adoption';

  @override
  String get giveLove => 'Give love';

  @override
  String get alertsTitle => 'Alerts';

  @override
  String get lostAndFound => 'Lost & Found';

  @override
  String get vetTitle => 'Vet';

  @override
  String get nearbyClinics => 'Nearby clinics';

  @override
  String get groomyTitle => 'Groomy';

  @override
  String get bookGrooming => 'Book grooming';

  @override
  String get petShopTitle => 'Pet Shop';

  @override
  String get shopNearYou => 'Shop near you';

  @override
  String get featuredDeal => 'Featured Deal';

  @override
  String get premiumLabel => 'Premium';

  @override
  String get goldLabel => 'Gold';

  @override
  String discountOff(Object percent) {
    return '$percent% OFF';
  }

  @override
  String get socialAndPlay => 'Social & Play';

  @override
  String get careAndServices => 'Care & Services';

  @override
  String get outdoorAndLifestyle => 'Outdoor & Lifestyle';

  @override
  String get exploreNearbyParks => 'Explore nearby parks';

  @override
  String get trainingTitle => 'Training';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get trainingComingSoonMessage => 'Training feature coming soon 🐾';

  @override
  String get communityHub => 'Community Hub';

  @override
  String activeCount(Object count) {
    return '$count active';
  }

  @override
  String get reportTitle => 'Report';

  @override
  String get lostDogTitle => 'Lost Dog';

  @override
  String get lostPetTitle => 'Lost Pet';

  @override
  String get foundDogTitle => 'Found Dog';

  @override
  String get foundPetTitle => 'Found Pet';

  @override
  String get lostTitle => 'Lost';

  @override
  String get dogsTitle => 'Dogs';

  @override
  String get petsTitle => 'Pets';

  @override
  String get foundTitle => 'Found';

  @override
  String get homeDefaultUsername => 'User';

  @override
  String get homePetHotelTitle => 'Pet Hotel';

  @override
  String get homeSafeStaySubtitle => 'Safe stay';

  @override
  String get homePetTaxiTitle => 'Pet Taxi';

  @override
  String get homeRideSafelySubtitle => 'Ride safely';

  @override
  String get homeGreenMemorialTitle => 'Green Memorial';

  @override
  String get homeVeterinaryTitle => 'Veterinary';

  @override
  String get homeLocationNeededTitle => 'Location needed';

  @override
  String get homeLocationNeededMessage =>
      'We use your location to show nearby vets';

  @override
  String get homeAllowButton => 'Allow';

  @override
  String get homeBusinessesTitle => 'Businesses';

  @override
  String get homeSearchHint => 'Search services, shops, community...';

  @override
  String get homePetFriendlyPlaceTitle => 'Pet Friendly Place';

  @override
  String get homeSponsoredLabel => 'Sponsored';

  @override
  String get homeShopButton => 'Shop';

  @override
  String get petShopDealName => 'Pet Shop A';

  @override
  String get petShopDealDesc => '15% OFF on all food';

  @override
  String get groomyDealName => 'Groomy Studio';

  @override
  String get groomyDealDesc => '20% OFF grooming this week';

  @override
  String get vetDealName => 'VetPlus';

  @override
  String get vetDealDesc => 'Gold members: free checkup';

  @override
  String get offerWhatsApp => 'WhatsApp';

  @override
  String offerCodeCopied(Object code) {
    return 'Code copied: $code';
  }

  @override
  String get offerOpenError => 'Error opening offer';

  @override
  String get businessRegisterLegalCompanyNameRequired =>
      '• Legal Company Name is required.';

  @override
  String get businessRegisterPublicDisplayNameRequired =>
      '• Public Display Name is required.';

  @override
  String get businessRegisterSelectCountry => '• Please select a Country.';

  @override
  String get businessRegisterSelectBusinessCategory =>
      '• Please select at least one business category.';

  @override
  String get businessRegisterEnterValidEmail =>
      '• Enter a valid email address (example: name@example.com).';

  @override
  String get businessRegisterPhoneIncomplete => '• Phone number is incomplete.';

  @override
  String get businessRegisterSelectCityProvince =>
      '• Please select City / Province.';

  @override
  String get businessRegisterSelectDistrict => '• Please select District.';

  @override
  String get businessRegisterBusinessAddressRequired =>
      '• Business Address is required.';

  @override
  String get businessRegisterAllLegalDocumentsRequired =>
      '• All required legal documents must be uploaded.';

  @override
  String get businessRegisterDocumentsVerifiedBeforeContinuing =>
      '• Documents must be verified before continuing.';

  @override
  String get businessRegisterAcceptPlatformTerms =>
      '• You must accept the Platform Terms.';

  @override
  String get businessRegisterAcceptLegalResponsibility =>
      '• You must accept legal responsibility declaration.';

  @override
  String get businessRegisterFixHighlightedFields =>
      'Please fix the highlighted fields';

  @override
  String get businessRegisterOk => 'OK';

  @override
  String get businessRegisterFailedToLoadCountries =>
      'Failed to load countries';

  @override
  String get businessRegisterFailedToLoadCities => 'Failed to load cities';

  @override
  String get businessRegisterFailedToLoadDistricts =>
      'Failed to load districts';

  @override
  String get businessRegisterPlatformLegalAgreement =>
      'Platform Legal Agreement';

  @override
  String get businessRegisterReadAndAccept => 'I Have Read and Accept';

  @override
  String get businessRegisterLocationPermissionDenied =>
      'Location permission denied';

  @override
  String get businessRegisterCouldNotDetectCity => 'Could not detect city';

  @override
  String get businessRegisterGroomer => 'Groomer';

  @override
  String get businessRegisterVeterinaryClinic => 'Veterinary Clinic';

  @override
  String get businessRegisterDogTrainer => 'Dog Trainer';

  @override
  String get businessRegisterPetHotel => 'Pet Hotel';

  @override
  String get businessRegisterDogWalker => 'Dog Walker';

  @override
  String get businessRegisterBreeder => 'Breeder';

  @override
  String get businessRegisterInvalidEmail => 'Invalid email';

  @override
  String get businessRegisterInvalidPhone => 'Invalid phone';

  @override
  String get businessRegisterInvalidWebsite => 'Invalid website';

  @override
  String get businessRegisterCouldNotOpenLegalText =>
      'Could not open legal text';

  @override
  String get businessRegisterSelectAtLeastOneBusinessCategory =>
      'Please select at least one business category';

  @override
  String get businessRegisterPleaseEnterBusinessAddress =>
      'Please enter business address';

  @override
  String get businessRegisterMustAcceptAllAgreements =>
      'You must accept all agreements';

  @override
  String get businessRegisterDocumentsVerifiedBeforeSubmission =>
      'Documents must be verified before submission';

  @override
  String get businessRegisterApplicationSubmittedSuccessfully =>
      'Application submitted successfully';

  @override
  String get businessRegisterSubmissionFailed => 'Submission failed';

  @override
  String get businessRegisterUnexpectedErrorOccurred =>
      'Unexpected error occurred';

  @override
  String get businessRegisterTitle => 'Register Business';

  @override
  String get businessRegisterStepIdentityCategories =>
      'Business identity and categories';

  @override
  String get businessRegisterStepContactLocation => 'Contact and location';

  @override
  String get businessRegisterStepLegalDocuments => 'Legal documents';

  @override
  String get businessRegisterStepAgreementConfirmation =>
      'Agreement confirmation';

  @override
  String get businessRegisterBack => 'Back';

  @override
  String get businessRegisterContinue => 'Continue';

  @override
  String get businessRegisterSubmitApplication => 'Submit Application';

  @override
  String get businessRegisterCompleteSectorDetails => 'Complete Sector Details';

  @override
  String get businessRegisterBusinessIdentity => 'Business identity';

  @override
  String get businessRegisterBusinessIdentitySubtitle =>
      'Tell us how your business should appear on PetSupo.';

  @override
  String get businessRegisterLegalCompanyName => 'Legal Company Name';

  @override
  String get businessRegisterRequired => 'Required';

  @override
  String get businessRegisterPublicDisplayName => 'Public Display Name';

  @override
  String get businessRegisterCountry => 'Country';

  @override
  String get businessRegisterBusinessCategories => 'Business categories';

  @override
  String get businessRegisterBusinessCategoriesSubtitle =>
      'Select all sectors this business operates in.';

  @override
  String get businessRegisterContactLocation => 'Contact & location';

  @override
  String get businessRegisterContactLocationSubtitle =>
      'These details help customers find and contact you.';

  @override
  String get businessRegisterPhone => 'Phone';

  @override
  String get businessRegisterWebsiteOptional => 'Website (optional)';

  @override
  String get businessRegisterLoadingCities => 'Loading cities...';

  @override
  String get businessRegisterCityProvince => 'City / Province';

  @override
  String get businessRegisterLoadingDistricts => 'Loading districts...';

  @override
  String get businessRegisterDistrict => 'District';

  @override
  String get businessRegisterBusinessAddress => 'Business Address';

  @override
  String get businessRegisterDetectCity => 'Detect City';

  @override
  String get businessRegisterMapPickerComingSoon =>
      'Map picker will be added soon';

  @override
  String get businessRegisterPickLocation => 'Pick Location';

  @override
  String get businessRegisterLocationSelected => 'Location selected';

  @override
  String get businessRegisterTaxPlate => 'Vergi Levhası (Tax Plate)';

  @override
  String get businessRegisterTradeRegistryGazette => 'Ticaret Sicil Gazetesi';

  @override
  String get businessRegisterAuthorizedSignatureDocument =>
      'Yetkili İmza Belgesi';

  @override
  String get businessRegisterTaxNumberVkn => 'Tax Number (VKN)';

  @override
  String get businessRegisterAutoFilledFromDocument =>
      'Auto-filled from document';

  @override
  String get businessRegisterDocumentVerificationInconsistencies =>
      'Document verification has inconsistencies. Admin review required.';

  @override
  String get businessRegisterMersisNumber => 'MERSIS Number';

  @override
  String get businessRegisterDocumentsSecurelyEncrypted =>
      'Your documents are securely encrypted and verified automatically';

  @override
  String get businessRegisterVerifiedFromDocument => 'Verified from document';

  @override
  String get businessRegisterAutoFilledAfterVerification =>
      'Auto-filled after document verification';

  @override
  String get businessRegisterUploadTradeRegistryFirst =>
      'Upload Trade Registry first';

  @override
  String get businessRegisterWaitingForDocumentVerification =>
      'Waiting for document verification...';

  @override
  String get businessRegisterSteuernummer => 'Steuernummer';

  @override
  String get businessRegisterTaxNumberRequired => 'Tax Number is required';

  @override
  String get businessRegisterGewerbeschein => 'Gewerbeschein';

  @override
  String get businessRegisterHandelsregisterauszug => 'Handelsregisterauszug';

  @override
  String get businessRegisterEinNumber => 'EIN Number';

  @override
  String get businessRegisterEinNumberRequired => 'EIN Number is required';

  @override
  String get businessRegisterBusinessLicense => 'Business License';

  @override
  String get businessRegisterIrsEinDocument => 'IRS EIN Document';

  @override
  String get businessRegisterProcessingDocument => 'Processing document...';

  @override
  String get businessRegisterDocumentVerifiedSuccessfully =>
      'Document verified successfully';

  @override
  String get businessRegisterCouldNotReadDocument =>
      'Could not read document, please re-upload';

  @override
  String get businessRegisterVeterinary => 'Veterinary';

  @override
  String get businessRegisterGroomy => 'Groomy';

  @override
  String businessRegisterStepOfFour(Object step) {
    return 'Step $step of 4';
  }

  @override
  String get businessRegisterLegalConfirmation => 'Legal Confirmation';

  @override
  String get businessRegisterAcceptTermsKvkk =>
      'I accept the Platform Terms and KVKK Data Protection Policy.';

  @override
  String get businessRegisterReadInsideApp => 'Read inside app';

  @override
  String get businessRegisterOpenOfficialLegalPage =>
      'Open official legal page';

  @override
  String get businessRegisterLegalVersion =>
      'Version v1.0 • Last updated May 2026';

  @override
  String get businessRegisterAgreementSecurelyStored =>
      'Your agreement is securely stored and legally binding';

  @override
  String get businessRegisterLegalResponsibilityDeclaration =>
      'I declare that all submitted documents are accurate and I accept full legal responsibility under Turkish Commercial Law.';

  @override
  String get businessRegisterUploaded => 'Uploaded';

  @override
  String get businessRegisterReplaceDocument => 'Replace document';

  @override
  String get businessRegisterReplaceDocumentConfirmation =>
      'Are you sure you want to replace this file?';

  @override
  String get businessRegisterReplace => 'Replace';

  @override
  String get businessRegisterUpload => 'Upload';

  @override
  String userProfileInitError(Object error) {
    return 'Profile init error: $error';
  }

  @override
  String userProfileImagePickError(Object error) {
    return 'Error selecting photo: $error';
  }

  @override
  String get userProfileUnknownBusinessType => 'Unknown business type';

  @override
  String get userProfileBusinessDashboard => 'Business Dashboard';

  @override
  String get userProfileActivity => 'Activity';

  @override
  String get userProfileSavedParks => 'Saved Parks';

  @override
  String get userProfileMatches => 'Matches';

  @override
  String get userProfileMyOrders => 'My Orders';

  @override
  String get myAppointments => 'My Appointments';

  @override
  String get myAppointmentsLoginRequired =>
      'Please log in to view your appointments';

  @override
  String get appointmentHistory => 'Appointment History';

  @override
  String get noAppointmentsYet => 'No appointments yet';

  @override
  String get viewAppointment => 'View Appointment';

  @override
  String get appointmentStatusPending => 'Pending';

  @override
  String get appointmentStatusAwaitingPayment => 'Awaiting Payment';

  @override
  String get appointmentStatusConfirmed => 'Confirmed';

  @override
  String get appointmentStatusConfirmedPaid => 'Confirmed & Paid';

  @override
  String get appointmentStatusPaymentExpired => 'Payment Expired';

  @override
  String get appointmentStatusRejected => 'Rejected';

  @override
  String get appointmentStatusCompleted => 'Completed';

  @override
  String get appointmentStatusCancelledByUser => 'Cancelled by you';

  @override
  String get appointmentStatusCancelledByVet => 'Cancelled by vet';

  @override
  String get appointmentStatusExpired => 'Expired';

  @override
  String get unpaidStatusLabel => 'Unpaid';

  @override
  String get paymentNotRequiredStatusLabel => 'No payment required';

  @override
  String get refundUnderReviewStatusLabel => 'Refund under review';

  @override
  String get refundRequestedStatusLabel => 'Refund requested';

  @override
  String get refundCompletedStatusLabel => 'Refund completed';

  @override
  String get refundFailedStatusLabel => 'Refund failed';

  @override
  String get noRefundRequiredStatusLabel => 'No refund required';

  @override
  String get refundNotProcessedStatusLabel => 'Refund not processed yet';

  @override
  String get veterinaryClinicFallback => 'Vet clinic';

  @override
  String get veterinaryServiceFallback => 'Veterinary service';

  @override
  String get petFallback => 'Pet';

  @override
  String get dogTypeLabel => 'dog';

  @override
  String get userProfileAdoptionRequests => 'Adoption Requests';

  @override
  String get userProfileBusiness => 'Business';

  @override
  String get userProfileAdmin => 'Admin';

  @override
  String get userProfileSupport => 'Support';

  @override
  String get userProfileSendFeedback => 'Send Feedback';

  @override
  String get userProfileHelpCenter => 'Help Center';

  @override
  String get userProfilePrivacy => 'Privacy';

  @override
  String get userProfileReportProblem => 'Report Problem';

  @override
  String get userProfileSubscriptionPlans => 'Subscription & Plans';

  @override
  String get userProfileLanguage => 'Language';

  @override
  String get userProfileTheme => 'Theme';

  @override
  String get userProfileChangePassword => 'Change Password';

  @override
  String get userProfileGuestTitle => 'You\'re browsing as Guest';

  @override
  String get userProfileGuestSubtitle => 'Login to unlock full features';

  @override
  String get userProfileLoginSignUp => 'Login / Sign Up';

  @override
  String get userProfileLanguageEnglish => 'English';

  @override
  String get userProfileLanguagePersian => 'Persian';

  @override
  String get userProfileLanguageTurkish => 'Turkish';

  @override
  String get userProfileUnlockBusinessFeatures => 'Unlock Business Features 🚀';

  @override
  String get userProfileUpgradeBusinessDescription =>
      'Upgrade to Gold to register your business and start receiving customers.';

  @override
  String get userProfileUpgradeToGold => 'Upgrade to Gold';

  @override
  String get userProfileManageAdoptionCenter => 'Manage Adoption Center';

  @override
  String get userProfileOverview => 'Overview';

  @override
  String get userProfileDogs => 'Dogs';

  @override
  String get userProfileRequests => 'Requests';

  @override
  String get userProfileOverviewSection => 'Overview Section';

  @override
  String get userProfileDogsSection => 'Dogs Section';

  @override
  String get userProfileRequestsSection => 'Requests Section';

  @override
  String get userProfileSettingsSection => 'Settings Section';

  @override
  String get userProfileApplicationUnderReview => 'Application Under Review';

  @override
  String get userProfileApplicationUnderReviewDescription =>
      'Your business request has been submitted successfully and is currently under review.';

  @override
  String get userProfileAdminPanel => 'Admin Panel';

  @override
  String get userProfileManageBusinessCenter => 'Manage Business Center';

  @override
  String get userProfileApplicationRejected => 'Application Rejected';

  @override
  String userProfileRejectionReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get userProfileUpgradeToGoldToContinue =>
      'Upgrade to Gold to continue';

  @override
  String get userProfileReApply => 'Re-Apply';

  @override
  String get userProfileBusinessStatus => 'Business Status';

  @override
  String get userProfileUnknownStatus => 'Unknown';

  @override
  String get userProfileChooseFromGallery => 'Choose from Gallery';

  @override
  String get userProfileRemovePhoto => 'Remove Photo';

  @override
  String get userProfileImageSelectionFailed => 'Image selection failed.';

  @override
  String get userProfileUsernameMinLength =>
      'Username must be at least 3 characters';

  @override
  String get userProfileUsernameMaxLength =>
      'Username must be at most 20 characters';

  @override
  String get userProfileUsernameNoSpaces => 'Username cannot contain spaces';

  @override
  String get userProfilePhoneInvalidCharacters =>
      'Phone contains invalid characters';

  @override
  String get userProfileBioMaxLength => 'Bio must be under 150 characters';

  @override
  String get userProfileUsernameAlreadyTaken => 'Username already taken';

  @override
  String get userProfileEmailUpdateFailed => 'Email update failed';

  @override
  String get userProfileUpdateFailed => 'Failed to update profile.';

  @override
  String get userProfileChangePhoto => 'Change Photo';

  @override
  String get userProfileEnterUsername => 'Enter username';

  @override
  String get userProfileEnterEmail => 'Enter email';

  @override
  String get userProfileOptionalPhoneNumber => 'Optional phone number';

  @override
  String get userProfileBio => 'Bio';

  @override
  String get userProfileBioHint => 'Tell people a little about yourself';

  @override
  String get unnamedProduct => 'Unnamed Product';

  @override
  String barcodeLabel(Object barcode) {
    return 'Barcode: $barcode';
  }

  @override
  String skuLabel(Object sku) {
    return 'SKU: $sku';
  }

  @override
  String get dealBadge => '💸 Deal';

  @override
  String get lowStockBadge => '⚡ Low';

  @override
  String saveAmountLabel(Object amount) {
    return 'Save $amount';
  }

  @override
  String salePriceLabel(Object price) {
    return 'Sale: $price';
  }

  @override
  String stockLabel(Object stock) {
    return 'Stock: $stock';
  }

  @override
  String get addToCartButton => 'Add to Cart';

  @override
  String get buyNowButton => 'Buy Now';

  @override
  String get addedToCart => 'Added to cart';

  @override
  String get mediaNotReadyYet => 'Media not ready yet';

  @override
  String cargoLabel(Object price) {
    return 'Cargo: $price';
  }

  @override
  String carrierLabel(Object carrier) {
    return 'Carrier: $carrier';
  }

  @override
  String deliveryDaysRangeLabel(Object max, Object min) {
    return '$min-$max days';
  }

  @override
  String get businessNotFound => 'Business not found';

  @override
  String get sectorDashboardNotImplementedYet =>
      'This sector dashboard is not implemented yet';

  @override
  String get goBackButton => 'Go Back';

  @override
  String get backButton => 'Back';

  @override
  String get veterinaryDashboardTitle => 'Veterinary Dashboard';

  @override
  String get overviewTab => 'Overview';

  @override
  String get appointmentsTab => 'Appointments';

  @override
  String get shopProfileTitle => 'Shop Profile';

  @override
  String get noDescriptionYet => 'No description added yet.';

  @override
  String get noRevenueYet => 'No revenue yet';

  @override
  String get netRevenueLabel => 'Net Revenue';

  @override
  String get afterPlatformCommissionLabel => 'After platform commission';

  @override
  String get grossSalesLabel => 'Gross Sales';

  @override
  String get platformFeeLabel => 'Platform Fee';

  @override
  String get adjustmentsLabel => 'Adjustments';

  @override
  String get recentOrdersTitle => 'Recent Orders';

  @override
  String get latestOrdersSubtitle => 'Latest 5 orders';

  @override
  String get viewAllButton => 'View all';

  @override
  String get noDataLabel => 'No data';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String orderNumberLabel(Object number) {
    return 'Order #$number';
  }

  @override
  String itemsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# items',
      one: '# item',
    );
    return '$_temp0';
  }

  @override
  String trackingLabel(Object tracking) {
    return 'Tracking: $tracking';
  }

  @override
  String get trackShipmentButton => 'Track Shipment';

  @override
  String get catalogStrengthUnavailable => 'Catalog strength unavailable';

  @override
  String get catalogStrengthTitle => 'Catalog Strength';

  @override
  String get productsTitle => 'Products';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get lowStockLabel => 'Low Stock';

  @override
  String get strengthLabel => 'Strength';

  @override
  String get shippableLabel => 'Shippable';

  @override
  String get withKdvLabel => 'With KDV';

  @override
  String get noProductsYet => 'No products yet';

  @override
  String get kdvIncludedLabel => 'KDV included';

  @override
  String fromLabel(Object city) {
    return 'From $city';
  }

  @override
  String returnsLabel(Object days) {
    return 'Returns ${days}d';
  }

  @override
  String get pickupLabel => 'Pickup';

  @override
  String get sameDayLabel => 'Same day';

  @override
  String get offersTitle => 'Offers';

  @override
  String get createOfferButton => 'Create Offer';

  @override
  String get videoLabel => 'VIDEO';

  @override
  String get catalogStrengthWeakLabel => 'Weak';

  @override
  String get catalogStrengthAddItemsMessage =>
      'Add products, description, media, and stock to strengthen your catalog.';

  @override
  String get catalogStrengthWeakDetailsMessage =>
      'Your product details are still weak. Add more media, descriptions, and stock info.';

  @override
  String get catalogStrengthMediumLabel => 'Medium';

  @override
  String get catalogStrengthMediumMessage =>
      'Good start. Add richer descriptions and more product media to improve visibility.';

  @override
  String get catalogStrengthStrongLabel => 'Strong';

  @override
  String get catalogStrengthStrongMessage =>
      'Great catalog quality. Your listings look strong and complete.';

  @override
  String get shippingCalculatedLabel => 'Shipping calculated';

  @override
  String get fragileLabel => 'Fragile';

  @override
  String get oversizeLabel => 'Oversize';

  @override
  String originLabel(Object city) {
    return 'Origin: $city';
  }

  @override
  String carriersCountLabel(Object count) {
    return '$count carriers';
  }

  @override
  String kdvRateLabel(Object percent) {
    return 'KDV $percent%';
  }

  @override
  String get myOrdersLoginRequired => 'Please log in to view your orders';

  @override
  String get myOrdersTitle => 'My Orders';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get searchByOrderIdOrProductNameHint =>
      'Search by order id or product name';

  @override
  String get allFilterLabel => 'All';

  @override
  String get noMatchingOrders => 'No matching orders';

  @override
  String get orderLabel => 'Order';

  @override
  String get itemsTitle => 'Items';

  @override
  String qtyLabel(Object qty) {
    return 'Qty: $qty';
  }

  @override
  String get pendingStatusLabel => 'Pending';

  @override
  String get paidStatusLabel => 'Paid';

  @override
  String get confirmedStatusLabel => 'Confirmed';

  @override
  String get preparingStatusLabel => 'Preparing';

  @override
  String get shippedStatusLabel => 'Shipped';

  @override
  String get deliveredStatusLabel => 'Delivered';

  @override
  String get completedStatusLabel => 'Completed';

  @override
  String get failedStatusLabel => 'Failed';

  @override
  String get cancelledStatusLabel => 'Cancelled';

  @override
  String get paymentFailedStatusLabel => 'Payment Failed';

  @override
  String get paidPayoutStatusLabel => 'Paid';

  @override
  String get readyForPayoutLabel => 'Ready for payout';

  @override
  String get payoutPendingLabel => 'Payout pending';

  @override
  String get waitingForPaymentLabel => 'Waiting for payment';

  @override
  String get payoutNotSetLabel => 'Payout not set';

  @override
  String get confirmOrderButton => 'Confirm Order';

  @override
  String get startPreparingButton => 'Start Preparing';

  @override
  String get openOrderButton => 'Open Order';

  @override
  String get simulateUploadInvoiceButton => 'Simulate Upload Invoice';

  @override
  String get invoiceSimulatedAsUploaded => 'Invoice simulated as uploaded';

  @override
  String invoiceError(Object error) {
    return 'Invoice error: $error';
  }

  @override
  String orderStatusUpdated(Object status) {
    return 'Updated to $status';
  }

  @override
  String invoiceSummaryLabel(Object deadline, Object status) {
    return 'Invoice: $status • Deadline: $deadline';
  }

  @override
  String sellerNetLabel(Object amount) {
    return 'Seller net: $amount';
  }

  @override
  String referenceLabel(Object reference) {
    return 'Ref: $reference';
  }

  @override
  String buyerNameLabel(Object name) {
    return 'Name: $name';
  }

  @override
  String buyerSurnameLabel(Object surname) {
    return 'Surname: $surname';
  }

  @override
  String buyerIdentityNumberLabel(Object identityNumber) {
    return 'ID: $identityNumber';
  }

  @override
  String buyerCityLabel(Object city) {
    return 'City: $city';
  }

  @override
  String buyerAddressLabel(Object address) {
    return 'Address: $address';
  }

  @override
  String get buyerInfoTitle => 'Buyer Info';

  @override
  String invoiceTypeLabel(Object type) {
    return 'Invoice Type: $type';
  }

  @override
  String get invoiceTitle => 'Invoice';

  @override
  String get uploadDeadlineLabel => 'Upload Deadline';

  @override
  String get warningsLabel => 'Warnings';

  @override
  String get penaltyLabel => 'Penalty';

  @override
  String get invoiceSystemLabel => 'Invoice System';

  @override
  String get invoiceNoLabel => 'Invoice No';

  @override
  String get dateLabel => 'Date';

  @override
  String get cannotOpenInvoiceFile => 'Cannot open invoice file';

  @override
  String get viewInvoiceButton => 'View Invoice';

  @override
  String get noInvoiceLabel => 'No Invoice';

  @override
  String get uploadingLabel => 'Uploading...';

  @override
  String get invoiceUploadedLabel => 'Invoice Uploaded';

  @override
  String get uploadInvoiceButton => 'Upload Invoice';

  @override
  String get invoiceUploadDeadlinePassed => 'Invoice upload deadline passed!';

  @override
  String get timelineTitle => 'Timeline';

  @override
  String get payoutTitle => 'Payout';

  @override
  String amountLabel(Object amount) {
    return 'Amount: $amount';
  }

  @override
  String get paymentWillBeTransferredByPetsupo =>
      'Payment will be transferred by Petsupo';

  @override
  String get pendingPayoutLabel => 'Pending payout';

  @override
  String get waitingForCustomerPayment => 'Waiting for customer payment';

  @override
  String get actionsTitle => 'Actions';

  @override
  String get payoutMarkedAsPaid => 'Payout marked as paid';

  @override
  String get trackingNumberLabel => 'Tracking Number';

  @override
  String get trackingNumberRequired => 'Tracking number is required';

  @override
  String get returnCarrierRequired => 'Carrier is required';

  @override
  String get returnShippedBackFailed =>
      'Could not mark the return as shipped back';

  @override
  String get returnTrackingNumberLabel => 'Return Tracking Number';

  @override
  String get returnTrackingNumberHelperText =>
      'Enter the tracking number provided for the return shipment.';

  @override
  String get returnCarrierHelperText =>
      'Use the same carrier used for the original delivery.';

  @override
  String get originalShipmentTrackingLabel => 'Original Shipment Tracking';

  @override
  String get returnShipmentTrackingLabel => 'Return Shipment Tracking';

  @override
  String get returnShippedBackTimelineLabel => 'Return shipped back';

  @override
  String get carrierMissingFromOrder => 'Carrier missing from order';

  @override
  String get enterTrackingNumber => 'Enter tracking number';

  @override
  String get shipOrderButton => 'Ship Order';

  @override
  String get markAsDeliveredButton => 'Mark as Delivered';

  @override
  String get goToCarrierWebsiteButton => 'Go to Carrier Website';

  @override
  String get noTimelineYet => 'No timeline yet';

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get invoiceUploadedSuccessfully => 'Invoice uploaded successfully';

  @override
  String uploadFailed(Object error) {
    return 'Upload failed: $error';
  }

  @override
  String get orderShipped => 'Order shipped';

  @override
  String get sellerTaxNumberMissing => 'Seller tax number missing';

  @override
  String get buyerIdentityNumberMissing => 'Buyer identity number missing';

  @override
  String get buyerTaxNumberMissing => 'Buyer tax number missing';

  @override
  String get invoiceSystemMismatch => 'Invoice type mismatch';

  @override
  String get invoiceStatusPendingUploadLabel => 'Invoice waiting';

  @override
  String get invoiceStatusUploadedValidLabel => 'Invoice uploaded';

  @override
  String get invoiceStatusUploadedWithIssuesLabel => 'Review required';

  @override
  String get invoiceStatusLateLabel => 'Late';

  @override
  String get invoiceStatusApprovedLabel => 'Invoice approved';

  @override
  String get invoiceStatusRejectedLabel => 'Invoice rejected';

  @override
  String get eArsivLabel => 'e-Archive';

  @override
  String get eFaturaLabel => 'e-Invoice';

  @override
  String get fileIsEmpty => 'File is empty';

  @override
  String get fileTooLarge => 'File too large';

  @override
  String get upgradePageTitle => 'Upgrade';

  @override
  String get upgradeHeroTitle => 'Find better matches faster 🐾';

  @override
  String get upgradeHeroSubtitle =>
      'Unlock premium features, better visibility, exclusive offers and business tools.';

  @override
  String get premiumPlanSubtitle => 'For active pet owners';

  @override
  String get premiumPlanFeatureUnlimitedChat => 'Unlimited chat';

  @override
  String get premiumPlanFeatureAdvancedMatchingFilters =>
      'Advanced matching filters';

  @override
  String get premiumPlanFeatureExclusivePetOffers => 'Exclusive pet offers';

  @override
  String get premiumPlanFeatureBetterProfileExperience =>
      'Better profile experience';

  @override
  String get goldPlanSubtitle => 'For pet businesses and power users';

  @override
  String get mostPopularLabel => 'MOST POPULAR';

  @override
  String get goldPlanFeatureEverythingInPremium => 'Everything in Premium';

  @override
  String get goldPlanFeatureBusinessRegistrationAccess =>
      'Business registration access';

  @override
  String get goldPlanFeatureBoostedVisibility => 'Boosted visibility';

  @override
  String get goldPlanFeatureBusinessDashboardAccess =>
      'Business dashboard access';

  @override
  String get goldPlanFeaturePremiumChatAndOffers => 'Premium chat and offers';

  @override
  String get storeNotReadyTryAgain => 'Store not ready. Try again.';

  @override
  String get processingLabel => 'Processing...';

  @override
  String get restoreRequestSent => 'Restore request sent.';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get upgradePaymentTerms =>
      'Your payment will be charged to your App Store account at confirmation. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period.';

  @override
  String get autoRenewableMonthlySubscription =>
      'Auto-renewable monthly subscription';

  @override
  String get securePaymentNotice =>
      'Secure payment • Cancel anytime • Plans are managed by the App Store';

  @override
  String continueWithPlan(Object plan) {
    return 'Continue with $plan';
  }

  @override
  String get loadingLabel => 'Loading...';

  @override
  String get privacyPolicyLabel => 'Privacy Policy';

  @override
  String get termsOfUseLabel => 'Terms of Use';

  @override
  String adoptionRequestSubtitle(Object dogName) {
    return '• $dogName';
  }

  @override
  String get adoptionStepPersonalInfoTitle => '1️⃣ Personal Info';

  @override
  String get adoptionFullNameLabel => 'Full Name';

  @override
  String get adoptionFullNameHint => 'Your full name';

  @override
  String get adoptionEnterFullName => 'Enter your full name';

  @override
  String get genderLabel => 'Gender';

  @override
  String get adoptionSelectGender => 'Select gender';

  @override
  String get adoptionPhoneHint => 'e.g. +90 5xx xxx xxxx';

  @override
  String get adoptionEnterValidPhone => 'Enter a valid phone number';

  @override
  String get adoptionIncomeRangeLabel => 'Monthly Income Range';

  @override
  String get adoptionSelectIncomeRange => 'Select income range';

  @override
  String get adoptionIncomeRange0_2000 => '0 - 2,000';

  @override
  String get adoptionIncomeRange2000_5000 => '2,000 - 5,000';

  @override
  String get adoptionIncomeRange5000_10000 => '5,000 - 10,000';

  @override
  String get adoptionIncomeRange10000Plus => '10,000+';

  @override
  String get adoptionStepHousingTitle => '2️⃣ Housing';

  @override
  String get adoptionHousingTypeLabel => 'Housing type';

  @override
  String get adoptionHousingApartment => 'Apartment';

  @override
  String get adoptionHousingHouse => 'House';

  @override
  String get adoptionHousingVilla => 'Villa';

  @override
  String get adoptionOwnershipLabel => 'Owned / Rented';

  @override
  String get adoptionOwnershipOwned => 'Owned';

  @override
  String get adoptionOwnershipRented => 'Rented';

  @override
  String get adoptionLandlordPermissionRequired =>
      'Landlord permission (required)';

  @override
  String get adoptionHasGarden => 'Has garden';

  @override
  String get adoptionFenceHeightLabel => 'Fence height (cm)';

  @override
  String get adoptionFenceHeightHint => 'e.g. 120';

  @override
  String get adoptionEnterValidFenceHeight => 'Enter 1..400';

  @override
  String get adoptionStepExperienceTitle => '3️⃣ Experience';

  @override
  String get adoptionYearsOfExperienceLabel => 'Years of experience';

  @override
  String get adoptionYearsOfExperienceHint => '0..60';

  @override
  String get adoptionEnterYearsOfExperience => 'Enter 0..60';

  @override
  String get adoptionPreviousDogQuestion => 'Previous dog? (Yes/No)';

  @override
  String get adoptionPreviousDogReasonLabel =>
      'Reason previous dog no longer with you';

  @override
  String get adoptionPreviousDogReasonHint => 'Explain briefly';

  @override
  String get adoptionExplainPreviousDog => 'At least 10 characters';

  @override
  String get adoptionOtherPetsAtHome => 'Other pets at home';

  @override
  String get adoptionDescribeOtherPetsLabel => 'Describe your other pets';

  @override
  String get adoptionDescribeOtherPetsHint => 'e.g. 2 cats, vaccinated';

  @override
  String get adoptionRequiredShort => 'Required';

  @override
  String get adoptionDescribeOtherPetsRequired =>
      'Please describe your other pets';

  @override
  String get adoptionMotivationMessageLabel => 'Motivation message';

  @override
  String get adoptionMotivationMinLength =>
      'Motivation should be at least 20 characters';

  @override
  String get adoptionStepFinancialCommitmentTitle =>
      '4️⃣ Financial & Commitment';

  @override
  String get adoptionCanAffordVetExpenses => 'Can afford vet expenses?';

  @override
  String get adoptionEmergencySavingsAvailable =>
      'Emergency savings available?';

  @override
  String get adoptionUploadsSectionTitle => '📷 Uploads';

  @override
  String get adoptionHousePhotosRequiredTitle => 'House photos (required)';

  @override
  String get adoptionUploadAtLeastOnePhoto => 'Upload at least 1 photo';

  @override
  String adoptionUploadedCount(Object count) {
    return '$count uploaded';
  }

  @override
  String get adoptionUploadButton => 'Upload';

  @override
  String get adoptionClearButton => 'Clear';

  @override
  String get adoptionIdPhotoRequiredTitle => 'ID photo (required)';

  @override
  String get adoptionNotUploaded => 'Not uploaded';

  @override
  String get adoptionUploaded => 'Uploaded';

  @override
  String get adoptionReplaceButton => 'Replace';

  @override
  String get adoptionRemoveButton => 'Remove';

  @override
  String get adoptionProofOfIncomeOptionalTitle => 'Proof of income (optional)';

  @override
  String get adoptionOptionalLabel => 'Optional';

  @override
  String get adoptionAgreeContractRequiredLabel =>
      'I agree to sign the adoption contract (required)';

  @override
  String get adoptionAgreeContractRequired =>
      'You must agree to the adoption contract';

  @override
  String get adoptionUploadIdPhoto => 'Please upload an ID photo';

  @override
  String get adoptionNextButton => 'Next';

  @override
  String smartPriceSuggestedRangeLabel(
    Object currency,
    Object max,
    Object min,
  ) {
    return 'Suggested range: $min - $max $currency';
  }

  @override
  String smartPriceSuggestedPriceLabel(Object currency, Object price) {
    return 'Suggested price: $price $currency';
  }

  @override
  String get bestPriceStrategyLabel => 'Best Price';

  @override
  String get aggressiveLowStrategyLabel => 'Aggressive Low';

  @override
  String get competitiveStrategyLabel => 'Competitive';

  @override
  String get slightlyHighStrategyLabel => 'Slightly High';

  @override
  String get tooExpensiveStrategyLabel => 'Too Expensive';

  @override
  String get manualPricingLabel => 'Manual pricing';

  @override
  String get bestPricePositionLabel => 'Best Price 🏆';

  @override
  String get aggressiveLowPositionLabel => 'Aggressive Low ⚡';

  @override
  String get competitivePositionLabel => 'Competitive ✅';

  @override
  String get slightlyHighPositionLabel => 'Slightly High 📈';

  @override
  String get tooExpensivePositionLabel => 'Too Expensive ⚠️';

  @override
  String get marketSourceAggregateLabel => 'Aggregate data';

  @override
  String get marketSourceFallbackProductsLabel => 'Fallback products';

  @override
  String get marketSourceNoneLabel => 'No market data';

  @override
  String get marketSourceInvalidPricesLabel => 'Invalid prices';

  @override
  String get marketSourceErrorLabel => 'Error';

  @override
  String get discountRate1Label => '1%';

  @override
  String get discountRate10Label => '10%';

  @override
  String get discountRate20Label => '20%';

  @override
  String get carrierYurticiKargo => 'Yurtiçi Kargo';

  @override
  String get carrierArasKargo => 'Aras Kargo';

  @override
  String get carrierMngKargo => 'MNG Kargo';

  @override
  String get carrierSuratKargo => 'Sürat Kargo';

  @override
  String get carrierPttKargo => 'PTT Kargo';

  @override
  String get carrierHepsiJet => 'HepsiJET';

  @override
  String get carrierKolayGelsin => 'Kolay Gelsin';

  @override
  String get carrierUpsTurkiye => 'UPS Türkiye';

  @override
  String get carrierDhlExpress => 'DHL Express';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryAccessories => 'Accessories';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryToys => 'Toys';

  @override
  String get subCategoryDryFood => 'Dry Food';

  @override
  String get subCategoryWetFood => 'Wet Food';

  @override
  String get subCategoryTreats => 'Treats';

  @override
  String get subCategoryCollar => 'Collar';

  @override
  String get subCategoryLeash => 'Leash';

  @override
  String get subCategoryClothing => 'Clothing';

  @override
  String get subCategoryVitamins => 'Vitamins';

  @override
  String get subCategoryMedicine => 'Medicine';

  @override
  String get subCategoryChewToy => 'Chew Toy';

  @override
  String get subCategoryInteractive => 'Interactive';

  @override
  String get productAlreadyExistsTitle => 'Product already exists';

  @override
  String get productAlreadyExistsDescription =>
      'This product already exists. Opening the product editor.';

  @override
  String get continueButton => 'Continue';

  @override
  String get productNameMustBeAtLeast4Chars =>
      'Product name must be at least 4 characters';

  @override
  String get invalidBarcode => 'Invalid barcode';

  @override
  String get invalidSku => 'Invalid SKU';

  @override
  String get invalidWholesalePrice => 'Invalid wholesale price';

  @override
  String get wholesaleMinQuantityMustBeAtLeast2 =>
      'Wholesale minimum quantity must be at least 2';

  @override
  String get kdvRateIsRequired => 'Select a VAT rate';

  @override
  String get invalidPrice => 'Invalid price';

  @override
  String get invalidDiscountPrice => 'Invalid discount price';

  @override
  String get discountMustBeLowerThanOriginalPrice =>
      'Discount price must be lower than original price';

  @override
  String get wholesalePriceMustBeLowerThanRetailPrice =>
      'Wholesale price must be lower than retail price';

  @override
  String get invalidStock => 'Invalid stock';

  @override
  String get stockMustBeAtLeastWholesaleMinQuantity =>
      'Stock must be at least the wholesale minimum quantity';

  @override
  String get inventoryStockFieldLabel => 'Stock';

  @override
  String get invalidLowStockAlert => 'Invalid low-stock alert';

  @override
  String get addAtLeast1Media => 'Add at least 1 media item';

  @override
  String get descriptionMustBeAtLeast10Characters =>
      'Description must be at least 10 characters';

  @override
  String get selectCategory => 'Select a category';

  @override
  String get weightOrDesiIsRequired => 'Weight or desi is required';

  @override
  String get lengthIsRequired => 'Length is required';

  @override
  String get widthIsRequired => 'Width is required';

  @override
  String get heightIsRequired => 'Height is required';

  @override
  String get invalidDesiValue => 'Invalid desi value';

  @override
  String get fixedShippingFeeIsRequired => 'Fixed shipping fee is required';

  @override
  String get invalidShippingFee => 'Invalid shipping fee';

  @override
  String get freeShippingThresholdIsRequired =>
      'Free shipping threshold is required';

  @override
  String get invalidPreparationTime => 'Invalid preparation time';

  @override
  String get invalidMaxDeliveryDays => 'Invalid maximum delivery days';

  @override
  String get selectAtLeast1CargoCarrier => 'Select at least 1 cargo carrier';

  @override
  String get returnWindowCannotBeLessThan14Days =>
      'Return window cannot be less than 14 days';

  @override
  String get returnCarrierIsRequired => 'Return carrier is required';

  @override
  String get shippingPayerMismatch => 'Shipping payer mismatch';

  @override
  String get productSavedStatus => 'Product saved ✅';

  @override
  String get scanFailed => 'Scan failed';

  @override
  String estimatedPriceLabel(Object currency, Object price) {
    return 'Estimated price: $price $currency';
  }

  @override
  String get loadedFromGlobalApi => 'Loaded from global API';

  @override
  String productFallbackName(Object short) {
    return 'Product $short';
  }

  @override
  String fallbackEstimateLabel(Object currency, Object price) {
    return 'Fallback estimate: $price $currency';
  }

  @override
  String offlineEstimateLabel(Object currency, Object price) {
    return 'Offline estimate: $price $currency';
  }

  @override
  String errorEstimateLabel(Object currency, Object price) {
    return 'Error estimate: $price $currency';
  }

  @override
  String smartDescriptionDefault(Object brand, Object name) {
    return '$name by $brand is a reliable option for pet owners.';
  }

  @override
  String get trustedBrand => 'Trusted brand';

  @override
  String get productDetectedStatus => 'Product detected';

  @override
  String get noProductFoundAnywhere => 'No product found anywhere';

  @override
  String get enterProductNameFirst => 'Enter product name first';

  @override
  String smartDescriptionFood(Object brand, Object name, Object subCategory) {
    return '$name by $brand is a practical choice for pets. It fits the $subCategory category and is suitable for daily use.';
  }

  @override
  String smartDescriptionAccessories(
    Object brand,
    Object name,
    Object subCategory,
  ) {
    return '$name by $brand is a useful accessory in the $subCategory category.';
  }

  @override
  String smartDescriptionHealth(Object brand, Object name, Object subCategory) {
    return '$name by $brand is designed for pet health and wellness in the $subCategory category.';
  }

  @override
  String smartDescriptionToys(Object brand, Object name, Object subCategory) {
    return '$name by $brand is an engaging toy from the $subCategory category.';
  }

  @override
  String get descriptionSuggestionAdded => 'Description suggestion added';

  @override
  String get noPricingDataYet => 'No pricing data yet';

  @override
  String get smartPriceSuggestionTitle => 'Smart Price Suggestion';

  @override
  String get waitingForPricingData => 'Waiting for pricing data...';

  @override
  String get tapToApplySuggestedPrice => 'Tap to apply suggested price';

  @override
  String get smartPricingEngineTitle => 'Smart Pricing Engine';

  @override
  String get modeLabel => 'Mode';

  @override
  String get noMarketDataLabel => 'No market data';

  @override
  String get usingSmartEstimationLabel => 'Using smart estimation 🧠';

  @override
  String get marketIntelligenceTitle => 'Market Intelligence';

  @override
  String get avgPriceLabel => 'Avg price';

  @override
  String get medianPriceLabel => 'Median price';

  @override
  String get sellerCountLabel => 'Seller count';

  @override
  String get bestPriceLabel => 'Best price';

  @override
  String get highestPriceLabel => 'Highest price';

  @override
  String get yourGapVsMarketLabel => 'Your gap vs market';

  @override
  String get positionLabel => 'Position';

  @override
  String get profitMarginLabel => 'Profit margin';

  @override
  String get sourceLabel => 'Source';

  @override
  String get searchingProductStatus => 'Searching product...';

  @override
  String get productAlreadyExistsOpeningEditStatus =>
      'Product exists, opening editor...';

  @override
  String get fetchingProductDataStatus => 'Fetching product data...';

  @override
  String get analyzingMarketStatus => 'Analyzing market...';

  @override
  String get marketAvgLabel => 'Average price';

  @override
  String get marketMedianLabel => 'Median price';

  @override
  String get marketSellersLabel => 'Seller count';

  @override
  String emergencyFallbackLabel(Object currency, Object price) {
    return 'Emergency fallback: $price $currency';
  }

  @override
  String get productReadyStatus => 'Product ready ✅';

  @override
  String get failedToLoadProductStatus => 'Failed to load product';

  @override
  String get barcodeLookupFailed => 'Barcode lookup failed';

  @override
  String get editProductTitle => 'Edit Product';

  @override
  String get addProductTitle => 'Add Product';

  @override
  String get tapToReplaceOrAddMedia => 'Tap to replace or add media';

  @override
  String get tapToAddMedia => 'Tap to add media';

  @override
  String get basicInfoSectionTitle => 'Basic info';

  @override
  String get productNameMinCharsLabel => 'Product name *';

  @override
  String get brandLabel => 'Brand';

  @override
  String get barcodeFieldLabel => 'Barcode';

  @override
  String get enterBarcodeHint => 'Enter or scan the barcode';

  @override
  String get noBarcodeSkuHint =>
      'Barcode is optional. SKU will be auto-generated if empty.';

  @override
  String get scanButtonLabel => 'Scan';

  @override
  String get skuCodeLabel => 'SKU Code';

  @override
  String get autoGeneratedSkuHint => 'Auto-generated if empty';

  @override
  String get shippingAndDeliverySectionTitle => 'Shipping and delivery';

  @override
  String get thisProductHasADiscount => 'This product has a discount';

  @override
  String get originalPriceLabel => 'Original price';

  @override
  String get priceLabel => 'Price';

  @override
  String get appointmentDetailTitle => 'Appointment Detail';

  @override
  String get appointmentNotFound => 'Appointment not found';

  @override
  String get petLabel => 'Pet';

  @override
  String get statusLabel => 'Status';

  @override
  String get paymentLabel => 'Payment';

  @override
  String get goToPaymentButton => 'Go to Payment';

  @override
  String get markedAsCompletedSnack => 'Marked as completed';

  @override
  String get markAsCompletedButton => 'Mark as Completed';

  @override
  String get wholesalePriceLabel => 'Wholesale price';

  @override
  String get minimumQuantityForWholesaleLabel =>
      'Minimum quantity for wholesale';

  @override
  String get wholesaleAppliesHint =>
      'Wholesale discount applies from this quantity';

  @override
  String get visibleOnlyToBusinessAccountsHint =>
      'Visible only to business accounts';

  @override
  String get usersWillSeeDiscountHint => 'Users will see the discount badge';

  @override
  String get discountPriceLabel => 'Discount price';

  @override
  String get kdvLabel => 'VAT';

  @override
  String get lengthLabel => 'Length';

  @override
  String get widthLabel => 'Width';

  @override
  String get heightLabel => 'Height';

  @override
  String calculatedDesiLabel(Object value) {
    return 'Calculated desi: $value';
  }

  @override
  String get manualDesiOverrideOptionalLabel =>
      'Manual desi override (optional)';

  @override
  String get shippingModeLabel => 'Shipping mode';

  @override
  String get carrierCalculatedLabel => 'Carrier calculated';

  @override
  String get fixedShippingFeeLabel => 'Fixed shipping fee';

  @override
  String get sellerPaysShippingLabel => 'Seller pays shipping';

  @override
  String get enableFreeShippingCampaignLabel => 'Enable free shipping campaign';

  @override
  String get freeShippingThresholdLabel => 'Free shipping threshold';

  @override
  String get preparationTimeDaysLabel => 'Preparation time (days)';

  @override
  String get maxDeliveryTimeDaysLabel => 'Max delivery time (days)';

  @override
  String get cargoCompaniesTitle => 'Cargo companies';

  @override
  String get allowReturnsLabel => 'Allow returns';

  @override
  String get returnWindowDaysLabel => 'Return window (days)';

  @override
  String get returnShippingPayerLabel => 'Return shipping payer';

  @override
  String get sellerOptionLabel => 'Seller';

  @override
  String get buyerOptionLabel => 'Buyer';

  @override
  String get sellerContractedCarrierOnlyLabel =>
      'Seller if contracted carrier only';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get lowStockAlertLabel => 'Low stock alert';

  @override
  String get mainCategoryLabel => 'Main category';

  @override
  String get subCategoryLabel => 'Subcategory';

  @override
  String get generatingLabel => 'Generating...';

  @override
  String get suggestLabel => 'Suggest';

  @override
  String get updateProductTitle => 'Update Product';

  @override
  String get sellInstantlyButtonLabel => 'Sell instantly';

  @override
  String get shippingEstimateTitle => 'Shipping estimate';

  @override
  String desiLabel(Object value) {
    return 'Desi: $value';
  }

  @override
  String billableLabel(Object value) {
    return 'Billable: $value';
  }

  @override
  String basePriceLabel(Object currency, Object value) {
    return 'Base: $value $currency';
  }

  @override
  String extraLabel(Object currency, Object value) {
    return 'Extra: $value $currency';
  }

  @override
  String totalPriceLabel(Object currency, Object value) {
    return 'Total: $value $currency';
  }

  @override
  String get returnRequestsTitle => 'Return Requests';

  @override
  String get returnAvailableAfterDeliveryMessage =>
      'Returns become available after delivery.';

  @override
  String get noReturnsYet => 'No return requests yet';

  @override
  String get requestReturnButton => 'Request Return';

  @override
  String get returnRequestSubmitted => 'Return request submitted';

  @override
  String get selectReturnReasonLabel => 'Select reason';

  @override
  String get returnDescriptionHint => 'Describe the issue...';

  @override
  String get selectReturnItemsLabel => 'Select items to return';

  @override
  String returnRequestLabel(Object id) {
    return 'Return #$id';
  }

  @override
  String get reasonLabel => 'Reason';

  @override
  String get refundAmountLabel => 'Refund amount';

  @override
  String get returnAmountLabel => 'Estimated refund';

  @override
  String get shippingResponsibilityLabel => 'Return shipping';

  @override
  String get refundTypeLabel => 'Refund type';

  @override
  String get returnTimelineTitle => 'Return timeline';

  @override
  String get refundResultLabel => 'Refund result';

  @override
  String get returnActionCompleted => 'Return updated';

  @override
  String get approveReturnButton => 'Approve';

  @override
  String get rejectReturnButton => 'Reject';

  @override
  String get cancelReturnButton => 'Cancel return';

  @override
  String get markShippedBackButton => 'Mark shipped back';

  @override
  String get markReceivedButton => 'Mark received';

  @override
  String get triggerRefundButton => 'Trigger refund';

  @override
  String get returnStatusPending => 'Pending';

  @override
  String get returnStatusApproved => 'Approved';

  @override
  String get returnStatusRejected => 'Rejected';

  @override
  String get returnStatusShippedBack => 'Shipped back';

  @override
  String get returnStatusReceivedBySeller => 'Received by seller';

  @override
  String get returnStatusRefundPending => 'Refund pending';

  @override
  String get returnStatusRefundFailed => 'Refund failed';

  @override
  String get returnStatusRefunded => 'Refunded';

  @override
  String get returnStatusCancelled => 'Cancelled';

  @override
  String get returnReasonDamaged => 'Damaged';

  @override
  String get returnReasonWrongProduct => 'Wrong product';

  @override
  String get returnReasonMissingParts => 'Missing parts';

  @override
  String get returnReasonNotAsDescribed => 'Not as described';

  @override
  String get returnReasonChangedMind => 'Changed mind';

  @override
  String get returnReasonOther => 'Other';

  @override
  String get refundTypeFullLabel => 'Full refund';

  @override
  String get refundTypePartialLabel => 'Partial refund';

  @override
  String get refundTypeShippingLabel => 'Shipping refund';

  @override
  String get shippingResponsibilitySellerLabel => 'Seller';

  @override
  String get shippingResponsibilityBuyerLabel => 'Buyer';

  @override
  String get shippingResponsibilityContractCarrierLabel =>
      'Seller if contracted carrier';

  @override
  String get returnCarrierLabel => 'Return Carrier';

  @override
  String get returnImagesAdded => 'Images added';

  @override
  String get refundRejectedStatusLabel => 'Refund rejected';
}
