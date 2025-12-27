import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('tr')
  ];

  /// Message shown when user is not logged in and is redirected to login page
  ///
  /// In en, this message translates to:
  /// **'User not logged in. Redirecting to login...'**
  String get userNotLoggedIn;

  /// Error message when user info fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading user info: {error}'**
  String errorLoadingUserInfo(Object error);

  /// Error message when dog data fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading dogs: {error}'**
  String errorLoadingDogs(Object error);

  /// Validation message for empty username
  ///
  /// In en, this message translates to:
  /// **'Username cannot be empty'**
  String get usernameCannotBeEmpty;

  /// Success message for profile update
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// Error message when updating dog fails
  ///
  /// In en, this message translates to:
  /// **'Error updating dog: {error}'**
  String errorUpdatingDog(Object error);

  /// Error message when account deletion fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting account: {error}'**
  String errorDeletingAccount(Object error);

  /// Success message for account deletion
  ///
  /// In en, this message translates to:
  /// **'Account deleted.'**
  String get accountDeleted;

  /// Error message during logout
  ///
  /// In en, this message translates to:
  /// **'Error during logout: {error}'**
  String errorDuringLogout(Object error);

  /// Success message for sending adoption request
  ///
  /// In en, this message translates to:
  /// **'Adoption request sent for {dogName}!'**
  String adoptionRequestSent(Object dogName);

  /// Label for user's own profile
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// Label for viewing another user's profile
  ///
  /// In en, this message translates to:
  /// **'User Profile'**
  String get userProfile;

  /// Section title for profile details
  ///
  /// In en, this message translates to:
  /// **'Profile Information'**
  String get profileInformation;

  /// Label for user's dogs section
  ///
  /// In en, this message translates to:
  /// **'My Dogs'**
  String get myDogs;

  /// Label for dogs available for adoption section
  ///
  /// In en, this message translates to:
  /// **'Dogs Available for Adoption'**
  String get dogsAvailableForAdoption;

  /// Button label for editing profile
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// Label for username field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// Label for email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// Placeholder for optional phone number field
  ///
  /// In en, this message translates to:
  /// **'Enter phone number (optional)'**
  String get enterPhoneNumberOptional;

  /// Button label for deleting account
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// Confirmation message for account deletion
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? This action cannot be undone.'**
  String get deleteAccountConfirmation;

  /// Button label for updating profile
  ///
  /// In en, this message translates to:
  /// **'Update Profile'**
  String get updateProfile;

  /// Tooltip for edit profile button
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTooltip;

  /// Tooltip for delete account button
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTooltip;

  /// Tooltip for logout button
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutTooltip;

  /// Message when no dogs are available for adoption
  ///
  /// In en, this message translates to:
  /// **'No dogs available for adoption.'**
  String get noDogsAvailableForAdoption;

  /// Label for unknown user
  ///
  /// In en, this message translates to:
  /// **'Unknown User'**
  String get unknownUser;

  /// Label for missing information
  ///
  /// In en, this message translates to:
  /// **'Not Provided'**
  String get notProvided;

  /// Message when user has not added any dogs
  ///
  /// In en, this message translates to:
  /// **'No dogs added yet.'**
  String get noDogsAddedYet;

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Barky Matches'**
  String get appTitle;

  /// Message shown while user data is loading
  ///
  /// In en, this message translates to:
  /// **'Loading user data...'**
  String get loadingUserData;

  /// Welcome message for the app
  ///
  /// In en, this message translates to:
  /// **'Welcome to Barky Matches!'**
  String get welcomeToBarkyMatches;

  /// Part of welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTo;

  /// Part of welcome message, app name
  ///
  /// In en, this message translates to:
  /// **'Barky Matches!'**
  String get barkyMatches;

  /// Welcome message for returning user
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {username}!'**
  String welcomeBack(Object username);

  /// Greeting message for user
  ///
  /// In en, this message translates to:
  /// **'Hello, {username}!'**
  String helloMessage(Object username);

  /// Title for sign-in page
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInTitle;

  /// Title for sign-up page
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpTitle;

  /// Button label for signing in
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signInButton;

  /// Button label for signing up
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpButton;

  /// Button label for guest login
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// Label for email input field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for username input field
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// Label for phone number input field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

  /// Label for password input field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// Label for confirm password input field
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPasswordLabel;

  /// Label for remember me checkbox
  ///
  /// In en, this message translates to:
  /// **'Remember Me'**
  String get rememberMeLabel;

  /// Label for forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordLabel;

  /// Label for terms and conditions checkbox
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms and Conditions'**
  String get termsAndConditionsLabel;

  /// Label for news and updates checkbox
  ///
  /// In en, this message translates to:
  /// **'Receive news and updates'**
  String get receiveNewsLabel;

  /// Validation message for empty email
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// Validation message for invalid email
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get emailInvalid;

  /// Validation message for empty username
  ///
  /// In en, this message translates to:
  /// **'Please enter your username'**
  String get usernameRequired;

  /// Validation message for empty phone number
  ///
  /// In en, this message translates to:
  /// **'Please enter your phone number'**
  String get phoneRequired;

  /// Validation message for short phone number
  ///
  /// In en, this message translates to:
  /// **'Phone number must be at least 10 digits'**
  String get phoneMinDigits;

  /// Validation message for empty password
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// Validation message for invalid password
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters, including both letters and numbers'**
  String get passwordValidation;

  /// Validation message for mismatched passwords
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// Validation message for empty confirm password
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get confirmPasswordRequired;

  /// Validation message for unchecked terms
  ///
  /// In en, this message translates to:
  /// **'You must agree to the Terms and Conditions'**
  String get termsRequired;

  /// Title for forgot password dialog
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordDialogTitle;

  /// Message for forgot password dialog
  ///
  /// In en, this message translates to:
  /// **'Please enter your email to reset your password.'**
  String get forgotPasswordDialogMessage;

  /// Button label for sending password reset
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendButton;

  /// Success message for password reset email
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent to {email}'**
  String passwordResetSent(Object email);

  /// Link text for sign-up option
  ///
  /// In en, this message translates to:
  /// **'Don’t have an account? Sign Up'**
  String get noAccountSignUp;

  /// Link text for sign-in option
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get haveAccountSignIn;

  /// Error message for non-existent user
  ///
  /// In en, this message translates to:
  /// **'No user found with this email. Please register.'**
  String get userNotFound;

  /// Error message for incorrect password
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get incorrectPassword;

  /// Validation message for incomplete form
  ///
  /// In en, this message translates to:
  /// **'Please fill all fields correctly'**
  String get fillAllFields;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String errorOccurred(Object error);

  /// Title for email verification page
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get verifyEmailTitle;

  /// Success message for sending verification code
  ///
  /// In en, this message translates to:
  /// **'A verification code has been sent to {email}'**
  String verificationCodeSent(Object email);

  /// Label for verification code input
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit Code'**
  String get enterCodeLabel;

  /// Button label for verifying code
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// Message prompting sign-in for Playmate feature
  ///
  /// In en, this message translates to:
  /// **'Please Sign In to access Playmate'**
  String get signInToAccessPlaymate;

  /// Message prompting sign-in for Find Friends feature
  ///
  /// In en, this message translates to:
  /// **'Please Sign In to find friends'**
  String get signInToFindFriends;

  /// Button label for adding a dog
  ///
  /// In en, this message translates to:
  /// **'Add Your Dog'**
  String get addYourDog;

  /// Label for dog name input field
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameLabel;

  /// Validation message for empty dog name
  ///
  /// In en, this message translates to:
  /// **'Please enter your dog\'s name'**
  String get pleaseEnterDogName;

  /// Hint for breed selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Breed'**
  String get selectBreedHint;

  /// Validation message for empty breed selection
  ///
  /// In en, this message translates to:
  /// **'Please select a breed'**
  String get pleaseSelectBreed;

  /// Label for dog age input field
  ///
  /// In en, this message translates to:
  /// **'Age *'**
  String get ageLabel;

  /// Validation message for empty dog age
  ///
  /// In en, this message translates to:
  /// **'Please enter your dog\'s age'**
  String get pleaseEnterDogAge;

  /// Validation message for invalid dog age
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid age'**
  String get pleaseEnterValidAge;

  /// Hint for gender selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGenderHint;

  /// Validation message for empty gender selection
  ///
  /// In en, this message translates to:
  /// **'Please select a gender'**
  String get pleaseSelectGender;

  /// Hint for health status selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Health Status'**
  String get selectHealthStatusHint;

  /// Validation message for empty health status selection
  ///
  /// In en, this message translates to:
  /// **'Please select a health status'**
  String get pleaseSelectHealthStatus;

  /// Label for neutered status input
  ///
  /// In en, this message translates to:
  /// **'Neutered *'**
  String get neuteredLabel;

  /// Label for affirmative option
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// Label for negative option
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// Validation message for empty neutered status
  ///
  /// In en, this message translates to:
  /// **'Please specify if the dog is neutered'**
  String get pleaseSpecifyNeutered;

  /// Label for dog traits input
  ///
  /// In en, this message translates to:
  /// **'Traits *'**
  String get traitsLabel;

  /// Validation message for empty traits selection
  ///
  /// In en, this message translates to:
  /// **'Please select at least one trait'**
  String get pleaseSelectAtLeastOneTrait;

  /// Hint for owner gender selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Owner Gender'**
  String get selectOwnerGenderHint;

  /// Validation message for empty owner gender selection
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get pleaseSelectOwnerGender;

  /// Label for image upload section
  ///
  /// In en, this message translates to:
  /// **'Upload Images'**
  String get uploadImagesLabel;

  /// Button label for picking image from gallery
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get pickFromGallery;

  /// Button label for taking photo
  ///
  /// In en, this message translates to:
  /// **'Take a Photo'**
  String get takePhoto;

  /// Label for adoption availability checkbox
  ///
  /// In en, this message translates to:
  /// **'Available for Adoption'**
  String get availableForAdoption;

  /// Label for dog description input
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// Placeholder for dog description input
  ///
  /// In en, this message translates to:
  /// **'Enter a description here...'**
  String get descriptionPlaceholder;

  /// Label for dog color input
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get colorLabel;

  /// Label for dog weight input
  ///
  /// In en, this message translates to:
  /// **'Weight (kg)'**
  String get weightLabel;

  /// Hint for collar type selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Collar Type'**
  String get selectCollarTypeHint;

  /// Label for clothing color input
  ///
  /// In en, this message translates to:
  /// **'Clothing Color'**
  String get clothingColorLabel;

  /// Label for lost dog location input
  ///
  /// In en, this message translates to:
  /// **'Lost Location *'**
  String get lostLocationLabel;

  /// Label for found dog location input
  ///
  /// In en, this message translates to:
  /// **'Found Location *'**
  String get foundLocationLabel;

  /// Label for contact info input
  ///
  /// In en, this message translates to:
  /// **'Contact Info *'**
  String get contactInfoLabel;

  /// Button label for editing dog
  ///
  /// In en, this message translates to:
  /// **'Edit Dog'**
  String get editDog;

  /// Button label for saving changes
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Error message for duplicate dog name
  ///
  /// In en, this message translates to:
  /// **'A dog with the name {name} already exists!'**
  String dogNameExists(Object name);

  /// Validation message for missing location
  ///
  /// In en, this message translates to:
  /// **'Location is required to add a dog.'**
  String get locationRequired;

  /// Error message for image upload failure
  ///
  /// In en, this message translates to:
  /// **'Error uploading image: {error}'**
  String errorUploadingImage(Object error);

  /// Error message for adding dog failure
  ///
  /// In en, this message translates to:
  /// **'Error adding dog: {error}'**
  String errorAddingDog(Object error);

  /// Validation message for incomplete required fields
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields correctly'**
  String get pleaseFillRequiredFields;

  /// Button label for adding dog
  ///
  /// In en, this message translates to:
  /// **'Add Dog'**
  String get addDogButton;

  /// Title for add dog page
  ///
  /// In en, this message translates to:
  /// **'Add Dog'**
  String get dogDetailsAddTitle;

  /// Title for edit dog page
  ///
  /// In en, this message translates to:
  /// **'Edit Dog'**
  String get dogDetailsEditTitle;

  /// Label for dog name in details view
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dogDetailsNameLabel;

  /// Label for dog age in details view
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get dogDetailsAgeLabel;

  /// Label for dog description in details view
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get dogDetailsDescriptionLabel;

  /// Label for dog gender in details view
  ///
  /// In en, this message translates to:
  /// **'Gender:'**
  String get dogDetailsGenderLabel;

  /// Label for dog health status in details view
  ///
  /// In en, this message translates to:
  /// **'Health Status:'**
  String get dogDetailsHealthLabel;

  /// Label for dog traits in details view
  ///
  /// In en, this message translates to:
  /// **'Traits:'**
  String get dogDetailsTraitsLabel;

  /// Label for owner gender in details view
  ///
  /// In en, this message translates to:
  /// **'Owner Gender:'**
  String get dogDetailsOwnerGenderLabel;

  /// Male gender option for dog details
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get dogDetailsGenderMale;

  /// Female gender option for dog details
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get dogDetailsGenderFemale;

  /// Healthy status option for dog details
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get dogDetailsHealthHealthy;

  /// Needs Care status option for dog details
  ///
  /// In en, this message translates to:
  /// **'Needs Care'**
  String get dogDetailsHealthNeedsCare;

  /// Under Treatment status option for dog details
  ///
  /// In en, this message translates to:
  /// **'Under Treatment'**
  String get dogDetailsHealthUnderTreatment;

  /// Prefer not to say option for owner gender
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get dogDetailsOwnerGenderPreferNotToSay;

  /// Button label for picking dog image
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get dogDetailsPickImageButton;

  /// Button label for adding dog in details view
  ///
  /// In en, this message translates to:
  /// **'Add Dog'**
  String get dogDetailsAddButton;

  /// Button label for updating dog in details view
  ///
  /// In en, this message translates to:
  /// **'Update Dog'**
  String get dogDetailsUpdateButton;

  /// Label for neutered status in details view
  ///
  /// In en, this message translates to:
  /// **'Neutered:'**
  String get dogDetailsNeuteredLabel;

  /// Label for adoption availability in details view
  ///
  /// In en, this message translates to:
  /// **'Available for Adoption:'**
  String get dogDetailsAdoptionLabel;

  /// Error message for duplicate dog name in details view
  ///
  /// In en, this message translates to:
  /// **'A dog with the name {name} already exists!'**
  String dogDetailsNameExistsError(Object name);

  /// Error message for unauthorized dog edit
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to edit this dog.'**
  String get editDogPermissionDenied;

  /// Validation message for empty dog name in edit
  ///
  /// In en, this message translates to:
  /// **'Please enter the dog\'s name'**
  String get editDogEnterName;

  /// Validation message for invalid dog age in edit
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid age'**
  String get editDogEnterValidAge;

  /// Male gender option for owner in edit dog
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get editDogOwnerGenderMale;

  /// Female gender option for owner in edit dog
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get editDogOwnerGenderFemale;

  /// Other gender option for owner in edit dog
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get editDogOwnerGenderOther;

  /// Title for find playmate page
  ///
  /// In en, this message translates to:
  /// **'Find a Playmate'**
  String get findPlaymateTitle;

  /// Message when no dogs match applied filters
  ///
  /// In en, this message translates to:
  /// **'No dogs match your filters.'**
  String get noDogsMatchFilters;

  /// Suggestion when no dogs match filters
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or increasing the distance.'**
  String get adjustFiltersSuggestion;

  /// Option for any gender in filters
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyGender;

  /// Label for distance in filters
  ///
  /// In en, this message translates to:
  /// **'Distance: {distance} km'**
  String distanceLabel(Object distance);

  /// Button label for resetting filters
  ///
  /// In en, this message translates to:
  /// **'Reset Filters'**
  String get resetFiltersButton;

  /// Button label for showing more filters
  ///
  /// In en, this message translates to:
  /// **'More Filters'**
  String get moreFiltersButton;

  /// Label for breed filter
  ///
  /// In en, this message translates to:
  /// **'Filter by Breed'**
  String get filterByBreed;

  /// Label for gender filter
  ///
  /// In en, this message translates to:
  /// **'Filter by Gender'**
  String get filterByGender;

  /// Label for age filter
  ///
  /// In en, this message translates to:
  /// **'Filter by Age'**
  String get filterByAge;

  /// Label for neutered status filter
  ///
  /// In en, this message translates to:
  /// **'Filter by Neutered Status'**
  String get filterByNeuteredStatus;

  /// Hint for neutered status dropdown
  ///
  /// In en, this message translates to:
  /// **'Select Neutered Status'**
  String get selectNeuteredStatusHint;

  /// Label for health status filter
  ///
  /// In en, this message translates to:
  /// **'Filter by Health Status'**
  String get filterByHealthStatus;

  /// Prompt for premium filters
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium for more filters!'**
  String get upgradeToPremiumForMoreFilters;

  /// Button label for applying filters
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Title for favorites page
  ///
  /// In en, this message translates to:
  /// **'Favorite Dogs'**
  String get favoritesPageTitle;

  /// Message when no favorite dogs exist
  ///
  /// In en, this message translates to:
  /// **'No favorite dogs yet!'**
  String get noFavoriteDogsYet;

  /// Suggestion for adding favorite dogs
  ///
  /// In en, this message translates to:
  /// **'Go back to the home page and add some dogs to your favorites.'**
  String get addFavoriteSuggestion;

  /// Tooltip for removing favorite dog
  ///
  /// In en, this message translates to:
  /// **'Remove Favorite'**
  String get removeFavoriteTooltip;

  /// Button label for scheduling playdate
  ///
  /// In en, this message translates to:
  /// **'Schedule Playdate'**
  String get schedulePlaydate;

  /// Label for selecting date and time
  ///
  /// In en, this message translates to:
  /// **'Select Date and Time'**
  String get selectDateAndTime;

  /// Button label for picking date
  ///
  /// In en, this message translates to:
  /// **'Pick Date'**
  String get pickDate;

  /// Button label for picking time
  ///
  /// In en, this message translates to:
  /// **'Pick Time'**
  String get pickTime;

  /// Hint for selecting user's dog
  ///
  /// In en, this message translates to:
  /// **'Select your dog'**
  String get selectYourDogHint;

  /// Hint for selecting friend's dog
  ///
  /// In en, this message translates to:
  /// **'Select friend\'s dog'**
  String get selectFriendsDogHint;

  /// Label for selecting user's dog
  ///
  /// In en, this message translates to:
  /// **'Select Your Dog'**
  String get selectYourDog;

  /// Label for selecting friend's dog
  ///
  /// In en, this message translates to:
  /// **'Select Friend\'s Dog'**
  String get selectFriendsDog;

  /// Message prompting login for playdate scheduling
  ///
  /// In en, this message translates to:
  /// **'Please log in to schedule a playdate'**
  String get pleaseLoginToSchedulePlaydate;

  /// Label for selecting location
  ///
  /// In en, this message translates to:
  /// **'Select Location'**
  String get selectLocation;

  /// Placeholder for location input
  ///
  /// In en, this message translates to:
  /// **'Enter location (e.g., Latitude: 41.0103, Longitude: 28.6724 or address)'**
  String get enterLocation;

  /// Button label for picking location on map
  ///
  /// In en, this message translates to:
  /// **'Pick on Map'**
  String get pickOnMap;

  /// Label for quick location options
  ///
  /// In en, this message translates to:
  /// **'Quick Locations'**
  String get quickLocations;

  /// Label for Park A location
  ///
  /// In en, this message translates to:
  /// **'Park A'**
  String get parkA;

  /// Label for Park B location
  ///
  /// In en, this message translates to:
  /// **'Park B'**
  String get parkB;

  /// Button label for confirming action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Button label for canceling action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Validation message for missing dog selection
  ///
  /// In en, this message translates to:
  /// **'Please select both dogs'**
  String get pleaseSelectBothDogs;

  /// Message prompting login for creating request
  ///
  /// In en, this message translates to:
  /// **'Please log in to create a request'**
  String get pleaseLoginToCreateRequest;

  /// Message for playdate request
  ///
  /// In en, this message translates to:
  /// **'{requesterDog} wants to play with {requestedDog}!'**
  String playdateRequestMessage(Object requesterDog, Object requestedDog);

  /// Success message for creating request
  ///
  /// In en, this message translates to:
  /// **'Request created successfully'**
  String get requestCreatedSuccess;

  /// Error message for creating request failure
  ///
  /// In en, this message translates to:
  /// **'Error creating request: {error}'**
  String errorCreatingRequest(Object error);

  /// Success message for scheduling playdate
  ///
  /// In en, this message translates to:
  /// **'Playdate with {dogName} scheduled for {dateTime} at {location}!'**
  String playdateScheduled(Object dogName, Object dateTime, Object location);

  /// Title for new playdate request notification
  ///
  /// In en, this message translates to:
  /// **'New Playdate Request!'**
  String get newPlaydateRequest;

  /// Body for playdate request notification
  ///
  /// In en, this message translates to:
  /// **'{requesterDog} wants to play with {requestedDog}!'**
  String playdateRequestBody(Object requesterDog, Object requestedDog);

  /// Message when dog is removed from favorites
  ///
  /// In en, this message translates to:
  /// **'{dogName} removed from favorites!'**
  String removedFromFavorites(Object dogName);

  /// Message when dog is added to favorites
  ///
  /// In en, this message translates to:
  /// **'{dogName} added to favorites!'**
  String addedToFavorites(Object dogName);

  /// Error message for toggling favorite
  ///
  /// In en, this message translates to:
  /// **'Error toggling favorite: {error}'**
  String errorTogglingFavorite(Object error);

  /// Message for initiating chat with dog owner
  ///
  /// In en, this message translates to:
  /// **'Chat with {dogName}\'s owner!'**
  String chatWithOwner(Object dogName);

  /// Error message for scheduling playdate failure
  ///
  /// In en, this message translates to:
  /// **'Error scheduling playdate: {error}'**
  String errorSchedulingPlaydate(Object error);

  /// Tooltip for viewing/editing dog details
  ///
  /// In en, this message translates to:
  /// **'View/Edit Dog Details'**
  String get viewEditDogDetails;

  /// Error message for unauthorized dog edit
  ///
  /// In en, this message translates to:
  /// **'No edit permission for {dogName}, onDogUpdated is empty'**
  String editNotAllowed(Object dogName);

  /// Message when edit dialog is already open
  ///
  /// In en, this message translates to:
  /// **'Edit dialog already open or editing in progress for {dogName}'**
  String editDialogOpen(Object dogName);

  /// Log message for opening edit dialog
  ///
  /// In en, this message translates to:
  /// **'Opening EditDogDialog for {dogName}'**
  String openingEditDialog(Object dogName);

  /// Log message for dog update in dialog
  ///
  /// In en, this message translates to:
  /// **'{dogName} updated in dialog'**
  String dogUpdatedInDialog(Object dogName);

  /// Log message for dialog close
  ///
  /// In en, this message translates to:
  /// **'Dialog successfully popped for {dogName}'**
  String dialogPopped(Object dogName);

  /// Log message for updated dog return
  ///
  /// In en, this message translates to:
  /// **'Updated dog returned from dialog: {dogName}'**
  String updatedDogReturned(Object dogName);

  /// Error message for showDialog failure
  ///
  /// In en, this message translates to:
  /// **'showDialog error for {dogName}: {error}'**
  String errorInShowDialog(Object dogName, Object error);

  /// Log message for dialog closure
  ///
  /// In en, this message translates to:
  /// **'Dialog closed, isEditing: {isEditing}, isDialogOpen: {isDialogOpen}'**
  String dialogClosed(Object isEditing, Object isDialogOpen);

  /// Log message for widget not mounted
  ///
  /// In en, this message translates to:
  /// **'Widget not mounted, reset isDialogOpen to: {isDialogOpen}'**
  String widgetNotMounted(Object isDialogOpen);

  /// Message when dislike is removed
  ///
  /// In en, this message translates to:
  /// **'Dislike removed for {dogName}!'**
  String removedDislike(Object dogName);

  /// Message when dog is disliked
  ///
  /// In en, this message translates to:
  /// **'{dogName} disliked!'**
  String addedDislike(Object dogName);

  /// Error message for dislike notification failure
  ///
  /// In en, this message translates to:
  /// **'Dislike notification failed: {message}'**
  String dislikeNotificationFailed(Object message);

  /// Message when notifications are disabled
  ///
  /// In en, this message translates to:
  /// **'Please ensure notifications are enabled for {dogName}\'s owner.'**
  String ensureNotificationsEnabled(Object dogName);

  /// Error message for dislike failure
  ///
  /// In en, this message translates to:
  /// **'Failed to dislike: {message}'**
  String failedToDislike(Object message);

  /// Error message for sending dislike notification
  ///
  /// In en, this message translates to:
  /// **'Error sending dislike notification: {error}'**
  String errorSendingDislike(Object error);

  /// Log message for widget disposal
  ///
  /// In en, this message translates to:
  /// **'Disposing for {dogName}'**
  String disposing(Object dogName);

  /// Log message for resetting dialog open state
  ///
  /// In en, this message translates to:
  /// **'Reset isDialogOpen during cancel: {isDialogOpen}'**
  String resetIsDialogOpen(Object isDialogOpen);

  /// Label for notifications section
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// Label for playdate requests section
  ///
  /// In en, this message translates to:
  /// **'Playdate Requests'**
  String get playdateRequests;

  /// Message when no notifications exist
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// Message when no playdate requests exist
  ///
  /// In en, this message translates to:
  /// **'No playdate requests yet.'**
  String get noPlaydateRequests;

  /// Button label for accepting request
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Button label for rejecting request
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// Label for request status
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Button label for deleting request
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Title for reject confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Reject Confirmation'**
  String get rejectConfirmation;

  /// Confirmation message for rejecting request
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this request?'**
  String get areYouSure;

  /// Success message for deleting notification
  ///
  /// In en, this message translates to:
  /// **'Notification deleted'**
  String get notificationDeleted;

  /// Error message for deleting notification
  ///
  /// In en, this message translates to:
  /// **'Error deleting notification: {error}'**
  String errorDeletingNotification(Object error);

  /// Section title for notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSection;

  /// Section title for playdate requests
  ///
  /// In en, this message translates to:
  /// **'Playdate Requests'**
  String get playdateRequestsSection;

  /// Default title when none provided
  ///
  /// In en, this message translates to:
  /// **'No Title'**
  String get noTitle;

  /// Default body when none provided
  ///
  /// In en, this message translates to:
  /// **'No Body'**
  String get noBody;

  /// Title for new like notification
  ///
  /// In en, this message translates to:
  /// **'New Like!'**
  String get newLikeTitle;

  /// Body for new like notification
  ///
  /// In en, this message translates to:
  /// **'{username} liked your dog {dogName}!'**
  String newLikeBody(Object username, Object dogName);

  /// Title for new playdate request notification
  ///
  /// In en, this message translates to:
  /// **'New Playdate Request!'**
  String get newPlayDateRequestTitle;

  /// Body for new playdate request notification
  ///
  /// In en, this message translates to:
  /// **'You have a new playdate request from {dogName}.'**
  String newPlayDateRequestBody(Object dogName);

  /// Title for canceled playdate notification
  ///
  /// In en, this message translates to:
  /// **'PlayDate Request Canceled'**
  String get playDateCanceledTitle;

  /// Body for canceled playdate notification
  ///
  /// In en, this message translates to:
  /// **'The playdate request with {dogName} has been canceled.'**
  String playDateCanceledBody(Object dogName);

  /// Title for accepted playdate notification
  ///
  /// In en, this message translates to:
  /// **'PlayDate Request Accepted!'**
  String get playDateAcceptedTitle;

  /// Body for accepted playdate for requester
  ///
  /// In en, this message translates to:
  /// **'You accepted the playdate request with {dogName}'**
  String playDateAcceptedBodyRequester(Object dogName);

  /// Body for accepted playdate for requested user
  ///
  /// In en, this message translates to:
  /// **'{dogName} accepted your playdate request with {dogName} at {dateTime}'**
  String playDateAcceptedBodyRequested(Object dogName, Object dateTime);

  /// Title for rejected playdate notification
  ///
  /// In en, this message translates to:
  /// **'PlayDate Request Rejected'**
  String get playDateRejectedTitle;

  /// Body for rejected playdate for requester
  ///
  /// In en, this message translates to:
  /// **'You rejected the playdate request with {dogName}'**
  String playDateRejectedBodyRequester(Object dogName);

  /// Body for rejected playdate for requested user
  ///
  /// In en, this message translates to:
  /// **'{dogName} rejected your playdate request with {dogName}'**
  String playDateRejectedBodyRequested(Object dogName);

  /// Error message for loading notifications
  ///
  /// In en, this message translates to:
  /// **'Error updating notifications: {error}'**
  String errorLoadingNotifications(Object error);

  /// Error message for initializing/loading requests
  ///
  /// In en, this message translates to:
  /// **'Error initializing or loading requests: {error}'**
  String errorInitializingOrLoadingRequests(Object error);

  /// Error message for loading requests
  ///
  /// In en, this message translates to:
  /// **'Error loading requests: {error}'**
  String errorLoadingRequests(Object error);

  /// Error message for loading specific request
  ///
  /// In en, this message translates to:
  /// **'Error loading specific request: {error}'**
  String errorLoadingSpecificRequest(Object error);

  /// Error message for loading notifications stream
  ///
  /// In en, this message translates to:
  /// **'Error loading notifications stream: {error}'**
  String errorLoadingNotificationsStream(Object error);

  /// Error message for loading requests stream
  ///
  /// In en, this message translates to:
  /// **'Error loading requests stream: {error}'**
  String errorLoadingRequestsStream(Object error);

  /// Error message for updating status
  ///
  /// In en, this message translates to:
  /// **'Error updating status: {error}'**
  String errorUpdatingStatus(Object error);

  /// Unexpected error message for updating status
  ///
  /// In en, this message translates to:
  /// **'Unexpected error updating status: {error}'**
  String errorUpdatingStatusUnexpected(Object error);

  /// Message prompting login to respond to requests
  ///
  /// In en, this message translates to:
  /// **'Please log in to respond to requests'**
  String get pleaseLoginToRespond;

  /// Success message for updating request status
  ///
  /// In en, this message translates to:
  /// **'Request {status} successfully'**
  String requestStatusUpdated(Object status);

  /// Error message for responding to request
  ///
  /// In en, this message translates to:
  /// **'Error responding to request: {error}'**
  String errorRespondingToRequest(Object error);

  /// Unexpected error message for responding to request
  ///
  /// In en, this message translates to:
  /// **'Unexpected error responding to request: {error}'**
  String errorRespondingToRequestUnexpected(Object error);

  /// Message prompting login to accept requests
  ///
  /// In en, this message translates to:
  /// **'Please log in to accept requests'**
  String get pleaseLoginToAccept;

  /// Success message for accepting request
  ///
  /// In en, this message translates to:
  /// **'Request accepted and added to playdates list.'**
  String get requestAcceptedSuccess;

  /// Error message for accepting request
  ///
  /// In en, this message translates to:
  /// **'Error accepting request: {error}'**
  String errorAcceptingRequest(Object error);

  /// Unexpected error message for accepting request
  ///
  /// In en, this message translates to:
  /// **'Unexpected error accepting request: {error}'**
  String errorAcceptingRequestUnexpected(Object error);

  /// Message prompting login to reject requests
  ///
  /// In en, this message translates to:
  /// **'Please log in to reject requests'**
  String get pleaseLoginToReject;

  /// Success message for rejecting request
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get requestRejectedSuccess;

  /// Error message for rejecting request
  ///
  /// In en, this message translates to:
  /// **'Error rejecting request: {error}'**
  String errorRejectingRequest(Object error);

  /// Unexpected error message for rejecting request
  ///
  /// In en, this message translates to:
  /// **'Unexpected error rejecting request: {error}'**
  String errorRejectingRequestUnexpected(Object error);

  /// Error message for scheduling reminder failure
  ///
  /// In en, this message translates to:
  /// **'Failed to schedule reminder. Check permissions.'**
  String get failedToScheduleReminder;

  /// Label for scheduled date/time
  ///
  /// In en, this message translates to:
  /// **'Scheduled:'**
  String get scheduledLabel;

  /// Label for location field
  ///
  /// In en, this message translates to:
  /// **'Location:'**
  String get locationLabel;

  /// Default status when unknown
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get unknownStatus;

  /// Default time when unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown time'**
  String get unknownTime;

  /// Time ago format for minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(Object minutes);

  /// Time ago format for hours
  ///
  /// In en, this message translates to:
  /// **'{hours} hr ago'**
  String hoursAgo(Object hours);

  /// Time ago format for days
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String daysAgo(Object days);

  /// Message when no schedule exists
  ///
  /// In en, this message translates to:
  /// **'Not scheduled'**
  String get notScheduled;

  /// Title for upcoming playdate notification
  ///
  /// In en, this message translates to:
  /// **'Upcoming Playdate'**
  String get upcomingPlaydateTitle;

  /// Body for upcoming playdate for requester
  ///
  /// In en, this message translates to:
  /// **'You have a playdate in 2 hours with {dogName}!'**
  String upcomingPlaydateBodyRequester(Object dogName);

  /// Body for upcoming playdate for requested user
  ///
  /// In en, this message translates to:
  /// **'You have a playdate in 2 hours with {dogName}!'**
  String upcomingPlaydateBodyRequested(Object dogName);

  /// Introduction to app features
  ///
  /// In en, this message translates to:
  /// **'With our app, you can:'**
  String get appFeatures;

  /// Message listing app features
  ///
  /// In en, this message translates to:
  /// **'With our app, you can:'**
  String get appFeaturesMessage;

  /// Label for Playmate service
  ///
  /// In en, this message translates to:
  /// **'Playmate'**
  String get playmateService;

  /// Label for Vet Services
  ///
  /// In en, this message translates to:
  /// **'Vet Services'**
  String get vetServices;

  /// Label for Adoption service
  ///
  /// In en, this message translates to:
  /// **'Adoption'**
  String get adoptionService;

  /// Label for Dog Training service
  ///
  /// In en, this message translates to:
  /// **'Dog Training'**
  String get dogTrainingService;

  /// Label for Dog Park service
  ///
  /// In en, this message translates to:
  /// **'Dog Park'**
  String get dogParkService;

  /// Label for Find Friends service
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get findFriendsService;

  /// Button label for getting started
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Label for Dog Training section
  ///
  /// In en, this message translates to:
  /// **'Dog Training'**
  String get dogTraining;

  /// Label for Dog Park section
  ///
  /// In en, this message translates to:
  /// **'Dog Park'**
  String get dogPark;

  /// Label for Find Friends section
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get findFriends;

  /// Message for upcoming Dog Training feature
  ///
  /// In en, this message translates to:
  /// **'Dog Training Coming Soon!'**
  String get dogTrainingComingSoon;

  /// Message for upcoming Lost Dogs feature
  ///
  /// In en, this message translates to:
  /// **'Lost Dogs Coming Soon!'**
  String get lostDogsComingSoon;

  /// Message for upcoming Pet Shops feature
  ///
  /// In en, this message translates to:
  /// **'Pet Shops Coming Soon!'**
  String get petShopsComingSoon;

  /// Message for upcoming Hospitals feature
  ///
  /// In en, this message translates to:
  /// **'Hospitals Coming Soon!'**
  String get hospitalsComingSoon;

  /// Message for upcoming Find Friends feature
  ///
  /// In en, this message translates to:
  /// **'Find Friends Coming Soon!'**
  String get findFriendsComingSoon;

  /// Title for menu
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuTitle;

  /// Menu item for home page
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeMenuItem;

  /// Menu item for my dogs
  ///
  /// In en, this message translates to:
  /// **'My Dogs'**
  String get myDogsMenuItem;

  /// Menu item for favorites
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesMenuItem;

  /// Menu item for adoption center
  ///
  /// In en, this message translates to:
  /// **'Adoption Center'**
  String get adoptionCenterMenuItem;

  /// Menu item for dog park
  ///
  /// In en, this message translates to:
  /// **'Dog Park'**
  String get dogParkMenuItem;

  /// Menu item for reporting lost dog
  ///
  /// In en, this message translates to:
  /// **'Report Lost Dog'**
  String get reportLostDogMenuItem;

  /// Menu item for lost dogs
  ///
  /// In en, this message translates to:
  /// **'Lost Dogs'**
  String get lostDogsMenuItem;

  /// Menu item for reporting found dog
  ///
  /// In en, this message translates to:
  /// **'Report Found Dog'**
  String get reportFoundDogMenuItem;

  /// Menu item for found dogs
  ///
  /// In en, this message translates to:
  /// **'Found Dogs'**
  String get foundDogsMenuItem;

  /// Menu item for pet shops
  ///
  /// In en, this message translates to:
  /// **'Pet Shops'**
  String get petShopsMenuItem;

  /// Menu item for hospitals
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get hospitalsMenuItem;

  /// Menu item for logout
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutMenuItem;

  /// Menu item for filtering dogs
  ///
  /// In en, this message translates to:
  /// **'Filter Dogs'**
  String get filterDogsMenuItem;

  /// Navigation item for home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeNavItem;

  /// Navigation item for favorites
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesNavItem;

  /// Navigation item for visiting vet
  ///
  /// In en, this message translates to:
  /// **'Visit Vet'**
  String get visitVetNavItem;

  /// Navigation item for playdate
  ///
  /// In en, this message translates to:
  /// **'Playdate'**
  String get playdateNavItem;

  /// Navigation item for profile
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileNavItem;

  /// Tooltip for notifications icon
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTooltip;

  /// Tooltip for chat icon
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTooltip;

  /// Message for unimplemented chat feature
  ///
  /// In en, this message translates to:
  /// **'Chat functionality not implemented yet'**
  String get chatNotImplemented;

  /// Title for dog parks page
  ///
  /// In en, this message translates to:
  /// **'Dog Parks'**
  String get dogParkTitle;

  /// Label for date in dog park
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dogParkDateLabel(Object date);

  /// Button label for loading park markers
  ///
  /// In en, this message translates to:
  /// **'Load Park Markers'**
  String get dogParkLoadMarkers;

  /// Button label for moving to markers
  ///
  /// In en, this message translates to:
  /// **'Move to Markers'**
  String get dogParkMoveToMarkers;

  /// Message for denied location permission
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Please enable it in settings.'**
  String get dogParkPermissionDenied;

  /// Message for denied background location permission
  ///
  /// In en, this message translates to:
  /// **'Background location permission denied. Some features may be limited.'**
  String get dogParkBackgroundPermissionDenied;

  /// Message for disabled location services
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled.'**
  String get dogParkLocationServicesDisabled;

  /// Prompt to enable location services
  ///
  /// In en, this message translates to:
  /// **'Please enable location services to continue.'**
  String get dogParkEnableLocationServices;

  /// Message for permanently denied location permission
  ///
  /// In en, this message translates to:
  /// **'Location permission permanently denied.'**
  String get dogParkPermissionDeniedPermanent;

  /// Message for permanently denied permissions
  ///
  /// In en, this message translates to:
  /// **'Location permissions are permanently denied. Please enable them from settings.'**
  String get dogParkPermissionsDenied;

  /// Error message for location retrieval failure
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String dogParkLocationError(Object error);

  /// Message requiring location permission for dog parks
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to show nearby dog parks.'**
  String get dogParkPermissionRequired;

  /// Recommendation for background location permission
  ///
  /// In en, this message translates to:
  /// **'Background location permission is recommended. Please enable it in settings.'**
  String get dogParkBackgroundRecommended;

  /// Button label for opening settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get dogParkSettingsAction;

  /// Label for distance to dog park
  ///
  /// In en, this message translates to:
  /// **'Distance: {distance} km'**
  String dogParkDistanceLabel(Object distance);

  /// Title for dog details page
  ///
  /// In en, this message translates to:
  /// **'Dog Details'**
  String get dogViewTitle;

  /// Label for dog name in view
  ///
  /// In en, this message translates to:
  /// **'Name:'**
  String get dogViewNameLabel;

  /// Label for dog breed in view
  ///
  /// In en, this message translates to:
  /// **'Breed:'**
  String get dogViewBreedLabel;

  /// Label for dog age in view
  ///
  /// In en, this message translates to:
  /// **'Age:'**
  String get dogViewAgeLabel;

  /// Label for dog gender in view
  ///
  /// In en, this message translates to:
  /// **'Gender:'**
  String get dogViewGenderLabel;

  /// Label for dog health status in view
  ///
  /// In en, this message translates to:
  /// **'Health:'**
  String get dogViewHealthLabel;

  /// Label for neutered status in view
  ///
  /// In en, this message translates to:
  /// **'Neutered:'**
  String get dogViewNeuteredLabel;

  /// Label for dog description in view
  ///
  /// In en, this message translates to:
  /// **'Description:'**
  String get dogViewDescriptionLabel;

  /// Label for dog traits in view
  ///
  /// In en, this message translates to:
  /// **'Traits:'**
  String get dogViewTraitsLabel;

  /// Label for owner gender in view
  ///
  /// In en, this message translates to:
  /// **'Owner Gender:'**
  String get dogViewOwnerGenderLabel;

  /// Label for adoption availability in view
  ///
  /// In en, this message translates to:
  /// **'Available for Adoption:'**
  String get dogViewAvailableLabel;

  /// Yes option for dog view
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get dogViewYes;

  /// No option for dog view
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get dogViewNo;

  /// Tooltip for like button in dog view
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get dogViewLikeTooltip;

  /// Tooltip for dislike button in dog view
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dogViewDislikeTooltip;

  /// Tooltip for add to favorite button in dog view
  ///
  /// In en, this message translates to:
  /// **'Add to Favorite'**
  String get dogViewAddFavoriteTooltip;

  /// Tooltip for chat button in dog view
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get dogViewChatTooltip;

  /// Button label for scheduling date in dog view
  ///
  /// In en, this message translates to:
  /// **'Schedule Date'**
  String get dogViewScheduleDate;

  /// Button label for adoption in dog view
  ///
  /// In en, this message translates to:
  /// **'Adoption'**
  String get dogViewAdoption;

  /// Success message for starting chat
  ///
  /// In en, this message translates to:
  /// **'Chat started!'**
  String get dogViewChatStarted;

  /// Success message for scheduling playdate in dog view
  ///
  /// In en, this message translates to:
  /// **'Play date scheduled for {day}/{month}/{year} at {time}!'**
  String dogViewPlayDateScheduled(Object day, Object month, Object year, Object time);

  /// Success message for sending adoption request in dog view
  ///
  /// In en, this message translates to:
  /// **'Adoption request sent!'**
  String get dogViewAdoptionRequest;

  /// Title for dog information page
  ///
  /// In en, this message translates to:
  /// **'Dog Information'**
  String get dogInfoTitle;

  /// Label for dog breed in info page
  ///
  /// In en, this message translates to:
  /// **'Breed:'**
  String get dogInfoBreedLabel;

  /// Label for dog age in info page
  ///
  /// In en, this message translates to:
  /// **'Age:'**
  String get dogInfoAgeLabel;

  /// Label for dog gender in info page
  ///
  /// In en, this message translates to:
  /// **'Gender:'**
  String get dogInfoGenderLabel;

  /// Label for dog health status in info page
  ///
  /// In en, this message translates to:
  /// **'Health Status:'**
  String get dogInfoHealthLabel;

  /// Label for neutered status in info page
  ///
  /// In en, this message translates to:
  /// **'Neutered:'**
  String get dogInfoNeuteredLabel;

  /// Label for dog description in info page
  ///
  /// In en, this message translates to:
  /// **'Description:'**
  String get dogInfoDescriptionLabel;

  /// Label for dog traits in info page
  ///
  /// In en, this message translates to:
  /// **'Traits:'**
  String get dogInfoTraitsLabel;

  /// Label for owner gender in info page
  ///
  /// In en, this message translates to:
  /// **'Owner Gender:'**
  String get dogInfoOwnerGenderLabel;

  /// Yes option for dog info
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get dogInfoYes;

  /// No option for dog info
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get dogInfoNo;

  /// Tooltip for like button in dog info
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get dogInfoLikeTooltip;

  /// Tooltip for dislike button in dog info
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dogInfoDislikeTooltip;

  /// Tooltip for chat button in dog info
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get dogInfoChatTooltip;

  /// Tooltip for add to favorite button in dog info
  ///
  /// In en, this message translates to:
  /// **'Add to Favorite'**
  String get dogInfoAddFavoriteTooltip;

  /// Tooltip for schedule playdate button in dog info
  ///
  /// In en, this message translates to:
  /// **'Schedule Playdate'**
  String get dogInfoSchedulePlaydateTooltip;

  /// Success message for scheduling playdate in dog info
  ///
  /// In en, this message translates to:
  /// **'Scheduled a play date with {dogName}!'**
  String dogInfoPlaydateScheduled(Object dogName);

  /// Message for liking dog in info page
  ///
  /// In en, this message translates to:
  /// **'Liked {dogName}!'**
  String dogInfoLiked(Object dogName);

  /// Message for disliking dog in info page
  ///
  /// In en, this message translates to:
  /// **'Disliked {dogName}!'**
  String dogInfoDisliked(Object dogName);

  /// Message for chatting with owner in info page
  ///
  /// In en, this message translates to:
  /// **'Chat with {dogName}\'s owner!'**
  String dogInfoChatWithOwner(Object dogName);

  /// Message for removing favorite in info page
  ///
  /// In en, this message translates to:
  /// **'Removed {dogName} from favorites!'**
  String dogInfoRemovedFavorite(Object dogName);

  /// Message for adding favorite in info page
  ///
  /// In en, this message translates to:
  /// **'Added {dogName} to favorites!'**
  String dogInfoAddedFavorite(Object dogName);

  /// Message when no dogs are found
  ///
  /// In en, this message translates to:
  /// **'No Dogs Found'**
  String get noDogsFound;

  /// Message when no dogs are found for a user
  ///
  /// In en, this message translates to:
  /// **'No dogs found for this user.'**
  String get noDogsForUser;

  /// Label for user's dogs section
  ///
  /// In en, this message translates to:
  /// **'Dogs of this User'**
  String get dogsOfThisUser;

  /// Status label for pending playdate
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get playDateStatus_pending;

  /// Status label for accepted playdate
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get playDateStatus_accepted;

  /// Status label for rejected playdate
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get playDateStatus_rejected;

  /// Message for disabled location services
  ///
  /// In en, this message translates to:
  /// **'Location services are disabled. Using default location.'**
  String get locationServicesDisabled;

  /// Message requiring location permission
  ///
  /// In en, this message translates to:
  /// **'Location permission is required. Using default location.'**
  String get locationPermissionRequired;

  /// Message for permanently denied location permission
  ///
  /// In en, this message translates to:
  /// **'Location permission is permanently denied. Using default location.'**
  String get locationPermissionPermanentlyDenied;

  /// Error message for location retrieval failure
  ///
  /// In en, this message translates to:
  /// **'Error getting location: {error}'**
  String errorGettingLocation(Object error);

  /// Error message for data loading failure
  ///
  /// In en, this message translates to:
  /// **'Error loading data: {error}'**
  String errorLoadingData(Object error);

  /// Error message for loading offers failure
  ///
  /// In en, this message translates to:
  /// **'Error loading offers: {error}'**
  String errorLoadingOffers(Object error);

  /// Error message for applying filters failure
  ///
  /// In en, this message translates to:
  /// **'Error applying filters: {error}'**
  String errorApplyingFilters(Object error);

  /// Name for notification channel
  ///
  /// In en, this message translates to:
  /// **'High Importance Notifications'**
  String get notificationChannelName;

  /// Description for notification channel
  ///
  /// In en, this message translates to:
  /// **'This channel is used for important notifications.'**
  String get notificationChannelDescription;

  /// Action label for opening app from notification
  ///
  /// In en, this message translates to:
  /// **'Open App'**
  String get openAppAction;

  /// Action label for dismissing notification
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissAction;

  /// Label for adoption center section
  ///
  /// In en, this message translates to:
  /// **'Adoption Center'**
  String get adoptionCenter;

  /// Trait label for energetic
  ///
  /// In en, this message translates to:
  /// **'Energetic'**
  String get traitEnergetic;

  /// Trait label for playful
  ///
  /// In en, this message translates to:
  /// **'Playful'**
  String get traitPlayful;

  /// Trait label for calm
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get traitCalm;

  /// Trait label for loyal
  ///
  /// In en, this message translates to:
  /// **'Loyal'**
  String get traitLoyal;

  /// Trait label for friendly
  ///
  /// In en, this message translates to:
  /// **'Friendly'**
  String get traitFriendly;

  /// Trait label for protective
  ///
  /// In en, this message translates to:
  /// **'Protective'**
  String get traitProtective;

  /// Trait label for intelligent
  ///
  /// In en, this message translates to:
  /// **'Intelligent'**
  String get traitIntelligent;

  /// Trait label for affectionate
  ///
  /// In en, this message translates to:
  /// **'Affectionate'**
  String get traitAffectionate;

  /// Trait label for curious
  ///
  /// In en, this message translates to:
  /// **'Curious'**
  String get traitCurious;

  /// Trait label for independent
  ///
  /// In en, this message translates to:
  /// **'Independent'**
  String get traitIndependent;

  /// Trait label for shy
  ///
  /// In en, this message translates to:
  /// **'Shy'**
  String get traitShy;

  /// Trait label for trained
  ///
  /// In en, this message translates to:
  /// **'Trained'**
  String get traitTrained;

  /// Trait label for social
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get traitSocial;

  /// Trait label for good with kids
  ///
  /// In en, this message translates to:
  /// **'Good with kids'**
  String get traitGoodWithKids;

  /// Breed label for Afghan Hound
  ///
  /// In en, this message translates to:
  /// **'Afghan Hound'**
  String get breedAfghanHound;

  /// Breed label for Airedale Terrier
  ///
  /// In en, this message translates to:
  /// **'Airedale Terrier'**
  String get breedAiredaleTerrier;

  /// Breed label for Akita
  ///
  /// In en, this message translates to:
  /// **'Akita'**
  String get breedAkita;

  /// Breed label for Alaskan Malamute
  ///
  /// In en, this message translates to:
  /// **'Alaskan Malamute'**
  String get breedAlaskanMalamute;

  /// Breed label for American Bulldog
  ///
  /// In en, this message translates to:
  /// **'American Bulldog'**
  String get breedAmericanBulldog;

  /// Breed label for American Pit Bull Terrier
  ///
  /// In en, this message translates to:
  /// **'Pit Bull'**
  String get breedAmericanPitBullTerrier;

  /// Breed label for Australian Cattle Dog
  ///
  /// In en, this message translates to:
  /// **'Australian Cattle Dog'**
  String get breedAustralianCattleDog;

  /// Breed label for Australian Shepherd
  ///
  /// In en, this message translates to:
  /// **'Australian Shepherd'**
  String get breedAustralianShepherd;

  /// Breed label for Basset Hound
  ///
  /// In en, this message translates to:
  /// **'Basset Hound'**
  String get breedBassetHound;

  /// Breed label for Beagle
  ///
  /// In en, this message translates to:
  /// **'Beagle'**
  String get breedBeagle;

  /// Breed label for Belgian Malinois
  ///
  /// In en, this message translates to:
  /// **'Belgian Malinois'**
  String get breedBelgianMalinois;

  /// Breed label for Bernese Mountain Dog
  ///
  /// In en, this message translates to:
  /// **'Bernese Mountain Dog'**
  String get breedBerneseMountainDog;

  /// Breed label for Bichon Frise
  ///
  /// In en, this message translates to:
  /// **'Bichon Frise'**
  String get breedBichonFrise;

  /// Breed label for Bloodhound
  ///
  /// In en, this message translates to:
  /// **'Bloodhound'**
  String get breedBloodhound;

  /// Breed label for Border Collie
  ///
  /// In en, this message translates to:
  /// **'Border Collie'**
  String get breedBorderCollie;

  /// Breed label for Boston Terrier
  ///
  /// In en, this message translates to:
  /// **'Boston Terrier'**
  String get breedBostonTerrier;

  /// Breed label for Boxer
  ///
  /// In en, this message translates to:
  /// **'Boxer'**
  String get breedBoxer;

  /// Breed label for Bulldog
  ///
  /// In en, this message translates to:
  /// **'Bulldog'**
  String get breedBulldog;

  /// Breed label for Bullmastiff
  ///
  /// In en, this message translates to:
  /// **'Bullmastiff'**
  String get breedBullmastiff;

  /// Breed label for Cairn Terrier
  ///
  /// In en, this message translates to:
  /// **'Cairn Terrier'**
  String get breedCairnTerrier;

  /// Breed label for Cane Corso
  ///
  /// In en, this message translates to:
  /// **'Cane Corso'**
  String get breedCaneCorso;

  /// Breed label for Cavalier King Charles Spaniel
  ///
  /// In en, this message translates to:
  /// **'Cavalier King Charles Spaniel'**
  String get breedCavalierKingCharlesSpaniel;

  /// Breed label for Chihuahua
  ///
  /// In en, this message translates to:
  /// **'Chihuahua'**
  String get breedChihuahua;

  /// Breed label for Chow Chow
  ///
  /// In en, this message translates to:
  /// **'Chow Chow'**
  String get breedChowChow;

  /// Breed label for Cocker Spaniel
  ///
  /// In en, this message translates to:
  /// **'Cocker Spaniel'**
  String get breedCockerSpaniel;

  /// Breed label for Collie
  ///
  /// In en, this message translates to:
  /// **'Collie'**
  String get breedCollie;

  /// Breed label for Dachshund
  ///
  /// In en, this message translates to:
  /// **'Dachshund'**
  String get breedDachshund;

  /// Breed label for Dalmatian
  ///
  /// In en, this message translates to:
  /// **'Dalmatian'**
  String get breedDalmatian;

  /// Breed label for Doberman Pinscher
  ///
  /// In en, this message translates to:
  /// **'Doberman Pinscher'**
  String get breedDobermanPinscher;

  /// Breed label for English Springer Spaniel
  ///
  /// In en, this message translates to:
  /// **'English Springer Spaniel'**
  String get breedEnglishSpringerSpaniel;

  /// Breed label for French Bulldog
  ///
  /// In en, this message translates to:
  /// **'French Bulldog'**
  String get breedFrenchBulldog;

  /// Breed label for German Shepherd
  ///
  /// In en, this message translates to:
  /// **'German Shepherd'**
  String get breedGermanShepherd;

  /// Breed label for German Shorthaired Pointer
  ///
  /// In en, this message translates to:
  /// **'German Shorthaired Pointer'**
  String get breedGermanShorthairedPointer;

  /// Breed label for Golden Retriever
  ///
  /// In en, this message translates to:
  /// **'Golden Retriever'**
  String get breedGoldenRetriever;

  /// Breed label for Great Dane
  ///
  /// In en, this message translates to:
  /// **'Great Dane'**
  String get breedGreatDane;

  /// Breed label for Great Pyrenees
  ///
  /// In en, this message translates to:
  /// **'Great Pyrenees'**
  String get breedGreatPyrenees;

  /// Breed label for Havanese
  ///
  /// In en, this message translates to:
  /// **'Havanese'**
  String get breedHavanese;

  /// Breed label for Irish Setter
  ///
  /// In en, this message translates to:
  /// **'Irish Setter'**
  String get breedIrishSetter;

  /// Breed label for Irish Wolfhound
  ///
  /// In en, this message translates to:
  /// **'Irish Wolfhound'**
  String get breedIrishWolfhound;

  /// Breed label for Jack Russell Terrier
  ///
  /// In en, this message translates to:
  /// **'Jack Russell Terrier'**
  String get breedJackRussellTerrier;

  /// Breed label for Labrador Retriever
  ///
  /// In en, this message translates to:
  /// **'Labrador Retriever'**
  String get breedLabradorRetriever;

  /// Breed label for Lhasa Apso
  ///
  /// In en, this message translates to:
  /// **'Lhasa Apso'**
  String get breedLhasaApso;

  /// Breed label for Maltese
  ///
  /// In en, this message translates to:
  /// **'Maltese'**
  String get breedMaltese;

  /// Breed label for Mastiff
  ///
  /// In en, this message translates to:
  /// **'Mastiff'**
  String get breedMastiff;

  /// Breed label for Miniature Schnauzer
  ///
  /// In en, this message translates to:
  /// **'Miniature Schnauzer'**
  String get breedMiniatureSchnauzer;

  /// Breed label for Newfoundland
  ///
  /// In en, this message translates to:
  /// **'Newfoundland'**
  String get breedNewfoundland;

  /// Breed label for Papillon
  ///
  /// In en, this message translates to:
  /// **'Papillon'**
  String get breedPapillon;

  /// Breed label for Pekingese
  ///
  /// In en, this message translates to:
  /// **'Pekingese'**
  String get breedPekingese;

  /// Breed label for Pomeranian
  ///
  /// In en, this message translates to:
  /// **'Pomeranian'**
  String get breedPomeranian;

  /// Breed label for Poodle
  ///
  /// In en, this message translates to:
  /// **'Poodle'**
  String get breedPoodle;

  /// Breed label for Pug
  ///
  /// In en, this message translates to:
  /// **'Pug'**
  String get breedPug;

  /// Breed label for Rottweiler
  ///
  /// In en, this message translates to:
  /// **'Rottweiler'**
  String get breedRottweiler;

  /// Breed label for Saint Bernard
  ///
  /// In en, this message translates to:
  /// **'Saint Bernard'**
  String get breedSaintBernard;

  /// Breed label for Samoyed
  ///
  /// In en, this message translates to:
  /// **'Samoyed'**
  String get breedSamoyed;

  /// Breed label for Shetland Sheepdog
  ///
  /// In en, this message translates to:
  /// **'Shetland Sheepdog'**
  String get breedShetlandSheepdog;

  /// Breed label for Shih Tzu
  ///
  /// In en, this message translates to:
  /// **'Shih Tzu'**
  String get breedShihTzu;

  /// Breed label for Siberian Husky
  ///
  /// In en, this message translates to:
  /// **'Siberian Husky'**
  String get breedSiberianHusky;

  /// Breed label for Staffordshire Bull Terrier
  ///
  /// In en, this message translates to:
  /// **'Staffordshire Bull Terrier'**
  String get breedStaffordshireBullTerrier;

  /// Breed label for Vizsla
  ///
  /// In en, this message translates to:
  /// **'Vizsla'**
  String get breedVizsla;

  /// Breed label for Weimaraner
  ///
  /// In en, this message translates to:
  /// **'Weimaraner'**
  String get breedWeimaraner;

  /// Breed label for West Highland White Terrier
  ///
  /// In en, this message translates to:
  /// **'West Highland White Terrier'**
  String get breedWestHighlandWhiteTerrier;

  /// Breed label for Yorkshire Terrier
  ///
  /// In en, this message translates to:
  /// **'Yorkshire Terrier'**
  String get breedYorkshireTerrier;

  /// Label for settings section
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Title for playdate requests and notifications page
  ///
  /// In en, this message translates to:
  /// **'Playdate Requests & Notifications'**
  String get playdateRequestsTitle;

  /// Button label for sending playdate request
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequestButton;

  /// Button label for confirming location
  ///
  /// In en, this message translates to:
  /// **'Confirm Location'**
  String get confirmLocation;

  /// Button label for canceling action
  ///
  /// In en, this message translates to:
  /// **'Cancel Action'**
  String get cancelButton;

  /// Healthy status option for editing dog
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get editDogHealthHealthy;

  /// Needs Care status option for editing dog
  ///
  /// In en, this message translates to:
  /// **'Needs Care'**
  String get editDogHealthNeedsCare;

  /// Under Treatment status option for editing dog
  ///
  /// In en, this message translates to:
  /// **'Under Treatment'**
  String get editDogHealthUnderTreatment;

  /// Message when no dogs are found for user account
  ///
  /// In en, this message translates to:
  /// **'No dog found for your account. Please add a dog first.'**
  String get noDogFoundForAccount;

  /// Message prompting to select a dog
  ///
  /// In en, this message translates to:
  /// **'Please select one of your dogs'**
  String get pleaseSelectYourDog;

  /// Message preventing playdate with own dog
  ///
  /// In en, this message translates to:
  /// **'You cannot schedule a playdate with your own dog.'**
  String get cannotScheduleWithOwnDog;

  /// Message preventing playdate with temporary user
  ///
  /// In en, this message translates to:
  /// **'Cannot schedule a playdate with a temporary user.'**
  String get cannotScheduleWithTempUser;

  /// Message for playdate request
  ///
  /// In en, this message translates to:
  /// **'Playdate request for {dogName}'**
  String playdateRequestFor(Object dogName);

  /// Label indicating dog is available for adoption
  ///
  /// In en, this message translates to:
  /// **'For Adoption'**
  String get forAdoption;

  /// Label for neutered status
  ///
  /// In en, this message translates to:
  /// **'Neutered'**
  String get neutered;

  /// Label for non-neutered status
  ///
  /// In en, this message translates to:
  /// **'Not Neutered'**
  String get notNeutered;

  /// Message prompting to select a dog for playdate
  ///
  /// In en, this message translates to:
  /// **'Please select one of your dogs for playdate'**
  String get pleaseSelectDogForPlaydate;

  /// Label for years in age display
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// Label for dog breed
  ///
  /// In en, this message translates to:
  /// **'Breed'**
  String get breed;

  /// Label for dog gender
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// Label for dog health status
  ///
  /// In en, this message translates to:
  /// **'Health Status'**
  String get healthStatus;

  /// Label for dog neutered status
  ///
  /// In en, this message translates to:
  /// **'Neutered Status'**
  String get neuteredStatus;

  /// Label for dog description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Label for dog traits
  ///
  /// In en, this message translates to:
  /// **'Traits'**
  String get traits;

  /// Button label for adding dog to favorites
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites;

  /// Title for new favorite dog notification
  ///
  /// In en, this message translates to:
  /// **'New Favorite!'**
  String get newFavoriteTitle;

  /// Body for new favorite dog notification
  ///
  /// In en, this message translates to:
  /// **'{userName} added your dog {dogName} to favorites!'**
  String newFavoriteBody(Object userName, Object dogName);

  /// Label for likes count
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// Tooltip for removing dislike
  ///
  /// In en, this message translates to:
  /// **'Remove Dislike'**
  String get removeDislike;

  /// Tooltip for disliking a dog
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dislike;

  /// Error message for toggling dislike
  ///
  /// In en, this message translates to:
  /// **'Error toggling dislike: {error}'**
  String errorTogglingDislike(Object error);

  /// Label for sending state
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sending;

  /// Button label for scheduling playdate
  ///
  /// In en, this message translates to:
  /// **'Schedule Play Date'**
  String get schedulePlayDate;

  /// Button label for chat
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// Button label for adopting dog
  ///
  /// In en, this message translates to:
  /// **'Adopt Dog'**
  String get adoptDog;

  /// Error message for sending dislike notification
  ///
  /// In en, this message translates to:
  /// **'Error sending dislike notification: {error}'**
  String errorSendingDislikeNotification(Object error);

  /// Label for male gender
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// Label for female gender
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// Label for healthy status
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthHealthy;

  /// Label for needs care status
  ///
  /// In en, this message translates to:
  /// **'Needs Care'**
  String get healthNeedsCare;

  /// Label for under treatment status
  ///
  /// In en, this message translates to:
  /// **'Under Treatment'**
  String get healthUnderTreatment;

  /// Alternative label for needs care status
  ///
  /// In en, this message translates to:
  /// **'Needs Care'**
  String get dogDetailsHealthSick;

  /// Alternative label for under treatment status
  ///
  /// In en, this message translates to:
  /// **'Under Treatment'**
  String get dogDetailsHealthRecovering;

  /// Message when no image is selected
  ///
  /// In en, this message translates to:
  /// **'No image selected.'**
  String get noImageSelected;

  /// Label for unknown gender
  ///
  /// In en, this message translates to:
  /// **'Unknown Gender'**
  String get unknownGender;

  /// Label for unknown breed
  ///
  /// In en, this message translates to:
  /// **'Unknown Breed'**
  String get unknownBreed;

  /// Label for unknown trait
  ///
  /// In en, this message translates to:
  /// **'Unknown Trait'**
  String get unknownTrait;

  /// Message when no traits are available
  ///
  /// In en, this message translates to:
  /// **'No traits available'**
  String get noTraits;

  /// Title for simple test page
  ///
  /// In en, this message translates to:
  /// **'Simple Test Page'**
  String get simpleTestPageTitle;

  /// Message for simple test page
  ///
  /// In en, this message translates to:
  /// **'This is a simple test page.'**
  String get simpleTestPageMessage;

  /// Shows the list of users who liked the dog
  ///
  /// In en, this message translates to:
  /// **'Liked by: {likers}'**
  String likedBy(Object likers);

  /// Message shown when location cannot be acquired
  ///
  /// In en, this message translates to:
  /// **'Location not acquired. Please try again.'**
  String get locationNotAcquired;

  /// Button label for retrying location acquisition
  ///
  /// In en, this message translates to:
  /// **'Retry Location'**
  String get retryLocation;

  /// Tooltip for liking a dog
  ///
  /// In en, this message translates to:
  /// **'Like this dog'**
  String get addLike;

  /// Tooltip for unliking a dog
  ///
  /// In en, this message translates to:
  /// **'Unlike this dog'**
  String get removeLike;

  /// Message when a dog is liked
  ///
  /// In en, this message translates to:
  /// **'You liked {dogName}!'**
  String addedLike(Object dogName);

  /// Message when a dog is unliked
  ///
  /// In en, this message translates to:
  /// **'You unliked {dogName}!'**
  String removedLike(Object dogName);

  /// Error message for like toggle failure
  ///
  /// In en, this message translates to:
  /// **'Error toggling like: {error}'**
  String errorTogglingLike(Object error);

  /// Error message shown when the dog's ownerId is null or empty
  ///
  /// In en, this message translates to:
  /// **'No valid owner found for this dog'**
  String get errorNoOwnerFound;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fa', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fa': return AppLocalizationsFa();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
