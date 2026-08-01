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
  String get checkoutCargoUpdatesQuestion => 'How should we send invoice and cargo tracking updates?';

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
  String get checkoutDistanceSalesAgreement => 'I accept the distance sales agreement';

  @override
  String get checkoutMarketingOptional => 'Receive marketing messages (optional)';

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
  String get checkoutPleaseSelectCargoCompany => 'Please select a cargo company';

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
  String get checkoutPaymentPageOpenedMessage => 'Payment page opened. Complete the payment, then return to the app.';

  @override
  String get checkoutBackButton => 'Back';

  @override
  String get checkoutProceedToPayment => 'Proceed to Payment';

  @override
  String get checkoutContinueButton => 'Continue';

  @override
  String get checkoutPaymentCompletedSuccessfully => 'Payment completed successfully';

  @override
  String get checkoutMultiSellerInfoTitle => 'One payment, separate orders';

  @override
  String get checkoutMultiSellerInfoBody => 'You’ll make one payment. A separate order will be created for each seller.';

  @override
  String checkoutSellerSection(Object sellerName) {
    return '$sellerName';
  }

  @override
  String checkoutSellerFallback(int number) {
    return 'Seller $number';
  }

  @override
  String get checkoutSellerSubtotal => 'Seller subtotal';

  @override
  String get checkoutProductsTotal => 'Products total';

  @override
  String get checkoutShippingMethod => 'Shipping method';

  @override
  String get checkoutShippingCost => 'Shipping cost';

  @override
  String get checkoutShippingTotal => 'Shipping total';

  @override
  String get checkoutEstimatedDelivery => 'Estimated delivery';

  @override
  String get checkoutSellerTotal => 'Seller total';

  @override
  String get checkoutMultiOrderSuccessTitle => 'Payment successful';

  @override
  String get checkoutMultiOrderSuccessBody => 'Your payment was completed and separate orders were created for each seller.';

  @override
  String checkoutSellerOrderLabel(int number) {
    return 'Seller order $number';
  }

  @override
  String get checkoutOpenOrder => 'View order';

  @override
  String get checkoutMultiOrderExit => 'Back to home';

  @override
  String get checkoutPaymentCancelledOrIncomplete => 'Payment was cancelled or not completed';

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
  String get cancelAppointmentConfirmation => 'Are you sure you want to cancel this appointment?';

  @override
  String get keepAppointmentButton => 'Keep Appointment';

  @override
  String get appointmentCancelled => 'Appointment cancelled';

  @override
  String get cancellationNotAllowed => 'Cancellation is not allowed for this appointment.';

  @override
  String get cancelAppointmentFailed => 'Could not cancel appointment. Please try again.';

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
  String get requestSentMessage => 'Your appointment request has been sent to the clinic.';

  @override
  String get okButton => 'OK';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get alreadyBookedAtThisTime => 'You already have a booking at this time. Please choose another time.';

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
  String get myDogs => 'My Pets';

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
  String get passwordValidation => 'Minimum 8 characters, with a letter and a number.';

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
  String get pleaseVerifyEmailBeforeSigningIn => 'Please verify your email before signing in.';

  @override
  String get userCreationFailed => 'User creation failed';

  @override
  String get verificationEmailCouldNotBeSent => 'Verification email could not be sent';

  @override
  String get verificationSessionCouldNotBeCreated => 'Verification session could not be created';

  @override
  String get emailAlreadyRegisteredTryLoggingIn => 'This email is already registered. Try logging in.';

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
  String get enterVerificationCodeSentToEmail => 'Enter the verification code sent to your email';

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
  String get authWelcomeBackSubtitle => 'Welcome back to PetSupo';

  @override
  String get authCreateAccountSubtitle => 'Create your PetSopu account';

  @override
  String get sessionExpiredPleaseSignInAgain => 'Your session expired. Please sign in again.';

  @override
  String get signInToAccessPlaymate => 'Please Sign In to access Playmate';

  @override
  String get findPlaymates => 'Find Playmates';

  @override
  String get signInToFindFriends => 'Find friends for your pet';

  @override
  String get addYourDog => 'Add Your Dog';

  @override
  String get addYourPetTitle => 'Add Your Pet';

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
  String get ageUnit => 'Unit';

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
    return 'Dog name \"$name\" already exists';
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
  String get addDogButton => 'Add Pet';

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
  String get upgradeToPremiumForMoreFilters => 'Upgrade to Premium for more filters!';

  @override
  String get upgradeToPremiumTitle => 'Upgrade to Premium';

  @override
  String get upgradeToPremiumSubtitle => 'Unlock advanced features and business tools';

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
  String get playdateRequestTitle => 'Playdate Request';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog wants to play with $requestedDog!';
  }

  @override
  String playdateRequestNotificationBody(Object requesterDog, Object requestedDog) {
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
  String get pleaseLoginToViewPlaydateRequests => 'Login to view playdate requests';

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
  String get playmateLocationNeededMessage => 'We use your location to show nearby dogs';

  @override
  String get playmateFiltersTitle => 'Filters';

  @override
  String get playmateBreedPremiumHint => 'Breed (PetSupo Partner)';

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
  String get dogParkUseYourLocationToShowNearbyDogParks => 'We use your location to show nearby dog parks';

  @override
  String get allowButton => 'Allow';

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
  String get distanceUnknown => 'Distance unknown';

  @override
  String boostDogTitle(Object dogName) {
    return 'Boost $dogName';
  }

  @override
  String get boostVisibilityDescription => 'Get more visibility in Playmates discovery.';

  @override
  String get boost24HoursTitle => '24 Hours Boost';

  @override
  String get boostQuickVisibilitySubtitle => 'Good for quick visibility';

  @override
  String get boostPrice29 => '₺29';

  @override
  String get boost3DaysTitle => '3 Days Boost';

  @override
  String get boostBetterExposureSubtitle => 'Better exposure for active discovery';

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
  String dogInfoLiked(Object name) {
    return 'You liked $name';
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
  String get months => 'months';

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
  String get playdateSchedulingSubtitle => 'Pick date, time, location and dogs for the playdate.';

  @override
  String get errorSelectDateAndTime => 'Please select date and time.';

  @override
  String get errorMissingLocationCoordinates => 'Park location coordinates missing.';

  @override
  String get errorPlaydateLeadTime => 'Playdate must be scheduled at least 15 minutes in advance.';

  @override
  String get playdateTimeConflict => 'This dog already has a playdate around this time 🐾';

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
  String get offerFallbackTitle => 'Special offer for PetSupo users';

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
  String get offerPremiumRequiredMessage => 'This offer is only for premium members.';

  @override
  String get offerCancel => 'Cancel';

  @override
  String get offerUpgrade => 'Upgrade';

  @override
  String get offerUnlockingMessage => 'Unlocking your deal...';

  @override
  String get offerChooseContinueTitle => 'Choose where to continue';

  @override
  String get offerChooseContinueSubtitle => 'Pick your preferred contact option for this offer.';

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
  String get pamperYourPet => 'Pamper your pet';

  @override
  String get petShopTitle => 'Pet Shop';

  @override
  String get shopNearYou => 'Shop near you';

  @override
  String get featuredDeal => 'Featured Deal';

  @override
  String get premiumLabel => 'Premium';

  @override
  String get goldLabel => 'PetSupo Partner';

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
  String get createMemoriesTogether => 'Create memories together';

  @override
  String get reportFoundTitle => 'Report Found';

  @override
  String get reconnectFamilies => 'Help reunite pets with their families';

  @override
  String get lostPetsTitle => 'Lost Pets';

  @override
  String get activeReportsNearby => 'View active missing pet reports';

  @override
  String get foundPetsTitle => 'Found Pets';

  @override
  String get waitingToReunite => 'Pets waiting to return home';

  @override
  String get trainingTitle => 'Training';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get trainingComingSoonMessage => 'Training feature coming soon 🐾';

  @override
  String get communityHub => 'Community Hub';

  @override
  String get safetyAndRescue => 'Safety & Rescue';

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
  String get expertCareForYourPet => 'Expert care for your pet';

  @override
  String get homeLocationNeededTitle => 'Location needed';

  @override
  String get homeLocationNeededMessage => 'We use your location to show nearby vets';

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
  String get vetDealDesc => 'PetSupo Partner members: free checkup';

  @override
  String get offerWhatsApp => 'WhatsApp';

  @override
  String offerCodeCopied(Object code) {
    return 'Code copied: $code';
  }

  @override
  String get offerOpenError => 'Error opening offer';

  @override
  String get businessRegisterLegalCompanyNameRequired => '• Legal Company Name is required.';

  @override
  String get businessRegisterPublicDisplayNameRequired => '• Public Display Name is required.';

  @override
  String get businessRegisterSelectCountry => '• Please select a Country.';

  @override
  String get businessRegisterSelectBusinessCategory => '• Please select at least one business category.';

  @override
  String get businessRegisterEnterValidEmail => '• Enter a valid email address (example: name@example.com).';

  @override
  String get businessRegisterPhoneIncomplete => '• Phone number is incomplete.';

  @override
  String get businessRegisterSelectCityProvince => '• Please select City / Province.';

  @override
  String get businessRegisterSelectDistrict => '• Please select District.';

  @override
  String get businessRegisterBusinessAddressRequired => '• Business Address is required.';

  @override
  String get businessRegisterAllLegalDocumentsRequired => '• All required legal documents must be uploaded.';

  @override
  String get businessRegisterDocumentsVerifiedBeforeContinuing => '• Documents must be verified before continuing.';

  @override
  String get businessRegisterAcceptPlatformTerms => '• You must accept the Platform Terms.';

  @override
  String get businessRegisterAcceptLegalResponsibility => '• You must accept legal responsibility declaration.';

  @override
  String get businessRegisterFixHighlightedFields => 'Please fix the highlighted fields';

  @override
  String get businessRegisterOk => 'OK';

  @override
  String get businessRegisterFailedToLoadCountries => 'Failed to load countries';

  @override
  String get businessRegisterFailedToLoadCities => 'Failed to load cities';

  @override
  String get businessRegisterFailedToLoadDistricts => 'Failed to load districts';

  @override
  String get businessRegisterPlatformLegalAgreement => 'Platform Legal Agreement';

  @override
  String get businessRegisterReadAndAccept => 'I Have Read and Accept';

  @override
  String get businessRegisterLocationPermissionDenied => 'Location permission denied';

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
  String get businessRegisterCouldNotOpenLegalText => 'Could not open legal text';

  @override
  String get businessRegisterSelectAtLeastOneBusinessCategory => 'Please select at least one business category';

  @override
  String get businessRegisterPleaseEnterBusinessAddress => 'Please enter business address';

  @override
  String get businessRegisterMustAcceptAllAgreements => 'You must accept all agreements';

  @override
  String get businessRegisterDocumentsVerifiedBeforeSubmission => 'Documents must be verified before submission';

  @override
  String get businessRegisterApplicationSubmittedSuccessfully => 'Application submitted successfully';

  @override
  String get businessRegisterSubmissionFailed => 'Submission failed';

  @override
  String get businessRegisterUnexpectedErrorOccurred => 'Unexpected error occurred';

  @override
  String get businessRegisterTitle => 'Register Business';

  @override
  String get businessRegisterStepIdentityCategories => 'Business identity and categories';

  @override
  String get businessRegisterStepContactLocation => 'Contact and location';

  @override
  String get businessRegisterStepLegalDocuments => 'Legal documents';

  @override
  String get businessRegisterStepAgreementConfirmation => 'Agreement confirmation';

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
  String get businessRegisterBusinessIdentitySubtitle => 'Tell us how your business should appear on PetSupo.';

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
  String get businessRegisterBusinessCategoriesSubtitle => 'Select all sectors this business operates in.';

  @override
  String get businessRegisterContactLocation => 'Contact & location';

  @override
  String get businessRegisterContactLocationSubtitle => 'These details help customers find and contact you.';

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
  String get businessRegisterMapPickerComingSoon => 'Map picker will be added soon';

  @override
  String get businessRegisterPickLocation => 'Pick Location';

  @override
  String get businessRegisterLocationSelected => 'Location selected';

  @override
  String get businessRegisterTaxPlate => 'Vergi Levhası (Tax Plate)';

  @override
  String get businessRegisterTradeRegistryGazette => 'Ticaret Sicil Gazetesi';

  @override
  String get businessRegisterAuthorizedSignatureDocument => 'Yetkili İmza Belgesi';

  @override
  String get businessRegisterTaxNumberVkn => 'Tax Number (VKN)';

  @override
  String get businessRegisterAutoFilledFromDocument => 'Auto-filled from document';

  @override
  String get businessRegisterDocumentVerificationInconsistencies => 'Document verification has inconsistencies. Admin review required.';

  @override
  String get businessRegisterMersisNumber => 'MERSIS Number';

  @override
  String get businessRegisterDocumentsSecurelyEncrypted => 'Your documents are securely encrypted and verified automatically';

  @override
  String get businessRegisterVerifiedFromDocument => 'Verified from document';

  @override
  String get businessRegisterAutoFilledAfterVerification => 'Auto-filled after document verification';

  @override
  String get businessRegisterUploadTradeRegistryFirst => 'Upload Trade Registry first';

  @override
  String get businessRegisterWaitingForDocumentVerification => 'Waiting for document verification...';

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
  String get businessRegisterDocumentVerifiedSuccessfully => 'Document verified successfully';

  @override
  String get businessRegisterCouldNotReadDocument => 'Could not read document, please re-upload';

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
  String get businessRegisterAcceptTermsKvkk => 'I accept the Platform Terms and KVKK Data Protection Policy.';

  @override
  String get businessRegisterReadInsideApp => 'Read inside app';

  @override
  String get businessRegisterOpenOfficialLegalPage => 'Open official legal page';

  @override
  String get businessRegisterLegalVersion => 'Version v1.0 • Last updated May 2026';

  @override
  String get businessRegisterAgreementSecurelyStored => 'Your agreement is securely stored and legally binding';

  @override
  String get businessRegisterLegalResponsibilityDeclaration => 'I declare that all submitted documents are accurate and I accept full legal responsibility under Turkish Commercial Law.';

  @override
  String get businessRegisterUploaded => 'Uploaded';

  @override
  String get businessRegisterReplaceDocument => 'Replace document';

  @override
  String get businessRegisterReplaceDocumentConfirmation => 'Are you sure you want to replace this file?';

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
  String get myAppointmentsLoginRequired => 'Please log in to view your appointments';

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
  String get userProfileUpgradeBusinessDescription => 'Upgrade to PetSupo Partner to register your business and start receiving customers.';

  @override
  String get userProfileUpgradeToGold => 'Upgrade to PetSupo Partner';

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
  String get userProfileApplicationUnderReviewDescription => 'Your business request has been submitted successfully and is currently under review.';

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
  String get userProfileUpgradeToGoldToContinue => 'Upgrade to PetSupo Partner to continue';

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
  String get userProfileUsernameMinLength => 'Username must be at least 3 characters';

  @override
  String get userProfileUsernameMaxLength => 'Username must be at most 20 characters';

  @override
  String get userProfileUsernameNoSpaces => 'Username cannot contain spaces';

  @override
  String get userProfilePhoneInvalidCharacters => 'Phone contains invalid characters';

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
  String get sectorDashboardNotImplementedYet => 'This sector dashboard is not implemented yet';

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
  String get catalogStrengthAddItemsMessage => 'Add products, description, media, and stock to strengthen your catalog.';

  @override
  String get catalogStrengthWeakDetailsMessage => 'Your product details are still weak. Add more media, descriptions, and stock info.';

  @override
  String get catalogStrengthMediumLabel => 'Medium';

  @override
  String get catalogStrengthMediumMessage => 'Good start. Add richer descriptions and more product media to improve visibility.';

  @override
  String get catalogStrengthStrongLabel => 'Strong';

  @override
  String get catalogStrengthStrongMessage => 'Great catalog quality. Your listings look strong and complete.';

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
  String get myOrdersUnknownProduct => 'Product';

  @override
  String get myOrdersUnknownSeller => 'Seller';

  @override
  String myOrdersProductAndMore(Object product, int count) {
    return '$product + $count more';
  }

  @override
  String get myOrdersOrderNumberUnavailable => 'Unavailable';

  @override
  String get myOrdersDateUnavailable => 'Date unavailable';

  @override
  String get myOrdersSortNewest => 'Date: newest first';

  @override
  String get myOrdersSortOldest => 'Date: oldest first';

  @override
  String get myOrdersSortProductAz => 'Product: A–Z';

  @override
  String get myOrdersSortProductZa => 'Product: Z–A';

  @override
  String get myOrdersSortSellerAz => 'Seller: A–Z';

  @override
  String get myOrdersSortSellerZa => 'Seller: Z–A';

  @override
  String get myOrdersSortAmountHigh => 'Amount: highest first';

  @override
  String get myOrdersSortAmountLow => 'Amount: lowest first';

  @override
  String get myOrdersProcessingStatus => 'Processing';

  @override
  String get myOrdersRefundedStatus => 'Refunded';

  @override
  String get myOrdersReturnedStatus => 'Returned';

  @override
  String get myOrdersRefundedOrReturnedStatus => 'Refunded / Returned';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get searchByOrderIdOrProductNameHint => 'Search by order id or product name';

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
  String get paymentWillBeTransferredByPetsupo => 'Payment will be transferred by Petsupo';

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
  String get returnShippedBackFailed => 'Could not mark the return as shipped back';

  @override
  String get returnTrackingNumberLabel => 'Return Tracking Number';

  @override
  String get returnTrackingNumberHelperText => 'Enter the tracking number provided for the return shipment.';

  @override
  String get returnCarrierHelperText => 'Use the same carrier used for the original delivery.';

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
  String get upgradeHeroSubtitle => 'Unlock premium features, better visibility, exclusive offers and business tools.';

  @override
  String get premiumPlanSubtitle => 'For active pet owners';

  @override
  String get premiumPlanFeatureUnlimitedChat => 'Unlimited chat';

  @override
  String get premiumPlanFeatureAdvancedMatchingFilters => 'Advanced matching filters';

  @override
  String get premiumPlanFeatureExclusivePetOffers => 'Exclusive pet offers';

  @override
  String get premiumPlanFeatureBetterProfileExperience => 'Better profile experience';

  @override
  String get goldPlanSubtitle => 'For pet-care professionals and businesses';

  @override
  String get mostPopularLabel => 'MOST POPULAR';

  @override
  String get goldPlanFeatureEverythingInPremium => 'Everything in Premium';

  @override
  String get goldPlanFeatureBusinessRegistrationAccess => 'Business registration access';

  @override
  String get goldPlanFeatureBoostedVisibility => 'Boosted visibility';

  @override
  String get goldPlanFeatureBusinessDashboardAccess => 'Business dashboard access';

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
  String get upgradePaymentTerms => 'Your payment will be charged to your App Store account at confirmation. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period.';

  @override
  String get autoRenewableMonthlySubscription => 'Auto-renewable monthly subscription';

  @override
  String get securePaymentNotice => 'Secure payment • Cancel anytime • Plans are managed by the App Store';

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
  String get adoptionLandlordPermissionRequired => 'Landlord permission (required)';

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
  String get adoptionPreviousDogReasonLabel => 'Reason previous dog no longer with you';

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
  String get adoptionDescribeOtherPetsRequired => 'Please describe your other pets';

  @override
  String get adoptionMotivationMessageLabel => 'Motivation message';

  @override
  String get adoptionMotivationMinLength => 'Motivation should be at least 20 characters';

  @override
  String get adoptionStepFinancialCommitmentTitle => '4️⃣ Financial & Commitment';

  @override
  String get adoptionCanAffordVetExpenses => 'Can afford vet expenses?';

  @override
  String get adoptionEmergencySavingsAvailable => 'Emergency savings available?';

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
  String get adoptionAgreeContractRequiredLabel => 'I agree to sign the adoption contract (required)';

  @override
  String get adoptionAgreeContractRequired => 'You must agree to the adoption contract';

  @override
  String get adoptionUploadIdPhoto => 'Please upload an ID photo';

  @override
  String get adoptionNextButton => 'Next';

  @override
  String smartPriceSuggestedRangeLabel(Object currency, Object max, Object min) {
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
  String get productAlreadyExistsDescription => 'This product already exists. Opening the product editor.';

  @override
  String get continueButton => 'Continue';

  @override
  String get productNameMustBeAtLeast4Chars => 'Product name must be at least 4 characters';

  @override
  String get invalidBarcode => 'Invalid barcode';

  @override
  String get invalidSku => 'Invalid SKU';

  @override
  String get invalidWholesalePrice => 'Invalid wholesale price';

  @override
  String get wholesaleMinQuantityMustBeAtLeast2 => 'Wholesale minimum quantity must be at least 2';

  @override
  String get kdvRateIsRequired => 'Select a VAT rate';

  @override
  String get invalidPrice => 'Invalid price';

  @override
  String get invalidDiscountPrice => 'Invalid discount price';

  @override
  String get discountMustBeLowerThanOriginalPrice => 'Discount price must be lower than original price';

  @override
  String get wholesalePriceMustBeLowerThanRetailPrice => 'Wholesale price must be lower than retail price';

  @override
  String get invalidStock => 'Invalid stock';

  @override
  String get stockMustBeAtLeastWholesaleMinQuantity => 'Stock must be at least the wholesale minimum quantity';

  @override
  String get inventoryStockFieldLabel => 'Stock';

  @override
  String get invalidLowStockAlert => 'Invalid low-stock alert';

  @override
  String get addAtLeast1Media => 'Add at least 1 media item';

  @override
  String get descriptionMustBeAtLeast10Characters => 'Description must be at least 10 characters';

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
  String get freeShippingThresholdIsRequired => 'Free shipping threshold is required';

  @override
  String get invalidPreparationTime => 'Invalid preparation time';

  @override
  String get invalidMaxDeliveryDays => 'Invalid maximum delivery days';

  @override
  String get selectAtLeast1CargoCarrier => 'Select at least 1 cargo carrier';

  @override
  String get returnWindowCannotBeLessThan14Days => 'Return window cannot be less than 14 days';

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
  String smartDescriptionAccessories(Object brand, Object name, Object subCategory) {
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
  String get productAlreadyExistsOpeningEditStatus => 'Product exists, opening editor...';

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
  String get noBarcodeSkuHint => 'Barcode is optional. SKU will be auto-generated if empty.';

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
  String get minimumQuantityForWholesaleLabel => 'Minimum quantity for wholesale';

  @override
  String get wholesaleAppliesHint => 'Wholesale discount applies from this quantity';

  @override
  String get visibleOnlyToBusinessAccountsHint => 'Visible only to business accounts';

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
  String get manualDesiOverrideOptionalLabel => 'Manual desi override (optional)';

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
  String get sellerContractedCarrierOnlyLabel => 'Seller if contracted carrier only';

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
  String get returnAvailableAfterDeliveryMessage => 'Returns become available after delivery.';

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
  String get returnShippingTitle => 'Return Shipping';

  @override
  String get returnShippingBuyerMessage => 'You are responsible for the return shipping cost.\n\nThe courier fee is separate from your refund and may not be reimbursed.';

  @override
  String get returnShippingSellerMessage => 'The seller is responsible for the return shipping cost.';

  @override
  String get returnShippingContractedCarrierMessage => 'Use the seller\'s contracted return carrier.';

  @override
  String get returnShippingBuyerShipBackMessage => 'The courier fee is your responsibility and is separate from the refund.';

  @override
  String get returnShippingSellerShipBackMessage => 'The seller covers the return shipping cost.';

  @override
  String get returnShippingAcknowledgement => 'I understand the return shipping policy.';

  @override
  String get returnShippingPolicyLoading => 'Loading return shipping policy…';

  @override
  String returnShippingCarrierValue(Object carrier) {
    return 'Carrier: $carrier';
  }

  @override
  String get returnShippingVerifiedCarrierHelper => 'Use this verified contracted return carrier.';

  @override
  String get returnCarrierEnterHelperText => 'Enter the carrier used for this return shipment.';

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
  String get shippingResponsibilityContractCarrierLabel => 'Seller if contracted carrier';

  @override
  String get returnCarrierLabel => 'Return Carrier';

  @override
  String get returnImagesAdded => 'Images added';

  @override
  String get refundRejectedStatusLabel => 'Refund rejected';

  @override
  String get refundDecisionTitle => 'Refund decision';

  @override
  String get refundDecisionFullTitle => 'Full Refund';

  @override
  String get refundDecisionFullDescription => 'Refund the entire eligible amount.';

  @override
  String get refundDecisionFullRecommended => 'Recommended for damaged or defective items, wrong items, seller mistakes, or items never delivered.';

  @override
  String get refundDecisionPartialTitle => 'Partial Refund';

  @override
  String get refundDecisionPartialDescription => 'Refund only part of the eligible amount. A justification is required.';

  @override
  String get refundDecisionRejectTitle => 'Reject Refund';

  @override
  String get refundDecisionRejectDescription => 'Decline the refund request. A clear explanation is required.';

  @override
  String get refundPartialAmountLabel => 'Partial refund amount';

  @override
  String refundMaximumEligible(Object amount) {
    return 'Maximum eligible: $amount';
  }

  @override
  String get refundAmountValidationError => 'Enter an amount greater than zero and no more than the eligible refund.';

  @override
  String get refundDecisionReasonLabel => 'Reason';

  @override
  String get refundReasonNotSelected => 'Select a reason';

  @override
  String get refundSellerNotesLabel => 'Seller notes';

  @override
  String get refundNotesOptional => 'Optional';

  @override
  String get refundNotesRequired => 'Required';

  @override
  String get refundBuyerExplanationLabel => 'Buyer-visible explanation';

  @override
  String get refundBuyerExplanationHelper => 'Explain clearly why the refund is being declined.';

  @override
  String get refundOriginalOrderLabel => 'Original Order';

  @override
  String get refundSummaryRefundLabel => 'Refund';

  @override
  String get refundDifferenceLabel => 'Difference';

  @override
  String get refundDecisionBuyerTitle => 'Refund decision';

  @override
  String get refundDecisionLabel => 'Decision';

  @override
  String get refundSellerExplanationLabel => 'Seller explanation';

  @override
  String get refundReasonItemReturnedDamaged => 'Item returned damaged';

  @override
  String get refundReasonMissingAccessories => 'Missing accessories';

  @override
  String get refundReasonCustomerCausedDamage => 'Customer caused damage';

  @override
  String get refundReasonRestockingFee => 'Restocking fee';

  @override
  String get refundReasonPartialReturn => 'Partial return';

  @override
  String get refundReasonSellerMistake => 'Seller mistake';

  @override
  String get refundReasonWrongItem => 'Wrong item';

  @override
  String get refundReasonDefectiveProduct => 'Defective product';

  @override
  String get refundReasonItemNeverDelivered => 'Item never delivered';

  @override
  String get refundReasonOther => 'Other';

  @override
  String get returnStatusWaitingSellerConfirmation => 'Waiting for seller confirmation';

  @override
  String get returnStatusAutoReceived => 'Automatically received';

  @override
  String get returnStatusDispute => 'Return dispute';

  @override
  String get waitingForSellerInspectionTitle => 'Waiting for seller inspection';

  @override
  String waitingForSellerInspectionMessage(Object date) {
    return 'The seller has until $date to inspect the returned package. If no action is taken, the return will automatically continue.';
  }

  @override
  String get inspectionDeadlineTitle => 'Inspection deadline';

  @override
  String inspectionDaysRemaining(int days) {
    return '$days days remaining';
  }

  @override
  String get inspectionDeadlinePassed => 'Deadline passed. Automatic completion pending.';

  @override
  String get reportReturnProblemTitle => 'Report return problem';

  @override
  String get reportProblemButton => 'Report problem';

  @override
  String get disputeReasonLabel => 'Problem reason';

  @override
  String get disputeReasonPackageNotReceived => 'Package not received';

  @override
  String get disputeReasonWrongItemReturned => 'Wrong item returned';

  @override
  String get disputeReasonEmptyPackage => 'Empty package';

  @override
  String get disputeReasonDamagedDuringReturn => 'Damaged during return';

  @override
  String get disputeReasonTrackingIssue => 'Tracking issue';

  @override
  String get adminReturnDisputesTitle => 'Return disputes';

  @override
  String get adminReturnDisputesSubtitle => 'Review disputed marketplace returns';

  @override
  String get noReturnDisputes => 'No disputed returns';

  @override
  String get locationUpdatedSuccessfully => 'Location updated successfully';

  @override
  String get centersLoadError => 'Unable to load centers';

  @override
  String get noAppointments => 'No appointments.';

  @override
  String get noAppointmentsFound => 'No appointments found.';

  @override
  String appointmentsCount(Object count) {
    return '$count appointments';
  }

  @override
  String get any => 'Any';

  @override
  String get search => 'Search...';

  @override
  String get accessDenied => 'Access Denied';

  @override
  String get skip => 'Skip';

  @override
  String searchService(Object service) {
    return 'Search $service...';
  }

  @override
  String get petHotels => 'Pet Hotels';

  @override
  String noItemsYet(Object title) {
    return 'No $title yet';
  }

  @override
  String get noSavedPostsYet => 'No saved posts yet';

  @override
  String uploadedAt(Object date) {
    return 'Uploaded: $date';
  }

  @override
  String get productDetails => 'Product Details';

  @override
  String get servicesCouldNotBeLoaded => 'Services couldn\'t be loaded';

  @override
  String get veterinaryClinics => 'Veterinary clinics';

  @override
  String get noVeterinaryClinicsFound => 'No veterinary clinics found.';

  @override
  String get securePayment => 'Secure Payment';

  @override
  String get liveDriver => 'Live Driver';

  @override
  String get driver => 'Driver';

  @override
  String get myRides => 'My Rides';

  @override
  String get clientMessages => 'Client Messages';

  @override
  String get preVisitForm => 'Pre-visit form';

  @override
  String get vetRevenueTitle => 'Revenue';

  @override
  String get vetRevenueDescription => 'Verified payment and settlement data from completed veterinary transactions.';

  @override
  String get vetRevenueRange7Days => '7 days';

  @override
  String get vetRevenueRange30Days => '30 days';

  @override
  String get vetRevenueRange90Days => '90 days';

  @override
  String get vetRevenueRangeThisYear => 'This year';

  @override
  String get vetRevenueRangeAllTime => 'All time';

  @override
  String get vetRevenueGrossRevenue => 'Gross Revenue';

  @override
  String get vetRevenuePetsupoCommission => 'PetSupo Commission';

  @override
  String get vetRevenueNetRevenue => 'Net Revenue';

  @override
  String get vetRevenuePendingSettlement => 'Pending Settlement';

  @override
  String get vetRevenuePaidTransactions => 'Paid Transactions';

  @override
  String get vetRevenuePendingPayments => 'Pending Payments';

  @override
  String get vetRevenueRefunded => 'Refunded';

  @override
  String get vetRevenueExpiredOpportunities => 'Expired Opportunities';

  @override
  String get vetRevenueMissingFinancialData => 'Missing Financial Data';

  @override
  String vetRevenueMissingFinancialWarning(int count) {
    return '$count paid record(s) have missing or malformed financial data and are excluded from totals.';
  }

  @override
  String get vetRevenueMixedCurrencyWarning => 'Multiple currencies are present. Amounts are shown separately and are never converted or combined.';

  @override
  String get vetRevenueNoAppointmentsTitle => 'No appointments yet';

  @override
  String get vetRevenueNoAppointmentsMessage => 'Revenue analytics will appear when veterinary appointments are created.';

  @override
  String get vetRevenueNoRangeTitle => 'No records in this period';

  @override
  String get vetRevenueNoRangeMessage => 'Choose a wider date range to review earlier transactions.';

  @override
  String get vetRevenueLoadErrorTitle => 'Revenue data is unavailable';

  @override
  String get vetRevenueLoadErrorMessage => 'Check the connection and try again. Existing payment records were not changed.';

  @override
  String get vetRevenueRetry => 'Retry';

  @override
  String get vetRevenueTrendTitle => 'Revenue Trend';

  @override
  String get vetRevenueMixedCurrencyChartHidden => 'The combined trend is hidden because the selected period contains multiple currencies.';

  @override
  String get vetRevenueNoRecognizedRevenue => 'No verified paid revenue in this period.';

  @override
  String get vetRevenueTopServices => 'Top Services by Gross Revenue';

  @override
  String get vetRevenueTransactions => 'Transactions';

  @override
  String get vetRevenueUncategorized => 'Uncategorized';

  @override
  String get vetRevenueSearchHint => 'Search customer, pet, service or transaction';

  @override
  String get vetRevenueAllPayments => 'All payments';

  @override
  String get vetRevenuePaid => 'Paid';

  @override
  String get vetRevenuePending => 'Pending';

  @override
  String get vetRevenueExpired => 'Expired';

  @override
  String get vetRevenueMissingFinancial => 'Financial data missing';

  @override
  String get vetRevenueSortDate => 'Sort by date';

  @override
  String get vetRevenueSortDirection => 'Change sort direction';

  @override
  String get vetRevenueDate => 'Date';

  @override
  String get vetRevenueCustomer => 'Customer';

  @override
  String get vetRevenuePet => 'Pet';

  @override
  String get vetRevenueService => 'Service';

  @override
  String get vetRevenueGross => 'Gross';

  @override
  String get vetRevenueCommission => 'Commission';

  @override
  String get vetRevenueNet => 'Net';

  @override
  String get vetRevenuePayment => 'Payment';

  @override
  String get vetRevenueSettlement => 'Settlement';

  @override
  String get vetRevenueInvoice => 'Invoice';

  @override
  String get vetRevenueTransactionReference => 'Transaction reference';

  @override
  String get vetRevenueNoMatchingTransactions => 'No transactions match the current search and filter.';

  @override
  String vetRevenuePageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get vetWebOverviewSubtitle => 'Clinic performance and operational overview';

  @override
  String get vetWebAppointmentsSubtitle => 'Review and manage veterinary appointments';

  @override
  String get vetWebRevenueSubtitle => 'Verified payment, commission and settlement analytics';

  @override
  String get vetWebVeterinaryLabel => 'Veterinary';

  @override
  String get petShopsTitle => 'Pet Shops';

  @override
  String get searchPetShopsHint => 'Search pet shops';

  @override
  String get noPetShopsFound => 'No pet shops found';

  @override
  String get noPetShopsFoundDescription => 'Try another search or check again later.';

  @override
  String get loadingPetShops => 'Finding pet shops near you…';

  @override
  String get petShopsLoadError => 'Pet shops could not be loaded. Please try again.';

  @override
  String get retryButton => 'Retry';

  @override
  String get shopInformationTitle => 'Shop information';

  @override
  String get noShopDescriptionAvailable => 'No shop description is available.';

  @override
  String get locationNotAvailable => 'Location not available';

  @override
  String get getDirectionsLabel => 'Get directions';

  @override
  String get connectLabel => 'Connect';

  @override
  String get callLabel => 'Call';

  @override
  String get whatsappLabel => 'WhatsApp';

  @override
  String get websiteLabel => 'Website';

  @override
  String get signInToContactShop => 'Sign in to contact this shop.';

  @override
  String get petShopUnavailable => 'Shop unavailable';

  @override
  String get petShopUnavailableDescription => 'This pet shop is no longer available.';

  @override
  String get reviewsCouldNotBeLoaded => 'Reviews could not be loaded.';

  @override
  String get noProductsAvailableFromShop => 'No products available from this shop';

  @override
  String get petShopLocationNeededMessage => 'We use your location to show nearby pet shops';

  @override
  String get infoTitle => 'Info';

  @override
  String get processTitle => 'Process';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get contactTitle => 'Contact';

  @override
  String get openFullProfile => 'Open full profile';

  @override
  String get noShopCategoriesAvailable => 'No shop categories are available.';

  @override
  String get browseShopProductsDescription => 'Browse products available from this pet shop.';

  @override
  String get viewAllProducts => 'View all products';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get orContinueWith => 'or continue with';

  @override
  String get authenticationCancelled => 'Authentication cancelled';

  @override
  String get unableToSignIn => 'Unable to sign in';

  @override
  String get emailRegisteredWithAnotherProvider => 'This email is already registered with another sign-in method';

  @override
  String get completeYourProfile => 'Complete your profile';

  @override
  String get cityLabel => 'City';

  @override
  String get districtLabel => 'District';

  @override
  String get cityRequired => 'Please enter your city';

  @override
  String get districtRequired => 'Please enter your district';

  @override
  String get continueLabel => 'Continue';

  @override
  String get petTaxiRequestRideTab => 'Request Ride';

  @override
  String get petTaxiRidesSubtitle => 'Your upcoming and past Pet Taxi journeys';

  @override
  String get petTaxiFilterActive => 'Active & Upcoming';

  @override
  String get petTaxiFilterCompleted => 'Completed';

  @override
  String get petTaxiFilterCancelled => 'Cancelled';

  @override
  String get petTaxiNoRidesTitle => 'No Pet Taxi rides yet';

  @override
  String get petTaxiNoRidesDescription => 'Your Pet Taxi bookings will appear here after you request a ride.';

  @override
  String get petTaxiNoRidesInFilter => 'No rides in this category';

  @override
  String get petTaxiTryAnotherFilter => 'Choose another category to view your other rides.';

  @override
  String get petTaxiRidesLoading => 'Loading your Pet Taxi rides';

  @override
  String get petTaxiRidesLoadErrorTitle => 'Your rides could not be loaded';

  @override
  String get petTaxiRidesLoadErrorDescription => 'Check your connection and try again. Your bookings have not been changed.';

  @override
  String get petTaxiSignInRequiredTitle => 'Sign in to view your rides';

  @override
  String get petTaxiSignInRequiredDescription => 'Your Pet Taxi bookings are available after you sign in.';

  @override
  String get petTaxiProviderLabel => 'Provider';

  @override
  String get petTaxiProviderFallback => 'Pet Taxi provider';

  @override
  String get petTaxiDestinationLabel => 'Destination';

  @override
  String get petTaxiScheduleUnavailable => 'Schedule unavailable';

  @override
  String get petTaxiPriceUnavailable => 'Price pending';

  @override
  String get petTaxiStatusPending => 'Request pending';

  @override
  String get petTaxiStatusAwaitingPayment => 'Awaiting payment';

  @override
  String get petTaxiStatusConfirmedPaid => 'Confirmed and paid';

  @override
  String get petTaxiStatusPaymentFailed => 'Payment failed';

  @override
  String get petTaxiStatusRefundPending => 'Refund pending';

  @override
  String get petTaxiStatusRefunded => 'Refunded';

  @override
  String get petTaxiStatusDriverOnTheWay => 'Driver on the way';

  @override
  String get petTaxiStatusArrived => 'Driver arrived';

  @override
  String get petTaxiStatusPetPickedUp => 'Pet picked up';

  @override
  String get petTaxiStatusOnTrip => 'On the way';

  @override
  String get petTaxiStatusCompleted => 'Completed';

  @override
  String get petTaxiStatusCancelledByUser => 'Cancelled by you';

  @override
  String get petTaxiStatusCancelledByProvider => 'Cancelled by provider';

  @override
  String get petTaxiStatusUnknown => 'Status unavailable';

  @override
  String get petTaxiPaymentPaid => 'Paid';

  @override
  String get petTaxiPaymentPending => 'Payment processing';

  @override
  String get petTaxiPaymentFailed => 'Payment failed';

  @override
  String get petTaxiPaymentRefunded => 'Refunded';

  @override
  String get petTaxiPaymentUnpaid => 'Unpaid';

  @override
  String get webSubscriptionPaymentUnavailable => 'Payment is temporarily unavailable';

  @override
  String get webSubscriptionCatalogLoadFailed => 'Secure payment prices could not be loaded. Check your connection and try again.';

  @override
  String get webSubscriptionCatalogUnauthenticated => 'Sign in to load subscription prices and continue securely.';

  @override
  String get webSubscriptionCatalogFunctionNotFound => 'The secure payment service is not available in this app version. Please refresh and try again.';

  @override
  String get webSubscriptionCatalogConfigurationMissing => 'Secure payment configuration is temporarily unavailable. Please try again later.';

  @override
  String get webSubscriptionCatalogNetworkFailed => 'The secure payment service could not be reached. Check your connection and retry.';

  @override
  String get webSubscriptionCatalogMalformed => 'The secure payment service returned an invalid response. Please retry.';

  @override
  String get webSubscriptionThirtyDayAccess => '30 days of subscription access';

  @override
  String get webSubscriptionContinueSecurePayment => 'Continue to secure payment';

  @override
  String get webSubscriptionPaymentTerms => 'One-time payment for 30 days of access. No automatic card renewal.';

  @override
  String get webSubscriptionIsbankSecurePayment => 'Secure payment with İş Bank • 30-day access • No automatic renewal';

  @override
  String get webSubscriptionCheckoutFailed => 'Secure checkout could not be started. Please try again.';

  @override
  String get webSubscriptionVerifyingTitle => 'Verifying your payment';

  @override
  String get webSubscriptionVerifyingMessage => 'Please wait while the bank payment is verified securely.';

  @override
  String get webSubscriptionSuccessTitle => 'Subscription activated';

  @override
  String get webSubscriptionSuccessMessage => 'Your payment was verified and your 30-day subscription access is active.';

  @override
  String get webSubscriptionFailedTitle => 'Payment could not be verified';

  @override
  String get webSubscriptionFailedMessage => 'Your subscription was not activated. No unverified payment can grant access.';

  @override
  String get webSubscriptionCancelledTitle => 'Payment cancelled';

  @override
  String get webSubscriptionCancelledMessage => 'The payment was cancelled and your subscription was not changed.';

  @override
  String get webSubscriptionPendingTitle => 'Payment is still processing';

  @override
  String get webSubscriptionPendingMessage => 'The bank has not completed verification yet. This page will check again automatically.';

  @override
  String chatError(Object error) {
    return 'Chat error: $error';
  }

  @override
  String get bankAccountSettingsTitle => 'Bank Account';

  @override
  String get bankAccountSettingsSubtitle => 'This account will be used when PetSupo sends your business earnings.';

  @override
  String get bankAccountInfoNotice => 'Please make sure the account holder and IBAN exactly match your official bank account. Incorrect information may delay payouts.';

  @override
  String get bankAccountSectionTitle => 'Account Details';

  @override
  String get bankAccountHolderLabel => 'Account Holder';

  @override
  String get bankAccountBankNameLabel => 'Bank Name';

  @override
  String get bankAccountIbanLabel => 'IBAN';

  @override
  String get bankAccountBillingInfoLabel => 'Billing Information (optional)';

  @override
  String get bankAccountIbanInvalid => 'IBAN must start with TR followed by 24 digits.';

  @override
  String get bankAccountSaveSuccess => 'Bank account information saved.';

  @override
  String get diagnosticsSectionTitle => 'Diagnostics';

  @override
  String get diagnosticsSectionDescription => 'Internal diagnostics tools for queue inspection and upload testing.';

  @override
  String get diagnosticsThrowButton => 'Throw';

  @override
  String get diagnosticsTestButton => 'Test';

  @override
  String get diagnosticsUploadButton => 'Upload';

  @override
  String get diagnosticsRefreshButton => 'Refresh';

  @override
  String get diagnosticsClearButton => 'Clear';

  @override
  String dogCardAgeWithBreed(Object age, Object breed) {
    return '${age}y • $breed';
  }

  @override
  String dogCardAgeYears(Object age) {
    return '${age}y';
  }

  @override
  String dogCardVaccines(int count) {
    return '$count vaccines';
  }

  @override
  String get dogParkPremiumMembersOnly => 'This park is available for Premium members only.';

  @override
  String get favoritesExplorePlaymates => 'Go explore Playmates 💛';

  @override
  String get vetServicesAvailableAfterLogin => 'Vet services available after login';

  @override
  String get loadingAccount => 'Loading account...';

  @override
  String get noNotificationsForGuest => 'No notifications for Guest';

  @override
  String get loginForNotifications => 'Login to receive updates and alerts';

  @override
  String get offerDetailsTitle => 'Offer';

  @override
  String get offerDiscountOffLabel => 'OFF';

  @override
  String get offerUseCodeLabel => 'Use code:';

  @override
  String get offerUseThisOffer => 'Use This Offer';

  @override
  String get playdateScheduledAtLabel => 'Playdate will be scheduled at:';

  @override
  String get continueToScheduling => 'Continue to scheduling';

  @override
  String get orderCancellationTitle => 'Order Cancellation';

  @override
  String get preShipmentCancellationAvailable => 'This order has not been shipped and can still be cancelled.';

  @override
  String get cancelOrderButton => 'Cancel Order';

  @override
  String get cancelOrderTitle => 'Cancel Order?';

  @override
  String get cancelOrderConfirmation => 'Are you sure you want to cancel this order? The order has not been shipped yet.';

  @override
  String get cancelOrderRefundNotice => 'After cancellation, your payment will be refunded.';

  @override
  String get cancellationReasonLabel => 'Reason for cancellation';

  @override
  String get cancelReasonOrderedByMistake => 'Ordered by mistake';

  @override
  String get cancelReasonChangedMind => 'Changed my mind';

  @override
  String get cancelReasonDuplicateOrder => 'Duplicate order';

  @override
  String get cancelReasonOther => 'Other';

  @override
  String get cancellationReasonDetailsLabel => 'Cancellation reason details';

  @override
  String get cancellationRefundProcessing => 'Order cancelled. Your refund is processing.';

  @override
  String get cancellationShipmentAlreadyStarted => 'This order can no longer be cancelled because shipment has started.';

  @override
  String get cancelOrderFailed => 'The order could not be cancelled. Please try again.';

  @override
  String get cancellationRefundProcessingStatus => 'Cancellation requested · Refund processing';

  @override
  String get cancellationRefundFailedStatus => 'Cancellation refund needs attention';

  @override
  String get orderCancelledRefundCompleted => 'Order cancelled · Refund completed';

  @override
  String get foundPetDetailsTitle => 'Found Pet Details';

  @override
  String get viewOnMap => 'View on Map';

  @override
  String get contactReporter => 'Contact Reporter';

  @override
  String get foundPetReportedSuccess => 'Found pet reported successfully!';

  @override
  String errorSubmittingReport(Object error) {
    return 'Error submitting report: $error';
  }

  @override
  String get tapToSelectImage => 'Tap to select image';

  @override
  String get foundPetsSubtitle => 'Help found pets return home safely';

  @override
  String get searchByNameHint => 'Search by name...';

  @override
  String get noFoundPetsReportedYet => 'No found pets reported yet';

  @override
  String get reportedFoundPetsAppearHere => 'Reported found pets will appear here';

  @override
  String get lostPetDetailsTitle => 'Lost Pet Details';

  @override
  String get havePetInformationPrompt => 'Have information about this pet?';

  @override
  String get callOwner => 'Call Owner';

  @override
  String get emailOwner => 'Email Owner';

  @override
  String get lostPetReportedSuccess => 'Lost pet reported successfully!';

  @override
  String get lostPetsSubtitle => 'Help lost pets find their way home';

  @override
  String get noLostPetsReportedYet => 'No lost pets reported yet';

  @override
  String get reportedLostPetsAppearHere => 'Reported lost pets will appear here';

  @override
  String get searchUsersHint => 'Search users...';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get searchPetsAndUsers => 'Search pets & users';

  @override
  String get findPetLoversNearby => 'Find pet lovers around you';

  @override
  String get selectAtLeastOnePhotoOrVideo => 'Please select at least one photo/video';

  @override
  String errorCreatingPost(Object error) {
    return 'Error creating post: $error';
  }

  @override
  String get createPostTitle => 'Create Post';

  @override
  String get share => 'Share';

  @override
  String get addPhotosOrVideos => 'Add photos/videos';

  @override
  String get writeSomethingHint => 'Write something...';

  @override
  String get replyHint => 'Reply...';

  @override
  String get replySent => 'Reply sent';

  @override
  String get close => 'Close';

  @override
  String get videoStoriesComingSoon => 'Video stories are coming soon';

  @override
  String get petploreTitle => 'Petplore';

  @override
  String get explorePetMoments => 'Explore pet moments';

  @override
  String followersCount(int count) {
    return '$count Followers';
  }

  @override
  String followingCount(int count) {
    return '$count Following';
  }

  @override
  String get feed => 'Feed';

  @override
  String get saved => 'Saved';

  @override
  String get myPosts => 'My Posts';

  @override
  String get loginRequired => 'Login required';

  @override
  String genericError(Object error) {
    return 'Error: $error';
  }

  @override
  String get noPostsYet => 'No posts yet';

  @override
  String get noResults => 'No results';

  @override
  String get commentsTitle => 'Comments';

  @override
  String commentsError(Object error) {
    return 'Comments error: $error';
  }

  @override
  String get noCommentsYet => 'No comments yet';

  @override
  String get writeCommentHint => 'Write a comment...';

  @override
  String get postsTitle => 'Posts';

  @override
  String get storyUploaded => 'Story uploaded';

  @override
  String storyUploadFailed(Object error) {
    return 'Story upload failed: $error';
  }

  @override
  String get addStory => 'Add Story';

  @override
  String get storyDurationPrompt => 'Share a pet moment that lasts 24h';

  @override
  String get seeWhosNearby => 'See who’s nearby 👀!';

  @override
  String get telegramLab => 'Telegram Lab';

  @override
  String get telegramBotApiTest => 'Telegram Bot API Test';

  @override
  String get telegramTestInstructions => 'Press the button below to send a test message.';

  @override
  String get sendTelegramMessage => 'Send Telegram Message';

  @override
  String get telegramUsers => 'Telegram Users';

  @override
  String get termsLastUpdated => 'Last updated: May 09, 2025';

  @override
  String get termsIntroductionTitle => '1. Introduction';

  @override
  String get termsIntroductionBody => 'Welcome to PetSupo! By signing up, you agree to these Terms and Conditions. This app is designed to help you find playmates for your dogs, connect with other pet owners, and access pet-related services. These terms govern your use of the app and services provided by PetSupo.';

  @override
  String get termsResponsibilitiesTitle => '2. User Responsibilities';

  @override
  String get termsResponsibilitiesBody => '- You must be at least 13 years old to use this app.\n- You are responsible for maintaining the confidentiality of your account and password.\n- You agree not to use the app for any unlawful or prohibited activities.\n- You must provide accurate and up-to-date information during registration.';

  @override
  String get termsPrivacyTitle => '3. Data Collection and Privacy';

  @override
  String get termsPrivacyBody => 'We collect personal data such as your username, email, location, and pet information to provide our services. In accordance with the Turkish Personal Data Protection Law (KVKK No. 6698) and international laws (e.g., GDPR), we:\n- Obtain explicit consent before collecting or processing your data.\n- Use your data only for the purposes stated (e.g., finding playmates, providing location-based services).\n- Implement security measures to protect your data.\n- Allow you to access, correct, or delete your data upon request. To exercise your rights, contact us at info@petsupo.com.';

  @override
  String get termsUserContentTitle => '4. User Content';

  @override
  String get termsUserContentBody => '- You retain ownership of any content you upload (e.g., photos, descriptions).\n- By uploading content, you grant PetSupo a non-exclusive, royalty-free license to use, display, and distribute your content within the app.\n- You must not upload content that is illegal, offensive, or violates the rights of others.';

  @override
  String get termsLiabilityTitle => '5. Limitation of Liability';

  @override
  String get termsLiabilityBody => 'PetSupo is not liable for any damages arising from your use of the app, including but not limited to interactions with other users or pets. We do not guarantee the accuracy of information provided by other users.';

  @override
  String get termsGoverningLawTitle => '6. Governing Law';

  @override
  String get termsGoverningLawBody => 'These Terms and Conditions are governed by the laws of the Republic of Turkey. Any disputes arising from your use of the app will be resolved in the courts of Istanbul, Turkey, unless otherwise required by international law (e.g., GDPR for EU users).';

  @override
  String get termsChangesTitle => '7. Changes to Terms';

  @override
  String get termsChangesBody => 'We may update these Terms and Conditions from time to time. You will be notified of significant changes via email or in-app notifications. Continued use of the app after changes constitutes your acceptance of the new terms.';

  @override
  String get termsContactTitle => '8. Contact Us';

  @override
  String get termsContactBody => 'If you have any questions or concerns about these Terms and Conditions, please contact us at info@petsupo.com.';

  @override
  String get pendingBusinessApprovals => 'Pending Business Approvals';

  @override
  String get invalidRequest => 'Invalid request';

  @override
  String get noPendingBusinessRequests => 'No pending business requests';

  @override
  String riskCount(Object count) {
    return '$count RISK';
  }

  @override
  String get verifiedLabel => 'VERIFIED';

  @override
  String get approve => 'Approve';

  @override
  String get suspend => 'Suspend';

  @override
  String get restore => 'Restore';

  @override
  String get businessApproved => 'Business approved';

  @override
  String get businessRejected => 'Business rejected';

  @override
  String get businessSuspended => 'Business suspended';

  @override
  String get businessRestored => 'Business restored';

  @override
  String actionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String dashboardError(Object error) {
    return 'Dashboard Error:\n$error';
  }

  @override
  String get platformOverview => 'Platform Overview';

  @override
  String get adminActivity => 'Admin Activity';

  @override
  String get developerTools => 'Developer Tools';

  @override
  String get testTelegramBotApi => 'Test Telegram Bot API';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsDescription => 'Crash reports & startup diagnostics';

  @override
  String get telegramUsersDescription => 'View connected Telegram users';

  @override
  String adminActivityError(Object error) {
    return 'Activity error:\n$error';
  }

  @override
  String get noAdminActivity => 'No admin activity yet';

  @override
  String get diagnosticReport => 'Diagnostic Report';

  @override
  String get diagnosticReportNotFound => 'Diagnostic report not found';

  @override
  String get reopen => 'Reopen';

  @override
  String get resolve => 'Resolve';

  @override
  String get ignore => 'Ignore';

  @override
  String get stackTrace => 'Stack Trace';

  @override
  String get breadcrumbsLogs => 'Breadcrumbs / Logs';

  @override
  String get noLogs => 'No logs';

  @override
  String get rawJson => 'Raw JSON';

  @override
  String get diagnosticReports => 'Diagnostic Reports';

  @override
  String get filters => 'Filters';

  @override
  String get noDiagnosticReports => 'No diagnostic reports';

  @override
  String reasonValue(Object value) {
    return 'Reason: $value';
  }

  @override
  String featureValue(Object value) {
    return 'Feature: $value';
  }

  @override
  String platformValue(Object value) {
    return 'Platform: $value';
  }

  @override
  String versionValue(Object value) {
    return 'Version: $value';
  }

  @override
  String receivedValue(Object value) {
    return 'Received: $value';
  }

  @override
  String messageValue(Object value) {
    return 'Message: $value';
  }

  @override
  String createdValue(Object value) {
    return 'Created: $value';
  }

  @override
  String get adminActions => 'Admin Actions';

  @override
  String get moderationCase => 'Moderation Case';

  @override
  String targetValue(Object value) {
    return 'Target: $value';
  }

  @override
  String reportsCount(Object count) {
    return 'Reports: $count';
  }

  @override
  String riskScoreValue(Object value) {
    return 'Risk Score: $value';
  }

  @override
  String priorityValue(Object value) {
    return 'Priority: $value';
  }

  @override
  String firestoreError(Object error) {
    return 'Firestore error: $error';
  }

  @override
  String get refundReview => 'Refund Review';

  @override
  String appointmentIdValue(Object value) {
    return 'Appointment ID: $value';
  }

  @override
  String paymentStatusValue(Object value) {
    return 'Payment Status: $value';
  }

  @override
  String refundStatusValue(Object value) {
    return 'Refund Status: $value';
  }

  @override
  String appointmentTimeValue(Object value) {
    return 'Appointment Time: $value';
  }

  @override
  String cancellationTimeValue(Object value) {
    return 'Cancellation Time: $value';
  }

  @override
  String hoursBeforeAppointmentValue(Object value) {
    return 'Hours Before Appointment: $value';
  }

  @override
  String businessValue(Object value) {
    return 'Business: $value';
  }

  @override
  String userValue(Object value) {
    return 'User: $value';
  }

  @override
  String petValue(Object value) {
    return 'Pet: $value';
  }

  @override
  String amountPaidValue(Object value) {
    return 'Amount Paid: $value';
  }

  @override
  String refundReasonValue(Object value) {
    return 'Refund Reason: $value';
  }

  @override
  String refundErrorValue(Object value) {
    return 'Refund Error: $value';
  }

  @override
  String get approveRefund => 'Approve Refund';

  @override
  String get rejectRefund => 'Reject Refund';

  @override
  String refundReviewFailed(Object error) {
    return 'Refund review failed: $error';
  }

  @override
  String get note => 'Note';

  @override
  String refundQueueError(Object error) {
    return 'Refund queue error: $error';
  }

  @override
  String get refundRequests => 'Refund Requests';

  @override
  String get noPendingRefundRequests => 'No pending refund requests';

  @override
  String get reportsTitle => 'Reports';

  @override
  String appointmentValue(Object value) {
    return 'Appointment: $value';
  }

  @override
  String cancelledValue(Object value) {
    return 'Cancelled: $value';
  }

  @override
  String amountValue(Object value) {
    return 'Amount: $value';
  }

  @override
  String statusValue(Object value) {
    return 'Status: $value';
  }

  @override
  String get confirmViolation => 'Confirm Violation';

  @override
  String get markClean => 'Mark Clean';

  @override
  String get businessMetrics => 'Business Metrics';

  @override
  String get businessSearch => 'Business Search';

  @override
  String get searchBusinessNameHint => 'Search business name...';

  @override
  String get suspendedLabel => 'Suspended';

  @override
  String get filterByStatus => 'Filter by status';

  @override
  String get complaintCenter => 'Complaint Center';

  @override
  String get noData => 'No data';

  @override
  String get noComplaintsFound => 'No complaints found';

  @override
  String categoryValue(Object value) {
    return 'Category: $value';
  }

  @override
  String get complaintDetail => 'Complaint Detail';

  @override
  String severityValue(Object value) {
    return 'Severity: $value';
  }

  @override
  String get evidence => 'Evidence';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get fraudAnalytics => 'Fraud Analytics';

  @override
  String get errorLoadingAnalytics => 'Error loading analytics';

  @override
  String get adminMapMonitor => 'Admin Map Monitor';

  @override
  String get platformMetrics => 'Platform Metrics';

  @override
  String get noMetricsData => 'No metrics data';

  @override
  String lastUpdatedValue(Object value) {
    return 'Last updated: $value';
  }

  @override
  String get revenueTitle => 'Revenue';

  @override
  String get noRevenueData => 'No revenue data';

  @override
  String get auditLogs => 'Audit Logs';

  @override
  String verifiedValue(Object value) {
    return 'Verified: $value';
  }

  @override
  String documentNumberValue(Object value) {
    return 'Document no: $value';
  }

  @override
  String get open => 'Open';

  @override
  String get petTaxiDocument => 'Pet Taxi Document';

  @override
  String get openPdf => 'Open PDF';

  @override
  String get suspendedBusinesses => 'Suspended Businesses';

  @override
  String get noDataReceived => 'No data received';

  @override
  String get noSuspendedBusinesses => 'No suspended businesses';

  @override
  String get subscriptionDetails => 'Subscription Details';

  @override
  String planValue(Object value) {
    return 'Plan: $value';
  }

  @override
  String priceValue(Object value) {
    return 'Price: $value';
  }

  @override
  String get cancelSubscription => 'Cancel Subscription';

  @override
  String get expireNow => 'Expire Now';

  @override
  String get makePremium => '⭐ Make Premium';

  @override
  String get upgradeToPartner => '👑 Upgrade to PetSupo Partner';

  @override
  String get downgradeToPremium => '⬇ Downgrade to Premium';

  @override
  String get extendThirtyDays => 'Extend 30 Days';

  @override
  String get subscriptionManagement => 'Subscription Management';

  @override
  String get searchUserIdHint => 'Search userId...';

  @override
  String get loadingSubscription => 'Loading subscription...';

  @override
  String get feedbackDetail => 'Feedback Detail';

  @override
  String ratingValue(Object value) {
    return 'Rating: $value';
  }

  @override
  String contextValue(Object value) {
    return 'Context: $value';
  }

  @override
  String get messageLabel => 'Message';

  @override
  String get userFeedback => 'User Feedback';

  @override
  String get noPayoutsFound => 'No payouts found';

  @override
  String get payoutManagement => 'Payout Management';

  @override
  String get readyLabel => 'Ready';

  @override
  String get searchPayoutsHint => 'Search order, seller, buyer, ref...';

  @override
  String get payoutMarkedReady => 'Payout marked as ready';

  @override
  String get confirmPayout => 'Confirm Payout';

  @override
  String get bankTransferReference => 'Bank Transfer Reference';

  @override
  String get bankReferenceHint => 'EFT / FAST / Bank Ref';

  @override
  String get payoutMarkedPaid => 'Payout marked as paid';

  @override
  String sellerValue(Object value) {
    return 'Seller: $value';
  }

  @override
  String buyerValue(Object value) {
    return 'Buyer: $value';
  }

  @override
  String referenceValue(Object value) {
    return 'Ref: $value';
  }

  @override
  String get markReady => 'Mark Ready';

  @override
  String get markPaid => 'Mark Paid';

  @override
  String openEntity(Object id, Object type) {
    return 'Open $type: $id';
  }

  @override
  String get globalAdminSearchHint => 'Search users, dogs, businesses, reports, complaints...';

  @override
  String get globalAdminSearch => 'Global Admin Search';

  @override
  String get notAuthenticated => 'Not authenticated';

  @override
  String get adoptionRequestNotFound => 'Adoption request not found';

  @override
  String get backToRequests => 'Back to requests';

  @override
  String get messageApplicant => 'Message Applicant';

  @override
  String get unknownPet => 'Unknown Pet';

  @override
  String get adoptionRequest => 'Adoption Request';

  @override
  String get waitingForOwnerResponse => 'Waiting for owner response';

  @override
  String get doneWithIcon => '✅ Done';

  @override
  String failedWithIcon(Object error) {
    return '❌ Failed: $error';
  }

  @override
  String get availablePets => 'Available Pets';

  @override
  String get petsCouldNotBeLoaded => 'Pets could not be loaded.';

  @override
  String get noPetsAvailable => 'No pets available';

  @override
  String get noImages => 'No images';

  @override
  String get viewAvailablePets => 'View Available Pets';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get writeReviewFirst => 'Please write a review first';

  @override
  String get reviewSubmitted => 'Review submitted';

  @override
  String get reviewExperienceHint => 'Tell others about your experience';

  @override
  String get submitReview => 'Submit Review';

  @override
  String get adoptionCenterDetails => 'Adoption Center Details';

  @override
  String get adoptionServices => 'Adoption Services';

  @override
  String get petTypes => 'Pet Types';

  @override
  String get workingDays => 'Working Days';

  @override
  String get vetCheckIncluded => 'Vet Check Included';

  @override
  String get homeVisitAvailable => 'Home Visit Available';

  @override
  String get transportSupport => 'Transport Support';

  @override
  String get fosterSupport => 'Foster Support';

  @override
  String get media => 'Media';

  @override
  String get logo => 'Logo';

  @override
  String get approvedBusinesses => 'Approved Businesses';

  @override
  String get searchBusinessesHint => 'Search businesses...';

  @override
  String get noApprovedBusinesses => 'No approved businesses';

  @override
  String get basic => 'Basic';

  @override
  String get disclaimerAccepted => 'Disclaimer accepted';

  @override
  String get mismatchDetected => '⚠ Mismatch detected';

  @override
  String get languageCodeTr => 'TR';

  @override
  String get languageCodeEn => 'EN';

  @override
  String get riskFlags => 'Risk Flags';

  @override
  String get noRiskFlags => 'No risk flags';

  @override
  String get adminNotes => 'Admin Notes';

  @override
  String get adminNotesHint => 'Add internal moderation notes...';

  @override
  String get saveNotes => 'Save Notes';

  @override
  String get adminNotesSaved => 'Admin notes saved ✅';

  @override
  String saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get noQuickRepliesFound => 'No quick replies found';

  @override
  String get quickReplies => 'Quick Replies';

  @override
  String get chatFailedToLoad => 'Chat failed to load';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get typeMessageHint => 'Type a message...';

  @override
  String get noRequests => 'No requests';

  @override
  String phoneValue(Object value) {
    return 'Phone: $value';
  }

  @override
  String genderValue(Object value) {
    return 'Gender: $value';
  }

  @override
  String petStatusUpdated(Object name) {
    return '$name status updated';
  }

  @override
  String statusUpdateFailed(Object error) {
    return 'Status update failed: $error';
  }

  @override
  String get deletePetQuestion => 'Delete pet?';

  @override
  String deletePetConfirmation(Object name) {
    return 'Are you sure you want to delete $name? This action cannot be undone.';
  }

  @override
  String petDeleted(Object name) {
    return '$name deleted';
  }

  @override
  String deleteFailedWithError(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get searchPetsHint => 'Search pets';

  @override
  String get noAdoptablePetsYet => 'No adoptable pets yet';

  @override
  String get addAdoptablePetsDescription => 'Add pets that are available for adoption and manage their status here.';

  @override
  String failedToLoadPets(Object error) {
    return 'Failed to load pets:\n$error';
  }

  @override
  String breedValue(Object value) {
    return 'Breed: $value';
  }

  @override
  String ageValue(Object value) {
    return 'Age: $value';
  }

  @override
  String get edit => 'Edit';

  @override
  String get noAdoptionPetsYet => 'No Adoption Pets Yet';

  @override
  String get addPetsForAdoption => 'Add pets that are available for adoption.';

  @override
  String get editAdoptionCenter => 'Edit Adoption Center';

  @override
  String get pleaseAddCoverImage => 'Please add cover image';

  @override
  String get addGalleryImages => 'Add Gallery Images';

  @override
  String get petNameLabel => 'Pet Name';

  @override
  String get ageMonthsLabel => 'Age (months)';

  @override
  String get visible => 'Visible';

  @override
  String failedToSetCover(Object error) {
    return 'Failed to set cover: $error';
  }

  @override
  String get uploadPetMedia => 'Upload Pet Media';

  @override
  String uploadedPercent(Object percent) {
    return '$percent% uploaded';
  }

  @override
  String get noMediaYet => 'No media yet';

  @override
  String get cover => 'Cover';

  @override
  String get adoptionCenterInfo => 'Adoption Center Info';

  @override
  String get centerNameLabel => 'Center name';

  @override
  String get instagram => 'Instagram';

  @override
  String get address => 'Address';

  @override
  String get saveCenterInfo => 'Save Center Info';

  @override
  String get latestAdoptionApplications => 'Latest adoption applications';

  @override
  String get viewAll => 'View All';

  @override
  String get tapForMoreDetails => 'Tap for more details';

  @override
  String get setAvailable => 'Set Available';

  @override
  String get setReserved => 'Set Reserved';

  @override
  String get setAdopted => 'Set Adopted';

  @override
  String get setPaused => 'Set Paused';

  @override
  String get clients => 'Clients';

  @override
  String get searchPetOrOwnerHint => 'Search by pet or owner name';

  @override
  String get couldNotLoadClients => 'Could not load clients.';

  @override
  String get addClient => 'Add Client';

  @override
  String get ownerNameLabel => 'Owner Name';

  @override
  String get notes => 'Notes';

  @override
  String get price => 'Price';

  @override
  String get saveClient => 'Save Client';

  @override
  String get petOwnerNamesRequired => 'Pet name and owner name are required';

  @override
  String get clientSaved => 'Client saved';

  @override
  String lastGrooming(Object date) {
    return 'Last grooming: $date';
  }

  @override
  String get noClientsYet => 'No clients yet';

  @override
  String get addFirstGroomingClient => 'Add your first grooming client to start tracking visits.';

  @override
  String get clientProfile => 'Client Profile';

  @override
  String get openAppointmentBooking => 'Open appointment booking from business page';

  @override
  String get groomingHistory => 'Grooming History';

  @override
  String get ownerNotFound => 'Owner not found';

  @override
  String get signInRequired => 'Sign in required';

  @override
  String get addGroomingVisit => 'Add Grooming Visit';

  @override
  String get serviceVisitTitle => 'Service / Visit Title';

  @override
  String get saveVisit => 'Save Visit';

  @override
  String get visitSaved => 'Visit saved';

  @override
  String get editClient => 'Edit Client';

  @override
  String get salonSchedule => 'Salon Schedule';

  @override
  String get manageGroomingAppointments => 'Manage grooming appointments';

  @override
  String amountTry(Object amount) {
    return '$amount TRY';
  }

  @override
  String get uploadGroomingMedia => 'Upload Grooming Media';

  @override
  String get add => 'Add';

  @override
  String get afterPlatformCommission => 'After platform commission';

  @override
  String get recentAppointments => 'Recent Appointments';

  @override
  String get latestGroomingRequests => 'Latest grooming requests and sessions';

  @override
  String appointmentError(Object error) {
    return 'Appointment error: $error';
  }

  @override
  String get noGroomingAppointmentsYet => 'No grooming appointments yet';

  @override
  String get deleteService => 'Delete Service';

  @override
  String get deleteServiceConfirmation => 'Are you sure you want to delete this service?';

  @override
  String get serviceDeleted => 'Service deleted';

  @override
  String get deleteFailed => 'Delete failed';

  @override
  String get availabilityUpdated => 'Availability updated';

  @override
  String updateFailed(Object error) {
    return 'Update failed: $error';
  }

  @override
  String get availability => 'Availability';

  @override
  String get capacityBookingExplanation => 'Capacity is used by the booking functions to prevent overlapping stays beyond available rooms.';

  @override
  String get roomCapacity => 'Room Capacity';

  @override
  String get maximumPetsRooms => 'Maximum pets / rooms';

  @override
  String currentCapacity(int count) {
    return 'Current capacity: $count';
  }

  @override
  String get saveAvailability => 'Save Availability';

  @override
  String get checkIn => 'Check In';

  @override
  String get completeStay => 'Complete Stay';

  @override
  String alreadyStatus(Object status) {
    return 'Already $status';
  }

  @override
  String bookingUpdated(Object status) {
    return 'Booking updated: $status';
  }

  @override
  String bookingError(Object error) {
    return 'Booking error: $error';
  }

  @override
  String get hotelProfile => 'Hotel Profile';

  @override
  String get hotelOverview => 'Hotel Overview';

  @override
  String get pendingRequests => 'Pending Requests';

  @override
  String get uploadHotelMedia => 'Upload Hotel Media';

  @override
  String get proposeFinalPrice => 'Propose Final Price';

  @override
  String get editProposedPrice => 'Edit Proposed Price';

  @override
  String get notifyCustomerConfirmation => 'This will notify the customer.';

  @override
  String get finalPrice => 'Final price';

  @override
  String get customerMustPayBeforeTrip => 'The customer must pay this amount in the app before the trip can start.';

  @override
  String get sendPrice => 'Send Price';

  @override
  String get petTaxiOverview => 'Pet Taxi Overview';

  @override
  String get driverOnline => 'Driver Online';

  @override
  String get serviceDetailsSaveFailed => 'Service details could not be saved.';

  @override
  String get priceDeterminedAfterExamination => 'Leave empty if the final price is determined after examination.';

  @override
  String get editing => 'Editing';

  @override
  String get setPriceDurationDescription => 'Set the price and estimated duration shown to pet owners.';

  @override
  String get serviceDetailsBeforeBooking => 'These details help pet owners understand the service before booking.';

  @override
  String get addCustomService => 'Add custom service';

  @override
  String get create => 'Create';

  @override
  String get paymentSuccessful => 'Payment successful';

  @override
  String get paymentCancelled => 'Payment cancelled';

  @override
  String paymentFailedWithError(Object error) {
    return 'Payment failed: $error';
  }

  @override
  String get appointmentPayment => 'Appointment Payment';

  @override
  String get done => 'Done';

  @override
  String get payNow => 'Pay Now';

  @override
  String get titleLabel => 'Title';

  @override
  String get noQuickRepliesYet => 'No quick replies yet';

  @override
  String get quickRepliesDescription => 'Create reusable responses for common client questions.';

  @override
  String get inbox => 'Inbox';

  @override
  String inboxError(Object error) {
    return 'Inbox error:\n$error';
  }

  @override
  String get emergency => 'Emergency';

  @override
  String get noClientMessagesYet => 'No client messages yet';

  @override
  String get clientMessagesDescription => 'When pet owners contact your clinic, conversations will appear here.';

  @override
  String get passportNumberFormat => 'Passport number must contain only uppercase letters, numbers, - or /';

  @override
  String get medicalProfileUpdated => 'Medical profile updated';

  @override
  String profileUpdateFailed(Object error) {
    return 'Failed to update profile: $error';
  }

  @override
  String get confirmMicrochipNumber => 'Confirm Microchip Number';

  @override
  String get review => 'Review';

  @override
  String get saveAnyway => 'Save Anyway';

  @override
  String get medicalProfile => 'Medical Profile';

  @override
  String get saveMedicalProfile => 'Save Medical Profile';

  @override
  String get ownerProfileUpdated => 'Owner profile updated';

  @override
  String get ownerProfile => 'Owner Profile';

  @override
  String couldNotSaveVisit(Object error) {
    return 'Could not save visit: $error';
  }

  @override
  String get deleteVisit => 'Delete Visit';

  @override
  String get deleteVisitConfirmation => 'Delete this visit from the medical record?';

  @override
  String couldNotDeleteVisit(Object error) {
    return 'Could not delete visit: $error';
  }

  @override
  String get deleteVisitTooltip => 'Delete visit';

  @override
  String get addVaccine => 'Add Vaccine';

  @override
  String get vaccine => 'Vaccine';

  @override
  String get reminder => 'Reminder';

  @override
  String get notifyBeforeNextDueDate => 'Notify before the next due date';

  @override
  String get saveVaccine => 'Save Vaccine';

  @override
  String get patientNotFound => 'Patient not found';

  @override
  String get editOwnerProfile => 'Edit Owner Profile';

  @override
  String get ownerEmergencyContactDetails => 'Owner and emergency contact details';

  @override
  String get editMedicalProfile => 'Edit Medical Profile';

  @override
  String get clinicalVeterinaryInformation => 'Clinical and veterinary information';

  @override
  String get visits => 'Visits';

  @override
  String get vaccines => 'Vaccines';

  @override
  String get ownerInformation => 'Owner Information';

  @override
  String get visitsUnavailable => 'Visits unavailable';

  @override
  String visitsError(Object error) {
    return 'Visits error: $error';
  }

  @override
  String get followUp => 'Follow-up';

  @override
  String get editVisitTooltip => 'Edit visit';

  @override
  String get editMedicalNotes => 'Edit Medical Notes';

  @override
  String get medicalNotes => 'Medical notes';

  @override
  String get editVaccineTooltip => 'Edit vaccine';

  @override
  String get deleteVaccineTooltip => 'Delete vaccine';

  @override
  String get deleteVaccine => 'Delete Vaccine';

  @override
  String get deleteVaccineConfirmation => 'Are you sure you want to delete this vaccine record?';

  @override
  String get editVaccine => 'Edit Vaccine';

  @override
  String get vaccineName => 'Vaccine name';

  @override
  String get updateVaccine => 'Update Vaccine';

  @override
  String get completeVaccine => 'Complete Vaccine';

  @override
  String get clientNote => 'Client note';

  @override
  String get businessInfo => 'Business Info';

  @override
  String get clinicName => 'Clinic name';

  @override
  String get emergencyServiceEnabled => 'Emergency service enabled';

  @override
  String get saveBusinessInfo => 'Save Business Info';

  @override
  String get openAppointmentsTab => 'Open Appointments tab from top';

  @override
  String get viewAllAppointments => 'View all appointments';

  @override
  String get checkConnectionTryAgain => 'Please check your connection and try again.';

  @override
  String get editServiceTooltip => 'Edit service';

  @override
  String get deleteServiceTooltip => 'Delete service';

  @override
  String get noServicesAddedYet => 'No services added yet';

  @override
  String get addFirstServiceDescription => 'Add your first service to make it available for pet owners.';

  @override
  String get servicesPricing => 'Services & Pricing';

  @override
  String get addService => 'Add Service';

  @override
  String get noServicesYet => 'No services yet.';

  @override
  String servicePriceDuration(Object price, Object currency, Object duration) {
    return '$price $currency • $duration min';
  }

  @override
  String get serviceTitle => 'Service title';

  @override
  String get durationMinutes => 'Duration (min)';

  @override
  String get requireDeposit => 'Require deposit';

  @override
  String get depositAmount => 'Deposit amount (₺)';

  @override
  String get featured => 'Featured';

  @override
  String get active => 'Active';

  @override
  String get photoUploadedSuccessfully => 'Photo uploaded successfully';

  @override
  String get photoDeleted => 'Photo deleted';

  @override
  String get coverImageUpdated => 'Cover image updated';

  @override
  String get galleryManagement => 'Gallery Management';

  @override
  String get coverImage => 'Cover Image';

  @override
  String get tapToChangeCover => 'Tap to change cover';

  @override
  String get uploadCoverImage => 'Upload cover image';

  @override
  String get tapToUploadClinicCover => 'Tap to upload clinic cover photo';

  @override
  String get galleryPhotos => 'Gallery Photos';

  @override
  String get noGalleryPhotosYet => 'No gallery photos yet';

  @override
  String get uploadClinicPhotosDescription => 'Upload clinic photos to improve trust and visibility.';

  @override
  String get uploadFirstPhoto => 'Upload First Photo';

  @override
  String get dragToReorderGallery => 'Drag to reorder gallery photos';

  @override
  String get patients => 'Patients';

  @override
  String get back => 'Back';

  @override
  String get patientRecords => 'Patient Records';

  @override
  String shownCount(int count) {
    return '$count shown';
  }

  @override
  String get searchPetOwnerBreed => 'Search pet, owner, or breed';

  @override
  String get clear => 'Clear';

  @override
  String preVisitSettingsLoadFailed(Object error) {
    return 'Failed to load pre-visit settings: $error';
  }

  @override
  String get preVisitSettingsSaved => 'Pre-visit form settings saved';

  @override
  String settingsSaveFailed(Object error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get preVisitForms => 'Pre-visit forms';

  @override
  String get servicePreVisitForms => 'Service pre-visit forms';

  @override
  String get serviceMedicalIntakeDescription => 'Each service can have its own medical intake questions.';

  @override
  String get servicesCouldNotBeLoadedPeriod => 'Services could not be loaded.';

  @override
  String get noActiveServicesForForms => 'No active services yet. Add services before creating forms.';

  @override
  String get enableForService => 'Enable for this service';

  @override
  String get onlyServiceAsksQuestions => 'Only this service will ask these questions.';

  @override
  String get noQuestionsForService => 'No questions for this service yet.';

  @override
  String get question => 'Question';

  @override
  String get questionExample => 'e.g. Has your pet eaten today?';

  @override
  String get remove => 'Remove';

  @override
  String get questionType => 'Question type';

  @override
  String get textType => 'Text';

  @override
  String get longTextType => 'Long text';

  @override
  String get yesNoType => 'Yes / No';

  @override
  String get singleChoice => 'Single choice';

  @override
  String get multipleChoice => 'Multiple choice';

  @override
  String get numberType => 'Number';

  @override
  String get requiredLabel => 'Required';

  @override
  String get options => 'Options';

  @override
  String optionNumber(int number) {
    return 'Option $number';
  }

  @override
  String get addOption => 'Add option';

  @override
  String get clinicSchedule => 'Clinic Schedule';

  @override
  String get appointments => 'Appointments';

  @override
  String totalCount(int count) {
    return '$count total';
  }

  @override
  String get services => 'Services';

  @override
  String get addServiceFlowComingNext => 'Add service flow coming next';

  @override
  String get clinicServices => 'Clinic Services';

  @override
  String get manageVisibleVetServices => 'Manage visible veterinary services';

  @override
  String get clinicSettings => 'Clinic Settings';

  @override
  String get emergencyAvailabilitySaveFailed => 'Failed to save emergency availability';

  @override
  String managementNotAvailable(Object label) {
    return '$label management is not available yet';
  }

  @override
  String loadError(Object error) {
    return 'Load error: $error';
  }

  @override
  String get workingHoursSaved => 'Working hours saved';

  @override
  String saveError(Object error) {
    return 'Save error: $error';
  }

  @override
  String get workingHours => 'Working Hours';

  @override
  String get clinicWorkingHours => 'Clinic Working Hours';

  @override
  String get manageOpeningDays => 'Manage opening days and appointment availability';

  @override
  String get editGroomyProfile => 'Edit Groomy Profile';

  @override
  String get groomyDetails => 'Groomy Details';

  @override
  String get homeService => 'Home Service';

  @override
  String get pickupService => 'Pickup Service';

  @override
  String get photos => 'Photos';

  @override
  String get complete => 'Complete';

  @override
  String get awaitingPayment => 'Awaiting payment';

  @override
  String appointmentUpdated(Object status) {
    return 'Appointment updated: $status';
  }

  @override
  String get galleryComingSoon => 'Gallery coming soon';

  @override
  String get editHotelProfile => 'Edit Hotel Profile';

  @override
  String pricePerNight(Object price) {
    return '$price₺ / night';
  }

  @override
  String bookStayAt(Object hotel) {
    return 'Book stay • $hotel';
  }

  @override
  String get hotelCareNotesHint => 'Feeding, medication, or care notes';

  @override
  String get requestBooking => 'Request Booking';

  @override
  String get checkoutAfterCheckin => 'Check-out must be after check-in';

  @override
  String get hotelBookingRequestSent => 'Your hotel booking request was sent.';

  @override
  String get noGalleryImagesYet => 'No gallery images yet';

  @override
  String get petHotelDetails => 'Pet Hotel Details';

  @override
  String get amenities => 'Amenities';

  @override
  String get petTaxiDetails => 'Pet Taxi Details';

  @override
  String get petTaxiManualReviewNotice => 'Your Pet Taxi application will not be published until documents are manually reviewed and approved.';

  @override
  String get transportationLawNotice => 'Transportation laws may vary by city/country. Businesses are responsible for complying with local transportation, insurance, and tax regulations.';

  @override
  String get legalDocumentsPrivacyNotice => 'Legal documents are stored for business owner and admin review only. They are not shown to public users.';

  @override
  String get savePetTaxiDetails => 'Save Pet Taxi Details';

  @override
  String get driverVehicle => 'Driver & Vehicle';

  @override
  String get vehicleType => 'Vehicle type';

  @override
  String get preview => 'Preview';

  @override
  String get editPetShopProfile => 'Edit PetShop Profile';

  @override
  String get petShopDetails => 'PetShop Details';

  @override
  String get shopTypes => 'Shop Types';

  @override
  String get priceLevel => 'Price Level';

  @override
  String get low => 'Low';

  @override
  String get mid => 'Mid';

  @override
  String get high => 'High';

  @override
  String get delivery => 'Delivery';

  @override
  String get hasDelivery => 'Has Delivery';

  @override
  String get offers => 'Offers';

  @override
  String get hasOffers => 'Has Offers';

  @override
  String get rejectedBusinesses => 'Rejected Businesses';

  @override
  String get noRejectedBusinesses => 'No rejected businesses';

  @override
  String get inheritedFromRegistration => 'Inherited from base registration';

  @override
  String get veterinaryDetails => 'Veterinary Details';

  @override
  String get licenseReviewNotice => 'This number will be reviewed during verification.';

  @override
  String get licenseExpiryDateNumbered => '12. License Expiry Date';

  @override
  String get workingDaysNumbered => '20. Working Days';

  @override
  String get acceptedAnimalTypesNumbered => '24. Accepted Animal Types';

  @override
  String get confirmInformationAccurate => '41. I confirm that the information provided is accurate';

  @override
  String get agreeDisplayInformation => '42. I agree to display my information in the app';

  @override
  String get agreeDisplayReviews => '43. I agree to user reviews being displayed';

  @override
  String get acceptPartnershipTerms => '44. I accept PetSupo partnership terms';

  @override
  String get submitVeterinaryDetails => 'Submit Veterinary Details';

  @override
  String get adoptionCenterTemporary => 'Adoption Center (TEMP)';

  @override
  String reviewsCountParenthesized(Object count) {
    return ' ($count reviews)';
  }

  @override
  String get messageSendingTimedOut => 'Message sending timed out';

  @override
  String messageFailed(Object error) {
    return 'Message failed: $error';
  }

  @override
  String get chatCreating => 'Chat is creating...';

  @override
  String get startChatting => 'Start chatting 👋';

  @override
  String get writeMessageHint => 'Write message...';

  @override
  String get noChatsYet => 'No chats yet';

  @override
  String get startChattingWithPetOwners => 'Start chatting with pet owners and make new friends for your pet 👋';

  @override
  String get failedToLoadChats => 'Failed to load chats';

  @override
  String get personalChatsCouldNotLoad => 'Personal chats could not be loaded.';

  @override
  String get businessConversations => 'Business Conversations';

  @override
  String get signInToUseChats => 'Sign in to use chats';

  @override
  String get chats => 'Chats';

  @override
  String get connectWithPetOwners => 'Connect with pet owners';

  @override
  String get noChatsFound => 'No chats found';

  @override
  String get tryAnotherKeyword => 'Try another keyword or username.';

  @override
  String get messages => 'Messages';

  @override
  String get failedToLoadMessages => 'Failed to load messages';

  @override
  String get noConversationsYet => 'No conversations yet';

  @override
  String get userInboxEmptyDescription => 'When you contact a business,\nyour conversations will appear here.';

  @override
  String get medicalRecords => 'Medical Records';

  @override
  String get vaccinesVisitsAndTreatments => 'Vaccines, visits and treatments';

  @override
  String amountInTry(Object amount) {
    return '$amount TRY';
  }

  @override
  String get reportDialogTitle => 'Report';

  @override
  String get reportSelectReasonError => 'Please select a reason';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonAbuse => 'Abuse / harassment';

  @override
  String get reportReasonScam => 'Scam';

  @override
  String get reportReasonFakeProfile => 'Fake profile';

  @override
  String get reportReasonInappropriateContent => 'Inappropriate content';

  @override
  String get reportReasonAnimalSafety => 'Animal safety';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportReasonFieldLabel => 'Reason';

  @override
  String get reportAdditionalDetailsHint => 'Additional details (optional)';

  @override
  String get reportSubmitButton => 'Submit report';

  @override
  String get reportSubmittedSuccess => 'Report submitted. Thank you for helping keep the community safe.';

  @override
  String get reportAlreadyReported => 'You\'ve already reported this - it\'s pending review.';

  @override
  String get reportRateLimited => 'Too many reports submitted recently. Please try again later.';

  @override
  String get reportTargetGone => 'This item no longer exists.';

  @override
  String get reportUnauthenticated => 'Please sign in to submit a report.';

  @override
  String get reportNetworkError => 'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String get reportGenericSuccess => 'Report submitted.';

  @override
  String get reportGenericError => 'Something went wrong. Please try again.';

  @override
  String get reportMenuUser => 'Report user';

  @override
  String get reportMenuPost => 'Report post';

  @override
  String get reportMenuComment => 'Report comment';

  @override
  String get reportMenuBusiness => 'Report business';

  @override
  String get adminReportsTitle => 'Reports';

  @override
  String get adminReportsTabPending => 'Pending';

  @override
  String get adminReportsTabApproved => 'Approved';

  @override
  String get adminReportsTabRejected => 'Rejected';

  @override
  String adminReportsLoadError(Object error) {
    return 'Error loading reports: $error';
  }

  @override
  String adminReportsEmpty(Object status) {
    return 'No $status reports';
  }

  @override
  String get moderationPermissionDenied => 'You don\'t have permission to do this.';

  @override
  String get moderationNotFound => 'This report or target could not be found.';

  @override
  String get moderationAlreadyReviewed => 'This report has already been reviewed.';

  @override
  String get moderationNetworkError => 'Network error. Please try again.';

  @override
  String get moderationNotesLabel => 'Notes (optional)';

  @override
  String get moderationCancel => 'Cancel';

  @override
  String get moderationConfirm => 'Confirm';

  @override
  String get moderationUnknownTargetType => 'Unknown target type - cannot moderate.';

  @override
  String get moderationReportApproved => 'Report approved.';

  @override
  String get moderationReportApprovedNoTarget => 'Report approved (target no longer exists - no action taken).';

  @override
  String get moderationRejectReportTitle => 'Reject report';

  @override
  String get moderationReportRejected => 'Report rejected.';

  @override
  String get moderationRestoreTargetTitle => 'Restore target';

  @override
  String get moderationTargetRestored => 'Target restored.';

  @override
  String get moderationTargetGone => 'This target no longer exists';

  @override
  String moderationOwnerLabel(Object name) {
    return 'Owner: $name';
  }

  @override
  String moderationReporterLabel(Object name) {
    return 'Reporter: $name';
  }

  @override
  String moderationReasonLabel(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get moderationApproveButton => 'Approve';

  @override
  String get moderationRejectButton => 'Reject';

  @override
  String get moderationRestoreButton => 'Restore';

  @override
  String moderationReviewedByLabel(Object name) {
    return 'Reviewed by $name';
  }

  @override
  String moderationActionLabel(Object action) {
    return 'action: $action';
  }

  @override
  String get moderationChooseAction => 'Choose moderation action';

  @override
  String get moderationApproveApply => 'Approve & apply';

  @override
  String get moderationNoOtherReports => 'No other reports on this target';

  @override
  String get moderationHistorySectionTitle => 'Report history & moderation timeline';

  @override
  String get suspendedAccountTitle => 'Your account has been suspended';

  @override
  String get suspendedAccountDefaultReason => 'This account was suspended for violating our community guidelines. If you believe this is a mistake, please contact support.';

  @override
  String get suspendedAccountSignOut => 'Sign out';

  @override
  String get payoutEligibleTab => 'Eligible';

  @override
  String get payoutBatchesTab => 'Batches';

  @override
  String get payoutExceptionsTab => 'Exceptions';

  @override
  String get payoutSelectAllEligible => 'Select all eligible sellers';

  @override
  String get payoutCreateBatch => 'Create payout batch';

  @override
  String payoutBatchCreated(Object batchNumber) {
    return 'Batch $batchNumber created';
  }

  @override
  String payoutOperationFailed(Object details) {
    return 'Payout operation failed. $details';
  }

  @override
  String get payoutLoadFailed => 'Payout data could not be loaded.';

  @override
  String get payoutNoExceptions => 'No payout exceptions';

  @override
  String get payoutDateFilter => 'Payment period';

  @override
  String get payoutToday => 'Today';

  @override
  String get payoutYesterday => 'Yesterday';

  @override
  String get payoutThisWeek => 'This week';

  @override
  String get payoutLastWeek => 'Last week';

  @override
  String get payoutThisMonth => 'This month';

  @override
  String get payoutValidBankOnly => 'Valid bank account';

  @override
  String get payoutUnknownSeller => 'Seller information unavailable';

  @override
  String get payoutBankMissing => 'Bank missing';

  @override
  String get payoutIncludedOrders => 'Included orders';

  @override
  String get payoutPeriod => 'Period';

  @override
  String get payoutGrossTotal => 'Gross total';

  @override
  String get payoutCommissionTotal => 'Commission total';

  @override
  String get payoutNetPayable => 'Net payable';

  @override
  String get payoutNoBatches => 'No payout batches';

  @override
  String get payoutSellers => 'sellers';

  @override
  String get payoutExportXlsx => 'Export XLSX';

  @override
  String get payoutValid => 'Valid';

  @override
  String get payoutBlocked => 'Blocked';

  @override
  String get payoutMissingBusiness => 'Missing business';

  @override
  String get payoutMissingAccountHolder => 'Missing account holder';

  @override
  String get payoutMissingIban => 'Missing IBAN';

  @override
  String get payoutInvalidIban => 'Invalid IBAN';

  @override
  String get payoutMissingBankName => 'Missing bank name';

  @override
  String get payoutNonPositiveAmount => 'Net amount must be positive';

  @override
  String get payoutSettlementIncomplete => 'Settlement incomplete';

  @override
  String get payoutCommissionUnknown => 'Commission requires review';

  @override
  String get payoutCustomerPaid => 'Customer paid';

  @override
  String get payoutSellerNetNotCalculated => 'Seller net: not calculated';

  @override
  String get payoutExcludedFromPayout => 'Excluded from payout';

  @override
  String get payoutRefundedOrCancelled => 'Refunded or cancelled order';

  @override
  String get payoutAlreadyBatched => 'Already assigned to a batch';

  @override
  String get payoutAlreadyPaid => 'Already paid';

  @override
  String get payoutUnsupportedCurrency => 'Unsupported currency';

  @override
  String get payoutIneligible => 'Payout is not eligible';

  @override
  String get payoutStatusFilter => 'Payout status';

  @override
  String get payoutSettlementFilter => 'Settlement status';

  @override
  String get payoutBatchFilter => 'Batch assignment';

  @override
  String get payoutIncludedInBatch => 'Included in batch';

  @override
  String get payoutNotIncludedInBatch => 'Not included in batch';

  @override
  String get payoutSellerFilter => 'Seller / business';

  @override
  String get payoutBankFilter => 'Bank';

  @override
  String get payoutMinimumAmount => 'Minimum payout';

  @override
  String get payoutMaximumAmount => 'Maximum payout';

  @override
  String get payoutCustomRange => 'Custom range';

  @override
  String get financeOverviewTab => 'Overview';

  @override
  String get financeWaitingTab => 'Waiting';

  @override
  String get financeEligibleSellers => 'Eligible sellers';

  @override
  String get financeEligibleRecords => 'Eligible records';

  @override
  String get financeWaitingSellers => 'Waiting sellers';

  @override
  String get financeWaitingRecords => 'Waiting records';

  @override
  String get financeWaitingAmount => 'Waiting amount';

  @override
  String get financeBlockedRecords => 'Blocked records';

  @override
  String get financeExceptionCount => 'Exceptions';

  @override
  String get financeTodaySales => 'Today\'s sales';

  @override
  String get financeTodayCommission => 'Today\'s commission';

  @override
  String get financeTodayRefunds => 'Today\'s refunds';

  @override
  String get financeTodayEligible => 'Today\'s eligible';

  @override
  String get financeTodayPaid => 'Today\'s paid';

  @override
  String get financeOutstandingLiability => 'Outstanding liability';

  @override
  String get financeMonthlyPlatformRevenue => 'Monthly platform revenue';

  @override
  String get financeNextEligibilityDate => 'Next eligible date';

  @override
  String get financeDaysRemaining => 'Days remaining';

  @override
  String get financeOldestWaitingRecord => 'Oldest waiting record';

  @override
  String get financeAmountEligibleNext => 'Amount becoming eligible next';

  @override
  String get financeSendForReview => 'Send for review';

  @override
  String get financeApproveBatch => 'Approve';

  @override
  String get financeRejectBatch => 'Reject batch';

  @override
  String get sellerFinanceTitle => 'Finance & Earnings';

  @override
  String get sellerFinanceDetails => 'Details';

  @override
  String get sellerFinanceAvailable => 'Available balance';

  @override
  String get sellerFinanceWaiting => 'Waiting balance';

  @override
  String get sellerFinanceProcessing => 'Pending / processing';

  @override
  String get sellerFinancePaidThisMonth => 'Paid this month';

  @override
  String get sellerFinanceTotalEarnings => 'Total earnings';

  @override
  String get sellerFinanceBlocked => 'Blocked amount';

  @override
  String get sellerFinanceBankBlocked => 'Your payout is blocked because your bank account information is incomplete.';

  @override
  String get sellerFinanceUpdateBank => 'Update bank account';

  @override
  String get sellerFinanceWaitingExplanation => 'Earnings become eligible 21 days after successful payment.';

  @override
  String get sellerFinanceWaitingSchedule => 'Waiting schedule';

  @override
  String get sellerFinanceLastPayout => 'Last payout';

  @override
  String get sellerFinanceOrders => 'orders';

  @override
  String get sellerFinanceAppointments => 'appointments';

  @override
  String get sellerFinanceBookings => 'bookings';

  @override
  String get sellerFinanceRides => 'rides';

  @override
  String get sellerFinanceRequests => 'requests';

  @override
  String get financeRecommendedAction => 'Recommended action';

  @override
  String get financeOpenSeller => 'Open seller';

  @override
  String get financeTomorrowEligible => 'Tomorrow becoming eligible';

  @override
  String get financeNext7Days => 'Next 7 days';

  @override
  String get financeNext30Days => 'Next 30 days';

  @override
  String get financeEstimatedPayable => 'Estimated payable';

  @override
  String get financeStartProcessing => 'Start processing';

  @override
  String get sellerFinanceEstimatedNext => 'Estimated next payout';

  @override
  String get sellerFinanceTimeline => 'Payout timeline';

  @override
  String get sellerFinanceTimelineValue => 'Paid → Waiting (21 days) → Eligible → Included in batch → Transferred → Completed';

  @override
  String get sellerFinanceEligibleRecords => 'Eligible records';

  @override
  String get sellerFinancePayoutHistory => 'Payout history';

  @override
  String get sellerFinanceExceptions => 'Exceptions';

  @override
  String get financeMarkFailed => 'Mark failed';

  @override
  String get financeFailureReason => 'Failure reason';

  @override
  String get userProfileCreatorProgram => 'Creator Program';

  @override
  String get userProfileOpenCreatorDashboard => 'Creator Dashboard';

  @override
  String get creatorDashboardTitle => 'Creator Dashboard';

  @override
  String get creatorWelcomeBack => 'Welcome back';

  @override
  String get creatorLevelLabel => 'Creator Level';

  @override
  String get creatorCurrentCampaign => 'Current campaign';

  @override
  String get creatorReferralCodeLabel => 'Referral Code';

  @override
  String get creatorReferralLinkLabel => 'Referral Link';

  @override
  String get creatorCopyCode => 'Copy Code';

  @override
  String get creatorCopyLink => 'Copy Link';

  @override
  String get creatorReferralCodeCopied => 'Referral code copied';

  @override
  String get creatorReferralLinkCopied => 'Referral link copied';

  @override
  String get creatorQualifiedUsers => 'Qualified Users';

  @override
  String get creatorVerifiedPartners => 'Verified Partners';

  @override
  String get creatorPendingRewards => 'Pending Rewards';

  @override
  String get creatorPaidRewards => 'Paid Rewards';

  @override
  String get creatorRecentActivity => 'Recent Activity';

  @override
  String get creatorNoActivityYet => 'No activity yet';

  @override
  String get creatorNoActivityMessage => 'Once someone uses your referral link, activity will show up here.';

  @override
  String get creatorUpcomingPayout => 'Upcoming Payout';

  @override
  String get creatorEstimatedPayout => 'Estimated payout';

  @override
  String get creatorPayoutDate => 'Payout date';

  @override
  String get creatorPayoutMethod => 'Payout method';

  @override
  String get creatorOpenFullDashboard => 'Open Full Dashboard';

  @override
  String get creatorOpenFullDashboardHint => 'See detailed charts, analytics and full reporting on the web';

  @override
  String get creatorPerformanceOverview => 'Performance Overview';

  @override
  String get creatorTotalClicks => 'Total Clicks';

  @override
  String get creatorRegistrations => 'Registrations';

  @override
  String get creatorConversionRate => 'Conversion Rate';

  @override
  String get creatorRewardBreakdown => 'Reward Breakdown';

  @override
  String get creatorPayoutHistory => 'Payout History';

  @override
  String get creatorAnalytics => 'Analytics';

  @override
  String get creatorReferralsTab => 'Referrals';

  @override
  String get creatorRewardsTab => 'Rewards';

  @override
  String get creatorFilters => 'Filters';

  @override
  String get creatorExport => 'Export';

  @override
  String get creatorTimeframe7d => '7 days';

  @override
  String get creatorTimeframe30d => '30 days';

  @override
  String get creatorTimeframe90d => '90 days';

  @override
  String get creatorTimeframe12m => '12 months';

  @override
  String get creatorSignInRequiredTitle => 'Sign in required';

  @override
  String get creatorSignInRequiredMessage => 'Sign in to view your Creator Dashboard';

  @override
  String get creatorAccessDeniedTitle => 'Creator access required';

  @override
  String get creatorAccessDeniedMessage => 'This dashboard is only available to approved PetSupo creators.';

  @override
  String get creatorGoToSignIn => 'Go to sign in';

  @override
  String get creatorBadgesAchievements => 'Badges & Achievements';

  @override
  String get creatorProgressToNextLevelPrefix => 'Progress to';

  @override
  String get creatorTotalEarned => 'Total earned';

  @override
  String get creatorShareYourLink => 'Share Your Referral Link';

  @override
  String get creatorStatusPaid => 'Paid';

  @override
  String get creatorStatusScheduled => 'Scheduled';

  @override
  String get creatorExportComingSoon => 'Export is coming soon';

  @override
  String get creatorFiltersComingSoon => 'Advanced filters are coming soon';

  @override
  String get creatorStatusLabel => 'Status';

  @override
  String get creatorStatusActive => 'Active';

  @override
  String get creatorStatusInactive => 'Inactive';

  @override
  String get creatorSampleData => 'Sample data';

  @override
  String get creatorOpenDashboardFailed => 'Couldn\'t open the dashboard. Please try again.';

  @override
  String get referralCodeOptionalLabel => 'Referral code (optional)';

  @override
  String get referralCodeInvalid => 'That referral code is unavailable. You can continue without it.';
}
