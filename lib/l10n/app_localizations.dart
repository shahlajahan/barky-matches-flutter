import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_ru.dart';
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
    Locale('ru'),
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

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get cartTitle;

  /// No description provided for @cartIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Cart is empty'**
  String get cartIsEmpty;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @checkoutButton.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkoutButton;

  /// No description provided for @checkoutStepAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get checkoutStepAddressTitle;

  /// No description provided for @checkoutStepPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get checkoutStepPaymentTitle;

  /// No description provided for @checkoutStepConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get checkoutStepConfirmTitle;

  /// No description provided for @checkoutDeliveryAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get checkoutDeliveryAddressTitle;

  /// No description provided for @checkoutFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get checkoutFullNameLabel;

  /// No description provided for @checkoutFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name Surname'**
  String get checkoutFullNameHint;

  /// No description provided for @checkoutPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'5XXXXXXXXX'**
  String get checkoutPhoneHint;

  /// No description provided for @checkoutCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get checkoutCityLabel;

  /// No description provided for @checkoutCityHint.
  ///
  /// In en, this message translates to:
  /// **'Istanbul'**
  String get checkoutCityHint;

  /// No description provided for @checkoutDistrictLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get checkoutDistrictLabel;

  /// No description provided for @checkoutDistrictHint.
  ///
  /// In en, this message translates to:
  /// **'Kadikoy'**
  String get checkoutDistrictHint;

  /// No description provided for @checkoutAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Open Address'**
  String get checkoutAddressLabel;

  /// No description provided for @checkoutAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Full address details'**
  String get checkoutAddressHint;

  /// No description provided for @checkoutInvoiceDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice Details'**
  String get checkoutInvoiceDetailsTitle;

  /// No description provided for @checkoutIndividualOption.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get checkoutIndividualOption;

  /// No description provided for @checkoutCompanyOption.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get checkoutCompanyOption;

  /// No description provided for @checkoutIdentityNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Identity Number'**
  String get checkoutIdentityNumberLabel;

  /// No description provided for @checkoutIdentityNumberHint.
  ///
  /// In en, this message translates to:
  /// **'11 digits'**
  String get checkoutIdentityNumberHint;

  /// No description provided for @checkoutCompanyNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Company Name'**
  String get checkoutCompanyNameLabel;

  /// No description provided for @checkoutTaxNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Number'**
  String get checkoutTaxNumberLabel;

  /// No description provided for @checkoutTaxNumberHint.
  ///
  /// In en, this message translates to:
  /// **'10 digits'**
  String get checkoutTaxNumberHint;

  /// No description provided for @checkoutTaxOfficeLabel.
  ///
  /// In en, this message translates to:
  /// **'Tax Office'**
  String get checkoutTaxOfficeLabel;

  /// No description provided for @checkoutCargoUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice & Cargo Updates'**
  String get checkoutCargoUpdatesTitle;

  /// No description provided for @checkoutCargoUpdatesQuestion.
  ///
  /// In en, this message translates to:
  /// **'How should we send invoice and cargo tracking updates?'**
  String get checkoutCargoUpdatesQuestion;

  /// No description provided for @checkoutSmsOption.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get checkoutSmsOption;

  /// No description provided for @checkoutEmailOption.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get checkoutEmailOption;

  /// No description provided for @checkoutSmsEmailOption.
  ///
  /// In en, this message translates to:
  /// **'SMS + Email'**
  String get checkoutSmsEmailOption;

  /// No description provided for @checkoutAgreementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agreements'**
  String get checkoutAgreementsTitle;

  /// No description provided for @checkoutKvkkDisclosure.
  ///
  /// In en, this message translates to:
  /// **'I have read KVKK disclosure'**
  String get checkoutKvkkDisclosure;

  /// No description provided for @checkoutViewButton.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get checkoutViewButton;

  /// No description provided for @checkoutPreInfoForm.
  ///
  /// In en, this message translates to:
  /// **'I accept the pre-information form'**
  String get checkoutPreInfoForm;

  /// No description provided for @checkoutDistanceSalesAgreement.
  ///
  /// In en, this message translates to:
  /// **'I accept the distance sales agreement'**
  String get checkoutDistanceSalesAgreement;

  /// No description provided for @checkoutMarketingOptional.
  ///
  /// In en, this message translates to:
  /// **'Receive marketing messages (optional)'**
  String get checkoutMarketingOptional;

  /// No description provided for @checkoutDeliveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get checkoutDeliveryTitle;

  /// No description provided for @checkoutPaymentSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Summary'**
  String get checkoutPaymentSummaryTitle;

  /// No description provided for @checkoutSubtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get checkoutSubtotalLabel;

  /// No description provided for @checkoutVatLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get checkoutVatLabel;

  /// No description provided for @checkoutShippingLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get checkoutShippingLabel;

  /// No description provided for @checkoutPleaseSelectCargoCompany.
  ///
  /// In en, this message translates to:
  /// **'Please select a cargo company'**
  String get checkoutPleaseSelectCargoCompany;

  /// No description provided for @checkoutEnterNameSurname.
  ///
  /// In en, this message translates to:
  /// **'Enter name & surname'**
  String get checkoutEnterNameSurname;

  /// No description provided for @checkoutEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter valid email'**
  String get checkoutEnterValidEmail;

  /// No description provided for @checkoutEnterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter valid phone'**
  String get checkoutEnterValidPhone;

  /// No description provided for @checkoutEnterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter city'**
  String get checkoutEnterCity;

  /// No description provided for @checkoutEnterDistrict.
  ///
  /// In en, this message translates to:
  /// **'Enter district'**
  String get checkoutEnterDistrict;

  /// No description provided for @checkoutEnterFullAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter full address'**
  String get checkoutEnterFullAddress;

  /// No description provided for @checkoutEnterValidIdentityNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter valid identity number'**
  String get checkoutEnterValidIdentityNumber;

  /// No description provided for @checkoutEnterCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Enter company name'**
  String get checkoutEnterCompanyName;

  /// No description provided for @checkoutEnterValidTaxNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter valid tax number'**
  String get checkoutEnterValidTaxNumber;

  /// No description provided for @checkoutEnterTaxOffice.
  ///
  /// In en, this message translates to:
  /// **'Enter tax office'**
  String get checkoutEnterTaxOffice;

  /// No description provided for @checkoutAcceptRequiredAgreements.
  ///
  /// In en, this message translates to:
  /// **'Accept required agreements'**
  String get checkoutAcceptRequiredAgreements;

  /// No description provided for @checkoutPaymentPageOpenedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment page opened. Complete the payment, then return to the app.'**
  String get checkoutPaymentPageOpenedMessage;

  /// No description provided for @checkoutBackButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get checkoutBackButton;

  /// No description provided for @checkoutProceedToPayment.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get checkoutProceedToPayment;

  /// No description provided for @checkoutContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get checkoutContinueButton;

  /// No description provided for @checkoutPaymentCompletedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Payment completed successfully'**
  String get checkoutPaymentCompletedSuccessfully;

  /// No description provided for @checkoutPaymentCancelledOrIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Payment was cancelled or not completed'**
  String get checkoutPaymentCancelledOrIncomplete;

  /// No description provided for @checkoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed: {error}'**
  String checkoutFailed(Object error);

  /// Success message for sending adoption request
  ///
  /// In en, this message translates to:
  /// **'Adoption request sent for {dogName}!'**
  String adoptionRequestSent(Object dogName);

  /// Label for adoption centers section
  ///
  /// In en, this message translates to:
  /// **'Adoption Centers'**
  String get adoptionCentersTitle;

  /// Label for available dogs subpage
  ///
  /// In en, this message translates to:
  /// **'Available Dogs'**
  String get availableDogsTitle;

  /// Message when no adoption centers are available
  ///
  /// In en, this message translates to:
  /// **'No adoption centers available'**
  String get noAdoptionCentersAvailable;

  /// Message when no dogs are available in the selected center
  ///
  /// In en, this message translates to:
  /// **'No dogs available in this center'**
  String get noDogsAvailableInThisCenter;

  /// Title for adoption request sheet
  ///
  /// In en, this message translates to:
  /// **'Adoption Request'**
  String get adoptionRequestTitle;

  /// Label for phone input in adoption request sheet
  ///
  /// In en, this message translates to:
  /// **'Your Phone'**
  String get yourPhone;

  /// Label for adoption request message field
  ///
  /// In en, this message translates to:
  /// **'Why do you want to adopt?'**
  String get whyDoYouWantToAdopt;

  /// No description provided for @appointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get appointmentTitle;

  /// No description provided for @cancelAppointmentButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Appointment'**
  String get cancelAppointmentButton;

  /// No description provided for @cancelAppointmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Appointment?'**
  String get cancelAppointmentTitle;

  /// No description provided for @cancelAppointmentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this appointment?'**
  String get cancelAppointmentConfirmation;

  /// No description provided for @keepAppointmentButton.
  ///
  /// In en, this message translates to:
  /// **'Keep Appointment'**
  String get keepAppointmentButton;

  /// No description provided for @appointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled'**
  String get appointmentCancelled;

  /// No description provided for @cancellationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Cancellation is not allowed for this appointment.'**
  String get cancellationNotAllowed;

  /// No description provided for @cancelAppointmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not cancel appointment. Please try again.'**
  String get cancelAppointmentFailed;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Select Service'**
  String get selectService;

  /// No description provided for @selectPet.
  ///
  /// In en, this message translates to:
  /// **'Select Pet'**
  String get selectPet;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @selectDate.
  ///
  /// In en, this message translates to:
  /// **'Select Date'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select Time'**
  String get selectTime;

  /// No description provided for @appointmentNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note for the clinic...'**
  String get appointmentNoteHint;

  /// No description provided for @requestAppointment.
  ///
  /// In en, this message translates to:
  /// **'Request Appointment'**
  String get requestAppointment;

  /// No description provided for @requestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Sent 🐾'**
  String get requestSentTitle;

  /// No description provided for @requestSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Your appointment request has been sent to the clinic.'**
  String get requestSentMessage;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @alreadyBookedAtThisTime.
  ///
  /// In en, this message translates to:
  /// **'You already have a booking at this time. Please choose another time.'**
  String get alreadyBookedAtThisTime;

  /// No description provided for @invalidBookingData.
  ///
  /// In en, this message translates to:
  /// **'Invalid booking data. Please try again.'**
  String get invalidBookingData;

  /// No description provided for @serviceDefaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get serviceDefaultLabel;

  /// No description provided for @ageYearsSuffix.
  ///
  /// In en, this message translates to:
  /// **' years'**
  String get ageYearsSuffix;

  /// No description provided for @overviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overviewTitle;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsTitle;

  /// No description provided for @galleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get galleryTitle;

  /// No description provided for @shopTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shopTitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @workingHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHoursTitle;

  /// No description provided for @locationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationTitle;

  /// No description provided for @instagramTitle.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagramTitle;

  /// No description provided for @noClinicDescriptionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No clinic description available.'**
  String get noClinicDescriptionAvailable;

  /// No description provided for @instagramNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Instagram not available.'**
  String get instagramNotAvailable;

  /// No description provided for @workingHoursNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Working hours not available'**
  String get workingHoursNotAvailable;

  /// No description provided for @openStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openStatusOpen;

  /// No description provided for @openStatusClosingSoon.
  ///
  /// In en, this message translates to:
  /// **'Closing soon'**
  String get openStatusClosingSoon;

  /// No description provided for @openStatusClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get openStatusClosed;

  /// No description provided for @mostRelevant.
  ///
  /// In en, this message translates to:
  /// **'Most relevant'**
  String get mostRelevant;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @bookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book Appointment'**
  String get bookAppointment;

  /// No description provided for @noServicesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No services available'**
  String get noServicesAvailable;

  /// No description provided for @errorLoadingServices.
  ///
  /// In en, this message translates to:
  /// **'Error loading services: {error}'**
  String errorLoadingServices(Object error);

  /// No description provided for @noServicesProvided.
  ///
  /// In en, this message translates to:
  /// **'No services provided.'**
  String get noServicesProvided;

  /// No description provided for @reviewsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsCountLabel(Object count);

  /// No description provided for @topLabel.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get topLabel;

  /// No description provided for @mostHelpful.
  ///
  /// In en, this message translates to:
  /// **'Most helpful'**
  String get mostHelpful;

  /// No description provided for @couldNotUpdateLike.
  ///
  /// In en, this message translates to:
  /// **'Could not update like'**
  String get couldNotUpdateLike;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @beFirstToReview.
  ///
  /// In en, this message translates to:
  /// **'Be the first to review'**
  String get beFirstToReview;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @writeAReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get writeAReview;

  /// No description provided for @shareYourExperienceHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get shareYourExperienceHint;

  /// No description provided for @pleaseWriteSomething.
  ///
  /// In en, this message translates to:
  /// **'Please write something'**
  String get pleaseWriteSomething;

  /// No description provided for @pleaseLoginFirst.
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get pleaseLoginFirst;

  /// No description provided for @alreadyReviewedThisVet.
  ///
  /// In en, this message translates to:
  /// **'You already reviewed this vet'**
  String get alreadyReviewedThisVet;

  /// No description provided for @errorSubmittingReview.
  ///
  /// In en, this message translates to:
  /// **'Error submitting review'**
  String get errorSubmittingReview;

  /// No description provided for @errorLoadingReviews.
  ///
  /// In en, this message translates to:
  /// **'Error loading reviews: {error}'**
  String errorLoadingReviews(Object error);

  /// No description provided for @galleryNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Gallery not available.'**
  String get galleryNotAvailable;

  /// No description provided for @noGalleryMediaYet.
  ///
  /// In en, this message translates to:
  /// **'No gallery media yet.'**
  String get noGalleryMediaYet;

  /// No description provided for @shopSectionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Shop section will be connected here.'**
  String get shopSectionComingSoon;

  /// No description provided for @durationMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutesShort(Object minutes);

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
  String get usernameLabel;

  /// Label for email field
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// Label for phone number field
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

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
  /// **'PetSupo'**
  String get appTitle;

  /// Message shown while user data is loading
  ///
  /// In en, this message translates to:
  /// **'Loading user data...'**
  String get loadingUserData;

  /// Welcome message for the app
  ///
  /// In en, this message translates to:
  /// **'Welcome to PetSopu!'**
  String get welcomeToPetSopu;

  /// Part of welcome message
  ///
  /// In en, this message translates to:
  /// **'Welcome to'**
  String get welcomeTo;

  /// App name
  ///
  /// In en, this message translates to:
  /// **'PetSopu'**
  String get petSopu;

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

  /// Prefix text before the terms and conditions link
  ///
  /// In en, this message translates to:
  /// **'I accept the '**
  String get termsAndConditionsPrefix;

  /// Linked terms and conditions text
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditionsText;

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

  /// Validation message for a short phone number
  ///
  /// In en, this message translates to:
  /// **'Phone number is too short'**
  String get phoneNumberTooShort;

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

  /// Hint text for email address input
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddressHint;

  /// Snackbar message after sending password reset email
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent 📩'**
  String get passwordResetEmailSent;

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

  /// Auth error message when no signed-in user is returned
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get authUserNotFound;

  /// Auth error message for unverified email sign-in
  ///
  /// In en, this message translates to:
  /// **'Please verify your email before signing in.'**
  String get pleaseVerifyEmailBeforeSigningIn;

  /// Auth error message when user creation returns no user
  ///
  /// In en, this message translates to:
  /// **'User creation failed'**
  String get userCreationFailed;

  /// Error message when verification email sending fails
  ///
  /// In en, this message translates to:
  /// **'Verification email could not be sent'**
  String get verificationEmailCouldNotBeSent;

  /// Error message when verification session cannot be created
  ///
  /// In en, this message translates to:
  /// **'Verification session could not be created'**
  String get verificationSessionCouldNotBeCreated;

  /// Error message for already registered email during signup
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try logging in.'**
  String get emailAlreadyRegisteredTryLoggingIn;

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

  /// Subtitle on email verification page
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to your email'**
  String get enterVerificationCodeSentToEmail;

  /// Validation message for verification code length
  ///
  /// In en, this message translates to:
  /// **'Please enter the 6-digit code'**
  String get pleaseEnterSixDigitCode;

  /// Success message after email verification
  ///
  /// In en, this message translates to:
  /// **'Email verified successfully'**
  String get emailVerifiedSuccessfully;

  /// Error message for invalid verification code
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code'**
  String get invalidVerificationCode;

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

  /// Subtitle on auth sign-in page
  ///
  /// In en, this message translates to:
  /// **'Welcome back to BarkyMatches'**
  String get authWelcomeBackSubtitle;

  /// Subtitle on auth sign-up page
  ///
  /// In en, this message translates to:
  /// **'Create your BarkyMatches account'**
  String get authCreateAccountSubtitle;

  /// Snackbar shown after native auth reset
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get sessionExpiredPleaseSignInAgain;

  /// Message prompting sign-in for Playmate feature
  ///
  /// In en, this message translates to:
  /// **'Please Sign In to access Playmate'**
  String get signInToAccessPlaymate;

  /// No description provided for @findPlaymates.
  ///
  /// In en, this message translates to:
  /// **'Find Playmates'**
  String get findPlaymates;

  /// Message prompting sign-in for Find Friends feature
  ///
  /// In en, this message translates to:
  /// **'Find friends for your pet'**
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

  /// No description provided for @photosLabel.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosLabel;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @noMedia.
  ///
  /// In en, this message translates to:
  /// **'No media'**
  String get noMedia;

  /// Button label for saving changes
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Error message for duplicate dog name
  ///
  /// In en, this message translates to:
  /// **'A dog with the name {name} already exists!'**
  String dogNameAlreadyExists(Object name);

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

  /// No description provided for @basketTitle.
  ///
  /// In en, this message translates to:
  /// **'Basket'**
  String get basketTitle;

  /// No description provided for @basketItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String basketItemsCount(Object count);

  /// No description provided for @yourBasketIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your basket is empty'**
  String get yourBasketIsEmpty;

  /// No description provided for @sellerLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get sellerLabel;

  /// No description provided for @allProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'All Products'**
  String get allProductsTitle;

  /// No description provided for @sellerProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Seller Products'**
  String get sellerProductsTitle;

  /// No description provided for @searchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search product, brand, seller...'**
  String get searchProductsHint;

  /// No description provided for @allCategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategoriesLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @shippingLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shippingLabel;

  /// No description provided for @freeShippingLabel.
  ///
  /// In en, this message translates to:
  /// **'Free shipping'**
  String get freeShippingLabel;

  /// No description provided for @sellerPaysCargoLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller pays cargo'**
  String get sellerPaysCargoLabel;

  /// No description provided for @fixedCargoLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed cargo'**
  String get fixedCargoLabel;

  /// No description provided for @calculatedCargoLabel.
  ///
  /// In en, this message translates to:
  /// **'Calculated cargo'**
  String get calculatedCargoLabel;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @recommendedLabel.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommendedLabel;

  /// No description provided for @priceLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Price low'**
  String get priceLowLabel;

  /// No description provided for @priceHighLabel.
  ///
  /// In en, this message translates to:
  /// **'Price high'**
  String get priceHighLabel;

  /// No description provided for @bestDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Best discount'**
  String get bestDiscountLabel;

  /// No description provided for @productsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String productsCount(Object count);

  /// No description provided for @noProductsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No products match your filters'**
  String get noProductsMatchFilters;

  /// No description provided for @errorLoadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Error loading products: {error}'**
  String errorLoadingProducts(Object error);

  /// No description provided for @noActiveProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No active products found'**
  String get noActiveProductsFound;

  /// No description provided for @addedToBasket.
  ///
  /// In en, this message translates to:
  /// **'{productName} added to basket'**
  String addedToBasket(Object productName);

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @freeCargoLabel.
  ///
  /// In en, this message translates to:
  /// **'Free cargo'**
  String get freeCargoLabel;

  /// No description provided for @cargoPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Cargo {price}'**
  String cargoPriceLabel(Object price);

  /// No description provided for @cargoCalculatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Cargo calculated'**
  String get cargoCalculatedLabel;

  /// No description provided for @freeOverLabel.
  ///
  /// In en, this message translates to:
  /// **'Free over {price}'**
  String freeOverLabel(Object price);

  /// No description provided for @vatRateLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT {percent}%'**
  String vatRateLabel(Object percent);

  /// No description provided for @vatIncludedLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT included'**
  String get vatIncludedLabel;

  /// No description provided for @daysLabel.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String daysLabel(Object days);

  /// No description provided for @inStockLabel.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStockLabel;

  /// No description provided for @outOfStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get outOfStockLabel;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// Button label for showing more filters
  ///
  /// In en, this message translates to:
  /// **'More Filters'**
  String get moreFiltersButton;

  /// Label for the pet type filter
  ///
  /// In en, this message translates to:
  /// **'Pet Type'**
  String get petTypeLabel;

  /// Pet type option for dog
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get petTypeDog;

  /// Pet type option for cat
  ///
  /// In en, this message translates to:
  /// **'Cat'**
  String get petTypeCat;

  /// Pet type option for bird
  ///
  /// In en, this message translates to:
  /// **'Bird'**
  String get petTypeBird;

  /// Pet type option for horse
  ///
  /// In en, this message translates to:
  /// **'Horse'**
  String get petTypeHorse;

  /// Label for other gender
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get genderOther;

  /// Breed option for Persian cat
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get breedPersian;

  /// Breed option for Siamese cat
  ///
  /// In en, this message translates to:
  /// **'Siamese'**
  String get breedSiamese;

  /// Breed option for Maine Coon cat
  ///
  /// In en, this message translates to:
  /// **'Maine Coon'**
  String get breedMaineCoon;

  /// Breed option for British Shorthair cat
  ///
  /// In en, this message translates to:
  /// **'British Shorthair'**
  String get breedBritishShorthair;

  /// Breed option for parrot
  ///
  /// In en, this message translates to:
  /// **'Parrot'**
  String get breedParrot;

  /// Breed option for canary
  ///
  /// In en, this message translates to:
  /// **'Canary'**
  String get breedCanary;

  /// Breed option for budgerigar
  ///
  /// In en, this message translates to:
  /// **'Budgerigar'**
  String get breedBudgerigar;

  /// Breed option for Arabian horse
  ///
  /// In en, this message translates to:
  /// **'Arabian'**
  String get breedArabian;

  /// Breed option for thoroughbred horse
  ///
  /// In en, this message translates to:
  /// **'Thoroughbred'**
  String get breedThoroughbred;

  /// Breed option for mustang horse
  ///
  /// In en, this message translates to:
  /// **'Mustang'**
  String get breedMustang;

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

  /// No description provided for @upgradeToPremiumTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Premium'**
  String get upgradeToPremiumTitle;

  /// No description provided for @upgradeToPremiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock advanced features and business tools'**
  String get upgradeToPremiumSubtitle;

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

  /// Title for playdate request
  ///
  /// In en, this message translates to:
  /// **'Playdate Request'**
  String get playdateRequestTitle;

  /// Body/message for playdate request
  ///
  /// In en, this message translates to:
  /// **'{requesterDog} wants to play with {requestedDog}!'**
  String playdateRequestBody(Object requesterDog, Object requestedDog);

  /// Notification body for playdate request
  ///
  /// In en, this message translates to:
  /// **'{requesterDog} wants to play with {requestedDog}!'**
  String playdateRequestNotificationBody(Object requesterDog, Object requestedDog);

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
  String get newPlaydateRequestTitle;

  /// Body for new playdate request notification
  ///
  /// In en, this message translates to:
  /// **'{requesterDog} wants to play with {requestedDog}!'**
  String newPlaydateRequestBody(Object requesterDog, Object requestedDog);

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

  /// No description provided for @pleaseLoginToViewPlaydateRequests.
  ///
  /// In en, this message translates to:
  /// **'Login to view playdate requests'**
  String get pleaseLoginToViewPlaydateRequests;

  /// No description provided for @pleaseLoginToSetReminders.
  ///
  /// In en, this message translates to:
  /// **'Please login to set reminders.'**
  String get pleaseLoginToSetReminders;

  /// Confirmation shown after creating a playdate reminder
  ///
  /// In en, this message translates to:
  /// **'Reminder set for {minutesBefore} minutes before 🐾'**
  String reminderSetForMinutesBefore(Object minutesBefore);

  /// No description provided for @failedToSetReminder.
  ///
  /// In en, this message translates to:
  /// **'Failed to set reminder ❌'**
  String get failedToSetReminder;

  /// No description provided for @playdateAcceptedCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Playdate Accepted 🐾'**
  String get playdateAcceptedCardTitle;

  /// Accepted playdate message shown on the requests page
  ///
  /// In en, this message translates to:
  /// **'{dogName} accepted your playdate request.\nBe happy — a tail-wagging meeting awaits! 🐶💖'**
  String playdateAcceptedCardBody(Object dogName);

  /// No description provided for @playdateRejectedCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Playdate Not This Time'**
  String get playdateRejectedCardTitle;

  /// Rejected playdate message shown on the requests page
  ///
  /// In en, this message translates to:
  /// **'{dogName} couldn’t accept this time.\nNo worries — try again and keep the paws moving 🐾'**
  String playdateRejectedCardBody(Object dogName);

  /// No description provided for @dogTab.
  ///
  /// In en, this message translates to:
  /// **'Dog'**
  String get dogTab;

  /// No description provided for @reminderTab.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderTab;

  /// No description provided for @playdateTimeNotScheduledYet.
  ///
  /// In en, this message translates to:
  /// **'⏳ Playdate time not scheduled yet'**
  String get playdateTimeNotScheduledYet;

  /// No description provided for @thirtyMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'30 minutes before'**
  String get thirtyMinutesBefore;

  /// No description provided for @oneHourBefore.
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get oneHourBefore;

  /// No description provided for @reminderSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder set ✅'**
  String get reminderSet;

  /// No description provided for @viewLocation.
  ///
  /// In en, this message translates to:
  /// **'View location'**
  String get viewLocation;

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

  /// Search hint for Playmate page
  ///
  /// In en, this message translates to:
  /// **'Search dogs...'**
  String get playmateSearchHint;

  /// Title for the Playmate location permission dialog
  ///
  /// In en, this message translates to:
  /// **'Location needed'**
  String get playmateLocationNeededTitle;

  /// Message for the Playmate location permission dialog
  ///
  /// In en, this message translates to:
  /// **'We use your location to show nearby dogs'**
  String get playmateLocationNeededMessage;

  /// Title for the Playmate filters overlay
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get playmateFiltersTitle;

  /// Locked breed hint for non-Gold users
  ///
  /// In en, this message translates to:
  /// **'Breed (Gold)'**
  String get playmateBreedPremiumHint;

  /// Locked owner gender hint for non-Premium users
  ///
  /// In en, this message translates to:
  /// **'Owner Gender (Premium)'**
  String get playmateOwnerGenderPremiumHint;

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
  /// **'Dog Park'**
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

  /// No description provided for @dogParkRecommendedBadge.
  ///
  /// In en, this message translates to:
  /// **'⭐ Recommended'**
  String get dogParkRecommendedBadge;

  /// No description provided for @dogParkPremiumBadge.
  ///
  /// In en, this message translates to:
  /// **'🔒 Premium'**
  String get dogParkPremiumBadge;

  /// No description provided for @dogParkSavedBadge.
  ///
  /// In en, this message translates to:
  /// **'❤️ Saved'**
  String get dogParkSavedBadge;

  /// No description provided for @dogParkRecommendedForPlaydates.
  ///
  /// In en, this message translates to:
  /// **'Recommended for Playdates'**
  String get dogParkRecommendedForPlaydates;

  /// No description provided for @dogParkSavedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Saved to Favorites'**
  String get dogParkSavedToFavorites;

  /// No description provided for @dogParkSaveThisPark.
  ///
  /// In en, this message translates to:
  /// **'Save this Park'**
  String get dogParkSaveThisPark;

  /// No description provided for @dogParkGetDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get dogParkGetDirections;

  /// No description provided for @dogParkUserNotReadyYet.
  ///
  /// In en, this message translates to:
  /// **'User not ready yet. Please try again.'**
  String get dogParkUserNotReadyYet;

  /// No description provided for @dogParkNeedToAddDogFirst.
  ///
  /// In en, this message translates to:
  /// **'You need to add a dog first'**
  String get dogParkNeedToAddDogFirst;

  /// No description provided for @dogParkSchedulePlaydateHere.
  ///
  /// In en, this message translates to:
  /// **'Schedule Playdate here'**
  String get dogParkSchedulePlaydateHere;

  /// No description provided for @dogParkSavedParksTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Parks'**
  String get dogParkSavedParksTitle;

  /// No description provided for @dogParkNoSavedParksYet.
  ///
  /// In en, this message translates to:
  /// **'No saved parks yet'**
  String get dogParkNoSavedParksYet;

  /// No description provided for @dogParkFindNearbyParks.
  ///
  /// In en, this message translates to:
  /// **'Find nearby parks'**
  String get dogParkFindNearbyParks;

  /// No description provided for @dogParkLocationNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Location needed'**
  String get dogParkLocationNeededTitle;

  /// No description provided for @dogParkUseYourLocationToShowNearbyDogParks.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show nearby dog parks'**
  String get dogParkUseYourLocationToShowNearbyDogParks;

  /// No description provided for @allowButton.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allowButton;

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

  /// No description provided for @distanceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Distance unknown'**
  String get distanceUnknown;

  /// No description provided for @boostDogTitle.
  ///
  /// In en, this message translates to:
  /// **'Boost {dogName}'**
  String boostDogTitle(Object dogName);

  /// No description provided for @boostVisibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'Get more visibility in Playmates discovery.'**
  String get boostVisibilityDescription;

  /// No description provided for @boost24HoursTitle.
  ///
  /// In en, this message translates to:
  /// **'24 Hours Boost'**
  String get boost24HoursTitle;

  /// No description provided for @boostQuickVisibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Good for quick visibility'**
  String get boostQuickVisibilitySubtitle;

  /// No description provided for @boostPrice29.
  ///
  /// In en, this message translates to:
  /// **'₺29'**
  String get boostPrice29;

  /// No description provided for @boost3DaysTitle.
  ///
  /// In en, this message translates to:
  /// **'3 Days Boost'**
  String get boost3DaysTitle;

  /// No description provided for @boostBetterExposureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Better exposure for active discovery'**
  String get boostBetterExposureSubtitle;

  /// No description provided for @boostPrice69.
  ///
  /// In en, this message translates to:
  /// **'₺69'**
  String get boostPrice69;

  /// No description provided for @boost7DaysTitle.
  ///
  /// In en, this message translates to:
  /// **'7 Days Boost'**
  String get boost7DaysTitle;

  /// No description provided for @boostBestValueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Best value for maximum reach'**
  String get boostBestValueSubtitle;

  /// No description provided for @boostPrice129.
  ///
  /// In en, this message translates to:
  /// **'₺129'**
  String get boostPrice129;

  /// No description provided for @boostActivated.
  ///
  /// In en, this message translates to:
  /// **'Boost activated 🚀'**
  String get boostActivated;

  /// No description provided for @boostFailed.
  ///
  /// In en, this message translates to:
  /// **'Boost failed: {error}'**
  String boostFailed(Object error);

  /// No description provided for @errorOpeningEdit.
  ///
  /// In en, this message translates to:
  /// **'Error opening edit'**
  String get errorOpeningEdit;

  /// No description provided for @boostBadge.
  ///
  /// In en, this message translates to:
  /// **'BOOSTED'**
  String get boostBadge;

  /// No description provided for @boostButton.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get boostButton;

  /// No description provided for @blockComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Block coming soon'**
  String get blockComingSoon;

  /// No description provided for @blockMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockMenuItem;

  /// No description provided for @sendAdoptionRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Adoption Request'**
  String get sendAdoptionRequest;

  /// No description provided for @ownerPrefix.
  ///
  /// In en, this message translates to:
  /// **'Owner: {owner}'**
  String ownerPrefix(Object owner);

  /// No description provided for @submitComplaintMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Submit Complaint'**
  String get submitComplaintMenuItem;

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

  /// No description provided for @playdateSchedulingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick date, time, location and dogs for the playdate.'**
  String get playdateSchedulingSubtitle;

  /// No description provided for @errorSelectDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Please select date and time.'**
  String get errorSelectDateAndTime;

  /// No description provided for @errorMissingLocationCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Park location coordinates missing.'**
  String get errorMissingLocationCoordinates;

  /// No description provided for @errorPlaydateLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Playdate must be scheduled at least 15 minutes in advance.'**
  String get errorPlaydateLeadTime;

  /// No description provided for @playdateTimeConflict.
  ///
  /// In en, this message translates to:
  /// **'This dog already has a playdate around this time 🐾'**
  String get playdateTimeConflict;

  /// Displayed when a picked map location is converted to text
  ///
  /// In en, this message translates to:
  /// **'Lat: {lat}, Lng: {lng}'**
  String coordinatesLatLng(Object lat, Object lng);

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

  /// Badge text for sponsored offers
  ///
  /// In en, this message translates to:
  /// **'🔥 Hot Deal'**
  String get offerHotDeal;

  /// Badge text for premium-only offers
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get offerPremiumBadge;

  /// Fallback title when offer title is missing
  ///
  /// In en, this message translates to:
  /// **'Special offer for Barky users'**
  String get offerFallbackTitle;

  /// Fallback provider name when provider is missing
  ///
  /// In en, this message translates to:
  /// **'Partner brand'**
  String get offerFallbackProvider;

  /// CTA label shown on offer card when an offer code or action is available
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get offerUnlock;

  /// CTA label shown on offer card when no code exists
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get offerView;

  /// Discount label on offer card
  ///
  /// In en, this message translates to:
  /// **'{discount}% OFF'**
  String offerDiscountPercent(Object discount);

  /// Dialog title shown when a premium-only offer is tapped by a non-premium user
  ///
  /// In en, this message translates to:
  /// **'Premium Required'**
  String get offerPremiumRequiredTitle;

  /// Dialog message shown when a premium-only offer is tapped by a non-premium user
  ///
  /// In en, this message translates to:
  /// **'This offer is only for premium members.'**
  String get offerPremiumRequiredMessage;

  /// Cancel button in offer premium dialog
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get offerCancel;

  /// Upgrade button in offer premium dialog
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get offerUpgrade;

  /// SnackBar shown when an offer is being opened
  ///
  /// In en, this message translates to:
  /// **'Unlocking your deal...'**
  String get offerUnlockingMessage;

  /// Bottom sheet title for choosing an offer contact method
  ///
  /// In en, this message translates to:
  /// **'Choose where to continue'**
  String get offerChooseContinueTitle;

  /// Bottom sheet subtitle for choosing an offer contact method
  ///
  /// In en, this message translates to:
  /// **'Pick your preferred contact option for this offer.'**
  String get offerChooseContinueSubtitle;

  /// CTA label for opening an offer website
  ///
  /// In en, this message translates to:
  /// **'Open Website'**
  String get offerOpenWebsite;

  /// CTA label for opening Instagram for an offer
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get offerInstagram;

  /// No description provided for @playdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Playdates'**
  String get playdatesTitle;

  /// No description provided for @manageRequests.
  ///
  /// In en, this message translates to:
  /// **'Manage requests'**
  String get manageRequests;

  /// No description provided for @adoptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Adoption'**
  String get adoptionTitle;

  /// No description provided for @giveLove.
  ///
  /// In en, this message translates to:
  /// **'Give love'**
  String get giveLove;

  /// No description provided for @alertsTitle.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alertsTitle;

  /// No description provided for @lostAndFound.
  ///
  /// In en, this message translates to:
  /// **'Lost & Found'**
  String get lostAndFound;

  /// No description provided for @vetTitle.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get vetTitle;

  /// No description provided for @nearbyClinics.
  ///
  /// In en, this message translates to:
  /// **'Nearby clinics'**
  String get nearbyClinics;

  /// No description provided for @groomyTitle.
  ///
  /// In en, this message translates to:
  /// **'Groomy'**
  String get groomyTitle;

  /// No description provided for @bookGrooming.
  ///
  /// In en, this message translates to:
  /// **'Book grooming'**
  String get bookGrooming;

  /// No description provided for @pamperYourPet.
  ///
  /// In en, this message translates to:
  /// **'Pamper your pet'**
  String get pamperYourPet;

  /// No description provided for @petShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Shop'**
  String get petShopTitle;

  /// No description provided for @shopNearYou.
  ///
  /// In en, this message translates to:
  /// **'Shop near you'**
  String get shopNearYou;

  /// No description provided for @featuredDeal.
  ///
  /// In en, this message translates to:
  /// **'Featured Deal'**
  String get featuredDeal;

  /// No description provided for @premiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumLabel;

  /// No description provided for @goldLabel.
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get goldLabel;

  /// No description provided for @discountOff.
  ///
  /// In en, this message translates to:
  /// **'{percent}% OFF'**
  String discountOff(Object percent);

  /// No description provided for @socialAndPlay.
  ///
  /// In en, this message translates to:
  /// **'Social & Play'**
  String get socialAndPlay;

  /// No description provided for @careAndServices.
  ///
  /// In en, this message translates to:
  /// **'Care & Services'**
  String get careAndServices;

  /// No description provided for @outdoorAndLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Outdoor & Lifestyle'**
  String get outdoorAndLifestyle;

  /// No description provided for @exploreNearbyParks.
  ///
  /// In en, this message translates to:
  /// **'Explore nearby parks'**
  String get exploreNearbyParks;

  /// No description provided for @createMemoriesTogether.
  ///
  /// In en, this message translates to:
  /// **'Create memories together'**
  String get createMemoriesTogether;

  /// No description provided for @reportFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Report Found'**
  String get reportFoundTitle;

  /// No description provided for @reconnectFamilies.
  ///
  /// In en, this message translates to:
  /// **'Help reunite pets with their families'**
  String get reconnectFamilies;

  /// No description provided for @lostPetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lost Pets'**
  String get lostPetsTitle;

  /// No description provided for @activeReportsNearby.
  ///
  /// In en, this message translates to:
  /// **'View active missing pet reports'**
  String get activeReportsNearby;

  /// No description provided for @foundPetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Pets'**
  String get foundPetsTitle;

  /// No description provided for @waitingToReunite.
  ///
  /// In en, this message translates to:
  /// **'Pets waiting to return home'**
  String get waitingToReunite;

  /// No description provided for @trainingTitle.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get trainingTitle;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @trainingComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'Training feature coming soon 🐾'**
  String get trainingComingSoonMessage;

  /// No description provided for @communityHub.
  ///
  /// In en, this message translates to:
  /// **'Community Hub'**
  String get communityHub;

  /// No description provided for @safetyAndRescue.
  ///
  /// In en, this message translates to:
  /// **'Safety & Rescue'**
  String get safetyAndRescue;

  /// No description provided for @activeCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String activeCount(Object count);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportTitle;

  /// No description provided for @lostDogTitle.
  ///
  /// In en, this message translates to:
  /// **'Lost Dog'**
  String get lostDogTitle;

  /// No description provided for @lostPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Lost Pet'**
  String get lostPetTitle;

  /// No description provided for @foundDogTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Dog'**
  String get foundDogTitle;

  /// No description provided for @foundPetTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Pet'**
  String get foundPetTitle;

  /// No description provided for @lostTitle.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get lostTitle;

  /// No description provided for @dogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get dogsTitle;

  /// No description provided for @petsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get petsTitle;

  /// No description provided for @foundTitle.
  ///
  /// In en, this message translates to:
  /// **'Found'**
  String get foundTitle;

  /// No description provided for @homeDefaultUsername.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get homeDefaultUsername;

  /// No description provided for @homePetHotelTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Hotel'**
  String get homePetHotelTitle;

  /// No description provided for @homeSafeStaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Safe stay'**
  String get homeSafeStaySubtitle;

  /// No description provided for @homePetTaxiTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi'**
  String get homePetTaxiTitle;

  /// No description provided for @homeRideSafelySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ride safely'**
  String get homeRideSafelySubtitle;

  /// No description provided for @homeGreenMemorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Green Memorial'**
  String get homeGreenMemorialTitle;

  /// No description provided for @homeVeterinaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Veterinary'**
  String get homeVeterinaryTitle;

  /// No description provided for @expertCareForYourPet.
  ///
  /// In en, this message translates to:
  /// **'Expert care for your pet'**
  String get expertCareForYourPet;

  /// No description provided for @homeLocationNeededTitle.
  ///
  /// In en, this message translates to:
  /// **'Location needed'**
  String get homeLocationNeededTitle;

  /// No description provided for @homeLocationNeededMessage.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show nearby vets'**
  String get homeLocationNeededMessage;

  /// No description provided for @homeAllowButton.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get homeAllowButton;

  /// No description provided for @homeBusinessesTitle.
  ///
  /// In en, this message translates to:
  /// **'Businesses'**
  String get homeBusinessesTitle;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search services, shops, community...'**
  String get homeSearchHint;

  /// No description provided for @homePetFriendlyPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Friendly Place'**
  String get homePetFriendlyPlaceTitle;

  /// No description provided for @homeSponsoredLabel.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get homeSponsoredLabel;

  /// No description provided for @homeShopButton.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get homeShopButton;

  /// No description provided for @petShopDealName.
  ///
  /// In en, this message translates to:
  /// **'Pet Shop A'**
  String get petShopDealName;

  /// No description provided for @petShopDealDesc.
  ///
  /// In en, this message translates to:
  /// **'15% OFF on all food'**
  String get petShopDealDesc;

  /// No description provided for @groomyDealName.
  ///
  /// In en, this message translates to:
  /// **'Groomy Studio'**
  String get groomyDealName;

  /// No description provided for @groomyDealDesc.
  ///
  /// In en, this message translates to:
  /// **'20% OFF grooming this week'**
  String get groomyDealDesc;

  /// No description provided for @vetDealName.
  ///
  /// In en, this message translates to:
  /// **'VetPlus'**
  String get vetDealName;

  /// No description provided for @vetDealDesc.
  ///
  /// In en, this message translates to:
  /// **'Gold members: free checkup'**
  String get vetDealDesc;

  /// CTA label for opening WhatsApp for an offer
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get offerWhatsApp;

  /// SnackBar shown when an offer code is copied
  ///
  /// In en, this message translates to:
  /// **'Code copied: {code}'**
  String offerCodeCopied(Object code);

  /// SnackBar shown when opening an offer fails
  ///
  /// In en, this message translates to:
  /// **'Error opening offer'**
  String get offerOpenError;

  /// No description provided for @businessRegisterLegalCompanyNameRequired.
  ///
  /// In en, this message translates to:
  /// **'• Legal Company Name is required.'**
  String get businessRegisterLegalCompanyNameRequired;

  /// No description provided for @businessRegisterPublicDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'• Public Display Name is required.'**
  String get businessRegisterPublicDisplayNameRequired;

  /// No description provided for @businessRegisterSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'• Please select a Country.'**
  String get businessRegisterSelectCountry;

  /// No description provided for @businessRegisterSelectBusinessCategory.
  ///
  /// In en, this message translates to:
  /// **'• Please select at least one business category.'**
  String get businessRegisterSelectBusinessCategory;

  /// No description provided for @businessRegisterEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'• Enter a valid email address (example: name@example.com).'**
  String get businessRegisterEnterValidEmail;

  /// No description provided for @businessRegisterPhoneIncomplete.
  ///
  /// In en, this message translates to:
  /// **'• Phone number is incomplete.'**
  String get businessRegisterPhoneIncomplete;

  /// No description provided for @businessRegisterSelectCityProvince.
  ///
  /// In en, this message translates to:
  /// **'• Please select City / Province.'**
  String get businessRegisterSelectCityProvince;

  /// No description provided for @businessRegisterSelectDistrict.
  ///
  /// In en, this message translates to:
  /// **'• Please select District.'**
  String get businessRegisterSelectDistrict;

  /// No description provided for @businessRegisterBusinessAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'• Business Address is required.'**
  String get businessRegisterBusinessAddressRequired;

  /// No description provided for @businessRegisterAllLegalDocumentsRequired.
  ///
  /// In en, this message translates to:
  /// **'• All required legal documents must be uploaded.'**
  String get businessRegisterAllLegalDocumentsRequired;

  /// No description provided for @businessRegisterDocumentsVerifiedBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'• Documents must be verified before continuing.'**
  String get businessRegisterDocumentsVerifiedBeforeContinuing;

  /// No description provided for @businessRegisterAcceptPlatformTerms.
  ///
  /// In en, this message translates to:
  /// **'• You must accept the Platform Terms.'**
  String get businessRegisterAcceptPlatformTerms;

  /// No description provided for @businessRegisterAcceptLegalResponsibility.
  ///
  /// In en, this message translates to:
  /// **'• You must accept legal responsibility declaration.'**
  String get businessRegisterAcceptLegalResponsibility;

  /// No description provided for @businessRegisterFixHighlightedFields.
  ///
  /// In en, this message translates to:
  /// **'Please fix the highlighted fields'**
  String get businessRegisterFixHighlightedFields;

  /// No description provided for @businessRegisterOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get businessRegisterOk;

  /// No description provided for @businessRegisterFailedToLoadCountries.
  ///
  /// In en, this message translates to:
  /// **'Failed to load countries'**
  String get businessRegisterFailedToLoadCountries;

  /// No description provided for @businessRegisterFailedToLoadCities.
  ///
  /// In en, this message translates to:
  /// **'Failed to load cities'**
  String get businessRegisterFailedToLoadCities;

  /// No description provided for @businessRegisterFailedToLoadDistricts.
  ///
  /// In en, this message translates to:
  /// **'Failed to load districts'**
  String get businessRegisterFailedToLoadDistricts;

  /// No description provided for @businessRegisterPlatformLegalAgreement.
  ///
  /// In en, this message translates to:
  /// **'Platform Legal Agreement'**
  String get businessRegisterPlatformLegalAgreement;

  /// No description provided for @businessRegisterReadAndAccept.
  ///
  /// In en, this message translates to:
  /// **'I Have Read and Accept'**
  String get businessRegisterReadAndAccept;

  /// No description provided for @businessRegisterLocationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission denied'**
  String get businessRegisterLocationPermissionDenied;

  /// No description provided for @businessRegisterCouldNotDetectCity.
  ///
  /// In en, this message translates to:
  /// **'Could not detect city'**
  String get businessRegisterCouldNotDetectCity;

  /// No description provided for @businessRegisterGroomer.
  ///
  /// In en, this message translates to:
  /// **'Groomer'**
  String get businessRegisterGroomer;

  /// No description provided for @businessRegisterVeterinaryClinic.
  ///
  /// In en, this message translates to:
  /// **'Veterinary Clinic'**
  String get businessRegisterVeterinaryClinic;

  /// No description provided for @businessRegisterDogTrainer.
  ///
  /// In en, this message translates to:
  /// **'Dog Trainer'**
  String get businessRegisterDogTrainer;

  /// No description provided for @businessRegisterPetHotel.
  ///
  /// In en, this message translates to:
  /// **'Pet Hotel'**
  String get businessRegisterPetHotel;

  /// No description provided for @businessRegisterDogWalker.
  ///
  /// In en, this message translates to:
  /// **'Dog Walker'**
  String get businessRegisterDogWalker;

  /// No description provided for @businessRegisterBreeder.
  ///
  /// In en, this message translates to:
  /// **'Breeder'**
  String get businessRegisterBreeder;

  /// No description provided for @businessRegisterInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get businessRegisterInvalidEmail;

  /// No description provided for @businessRegisterInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Invalid phone'**
  String get businessRegisterInvalidPhone;

  /// No description provided for @businessRegisterInvalidWebsite.
  ///
  /// In en, this message translates to:
  /// **'Invalid website'**
  String get businessRegisterInvalidWebsite;

  /// No description provided for @businessRegisterCouldNotOpenLegalText.
  ///
  /// In en, this message translates to:
  /// **'Could not open legal text'**
  String get businessRegisterCouldNotOpenLegalText;

  /// No description provided for @businessRegisterSelectAtLeastOneBusinessCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one business category'**
  String get businessRegisterSelectAtLeastOneBusinessCategory;

  /// No description provided for @businessRegisterPleaseEnterBusinessAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter business address'**
  String get businessRegisterPleaseEnterBusinessAddress;

  /// No description provided for @businessRegisterMustAcceptAllAgreements.
  ///
  /// In en, this message translates to:
  /// **'You must accept all agreements'**
  String get businessRegisterMustAcceptAllAgreements;

  /// No description provided for @businessRegisterDocumentsVerifiedBeforeSubmission.
  ///
  /// In en, this message translates to:
  /// **'Documents must be verified before submission'**
  String get businessRegisterDocumentsVerifiedBeforeSubmission;

  /// No description provided for @businessRegisterApplicationSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Application submitted successfully'**
  String get businessRegisterApplicationSubmittedSuccessfully;

  /// No description provided for @businessRegisterSubmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed'**
  String get businessRegisterSubmissionFailed;

  /// No description provided for @businessRegisterUnexpectedErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error occurred'**
  String get businessRegisterUnexpectedErrorOccurred;

  /// No description provided for @businessRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Business'**
  String get businessRegisterTitle;

  /// No description provided for @businessRegisterStepIdentityCategories.
  ///
  /// In en, this message translates to:
  /// **'Business identity and categories'**
  String get businessRegisterStepIdentityCategories;

  /// No description provided for @businessRegisterStepContactLocation.
  ///
  /// In en, this message translates to:
  /// **'Contact and location'**
  String get businessRegisterStepContactLocation;

  /// No description provided for @businessRegisterStepLegalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Legal documents'**
  String get businessRegisterStepLegalDocuments;

  /// No description provided for @businessRegisterStepAgreementConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Agreement confirmation'**
  String get businessRegisterStepAgreementConfirmation;

  /// No description provided for @businessRegisterBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get businessRegisterBack;

  /// No description provided for @businessRegisterContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get businessRegisterContinue;

  /// No description provided for @businessRegisterSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit Application'**
  String get businessRegisterSubmitApplication;

  /// No description provided for @businessRegisterCompleteSectorDetails.
  ///
  /// In en, this message translates to:
  /// **'Complete Sector Details'**
  String get businessRegisterCompleteSectorDetails;

  /// No description provided for @businessRegisterBusinessIdentity.
  ///
  /// In en, this message translates to:
  /// **'Business identity'**
  String get businessRegisterBusinessIdentity;

  /// No description provided for @businessRegisterBusinessIdentitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us how your business should appear on PetSupo.'**
  String get businessRegisterBusinessIdentitySubtitle;

  /// No description provided for @businessRegisterLegalCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Legal Company Name'**
  String get businessRegisterLegalCompanyName;

  /// No description provided for @businessRegisterRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get businessRegisterRequired;

  /// No description provided for @businessRegisterPublicDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Public Display Name'**
  String get businessRegisterPublicDisplayName;

  /// No description provided for @businessRegisterCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get businessRegisterCountry;

  /// No description provided for @businessRegisterBusinessCategories.
  ///
  /// In en, this message translates to:
  /// **'Business categories'**
  String get businessRegisterBusinessCategories;

  /// No description provided for @businessRegisterBusinessCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select all sectors this business operates in.'**
  String get businessRegisterBusinessCategoriesSubtitle;

  /// No description provided for @businessRegisterContactLocation.
  ///
  /// In en, this message translates to:
  /// **'Contact & location'**
  String get businessRegisterContactLocation;

  /// No description provided for @businessRegisterContactLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'These details help customers find and contact you.'**
  String get businessRegisterContactLocationSubtitle;

  /// No description provided for @businessRegisterPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get businessRegisterPhone;

  /// No description provided for @businessRegisterWebsiteOptional.
  ///
  /// In en, this message translates to:
  /// **'Website (optional)'**
  String get businessRegisterWebsiteOptional;

  /// No description provided for @businessRegisterLoadingCities.
  ///
  /// In en, this message translates to:
  /// **'Loading cities...'**
  String get businessRegisterLoadingCities;

  /// No description provided for @businessRegisterCityProvince.
  ///
  /// In en, this message translates to:
  /// **'City / Province'**
  String get businessRegisterCityProvince;

  /// No description provided for @businessRegisterLoadingDistricts.
  ///
  /// In en, this message translates to:
  /// **'Loading districts...'**
  String get businessRegisterLoadingDistricts;

  /// No description provided for @businessRegisterDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get businessRegisterDistrict;

  /// No description provided for @businessRegisterBusinessAddress.
  ///
  /// In en, this message translates to:
  /// **'Business Address'**
  String get businessRegisterBusinessAddress;

  /// No description provided for @businessRegisterDetectCity.
  ///
  /// In en, this message translates to:
  /// **'Detect City'**
  String get businessRegisterDetectCity;

  /// No description provided for @businessRegisterMapPickerComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Map picker will be added soon'**
  String get businessRegisterMapPickerComingSoon;

  /// No description provided for @businessRegisterPickLocation.
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get businessRegisterPickLocation;

  /// No description provided for @businessRegisterLocationSelected.
  ///
  /// In en, this message translates to:
  /// **'Location selected'**
  String get businessRegisterLocationSelected;

  /// No description provided for @businessRegisterTaxPlate.
  ///
  /// In en, this message translates to:
  /// **'Vergi Levhası (Tax Plate)'**
  String get businessRegisterTaxPlate;

  /// No description provided for @businessRegisterTradeRegistryGazette.
  ///
  /// In en, this message translates to:
  /// **'Ticaret Sicil Gazetesi'**
  String get businessRegisterTradeRegistryGazette;

  /// No description provided for @businessRegisterAuthorizedSignatureDocument.
  ///
  /// In en, this message translates to:
  /// **'Yetkili İmza Belgesi'**
  String get businessRegisterAuthorizedSignatureDocument;

  /// No description provided for @businessRegisterTaxNumberVkn.
  ///
  /// In en, this message translates to:
  /// **'Tax Number (VKN)'**
  String get businessRegisterTaxNumberVkn;

  /// No description provided for @businessRegisterAutoFilledFromDocument.
  ///
  /// In en, this message translates to:
  /// **'Auto-filled from document'**
  String get businessRegisterAutoFilledFromDocument;

  /// No description provided for @businessRegisterDocumentVerificationInconsistencies.
  ///
  /// In en, this message translates to:
  /// **'Document verification has inconsistencies. Admin review required.'**
  String get businessRegisterDocumentVerificationInconsistencies;

  /// No description provided for @businessRegisterMersisNumber.
  ///
  /// In en, this message translates to:
  /// **'MERSIS Number'**
  String get businessRegisterMersisNumber;

  /// No description provided for @businessRegisterDocumentsSecurelyEncrypted.
  ///
  /// In en, this message translates to:
  /// **'Your documents are securely encrypted and verified automatically'**
  String get businessRegisterDocumentsSecurelyEncrypted;

  /// No description provided for @businessRegisterVerifiedFromDocument.
  ///
  /// In en, this message translates to:
  /// **'Verified from document'**
  String get businessRegisterVerifiedFromDocument;

  /// No description provided for @businessRegisterAutoFilledAfterVerification.
  ///
  /// In en, this message translates to:
  /// **'Auto-filled after document verification'**
  String get businessRegisterAutoFilledAfterVerification;

  /// No description provided for @businessRegisterUploadTradeRegistryFirst.
  ///
  /// In en, this message translates to:
  /// **'Upload Trade Registry first'**
  String get businessRegisterUploadTradeRegistryFirst;

  /// No description provided for @businessRegisterWaitingForDocumentVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for document verification...'**
  String get businessRegisterWaitingForDocumentVerification;

  /// No description provided for @businessRegisterSteuernummer.
  ///
  /// In en, this message translates to:
  /// **'Steuernummer'**
  String get businessRegisterSteuernummer;

  /// No description provided for @businessRegisterTaxNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Tax Number is required'**
  String get businessRegisterTaxNumberRequired;

  /// No description provided for @businessRegisterGewerbeschein.
  ///
  /// In en, this message translates to:
  /// **'Gewerbeschein'**
  String get businessRegisterGewerbeschein;

  /// No description provided for @businessRegisterHandelsregisterauszug.
  ///
  /// In en, this message translates to:
  /// **'Handelsregisterauszug'**
  String get businessRegisterHandelsregisterauszug;

  /// No description provided for @businessRegisterEinNumber.
  ///
  /// In en, this message translates to:
  /// **'EIN Number'**
  String get businessRegisterEinNumber;

  /// No description provided for @businessRegisterEinNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'EIN Number is required'**
  String get businessRegisterEinNumberRequired;

  /// No description provided for @businessRegisterBusinessLicense.
  ///
  /// In en, this message translates to:
  /// **'Business License'**
  String get businessRegisterBusinessLicense;

  /// No description provided for @businessRegisterIrsEinDocument.
  ///
  /// In en, this message translates to:
  /// **'IRS EIN Document'**
  String get businessRegisterIrsEinDocument;

  /// No description provided for @businessRegisterProcessingDocument.
  ///
  /// In en, this message translates to:
  /// **'Processing document...'**
  String get businessRegisterProcessingDocument;

  /// No description provided for @businessRegisterDocumentVerifiedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Document verified successfully'**
  String get businessRegisterDocumentVerifiedSuccessfully;

  /// No description provided for @businessRegisterCouldNotReadDocument.
  ///
  /// In en, this message translates to:
  /// **'Could not read document, please re-upload'**
  String get businessRegisterCouldNotReadDocument;

  /// No description provided for @businessRegisterVeterinary.
  ///
  /// In en, this message translates to:
  /// **'Veterinary'**
  String get businessRegisterVeterinary;

  /// No description provided for @businessRegisterGroomy.
  ///
  /// In en, this message translates to:
  /// **'Groomy'**
  String get businessRegisterGroomy;

  /// No description provided for @businessRegisterStepOfFour.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 4'**
  String businessRegisterStepOfFour(Object step);

  /// No description provided for @businessRegisterLegalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Legal Confirmation'**
  String get businessRegisterLegalConfirmation;

  /// No description provided for @businessRegisterAcceptTermsKvkk.
  ///
  /// In en, this message translates to:
  /// **'I accept the Platform Terms and KVKK Data Protection Policy.'**
  String get businessRegisterAcceptTermsKvkk;

  /// No description provided for @businessRegisterReadInsideApp.
  ///
  /// In en, this message translates to:
  /// **'Read inside app'**
  String get businessRegisterReadInsideApp;

  /// No description provided for @businessRegisterOpenOfficialLegalPage.
  ///
  /// In en, this message translates to:
  /// **'Open official legal page'**
  String get businessRegisterOpenOfficialLegalPage;

  /// No description provided for @businessRegisterLegalVersion.
  ///
  /// In en, this message translates to:
  /// **'Version v1.0 • Last updated May 2026'**
  String get businessRegisterLegalVersion;

  /// No description provided for @businessRegisterAgreementSecurelyStored.
  ///
  /// In en, this message translates to:
  /// **'Your agreement is securely stored and legally binding'**
  String get businessRegisterAgreementSecurelyStored;

  /// No description provided for @businessRegisterLegalResponsibilityDeclaration.
  ///
  /// In en, this message translates to:
  /// **'I declare that all submitted documents are accurate and I accept full legal responsibility under Turkish Commercial Law.'**
  String get businessRegisterLegalResponsibilityDeclaration;

  /// No description provided for @businessRegisterUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get businessRegisterUploaded;

  /// No description provided for @businessRegisterReplaceDocument.
  ///
  /// In en, this message translates to:
  /// **'Replace document'**
  String get businessRegisterReplaceDocument;

  /// No description provided for @businessRegisterReplaceDocumentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to replace this file?'**
  String get businessRegisterReplaceDocumentConfirmation;

  /// No description provided for @businessRegisterReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get businessRegisterReplace;

  /// No description provided for @businessRegisterUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get businessRegisterUpload;

  /// No description provided for @userProfileInitError.
  ///
  /// In en, this message translates to:
  /// **'Profile init error: {error}'**
  String userProfileInitError(Object error);

  /// No description provided for @userProfileImagePickError.
  ///
  /// In en, this message translates to:
  /// **'Error selecting photo: {error}'**
  String userProfileImagePickError(Object error);

  /// No description provided for @userProfileUnknownBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Unknown business type'**
  String get userProfileUnknownBusinessType;

  /// No description provided for @userProfileBusinessDashboard.
  ///
  /// In en, this message translates to:
  /// **'Business Dashboard'**
  String get userProfileBusinessDashboard;

  /// No description provided for @userProfileActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get userProfileActivity;

  /// No description provided for @userProfileSavedParks.
  ///
  /// In en, this message translates to:
  /// **'Saved Parks'**
  String get userProfileSavedParks;

  /// No description provided for @userProfileMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get userProfileMatches;

  /// No description provided for @userProfileMyOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get userProfileMyOrders;

  /// No description provided for @myAppointments.
  ///
  /// In en, this message translates to:
  /// **'My Appointments'**
  String get myAppointments;

  /// No description provided for @myAppointmentsLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view your appointments'**
  String get myAppointmentsLoginRequired;

  /// No description provided for @appointmentHistory.
  ///
  /// In en, this message translates to:
  /// **'Appointment History'**
  String get appointmentHistory;

  /// No description provided for @noAppointmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No appointments yet'**
  String get noAppointmentsYet;

  /// No description provided for @viewAppointment.
  ///
  /// In en, this message translates to:
  /// **'View Appointment'**
  String get viewAppointment;

  /// No description provided for @appointmentStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get appointmentStatusPending;

  /// No description provided for @appointmentStatusAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting Payment'**
  String get appointmentStatusAwaitingPayment;

  /// No description provided for @appointmentStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get appointmentStatusConfirmed;

  /// No description provided for @appointmentStatusConfirmedPaid.
  ///
  /// In en, this message translates to:
  /// **'Confirmed & Paid'**
  String get appointmentStatusConfirmedPaid;

  /// No description provided for @appointmentStatusPaymentExpired.
  ///
  /// In en, this message translates to:
  /// **'Payment Expired'**
  String get appointmentStatusPaymentExpired;

  /// No description provided for @appointmentStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get appointmentStatusRejected;

  /// No description provided for @appointmentStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get appointmentStatusCompleted;

  /// No description provided for @appointmentStatusCancelledByUser.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by you'**
  String get appointmentStatusCancelledByUser;

  /// No description provided for @appointmentStatusCancelledByVet.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by vet'**
  String get appointmentStatusCancelledByVet;

  /// No description provided for @appointmentStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get appointmentStatusExpired;

  /// No description provided for @unpaidStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get unpaidStatusLabel;

  /// No description provided for @paymentNotRequiredStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'No payment required'**
  String get paymentNotRequiredStatusLabel;

  /// No description provided for @refundUnderReviewStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund under review'**
  String get refundUnderReviewStatusLabel;

  /// No description provided for @refundRequestedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund requested'**
  String get refundRequestedStatusLabel;

  /// No description provided for @refundCompletedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund completed'**
  String get refundCompletedStatusLabel;

  /// No description provided for @refundFailedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund failed'**
  String get refundFailedStatusLabel;

  /// No description provided for @noRefundRequiredStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'No refund required'**
  String get noRefundRequiredStatusLabel;

  /// No description provided for @refundNotProcessedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund not processed yet'**
  String get refundNotProcessedStatusLabel;

  /// No description provided for @veterinaryClinicFallback.
  ///
  /// In en, this message translates to:
  /// **'Vet clinic'**
  String get veterinaryClinicFallback;

  /// No description provided for @veterinaryServiceFallback.
  ///
  /// In en, this message translates to:
  /// **'Veterinary service'**
  String get veterinaryServiceFallback;

  /// No description provided for @petFallback.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get petFallback;

  /// No description provided for @dogTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'dog'**
  String get dogTypeLabel;

  /// No description provided for @userProfileAdoptionRequests.
  ///
  /// In en, this message translates to:
  /// **'Adoption Requests'**
  String get userProfileAdoptionRequests;

  /// No description provided for @userProfileBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get userProfileBusiness;

  /// No description provided for @userProfileAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get userProfileAdmin;

  /// No description provided for @userProfileSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get userProfileSupport;

  /// No description provided for @userProfileSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get userProfileSendFeedback;

  /// No description provided for @userProfileHelpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get userProfileHelpCenter;

  /// No description provided for @userProfilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get userProfilePrivacy;

  /// No description provided for @userProfileReportProblem.
  ///
  /// In en, this message translates to:
  /// **'Report Problem'**
  String get userProfileReportProblem;

  /// No description provided for @userProfileSubscriptionPlans.
  ///
  /// In en, this message translates to:
  /// **'Subscription & Plans'**
  String get userProfileSubscriptionPlans;

  /// No description provided for @userProfileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get userProfileLanguage;

  /// No description provided for @userProfileTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get userProfileTheme;

  /// No description provided for @userProfileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get userProfileChangePassword;

  /// No description provided for @userProfileGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re browsing as Guest'**
  String get userProfileGuestTitle;

  /// No description provided for @userProfileGuestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Login to unlock full features'**
  String get userProfileGuestSubtitle;

  /// No description provided for @userProfileLoginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Login / Sign Up'**
  String get userProfileLoginSignUp;

  /// No description provided for @userProfileLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get userProfileLanguageEnglish;

  /// No description provided for @userProfileLanguagePersian.
  ///
  /// In en, this message translates to:
  /// **'Persian'**
  String get userProfileLanguagePersian;

  /// No description provided for @userProfileLanguageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get userProfileLanguageTurkish;

  /// No description provided for @userProfileUnlockBusinessFeatures.
  ///
  /// In en, this message translates to:
  /// **'Unlock Business Features 🚀'**
  String get userProfileUnlockBusinessFeatures;

  /// No description provided for @userProfileUpgradeBusinessDescription.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Gold to register your business and start receiving customers.'**
  String get userProfileUpgradeBusinessDescription;

  /// No description provided for @userProfileUpgradeToGold.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Gold'**
  String get userProfileUpgradeToGold;

  /// No description provided for @userProfileManageAdoptionCenter.
  ///
  /// In en, this message translates to:
  /// **'Manage Adoption Center'**
  String get userProfileManageAdoptionCenter;

  /// No description provided for @userProfileOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get userProfileOverview;

  /// No description provided for @userProfileDogs.
  ///
  /// In en, this message translates to:
  /// **'Dogs'**
  String get userProfileDogs;

  /// No description provided for @userProfileRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get userProfileRequests;

  /// No description provided for @userProfileOverviewSection.
  ///
  /// In en, this message translates to:
  /// **'Overview Section'**
  String get userProfileOverviewSection;

  /// No description provided for @userProfileDogsSection.
  ///
  /// In en, this message translates to:
  /// **'Dogs Section'**
  String get userProfileDogsSection;

  /// No description provided for @userProfileRequestsSection.
  ///
  /// In en, this message translates to:
  /// **'Requests Section'**
  String get userProfileRequestsSection;

  /// No description provided for @userProfileSettingsSection.
  ///
  /// In en, this message translates to:
  /// **'Settings Section'**
  String get userProfileSettingsSection;

  /// No description provided for @userProfileApplicationUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Application Under Review'**
  String get userProfileApplicationUnderReview;

  /// No description provided for @userProfileApplicationUnderReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Your business request has been submitted successfully and is currently under review.'**
  String get userProfileApplicationUnderReviewDescription;

  /// No description provided for @userProfileAdminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get userProfileAdminPanel;

  /// No description provided for @userProfileManageBusinessCenter.
  ///
  /// In en, this message translates to:
  /// **'Manage Business Center'**
  String get userProfileManageBusinessCenter;

  /// No description provided for @userProfileApplicationRejected.
  ///
  /// In en, this message translates to:
  /// **'Application Rejected'**
  String get userProfileApplicationRejected;

  /// No description provided for @userProfileRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String userProfileRejectionReason(Object reason);

  /// No description provided for @userProfileUpgradeToGoldToContinue.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Gold to continue'**
  String get userProfileUpgradeToGoldToContinue;

  /// No description provided for @userProfileReApply.
  ///
  /// In en, this message translates to:
  /// **'Re-Apply'**
  String get userProfileReApply;

  /// No description provided for @userProfileBusinessStatus.
  ///
  /// In en, this message translates to:
  /// **'Business Status'**
  String get userProfileBusinessStatus;

  /// No description provided for @userProfileUnknownStatus.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get userProfileUnknownStatus;

  /// No description provided for @userProfileChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get userProfileChooseFromGallery;

  /// No description provided for @userProfileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get userProfileRemovePhoto;

  /// No description provided for @userProfileImageSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Image selection failed.'**
  String get userProfileImageSelectionFailed;

  /// No description provided for @userProfileUsernameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters'**
  String get userProfileUsernameMinLength;

  /// No description provided for @userProfileUsernameMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be at most 20 characters'**
  String get userProfileUsernameMaxLength;

  /// No description provided for @userProfileUsernameNoSpaces.
  ///
  /// In en, this message translates to:
  /// **'Username cannot contain spaces'**
  String get userProfileUsernameNoSpaces;

  /// No description provided for @userProfilePhoneInvalidCharacters.
  ///
  /// In en, this message translates to:
  /// **'Phone contains invalid characters'**
  String get userProfilePhoneInvalidCharacters;

  /// No description provided for @userProfileBioMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Bio must be under 150 characters'**
  String get userProfileBioMaxLength;

  /// No description provided for @userProfileUsernameAlreadyTaken.
  ///
  /// In en, this message translates to:
  /// **'Username already taken'**
  String get userProfileUsernameAlreadyTaken;

  /// No description provided for @userProfileEmailUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Email update failed'**
  String get userProfileEmailUpdateFailed;

  /// No description provided for @userProfileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile.'**
  String get userProfileUpdateFailed;

  /// No description provided for @userProfileChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get userProfileChangePhoto;

  /// No description provided for @userProfileEnterUsername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get userProfileEnterUsername;

  /// No description provided for @userProfileEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter email'**
  String get userProfileEnterEmail;

  /// No description provided for @userProfileOptionalPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Optional phone number'**
  String get userProfileOptionalPhoneNumber;

  /// No description provided for @userProfileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get userProfileBio;

  /// No description provided for @userProfileBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people a little about yourself'**
  String get userProfileBioHint;

  /// No description provided for @unnamedProduct.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Product'**
  String get unnamedProduct;

  /// No description provided for @barcodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode: {barcode}'**
  String barcodeLabel(Object barcode);

  /// No description provided for @skuLabel.
  ///
  /// In en, this message translates to:
  /// **'SKU: {sku}'**
  String skuLabel(Object sku);

  /// No description provided for @dealBadge.
  ///
  /// In en, this message translates to:
  /// **'💸 Deal'**
  String get dealBadge;

  /// No description provided for @lowStockBadge.
  ///
  /// In en, this message translates to:
  /// **'⚡ Low'**
  String get lowStockBadge;

  /// No description provided for @saveAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {amount}'**
  String saveAmountLabel(Object amount);

  /// No description provided for @salePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Sale: {price}'**
  String salePriceLabel(Object price);

  /// No description provided for @stockLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock: {stock}'**
  String stockLabel(Object stock);

  /// No description provided for @addToCartButton.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCartButton;

  /// No description provided for @buyNowButton.
  ///
  /// In en, this message translates to:
  /// **'Buy Now'**
  String get buyNowButton;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to cart'**
  String get addedToCart;

  /// No description provided for @mediaNotReadyYet.
  ///
  /// In en, this message translates to:
  /// **'Media not ready yet'**
  String get mediaNotReadyYet;

  /// No description provided for @cargoLabel.
  ///
  /// In en, this message translates to:
  /// **'Cargo: {price}'**
  String cargoLabel(Object price);

  /// No description provided for @carrierLabel.
  ///
  /// In en, this message translates to:
  /// **'Carrier: {carrier}'**
  String carrierLabel(Object carrier);

  /// No description provided for @deliveryDaysRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'{min}-{max} days'**
  String deliveryDaysRangeLabel(Object max, Object min);

  /// No description provided for @businessNotFound.
  ///
  /// In en, this message translates to:
  /// **'Business not found'**
  String get businessNotFound;

  /// No description provided for @sectorDashboardNotImplementedYet.
  ///
  /// In en, this message translates to:
  /// **'This sector dashboard is not implemented yet'**
  String get sectorDashboardNotImplementedYet;

  /// No description provided for @goBackButton.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get goBackButton;

  /// No description provided for @backButton.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get backButton;

  /// No description provided for @veterinaryDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Veterinary Dashboard'**
  String get veterinaryDashboardTitle;

  /// No description provided for @overviewTab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overviewTab;

  /// No description provided for @appointmentsTab.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointmentsTab;

  /// No description provided for @shopProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop Profile'**
  String get shopProfileTitle;

  /// No description provided for @noDescriptionYet.
  ///
  /// In en, this message translates to:
  /// **'No description added yet.'**
  String get noDescriptionYet;

  /// No description provided for @noRevenueYet.
  ///
  /// In en, this message translates to:
  /// **'No revenue yet'**
  String get noRevenueYet;

  /// No description provided for @netRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Net Revenue'**
  String get netRevenueLabel;

  /// No description provided for @afterPlatformCommissionLabel.
  ///
  /// In en, this message translates to:
  /// **'After platform commission'**
  String get afterPlatformCommissionLabel;

  /// No description provided for @grossSalesLabel.
  ///
  /// In en, this message translates to:
  /// **'Gross Sales'**
  String get grossSalesLabel;

  /// No description provided for @platformFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform Fee'**
  String get platformFeeLabel;

  /// No description provided for @adjustmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get adjustmentsLabel;

  /// No description provided for @recentOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent Orders'**
  String get recentOrdersTitle;

  /// No description provided for @latestOrdersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Latest 5 orders'**
  String get latestOrdersSubtitle;

  /// No description provided for @viewAllButton.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAllButton;

  /// No description provided for @noDataLabel.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noDataLabel;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @orderNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String orderNumberLabel(Object number);

  /// No description provided for @itemsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# item} other {# items}}'**
  String itemsCountLabel(num count);

  /// No description provided for @trackingLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracking: {tracking}'**
  String trackingLabel(Object tracking);

  /// No description provided for @trackShipmentButton.
  ///
  /// In en, this message translates to:
  /// **'Track Shipment'**
  String get trackShipmentButton;

  /// No description provided for @catalogStrengthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Catalog strength unavailable'**
  String get catalogStrengthUnavailable;

  /// No description provided for @catalogStrengthTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog Strength'**
  String get catalogStrengthTitle;

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @lowStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStockLabel;

  /// No description provided for @strengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get strengthLabel;

  /// No description provided for @shippableLabel.
  ///
  /// In en, this message translates to:
  /// **'Shippable'**
  String get shippableLabel;

  /// No description provided for @withKdvLabel.
  ///
  /// In en, this message translates to:
  /// **'With KDV'**
  String get withKdvLabel;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @kdvIncludedLabel.
  ///
  /// In en, this message translates to:
  /// **'KDV included'**
  String get kdvIncludedLabel;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From {city}'**
  String fromLabel(Object city);

  /// No description provided for @returnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Returns {days}d'**
  String returnsLabel(Object days);

  /// No description provided for @pickupLabel.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pickupLabel;

  /// No description provided for @sameDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Same day'**
  String get sameDayLabel;

  /// No description provided for @offersTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offersTitle;

  /// No description provided for @createOfferButton.
  ///
  /// In en, this message translates to:
  /// **'Create Offer'**
  String get createOfferButton;

  /// No description provided for @videoLabel.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get videoLabel;

  /// No description provided for @catalogStrengthWeakLabel.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get catalogStrengthWeakLabel;

  /// No description provided for @catalogStrengthAddItemsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add products, description, media, and stock to strengthen your catalog.'**
  String get catalogStrengthAddItemsMessage;

  /// No description provided for @catalogStrengthWeakDetailsMessage.
  ///
  /// In en, this message translates to:
  /// **'Your product details are still weak. Add more media, descriptions, and stock info.'**
  String get catalogStrengthWeakDetailsMessage;

  /// No description provided for @catalogStrengthMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get catalogStrengthMediumLabel;

  /// No description provided for @catalogStrengthMediumMessage.
  ///
  /// In en, this message translates to:
  /// **'Good start. Add richer descriptions and more product media to improve visibility.'**
  String get catalogStrengthMediumMessage;

  /// No description provided for @catalogStrengthStrongLabel.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get catalogStrengthStrongLabel;

  /// No description provided for @catalogStrengthStrongMessage.
  ///
  /// In en, this message translates to:
  /// **'Great catalog quality. Your listings look strong and complete.'**
  String get catalogStrengthStrongMessage;

  /// No description provided for @shippingCalculatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping calculated'**
  String get shippingCalculatedLabel;

  /// No description provided for @fragileLabel.
  ///
  /// In en, this message translates to:
  /// **'Fragile'**
  String get fragileLabel;

  /// No description provided for @oversizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Oversize'**
  String get oversizeLabel;

  /// No description provided for @originLabel.
  ///
  /// In en, this message translates to:
  /// **'Origin: {city}'**
  String originLabel(Object city);

  /// No description provided for @carriersCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} carriers'**
  String carriersCountLabel(Object count);

  /// No description provided for @kdvRateLabel.
  ///
  /// In en, this message translates to:
  /// **'KDV {percent}%'**
  String kdvRateLabel(Object percent);

  /// No description provided for @myOrdersLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view your orders'**
  String get myOrdersLoginRequired;

  /// No description provided for @myOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrdersTitle;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @searchByOrderIdOrProductNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by order id or product name'**
  String get searchByOrderIdOrProductNameHint;

  /// No description provided for @allFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilterLabel;

  /// No description provided for @noMatchingOrders.
  ///
  /// In en, this message translates to:
  /// **'No matching orders'**
  String get noMatchingOrders;

  /// No description provided for @orderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderLabel;

  /// No description provided for @itemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get itemsTitle;

  /// No description provided for @qtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String qtyLabel(Object qty);

  /// No description provided for @pendingStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingStatusLabel;

  /// No description provided for @paidStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidStatusLabel;

  /// No description provided for @confirmedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmedStatusLabel;

  /// No description provided for @preparingStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparingStatusLabel;

  /// No description provided for @shippedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get shippedStatusLabel;

  /// No description provided for @deliveredStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get deliveredStatusLabel;

  /// No description provided for @completedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedStatusLabel;

  /// No description provided for @failedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedStatusLabel;

  /// No description provided for @cancelledStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledStatusLabel;

  /// No description provided for @paymentFailedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailedStatusLabel;

  /// No description provided for @paidPayoutStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidPayoutStatusLabel;

  /// No description provided for @readyForPayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready for payout'**
  String get readyForPayoutLabel;

  /// No description provided for @payoutPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Payout pending'**
  String get payoutPendingLabel;

  /// No description provided for @waitingForPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment'**
  String get waitingForPaymentLabel;

  /// No description provided for @payoutNotSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Payout not set'**
  String get payoutNotSetLabel;

  /// No description provided for @confirmOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrderButton;

  /// No description provided for @startPreparingButton.
  ///
  /// In en, this message translates to:
  /// **'Start Preparing'**
  String get startPreparingButton;

  /// No description provided for @openOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Open Order'**
  String get openOrderButton;

  /// No description provided for @simulateUploadInvoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Simulate Upload Invoice'**
  String get simulateUploadInvoiceButton;

  /// No description provided for @invoiceSimulatedAsUploaded.
  ///
  /// In en, this message translates to:
  /// **'Invoice simulated as uploaded'**
  String get invoiceSimulatedAsUploaded;

  /// No description provided for @invoiceError.
  ///
  /// In en, this message translates to:
  /// **'Invoice error: {error}'**
  String invoiceError(Object error);

  /// No description provided for @orderStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated to {status}'**
  String orderStatusUpdated(Object status);

  /// No description provided for @invoiceSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice: {status} • Deadline: {deadline}'**
  String invoiceSummaryLabel(Object deadline, Object status);

  /// No description provided for @sellerNetLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller net: {amount}'**
  String sellerNetLabel(Object amount);

  /// No description provided for @referenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Ref: {reference}'**
  String referenceLabel(Object reference);

  /// No description provided for @buyerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name: {name}'**
  String buyerNameLabel(Object name);

  /// No description provided for @buyerSurnameLabel.
  ///
  /// In en, this message translates to:
  /// **'Surname: {surname}'**
  String buyerSurnameLabel(Object surname);

  /// No description provided for @buyerIdentityNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'ID: {identityNumber}'**
  String buyerIdentityNumberLabel(Object identityNumber);

  /// No description provided for @buyerCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City: {city}'**
  String buyerCityLabel(Object city);

  /// No description provided for @buyerAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address: {address}'**
  String buyerAddressLabel(Object address);

  /// No description provided for @buyerInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Buyer Info'**
  String get buyerInfoTitle;

  /// No description provided for @invoiceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice Type: {type}'**
  String invoiceTypeLabel(Object type);

  /// No description provided for @invoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceTitle;

  /// No description provided for @uploadDeadlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload Deadline'**
  String get uploadDeadlineLabel;

  /// No description provided for @warningsLabel.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get warningsLabel;

  /// No description provided for @penaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'Penalty'**
  String get penaltyLabel;

  /// No description provided for @invoiceSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice System'**
  String get invoiceSystemLabel;

  /// No description provided for @invoiceNoLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice No'**
  String get invoiceNoLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @cannotOpenInvoiceFile.
  ///
  /// In en, this message translates to:
  /// **'Cannot open invoice file'**
  String get cannotOpenInvoiceFile;

  /// No description provided for @viewInvoiceButton.
  ///
  /// In en, this message translates to:
  /// **'View Invoice'**
  String get viewInvoiceButton;

  /// No description provided for @noInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'No Invoice'**
  String get noInvoiceLabel;

  /// No description provided for @uploadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingLabel;

  /// No description provided for @invoiceUploadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice Uploaded'**
  String get invoiceUploadedLabel;

  /// No description provided for @uploadInvoiceButton.
  ///
  /// In en, this message translates to:
  /// **'Upload Invoice'**
  String get uploadInvoiceButton;

  /// No description provided for @invoiceUploadDeadlinePassed.
  ///
  /// In en, this message translates to:
  /// **'Invoice upload deadline passed!'**
  String get invoiceUploadDeadlinePassed;

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTitle;

  /// No description provided for @payoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout'**
  String get payoutTitle;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount: {amount}'**
  String amountLabel(Object amount);

  /// No description provided for @paymentWillBeTransferredByPetsupo.
  ///
  /// In en, this message translates to:
  /// **'Payment will be transferred by Petsupo'**
  String get paymentWillBeTransferredByPetsupo;

  /// No description provided for @pendingPayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending payout'**
  String get pendingPayoutLabel;

  /// No description provided for @waitingForCustomerPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for customer payment'**
  String get waitingForCustomerPayment;

  /// No description provided for @actionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsTitle;

  /// No description provided for @payoutMarkedAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Payout marked as paid'**
  String get payoutMarkedAsPaid;

  /// No description provided for @trackingNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracking Number'**
  String get trackingNumberLabel;

  /// No description provided for @trackingNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Tracking number is required'**
  String get trackingNumberRequired;

  /// No description provided for @returnCarrierRequired.
  ///
  /// In en, this message translates to:
  /// **'Carrier is required'**
  String get returnCarrierRequired;

  /// No description provided for @returnShippedBackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not mark the return as shipped back'**
  String get returnShippedBackFailed;

  /// No description provided for @returnTrackingNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Return Tracking Number'**
  String get returnTrackingNumberLabel;

  /// No description provided for @returnTrackingNumberHelperText.
  ///
  /// In en, this message translates to:
  /// **'Enter the tracking number provided for the return shipment.'**
  String get returnTrackingNumberHelperText;

  /// No description provided for @returnCarrierHelperText.
  ///
  /// In en, this message translates to:
  /// **'Use the same carrier used for the original delivery.'**
  String get returnCarrierHelperText;

  /// No description provided for @originalShipmentTrackingLabel.
  ///
  /// In en, this message translates to:
  /// **'Original Shipment Tracking'**
  String get originalShipmentTrackingLabel;

  /// No description provided for @returnShipmentTrackingLabel.
  ///
  /// In en, this message translates to:
  /// **'Return Shipment Tracking'**
  String get returnShipmentTrackingLabel;

  /// No description provided for @returnShippedBackTimelineLabel.
  ///
  /// In en, this message translates to:
  /// **'Return shipped back'**
  String get returnShippedBackTimelineLabel;

  /// No description provided for @carrierMissingFromOrder.
  ///
  /// In en, this message translates to:
  /// **'Carrier missing from order'**
  String get carrierMissingFromOrder;

  /// No description provided for @enterTrackingNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter tracking number'**
  String get enterTrackingNumber;

  /// No description provided for @shipOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Ship Order'**
  String get shipOrderButton;

  /// No description provided for @markAsDeliveredButton.
  ///
  /// In en, this message translates to:
  /// **'Mark as Delivered'**
  String get markAsDeliveredButton;

  /// No description provided for @goToCarrierWebsiteButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Carrier Website'**
  String get goToCarrierWebsiteButton;

  /// No description provided for @noTimelineYet.
  ///
  /// In en, this message translates to:
  /// **'No timeline yet'**
  String get noTimelineYet;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @invoiceUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Invoice uploaded successfully'**
  String get invoiceUploadedSuccessfully;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(Object error);

  /// No description provided for @orderShipped.
  ///
  /// In en, this message translates to:
  /// **'Order shipped'**
  String get orderShipped;

  /// No description provided for @sellerTaxNumberMissing.
  ///
  /// In en, this message translates to:
  /// **'Seller tax number missing'**
  String get sellerTaxNumberMissing;

  /// No description provided for @buyerIdentityNumberMissing.
  ///
  /// In en, this message translates to:
  /// **'Buyer identity number missing'**
  String get buyerIdentityNumberMissing;

  /// No description provided for @buyerTaxNumberMissing.
  ///
  /// In en, this message translates to:
  /// **'Buyer tax number missing'**
  String get buyerTaxNumberMissing;

  /// No description provided for @invoiceSystemMismatch.
  ///
  /// In en, this message translates to:
  /// **'Invoice type mismatch'**
  String get invoiceSystemMismatch;

  /// No description provided for @invoiceStatusPendingUploadLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice waiting'**
  String get invoiceStatusPendingUploadLabel;

  /// No description provided for @invoiceStatusUploadedValidLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice uploaded'**
  String get invoiceStatusUploadedValidLabel;

  /// No description provided for @invoiceStatusUploadedWithIssuesLabel.
  ///
  /// In en, this message translates to:
  /// **'Review required'**
  String get invoiceStatusUploadedWithIssuesLabel;

  /// No description provided for @invoiceStatusLateLabel.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get invoiceStatusLateLabel;

  /// No description provided for @invoiceStatusApprovedLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice approved'**
  String get invoiceStatusApprovedLabel;

  /// No description provided for @invoiceStatusRejectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice rejected'**
  String get invoiceStatusRejectedLabel;

  /// No description provided for @eArsivLabel.
  ///
  /// In en, this message translates to:
  /// **'e-Archive'**
  String get eArsivLabel;

  /// No description provided for @eFaturaLabel.
  ///
  /// In en, this message translates to:
  /// **'e-Invoice'**
  String get eFaturaLabel;

  /// No description provided for @fileIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'File is empty'**
  String get fileIsEmpty;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large'**
  String get fileTooLarge;

  /// No description provided for @upgradePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgradePageTitle;

  /// No description provided for @upgradeHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Find better matches faster 🐾'**
  String get upgradeHeroTitle;

  /// No description provided for @upgradeHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock premium features, better visibility, exclusive offers and business tools.'**
  String get upgradeHeroSubtitle;

  /// No description provided for @premiumPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For active pet owners'**
  String get premiumPlanSubtitle;

  /// No description provided for @premiumPlanFeatureUnlimitedChat.
  ///
  /// In en, this message translates to:
  /// **'Unlimited chat'**
  String get premiumPlanFeatureUnlimitedChat;

  /// No description provided for @premiumPlanFeatureAdvancedMatchingFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced matching filters'**
  String get premiumPlanFeatureAdvancedMatchingFilters;

  /// No description provided for @premiumPlanFeatureExclusivePetOffers.
  ///
  /// In en, this message translates to:
  /// **'Exclusive pet offers'**
  String get premiumPlanFeatureExclusivePetOffers;

  /// No description provided for @premiumPlanFeatureBetterProfileExperience.
  ///
  /// In en, this message translates to:
  /// **'Better profile experience'**
  String get premiumPlanFeatureBetterProfileExperience;

  /// No description provided for @goldPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For pet businesses and power users'**
  String get goldPlanSubtitle;

  /// No description provided for @mostPopularLabel.
  ///
  /// In en, this message translates to:
  /// **'MOST POPULAR'**
  String get mostPopularLabel;

  /// No description provided for @goldPlanFeatureEverythingInPremium.
  ///
  /// In en, this message translates to:
  /// **'Everything in Premium'**
  String get goldPlanFeatureEverythingInPremium;

  /// No description provided for @goldPlanFeatureBusinessRegistrationAccess.
  ///
  /// In en, this message translates to:
  /// **'Business registration access'**
  String get goldPlanFeatureBusinessRegistrationAccess;

  /// No description provided for @goldPlanFeatureBoostedVisibility.
  ///
  /// In en, this message translates to:
  /// **'Boosted visibility'**
  String get goldPlanFeatureBoostedVisibility;

  /// No description provided for @goldPlanFeatureBusinessDashboardAccess.
  ///
  /// In en, this message translates to:
  /// **'Business dashboard access'**
  String get goldPlanFeatureBusinessDashboardAccess;

  /// No description provided for @goldPlanFeaturePremiumChatAndOffers.
  ///
  /// In en, this message translates to:
  /// **'Premium chat and offers'**
  String get goldPlanFeaturePremiumChatAndOffers;

  /// No description provided for @storeNotReadyTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Store not ready. Try again.'**
  String get storeNotReadyTryAgain;

  /// No description provided for @processingLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processingLabel;

  /// No description provided for @restoreRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Restore request sent.'**
  String get restoreRequestSent;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @upgradePaymentTerms.
  ///
  /// In en, this message translates to:
  /// **'Your payment will be charged to your App Store account at confirmation. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period.'**
  String get upgradePaymentTerms;

  /// No description provided for @autoRenewableMonthlySubscription.
  ///
  /// In en, this message translates to:
  /// **'Auto-renewable monthly subscription'**
  String get autoRenewableMonthlySubscription;

  /// No description provided for @securePaymentNotice.
  ///
  /// In en, this message translates to:
  /// **'Secure payment • Cancel anytime • Plans are managed by the App Store'**
  String get securePaymentNotice;

  /// No description provided for @continueWithPlan.
  ///
  /// In en, this message translates to:
  /// **'Continue with {plan}'**
  String continueWithPlan(Object plan);

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loadingLabel;

  /// No description provided for @privacyPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyLabel;

  /// No description provided for @termsOfUseLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUseLabel;

  /// No description provided for @adoptionRequestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'• {dogName}'**
  String adoptionRequestSubtitle(Object dogName);

  /// No description provided for @adoptionStepPersonalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'1️⃣ Personal Info'**
  String get adoptionStepPersonalInfoTitle;

  /// No description provided for @adoptionFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get adoptionFullNameLabel;

  /// No description provided for @adoptionFullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get adoptionFullNameHint;

  /// No description provided for @adoptionEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get adoptionEnterFullName;

  /// No description provided for @genderLabel.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get genderLabel;

  /// No description provided for @adoptionSelectGender.
  ///
  /// In en, this message translates to:
  /// **'Select gender'**
  String get adoptionSelectGender;

  /// No description provided for @adoptionPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. +90 5xx xxx xxxx'**
  String get adoptionPhoneHint;

  /// No description provided for @adoptionEnterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get adoptionEnterValidPhone;

  /// No description provided for @adoptionIncomeRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly Income Range'**
  String get adoptionIncomeRangeLabel;

  /// No description provided for @adoptionSelectIncomeRange.
  ///
  /// In en, this message translates to:
  /// **'Select income range'**
  String get adoptionSelectIncomeRange;

  /// No description provided for @adoptionIncomeRange0_2000.
  ///
  /// In en, this message translates to:
  /// **'0 - 2,000'**
  String get adoptionIncomeRange0_2000;

  /// No description provided for @adoptionIncomeRange2000_5000.
  ///
  /// In en, this message translates to:
  /// **'2,000 - 5,000'**
  String get adoptionIncomeRange2000_5000;

  /// No description provided for @adoptionIncomeRange5000_10000.
  ///
  /// In en, this message translates to:
  /// **'5,000 - 10,000'**
  String get adoptionIncomeRange5000_10000;

  /// No description provided for @adoptionIncomeRange10000Plus.
  ///
  /// In en, this message translates to:
  /// **'10,000+'**
  String get adoptionIncomeRange10000Plus;

  /// No description provided for @adoptionStepHousingTitle.
  ///
  /// In en, this message translates to:
  /// **'2️⃣ Housing'**
  String get adoptionStepHousingTitle;

  /// No description provided for @adoptionHousingTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Housing type'**
  String get adoptionHousingTypeLabel;

  /// No description provided for @adoptionHousingApartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get adoptionHousingApartment;

  /// No description provided for @adoptionHousingHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get adoptionHousingHouse;

  /// No description provided for @adoptionHousingVilla.
  ///
  /// In en, this message translates to:
  /// **'Villa'**
  String get adoptionHousingVilla;

  /// No description provided for @adoptionOwnershipLabel.
  ///
  /// In en, this message translates to:
  /// **'Owned / Rented'**
  String get adoptionOwnershipLabel;

  /// No description provided for @adoptionOwnershipOwned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get adoptionOwnershipOwned;

  /// No description provided for @adoptionOwnershipRented.
  ///
  /// In en, this message translates to:
  /// **'Rented'**
  String get adoptionOwnershipRented;

  /// No description provided for @adoptionLandlordPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Landlord permission (required)'**
  String get adoptionLandlordPermissionRequired;

  /// No description provided for @adoptionHasGarden.
  ///
  /// In en, this message translates to:
  /// **'Has garden'**
  String get adoptionHasGarden;

  /// No description provided for @adoptionFenceHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Fence height (cm)'**
  String get adoptionFenceHeightLabel;

  /// No description provided for @adoptionFenceHeightHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 120'**
  String get adoptionFenceHeightHint;

  /// No description provided for @adoptionEnterValidFenceHeight.
  ///
  /// In en, this message translates to:
  /// **'Enter 1..400'**
  String get adoptionEnterValidFenceHeight;

  /// No description provided for @adoptionStepExperienceTitle.
  ///
  /// In en, this message translates to:
  /// **'3️⃣ Experience'**
  String get adoptionStepExperienceTitle;

  /// No description provided for @adoptionYearsOfExperienceLabel.
  ///
  /// In en, this message translates to:
  /// **'Years of experience'**
  String get adoptionYearsOfExperienceLabel;

  /// No description provided for @adoptionYearsOfExperienceHint.
  ///
  /// In en, this message translates to:
  /// **'0..60'**
  String get adoptionYearsOfExperienceHint;

  /// No description provided for @adoptionEnterYearsOfExperience.
  ///
  /// In en, this message translates to:
  /// **'Enter 0..60'**
  String get adoptionEnterYearsOfExperience;

  /// No description provided for @adoptionPreviousDogQuestion.
  ///
  /// In en, this message translates to:
  /// **'Previous dog? (Yes/No)'**
  String get adoptionPreviousDogQuestion;

  /// No description provided for @adoptionPreviousDogReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason previous dog no longer with you'**
  String get adoptionPreviousDogReasonLabel;

  /// No description provided for @adoptionPreviousDogReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Explain briefly'**
  String get adoptionPreviousDogReasonHint;

  /// No description provided for @adoptionExplainPreviousDog.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get adoptionExplainPreviousDog;

  /// No description provided for @adoptionOtherPetsAtHome.
  ///
  /// In en, this message translates to:
  /// **'Other pets at home'**
  String get adoptionOtherPetsAtHome;

  /// No description provided for @adoptionDescribeOtherPetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Describe your other pets'**
  String get adoptionDescribeOtherPetsLabel;

  /// No description provided for @adoptionDescribeOtherPetsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2 cats, vaccinated'**
  String get adoptionDescribeOtherPetsHint;

  /// No description provided for @adoptionRequiredShort.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get adoptionRequiredShort;

  /// No description provided for @adoptionDescribeOtherPetsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please describe your other pets'**
  String get adoptionDescribeOtherPetsRequired;

  /// No description provided for @adoptionMotivationMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Motivation message'**
  String get adoptionMotivationMessageLabel;

  /// No description provided for @adoptionMotivationMinLength.
  ///
  /// In en, this message translates to:
  /// **'Motivation should be at least 20 characters'**
  String get adoptionMotivationMinLength;

  /// No description provided for @adoptionStepFinancialCommitmentTitle.
  ///
  /// In en, this message translates to:
  /// **'4️⃣ Financial & Commitment'**
  String get adoptionStepFinancialCommitmentTitle;

  /// No description provided for @adoptionCanAffordVetExpenses.
  ///
  /// In en, this message translates to:
  /// **'Can afford vet expenses?'**
  String get adoptionCanAffordVetExpenses;

  /// No description provided for @adoptionEmergencySavingsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Emergency savings available?'**
  String get adoptionEmergencySavingsAvailable;

  /// No description provided for @adoptionUploadsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'📷 Uploads'**
  String get adoptionUploadsSectionTitle;

  /// No description provided for @adoptionHousePhotosRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'House photos (required)'**
  String get adoptionHousePhotosRequiredTitle;

  /// No description provided for @adoptionUploadAtLeastOnePhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload at least 1 photo'**
  String get adoptionUploadAtLeastOnePhoto;

  /// No description provided for @adoptionUploadedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} uploaded'**
  String adoptionUploadedCount(Object count);

  /// No description provided for @adoptionUploadButton.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get adoptionUploadButton;

  /// No description provided for @adoptionClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get adoptionClearButton;

  /// No description provided for @adoptionIdPhotoRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'ID photo (required)'**
  String get adoptionIdPhotoRequiredTitle;

  /// No description provided for @adoptionNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get adoptionNotUploaded;

  /// No description provided for @adoptionUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get adoptionUploaded;

  /// No description provided for @adoptionReplaceButton.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get adoptionReplaceButton;

  /// No description provided for @adoptionRemoveButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get adoptionRemoveButton;

  /// No description provided for @adoptionProofOfIncomeOptionalTitle.
  ///
  /// In en, this message translates to:
  /// **'Proof of income (optional)'**
  String get adoptionProofOfIncomeOptionalTitle;

  /// No description provided for @adoptionOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get adoptionOptionalLabel;

  /// No description provided for @adoptionAgreeContractRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'I agree to sign the adoption contract (required)'**
  String get adoptionAgreeContractRequiredLabel;

  /// No description provided for @adoptionAgreeContractRequired.
  ///
  /// In en, this message translates to:
  /// **'You must agree to the adoption contract'**
  String get adoptionAgreeContractRequired;

  /// No description provided for @adoptionUploadIdPhoto.
  ///
  /// In en, this message translates to:
  /// **'Please upload an ID photo'**
  String get adoptionUploadIdPhoto;

  /// No description provided for @adoptionNextButton.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get adoptionNextButton;

  /// No description provided for @smartPriceSuggestedRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested range: {min} - {max} {currency}'**
  String smartPriceSuggestedRangeLabel(Object currency, Object max, Object min);

  /// No description provided for @smartPriceSuggestedPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested price: {price} {currency}'**
  String smartPriceSuggestedPriceLabel(Object currency, Object price);

  /// No description provided for @bestPriceStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Best Price'**
  String get bestPriceStrategyLabel;

  /// No description provided for @aggressiveLowStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Aggressive Low'**
  String get aggressiveLowStrategyLabel;

  /// No description provided for @competitiveStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Competitive'**
  String get competitiveStrategyLabel;

  /// No description provided for @slightlyHighStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Slightly High'**
  String get slightlyHighStrategyLabel;

  /// No description provided for @tooExpensiveStrategyLabel.
  ///
  /// In en, this message translates to:
  /// **'Too Expensive'**
  String get tooExpensiveStrategyLabel;

  /// No description provided for @manualPricingLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual pricing'**
  String get manualPricingLabel;

  /// No description provided for @bestPricePositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Best Price 🏆'**
  String get bestPricePositionLabel;

  /// No description provided for @aggressiveLowPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Aggressive Low ⚡'**
  String get aggressiveLowPositionLabel;

  /// No description provided for @competitivePositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Competitive ✅'**
  String get competitivePositionLabel;

  /// No description provided for @slightlyHighPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Slightly High 📈'**
  String get slightlyHighPositionLabel;

  /// No description provided for @tooExpensivePositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Too Expensive ⚠️'**
  String get tooExpensivePositionLabel;

  /// No description provided for @marketSourceAggregateLabel.
  ///
  /// In en, this message translates to:
  /// **'Aggregate data'**
  String get marketSourceAggregateLabel;

  /// No description provided for @marketSourceFallbackProductsLabel.
  ///
  /// In en, this message translates to:
  /// **'Fallback products'**
  String get marketSourceFallbackProductsLabel;

  /// No description provided for @marketSourceNoneLabel.
  ///
  /// In en, this message translates to:
  /// **'No market data'**
  String get marketSourceNoneLabel;

  /// No description provided for @marketSourceInvalidPricesLabel.
  ///
  /// In en, this message translates to:
  /// **'Invalid prices'**
  String get marketSourceInvalidPricesLabel;

  /// No description provided for @marketSourceErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get marketSourceErrorLabel;

  /// No description provided for @discountRate1Label.
  ///
  /// In en, this message translates to:
  /// **'1%'**
  String get discountRate1Label;

  /// No description provided for @discountRate10Label.
  ///
  /// In en, this message translates to:
  /// **'10%'**
  String get discountRate10Label;

  /// No description provided for @discountRate20Label.
  ///
  /// In en, this message translates to:
  /// **'20%'**
  String get discountRate20Label;

  /// No description provided for @carrierYurticiKargo.
  ///
  /// In en, this message translates to:
  /// **'Yurtiçi Kargo'**
  String get carrierYurticiKargo;

  /// No description provided for @carrierArasKargo.
  ///
  /// In en, this message translates to:
  /// **'Aras Kargo'**
  String get carrierArasKargo;

  /// No description provided for @carrierMngKargo.
  ///
  /// In en, this message translates to:
  /// **'MNG Kargo'**
  String get carrierMngKargo;

  /// No description provided for @carrierSuratKargo.
  ///
  /// In en, this message translates to:
  /// **'Sürat Kargo'**
  String get carrierSuratKargo;

  /// No description provided for @carrierPttKargo.
  ///
  /// In en, this message translates to:
  /// **'PTT Kargo'**
  String get carrierPttKargo;

  /// No description provided for @carrierHepsiJet.
  ///
  /// In en, this message translates to:
  /// **'HepsiJET'**
  String get carrierHepsiJet;

  /// No description provided for @carrierKolayGelsin.
  ///
  /// In en, this message translates to:
  /// **'Kolay Gelsin'**
  String get carrierKolayGelsin;

  /// No description provided for @carrierUpsTurkiye.
  ///
  /// In en, this message translates to:
  /// **'UPS Türkiye'**
  String get carrierUpsTurkiye;

  /// No description provided for @carrierDhlExpress.
  ///
  /// In en, this message translates to:
  /// **'DHL Express'**
  String get carrierDhlExpress;

  /// No description provided for @categoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// No description provided for @categoryAccessories.
  ///
  /// In en, this message translates to:
  /// **'Accessories'**
  String get categoryAccessories;

  /// No description provided for @categoryHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get categoryHealth;

  /// No description provided for @categoryToys.
  ///
  /// In en, this message translates to:
  /// **'Toys'**
  String get categoryToys;

  /// No description provided for @subCategoryDryFood.
  ///
  /// In en, this message translates to:
  /// **'Dry Food'**
  String get subCategoryDryFood;

  /// No description provided for @subCategoryWetFood.
  ///
  /// In en, this message translates to:
  /// **'Wet Food'**
  String get subCategoryWetFood;

  /// No description provided for @subCategoryTreats.
  ///
  /// In en, this message translates to:
  /// **'Treats'**
  String get subCategoryTreats;

  /// No description provided for @subCategoryCollar.
  ///
  /// In en, this message translates to:
  /// **'Collar'**
  String get subCategoryCollar;

  /// No description provided for @subCategoryLeash.
  ///
  /// In en, this message translates to:
  /// **'Leash'**
  String get subCategoryLeash;

  /// No description provided for @subCategoryClothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get subCategoryClothing;

  /// No description provided for @subCategoryVitamins.
  ///
  /// In en, this message translates to:
  /// **'Vitamins'**
  String get subCategoryVitamins;

  /// No description provided for @subCategoryMedicine.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get subCategoryMedicine;

  /// No description provided for @subCategoryChewToy.
  ///
  /// In en, this message translates to:
  /// **'Chew Toy'**
  String get subCategoryChewToy;

  /// No description provided for @subCategoryInteractive.
  ///
  /// In en, this message translates to:
  /// **'Interactive'**
  String get subCategoryInteractive;

  /// No description provided for @productAlreadyExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product already exists'**
  String get productAlreadyExistsTitle;

  /// No description provided for @productAlreadyExistsDescription.
  ///
  /// In en, this message translates to:
  /// **'This product already exists. Opening the product editor.'**
  String get productAlreadyExistsDescription;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @productNameMustBeAtLeast4Chars.
  ///
  /// In en, this message translates to:
  /// **'Product name must be at least 4 characters'**
  String get productNameMustBeAtLeast4Chars;

  /// No description provided for @invalidBarcode.
  ///
  /// In en, this message translates to:
  /// **'Invalid barcode'**
  String get invalidBarcode;

  /// No description provided for @invalidSku.
  ///
  /// In en, this message translates to:
  /// **'Invalid SKU'**
  String get invalidSku;

  /// No description provided for @invalidWholesalePrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid wholesale price'**
  String get invalidWholesalePrice;

  /// No description provided for @wholesaleMinQuantityMustBeAtLeast2.
  ///
  /// In en, this message translates to:
  /// **'Wholesale minimum quantity must be at least 2'**
  String get wholesaleMinQuantityMustBeAtLeast2;

  /// No description provided for @kdvRateIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a VAT rate'**
  String get kdvRateIsRequired;

  /// No description provided for @invalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get invalidPrice;

  /// No description provided for @invalidDiscountPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid discount price'**
  String get invalidDiscountPrice;

  /// No description provided for @discountMustBeLowerThanOriginalPrice.
  ///
  /// In en, this message translates to:
  /// **'Discount price must be lower than original price'**
  String get discountMustBeLowerThanOriginalPrice;

  /// No description provided for @wholesalePriceMustBeLowerThanRetailPrice.
  ///
  /// In en, this message translates to:
  /// **'Wholesale price must be lower than retail price'**
  String get wholesalePriceMustBeLowerThanRetailPrice;

  /// No description provided for @invalidStock.
  ///
  /// In en, this message translates to:
  /// **'Invalid stock'**
  String get invalidStock;

  /// No description provided for @stockMustBeAtLeastWholesaleMinQuantity.
  ///
  /// In en, this message translates to:
  /// **'Stock must be at least the wholesale minimum quantity'**
  String get stockMustBeAtLeastWholesaleMinQuantity;

  /// No description provided for @inventoryStockFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get inventoryStockFieldLabel;

  /// No description provided for @invalidLowStockAlert.
  ///
  /// In en, this message translates to:
  /// **'Invalid low-stock alert'**
  String get invalidLowStockAlert;

  /// No description provided for @addAtLeast1Media.
  ///
  /// In en, this message translates to:
  /// **'Add at least 1 media item'**
  String get addAtLeast1Media;

  /// No description provided for @descriptionMustBeAtLeast10Characters.
  ///
  /// In en, this message translates to:
  /// **'Description must be at least 10 characters'**
  String get descriptionMustBeAtLeast10Characters;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategory;

  /// No description provided for @weightOrDesiIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Weight or desi is required'**
  String get weightOrDesiIsRequired;

  /// No description provided for @lengthIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Length is required'**
  String get lengthIsRequired;

  /// No description provided for @widthIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Width is required'**
  String get widthIsRequired;

  /// No description provided for @heightIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Height is required'**
  String get heightIsRequired;

  /// No description provided for @invalidDesiValue.
  ///
  /// In en, this message translates to:
  /// **'Invalid desi value'**
  String get invalidDesiValue;

  /// No description provided for @fixedShippingFeeIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Fixed shipping fee is required'**
  String get fixedShippingFeeIsRequired;

  /// No description provided for @invalidShippingFee.
  ///
  /// In en, this message translates to:
  /// **'Invalid shipping fee'**
  String get invalidShippingFee;

  /// No description provided for @freeShippingThresholdIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Free shipping threshold is required'**
  String get freeShippingThresholdIsRequired;

  /// No description provided for @invalidPreparationTime.
  ///
  /// In en, this message translates to:
  /// **'Invalid preparation time'**
  String get invalidPreparationTime;

  /// No description provided for @invalidMaxDeliveryDays.
  ///
  /// In en, this message translates to:
  /// **'Invalid maximum delivery days'**
  String get invalidMaxDeliveryDays;

  /// No description provided for @selectAtLeast1CargoCarrier.
  ///
  /// In en, this message translates to:
  /// **'Select at least 1 cargo carrier'**
  String get selectAtLeast1CargoCarrier;

  /// No description provided for @returnWindowCannotBeLessThan14Days.
  ///
  /// In en, this message translates to:
  /// **'Return window cannot be less than 14 days'**
  String get returnWindowCannotBeLessThan14Days;

  /// No description provided for @returnCarrierIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Return carrier is required'**
  String get returnCarrierIsRequired;

  /// No description provided for @shippingPayerMismatch.
  ///
  /// In en, this message translates to:
  /// **'Shipping payer mismatch'**
  String get shippingPayerMismatch;

  /// No description provided for @productSavedStatus.
  ///
  /// In en, this message translates to:
  /// **'Product saved ✅'**
  String get productSavedStatus;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed'**
  String get scanFailed;

  /// No description provided for @estimatedPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated price: {price} {currency}'**
  String estimatedPriceLabel(Object currency, Object price);

  /// No description provided for @loadedFromGlobalApi.
  ///
  /// In en, this message translates to:
  /// **'Loaded from global API'**
  String get loadedFromGlobalApi;

  /// No description provided for @productFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Product {short}'**
  String productFallbackName(Object short);

  /// No description provided for @fallbackEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Fallback estimate: {price} {currency}'**
  String fallbackEstimateLabel(Object currency, Object price);

  /// No description provided for @offlineEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline estimate: {price} {currency}'**
  String offlineEstimateLabel(Object currency, Object price);

  /// No description provided for @errorEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Error estimate: {price} {currency}'**
  String errorEstimateLabel(Object currency, Object price);

  /// No description provided for @smartDescriptionDefault.
  ///
  /// In en, this message translates to:
  /// **'{name} by {brand} is a reliable option for pet owners.'**
  String smartDescriptionDefault(Object brand, Object name);

  /// No description provided for @trustedBrand.
  ///
  /// In en, this message translates to:
  /// **'Trusted brand'**
  String get trustedBrand;

  /// No description provided for @productDetectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Product detected'**
  String get productDetectedStatus;

  /// No description provided for @noProductFoundAnywhere.
  ///
  /// In en, this message translates to:
  /// **'No product found anywhere'**
  String get noProductFoundAnywhere;

  /// No description provided for @enterProductNameFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter product name first'**
  String get enterProductNameFirst;

  /// No description provided for @smartDescriptionFood.
  ///
  /// In en, this message translates to:
  /// **'{name} by {brand} is a practical choice for pets. It fits the {subCategory} category and is suitable for daily use.'**
  String smartDescriptionFood(Object brand, Object name, Object subCategory);

  /// No description provided for @smartDescriptionAccessories.
  ///
  /// In en, this message translates to:
  /// **'{name} by {brand} is a useful accessory in the {subCategory} category.'**
  String smartDescriptionAccessories(Object brand, Object name, Object subCategory);

  /// No description provided for @smartDescriptionHealth.
  ///
  /// In en, this message translates to:
  /// **'{name} by {brand} is designed for pet health and wellness in the {subCategory} category.'**
  String smartDescriptionHealth(Object brand, Object name, Object subCategory);

  /// No description provided for @smartDescriptionToys.
  ///
  /// In en, this message translates to:
  /// **'{name} by {brand} is an engaging toy from the {subCategory} category.'**
  String smartDescriptionToys(Object brand, Object name, Object subCategory);

  /// No description provided for @descriptionSuggestionAdded.
  ///
  /// In en, this message translates to:
  /// **'Description suggestion added'**
  String get descriptionSuggestionAdded;

  /// No description provided for @noPricingDataYet.
  ///
  /// In en, this message translates to:
  /// **'No pricing data yet'**
  String get noPricingDataYet;

  /// No description provided for @smartPriceSuggestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Price Suggestion'**
  String get smartPriceSuggestionTitle;

  /// No description provided for @waitingForPricingData.
  ///
  /// In en, this message translates to:
  /// **'Waiting for pricing data...'**
  String get waitingForPricingData;

  /// No description provided for @tapToApplySuggestedPrice.
  ///
  /// In en, this message translates to:
  /// **'Tap to apply suggested price'**
  String get tapToApplySuggestedPrice;

  /// No description provided for @smartPricingEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Pricing Engine'**
  String get smartPricingEngineTitle;

  /// No description provided for @modeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get modeLabel;

  /// No description provided for @noMarketDataLabel.
  ///
  /// In en, this message translates to:
  /// **'No market data'**
  String get noMarketDataLabel;

  /// No description provided for @usingSmartEstimationLabel.
  ///
  /// In en, this message translates to:
  /// **'Using smart estimation 🧠'**
  String get usingSmartEstimationLabel;

  /// No description provided for @marketIntelligenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Market Intelligence'**
  String get marketIntelligenceTitle;

  /// No description provided for @avgPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Avg price'**
  String get avgPriceLabel;

  /// No description provided for @medianPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Median price'**
  String get medianPriceLabel;

  /// No description provided for @sellerCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller count'**
  String get sellerCountLabel;

  /// No description provided for @bestPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Best price'**
  String get bestPriceLabel;

  /// No description provided for @highestPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Highest price'**
  String get highestPriceLabel;

  /// No description provided for @yourGapVsMarketLabel.
  ///
  /// In en, this message translates to:
  /// **'Your gap vs market'**
  String get yourGapVsMarketLabel;

  /// No description provided for @positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get positionLabel;

  /// No description provided for @profitMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Profit margin'**
  String get profitMarginLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @searchingProductStatus.
  ///
  /// In en, this message translates to:
  /// **'Searching product...'**
  String get searchingProductStatus;

  /// No description provided for @productAlreadyExistsOpeningEditStatus.
  ///
  /// In en, this message translates to:
  /// **'Product exists, opening editor...'**
  String get productAlreadyExistsOpeningEditStatus;

  /// No description provided for @fetchingProductDataStatus.
  ///
  /// In en, this message translates to:
  /// **'Fetching product data...'**
  String get fetchingProductDataStatus;

  /// No description provided for @analyzingMarketStatus.
  ///
  /// In en, this message translates to:
  /// **'Analyzing market...'**
  String get analyzingMarketStatus;

  /// No description provided for @marketAvgLabel.
  ///
  /// In en, this message translates to:
  /// **'Average price'**
  String get marketAvgLabel;

  /// No description provided for @marketMedianLabel.
  ///
  /// In en, this message translates to:
  /// **'Median price'**
  String get marketMedianLabel;

  /// No description provided for @marketSellersLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller count'**
  String get marketSellersLabel;

  /// No description provided for @emergencyFallbackLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency fallback: {price} {currency}'**
  String emergencyFallbackLabel(Object currency, Object price);

  /// No description provided for @productReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Product ready ✅'**
  String get productReadyStatus;

  /// No description provided for @failedToLoadProductStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to load product'**
  String get failedToLoadProductStatus;

  /// No description provided for @barcodeLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Barcode lookup failed'**
  String get barcodeLookupFailed;

  /// No description provided for @editProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get editProductTitle;

  /// No description provided for @addProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get addProductTitle;

  /// No description provided for @tapToReplaceOrAddMedia.
  ///
  /// In en, this message translates to:
  /// **'Tap to replace or add media'**
  String get tapToReplaceOrAddMedia;

  /// No description provided for @tapToAddMedia.
  ///
  /// In en, this message translates to:
  /// **'Tap to add media'**
  String get tapToAddMedia;

  /// No description provided for @basicInfoSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic info'**
  String get basicInfoSectionTitle;

  /// No description provided for @productNameMinCharsLabel.
  ///
  /// In en, this message translates to:
  /// **'Product name *'**
  String get productNameMinCharsLabel;

  /// No description provided for @brandLabel.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brandLabel;

  /// No description provided for @barcodeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcodeFieldLabel;

  /// No description provided for @enterBarcodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter or scan the barcode'**
  String get enterBarcodeHint;

  /// No description provided for @noBarcodeSkuHint.
  ///
  /// In en, this message translates to:
  /// **'Barcode is optional. SKU will be auto-generated if empty.'**
  String get noBarcodeSkuHint;

  /// No description provided for @scanButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanButtonLabel;

  /// No description provided for @skuCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'SKU Code'**
  String get skuCodeLabel;

  /// No description provided for @autoGeneratedSkuHint.
  ///
  /// In en, this message translates to:
  /// **'Auto-generated if empty'**
  String get autoGeneratedSkuHint;

  /// No description provided for @shippingAndDeliverySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipping and delivery'**
  String get shippingAndDeliverySectionTitle;

  /// No description provided for @thisProductHasADiscount.
  ///
  /// In en, this message translates to:
  /// **'This product has a discount'**
  String get thisProductHasADiscount;

  /// No description provided for @originalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Original price'**
  String get originalPriceLabel;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @appointmentDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointment Detail'**
  String get appointmentDetailTitle;

  /// No description provided for @appointmentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Appointment not found'**
  String get appointmentNotFound;

  /// No description provided for @petLabel.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get petLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @paymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentLabel;

  /// No description provided for @goToPaymentButton.
  ///
  /// In en, this message translates to:
  /// **'Go to Payment'**
  String get goToPaymentButton;

  /// No description provided for @markedAsCompletedSnack.
  ///
  /// In en, this message translates to:
  /// **'Marked as completed'**
  String get markedAsCompletedSnack;

  /// No description provided for @markAsCompletedButton.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get markAsCompletedButton;

  /// No description provided for @wholesalePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Wholesale price'**
  String get wholesalePriceLabel;

  /// No description provided for @minimumQuantityForWholesaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum quantity for wholesale'**
  String get minimumQuantityForWholesaleLabel;

  /// No description provided for @wholesaleAppliesHint.
  ///
  /// In en, this message translates to:
  /// **'Wholesale discount applies from this quantity'**
  String get wholesaleAppliesHint;

  /// No description provided for @visibleOnlyToBusinessAccountsHint.
  ///
  /// In en, this message translates to:
  /// **'Visible only to business accounts'**
  String get visibleOnlyToBusinessAccountsHint;

  /// No description provided for @usersWillSeeDiscountHint.
  ///
  /// In en, this message translates to:
  /// **'Users will see the discount badge'**
  String get usersWillSeeDiscountHint;

  /// No description provided for @discountPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Discount price'**
  String get discountPriceLabel;

  /// No description provided for @kdvLabel.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get kdvLabel;

  /// No description provided for @lengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get lengthLabel;

  /// No description provided for @widthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get widthLabel;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightLabel;

  /// No description provided for @calculatedDesiLabel.
  ///
  /// In en, this message translates to:
  /// **'Calculated desi: {value}'**
  String calculatedDesiLabel(Object value);

  /// No description provided for @manualDesiOverrideOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Manual desi override (optional)'**
  String get manualDesiOverrideOptionalLabel;

  /// No description provided for @shippingModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping mode'**
  String get shippingModeLabel;

  /// No description provided for @carrierCalculatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Carrier calculated'**
  String get carrierCalculatedLabel;

  /// No description provided for @fixedShippingFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed shipping fee'**
  String get fixedShippingFeeLabel;

  /// No description provided for @sellerPaysShippingLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller pays shipping'**
  String get sellerPaysShippingLabel;

  /// No description provided for @enableFreeShippingCampaignLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable free shipping campaign'**
  String get enableFreeShippingCampaignLabel;

  /// No description provided for @freeShippingThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Free shipping threshold'**
  String get freeShippingThresholdLabel;

  /// No description provided for @preparationTimeDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Preparation time (days)'**
  String get preparationTimeDaysLabel;

  /// No description provided for @maxDeliveryTimeDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Max delivery time (days)'**
  String get maxDeliveryTimeDaysLabel;

  /// No description provided for @cargoCompaniesTitle.
  ///
  /// In en, this message translates to:
  /// **'Cargo companies'**
  String get cargoCompaniesTitle;

  /// No description provided for @allowReturnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow returns'**
  String get allowReturnsLabel;

  /// No description provided for @returnWindowDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Return window (days)'**
  String get returnWindowDaysLabel;

  /// No description provided for @returnShippingPayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Return shipping payer'**
  String get returnShippingPayerLabel;

  /// No description provided for @sellerOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get sellerOptionLabel;

  /// No description provided for @buyerOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get buyerOptionLabel;

  /// No description provided for @sellerContractedCarrierOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller if contracted carrier only'**
  String get sellerContractedCarrierOnlyLabel;

  /// No description provided for @inventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventoryTitle;

  /// No description provided for @lowStockAlertLabel.
  ///
  /// In en, this message translates to:
  /// **'Low stock alert'**
  String get lowStockAlertLabel;

  /// No description provided for @mainCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Main category'**
  String get mainCategoryLabel;

  /// No description provided for @subCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get subCategoryLabel;

  /// No description provided for @generatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generatingLabel;

  /// No description provided for @suggestLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggest'**
  String get suggestLabel;

  /// No description provided for @updateProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Product'**
  String get updateProductTitle;

  /// No description provided for @sellInstantlyButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Sell instantly'**
  String get sellInstantlyButtonLabel;

  /// No description provided for @shippingEstimateTitle.
  ///
  /// In en, this message translates to:
  /// **'Shipping estimate'**
  String get shippingEstimateTitle;

  /// No description provided for @desiLabel.
  ///
  /// In en, this message translates to:
  /// **'Desi: {value}'**
  String desiLabel(Object value);

  /// No description provided for @billableLabel.
  ///
  /// In en, this message translates to:
  /// **'Billable: {value}'**
  String billableLabel(Object value);

  /// No description provided for @basePriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Base: {value} {currency}'**
  String basePriceLabel(Object currency, Object value);

  /// No description provided for @extraLabel.
  ///
  /// In en, this message translates to:
  /// **'Extra: {value} {currency}'**
  String extraLabel(Object currency, Object value);

  /// No description provided for @totalPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Total: {value} {currency}'**
  String totalPriceLabel(Object currency, Object value);

  /// No description provided for @returnRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Return Requests'**
  String get returnRequestsTitle;

  /// No description provided for @returnAvailableAfterDeliveryMessage.
  ///
  /// In en, this message translates to:
  /// **'Returns become available after delivery.'**
  String get returnAvailableAfterDeliveryMessage;

  /// No description provided for @noReturnsYet.
  ///
  /// In en, this message translates to:
  /// **'No return requests yet'**
  String get noReturnsYet;

  /// No description provided for @requestReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Request Return'**
  String get requestReturnButton;

  /// No description provided for @returnRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Return request submitted'**
  String get returnRequestSubmitted;

  /// No description provided for @selectReturnReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Select reason'**
  String get selectReturnReasonLabel;

  /// No description provided for @returnDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
  String get returnDescriptionHint;

  /// No description provided for @selectReturnItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Select items to return'**
  String get selectReturnItemsLabel;

  /// No description provided for @returnRequestLabel.
  ///
  /// In en, this message translates to:
  /// **'Return #{id}'**
  String returnRequestLabel(Object id);

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonLabel;

  /// No description provided for @refundAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund amount'**
  String get refundAmountLabel;

  /// No description provided for @returnAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated refund'**
  String get returnAmountLabel;

  /// No description provided for @shippingResponsibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Return shipping'**
  String get shippingResponsibilityLabel;

  /// No description provided for @refundTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund type'**
  String get refundTypeLabel;

  /// No description provided for @returnTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Return timeline'**
  String get returnTimelineTitle;

  /// No description provided for @refundResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund result'**
  String get refundResultLabel;

  /// No description provided for @returnActionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Return updated'**
  String get returnActionCompleted;

  /// No description provided for @approveReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveReturnButton;

  /// No description provided for @rejectReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectReturnButton;

  /// No description provided for @cancelReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel return'**
  String get cancelReturnButton;

  /// No description provided for @markShippedBackButton.
  ///
  /// In en, this message translates to:
  /// **'Mark shipped back'**
  String get markShippedBackButton;

  /// No description provided for @markReceivedButton.
  ///
  /// In en, this message translates to:
  /// **'Mark received'**
  String get markReceivedButton;

  /// No description provided for @triggerRefundButton.
  ///
  /// In en, this message translates to:
  /// **'Trigger refund'**
  String get triggerRefundButton;

  /// No description provided for @returnStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get returnStatusPending;

  /// No description provided for @returnStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get returnStatusApproved;

  /// No description provided for @returnStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get returnStatusRejected;

  /// No description provided for @returnStatusShippedBack.
  ///
  /// In en, this message translates to:
  /// **'Shipped back'**
  String get returnStatusShippedBack;

  /// No description provided for @returnStatusReceivedBySeller.
  ///
  /// In en, this message translates to:
  /// **'Received by seller'**
  String get returnStatusReceivedBySeller;

  /// No description provided for @returnStatusRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund pending'**
  String get returnStatusRefundPending;

  /// No description provided for @returnStatusRefundFailed.
  ///
  /// In en, this message translates to:
  /// **'Refund failed'**
  String get returnStatusRefundFailed;

  /// No description provided for @returnStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get returnStatusRefunded;

  /// No description provided for @returnStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get returnStatusCancelled;

  /// No description provided for @returnReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get returnReasonDamaged;

  /// No description provided for @returnReasonWrongProduct.
  ///
  /// In en, this message translates to:
  /// **'Wrong product'**
  String get returnReasonWrongProduct;

  /// No description provided for @returnReasonMissingParts.
  ///
  /// In en, this message translates to:
  /// **'Missing parts'**
  String get returnReasonMissingParts;

  /// No description provided for @returnReasonNotAsDescribed.
  ///
  /// In en, this message translates to:
  /// **'Not as described'**
  String get returnReasonNotAsDescribed;

  /// No description provided for @returnReasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'Changed mind'**
  String get returnReasonChangedMind;

  /// No description provided for @returnReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get returnReasonOther;

  /// No description provided for @refundTypeFullLabel.
  ///
  /// In en, this message translates to:
  /// **'Full refund'**
  String get refundTypeFullLabel;

  /// No description provided for @refundTypePartialLabel.
  ///
  /// In en, this message translates to:
  /// **'Partial refund'**
  String get refundTypePartialLabel;

  /// No description provided for @refundTypeShippingLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping refund'**
  String get refundTypeShippingLabel;

  /// No description provided for @shippingResponsibilitySellerLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get shippingResponsibilitySellerLabel;

  /// No description provided for @shippingResponsibilityBuyerLabel.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get shippingResponsibilityBuyerLabel;

  /// No description provided for @shippingResponsibilityContractCarrierLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller if contracted carrier'**
  String get shippingResponsibilityContractCarrierLabel;

  /// No description provided for @returnCarrierLabel.
  ///
  /// In en, this message translates to:
  /// **'Return Carrier'**
  String get returnCarrierLabel;

  /// No description provided for @returnImagesAdded.
  ///
  /// In en, this message translates to:
  /// **'Images added'**
  String get returnImagesAdded;

  /// No description provided for @refundRejectedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund rejected'**
  String get refundRejectedStatusLabel;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'fa', 'ru', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'fa': return AppLocalizationsFa();
    case 'ru': return AppLocalizationsRu();
    case 'tr': return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
