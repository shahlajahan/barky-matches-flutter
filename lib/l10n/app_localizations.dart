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

  /// No description provided for @marketplaceDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get marketplaceDisclaimerTitle;

  /// No description provided for @marketplaceDisclaimerMessage.
  ///
  /// In en, this message translates to:
  /// **'PetSupo is a platform that connects you with independent businesses and service providers. The selected service is provided by the business or provider shown. PetSupo does not guarantee or assume responsibility for the quality or execution of that independent service. Please review the business or provider information before continuing.'**
  String get marketplaceDisclaimerMessage;

  /// No description provided for @marketplaceDisclaimerAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept & Continue'**
  String get marketplaceDisclaimerAccept;

  /// No description provided for @marketplaceDisclaimerCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get marketplaceDisclaimerCancel;

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

  /// No description provided for @checkoutMultiSellerInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'One payment, separate orders'**
  String get checkoutMultiSellerInfoTitle;

  /// No description provided for @checkoutMultiSellerInfoBody.
  ///
  /// In en, this message translates to:
  /// **'You’ll make one payment. A separate order will be created for each seller.'**
  String get checkoutMultiSellerInfoBody;

  /// No description provided for @checkoutSellerSection.
  ///
  /// In en, this message translates to:
  /// **'{sellerName}'**
  String checkoutSellerSection(Object sellerName);

  /// No description provided for @checkoutSellerFallback.
  ///
  /// In en, this message translates to:
  /// **'Seller {number}'**
  String checkoutSellerFallback(int number);

  /// No description provided for @checkoutSellerSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Seller subtotal'**
  String get checkoutSellerSubtotal;

  /// No description provided for @checkoutProductsTotal.
  ///
  /// In en, this message translates to:
  /// **'Products total'**
  String get checkoutProductsTotal;

  /// No description provided for @checkoutShippingMethod.
  ///
  /// In en, this message translates to:
  /// **'Shipping method'**
  String get checkoutShippingMethod;

  /// No description provided for @checkoutShippingCost.
  ///
  /// In en, this message translates to:
  /// **'Shipping cost'**
  String get checkoutShippingCost;

  /// No description provided for @checkoutShippingTotal.
  ///
  /// In en, this message translates to:
  /// **'Shipping total'**
  String get checkoutShippingTotal;

  /// No description provided for @checkoutEstimatedDelivery.
  ///
  /// In en, this message translates to:
  /// **'Estimated delivery'**
  String get checkoutEstimatedDelivery;

  /// No description provided for @checkoutSellerTotal.
  ///
  /// In en, this message translates to:
  /// **'Seller total'**
  String get checkoutSellerTotal;

  /// No description provided for @checkoutMultiOrderSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get checkoutMultiOrderSuccessTitle;

  /// No description provided for @checkoutMultiOrderSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment was completed and separate orders were created for each seller.'**
  String get checkoutMultiOrderSuccessBody;

  /// No description provided for @checkoutSellerOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller order {number}'**
  String checkoutSellerOrderLabel(int number);

  /// No description provided for @checkoutOpenOrder.
  ///
  /// In en, this message translates to:
  /// **'View order'**
  String get checkoutOpenOrder;

  /// No description provided for @checkoutMultiOrderExit.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get checkoutMultiOrderExit;

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
  /// **'My Pets'**
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
  /// **'Minimum 8 characters, with a letter and a number.'**
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
  /// **'Invalid verification code. Please try again.'**
  String get invalidVerificationCode;

  /// No description provided for @verificationCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired. Request a new code.'**
  String get verificationCodeExpired;

  /// No description provided for @unableToVerifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify right now. Please try again.'**
  String get unableToVerifyEmail;

  /// No description provided for @unableToSendVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Unable to send a new code right now. Please try again.'**
  String get unableToSendVerificationCode;

  /// No description provided for @verificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code sent to: {email}'**
  String verificationCodeSentTo(Object email);

  /// No description provided for @verificationCodeSentToLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to'**
  String get verificationCodeSentToLabel;

  /// No description provided for @sendingVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingVerificationCode;

  /// No description provided for @resendCodeAvailableIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code available in {seconds}s'**
  String resendCodeAvailableIn(Object seconds);

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change email'**
  String get changeEmail;

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
  /// **'Welcome back to PetSupo'**
  String get authWelcomeBackSubtitle;

  /// Subtitle on auth sign-up page
  ///
  /// In en, this message translates to:
  /// **'Create your PetSopu account'**
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

  /// Title for the add pet screen
  ///
  /// In en, this message translates to:
  /// **'Add Your Pet'**
  String get addYourPetTitle;

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

  /// Label for age unit dropdown
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get ageUnit;

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
  /// **'Edit Pet Profile'**
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

  /// No description provided for @dogNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Dog name \"{name}\" already exists'**
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
  /// **'Add Pet'**
  String get addDogButton;

  /// Title for add dog page
  ///
  /// In en, this message translates to:
  /// **'Add Dog'**
  String get dogDetailsAddTitle;

  /// Title for edit dog page
  ///
  /// In en, this message translates to:
  /// **'Edit Pet Profile'**
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
  /// **'Breed (PetSupo Partner)'**
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

  /// No description provided for @dogInfoLiked.
  ///
  /// In en, this message translates to:
  /// **'You liked {name}'**
  String dogInfoLiked(Object name);

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

  /// Label for months in age display
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get months;

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

  /// Badge text shown for sponsored offers
  ///
  /// In en, this message translates to:
  /// **'🔥 Hot Deal'**
  String get offerHotDeal;

  /// Badge text shown for premium-only offers
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get offerPremiumBadge;

  /// No description provided for @offerFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Special offer for PetSupo users'**
  String get offerFallbackTitle;

  /// Fallback provider name shown when an offer provider is missing
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

  /// No description provided for @featuredDealsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Featured Deals'**
  String get featuredDealsEmptyTitle;

  /// No description provided for @featuredDealsEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Special offers from PetSupo partners will appear here.'**
  String get featuredDealsEmptyDescription;

  /// No description provided for @premiumLabel.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumLabel;

  /// No description provided for @goldLabel.
  ///
  /// In en, this message translates to:
  /// **'PetSupo Partner'**
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
  /// **'Coming Soon'**
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
  /// **'PetSupo Partner members: free checkup'**
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

  /// No description provided for @businessRegisterCompanyTypeQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is your business type?'**
  String get businessRegisterCompanyTypeQuestion;

  /// No description provided for @businessRegisterCompanyTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'The documents you need to upload will be determined by your business type.'**
  String get businessRegisterCompanyTypeHelper;

  /// No description provided for @businessRegisterCompanyTypeSoleProprietorship.
  ///
  /// In en, this message translates to:
  /// **'Şahıs İşletmesi (Sole Proprietorship)'**
  String get businessRegisterCompanyTypeSoleProprietorship;

  /// No description provided for @businessRegisterCompanyTypeLimitedCompany.
  ///
  /// In en, this message translates to:
  /// **'Limited Şirket (Limited Company)'**
  String get businessRegisterCompanyTypeLimitedCompany;

  /// No description provided for @businessRegisterCompanyTypeJointStockCompany.
  ///
  /// In en, this message translates to:
  /// **'Anonim Şirket (Joint Stock Company)'**
  String get businessRegisterCompanyTypeJointStockCompany;

  /// No description provided for @businessRegisterCompanyTypeRequired.
  ///
  /// In en, this message translates to:
  /// **'• Please select your company type.'**
  String get businessRegisterCompanyTypeRequired;

  /// No description provided for @businessRegisterCompanyTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Company Type'**
  String get businessRegisterCompanyTypeLabel;

  /// No description provided for @businessRegisterCompanyTypeLegacyUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified / Legacy'**
  String get businessRegisterCompanyTypeLegacyUnspecified;

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
  /// **'Upgrade to PetSupo Partner to register your business and start receiving customers.'**
  String get userProfileUpgradeBusinessDescription;

  /// No description provided for @userProfileUpgradeToGold.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to PetSupo Partner'**
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
  /// **'Upgrade to PetSupo Partner to continue'**
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

  /// No description provided for @myOrdersUnknownProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get myOrdersUnknownProduct;

  /// No description provided for @myOrdersUnknownSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller'**
  String get myOrdersUnknownSeller;

  /// No description provided for @myOrdersProductAndMore.
  ///
  /// In en, this message translates to:
  /// **'{product} + {count} more'**
  String myOrdersProductAndMore(Object product, int count);

  /// No description provided for @myOrdersOrderNumberUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get myOrdersOrderNumberUnavailable;

  /// No description provided for @myOrdersDateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Date unavailable'**
  String get myOrdersDateUnavailable;

  /// No description provided for @myOrdersSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Date: newest first'**
  String get myOrdersSortNewest;

  /// No description provided for @myOrdersSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Date: oldest first'**
  String get myOrdersSortOldest;

  /// No description provided for @myOrdersSortProductAz.
  ///
  /// In en, this message translates to:
  /// **'Product: A–Z'**
  String get myOrdersSortProductAz;

  /// No description provided for @myOrdersSortProductZa.
  ///
  /// In en, this message translates to:
  /// **'Product: Z–A'**
  String get myOrdersSortProductZa;

  /// No description provided for @myOrdersSortSellerAz.
  ///
  /// In en, this message translates to:
  /// **'Seller: A–Z'**
  String get myOrdersSortSellerAz;

  /// No description provided for @myOrdersSortSellerZa.
  ///
  /// In en, this message translates to:
  /// **'Seller: Z–A'**
  String get myOrdersSortSellerZa;

  /// No description provided for @myOrdersSortAmountHigh.
  ///
  /// In en, this message translates to:
  /// **'Amount: highest first'**
  String get myOrdersSortAmountHigh;

  /// No description provided for @myOrdersSortAmountLow.
  ///
  /// In en, this message translates to:
  /// **'Amount: lowest first'**
  String get myOrdersSortAmountLow;

  /// No description provided for @myOrdersProcessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get myOrdersProcessingStatus;

  /// No description provided for @myOrdersRefundedStatus.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get myOrdersRefundedStatus;

  /// No description provided for @myOrdersReturnedStatus.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get myOrdersReturnedStatus;

  /// No description provided for @myOrdersRefundedOrReturnedStatus.
  ///
  /// In en, this message translates to:
  /// **'Refunded / Returned'**
  String get myOrdersRefundedOrReturnedStatus;

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
  /// **'For pet-care professionals and businesses'**
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

  /// No description provided for @mobileSubscriptionVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify the subscription yet. Please try Restore Purchases again.'**
  String get mobileSubscriptionVerificationFailed;

  /// No description provided for @mobileSubscriptionOwnershipConflict.
  ///
  /// In en, this message translates to:
  /// **'This subscription is linked to another Petsupo account. Please sign in to the account originally used for this subscription.'**
  String get mobileSubscriptionOwnershipConflict;

  /// No description provided for @deleteAccountStoreSubscriptionNotice.
  ///
  /// In en, this message translates to:
  /// **'Deleting your PetSupo account does not cancel Apple App Store or Google Play subscriptions. Cancel store billing separately before deleting your account.'**
  String get deleteAccountStoreSubscriptionNotice;

  /// No description provided for @manageStoreSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage store subscription'**
  String get manageStoreSubscription;

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

  /// No description provided for @sellerRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller relationship'**
  String get sellerRelationshipLabel;

  /// No description provided for @sellerRelationshipIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a seller relationship'**
  String get sellerRelationshipIsRequired;

  /// No description provided for @sellerRelationshipBrandOwner.
  ///
  /// In en, this message translates to:
  /// **'Brand owner'**
  String get sellerRelationshipBrandOwner;

  /// No description provided for @sellerRelationshipManufacturer.
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get sellerRelationshipManufacturer;

  /// No description provided for @sellerRelationshipAuthorizedDistributor.
  ///
  /// In en, this message translates to:
  /// **'Authorized distributor'**
  String get sellerRelationshipAuthorizedDistributor;

  /// No description provided for @sellerRelationshipAuthorizedDealer.
  ///
  /// In en, this message translates to:
  /// **'Authorized dealer'**
  String get sellerRelationshipAuthorizedDealer;

  /// No description provided for @sellerRelationshipImporter.
  ///
  /// In en, this message translates to:
  /// **'Importer'**
  String get sellerRelationshipImporter;

  /// No description provided for @sellerRelationshipReseller.
  ///
  /// In en, this message translates to:
  /// **'Reseller'**
  String get sellerRelationshipReseller;

  /// No description provided for @mediaMaxTwentyEntries.
  ///
  /// In en, this message translates to:
  /// **'You can add up to 20 media items'**
  String get mediaMaxTwentyEntries;

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

  /// No description provided for @productSubmittedForReviewStatus.
  ///
  /// In en, this message translates to:
  /// **'Product submitted for review. It will not be visible until approved.'**
  String get productSubmittedForReviewStatus;

  /// No description provided for @veterinaryProductsNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Online sale and promotion of veterinary medicinal products is not supported.'**
  String get veterinaryProductsNotSupported;

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

  /// No description provided for @appointmentNoLongerAvailable.
  ///
  /// In en, this message translates to:
  /// **'This appointment is no longer available.'**
  String get appointmentNoLongerAvailable;

  /// No description provided for @appointmentAvailabilityChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking appointment availability...'**
  String get appointmentAvailabilityChecking;

  /// No description provided for @appointmentAvailabilityCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check this appointment. Please try again.'**
  String get appointmentAvailabilityCheckFailed;

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

  /// No description provided for @returnShippingTitle.
  ///
  /// In en, this message translates to:
  /// **'Return Shipping'**
  String get returnShippingTitle;

  /// No description provided for @returnShippingBuyerMessage.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for the return shipping cost.\n\nThe courier fee is separate from your refund and may not be reimbursed.'**
  String get returnShippingBuyerMessage;

  /// No description provided for @returnShippingSellerMessage.
  ///
  /// In en, this message translates to:
  /// **'The seller is responsible for the return shipping cost.'**
  String get returnShippingSellerMessage;

  /// No description provided for @returnShippingContractedCarrierMessage.
  ///
  /// In en, this message translates to:
  /// **'Use the seller\'s contracted return carrier.'**
  String get returnShippingContractedCarrierMessage;

  /// No description provided for @returnShippingBuyerShipBackMessage.
  ///
  /// In en, this message translates to:
  /// **'The courier fee is your responsibility and is separate from the refund.'**
  String get returnShippingBuyerShipBackMessage;

  /// No description provided for @returnShippingSellerShipBackMessage.
  ///
  /// In en, this message translates to:
  /// **'The seller covers the return shipping cost.'**
  String get returnShippingSellerShipBackMessage;

  /// No description provided for @returnShippingAcknowledgement.
  ///
  /// In en, this message translates to:
  /// **'I understand the return shipping policy.'**
  String get returnShippingAcknowledgement;

  /// No description provided for @returnShippingPolicyLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading return shipping policy…'**
  String get returnShippingPolicyLoading;

  /// No description provided for @returnShippingCarrierValue.
  ///
  /// In en, this message translates to:
  /// **'Carrier: {carrier}'**
  String returnShippingCarrierValue(Object carrier);

  /// No description provided for @returnShippingVerifiedCarrierHelper.
  ///
  /// In en, this message translates to:
  /// **'Use this verified contracted return carrier.'**
  String get returnShippingVerifiedCarrierHelper;

  /// No description provided for @returnCarrierEnterHelperText.
  ///
  /// In en, this message translates to:
  /// **'Enter the carrier used for this return shipment.'**
  String get returnCarrierEnterHelperText;

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

  /// No description provided for @refundDecisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund decision'**
  String get refundDecisionTitle;

  /// No description provided for @refundDecisionFullTitle.
  ///
  /// In en, this message translates to:
  /// **'Full Refund'**
  String get refundDecisionFullTitle;

  /// No description provided for @refundDecisionFullDescription.
  ///
  /// In en, this message translates to:
  /// **'Refund the entire eligible amount.'**
  String get refundDecisionFullDescription;

  /// No description provided for @refundDecisionFullRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended for damaged or defective items, wrong items, seller mistakes, or items never delivered.'**
  String get refundDecisionFullRecommended;

  /// No description provided for @refundDecisionPartialTitle.
  ///
  /// In en, this message translates to:
  /// **'Partial Refund'**
  String get refundDecisionPartialTitle;

  /// No description provided for @refundDecisionPartialDescription.
  ///
  /// In en, this message translates to:
  /// **'Refund only part of the eligible amount. A justification is required.'**
  String get refundDecisionPartialDescription;

  /// No description provided for @refundDecisionRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Refund'**
  String get refundDecisionRejectTitle;

  /// No description provided for @refundDecisionRejectDescription.
  ///
  /// In en, this message translates to:
  /// **'Decline the refund request. A clear explanation is required.'**
  String get refundDecisionRejectDescription;

  /// No description provided for @refundPartialAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Partial refund amount'**
  String get refundPartialAmountLabel;

  /// No description provided for @refundMaximumEligible.
  ///
  /// In en, this message translates to:
  /// **'Maximum eligible: {amount}'**
  String refundMaximumEligible(Object amount);

  /// No description provided for @refundAmountValidationError.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount greater than zero and no more than the eligible refund.'**
  String get refundAmountValidationError;

  /// No description provided for @refundDecisionReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get refundDecisionReasonLabel;

  /// No description provided for @refundReasonNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Select a reason'**
  String get refundReasonNotSelected;

  /// No description provided for @refundSellerNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller notes'**
  String get refundSellerNotesLabel;

  /// No description provided for @refundNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get refundNotesOptional;

  /// No description provided for @refundNotesRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get refundNotesRequired;

  /// No description provided for @refundBuyerExplanationLabel.
  ///
  /// In en, this message translates to:
  /// **'Buyer-visible explanation'**
  String get refundBuyerExplanationLabel;

  /// No description provided for @refundBuyerExplanationHelper.
  ///
  /// In en, this message translates to:
  /// **'Explain clearly why the refund is being declined.'**
  String get refundBuyerExplanationHelper;

  /// No description provided for @refundOriginalOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Original Order'**
  String get refundOriginalOrderLabel;

  /// No description provided for @refundSummaryRefundLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refundSummaryRefundLabel;

  /// No description provided for @refundDifferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Difference'**
  String get refundDifferenceLabel;

  /// No description provided for @refundDecisionBuyerTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund decision'**
  String get refundDecisionBuyerTitle;

  /// No description provided for @refundDecisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get refundDecisionLabel;

  /// No description provided for @refundSellerExplanationLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller explanation'**
  String get refundSellerExplanationLabel;

  /// No description provided for @refundReasonItemReturnedDamaged.
  ///
  /// In en, this message translates to:
  /// **'Item returned damaged'**
  String get refundReasonItemReturnedDamaged;

  /// No description provided for @refundReasonMissingAccessories.
  ///
  /// In en, this message translates to:
  /// **'Missing accessories'**
  String get refundReasonMissingAccessories;

  /// No description provided for @refundReasonCustomerCausedDamage.
  ///
  /// In en, this message translates to:
  /// **'Customer caused damage'**
  String get refundReasonCustomerCausedDamage;

  /// No description provided for @refundReasonRestockingFee.
  ///
  /// In en, this message translates to:
  /// **'Restocking fee'**
  String get refundReasonRestockingFee;

  /// No description provided for @refundReasonPartialReturn.
  ///
  /// In en, this message translates to:
  /// **'Partial return'**
  String get refundReasonPartialReturn;

  /// No description provided for @refundReasonSellerMistake.
  ///
  /// In en, this message translates to:
  /// **'Seller mistake'**
  String get refundReasonSellerMistake;

  /// No description provided for @refundReasonWrongItem.
  ///
  /// In en, this message translates to:
  /// **'Wrong item'**
  String get refundReasonWrongItem;

  /// No description provided for @refundReasonDefectiveProduct.
  ///
  /// In en, this message translates to:
  /// **'Defective product'**
  String get refundReasonDefectiveProduct;

  /// No description provided for @refundReasonItemNeverDelivered.
  ///
  /// In en, this message translates to:
  /// **'Item never delivered'**
  String get refundReasonItemNeverDelivered;

  /// No description provided for @refundReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get refundReasonOther;

  /// No description provided for @returnStatusWaitingSellerConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for seller confirmation'**
  String get returnStatusWaitingSellerConfirmation;

  /// No description provided for @returnStatusAutoReceived.
  ///
  /// In en, this message translates to:
  /// **'Automatically received'**
  String get returnStatusAutoReceived;

  /// No description provided for @returnStatusDispute.
  ///
  /// In en, this message translates to:
  /// **'Return dispute'**
  String get returnStatusDispute;

  /// No description provided for @waitingForSellerInspectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for seller inspection'**
  String get waitingForSellerInspectionTitle;

  /// No description provided for @waitingForSellerInspectionMessage.
  ///
  /// In en, this message translates to:
  /// **'The seller has until {date} to inspect the returned package. If no action is taken, the return will automatically continue.'**
  String waitingForSellerInspectionMessage(Object date);

  /// No description provided for @inspectionDeadlineTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection deadline'**
  String get inspectionDeadlineTitle;

  /// No description provided for @inspectionDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String inspectionDaysRemaining(int days);

  /// No description provided for @inspectionDeadlinePassed.
  ///
  /// In en, this message translates to:
  /// **'Deadline passed. Automatic completion pending.'**
  String get inspectionDeadlinePassed;

  /// No description provided for @reportReturnProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Report return problem'**
  String get reportReturnProblemTitle;

  /// No description provided for @reportProblemButton.
  ///
  /// In en, this message translates to:
  /// **'Report problem'**
  String get reportProblemButton;

  /// No description provided for @disputeReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Problem reason'**
  String get disputeReasonLabel;

  /// No description provided for @disputeReasonPackageNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Package not received'**
  String get disputeReasonPackageNotReceived;

  /// No description provided for @disputeReasonWrongItemReturned.
  ///
  /// In en, this message translates to:
  /// **'Wrong item returned'**
  String get disputeReasonWrongItemReturned;

  /// No description provided for @disputeReasonEmptyPackage.
  ///
  /// In en, this message translates to:
  /// **'Empty package'**
  String get disputeReasonEmptyPackage;

  /// No description provided for @disputeReasonDamagedDuringReturn.
  ///
  /// In en, this message translates to:
  /// **'Damaged during return'**
  String get disputeReasonDamagedDuringReturn;

  /// No description provided for @disputeReasonTrackingIssue.
  ///
  /// In en, this message translates to:
  /// **'Tracking issue'**
  String get disputeReasonTrackingIssue;

  /// No description provided for @adminReturnDisputesTitle.
  ///
  /// In en, this message translates to:
  /// **'Return disputes'**
  String get adminReturnDisputesTitle;

  /// No description provided for @adminReturnDisputesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review disputed marketplace returns'**
  String get adminReturnDisputesSubtitle;

  /// No description provided for @noReturnDisputes.
  ///
  /// In en, this message translates to:
  /// **'No disputed returns'**
  String get noReturnDisputes;

  /// No description provided for @locationUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Location updated successfully'**
  String get locationUpdatedSuccessfully;

  /// No description provided for @centersLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load centers'**
  String get centersLoadError;

  /// No description provided for @noAppointments.
  ///
  /// In en, this message translates to:
  /// **'No appointments.'**
  String get noAppointments;

  /// No description provided for @noAppointmentsFound.
  ///
  /// In en, this message translates to:
  /// **'No appointments found.'**
  String get noAppointmentsFound;

  /// No description provided for @appointmentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} appointments'**
  String appointmentsCount(Object count);

  /// No description provided for @any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get any;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get search;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get accessDenied;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @searchService.
  ///
  /// In en, this message translates to:
  /// **'Search {service}...'**
  String searchService(Object service);

  /// No description provided for @petHotels.
  ///
  /// In en, this message translates to:
  /// **'Pet Hotels'**
  String get petHotels;

  /// No description provided for @noItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No {title} yet'**
  String noItemsYet(Object title);

  /// No description provided for @noSavedPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved posts yet'**
  String get noSavedPostsYet;

  /// No description provided for @uploadedAt.
  ///
  /// In en, this message translates to:
  /// **'Uploaded: {date}'**
  String uploadedAt(Object date);

  /// No description provided for @productDetails.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productDetails;

  /// No description provided for @servicesCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Services couldn\'t be loaded'**
  String get servicesCouldNotBeLoaded;

  /// No description provided for @veterinaryClinics.
  ///
  /// In en, this message translates to:
  /// **'Veterinary clinics'**
  String get veterinaryClinics;

  /// No description provided for @noVeterinaryClinicsFound.
  ///
  /// In en, this message translates to:
  /// **'No veterinary clinics found.'**
  String get noVeterinaryClinicsFound;

  /// No description provided for @securePayment.
  ///
  /// In en, this message translates to:
  /// **'Secure Payment'**
  String get securePayment;

  /// No description provided for @liveDriver.
  ///
  /// In en, this message translates to:
  /// **'Live Driver'**
  String get liveDriver;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @myRides.
  ///
  /// In en, this message translates to:
  /// **'My Rides'**
  String get myRides;

  /// No description provided for @clientMessages.
  ///
  /// In en, this message translates to:
  /// **'Client Messages'**
  String get clientMessages;

  /// No description provided for @preVisitForm.
  ///
  /// In en, this message translates to:
  /// **'Pre-visit form'**
  String get preVisitForm;

  /// No description provided for @vetRevenueTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get vetRevenueTitle;

  /// No description provided for @vetRevenueDescription.
  ///
  /// In en, this message translates to:
  /// **'Verified payment and settlement data from completed veterinary transactions.'**
  String get vetRevenueDescription;

  /// No description provided for @vetRevenueRange7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get vetRevenueRange7Days;

  /// No description provided for @vetRevenueRange30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get vetRevenueRange30Days;

  /// No description provided for @vetRevenueRange90Days.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get vetRevenueRange90Days;

  /// No description provided for @vetRevenueRangeThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get vetRevenueRangeThisYear;

  /// No description provided for @vetRevenueRangeAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get vetRevenueRangeAllTime;

  /// No description provided for @vetRevenueGrossRevenue.
  ///
  /// In en, this message translates to:
  /// **'Gross Revenue'**
  String get vetRevenueGrossRevenue;

  /// No description provided for @vetRevenuePetsupoCommission.
  ///
  /// In en, this message translates to:
  /// **'PetSupo Commission'**
  String get vetRevenuePetsupoCommission;

  /// No description provided for @vetRevenueNetRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net Revenue'**
  String get vetRevenueNetRevenue;

  /// No description provided for @vetRevenuePendingSettlement.
  ///
  /// In en, this message translates to:
  /// **'Pending Settlement'**
  String get vetRevenuePendingSettlement;

  /// No description provided for @vetRevenuePaidTransactions.
  ///
  /// In en, this message translates to:
  /// **'Paid Transactions'**
  String get vetRevenuePaidTransactions;

  /// No description provided for @vetRevenuePendingPayments.
  ///
  /// In en, this message translates to:
  /// **'Pending Payments'**
  String get vetRevenuePendingPayments;

  /// No description provided for @vetRevenueRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get vetRevenueRefunded;

  /// No description provided for @vetRevenueExpiredOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Expired Opportunities'**
  String get vetRevenueExpiredOpportunities;

  /// No description provided for @vetRevenueMissingFinancialData.
  ///
  /// In en, this message translates to:
  /// **'Missing Financial Data'**
  String get vetRevenueMissingFinancialData;

  /// No description provided for @vetRevenueMissingFinancialWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} paid record(s) have missing or malformed financial data and are excluded from totals.'**
  String vetRevenueMissingFinancialWarning(int count);

  /// No description provided for @vetRevenueMixedCurrencyWarning.
  ///
  /// In en, this message translates to:
  /// **'Multiple currencies are present. Amounts are shown separately and are never converted or combined.'**
  String get vetRevenueMixedCurrencyWarning;

  /// No description provided for @vetRevenueNoAppointmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'No appointments yet'**
  String get vetRevenueNoAppointmentsTitle;

  /// No description provided for @vetRevenueNoAppointmentsMessage.
  ///
  /// In en, this message translates to:
  /// **'Revenue analytics will appear when veterinary appointments are created.'**
  String get vetRevenueNoAppointmentsMessage;

  /// No description provided for @vetRevenueNoRangeTitle.
  ///
  /// In en, this message translates to:
  /// **'No records in this period'**
  String get vetRevenueNoRangeTitle;

  /// No description provided for @vetRevenueNoRangeMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a wider date range to review earlier transactions.'**
  String get vetRevenueNoRangeMessage;

  /// No description provided for @vetRevenueLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue data is unavailable'**
  String get vetRevenueLoadErrorTitle;

  /// No description provided for @vetRevenueLoadErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Check the connection and try again. Existing payment records were not changed.'**
  String get vetRevenueLoadErrorMessage;

  /// No description provided for @vetRevenueRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get vetRevenueRetry;

  /// No description provided for @vetRevenueTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue Trend'**
  String get vetRevenueTrendTitle;

  /// No description provided for @vetRevenueMixedCurrencyChartHidden.
  ///
  /// In en, this message translates to:
  /// **'The combined trend is hidden because the selected period contains multiple currencies.'**
  String get vetRevenueMixedCurrencyChartHidden;

  /// No description provided for @vetRevenueNoRecognizedRevenue.
  ///
  /// In en, this message translates to:
  /// **'No verified paid revenue in this period.'**
  String get vetRevenueNoRecognizedRevenue;

  /// No description provided for @vetRevenueTopServices.
  ///
  /// In en, this message translates to:
  /// **'Top Services by Gross Revenue'**
  String get vetRevenueTopServices;

  /// No description provided for @vetRevenueTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get vetRevenueTransactions;

  /// No description provided for @vetRevenueUncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get vetRevenueUncategorized;

  /// No description provided for @vetRevenueSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer, pet, service or transaction'**
  String get vetRevenueSearchHint;

  /// No description provided for @vetRevenueAllPayments.
  ///
  /// In en, this message translates to:
  /// **'All payments'**
  String get vetRevenueAllPayments;

  /// No description provided for @vetRevenuePaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get vetRevenuePaid;

  /// No description provided for @vetRevenuePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get vetRevenuePending;

  /// No description provided for @vetRevenueExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get vetRevenueExpired;

  /// No description provided for @vetRevenueMissingFinancial.
  ///
  /// In en, this message translates to:
  /// **'Financial data missing'**
  String get vetRevenueMissingFinancial;

  /// No description provided for @vetRevenueSortDate.
  ///
  /// In en, this message translates to:
  /// **'Sort by date'**
  String get vetRevenueSortDate;

  /// No description provided for @vetRevenueSortDirection.
  ///
  /// In en, this message translates to:
  /// **'Change sort direction'**
  String get vetRevenueSortDirection;

  /// No description provided for @vetRevenueDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get vetRevenueDate;

  /// No description provided for @vetRevenueCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get vetRevenueCustomer;

  /// No description provided for @vetRevenuePet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get vetRevenuePet;

  /// No description provided for @vetRevenueService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get vetRevenueService;

  /// No description provided for @vetRevenueGross.
  ///
  /// In en, this message translates to:
  /// **'Gross'**
  String get vetRevenueGross;

  /// No description provided for @vetRevenueCommission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get vetRevenueCommission;

  /// No description provided for @vetRevenueNet.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get vetRevenueNet;

  /// No description provided for @vetRevenuePayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get vetRevenuePayment;

  /// No description provided for @vetRevenueSettlement.
  ///
  /// In en, this message translates to:
  /// **'Settlement'**
  String get vetRevenueSettlement;

  /// No description provided for @vetRevenueInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get vetRevenueInvoice;

  /// No description provided for @vetRevenueTransactionReference.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference'**
  String get vetRevenueTransactionReference;

  /// No description provided for @vetRevenueNoMatchingTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions match the current search and filter.'**
  String get vetRevenueNoMatchingTransactions;

  /// No description provided for @vetRevenuePageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String vetRevenuePageOf(int page, int total);

  /// No description provided for @vetWebOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic performance and operational overview'**
  String get vetWebOverviewSubtitle;

  /// No description provided for @vetWebAppointmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and manage veterinary appointments'**
  String get vetWebAppointmentsSubtitle;

  /// No description provided for @vetWebRevenueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified payment, commission and settlement analytics'**
  String get vetWebRevenueSubtitle;

  /// No description provided for @vetWebVeterinaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Veterinary'**
  String get vetWebVeterinaryLabel;

  /// No description provided for @petShopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Shops'**
  String get petShopsTitle;

  /// No description provided for @searchPetShopsHint.
  ///
  /// In en, this message translates to:
  /// **'Search pet shops'**
  String get searchPetShopsHint;

  /// No description provided for @noPetShopsFound.
  ///
  /// In en, this message translates to:
  /// **'No pet shops found'**
  String get noPetShopsFound;

  /// No description provided for @noPetShopsFoundDescription.
  ///
  /// In en, this message translates to:
  /// **'Try another search or check again later.'**
  String get noPetShopsFoundDescription;

  /// No description provided for @loadingPetShops.
  ///
  /// In en, this message translates to:
  /// **'Finding pet shops near you…'**
  String get loadingPetShops;

  /// No description provided for @petShopsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Pet shops could not be loaded. Please try again.'**
  String get petShopsLoadError;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @shopInformationTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop information'**
  String get shopInformationTitle;

  /// No description provided for @noShopDescriptionAvailable.
  ///
  /// In en, this message translates to:
  /// **'No shop description is available.'**
  String get noShopDescriptionAvailable;

  /// No description provided for @locationNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get locationNotAvailable;

  /// No description provided for @getDirectionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get getDirectionsLabel;

  /// No description provided for @connectLabel.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectLabel;

  /// No description provided for @callLabel.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get callLabel;

  /// No description provided for @whatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get whatsappLabel;

  /// No description provided for @websiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get websiteLabel;

  /// No description provided for @signInToContactShop.
  ///
  /// In en, this message translates to:
  /// **'Sign in to contact this shop.'**
  String get signInToContactShop;

  /// No description provided for @petShopUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Shop unavailable'**
  String get petShopUnavailable;

  /// No description provided for @petShopUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'This pet shop is no longer available.'**
  String get petShopUnavailableDescription;

  /// No description provided for @reviewsCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Reviews could not be loaded.'**
  String get reviewsCouldNotBeLoaded;

  /// No description provided for @noProductsAvailableFromShop.
  ///
  /// In en, this message translates to:
  /// **'No products available from this shop'**
  String get noProductsAvailableFromShop;

  /// No description provided for @petShopLocationNeededMessage.
  ///
  /// In en, this message translates to:
  /// **'We use your location to show nearby pet shops'**
  String get petShopLocationNeededMessage;

  /// No description provided for @infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get infoTitle;

  /// No description provided for @processTitle.
  ///
  /// In en, this message translates to:
  /// **'Process'**
  String get processTitle;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactTitle;

  /// No description provided for @openFullProfile.
  ///
  /// In en, this message translates to:
  /// **'Open full profile'**
  String get openFullProfile;

  /// No description provided for @noShopCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No shop categories are available.'**
  String get noShopCategoriesAvailable;

  /// No description provided for @browseShopProductsDescription.
  ///
  /// In en, this message translates to:
  /// **'Browse products available from this pet shop.'**
  String get browseShopProductsDescription;

  /// No description provided for @viewAllProducts.
  ///
  /// In en, this message translates to:
  /// **'View all products'**
  String get viewAllProducts;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @connectAppleAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect Apple account'**
  String get connectAppleAccount;

  /// No description provided for @appleAccountConnected.
  ///
  /// In en, this message translates to:
  /// **'Apple account connected'**
  String get appleAccountConnected;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @authenticationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Authentication cancelled'**
  String get authenticationCancelled;

  /// No description provided for @unableToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Unable to sign in'**
  String get unableToSignIn;

  /// No description provided for @emailRegisteredWithAnotherProvider.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered with another sign-in method'**
  String get emailRegisteredWithAnotherProvider;

  /// No description provided for @completeYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get completeYourProfile;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @districtLabel.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get districtLabel;

  /// No description provided for @cityRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your city'**
  String get cityRequired;

  /// No description provided for @districtRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your district'**
  String get districtRequired;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @petTaxiRequestRideTab.
  ///
  /// In en, this message translates to:
  /// **'Request Ride'**
  String get petTaxiRequestRideTab;

  /// No description provided for @petTaxiRidesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your upcoming and past Pet Taxi journeys'**
  String get petTaxiRidesSubtitle;

  /// No description provided for @petTaxiFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active & Upcoming'**
  String get petTaxiFilterActive;

  /// No description provided for @petTaxiFilterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get petTaxiFilterCompleted;

  /// No description provided for @petTaxiFilterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get petTaxiFilterCancelled;

  /// No description provided for @petTaxiNoRidesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Pet Taxi rides yet'**
  String get petTaxiNoRidesTitle;

  /// No description provided for @petTaxiNoRidesDescription.
  ///
  /// In en, this message translates to:
  /// **'Your Pet Taxi bookings will appear here after you request a ride.'**
  String get petTaxiNoRidesDescription;

  /// No description provided for @petTaxiNoRidesInFilter.
  ///
  /// In en, this message translates to:
  /// **'No rides in this category'**
  String get petTaxiNoRidesInFilter;

  /// No description provided for @petTaxiTryAnotherFilter.
  ///
  /// In en, this message translates to:
  /// **'Choose another category to view your other rides.'**
  String get petTaxiTryAnotherFilter;

  /// No description provided for @petTaxiRidesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your Pet Taxi rides'**
  String get petTaxiRidesLoading;

  /// No description provided for @petTaxiRidesLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rides could not be loaded'**
  String get petTaxiRidesLoadErrorTitle;

  /// No description provided for @petTaxiRidesLoadErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again. Your bookings have not been changed.'**
  String get petTaxiRidesLoadErrorDescription;

  /// No description provided for @petTaxiSignInRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your rides'**
  String get petTaxiSignInRequiredTitle;

  /// No description provided for @petTaxiSignInRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'Your Pet Taxi bookings are available after you sign in.'**
  String get petTaxiSignInRequiredDescription;

  /// No description provided for @petTaxiProviderLabel.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get petTaxiProviderLabel;

  /// No description provided for @petTaxiProviderFallback.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi provider'**
  String get petTaxiProviderFallback;

  /// No description provided for @petTaxiDestinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get petTaxiDestinationLabel;

  /// No description provided for @petTaxiScheduleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Schedule unavailable'**
  String get petTaxiScheduleUnavailable;

  /// No description provided for @petTaxiPriceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Price pending'**
  String get petTaxiPriceUnavailable;

  /// No description provided for @petTaxiStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Request pending'**
  String get petTaxiStatusPending;

  /// No description provided for @petTaxiStatusAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get petTaxiStatusAwaitingPayment;

  /// No description provided for @petTaxiStatusConfirmedPaid.
  ///
  /// In en, this message translates to:
  /// **'Confirmed and paid'**
  String get petTaxiStatusConfirmedPaid;

  /// No description provided for @petTaxiStatusPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get petTaxiStatusPaymentFailed;

  /// No description provided for @petTaxiStatusRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund pending'**
  String get petTaxiStatusRefundPending;

  /// No description provided for @petTaxiStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get petTaxiStatusRefunded;

  /// No description provided for @petTaxiStatusDriverOnTheWay.
  ///
  /// In en, this message translates to:
  /// **'Driver on the way'**
  String get petTaxiStatusDriverOnTheWay;

  /// No description provided for @petTaxiStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Driver arrived'**
  String get petTaxiStatusArrived;

  /// No description provided for @petTaxiStatusPetPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Pet picked up'**
  String get petTaxiStatusPetPickedUp;

  /// No description provided for @petTaxiStatusOnTrip.
  ///
  /// In en, this message translates to:
  /// **'On the way'**
  String get petTaxiStatusOnTrip;

  /// No description provided for @petTaxiStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get petTaxiStatusCompleted;

  /// No description provided for @petTaxiStatusCancelledByUser.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by you'**
  String get petTaxiStatusCancelledByUser;

  /// No description provided for @petTaxiStatusCancelledByProvider.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by provider'**
  String get petTaxiStatusCancelledByProvider;

  /// No description provided for @petTaxiStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Status unavailable'**
  String get petTaxiStatusUnknown;

  /// No description provided for @petTaxiPaymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get petTaxiPaymentPaid;

  /// No description provided for @petTaxiPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment processing'**
  String get petTaxiPaymentPending;

  /// No description provided for @petTaxiPaymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get petTaxiPaymentFailed;

  /// No description provided for @petTaxiPaymentRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get petTaxiPaymentRefunded;

  /// No description provided for @petTaxiPaymentUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get petTaxiPaymentUnpaid;

  /// No description provided for @webSubscriptionPaymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment is temporarily unavailable'**
  String get webSubscriptionPaymentUnavailable;

  /// No description provided for @webSubscriptionCatalogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Secure payment prices could not be loaded. Check your connection and try again.'**
  String get webSubscriptionCatalogLoadFailed;

  /// No description provided for @webSubscriptionCatalogUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Sign in to load subscription prices and continue securely.'**
  String get webSubscriptionCatalogUnauthenticated;

  /// No description provided for @webSubscriptionCatalogFunctionNotFound.
  ///
  /// In en, this message translates to:
  /// **'The secure payment service is not available in this app version. Please refresh and try again.'**
  String get webSubscriptionCatalogFunctionNotFound;

  /// No description provided for @webSubscriptionCatalogConfigurationMissing.
  ///
  /// In en, this message translates to:
  /// **'Secure payment configuration is temporarily unavailable. Please try again later.'**
  String get webSubscriptionCatalogConfigurationMissing;

  /// No description provided for @webSubscriptionCatalogNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'The secure payment service could not be reached. Check your connection and retry.'**
  String get webSubscriptionCatalogNetworkFailed;

  /// No description provided for @webSubscriptionCatalogMalformed.
  ///
  /// In en, this message translates to:
  /// **'The secure payment service returned an invalid response. Please retry.'**
  String get webSubscriptionCatalogMalformed;

  /// No description provided for @webSubscriptionThirtyDayAccess.
  ///
  /// In en, this message translates to:
  /// **'30 days of subscription access'**
  String get webSubscriptionThirtyDayAccess;

  /// No description provided for @webSubscriptionContinueSecurePayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to secure payment'**
  String get webSubscriptionContinueSecurePayment;

  /// No description provided for @webSubscriptionPaymentTerms.
  ///
  /// In en, this message translates to:
  /// **'One-time payment for 30 days of access. No automatic card renewal.'**
  String get webSubscriptionPaymentTerms;

  /// No description provided for @webSubscriptionIsbankSecurePayment.
  ///
  /// In en, this message translates to:
  /// **'Secure payment with İş Bank • 30-day access • No automatic renewal'**
  String get webSubscriptionIsbankSecurePayment;

  /// No description provided for @webSubscriptionCheckoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Secure checkout could not be started. Please try again.'**
  String get webSubscriptionCheckoutFailed;

  /// No description provided for @webSubscriptionVerifyingTitle.
  ///
  /// In en, this message translates to:
  /// **'Verifying your payment'**
  String get webSubscriptionVerifyingTitle;

  /// No description provided for @webSubscriptionVerifyingMessage.
  ///
  /// In en, this message translates to:
  /// **'Please wait while the bank payment is verified securely.'**
  String get webSubscriptionVerifyingMessage;

  /// No description provided for @webSubscriptionSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscription activated'**
  String get webSubscriptionSuccessTitle;

  /// No description provided for @webSubscriptionSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment was verified and your 30-day subscription access is active.'**
  String get webSubscriptionSuccessMessage;

  /// No description provided for @webSubscriptionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be verified'**
  String get webSubscriptionFailedTitle;

  /// No description provided for @webSubscriptionFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your subscription was not activated. No unverified payment can grant access.'**
  String get webSubscriptionFailedMessage;

  /// No description provided for @webSubscriptionCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get webSubscriptionCancelledTitle;

  /// No description provided for @webSubscriptionCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'The payment was cancelled and your subscription was not changed.'**
  String get webSubscriptionCancelledMessage;

  /// No description provided for @webSubscriptionPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment is still processing'**
  String get webSubscriptionPendingTitle;

  /// No description provided for @webSubscriptionPendingMessage.
  ///
  /// In en, this message translates to:
  /// **'The bank has not completed verification yet. This page will check again automatically.'**
  String get webSubscriptionPendingMessage;

  /// No description provided for @chatError.
  ///
  /// In en, this message translates to:
  /// **'Chat error: {error}'**
  String chatError(Object error);

  /// No description provided for @bankAccountSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank Account'**
  String get bankAccountSettingsTitle;

  /// No description provided for @bankAccountSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This account will be used when PetSupo sends your business earnings.'**
  String get bankAccountSettingsSubtitle;

  /// No description provided for @bankAccountInfoNotice.
  ///
  /// In en, this message translates to:
  /// **'Please make sure the account holder and IBAN exactly match your official bank account. Incorrect information may delay payouts.'**
  String get bankAccountInfoNotice;

  /// No description provided for @bankAccountSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Details'**
  String get bankAccountSectionTitle;

  /// No description provided for @bankAccountHolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Account Holder'**
  String get bankAccountHolderLabel;

  /// No description provided for @bankAccountBankNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankAccountBankNameLabel;

  /// No description provided for @bankAccountIbanLabel.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get bankAccountIbanLabel;

  /// No description provided for @bankAccountBillingInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing Information (optional)'**
  String get bankAccountBillingInfoLabel;

  /// No description provided for @bankAccountIbanInvalid.
  ///
  /// In en, this message translates to:
  /// **'IBAN must start with TR followed by 24 digits.'**
  String get bankAccountIbanInvalid;

  /// No description provided for @bankAccountSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Bank account information saved.'**
  String get bankAccountSaveSuccess;

  /// No description provided for @diagnosticsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsSectionTitle;

  /// No description provided for @diagnosticsSectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Internal diagnostics tools for queue inspection and upload testing.'**
  String get diagnosticsSectionDescription;

  /// No description provided for @diagnosticsThrowButton.
  ///
  /// In en, this message translates to:
  /// **'Throw'**
  String get diagnosticsThrowButton;

  /// No description provided for @diagnosticsTestButton.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get diagnosticsTestButton;

  /// No description provided for @diagnosticsUploadButton.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get diagnosticsUploadButton;

  /// No description provided for @diagnosticsRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get diagnosticsRefreshButton;

  /// No description provided for @diagnosticsClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diagnosticsClearButton;

  /// No description provided for @dogCardAgeWithBreed.
  ///
  /// In en, this message translates to:
  /// **'{age}y • {breed}'**
  String dogCardAgeWithBreed(Object age, Object breed);

  /// No description provided for @dogCardAgeYears.
  ///
  /// In en, this message translates to:
  /// **'{age}y'**
  String dogCardAgeYears(Object age);

  /// No description provided for @dogCardVaccines.
  ///
  /// In en, this message translates to:
  /// **'{count} vaccines'**
  String dogCardVaccines(int count);

  /// No description provided for @dogParkPremiumMembersOnly.
  ///
  /// In en, this message translates to:
  /// **'This park is available for Premium members only.'**
  String get dogParkPremiumMembersOnly;

  /// No description provided for @favoritesExplorePlaymates.
  ///
  /// In en, this message translates to:
  /// **'Go explore Playmates 💛'**
  String get favoritesExplorePlaymates;

  /// No description provided for @vetServicesAvailableAfterLogin.
  ///
  /// In en, this message translates to:
  /// **'Vet services available after login'**
  String get vetServicesAvailableAfterLogin;

  /// No description provided for @loadingAccount.
  ///
  /// In en, this message translates to:
  /// **'Loading account...'**
  String get loadingAccount;

  /// No description provided for @noNotificationsForGuest.
  ///
  /// In en, this message translates to:
  /// **'No notifications for Guest'**
  String get noNotificationsForGuest;

  /// No description provided for @loginForNotifications.
  ///
  /// In en, this message translates to:
  /// **'Login to receive updates and alerts'**
  String get loginForNotifications;

  /// No description provided for @offerDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get offerDetailsTitle;

  /// No description provided for @offerDiscountOffLabel.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get offerDiscountOffLabel;

  /// No description provided for @offerUseCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Use code:'**
  String get offerUseCodeLabel;

  /// No description provided for @offerUseThisOffer.
  ///
  /// In en, this message translates to:
  /// **'Use This Offer'**
  String get offerUseThisOffer;

  /// No description provided for @playdateScheduledAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Playdate will be scheduled at:'**
  String get playdateScheduledAtLabel;

  /// No description provided for @continueToScheduling.
  ///
  /// In en, this message translates to:
  /// **'Continue to scheduling'**
  String get continueToScheduling;

  /// No description provided for @orderCancellationTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Cancellation'**
  String get orderCancellationTitle;

  /// No description provided for @preShipmentCancellationAvailable.
  ///
  /// In en, this message translates to:
  /// **'This order has not been shipped and can still be cancelled.'**
  String get preShipmentCancellationAvailable;

  /// No description provided for @cancelOrderButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrderButton;

  /// No description provided for @cancelOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order?'**
  String get cancelOrderTitle;

  /// No description provided for @cancelOrderConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order? The order has not been shipped yet.'**
  String get cancelOrderConfirmation;

  /// No description provided for @cancelOrderRefundNotice.
  ///
  /// In en, this message translates to:
  /// **'After cancellation, your payment will be refunded.'**
  String get cancelOrderRefundNotice;

  /// No description provided for @cancellationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for cancellation'**
  String get cancellationReasonLabel;

  /// No description provided for @cancelReasonOrderedByMistake.
  ///
  /// In en, this message translates to:
  /// **'Ordered by mistake'**
  String get cancelReasonOrderedByMistake;

  /// No description provided for @cancelReasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'Changed my mind'**
  String get cancelReasonChangedMind;

  /// No description provided for @cancelReasonDuplicateOrder.
  ///
  /// In en, this message translates to:
  /// **'Duplicate order'**
  String get cancelReasonDuplicateOrder;

  /// No description provided for @cancelReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cancelReasonOther;

  /// No description provided for @cancellationReasonDetailsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason details'**
  String get cancellationReasonDetailsLabel;

  /// No description provided for @cancellationRefundProcessing.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled. Your refund is processing.'**
  String get cancellationRefundProcessing;

  /// No description provided for @cancellationShipmentAlreadyStarted.
  ///
  /// In en, this message translates to:
  /// **'This order can no longer be cancelled because shipment has started.'**
  String get cancellationShipmentAlreadyStarted;

  /// No description provided for @cancelOrderFailed.
  ///
  /// In en, this message translates to:
  /// **'The order could not be cancelled. Please try again.'**
  String get cancelOrderFailed;

  /// No description provided for @cancellationRefundProcessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancellation requested · Refund processing'**
  String get cancellationRefundProcessingStatus;

  /// No description provided for @cancellationRefundFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Cancellation refund needs attention'**
  String get cancellationRefundFailedStatus;

  /// No description provided for @orderCancelledRefundCompleted.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled · Refund completed'**
  String get orderCancelledRefundCompleted;

  /// No description provided for @foundPetDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Found Pet Details'**
  String get foundPetDetailsTitle;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get viewOnMap;

  /// No description provided for @contactReporter.
  ///
  /// In en, this message translates to:
  /// **'Contact Reporter'**
  String get contactReporter;

  /// No description provided for @foundPetReportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Found pet reported successfully!'**
  String get foundPetReportedSuccess;

  /// No description provided for @errorSubmittingReport.
  ///
  /// In en, this message translates to:
  /// **'Error submitting report: {error}'**
  String errorSubmittingReport(Object error);

  /// No description provided for @tapToSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to select image'**
  String get tapToSelectImage;

  /// No description provided for @foundPetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help found pets return home safely'**
  String get foundPetsSubtitle;

  /// No description provided for @searchByNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchByNameHint;

  /// No description provided for @noFoundPetsReportedYet.
  ///
  /// In en, this message translates to:
  /// **'No found pets reported yet'**
  String get noFoundPetsReportedYet;

  /// No description provided for @reportedFoundPetsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Reported found pets will appear here'**
  String get reportedFoundPetsAppearHere;

  /// No description provided for @lostPetDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Lost Pet Details'**
  String get lostPetDetailsTitle;

  /// No description provided for @havePetInformationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Have information about this pet?'**
  String get havePetInformationPrompt;

  /// No description provided for @callOwner.
  ///
  /// In en, this message translates to:
  /// **'Call Owner'**
  String get callOwner;

  /// No description provided for @emailOwner.
  ///
  /// In en, this message translates to:
  /// **'Email Owner'**
  String get emailOwner;

  /// No description provided for @lostPetReportedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Lost pet reported successfully!'**
  String get lostPetReportedSuccess;

  /// No description provided for @lostPetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help lost pets find their way home'**
  String get lostPetsSubtitle;

  /// No description provided for @noLostPetsReportedYet.
  ///
  /// In en, this message translates to:
  /// **'No lost pets reported yet'**
  String get noLostPetsReportedYet;

  /// No description provided for @reportedLostPetsAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Reported lost pets will appear here'**
  String get reportedLostPetsAppearHere;

  /// No description provided for @searchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search users...'**
  String get searchUsersHint;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @searchPetsAndUsers.
  ///
  /// In en, this message translates to:
  /// **'Search pets & users'**
  String get searchPetsAndUsers;

  /// No description provided for @findPetLoversNearby.
  ///
  /// In en, this message translates to:
  /// **'Find pet lovers around you'**
  String get findPetLoversNearby;

  /// No description provided for @selectAtLeastOnePhotoOrVideo.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one photo/video'**
  String get selectAtLeastOnePhotoOrVideo;

  /// No description provided for @errorCreatingPost.
  ///
  /// In en, this message translates to:
  /// **'Error creating post: {error}'**
  String errorCreatingPost(Object error);

  /// No description provided for @createPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get createPostTitle;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @addPhotosOrVideos.
  ///
  /// In en, this message translates to:
  /// **'Add photos/videos'**
  String get addPhotosOrVideos;

  /// No description provided for @writeSomethingHint.
  ///
  /// In en, this message translates to:
  /// **'Write something...'**
  String get writeSomethingHint;

  /// No description provided for @replyHint.
  ///
  /// In en, this message translates to:
  /// **'Reply...'**
  String get replyHint;

  /// No description provided for @replySent.
  ///
  /// In en, this message translates to:
  /// **'Reply sent'**
  String get replySent;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @videoStoriesComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Video stories are coming soon'**
  String get videoStoriesComingSoon;

  /// No description provided for @petploreTitle.
  ///
  /// In en, this message translates to:
  /// **'Petplore'**
  String get petploreTitle;

  /// No description provided for @explorePetMoments.
  ///
  /// In en, this message translates to:
  /// **'Explore pet moments'**
  String get explorePetMoments;

  /// No description provided for @followersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Followers'**
  String followersCount(int count);

  /// No description provided for @followingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Following'**
  String followingCount(int count);

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @myPosts.
  ///
  /// In en, this message translates to:
  /// **'My Posts'**
  String get myPosts;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login required'**
  String get loginRequired;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String genericError(Object error);

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsError.
  ///
  /// In en, this message translates to:
  /// **'Comments error: {error}'**
  String commentsError(Object error);

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noCommentsYet;

  /// No description provided for @writeCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment...'**
  String get writeCommentHint;

  /// No description provided for @postsTitle.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get postsTitle;

  /// No description provided for @storyUploaded.
  ///
  /// In en, this message translates to:
  /// **'Story uploaded'**
  String get storyUploaded;

  /// No description provided for @storyUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Story upload failed: {error}'**
  String storyUploadFailed(Object error);

  /// No description provided for @addStory.
  ///
  /// In en, this message translates to:
  /// **'Add Story'**
  String get addStory;

  /// No description provided for @storyDurationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Share a pet moment that lasts 24h'**
  String get storyDurationPrompt;

  /// No description provided for @seeWhosNearby.
  ///
  /// In en, this message translates to:
  /// **'See who’s nearby 👀!'**
  String get seeWhosNearby;

  /// No description provided for @telegramLab.
  ///
  /// In en, this message translates to:
  /// **'Telegram Lab'**
  String get telegramLab;

  /// No description provided for @telegramBotApiTest.
  ///
  /// In en, this message translates to:
  /// **'Telegram Bot API Test'**
  String get telegramBotApiTest;

  /// No description provided for @telegramTestInstructions.
  ///
  /// In en, this message translates to:
  /// **'Press the button below to send a test message.'**
  String get telegramTestInstructions;

  /// No description provided for @sendTelegramMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Telegram Message'**
  String get sendTelegramMessage;

  /// No description provided for @telegramUsers.
  ///
  /// In en, this message translates to:
  /// **'Telegram Users'**
  String get telegramUsers;

  /// No description provided for @termsLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: May 09, 2025'**
  String get termsLastUpdated;

  /// No description provided for @termsIntroductionTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Introduction'**
  String get termsIntroductionTitle;

  /// No description provided for @termsIntroductionBody.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PetSupo! By signing up, you agree to these Terms and Conditions. This app is designed to help you find playmates for your dogs, connect with other pet owners, and access pet-related services. These terms govern your use of the app and services provided by PetSupo.'**
  String get termsIntroductionBody;

  /// No description provided for @termsResponsibilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'2. User Responsibilities'**
  String get termsResponsibilitiesTitle;

  /// No description provided for @termsResponsibilitiesBody.
  ///
  /// In en, this message translates to:
  /// **'- You must be at least 13 years old to use this app.\n- You are responsible for maintaining the confidentiality of your account and password.\n- You agree not to use the app for any unlawful or prohibited activities.\n- You must provide accurate and up-to-date information during registration.'**
  String get termsResponsibilitiesBody;

  /// No description provided for @termsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'3. Data Collection and Privacy'**
  String get termsPrivacyTitle;

  /// No description provided for @termsPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'We collect personal data such as your username, email, location, and pet information to provide our services. In accordance with the Turkish Personal Data Protection Law (KVKK No. 6698) and international laws (e.g., GDPR), we:\n- Obtain explicit consent before collecting or processing your data.\n- Use your data only for the purposes stated (e.g., finding playmates, providing location-based services).\n- Implement security measures to protect your data.\n- Allow you to access, correct, or delete your data upon request. To exercise your rights, contact us at info@petsupo.com.'**
  String get termsPrivacyBody;

  /// No description provided for @termsUserContentTitle.
  ///
  /// In en, this message translates to:
  /// **'4. User Content'**
  String get termsUserContentTitle;

  /// No description provided for @termsUserContentBody.
  ///
  /// In en, this message translates to:
  /// **'- You retain ownership of any content you upload (e.g., photos, descriptions).\n- By uploading content, you grant PetSupo a non-exclusive, royalty-free license to use, display, and distribute your content within the app.\n- You must not upload content that is illegal, offensive, or violates the rights of others.'**
  String get termsUserContentBody;

  /// No description provided for @termsLiabilityTitle.
  ///
  /// In en, this message translates to:
  /// **'5. Limitation of Liability'**
  String get termsLiabilityTitle;

  /// No description provided for @termsLiabilityBody.
  ///
  /// In en, this message translates to:
  /// **'PetSupo is not liable for any damages arising from your use of the app, including but not limited to interactions with other users or pets. We do not guarantee the accuracy of information provided by other users.'**
  String get termsLiabilityBody;

  /// No description provided for @termsGoverningLawTitle.
  ///
  /// In en, this message translates to:
  /// **'6. Governing Law'**
  String get termsGoverningLawTitle;

  /// No description provided for @termsGoverningLawBody.
  ///
  /// In en, this message translates to:
  /// **'These Terms and Conditions are governed by the laws of the Republic of Turkey. Any disputes arising from your use of the app will be resolved in the courts of Istanbul, Turkey, unless otherwise required by international law (e.g., GDPR for EU users).'**
  String get termsGoverningLawBody;

  /// No description provided for @termsChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'7. Changes to Terms'**
  String get termsChangesTitle;

  /// No description provided for @termsChangesBody.
  ///
  /// In en, this message translates to:
  /// **'We may update these Terms and Conditions from time to time. You will be notified of significant changes via email or in-app notifications. Continued use of the app after changes constitutes your acceptance of the new terms.'**
  String get termsChangesBody;

  /// No description provided for @termsContactTitle.
  ///
  /// In en, this message translates to:
  /// **'7. Contact'**
  String get termsContactTitle;

  /// No description provided for @termsContactBody.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions or concerns about these Terms and Conditions, please contact us at info@petsupo.com.'**
  String get termsContactBody;

  /// No description provided for @pendingBusinessApprovals.
  ///
  /// In en, this message translates to:
  /// **'Pending Business Approvals'**
  String get pendingBusinessApprovals;

  /// No description provided for @invalidRequest.
  ///
  /// In en, this message translates to:
  /// **'Invalid request'**
  String get invalidRequest;

  /// No description provided for @noPendingBusinessRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending business requests'**
  String get noPendingBusinessRequests;

  /// No description provided for @riskCount.
  ///
  /// In en, this message translates to:
  /// **'{count} RISK'**
  String riskCount(Object count);

  /// No description provided for @verifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get verifiedLabel;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @businessApproved.
  ///
  /// In en, this message translates to:
  /// **'Business approved'**
  String get businessApproved;

  /// No description provided for @businessRejected.
  ///
  /// In en, this message translates to:
  /// **'Business rejected'**
  String get businessRejected;

  /// No description provided for @businessSuspended.
  ///
  /// In en, this message translates to:
  /// **'Business suspended'**
  String get businessSuspended;

  /// No description provided for @businessRestored.
  ///
  /// In en, this message translates to:
  /// **'Business restored'**
  String get businessRestored;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String actionFailed(Object error);

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @dashboardError.
  ///
  /// In en, this message translates to:
  /// **'Dashboard Error:\n{error}'**
  String dashboardError(Object error);

  /// No description provided for @platformOverview.
  ///
  /// In en, this message translates to:
  /// **'Platform Overview'**
  String get platformOverview;

  /// No description provided for @adminActivity.
  ///
  /// In en, this message translates to:
  /// **'Admin Activity'**
  String get adminActivity;

  /// No description provided for @developerTools.
  ///
  /// In en, this message translates to:
  /// **'Developer Tools'**
  String get developerTools;

  /// No description provided for @testTelegramBotApi.
  ///
  /// In en, this message translates to:
  /// **'Test Telegram Bot API'**
  String get testTelegramBotApi;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Crash reports & startup diagnostics'**
  String get diagnosticsDescription;

  /// No description provided for @telegramUsersDescription.
  ///
  /// In en, this message translates to:
  /// **'View connected Telegram users'**
  String get telegramUsersDescription;

  /// No description provided for @adminActivityError.
  ///
  /// In en, this message translates to:
  /// **'Activity error:\n{error}'**
  String adminActivityError(Object error);

  /// No description provided for @noAdminActivity.
  ///
  /// In en, this message translates to:
  /// **'No admin activity yet'**
  String get noAdminActivity;

  /// No description provided for @diagnosticReport.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Report'**
  String get diagnosticReport;

  /// No description provided for @diagnosticReportNotFound.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic report not found'**
  String get diagnosticReportNotFound;

  /// No description provided for @reopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get reopen;

  /// No description provided for @resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolve;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @stackTrace.
  ///
  /// In en, this message translates to:
  /// **'Stack Trace'**
  String get stackTrace;

  /// No description provided for @breadcrumbsLogs.
  ///
  /// In en, this message translates to:
  /// **'Breadcrumbs / Logs'**
  String get breadcrumbsLogs;

  /// No description provided for @noLogs.
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get noLogs;

  /// No description provided for @rawJson.
  ///
  /// In en, this message translates to:
  /// **'Raw JSON'**
  String get rawJson;

  /// No description provided for @diagnosticReports.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic Reports'**
  String get diagnosticReports;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @noDiagnosticReports.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic reports'**
  String get noDiagnosticReports;

  /// No description provided for @reasonValue.
  ///
  /// In en, this message translates to:
  /// **'Reason: {value}'**
  String reasonValue(Object value);

  /// No description provided for @featureValue.
  ///
  /// In en, this message translates to:
  /// **'Feature: {value}'**
  String featureValue(Object value);

  /// No description provided for @platformValue.
  ///
  /// In en, this message translates to:
  /// **'Platform: {value}'**
  String platformValue(Object value);

  /// No description provided for @versionValue.
  ///
  /// In en, this message translates to:
  /// **'Version: {value}'**
  String versionValue(Object value);

  /// No description provided for @receivedValue.
  ///
  /// In en, this message translates to:
  /// **'Received: {value}'**
  String receivedValue(Object value);

  /// No description provided for @messageValue.
  ///
  /// In en, this message translates to:
  /// **'Message: {value}'**
  String messageValue(Object value);

  /// No description provided for @createdValue.
  ///
  /// In en, this message translates to:
  /// **'Created: {value}'**
  String createdValue(Object value);

  /// No description provided for @adminActions.
  ///
  /// In en, this message translates to:
  /// **'Admin Actions'**
  String get adminActions;

  /// No description provided for @moderationCase.
  ///
  /// In en, this message translates to:
  /// **'Moderation Case'**
  String get moderationCase;

  /// No description provided for @targetValue.
  ///
  /// In en, this message translates to:
  /// **'Target: {value}'**
  String targetValue(Object value);

  /// No description provided for @reportsCount.
  ///
  /// In en, this message translates to:
  /// **'Reports: {count}'**
  String reportsCount(Object count);

  /// No description provided for @riskScoreValue.
  ///
  /// In en, this message translates to:
  /// **'Risk Score: {value}'**
  String riskScoreValue(Object value);

  /// No description provided for @priorityValue.
  ///
  /// In en, this message translates to:
  /// **'Priority: {value}'**
  String priorityValue(Object value);

  /// No description provided for @firestoreError.
  ///
  /// In en, this message translates to:
  /// **'Firestore error: {error}'**
  String firestoreError(Object error);

  /// No description provided for @refundReview.
  ///
  /// In en, this message translates to:
  /// **'Refund Review'**
  String get refundReview;

  /// No description provided for @appointmentIdValue.
  ///
  /// In en, this message translates to:
  /// **'Appointment ID: {value}'**
  String appointmentIdValue(Object value);

  /// No description provided for @paymentStatusValue.
  ///
  /// In en, this message translates to:
  /// **'Payment Status: {value}'**
  String paymentStatusValue(Object value);

  /// No description provided for @refundStatusValue.
  ///
  /// In en, this message translates to:
  /// **'Refund Status: {value}'**
  String refundStatusValue(Object value);

  /// No description provided for @appointmentTimeValue.
  ///
  /// In en, this message translates to:
  /// **'Appointment Time: {value}'**
  String appointmentTimeValue(Object value);

  /// No description provided for @cancellationTimeValue.
  ///
  /// In en, this message translates to:
  /// **'Cancellation Time: {value}'**
  String cancellationTimeValue(Object value);

  /// No description provided for @hoursBeforeAppointmentValue.
  ///
  /// In en, this message translates to:
  /// **'Hours Before Appointment: {value}'**
  String hoursBeforeAppointmentValue(Object value);

  /// No description provided for @businessValue.
  ///
  /// In en, this message translates to:
  /// **'Business: {value}'**
  String businessValue(Object value);

  /// No description provided for @userValue.
  ///
  /// In en, this message translates to:
  /// **'User: {value}'**
  String userValue(Object value);

  /// No description provided for @petValue.
  ///
  /// In en, this message translates to:
  /// **'Pet: {value}'**
  String petValue(Object value);

  /// No description provided for @amountPaidValue.
  ///
  /// In en, this message translates to:
  /// **'Amount Paid: {value}'**
  String amountPaidValue(Object value);

  /// No description provided for @refundReasonValue.
  ///
  /// In en, this message translates to:
  /// **'Refund Reason: {value}'**
  String refundReasonValue(Object value);

  /// No description provided for @refundErrorValue.
  ///
  /// In en, this message translates to:
  /// **'Refund Error: {value}'**
  String refundErrorValue(Object value);

  /// No description provided for @approveRefund.
  ///
  /// In en, this message translates to:
  /// **'Approve Refund'**
  String get approveRefund;

  /// No description provided for @rejectRefund.
  ///
  /// In en, this message translates to:
  /// **'Reject Refund'**
  String get rejectRefund;

  /// No description provided for @refundReviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Refund review failed: {error}'**
  String refundReviewFailed(Object error);

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @refundQueueError.
  ///
  /// In en, this message translates to:
  /// **'Refund queue error: {error}'**
  String refundQueueError(Object error);

  /// No description provided for @refundRequests.
  ///
  /// In en, this message translates to:
  /// **'Refund Requests'**
  String get refundRequests;

  /// No description provided for @noPendingRefundRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending refund requests'**
  String get noPendingRefundRequests;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @appointmentValue.
  ///
  /// In en, this message translates to:
  /// **'Appointment: {value}'**
  String appointmentValue(Object value);

  /// No description provided for @cancelledValue.
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {value}'**
  String cancelledValue(Object value);

  /// No description provided for @amountValue.
  ///
  /// In en, this message translates to:
  /// **'Amount: {value}'**
  String amountValue(Object value);

  /// No description provided for @statusValue.
  ///
  /// In en, this message translates to:
  /// **'Status: {value}'**
  String statusValue(Object value);

  /// No description provided for @confirmViolation.
  ///
  /// In en, this message translates to:
  /// **'Confirm Violation'**
  String get confirmViolation;

  /// No description provided for @markClean.
  ///
  /// In en, this message translates to:
  /// **'Mark Clean'**
  String get markClean;

  /// No description provided for @businessMetrics.
  ///
  /// In en, this message translates to:
  /// **'Business Metrics'**
  String get businessMetrics;

  /// No description provided for @businessSearch.
  ///
  /// In en, this message translates to:
  /// **'Business Search'**
  String get businessSearch;

  /// No description provided for @searchBusinessNameHint.
  ///
  /// In en, this message translates to:
  /// **'Search business name...'**
  String get searchBusinessNameHint;

  /// No description provided for @suspendedLabel.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspendedLabel;

  /// No description provided for @filterByStatus.
  ///
  /// In en, this message translates to:
  /// **'Filter by status'**
  String get filterByStatus;

  /// No description provided for @complaintCenter.
  ///
  /// In en, this message translates to:
  /// **'Complaint Center'**
  String get complaintCenter;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @noComplaintsFound.
  ///
  /// In en, this message translates to:
  /// **'No complaints found'**
  String get noComplaintsFound;

  /// No description provided for @categoryValue.
  ///
  /// In en, this message translates to:
  /// **'Category: {value}'**
  String categoryValue(Object value);

  /// No description provided for @complaintDetail.
  ///
  /// In en, this message translates to:
  /// **'Complaint Detail'**
  String get complaintDetail;

  /// No description provided for @severityValue.
  ///
  /// In en, this message translates to:
  /// **'Severity: {value}'**
  String severityValue(Object value);

  /// No description provided for @evidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @fraudAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Fraud Analytics'**
  String get fraudAnalytics;

  /// No description provided for @errorLoadingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Error loading analytics'**
  String get errorLoadingAnalytics;

  /// No description provided for @adminMapMonitor.
  ///
  /// In en, this message translates to:
  /// **'Admin Map Monitor'**
  String get adminMapMonitor;

  /// No description provided for @platformMetrics.
  ///
  /// In en, this message translates to:
  /// **'Platform Metrics'**
  String get platformMetrics;

  /// No description provided for @noMetricsData.
  ///
  /// In en, this message translates to:
  /// **'No metrics data'**
  String get noMetricsData;

  /// No description provided for @lastUpdatedValue.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {value}'**
  String lastUpdatedValue(Object value);

  /// No description provided for @revenueTitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenueTitle;

  /// No description provided for @noRevenueData.
  ///
  /// In en, this message translates to:
  /// **'No revenue data'**
  String get noRevenueData;

  /// No description provided for @auditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get auditLogs;

  /// No description provided for @verifiedValue.
  ///
  /// In en, this message translates to:
  /// **'Verified: {value}'**
  String verifiedValue(Object value);

  /// No description provided for @documentNumberValue.
  ///
  /// In en, this message translates to:
  /// **'Document no: {value}'**
  String documentNumberValue(Object value);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @petTaxiDocument.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi Document'**
  String get petTaxiDocument;

  /// No description provided for @openPdf.
  ///
  /// In en, this message translates to:
  /// **'Open PDF'**
  String get openPdf;

  /// No description provided for @suspendedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Suspended Businesses'**
  String get suspendedBusinesses;

  /// No description provided for @noDataReceived.
  ///
  /// In en, this message translates to:
  /// **'No data received'**
  String get noDataReceived;

  /// No description provided for @noSuspendedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'No suspended businesses'**
  String get noSuspendedBusinesses;

  /// No description provided for @subscriptionDetails.
  ///
  /// In en, this message translates to:
  /// **'Subscription Details'**
  String get subscriptionDetails;

  /// No description provided for @planValue.
  ///
  /// In en, this message translates to:
  /// **'Plan: {value}'**
  String planValue(Object value);

  /// No description provided for @priceValue.
  ///
  /// In en, this message translates to:
  /// **'Price: {value}'**
  String priceValue(Object value);

  /// No description provided for @cancelSubscription.
  ///
  /// In en, this message translates to:
  /// **'Cancel Subscription'**
  String get cancelSubscription;

  /// No description provided for @expireNow.
  ///
  /// In en, this message translates to:
  /// **'Expire Now'**
  String get expireNow;

  /// No description provided for @makePremium.
  ///
  /// In en, this message translates to:
  /// **'⭐ Make Premium'**
  String get makePremium;

  /// No description provided for @upgradeToPartner.
  ///
  /// In en, this message translates to:
  /// **'👑 Upgrade to PetSupo Partner'**
  String get upgradeToPartner;

  /// No description provided for @downgradeToPremium.
  ///
  /// In en, this message translates to:
  /// **'⬇ Downgrade to Premium'**
  String get downgradeToPremium;

  /// No description provided for @extendThirtyDays.
  ///
  /// In en, this message translates to:
  /// **'Extend 30 Days'**
  String get extendThirtyDays;

  /// No description provided for @subscriptionManagement.
  ///
  /// In en, this message translates to:
  /// **'Subscription Management'**
  String get subscriptionManagement;

  /// No description provided for @searchUserIdHint.
  ///
  /// In en, this message translates to:
  /// **'Search userId...'**
  String get searchUserIdHint;

  /// No description provided for @loadingSubscription.
  ///
  /// In en, this message translates to:
  /// **'Loading subscription...'**
  String get loadingSubscription;

  /// No description provided for @feedbackDetail.
  ///
  /// In en, this message translates to:
  /// **'Feedback Detail'**
  String get feedbackDetail;

  /// No description provided for @ratingValue.
  ///
  /// In en, this message translates to:
  /// **'Rating: {value}'**
  String ratingValue(Object value);

  /// No description provided for @contextValue.
  ///
  /// In en, this message translates to:
  /// **'Context: {value}'**
  String contextValue(Object value);

  /// No description provided for @messageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageLabel;

  /// No description provided for @userFeedback.
  ///
  /// In en, this message translates to:
  /// **'User Feedback'**
  String get userFeedback;

  /// No description provided for @noPayoutsFound.
  ///
  /// In en, this message translates to:
  /// **'No payouts found'**
  String get noPayoutsFound;

  /// No description provided for @payoutManagement.
  ///
  /// In en, this message translates to:
  /// **'Payout Management'**
  String get payoutManagement;

  /// No description provided for @readyLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get readyLabel;

  /// No description provided for @searchPayoutsHint.
  ///
  /// In en, this message translates to:
  /// **'Search order, seller, buyer, ref...'**
  String get searchPayoutsHint;

  /// No description provided for @payoutMarkedReady.
  ///
  /// In en, this message translates to:
  /// **'Payout marked as ready'**
  String get payoutMarkedReady;

  /// No description provided for @confirmPayout.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payout'**
  String get confirmPayout;

  /// No description provided for @bankTransferReference.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer Reference'**
  String get bankTransferReference;

  /// No description provided for @bankReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'EFT / FAST / Bank Ref'**
  String get bankReferenceHint;

  /// No description provided for @payoutMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'Payout marked as paid'**
  String get payoutMarkedPaid;

  /// No description provided for @sellerValue.
  ///
  /// In en, this message translates to:
  /// **'Seller: {value}'**
  String sellerValue(Object value);

  /// No description provided for @buyerValue.
  ///
  /// In en, this message translates to:
  /// **'Buyer: {value}'**
  String buyerValue(Object value);

  /// No description provided for @referenceValue.
  ///
  /// In en, this message translates to:
  /// **'Ref: {value}'**
  String referenceValue(Object value);

  /// No description provided for @markReady.
  ///
  /// In en, this message translates to:
  /// **'Mark Ready'**
  String get markReady;

  /// No description provided for @markPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark Paid'**
  String get markPaid;

  /// No description provided for @openEntity.
  ///
  /// In en, this message translates to:
  /// **'Open {type}: {id}'**
  String openEntity(Object id, Object type);

  /// No description provided for @globalAdminSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search users, dogs, businesses, reports, complaints...'**
  String get globalAdminSearchHint;

  /// No description provided for @globalAdminSearch.
  ///
  /// In en, this message translates to:
  /// **'Global Admin Search'**
  String get globalAdminSearch;

  /// No description provided for @notAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated'**
  String get notAuthenticated;

  /// No description provided for @adoptionRequestNotFound.
  ///
  /// In en, this message translates to:
  /// **'Adoption request not found'**
  String get adoptionRequestNotFound;

  /// No description provided for @backToRequests.
  ///
  /// In en, this message translates to:
  /// **'Back to requests'**
  String get backToRequests;

  /// No description provided for @messageApplicant.
  ///
  /// In en, this message translates to:
  /// **'Message Applicant'**
  String get messageApplicant;

  /// No description provided for @unknownPet.
  ///
  /// In en, this message translates to:
  /// **'Unknown Pet'**
  String get unknownPet;

  /// No description provided for @adoptionRequest.
  ///
  /// In en, this message translates to:
  /// **'Adoption Request'**
  String get adoptionRequest;

  /// No description provided for @waitingForOwnerResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for owner response'**
  String get waitingForOwnerResponse;

  /// No description provided for @doneWithIcon.
  ///
  /// In en, this message translates to:
  /// **'✅ Done'**
  String get doneWithIcon;

  /// No description provided for @failedWithIcon.
  ///
  /// In en, this message translates to:
  /// **'❌ Failed: {error}'**
  String failedWithIcon(Object error);

  /// No description provided for @availablePets.
  ///
  /// In en, this message translates to:
  /// **'Available Pets'**
  String get availablePets;

  /// No description provided for @petsCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Pets could not be loaded.'**
  String get petsCouldNotBeLoaded;

  /// No description provided for @noPetsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No pets available'**
  String get noPetsAvailable;

  /// No description provided for @noImages.
  ///
  /// In en, this message translates to:
  /// **'No images'**
  String get noImages;

  /// No description provided for @viewAvailablePets.
  ///
  /// In en, this message translates to:
  /// **'View Available Pets'**
  String get viewAvailablePets;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @writeReviewFirst.
  ///
  /// In en, this message translates to:
  /// **'Please write a review first'**
  String get writeReviewFirst;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted'**
  String get reviewSubmitted;

  /// No description provided for @reviewExperienceHint.
  ///
  /// In en, this message translates to:
  /// **'Tell others about your experience'**
  String get reviewExperienceHint;

  /// No description provided for @submitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get submitReview;

  /// No description provided for @adoptionCenterDetails.
  ///
  /// In en, this message translates to:
  /// **'Adoption Center Details'**
  String get adoptionCenterDetails;

  /// No description provided for @adoptionServices.
  ///
  /// In en, this message translates to:
  /// **'Adoption Services'**
  String get adoptionServices;

  /// No description provided for @petTypes.
  ///
  /// In en, this message translates to:
  /// **'Pet Types'**
  String get petTypes;

  /// No description provided for @workingDays.
  ///
  /// In en, this message translates to:
  /// **'Working Days'**
  String get workingDays;

  /// No description provided for @vetCheckIncluded.
  ///
  /// In en, this message translates to:
  /// **'Vet Check Included'**
  String get vetCheckIncluded;

  /// No description provided for @homeVisitAvailable.
  ///
  /// In en, this message translates to:
  /// **'Home Visit Available'**
  String get homeVisitAvailable;

  /// No description provided for @transportSupport.
  ///
  /// In en, this message translates to:
  /// **'Transport Support'**
  String get transportSupport;

  /// No description provided for @fosterSupport.
  ///
  /// In en, this message translates to:
  /// **'Foster Support'**
  String get fosterSupport;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @logo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get logo;

  /// No description provided for @approvedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Approved Businesses'**
  String get approvedBusinesses;

  /// No description provided for @searchBusinessesHint.
  ///
  /// In en, this message translates to:
  /// **'Search businesses...'**
  String get searchBusinessesHint;

  /// No description provided for @noApprovedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'No approved businesses'**
  String get noApprovedBusinesses;

  /// No description provided for @basic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get basic;

  /// No description provided for @disclaimerAccepted.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer accepted'**
  String get disclaimerAccepted;

  /// No description provided for @mismatchDetected.
  ///
  /// In en, this message translates to:
  /// **'⚠ Mismatch detected'**
  String get mismatchDetected;

  /// No description provided for @languageCodeTr.
  ///
  /// In en, this message translates to:
  /// **'TR'**
  String get languageCodeTr;

  /// No description provided for @languageCodeEn.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageCodeEn;

  /// No description provided for @riskFlags.
  ///
  /// In en, this message translates to:
  /// **'Risk Flags'**
  String get riskFlags;

  /// No description provided for @noRiskFlags.
  ///
  /// In en, this message translates to:
  /// **'No risk flags'**
  String get noRiskFlags;

  /// No description provided for @adminNotes.
  ///
  /// In en, this message translates to:
  /// **'Admin Notes'**
  String get adminNotes;

  /// No description provided for @adminNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Add internal moderation notes...'**
  String get adminNotesHint;

  /// No description provided for @saveNotes.
  ///
  /// In en, this message translates to:
  /// **'Save Notes'**
  String get saveNotes;

  /// No description provided for @adminNotesSaved.
  ///
  /// In en, this message translates to:
  /// **'Admin notes saved ✅'**
  String get adminNotesSaved;

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(Object error);

  /// No description provided for @noQuickRepliesFound.
  ///
  /// In en, this message translates to:
  /// **'No quick replies found'**
  String get noQuickRepliesFound;

  /// No description provided for @quickReplies.
  ///
  /// In en, this message translates to:
  /// **'Quick Replies'**
  String get quickReplies;

  /// No description provided for @chatFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Chat failed to load'**
  String get chatFailedToLoad;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @typeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get typeMessageHint;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No requests'**
  String get noRequests;

  /// No description provided for @phoneValue.
  ///
  /// In en, this message translates to:
  /// **'Phone: {value}'**
  String phoneValue(Object value);

  /// No description provided for @genderValue.
  ///
  /// In en, this message translates to:
  /// **'Gender: {value}'**
  String genderValue(Object value);

  /// No description provided for @petStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'{name} status updated'**
  String petStatusUpdated(Object name);

  /// No description provided for @statusUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Status update failed: {error}'**
  String statusUpdateFailed(Object error);

  /// No description provided for @deletePetQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete pet?'**
  String get deletePetQuestion;

  /// No description provided for @deletePetConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? This action cannot be undone.'**
  String deletePetConfirmation(Object name);

  /// No description provided for @petDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String petDeleted(Object name);

  /// No description provided for @deleteFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailedWithError(Object error);

  /// No description provided for @searchPetsHint.
  ///
  /// In en, this message translates to:
  /// **'Search pets'**
  String get searchPetsHint;

  /// No description provided for @noAdoptablePetsYet.
  ///
  /// In en, this message translates to:
  /// **'No adoptable pets yet'**
  String get noAdoptablePetsYet;

  /// No description provided for @addAdoptablePetsDescription.
  ///
  /// In en, this message translates to:
  /// **'Add pets that are available for adoption and manage their status here.'**
  String get addAdoptablePetsDescription;

  /// No description provided for @failedToLoadPets.
  ///
  /// In en, this message translates to:
  /// **'Failed to load pets:\n{error}'**
  String failedToLoadPets(Object error);

  /// No description provided for @breedValue.
  ///
  /// In en, this message translates to:
  /// **'Breed: {value}'**
  String breedValue(Object value);

  /// No description provided for @ageValue.
  ///
  /// In en, this message translates to:
  /// **'Age: {value}'**
  String ageValue(Object value);

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @noAdoptionPetsYet.
  ///
  /// In en, this message translates to:
  /// **'No Adoption Pets Yet'**
  String get noAdoptionPetsYet;

  /// No description provided for @addPetsForAdoption.
  ///
  /// In en, this message translates to:
  /// **'Add pets that are available for adoption.'**
  String get addPetsForAdoption;

  /// No description provided for @editAdoptionCenter.
  ///
  /// In en, this message translates to:
  /// **'Edit Adoption Center'**
  String get editAdoptionCenter;

  /// No description provided for @pleaseAddCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Please add cover image'**
  String get pleaseAddCoverImage;

  /// No description provided for @addGalleryImages.
  ///
  /// In en, this message translates to:
  /// **'Add Gallery Images'**
  String get addGalleryImages;

  /// No description provided for @petNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Pet Name'**
  String get petNameLabel;

  /// No description provided for @ageMonthsLabel.
  ///
  /// In en, this message translates to:
  /// **'Age (months)'**
  String get ageMonthsLabel;

  /// No description provided for @visible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get visible;

  /// No description provided for @failedToSetCover.
  ///
  /// In en, this message translates to:
  /// **'Failed to set cover: {error}'**
  String failedToSetCover(Object error);

  /// No description provided for @uploadPetMedia.
  ///
  /// In en, this message translates to:
  /// **'Upload Pet Media'**
  String get uploadPetMedia;

  /// No description provided for @uploadedPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% uploaded'**
  String uploadedPercent(Object percent);

  /// No description provided for @noMediaYet.
  ///
  /// In en, this message translates to:
  /// **'No media yet'**
  String get noMediaYet;

  /// No description provided for @cover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get cover;

  /// No description provided for @adoptionCenterInfo.
  ///
  /// In en, this message translates to:
  /// **'Adoption Center Info'**
  String get adoptionCenterInfo;

  /// No description provided for @centerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Center name'**
  String get centerNameLabel;

  /// No description provided for @instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @saveCenterInfo.
  ///
  /// In en, this message translates to:
  /// **'Save Center Info'**
  String get saveCenterInfo;

  /// No description provided for @latestAdoptionApplications.
  ///
  /// In en, this message translates to:
  /// **'Latest adoption applications'**
  String get latestAdoptionApplications;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @tapForMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'Tap for more details'**
  String get tapForMoreDetails;

  /// No description provided for @setAvailable.
  ///
  /// In en, this message translates to:
  /// **'Set Available'**
  String get setAvailable;

  /// No description provided for @setReserved.
  ///
  /// In en, this message translates to:
  /// **'Set Reserved'**
  String get setReserved;

  /// No description provided for @setAdopted.
  ///
  /// In en, this message translates to:
  /// **'Set Adopted'**
  String get setAdopted;

  /// No description provided for @setPaused.
  ///
  /// In en, this message translates to:
  /// **'Set Paused'**
  String get setPaused;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @searchPetOrOwnerHint.
  ///
  /// In en, this message translates to:
  /// **'Search by pet or owner name'**
  String get searchPetOrOwnerHint;

  /// No description provided for @couldNotLoadClients.
  ///
  /// In en, this message translates to:
  /// **'Could not load clients.'**
  String get couldNotLoadClients;

  /// No description provided for @addClient.
  ///
  /// In en, this message translates to:
  /// **'Add Client'**
  String get addClient;

  /// No description provided for @ownerNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner Name'**
  String get ownerNameLabel;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @saveClient.
  ///
  /// In en, this message translates to:
  /// **'Save Client'**
  String get saveClient;

  /// No description provided for @petOwnerNamesRequired.
  ///
  /// In en, this message translates to:
  /// **'Pet name and owner name are required'**
  String get petOwnerNamesRequired;

  /// No description provided for @clientSaved.
  ///
  /// In en, this message translates to:
  /// **'Client saved'**
  String get clientSaved;

  /// No description provided for @lastGrooming.
  ///
  /// In en, this message translates to:
  /// **'Last grooming: {date}'**
  String lastGrooming(Object date);

  /// No description provided for @noClientsYet.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get noClientsYet;

  /// No description provided for @addFirstGroomingClient.
  ///
  /// In en, this message translates to:
  /// **'Add your first grooming client to start tracking visits.'**
  String get addFirstGroomingClient;

  /// No description provided for @clientProfile.
  ///
  /// In en, this message translates to:
  /// **'Client Profile'**
  String get clientProfile;

  /// No description provided for @openAppointmentBooking.
  ///
  /// In en, this message translates to:
  /// **'Open appointment booking from business page'**
  String get openAppointmentBooking;

  /// No description provided for @groomingHistory.
  ///
  /// In en, this message translates to:
  /// **'Grooming History'**
  String get groomingHistory;

  /// No description provided for @ownerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Owner not found'**
  String get ownerNotFound;

  /// No description provided for @signInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get signInRequired;

  /// No description provided for @addGroomingVisit.
  ///
  /// In en, this message translates to:
  /// **'Add Grooming Visit'**
  String get addGroomingVisit;

  /// No description provided for @serviceVisitTitle.
  ///
  /// In en, this message translates to:
  /// **'Service / Visit Title'**
  String get serviceVisitTitle;

  /// No description provided for @saveVisit.
  ///
  /// In en, this message translates to:
  /// **'Save Visit'**
  String get saveVisit;

  /// No description provided for @visitSaved.
  ///
  /// In en, this message translates to:
  /// **'Visit saved'**
  String get visitSaved;

  /// No description provided for @editClient.
  ///
  /// In en, this message translates to:
  /// **'Edit Client'**
  String get editClient;

  /// No description provided for @salonSchedule.
  ///
  /// In en, this message translates to:
  /// **'Salon Schedule'**
  String get salonSchedule;

  /// No description provided for @manageGroomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'Manage grooming appointments'**
  String get manageGroomingAppointments;

  /// No description provided for @amountTry.
  ///
  /// In en, this message translates to:
  /// **'{amount} TRY'**
  String amountTry(Object amount);

  /// No description provided for @uploadGroomingMedia.
  ///
  /// In en, this message translates to:
  /// **'Upload Grooming Media'**
  String get uploadGroomingMedia;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @afterPlatformCommission.
  ///
  /// In en, this message translates to:
  /// **'After platform commission'**
  String get afterPlatformCommission;

  /// No description provided for @recentAppointments.
  ///
  /// In en, this message translates to:
  /// **'Recent Appointments'**
  String get recentAppointments;

  /// No description provided for @latestGroomingRequests.
  ///
  /// In en, this message translates to:
  /// **'Latest grooming requests and sessions'**
  String get latestGroomingRequests;

  /// No description provided for @appointmentError.
  ///
  /// In en, this message translates to:
  /// **'Appointment error: {error}'**
  String appointmentError(Object error);

  /// No description provided for @noGroomingAppointmentsYet.
  ///
  /// In en, this message translates to:
  /// **'No grooming appointments yet'**
  String get noGroomingAppointmentsYet;

  /// No description provided for @deleteService.
  ///
  /// In en, this message translates to:
  /// **'Delete Service'**
  String get deleteService;

  /// No description provided for @deleteServiceConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this service?'**
  String get deleteServiceConfirmation;

  /// No description provided for @serviceDeleted.
  ///
  /// In en, this message translates to:
  /// **'Service deleted'**
  String get serviceDeleted;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get deleteFailed;

  /// No description provided for @availabilityUpdated.
  ///
  /// In en, this message translates to:
  /// **'Availability updated'**
  String get availabilityUpdated;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateFailed(Object error);

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @capacityBookingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Capacity is used by the booking functions to prevent overlapping stays beyond available rooms.'**
  String get capacityBookingExplanation;

  /// No description provided for @roomCapacity.
  ///
  /// In en, this message translates to:
  /// **'Room Capacity'**
  String get roomCapacity;

  /// No description provided for @maximumPetsRooms.
  ///
  /// In en, this message translates to:
  /// **'Maximum pets / rooms'**
  String get maximumPetsRooms;

  /// No description provided for @currentCapacity.
  ///
  /// In en, this message translates to:
  /// **'Current capacity: {count}'**
  String currentCapacity(int count);

  /// No description provided for @saveAvailability.
  ///
  /// In en, this message translates to:
  /// **'Save Availability'**
  String get saveAvailability;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check In'**
  String get checkIn;

  /// No description provided for @completeStay.
  ///
  /// In en, this message translates to:
  /// **'Complete Stay'**
  String get completeStay;

  /// No description provided for @alreadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Already {status}'**
  String alreadyStatus(Object status);

  /// No description provided for @bookingUpdated.
  ///
  /// In en, this message translates to:
  /// **'Booking updated: {status}'**
  String bookingUpdated(Object status);

  /// No description provided for @bookingError.
  ///
  /// In en, this message translates to:
  /// **'Booking error: {error}'**
  String bookingError(Object error);

  /// No description provided for @hotelProfile.
  ///
  /// In en, this message translates to:
  /// **'Hotel Profile'**
  String get hotelProfile;

  /// No description provided for @hotelOverview.
  ///
  /// In en, this message translates to:
  /// **'Hotel Overview'**
  String get hotelOverview;

  /// No description provided for @pendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending Requests'**
  String get pendingRequests;

  /// No description provided for @uploadHotelMedia.
  ///
  /// In en, this message translates to:
  /// **'Upload Hotel Media'**
  String get uploadHotelMedia;

  /// No description provided for @proposeFinalPrice.
  ///
  /// In en, this message translates to:
  /// **'Propose Final Price'**
  String get proposeFinalPrice;

  /// No description provided for @editProposedPrice.
  ///
  /// In en, this message translates to:
  /// **'Edit Proposed Price'**
  String get editProposedPrice;

  /// No description provided for @notifyCustomerConfirmation.
  ///
  /// In en, this message translates to:
  /// **'This will notify the customer.'**
  String get notifyCustomerConfirmation;

  /// No description provided for @finalPrice.
  ///
  /// In en, this message translates to:
  /// **'Final price'**
  String get finalPrice;

  /// No description provided for @customerMustPayBeforeTrip.
  ///
  /// In en, this message translates to:
  /// **'The customer must pay this amount in the app before the trip can start.'**
  String get customerMustPayBeforeTrip;

  /// No description provided for @sendPrice.
  ///
  /// In en, this message translates to:
  /// **'Send Price'**
  String get sendPrice;

  /// No description provided for @petTaxiOverview.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi Overview'**
  String get petTaxiOverview;

  /// No description provided for @driverOnline.
  ///
  /// In en, this message translates to:
  /// **'Driver Online'**
  String get driverOnline;

  /// No description provided for @petTaxiAwaitingActivation.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi is awaiting activation.'**
  String get petTaxiAwaitingActivation;

  /// No description provided for @petTaxiAvailabilityUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update Driver Online status. Please try again.'**
  String get petTaxiAvailabilityUpdateFailed;

  /// No description provided for @serviceDetailsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Service details could not be saved.'**
  String get serviceDetailsSaveFailed;

  /// No description provided for @priceDeterminedAfterExamination.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if the final price is determined after examination.'**
  String get priceDeterminedAfterExamination;

  /// No description provided for @editing.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get editing;

  /// No description provided for @setPriceDurationDescription.
  ///
  /// In en, this message translates to:
  /// **'Set the price and estimated duration shown to pet owners.'**
  String get setPriceDurationDescription;

  /// No description provided for @serviceDetailsBeforeBooking.
  ///
  /// In en, this message translates to:
  /// **'These details help pet owners understand the service before booking.'**
  String get serviceDetailsBeforeBooking;

  /// No description provided for @addCustomService.
  ///
  /// In en, this message translates to:
  /// **'Add custom service'**
  String get addCustomService;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment successful'**
  String get paymentSuccessful;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled'**
  String get paymentCancelled;

  /// No description provided for @paymentFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Payment failed: {error}'**
  String paymentFailedWithError(Object error);

  /// No description provided for @appointmentPayment.
  ///
  /// In en, this message translates to:
  /// **'Appointment Payment'**
  String get appointmentPayment;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @noQuickRepliesYet.
  ///
  /// In en, this message translates to:
  /// **'No quick replies yet'**
  String get noQuickRepliesYet;

  /// No description provided for @quickRepliesDescription.
  ///
  /// In en, this message translates to:
  /// **'Create reusable responses for common client questions.'**
  String get quickRepliesDescription;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @inboxError.
  ///
  /// In en, this message translates to:
  /// **'Inbox error:\n{error}'**
  String inboxError(Object error);

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @noClientMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No client messages yet'**
  String get noClientMessagesYet;

  /// No description provided for @clientMessagesDescription.
  ///
  /// In en, this message translates to:
  /// **'When pet owners contact your clinic, conversations will appear here.'**
  String get clientMessagesDescription;

  /// No description provided for @passportNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Passport number must contain only uppercase letters, numbers, - or /'**
  String get passportNumberFormat;

  /// No description provided for @medicalProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Medical profile updated'**
  String get medicalProfileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile: {error}'**
  String profileUpdateFailed(Object error);

  /// No description provided for @confirmMicrochipNumber.
  ///
  /// In en, this message translates to:
  /// **'Confirm Microchip Number'**
  String get confirmMicrochipNumber;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @saveAnyway.
  ///
  /// In en, this message translates to:
  /// **'Save Anyway'**
  String get saveAnyway;

  /// No description provided for @medicalProfile.
  ///
  /// In en, this message translates to:
  /// **'Medical Profile'**
  String get medicalProfile;

  /// No description provided for @saveMedicalProfile.
  ///
  /// In en, this message translates to:
  /// **'Save Medical Profile'**
  String get saveMedicalProfile;

  /// No description provided for @ownerProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Owner profile updated'**
  String get ownerProfileUpdated;

  /// No description provided for @ownerProfile.
  ///
  /// In en, this message translates to:
  /// **'Owner Profile'**
  String get ownerProfile;

  /// No description provided for @couldNotSaveVisit.
  ///
  /// In en, this message translates to:
  /// **'Could not save visit: {error}'**
  String couldNotSaveVisit(Object error);

  /// No description provided for @deleteVisit.
  ///
  /// In en, this message translates to:
  /// **'Delete Visit'**
  String get deleteVisit;

  /// No description provided for @deleteVisitConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete this visit from the medical record?'**
  String get deleteVisitConfirmation;

  /// No description provided for @couldNotDeleteVisit.
  ///
  /// In en, this message translates to:
  /// **'Could not delete visit: {error}'**
  String couldNotDeleteVisit(Object error);

  /// No description provided for @deleteVisitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete visit'**
  String get deleteVisitTooltip;

  /// No description provided for @addVaccine.
  ///
  /// In en, this message translates to:
  /// **'Add Vaccine'**
  String get addVaccine;

  /// No description provided for @vaccine.
  ///
  /// In en, this message translates to:
  /// **'Vaccine'**
  String get vaccine;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @notifyBeforeNextDueDate.
  ///
  /// In en, this message translates to:
  /// **'Notify before the next due date'**
  String get notifyBeforeNextDueDate;

  /// No description provided for @saveVaccine.
  ///
  /// In en, this message translates to:
  /// **'Save Vaccine'**
  String get saveVaccine;

  /// No description provided for @patientNotFound.
  ///
  /// In en, this message translates to:
  /// **'Patient not found'**
  String get patientNotFound;

  /// No description provided for @editOwnerProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Owner Profile'**
  String get editOwnerProfile;

  /// No description provided for @ownerEmergencyContactDetails.
  ///
  /// In en, this message translates to:
  /// **'Owner and emergency contact details'**
  String get ownerEmergencyContactDetails;

  /// No description provided for @editMedicalProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Medical Profile'**
  String get editMedicalProfile;

  /// No description provided for @clinicalVeterinaryInformation.
  ///
  /// In en, this message translates to:
  /// **'Clinical and veterinary information'**
  String get clinicalVeterinaryInformation;

  /// No description provided for @visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visits;

  /// No description provided for @vaccines.
  ///
  /// In en, this message translates to:
  /// **'Vaccines'**
  String get vaccines;

  /// No description provided for @ownerInformation.
  ///
  /// In en, this message translates to:
  /// **'Owner Information'**
  String get ownerInformation;

  /// No description provided for @visitsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Visits unavailable'**
  String get visitsUnavailable;

  /// No description provided for @visitsError.
  ///
  /// In en, this message translates to:
  /// **'Visits error: {error}'**
  String visitsError(Object error);

  /// No description provided for @followUp.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get followUp;

  /// No description provided for @editVisitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit visit'**
  String get editVisitTooltip;

  /// No description provided for @editMedicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Edit Medical Notes'**
  String get editMedicalNotes;

  /// No description provided for @medicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Medical notes'**
  String get medicalNotes;

  /// No description provided for @editVaccineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit vaccine'**
  String get editVaccineTooltip;

  /// No description provided for @deleteVaccineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete vaccine'**
  String get deleteVaccineTooltip;

  /// No description provided for @deleteVaccine.
  ///
  /// In en, this message translates to:
  /// **'Delete Vaccine'**
  String get deleteVaccine;

  /// No description provided for @deleteVaccineConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this vaccine record?'**
  String get deleteVaccineConfirmation;

  /// No description provided for @editVaccine.
  ///
  /// In en, this message translates to:
  /// **'Edit Vaccine'**
  String get editVaccine;

  /// No description provided for @vaccineName.
  ///
  /// In en, this message translates to:
  /// **'Vaccine name'**
  String get vaccineName;

  /// No description provided for @updateVaccine.
  ///
  /// In en, this message translates to:
  /// **'Update Vaccine'**
  String get updateVaccine;

  /// No description provided for @completeVaccine.
  ///
  /// In en, this message translates to:
  /// **'Complete Vaccine'**
  String get completeVaccine;

  /// No description provided for @clientNote.
  ///
  /// In en, this message translates to:
  /// **'Client note'**
  String get clientNote;

  /// No description provided for @businessInfo.
  ///
  /// In en, this message translates to:
  /// **'Business Info'**
  String get businessInfo;

  /// No description provided for @clinicName.
  ///
  /// In en, this message translates to:
  /// **'Clinic name'**
  String get clinicName;

  /// No description provided for @emergencyServiceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Emergency service enabled'**
  String get emergencyServiceEnabled;

  /// No description provided for @saveBusinessInfo.
  ///
  /// In en, this message translates to:
  /// **'Save Business Info'**
  String get saveBusinessInfo;

  /// No description provided for @openAppointmentsTab.
  ///
  /// In en, this message translates to:
  /// **'Open Appointments tab from top'**
  String get openAppointmentsTab;

  /// No description provided for @viewAllAppointments.
  ///
  /// In en, this message translates to:
  /// **'View all appointments'**
  String get viewAllAppointments;

  /// No description provided for @checkConnectionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get checkConnectionTryAgain;

  /// No description provided for @editServiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get editServiceTooltip;

  /// No description provided for @deleteServiceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete service'**
  String get deleteServiceTooltip;

  /// No description provided for @noServicesAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No services added yet'**
  String get noServicesAddedYet;

  /// No description provided for @addFirstServiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Add your first service to make it available for pet owners.'**
  String get addFirstServiceDescription;

  /// No description provided for @servicesPricing.
  ///
  /// In en, this message translates to:
  /// **'Services & Pricing'**
  String get servicesPricing;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add Service'**
  String get addService;

  /// No description provided for @noServicesYet.
  ///
  /// In en, this message translates to:
  /// **'No services yet.'**
  String get noServicesYet;

  /// No description provided for @servicePriceDuration.
  ///
  /// In en, this message translates to:
  /// **'{price} {currency} • {duration} min'**
  String servicePriceDuration(Object price, Object currency, Object duration);

  /// No description provided for @serviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Service title'**
  String get serviceTitle;

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get durationMinutes;

  /// No description provided for @requireDeposit.
  ///
  /// In en, this message translates to:
  /// **'Require deposit'**
  String get requireDeposit;

  /// No description provided for @depositAmount.
  ///
  /// In en, this message translates to:
  /// **'Deposit amount (₺)'**
  String get depositAmount;

  /// No description provided for @featured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get featured;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @photoUploadedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Photo uploaded successfully'**
  String get photoUploadedSuccessfully;

  /// No description provided for @photoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Photo deleted'**
  String get photoDeleted;

  /// No description provided for @coverImageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Cover image updated'**
  String get coverImageUpdated;

  /// No description provided for @galleryManagement.
  ///
  /// In en, this message translates to:
  /// **'Gallery Management'**
  String get galleryManagement;

  /// No description provided for @coverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover Image'**
  String get coverImage;

  /// No description provided for @tapToChangeCover.
  ///
  /// In en, this message translates to:
  /// **'Tap to change cover'**
  String get tapToChangeCover;

  /// No description provided for @uploadCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Upload cover image'**
  String get uploadCoverImage;

  /// No description provided for @tapToUploadClinicCover.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload clinic cover photo'**
  String get tapToUploadClinicCover;

  /// No description provided for @galleryPhotos.
  ///
  /// In en, this message translates to:
  /// **'Gallery Photos'**
  String get galleryPhotos;

  /// No description provided for @noGalleryPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No gallery photos yet'**
  String get noGalleryPhotosYet;

  /// No description provided for @uploadClinicPhotosDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload clinic photos to improve trust and visibility.'**
  String get uploadClinicPhotosDescription;

  /// No description provided for @uploadFirstPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload First Photo'**
  String get uploadFirstPhoto;

  /// No description provided for @dragToReorderGallery.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder gallery photos'**
  String get dragToReorderGallery;

  /// No description provided for @patients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get patients;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @patientRecords.
  ///
  /// In en, this message translates to:
  /// **'Patient Records'**
  String get patientRecords;

  /// No description provided for @shownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} shown'**
  String shownCount(int count);

  /// No description provided for @searchPetOwnerBreed.
  ///
  /// In en, this message translates to:
  /// **'Search pet, owner, or breed'**
  String get searchPetOwnerBreed;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @preVisitSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load pre-visit settings: {error}'**
  String preVisitSettingsLoadFailed(Object error);

  /// No description provided for @preVisitSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Pre-visit form settings saved'**
  String get preVisitSettingsSaved;

  /// No description provided for @settingsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings: {error}'**
  String settingsSaveFailed(Object error);

  /// No description provided for @preVisitForms.
  ///
  /// In en, this message translates to:
  /// **'Pre-visit forms'**
  String get preVisitForms;

  /// No description provided for @servicePreVisitForms.
  ///
  /// In en, this message translates to:
  /// **'Service pre-visit forms'**
  String get servicePreVisitForms;

  /// No description provided for @serviceMedicalIntakeDescription.
  ///
  /// In en, this message translates to:
  /// **'Each service can have its own medical intake questions.'**
  String get serviceMedicalIntakeDescription;

  /// No description provided for @servicesCouldNotBeLoadedPeriod.
  ///
  /// In en, this message translates to:
  /// **'Services could not be loaded.'**
  String get servicesCouldNotBeLoadedPeriod;

  /// No description provided for @noActiveServicesForForms.
  ///
  /// In en, this message translates to:
  /// **'No active services yet. Add services before creating forms.'**
  String get noActiveServicesForForms;

  /// No description provided for @enableForService.
  ///
  /// In en, this message translates to:
  /// **'Enable for this service'**
  String get enableForService;

  /// No description provided for @onlyServiceAsksQuestions.
  ///
  /// In en, this message translates to:
  /// **'Only this service will ask these questions.'**
  String get onlyServiceAsksQuestions;

  /// No description provided for @noQuestionsForService.
  ///
  /// In en, this message translates to:
  /// **'No questions for this service yet.'**
  String get noQuestionsForService;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @questionExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Has your pet eaten today?'**
  String get questionExample;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @questionType.
  ///
  /// In en, this message translates to:
  /// **'Question type'**
  String get questionType;

  /// No description provided for @textType.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textType;

  /// No description provided for @longTextType.
  ///
  /// In en, this message translates to:
  /// **'Long text'**
  String get longTextType;

  /// No description provided for @yesNoType.
  ///
  /// In en, this message translates to:
  /// **'Yes / No'**
  String get yesNoType;

  /// No description provided for @singleChoice.
  ///
  /// In en, this message translates to:
  /// **'Single choice'**
  String get singleChoice;

  /// No description provided for @multipleChoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple choice'**
  String get multipleChoice;

  /// No description provided for @numberType.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get numberType;

  /// No description provided for @requiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredLabel;

  /// No description provided for @options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get options;

  /// No description provided for @optionNumber.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String optionNumber(int number);

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add option'**
  String get addOption;

  /// No description provided for @clinicSchedule.
  ///
  /// In en, this message translates to:
  /// **'Clinic Schedule'**
  String get clinicSchedule;

  /// No description provided for @appointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get appointments;

  /// No description provided for @totalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String totalCount(int count);

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @addServiceFlowComingNext.
  ///
  /// In en, this message translates to:
  /// **'Add service flow coming next'**
  String get addServiceFlowComingNext;

  /// No description provided for @clinicServices.
  ///
  /// In en, this message translates to:
  /// **'Clinic Services'**
  String get clinicServices;

  /// No description provided for @manageVisibleVetServices.
  ///
  /// In en, this message translates to:
  /// **'Manage visible veterinary services'**
  String get manageVisibleVetServices;

  /// No description provided for @clinicSettings.
  ///
  /// In en, this message translates to:
  /// **'Clinic Settings'**
  String get clinicSettings;

  /// No description provided for @emergencyAvailabilitySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save emergency availability'**
  String get emergencyAvailabilitySaveFailed;

  /// No description provided for @managementNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'{label} management is not available yet'**
  String managementNotAvailable(Object label);

  /// No description provided for @loadError.
  ///
  /// In en, this message translates to:
  /// **'Load error: {error}'**
  String loadError(Object error);

  /// No description provided for @workingHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Working hours saved'**
  String get workingHoursSaved;

  /// No description provided for @saveError.
  ///
  /// In en, this message translates to:
  /// **'Save error: {error}'**
  String saveError(Object error);

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working Hours'**
  String get workingHours;

  /// No description provided for @clinicWorkingHours.
  ///
  /// In en, this message translates to:
  /// **'Clinic Working Hours'**
  String get clinicWorkingHours;

  /// No description provided for @manageOpeningDays.
  ///
  /// In en, this message translates to:
  /// **'Manage opening days and appointment availability'**
  String get manageOpeningDays;

  /// No description provided for @editGroomyProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Groomy Profile'**
  String get editGroomyProfile;

  /// No description provided for @groomyDetails.
  ///
  /// In en, this message translates to:
  /// **'Groomy Details'**
  String get groomyDetails;

  /// No description provided for @homeService.
  ///
  /// In en, this message translates to:
  /// **'Home Service'**
  String get homeService;

  /// No description provided for @pickupService.
  ///
  /// In en, this message translates to:
  /// **'Pickup Service'**
  String get pickupService;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @awaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get awaitingPayment;

  /// No description provided for @appointmentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Appointment updated: {status}'**
  String appointmentUpdated(Object status);

  /// No description provided for @galleryComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Gallery coming soon'**
  String get galleryComingSoon;

  /// No description provided for @editHotelProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Hotel Profile'**
  String get editHotelProfile;

  /// No description provided for @pricePerNight.
  ///
  /// In en, this message translates to:
  /// **'{price}₺ / night'**
  String pricePerNight(Object price);

  /// No description provided for @bookStayAt.
  ///
  /// In en, this message translates to:
  /// **'Book stay • {hotel}'**
  String bookStayAt(Object hotel);

  /// No description provided for @hotelCareNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Feeding, medication, or care notes'**
  String get hotelCareNotesHint;

  /// No description provided for @requestBooking.
  ///
  /// In en, this message translates to:
  /// **'Request Booking'**
  String get requestBooking;

  /// No description provided for @checkoutAfterCheckin.
  ///
  /// In en, this message translates to:
  /// **'Check-out must be after check-in'**
  String get checkoutAfterCheckin;

  /// No description provided for @hotelBookingRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Your hotel booking request was sent.'**
  String get hotelBookingRequestSent;

  /// No description provided for @noGalleryImagesYet.
  ///
  /// In en, this message translates to:
  /// **'No gallery images yet'**
  String get noGalleryImagesYet;

  /// No description provided for @petHotelDetails.
  ///
  /// In en, this message translates to:
  /// **'Pet Hotel Details'**
  String get petHotelDetails;

  /// No description provided for @amenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get amenities;

  /// No description provided for @petTaxiDetails.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi Details'**
  String get petTaxiDetails;

  /// No description provided for @petTaxiManualReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Your Pet Taxi application will not be published until documents are manually reviewed and approved.'**
  String get petTaxiManualReviewNotice;

  /// No description provided for @petTaxiReplacementExpiryDateDriverLicense.
  ///
  /// In en, this message translates to:
  /// **'New driver license expiry date'**
  String get petTaxiReplacementExpiryDateDriverLicense;

  /// No description provided for @petTaxiReplacementExpiryDateTrafficInsurance.
  ///
  /// In en, this message translates to:
  /// **'New traffic insurance expiry date'**
  String get petTaxiReplacementExpiryDateTrafficInsurance;

  /// No description provided for @petTaxiReplacementExpiryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a valid future expiry date before submitting this replacement.'**
  String get petTaxiReplacementExpiryRequired;

  /// No description provided for @petTaxiReplacementSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Replacement submitted for review.'**
  String get petTaxiReplacementSubmitted;

  /// No description provided for @petTaxiDocumentsRequiringReplacement.
  ///
  /// In en, this message translates to:
  /// **'Documents requiring replacement'**
  String get petTaxiDocumentsRequiringReplacement;

  /// No description provided for @petTaxiRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get petTaxiRejected;

  /// No description provided for @petTaxiReplaceDocument.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get petTaxiReplaceDocument;

  /// No description provided for @transportationLawNotice.
  ///
  /// In en, this message translates to:
  /// **'Transportation laws may vary by city/country. Businesses are responsible for complying with local transportation, insurance, and tax regulations.'**
  String get transportationLawNotice;

  /// No description provided for @legalDocumentsPrivacyNotice.
  ///
  /// In en, this message translates to:
  /// **'Legal documents are stored for business owner and admin review only. They are not shown to public users.'**
  String get legalDocumentsPrivacyNotice;

  /// No description provided for @savePetTaxiDetails.
  ///
  /// In en, this message translates to:
  /// **'Save Pet Taxi Details'**
  String get savePetTaxiDetails;

  /// No description provided for @driverVehicle.
  ///
  /// In en, this message translates to:
  /// **'Driver & Vehicle'**
  String get driverVehicle;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get vehicleType;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @editPetShopProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit PetShop Profile'**
  String get editPetShopProfile;

  /// No description provided for @petShopDetails.
  ///
  /// In en, this message translates to:
  /// **'PetShop Details'**
  String get petShopDetails;

  /// No description provided for @shopTypes.
  ///
  /// In en, this message translates to:
  /// **'Shop Types'**
  String get shopTypes;

  /// No description provided for @priceLevel.
  ///
  /// In en, this message translates to:
  /// **'Price Level'**
  String get priceLevel;

  /// No description provided for @low.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get low;

  /// No description provided for @mid.
  ///
  /// In en, this message translates to:
  /// **'Mid'**
  String get mid;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @hasDelivery.
  ///
  /// In en, this message translates to:
  /// **'Has Delivery'**
  String get hasDelivery;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @hasOffers.
  ///
  /// In en, this message translates to:
  /// **'Has Offers'**
  String get hasOffers;

  /// No description provided for @rejectedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Rejected Businesses'**
  String get rejectedBusinesses;

  /// No description provided for @noRejectedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'No rejected businesses'**
  String get noRejectedBusinesses;

  /// No description provided for @inheritedFromRegistration.
  ///
  /// In en, this message translates to:
  /// **'Inherited from base registration'**
  String get inheritedFromRegistration;

  /// No description provided for @veterinaryDetails.
  ///
  /// In en, this message translates to:
  /// **'Veterinary Details'**
  String get veterinaryDetails;

  /// No description provided for @licenseReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'This number will be reviewed during verification.'**
  String get licenseReviewNotice;

  /// No description provided for @licenseExpiryDateNumbered.
  ///
  /// In en, this message translates to:
  /// **'12. License Expiry Date'**
  String get licenseExpiryDateNumbered;

  /// No description provided for @workingDaysNumbered.
  ///
  /// In en, this message translates to:
  /// **'20. Working Days'**
  String get workingDaysNumbered;

  /// No description provided for @acceptedAnimalTypesNumbered.
  ///
  /// In en, this message translates to:
  /// **'24. Accepted Animal Types'**
  String get acceptedAnimalTypesNumbered;

  /// No description provided for @confirmInformationAccurate.
  ///
  /// In en, this message translates to:
  /// **'41. I confirm that the information provided is accurate'**
  String get confirmInformationAccurate;

  /// No description provided for @agreeDisplayInformation.
  ///
  /// In en, this message translates to:
  /// **'42. I agree to display my information in the app'**
  String get agreeDisplayInformation;

  /// No description provided for @agreeDisplayReviews.
  ///
  /// In en, this message translates to:
  /// **'43. I agree to user reviews being displayed'**
  String get agreeDisplayReviews;

  /// No description provided for @acceptPartnershipTerms.
  ///
  /// In en, this message translates to:
  /// **'44. I accept PetSupo partnership terms'**
  String get acceptPartnershipTerms;

  /// No description provided for @submitVeterinaryDetails.
  ///
  /// In en, this message translates to:
  /// **'Submit Veterinary Details'**
  String get submitVeterinaryDetails;

  /// No description provided for @adoptionCenterTemporary.
  ///
  /// In en, this message translates to:
  /// **'Adoption Center (TEMP)'**
  String get adoptionCenterTemporary;

  /// No description provided for @reviewsCountParenthesized.
  ///
  /// In en, this message translates to:
  /// **' ({count} reviews)'**
  String reviewsCountParenthesized(Object count);

  /// No description provided for @messageSendingTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Message sending timed out'**
  String get messageSendingTimedOut;

  /// No description provided for @messageFailed.
  ///
  /// In en, this message translates to:
  /// **'Message failed: {error}'**
  String messageFailed(Object error);

  /// No description provided for @chatCreating.
  ///
  /// In en, this message translates to:
  /// **'Chat is creating...'**
  String get chatCreating;

  /// No description provided for @startChatting.
  ///
  /// In en, this message translates to:
  /// **'Start chatting 👋'**
  String get startChatting;

  /// No description provided for @writeMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Write message...'**
  String get writeMessageHint;

  /// No description provided for @noChatsYet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get noChatsYet;

  /// No description provided for @startChattingWithPetOwners.
  ///
  /// In en, this message translates to:
  /// **'Start chatting with pet owners and make new friends for your pet 👋'**
  String get startChattingWithPetOwners;

  /// No description provided for @failedToLoadChats.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chats'**
  String get failedToLoadChats;

  /// No description provided for @personalChatsCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Personal chats could not be loaded.'**
  String get personalChatsCouldNotLoad;

  /// No description provided for @businessConversations.
  ///
  /// In en, this message translates to:
  /// **'Business Conversations'**
  String get businessConversations;

  /// No description provided for @signInToUseChats.
  ///
  /// In en, this message translates to:
  /// **'Sign in to use chats'**
  String get signInToUseChats;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @connectWithPetOwners.
  ///
  /// In en, this message translates to:
  /// **'Connect with pet owners'**
  String get connectWithPetOwners;

  /// No description provided for @noChatsFound.
  ///
  /// In en, this message translates to:
  /// **'No chats found'**
  String get noChatsFound;

  /// No description provided for @tryAnotherKeyword.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or username.'**
  String get tryAnotherKeyword;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @failedToLoadMessages.
  ///
  /// In en, this message translates to:
  /// **'Failed to load messages'**
  String get failedToLoadMessages;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @userInboxEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'When you contact a business,\nyour conversations will appear here.'**
  String get userInboxEmptyDescription;

  /// No description provided for @medicalRecords.
  ///
  /// In en, this message translates to:
  /// **'Medical Records'**
  String get medicalRecords;

  /// No description provided for @vaccinesVisitsAndTreatments.
  ///
  /// In en, this message translates to:
  /// **'Vaccines, visits and treatments'**
  String get vaccinesVisitsAndTreatments;

  /// No description provided for @amountInTry.
  ///
  /// In en, this message translates to:
  /// **'{amount} TRY'**
  String amountInTry(Object amount);

  /// No description provided for @reportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportDialogTitle;

  /// No description provided for @reportSelectReasonError.
  ///
  /// In en, this message translates to:
  /// **'Please select a reason'**
  String get reportSelectReasonError;

  /// No description provided for @reportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonAbuse.
  ///
  /// In en, this message translates to:
  /// **'Abuse / harassment'**
  String get reportReasonAbuse;

  /// No description provided for @reportReasonScam.
  ///
  /// In en, this message translates to:
  /// **'Scam'**
  String get reportReasonScam;

  /// No description provided for @reportReasonFakeProfile.
  ///
  /// In en, this message translates to:
  /// **'Fake profile'**
  String get reportReasonFakeProfile;

  /// No description provided for @reportReasonInappropriateContent.
  ///
  /// In en, this message translates to:
  /// **'Inappropriate content'**
  String get reportReasonInappropriateContent;

  /// No description provided for @reportReasonAnimalSafety.
  ///
  /// In en, this message translates to:
  /// **'Animal safety'**
  String get reportReasonAnimalSafety;

  /// No description provided for @reportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportReasonOther;

  /// No description provided for @reportReasonFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reportReasonFieldLabel;

  /// No description provided for @reportAdditionalDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'Additional details (optional)'**
  String get reportAdditionalDetailsHint;

  /// No description provided for @reportSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSubmitButton;

  /// No description provided for @reportSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you for helping keep the community safe.'**
  String get reportSubmittedSuccess;

  /// No description provided for @reportAlreadyReported.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already reported this - it\'s pending review.'**
  String get reportAlreadyReported;

  /// No description provided for @reportRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many reports submitted recently. Please try again later.'**
  String get reportRateLimited;

  /// No description provided for @reportTargetGone.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.'**
  String get reportTargetGone;

  /// No description provided for @reportUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to submit a report.'**
  String get reportUnauthenticated;

  /// No description provided for @reportNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get reportNetworkError;

  /// No description provided for @reportGenericSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report submitted.'**
  String get reportGenericSuccess;

  /// No description provided for @reportGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get reportGenericError;

  /// No description provided for @reportMenuUser.
  ///
  /// In en, this message translates to:
  /// **'Report user'**
  String get reportMenuUser;

  /// No description provided for @reportMenuPost.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get reportMenuPost;

  /// No description provided for @reportMenuComment.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get reportMenuComment;

  /// No description provided for @reportMenuBusiness.
  ///
  /// In en, this message translates to:
  /// **'Report business'**
  String get reportMenuBusiness;

  /// No description provided for @adminReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReportsTitle;

  /// No description provided for @adminReportsTabPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get adminReportsTabPending;

  /// No description provided for @adminReportsTabApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get adminReportsTabApproved;

  /// No description provided for @adminReportsTabRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get adminReportsTabRejected;

  /// No description provided for @adminReportsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading reports: {error}'**
  String adminReportsLoadError(Object error);

  /// No description provided for @adminReportsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No {status} reports'**
  String adminReportsEmpty(Object status);

  /// No description provided for @moderationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get moderationPermissionDenied;

  /// No description provided for @moderationNotFound.
  ///
  /// In en, this message translates to:
  /// **'This report or target could not be found.'**
  String get moderationNotFound;

  /// No description provided for @moderationAlreadyReviewed.
  ///
  /// In en, this message translates to:
  /// **'This report has already been reviewed.'**
  String get moderationAlreadyReviewed;

  /// No description provided for @moderationNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please try again.'**
  String get moderationNetworkError;

  /// No description provided for @moderationNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get moderationNotesLabel;

  /// No description provided for @moderationCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get moderationCancel;

  /// No description provided for @moderationConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get moderationConfirm;

  /// No description provided for @moderationUnknownTargetType.
  ///
  /// In en, this message translates to:
  /// **'Unknown target type - cannot moderate.'**
  String get moderationUnknownTargetType;

  /// No description provided for @moderationReportApproved.
  ///
  /// In en, this message translates to:
  /// **'Report approved.'**
  String get moderationReportApproved;

  /// No description provided for @moderationReportApprovedNoTarget.
  ///
  /// In en, this message translates to:
  /// **'Report approved (target no longer exists - no action taken).'**
  String get moderationReportApprovedNoTarget;

  /// No description provided for @moderationRejectReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject report'**
  String get moderationRejectReportTitle;

  /// No description provided for @moderationReportRejected.
  ///
  /// In en, this message translates to:
  /// **'Report rejected.'**
  String get moderationReportRejected;

  /// No description provided for @moderationRestoreTargetTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore target'**
  String get moderationRestoreTargetTitle;

  /// No description provided for @moderationTargetRestored.
  ///
  /// In en, this message translates to:
  /// **'Target restored.'**
  String get moderationTargetRestored;

  /// No description provided for @moderationTargetGone.
  ///
  /// In en, this message translates to:
  /// **'This target no longer exists'**
  String get moderationTargetGone;

  /// No description provided for @moderationOwnerLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner: {name}'**
  String moderationOwnerLabel(Object name);

  /// No description provided for @moderationReporterLabel.
  ///
  /// In en, this message translates to:
  /// **'Reporter: {name}'**
  String moderationReporterLabel(Object name);

  /// No description provided for @moderationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String moderationReasonLabel(Object reason);

  /// No description provided for @moderationApproveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get moderationApproveButton;

  /// No description provided for @moderationRejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get moderationRejectButton;

  /// No description provided for @moderationRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get moderationRestoreButton;

  /// No description provided for @moderationReviewedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by {name}'**
  String moderationReviewedByLabel(Object name);

  /// No description provided for @moderationActionLabel.
  ///
  /// In en, this message translates to:
  /// **'action: {action}'**
  String moderationActionLabel(Object action);

  /// No description provided for @moderationChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Choose moderation action'**
  String get moderationChooseAction;

  /// No description provided for @moderationApproveApply.
  ///
  /// In en, this message translates to:
  /// **'Approve & apply'**
  String get moderationApproveApply;

  /// No description provided for @moderationNoOtherReports.
  ///
  /// In en, this message translates to:
  /// **'No other reports on this target'**
  String get moderationNoOtherReports;

  /// No description provided for @moderationHistorySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Report history & moderation timeline'**
  String get moderationHistorySectionTitle;

  /// No description provided for @suspendedAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Your account has been suspended'**
  String get suspendedAccountTitle;

  /// No description provided for @suspendedAccountDefaultReason.
  ///
  /// In en, this message translates to:
  /// **'This account was suspended for violating our community guidelines. If you believe this is a mistake, please contact support.'**
  String get suspendedAccountDefaultReason;

  /// No description provided for @suspendedAccountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get suspendedAccountSignOut;

  /// No description provided for @payoutEligibleTab.
  ///
  /// In en, this message translates to:
  /// **'Eligible'**
  String get payoutEligibleTab;

  /// No description provided for @payoutBatchesTab.
  ///
  /// In en, this message translates to:
  /// **'Batches'**
  String get payoutBatchesTab;

  /// No description provided for @payoutExceptionsTab.
  ///
  /// In en, this message translates to:
  /// **'Exceptions'**
  String get payoutExceptionsTab;

  /// No description provided for @payoutSelectAllEligible.
  ///
  /// In en, this message translates to:
  /// **'Select all eligible sellers'**
  String get payoutSelectAllEligible;

  /// No description provided for @payoutCreateBatch.
  ///
  /// In en, this message translates to:
  /// **'Create payout batch'**
  String get payoutCreateBatch;

  /// No description provided for @payoutBatchCreated.
  ///
  /// In en, this message translates to:
  /// **'Batch {batchNumber} created'**
  String payoutBatchCreated(Object batchNumber);

  /// No description provided for @payoutOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Payout operation failed. {details}'**
  String payoutOperationFailed(Object details);

  /// No description provided for @payoutLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Payout data could not be loaded.'**
  String get payoutLoadFailed;

  /// No description provided for @payoutNoExceptions.
  ///
  /// In en, this message translates to:
  /// **'No payout exceptions'**
  String get payoutNoExceptions;

  /// No description provided for @payoutDateFilter.
  ///
  /// In en, this message translates to:
  /// **'Payment period'**
  String get payoutDateFilter;

  /// No description provided for @payoutToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get payoutToday;

  /// No description provided for @payoutYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get payoutYesterday;

  /// No description provided for @payoutThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get payoutThisWeek;

  /// No description provided for @payoutLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get payoutLastWeek;

  /// No description provided for @payoutThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get payoutThisMonth;

  /// No description provided for @payoutValidBankOnly.
  ///
  /// In en, this message translates to:
  /// **'Valid bank account'**
  String get payoutValidBankOnly;

  /// No description provided for @payoutUnknownSeller.
  ///
  /// In en, this message translates to:
  /// **'Seller information unavailable'**
  String get payoutUnknownSeller;

  /// No description provided for @payoutBankMissing.
  ///
  /// In en, this message translates to:
  /// **'Bank missing'**
  String get payoutBankMissing;

  /// No description provided for @payoutIncludedOrders.
  ///
  /// In en, this message translates to:
  /// **'Included orders'**
  String get payoutIncludedOrders;

  /// No description provided for @payoutPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get payoutPeriod;

  /// No description provided for @payoutGrossTotal.
  ///
  /// In en, this message translates to:
  /// **'Gross total'**
  String get payoutGrossTotal;

  /// No description provided for @payoutCommissionTotal.
  ///
  /// In en, this message translates to:
  /// **'Commission total'**
  String get payoutCommissionTotal;

  /// No description provided for @payoutNetPayable.
  ///
  /// In en, this message translates to:
  /// **'Net payable'**
  String get payoutNetPayable;

  /// No description provided for @payoutNoBatches.
  ///
  /// In en, this message translates to:
  /// **'No payout batches'**
  String get payoutNoBatches;

  /// No description provided for @payoutSellers.
  ///
  /// In en, this message translates to:
  /// **'sellers'**
  String get payoutSellers;

  /// No description provided for @payoutExportXlsx.
  ///
  /// In en, this message translates to:
  /// **'Export XLSX'**
  String get payoutExportXlsx;

  /// No description provided for @payoutValid.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get payoutValid;

  /// No description provided for @payoutBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get payoutBlocked;

  /// No description provided for @payoutMissingBusiness.
  ///
  /// In en, this message translates to:
  /// **'Missing business'**
  String get payoutMissingBusiness;

  /// No description provided for @payoutMissingAccountHolder.
  ///
  /// In en, this message translates to:
  /// **'Missing account holder'**
  String get payoutMissingAccountHolder;

  /// No description provided for @payoutMissingIban.
  ///
  /// In en, this message translates to:
  /// **'Missing IBAN'**
  String get payoutMissingIban;

  /// No description provided for @payoutInvalidIban.
  ///
  /// In en, this message translates to:
  /// **'Invalid IBAN'**
  String get payoutInvalidIban;

  /// No description provided for @payoutMissingBankName.
  ///
  /// In en, this message translates to:
  /// **'Missing bank name'**
  String get payoutMissingBankName;

  /// No description provided for @payoutNonPositiveAmount.
  ///
  /// In en, this message translates to:
  /// **'Net amount must be positive'**
  String get payoutNonPositiveAmount;

  /// No description provided for @payoutSettlementIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Settlement incomplete'**
  String get payoutSettlementIncomplete;

  /// No description provided for @payoutCommissionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Commission requires review'**
  String get payoutCommissionUnknown;

  /// No description provided for @payoutCustomerPaid.
  ///
  /// In en, this message translates to:
  /// **'Customer paid'**
  String get payoutCustomerPaid;

  /// No description provided for @payoutSellerNetNotCalculated.
  ///
  /// In en, this message translates to:
  /// **'Seller net: not calculated'**
  String get payoutSellerNetNotCalculated;

  /// No description provided for @payoutExcludedFromPayout.
  ///
  /// In en, this message translates to:
  /// **'Excluded from payout'**
  String get payoutExcludedFromPayout;

  /// No description provided for @payoutRefundedOrCancelled.
  ///
  /// In en, this message translates to:
  /// **'Refunded or cancelled order'**
  String get payoutRefundedOrCancelled;

  /// No description provided for @payoutAlreadyBatched.
  ///
  /// In en, this message translates to:
  /// **'Already assigned to a batch'**
  String get payoutAlreadyBatched;

  /// No description provided for @payoutAlreadyPaid.
  ///
  /// In en, this message translates to:
  /// **'Already paid'**
  String get payoutAlreadyPaid;

  /// No description provided for @payoutUnsupportedCurrency.
  ///
  /// In en, this message translates to:
  /// **'Unsupported currency'**
  String get payoutUnsupportedCurrency;

  /// No description provided for @payoutIneligible.
  ///
  /// In en, this message translates to:
  /// **'Payout is not eligible'**
  String get payoutIneligible;

  /// No description provided for @payoutStatusFilter.
  ///
  /// In en, this message translates to:
  /// **'Payout status'**
  String get payoutStatusFilter;

  /// No description provided for @payoutSettlementFilter.
  ///
  /// In en, this message translates to:
  /// **'Settlement status'**
  String get payoutSettlementFilter;

  /// No description provided for @payoutBatchFilter.
  ///
  /// In en, this message translates to:
  /// **'Batch assignment'**
  String get payoutBatchFilter;

  /// No description provided for @payoutIncludedInBatch.
  ///
  /// In en, this message translates to:
  /// **'Included in batch'**
  String get payoutIncludedInBatch;

  /// No description provided for @payoutNotIncludedInBatch.
  ///
  /// In en, this message translates to:
  /// **'Not included in batch'**
  String get payoutNotIncludedInBatch;

  /// No description provided for @payoutSellerFilter.
  ///
  /// In en, this message translates to:
  /// **'Seller / business'**
  String get payoutSellerFilter;

  /// No description provided for @payoutBankFilter.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get payoutBankFilter;

  /// No description provided for @payoutMinimumAmount.
  ///
  /// In en, this message translates to:
  /// **'Minimum payout'**
  String get payoutMinimumAmount;

  /// No description provided for @payoutMaximumAmount.
  ///
  /// In en, this message translates to:
  /// **'Maximum payout'**
  String get payoutMaximumAmount;

  /// No description provided for @payoutCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get payoutCustomRange;

  /// No description provided for @financeOverviewTab.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get financeOverviewTab;

  /// No description provided for @financeWaitingTab.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get financeWaitingTab;

  /// No description provided for @financeEligibleSellers.
  ///
  /// In en, this message translates to:
  /// **'Eligible sellers'**
  String get financeEligibleSellers;

  /// No description provided for @financeEligibleRecords.
  ///
  /// In en, this message translates to:
  /// **'Eligible records'**
  String get financeEligibleRecords;

  /// No description provided for @financeWaitingSellers.
  ///
  /// In en, this message translates to:
  /// **'Waiting sellers'**
  String get financeWaitingSellers;

  /// No description provided for @financeWaitingRecords.
  ///
  /// In en, this message translates to:
  /// **'Waiting records'**
  String get financeWaitingRecords;

  /// No description provided for @financeWaitingAmount.
  ///
  /// In en, this message translates to:
  /// **'Waiting amount'**
  String get financeWaitingAmount;

  /// No description provided for @financeBlockedRecords.
  ///
  /// In en, this message translates to:
  /// **'Blocked records'**
  String get financeBlockedRecords;

  /// No description provided for @financeExceptionCount.
  ///
  /// In en, this message translates to:
  /// **'Exceptions'**
  String get financeExceptionCount;

  /// No description provided for @financeTodaySales.
  ///
  /// In en, this message translates to:
  /// **'Today\'s sales'**
  String get financeTodaySales;

  /// No description provided for @financeTodayCommission.
  ///
  /// In en, this message translates to:
  /// **'Today\'s commission'**
  String get financeTodayCommission;

  /// No description provided for @financeTodayRefunds.
  ///
  /// In en, this message translates to:
  /// **'Today\'s refunds'**
  String get financeTodayRefunds;

  /// No description provided for @financeTodayEligible.
  ///
  /// In en, this message translates to:
  /// **'Today\'s eligible'**
  String get financeTodayEligible;

  /// No description provided for @financeTodayPaid.
  ///
  /// In en, this message translates to:
  /// **'Today\'s paid'**
  String get financeTodayPaid;

  /// No description provided for @financeOutstandingLiability.
  ///
  /// In en, this message translates to:
  /// **'Outstanding liability'**
  String get financeOutstandingLiability;

  /// No description provided for @financeMonthlyPlatformRevenue.
  ///
  /// In en, this message translates to:
  /// **'Monthly platform revenue'**
  String get financeMonthlyPlatformRevenue;

  /// No description provided for @financeNextEligibilityDate.
  ///
  /// In en, this message translates to:
  /// **'Next eligible date'**
  String get financeNextEligibilityDate;

  /// No description provided for @financeDaysRemaining.
  ///
  /// In en, this message translates to:
  /// **'Days remaining'**
  String get financeDaysRemaining;

  /// No description provided for @financeOldestWaitingRecord.
  ///
  /// In en, this message translates to:
  /// **'Oldest waiting record'**
  String get financeOldestWaitingRecord;

  /// No description provided for @financeAmountEligibleNext.
  ///
  /// In en, this message translates to:
  /// **'Amount becoming eligible next'**
  String get financeAmountEligibleNext;

  /// No description provided for @financeSendForReview.
  ///
  /// In en, this message translates to:
  /// **'Send for review'**
  String get financeSendForReview;

  /// No description provided for @financeApproveBatch.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get financeApproveBatch;

  /// No description provided for @financeRejectBatch.
  ///
  /// In en, this message translates to:
  /// **'Reject batch'**
  String get financeRejectBatch;

  /// No description provided for @sellerFinanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Finance & Earnings'**
  String get sellerFinanceTitle;

  /// No description provided for @sellerFinanceDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get sellerFinanceDetails;

  /// No description provided for @sellerFinanceAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available balance'**
  String get sellerFinanceAvailable;

  /// No description provided for @sellerFinanceWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting balance'**
  String get sellerFinanceWaiting;

  /// No description provided for @sellerFinanceProcessing.
  ///
  /// In en, this message translates to:
  /// **'Pending / processing'**
  String get sellerFinanceProcessing;

  /// No description provided for @sellerFinancePaidThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Paid this month'**
  String get sellerFinancePaidThisMonth;

  /// No description provided for @sellerFinanceTotalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total earnings'**
  String get sellerFinanceTotalEarnings;

  /// No description provided for @sellerFinanceBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked amount'**
  String get sellerFinanceBlocked;

  /// No description provided for @sellerFinanceBankBlocked.
  ///
  /// In en, this message translates to:
  /// **'Your payout is blocked because your bank account information is incomplete.'**
  String get sellerFinanceBankBlocked;

  /// No description provided for @sellerFinanceBankReady.
  ///
  /// In en, this message translates to:
  /// **'Bank account ready for payouts'**
  String get sellerFinanceBankReady;

  /// No description provided for @sellerFinanceUpdateBank.
  ///
  /// In en, this message translates to:
  /// **'Update bank account'**
  String get sellerFinanceUpdateBank;

  /// No description provided for @sellerFinanceWaitingExplanation.
  ///
  /// In en, this message translates to:
  /// **'Earnings become eligible 21 days after successful payment.'**
  String get sellerFinanceWaitingExplanation;

  /// No description provided for @sellerFinanceWaitingSchedule.
  ///
  /// In en, this message translates to:
  /// **'Waiting schedule'**
  String get sellerFinanceWaitingSchedule;

  /// No description provided for @sellerFinanceLastPayout.
  ///
  /// In en, this message translates to:
  /// **'Last payout'**
  String get sellerFinanceLastPayout;

  /// No description provided for @sellerFinanceOrders.
  ///
  /// In en, this message translates to:
  /// **'orders'**
  String get sellerFinanceOrders;

  /// No description provided for @sellerFinanceAppointments.
  ///
  /// In en, this message translates to:
  /// **'appointments'**
  String get sellerFinanceAppointments;

  /// No description provided for @sellerFinanceBookings.
  ///
  /// In en, this message translates to:
  /// **'bookings'**
  String get sellerFinanceBookings;

  /// No description provided for @sellerFinanceRides.
  ///
  /// In en, this message translates to:
  /// **'rides'**
  String get sellerFinanceRides;

  /// No description provided for @sellerFinanceRequests.
  ///
  /// In en, this message translates to:
  /// **'requests'**
  String get sellerFinanceRequests;

  /// No description provided for @financeRecommendedAction.
  ///
  /// In en, this message translates to:
  /// **'Recommended action'**
  String get financeRecommendedAction;

  /// No description provided for @financeOpenSeller.
  ///
  /// In en, this message translates to:
  /// **'Open seller'**
  String get financeOpenSeller;

  /// No description provided for @financeTomorrowEligible.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow becoming eligible'**
  String get financeTomorrowEligible;

  /// No description provided for @financeNext7Days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get financeNext7Days;

  /// No description provided for @financeNext30Days.
  ///
  /// In en, this message translates to:
  /// **'Next 30 days'**
  String get financeNext30Days;

  /// No description provided for @financeEstimatedPayable.
  ///
  /// In en, this message translates to:
  /// **'Estimated payable'**
  String get financeEstimatedPayable;

  /// No description provided for @financeStartProcessing.
  ///
  /// In en, this message translates to:
  /// **'Start processing'**
  String get financeStartProcessing;

  /// No description provided for @sellerFinanceEstimatedNext.
  ///
  /// In en, this message translates to:
  /// **'Estimated next payout'**
  String get sellerFinanceEstimatedNext;

  /// No description provided for @sellerFinanceTimeline.
  ///
  /// In en, this message translates to:
  /// **'Payout timeline'**
  String get sellerFinanceTimeline;

  /// No description provided for @sellerFinanceTimelineValue.
  ///
  /// In en, this message translates to:
  /// **'Paid → Waiting (21 days) → Eligible → Included in batch → Transferred → Completed'**
  String get sellerFinanceTimelineValue;

  /// No description provided for @sellerFinanceEligibleRecords.
  ///
  /// In en, this message translates to:
  /// **'Eligible records'**
  String get sellerFinanceEligibleRecords;

  /// No description provided for @sellerFinancePayoutHistory.
  ///
  /// In en, this message translates to:
  /// **'Payout history'**
  String get sellerFinancePayoutHistory;

  /// No description provided for @sellerFinanceExceptions.
  ///
  /// In en, this message translates to:
  /// **'Exceptions'**
  String get sellerFinanceExceptions;

  /// No description provided for @financeMarkFailed.
  ///
  /// In en, this message translates to:
  /// **'Mark failed'**
  String get financeMarkFailed;

  /// No description provided for @financeFailureReason.
  ///
  /// In en, this message translates to:
  /// **'Failure reason'**
  String get financeFailureReason;

  /// No description provided for @userProfileCreatorProgram.
  ///
  /// In en, this message translates to:
  /// **'Creator Program'**
  String get userProfileCreatorProgram;

  /// No description provided for @userProfileOpenCreatorDashboard.
  ///
  /// In en, this message translates to:
  /// **'Creator Dashboard'**
  String get userProfileOpenCreatorDashboard;

  /// No description provided for @creatorDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator Dashboard'**
  String get creatorDashboardTitle;

  /// No description provided for @creatorWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get creatorWelcomeBack;

  /// No description provided for @creatorLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Creator Level'**
  String get creatorLevelLabel;

  /// No description provided for @creatorCurrentCampaign.
  ///
  /// In en, this message translates to:
  /// **'Current campaign'**
  String get creatorCurrentCampaign;

  /// No description provided for @creatorReferralCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral Code'**
  String get creatorReferralCodeLabel;

  /// No description provided for @creatorReferralLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral Link'**
  String get creatorReferralLinkLabel;

  /// No description provided for @creatorCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get creatorCopyCode;

  /// No description provided for @creatorCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get creatorCopyLink;

  /// No description provided for @creatorReferralCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get creatorReferralCodeCopied;

  /// No description provided for @creatorReferralLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Referral link copied'**
  String get creatorReferralLinkCopied;

  /// No description provided for @creatorQualifiedUsers.
  ///
  /// In en, this message translates to:
  /// **'Qualified Users'**
  String get creatorQualifiedUsers;

  /// No description provided for @creatorVerifiedPartners.
  ///
  /// In en, this message translates to:
  /// **'Verified Partners'**
  String get creatorVerifiedPartners;

  /// No description provided for @creatorPendingRewards.
  ///
  /// In en, this message translates to:
  /// **'Pending Rewards'**
  String get creatorPendingRewards;

  /// No description provided for @creatorPaidRewards.
  ///
  /// In en, this message translates to:
  /// **'Paid Rewards'**
  String get creatorPaidRewards;

  /// No description provided for @creatorRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get creatorRecentActivity;

  /// No description provided for @creatorNoActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get creatorNoActivityYet;

  /// No description provided for @creatorNoActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'Once someone uses your referral link, activity will show up here.'**
  String get creatorNoActivityMessage;

  /// No description provided for @creatorUpcomingPayout.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Payout'**
  String get creatorUpcomingPayout;

  /// No description provided for @creatorEstimatedPayout.
  ///
  /// In en, this message translates to:
  /// **'Estimated payout'**
  String get creatorEstimatedPayout;

  /// No description provided for @creatorPayoutDate.
  ///
  /// In en, this message translates to:
  /// **'Payout date'**
  String get creatorPayoutDate;

  /// No description provided for @creatorPayoutMethod.
  ///
  /// In en, this message translates to:
  /// **'Payout method'**
  String get creatorPayoutMethod;

  /// No description provided for @creatorOpenFullDashboard.
  ///
  /// In en, this message translates to:
  /// **'Open Full Dashboard'**
  String get creatorOpenFullDashboard;

  /// No description provided for @creatorOpenFullDashboardHint.
  ///
  /// In en, this message translates to:
  /// **'See detailed charts, analytics and full reporting on the web'**
  String get creatorOpenFullDashboardHint;

  /// No description provided for @creatorPerformanceOverview.
  ///
  /// In en, this message translates to:
  /// **'Performance Overview'**
  String get creatorPerformanceOverview;

  /// No description provided for @creatorTotalClicks.
  ///
  /// In en, this message translates to:
  /// **'Total Clicks'**
  String get creatorTotalClicks;

  /// No description provided for @creatorRegistrations.
  ///
  /// In en, this message translates to:
  /// **'Registrations'**
  String get creatorRegistrations;

  /// No description provided for @creatorConversionRate.
  ///
  /// In en, this message translates to:
  /// **'Conversion Rate'**
  String get creatorConversionRate;

  /// No description provided for @creatorRewardBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Reward Breakdown'**
  String get creatorRewardBreakdown;

  /// No description provided for @creatorPayoutHistory.
  ///
  /// In en, this message translates to:
  /// **'Payout History'**
  String get creatorPayoutHistory;

  /// No description provided for @creatorAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get creatorAnalytics;

  /// No description provided for @creatorReferralsTab.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get creatorReferralsTab;

  /// No description provided for @creatorRewardsTab.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get creatorRewardsTab;

  /// No description provided for @creatorFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get creatorFilters;

  /// No description provided for @creatorExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get creatorExport;

  /// No description provided for @creatorTimeframe7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get creatorTimeframe7d;

  /// No description provided for @creatorTimeframe30d.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get creatorTimeframe30d;

  /// No description provided for @creatorTimeframe90d.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get creatorTimeframe90d;

  /// No description provided for @creatorTimeframe12m.
  ///
  /// In en, this message translates to:
  /// **'12 months'**
  String get creatorTimeframe12m;

  /// No description provided for @creatorSignInRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in required'**
  String get creatorSignInRequiredTitle;

  /// No description provided for @creatorSignInRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your Creator Dashboard'**
  String get creatorSignInRequiredMessage;

  /// No description provided for @creatorAccessDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Creator access required'**
  String get creatorAccessDeniedTitle;

  /// No description provided for @creatorAccessDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'This dashboard is only available to approved PetSupo creators.'**
  String get creatorAccessDeniedMessage;

  /// No description provided for @creatorGoToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign in'**
  String get creatorGoToSignIn;

  /// No description provided for @creatorBadgesAchievements.
  ///
  /// In en, this message translates to:
  /// **'Badges & Achievements'**
  String get creatorBadgesAchievements;

  /// No description provided for @creatorProgressToNextLevelPrefix.
  ///
  /// In en, this message translates to:
  /// **'Progress to'**
  String get creatorProgressToNextLevelPrefix;

  /// No description provided for @creatorTotalEarned.
  ///
  /// In en, this message translates to:
  /// **'Total earned'**
  String get creatorTotalEarned;

  /// No description provided for @creatorShareYourLink.
  ///
  /// In en, this message translates to:
  /// **'Share Your Referral Link'**
  String get creatorShareYourLink;

  /// No description provided for @creatorStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get creatorStatusPaid;

  /// No description provided for @creatorStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get creatorStatusScheduled;

  /// No description provided for @creatorExportComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Export is coming soon'**
  String get creatorExportComingSoon;

  /// No description provided for @creatorFiltersComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters are coming soon'**
  String get creatorFiltersComingSoon;

  /// No description provided for @creatorStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get creatorStatusLabel;

  /// No description provided for @creatorStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get creatorStatusActive;

  /// No description provided for @creatorStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get creatorStatusInactive;

  /// No description provided for @creatorSampleData.
  ///
  /// In en, this message translates to:
  /// **'Sample data'**
  String get creatorSampleData;

  /// No description provided for @creatorOpenDashboardFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the dashboard. Please try again.'**
  String get creatorOpenDashboardFailed;

  /// No description provided for @referralCodeOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral code (optional)'**
  String get referralCodeOptionalLabel;

  /// No description provided for @referralCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'That referral code is unavailable. You can continue without it.'**
  String get referralCodeInvalid;

  /// No description provided for @moderationNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No moderation history yet'**
  String get moderationNoHistory;

  /// No description provided for @complaintNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.'**
  String get complaintNoMessages;

  /// No description provided for @generatedFinanceReports.
  ///
  /// In en, this message translates to:
  /// **'Generated Finance Reports'**
  String get generatedFinanceReports;

  /// No description provided for @noReportFilesGenerated.
  ///
  /// In en, this message translates to:
  /// **'No report files were generated.'**
  String get noReportFilesGenerated;

  /// No description provided for @noEligibleSellers.
  ///
  /// In en, this message translates to:
  /// **'No eligible sellers right now'**
  String get noEligibleSellers;

  /// No description provided for @viewWaitingSellers.
  ///
  /// In en, this message translates to:
  /// **'View Waiting Sellers'**
  String get viewWaitingSellers;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @exportFinanceReport.
  ///
  /// In en, this message translates to:
  /// **'Export Finance Report'**
  String get exportFinanceReport;

  /// No description provided for @exportOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'Export operation failed: {error}'**
  String exportOperationFailed(Object error);

  /// No description provided for @generatedXlsx.
  ///
  /// In en, this message translates to:
  /// **'Generated XLSX'**
  String get generatedXlsx;

  /// No description provided for @batchExportedReady.
  ///
  /// In en, this message translates to:
  /// **'The batch is now exported and ready for processing.'**
  String get batchExportedReady;

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @downloadXlsx.
  ///
  /// In en, this message translates to:
  /// **'Download XLSX'**
  String get downloadXlsx;

  /// No description provided for @previewBatch.
  ///
  /// In en, this message translates to:
  /// **'Preview {batch}'**
  String previewBatch(Object batch);

  /// No description provided for @auditHistory.
  ///
  /// In en, this message translates to:
  /// **'Audit History'**
  String get auditHistory;

  /// No description provided for @noAuditEvents.
  ///
  /// In en, this message translates to:
  /// **'No audit events found.'**
  String get noAuditEvents;

  /// No description provided for @settlementRetryRequested.
  ///
  /// In en, this message translates to:
  /// **'Settlement retry requested.'**
  String get settlementRetryRequested;

  /// No description provided for @financialSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Financial Snapshot'**
  String get financialSnapshot;

  /// No description provided for @openOrder.
  ///
  /// In en, this message translates to:
  /// **'Open Order'**
  String get openOrder;

  /// No description provided for @openSeller.
  ///
  /// In en, this message translates to:
  /// **'Open Seller'**
  String get openSeller;

  /// No description provided for @openFinancialSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Open Financial Snapshot'**
  String get openFinancialSnapshot;

  /// No description provided for @retrySettlement.
  ///
  /// In en, this message translates to:
  /// **'Retry Settlement'**
  String get retrySettlement;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @allRecords.
  ///
  /// In en, this message translates to:
  /// **'All records'**
  String get allRecords;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get customRange;

  /// No description provided for @statuses.
  ///
  /// In en, this message translates to:
  /// **'Statuses'**
  String get statuses;

  /// No description provided for @sector.
  ///
  /// In en, this message translates to:
  /// **'Sector'**
  String get sector;

  /// No description provided for @allSectors.
  ///
  /// In en, this message translates to:
  /// **'All sectors'**
  String get allSectors;

  /// No description provided for @petShop.
  ///
  /// In en, this message translates to:
  /// **'Pet Shop'**
  String get petShop;

  /// No description provided for @vet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get vet;

  /// No description provided for @groomy.
  ///
  /// In en, this message translates to:
  /// **'Groomy'**
  String get groomy;

  /// No description provided for @hotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get hotel;

  /// No description provided for @taxi.
  ///
  /// In en, this message translates to:
  /// **'Taxi'**
  String get taxi;

  /// No description provided for @sellerBusinessIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Seller business ID (optional)'**
  String get sellerBusinessIdOptional;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @allCurrencies.
  ///
  /// In en, this message translates to:
  /// **'All currencies'**
  String get allCurrencies;

  /// No description provided for @tryCurrency.
  ///
  /// In en, this message translates to:
  /// **'TRY'**
  String get tryCurrency;

  /// No description provided for @reportLanguage.
  ///
  /// In en, this message translates to:
  /// **'Report language'**
  String get reportLanguage;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @both.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get both;

  /// No description provided for @documentType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get documentType;

  /// No description provided for @accountantCopy.
  ///
  /// In en, this message translates to:
  /// **'Accountant Copy'**
  String get accountantCopy;

  /// No description provided for @internalRecordsCopy.
  ///
  /// In en, this message translates to:
  /// **'Internal Records Copy'**
  String get internalRecordsCopy;

  /// No description provided for @generateReports.
  ///
  /// In en, this message translates to:
  /// **'Generate Reports'**
  String get generateReports;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @adoptionImpactOverview.
  ///
  /// In en, this message translates to:
  /// **'Impact Overview'**
  String get adoptionImpactOverview;

  /// No description provided for @adoptionPerformanceShelterActivity.
  ///
  /// In en, this message translates to:
  /// **'Adoption performance and shelter activity'**
  String get adoptionPerformanceShelterActivity;

  /// No description provided for @noAnimalsAvailableAdoption.
  ///
  /// In en, this message translates to:
  /// **'No animals are currently available for adoption.\nAdd your first animal to begin accepting applications.'**
  String get noAnimalsAvailableAdoption;

  /// No description provided for @adoptionTrend.
  ///
  /// In en, this message translates to:
  /// **'Adoption Trend'**
  String get adoptionTrend;

  /// No description provided for @noAdoptionsYet.
  ///
  /// In en, this message translates to:
  /// **'No adoptions yet.'**
  String get noAdoptionsYet;

  /// No description provided for @speciesBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Species Breakdown'**
  String get speciesBreakdown;

  /// No description provided for @speciesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Species unavailable'**
  String get speciesUnavailable;

  /// No description provided for @adopted.
  ///
  /// In en, this message translates to:
  /// **'Adopted'**
  String get adopted;

  /// No description provided for @revenueTrend.
  ///
  /// In en, this message translates to:
  /// **'Revenue trend'**
  String get revenueTrend;

  /// No description provided for @noRevenueTrendYet.
  ///
  /// In en, this message translates to:
  /// **'No revenue trend yet'**
  String get noRevenueTrendYet;

  /// No description provided for @paymentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} payments'**
  String paymentsCount(Object count);

  /// No description provided for @revenueBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Revenue breakdown'**
  String get revenueBreakdown;

  /// No description provided for @noRevenueActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No revenue activity yet'**
  String get noRevenueActivityYet;

  /// No description provided for @settlementTimeline.
  ///
  /// In en, this message translates to:
  /// **'Settlement timeline'**
  String get settlementTimeline;

  /// No description provided for @waitingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String waitingCount(Object count);

  /// No description provided for @noPayoutsYet.
  ///
  /// In en, this message translates to:
  /// **'No payouts yet'**
  String get noPayoutsYet;

  /// No description provided for @turnOnLocationServices.
  ///
  /// In en, this message translates to:
  /// **'Turn On Location Services'**
  String get turnOnLocationServices;

  /// No description provided for @petTaxiLocationServicesMessage.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi needs location services enabled to show your live position on the map.'**
  String get petTaxiLocationServicesMessage;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get notNow;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @allowLocationAccess.
  ///
  /// In en, this message translates to:
  /// **'Allow Location Access'**
  String get allowLocationAccess;

  /// No description provided for @petTaxiLocationPermissionMessage.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi needs location permission to enable My Location and center the map on you.'**
  String get petTaxiLocationPermissionMessage;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @locationPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location Permission Blocked'**
  String get locationPermissionBlocked;

  /// No description provided for @petTaxiLocationBlockedMessage.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked for Pet Taxi. Open app settings to allow location permission.'**
  String get petTaxiLocationBlockedMessage;

  /// No description provided for @petTaxiBottomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Safe & trusted transportation for your pet'**
  String get petTaxiBottomSubtitle;

  /// No description provided for @petTaxiNoPetsFound.
  ///
  /// In en, this message translates to:
  /// **'No pets found'**
  String get petTaxiNoPetsFound;

  /// No description provided for @petTaxiAddPetPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add a pet to request a Pet Taxi ride.'**
  String get petTaxiAddPetPrompt;

  /// No description provided for @dailySummary.
  ///
  /// In en, this message translates to:
  /// **'Daily Summary'**
  String get dailySummary;

  /// No description provided for @sellers.
  ///
  /// In en, this message translates to:
  /// **'Sellers'**
  String get sellers;

  /// No description provided for @sellerQueryError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String sellerQueryError(Object error);

  /// No description provided for @noSellersFound.
  ///
  /// In en, this message translates to:
  /// **'No sellers found'**
  String get noSellersFound;

  /// No description provided for @medicalNotSigned.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get medicalNotSigned;

  /// No description provided for @medicalNoPets.
  ///
  /// In en, this message translates to:
  /// **'No pets found'**
  String get medicalNoPets;

  /// No description provided for @cancelBookingQuestion.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking?'**
  String get cancelBookingQuestion;

  /// No description provided for @taxiBusinessNotified.
  ///
  /// In en, this message translates to:
  /// **'The taxi business will be notified.'**
  String get taxiBusinessNotified;

  /// No description provided for @keepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keepBooking;

  /// No description provided for @cancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get cancelBooking;

  /// No description provided for @petTaxiBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi Booking'**
  String get petTaxiBookingTitle;

  /// No description provided for @petTaxiBookingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Booking not found'**
  String get petTaxiBookingNotFound;

  /// No description provided for @updating.
  ///
  /// In en, this message translates to:
  /// **'Updating...'**
  String get updating;

  /// No description provided for @petTaxiPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi payment'**
  String get petTaxiPaymentTitle;

  /// No description provided for @paymentRequiredBeforeTrip.
  ///
  /// In en, this message translates to:
  /// **'Payment is required before the trip starts. Provider payout is prepared after trip completion.'**
  String get paymentRequiredBeforeTrip;

  /// No description provided for @bookPetTaxi.
  ///
  /// In en, this message translates to:
  /// **'Book Pet Taxi'**
  String get bookPetTaxi;

  /// No description provided for @transportResponsibilityDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'PetSupo only provides booking infrastructure. Transportation responsibility belongs to the provider.'**
  String get transportResponsibilityDisclaimer;

  /// No description provided for @petSafeForTransportation.
  ///
  /// In en, this message translates to:
  /// **'I confirm my pet is safe for transportation.'**
  String get petSafeForTransportation;

  /// No description provided for @petTaxiBusinessSummary.
  ///
  /// In en, this message translates to:
  /// **'Pet taxi business summary'**
  String get petTaxiBusinessSummary;

  /// No description provided for @noPetsBeforeTaxiBooking.
  ///
  /// In en, this message translates to:
  /// **'No pets found. Add a pet profile before booking.'**
  String get noPetsBeforeTaxiBooking;

  /// No description provided for @selectPetForTaxiBooking.
  ///
  /// In en, this message translates to:
  /// **'Select pet for taxi booking'**
  String get selectPetForTaxiBooking;

  /// No description provided for @selectPickupDateTime.
  ///
  /// In en, this message translates to:
  /// **'Select pickup date and time'**
  String get selectPickupDateTime;

  /// No description provided for @futurePickupDateTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Select a future pickup date and time'**
  String get futurePickupDateTimeRequired;

  /// No description provided for @bookingSummaryA11y.
  ///
  /// In en, this message translates to:
  /// **'Booking summary'**
  String get bookingSummaryA11y;

  /// No description provided for @bookingSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking Summary'**
  String get bookingSummaryTitle;

  /// No description provided for @estimatedPetTaxiPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Estimated pet taxi price range'**
  String get estimatedPetTaxiPriceRange;

  /// No description provided for @estimatedPrice.
  ///
  /// In en, this message translates to:
  /// **'Estimated Price'**
  String get estimatedPrice;

  /// No description provided for @routeEstimateNeeded.
  ///
  /// In en, this message translates to:
  /// **'Select pickup/dropoff locations and pickup time to calculate a real driving-route estimate.'**
  String get routeEstimateNeeded;

  /// No description provided for @routeEstimateDetail.
  ///
  /// In en, this message translates to:
  /// **'{distance} km driving route • {duration} min. Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.'**
  String routeEstimateDetail(Object distance, Object duration);

  /// No description provided for @petTaxiRouteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No drivable route could be found between the selected locations. Please check the pickup and destination.'**
  String get petTaxiRouteUnavailable;

  /// No description provided for @routeEstimateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The route estimate is currently unavailable. Please check the selected locations and try again.'**
  String get routeEstimateUnavailable;

  /// No description provided for @createPetTaxiBooking.
  ///
  /// In en, this message translates to:
  /// **'Create pet taxi booking'**
  String get createPetTaxiBooking;

  /// No description provided for @creatingBooking.
  ///
  /// In en, this message translates to:
  /// **'Creating booking...'**
  String get creatingBooking;

  /// No description provided for @petTaxiTitle.
  ///
  /// In en, this message translates to:
  /// **'Pet Taxi'**
  String get petTaxiTitle;

  /// No description provided for @petTaxiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book safe pet transportation with reviewed taxi businesses.'**
  String get petTaxiSubtitle;

  /// No description provided for @searchTaxiBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Search taxi businesses'**
  String get searchTaxiBusinesses;

  /// No description provided for @locationSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Location search failed: {error}'**
  String locationSearchFailed(Object error);

  /// No description provided for @addressLookupFailed.
  ///
  /// In en, this message translates to:
  /// **'Address lookup failed: {error}'**
  String addressLookupFailed(Object error);

  /// No description provided for @currentLocationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load current location: {error}'**
  String currentLocationLoadFailed(Object error);

  /// No description provided for @useSelectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Use Selected Location'**
  String get useSelectedLocation;

  /// No description provided for @searchRealAddress.
  ///
  /// In en, this message translates to:
  /// **'Search real address'**
  String get searchRealAddress;

  /// No description provided for @streetBuildingDistrict.
  ///
  /// In en, this message translates to:
  /// **'Street, building, district'**
  String get streetBuildingDistrict;

  /// No description provided for @useMyCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use My Current Location'**
  String get useMyCurrentLocation;

  /// No description provided for @helpCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenterTitle;

  /// No description provided for @helpCenterIntro.
  ///
  /// In en, this message translates to:
  /// **'Need help with PetSupo? Find answers and contact support easily.'**
  String get helpCenterIntro;

  /// No description provided for @frequentlyAskedQuestions.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get frequentlyAskedQuestions;

  /// No description provided for @emailAppUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Could not open email app'**
  String get emailAppUnavailable;

  /// No description provided for @emailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get emailCopied;

  /// No description provided for @privacyPolicyContent.
  ///
  /// In en, this message translates to:
  /// **'PetSupo respects your privacy and is committed to protecting your personal data.\n\n1. Data We Collect\nWe may collect personal information, location data, pet-related information, media uploads, and device and notification data.\n\n2. How We Use Your Data\nYour data is used to provide and operate our services, enable matching and communication, improve the app, and send notifications with your permission.\n\n3. Data Sharing\nWe do NOT sell your personal data. Data may be shared only with trusted service providers or when required by law.\n\n4. Data Storage & Security\nYour data is securely stored on servers located in Europe, with appropriate technical and organizational safeguards.\n\n5. Data Retention\nWe retain data only as long as necessary. Users may request deletion at any time.\n\n6. Your Rights (KVKK & GDPR)\nYou may access, correct, delete, withdraw consent, and request portability of your data.\n\n7. Account Deletion\nContact us to request deletion of your account and associated data.\n\n8. Children\'s Privacy\nPetSupo is not intended for children under 13.\n\n9. Changes to This Policy\nWe may update this policy and notify users of significant changes.\n\n10. Contact\nIf you have questions about this policy or your data, please contact us:'**
  String get privacyPolicyContent;

  /// No description provided for @privacyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'7. Contact'**
  String get privacyContactTitle;

  /// No description provided for @privacyContactPrompt.
  ///
  /// In en, this message translates to:
  /// **'If you have any questions about this Privacy Policy or your data, please contact us:'**
  String get privacyContactPrompt;

  /// No description provided for @privacyResponseTime.
  ///
  /// In en, this message translates to:
  /// **'We will respond as soon as possible.'**
  String get privacyResponseTime;

  /// No description provided for @termsEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Email copied'**
  String get termsEmailCopied;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceTitle;

  /// No description provided for @termsIntro.
  ///
  /// In en, this message translates to:
  /// **'By using PetSupo, you agree to the following terms:'**
  String get termsIntro;

  /// No description provided for @termsResponseTime.
  ///
  /// In en, this message translates to:
  /// **'We aim to respond within a reasonable timeframe.'**
  String get termsResponseTime;

  /// No description provided for @invoiceNumberDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Invoice number and date are required'**
  String get invoiceNumberDateRequired;

  /// No description provided for @invoiceUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Invoice upload failed: {error}'**
  String invoiceUploadFailed(Object error);

  /// No description provided for @invoiceStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Invoice {status}'**
  String invoiceStatusMessage(Object status);

  /// No description provided for @invoiceReviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Invoice review failed: {error}'**
  String invoiceReviewFailed(Object error);

  /// No description provided for @openInvoice.
  ///
  /// In en, this message translates to:
  /// **'Open invoice'**
  String get openInvoice;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumber;

  /// No description provided for @invoiceDate.
  ///
  /// In en, this message translates to:
  /// **'Invoice date'**
  String get invoiceDate;

  /// No description provided for @invoiceType.
  ///
  /// In en, this message translates to:
  /// **'Invoice type'**
  String get invoiceType;

  /// No description provided for @individual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get individual;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note optional'**
  String get noteOptional;

  /// No description provided for @rejectionReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason optional'**
  String get rejectionReasonOptional;

  /// No description provided for @paymentSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Success'**
  String get paymentSuccessTitle;

  /// No description provided for @paymentSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment completed successfully ✅'**
  String get paymentSuccessMessage;

  /// No description provided for @paymentFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailedTitle;

  /// No description provided for @paymentFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment verification failed ❌'**
  String get paymentFailedMessage;

  /// No description provided for @paymentCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment Cancelled'**
  String get paymentCancelledTitle;

  /// No description provided for @paymentCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'Payment was cancelled ⚠️'**
  String get paymentCancelledMessage;

  /// No description provided for @submitComplaintTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit Complaint'**
  String get submitComplaintTitle;

  /// No description provided for @submitComplaintConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to submit this complaint?'**
  String get submitComplaintConfirmation;

  /// No description provided for @complaintSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Complaint submitted successfully'**
  String get complaintSubmittedSuccessfully;

  /// No description provided for @unexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get unexpectedError;

  /// No description provided for @complaintCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get complaintCategory;

  /// No description provided for @pleaseSelectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select rating'**
  String get pleaseSelectRating;

  /// No description provided for @feedbackSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Feedback submitted successfully'**
  String get feedbackSubmittedSuccessfully;

  /// No description provided for @feedbackSubmissionFailed.
  ///
  /// In en, this message translates to:
  /// **'Submission failed: {error}'**
  String feedbackSubmissionFailed(Object error);

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send Feedback'**
  String get sendFeedback;

  /// No description provided for @feedbackIntro.
  ///
  /// In en, this message translates to:
  /// **'Help us improve PetSupo with your feedback, ideas, and suggestions.'**
  String get feedbackIntro;

  /// No description provided for @rateYourExperience.
  ///
  /// In en, this message translates to:
  /// **'Rate your experience'**
  String get rateYourExperience;

  /// No description provided for @feedbackCategory.
  ///
  /// In en, this message translates to:
  /// **'Feedback Category'**
  String get feedbackCategory;

  /// No description provided for @generalFeedback.
  ///
  /// In en, this message translates to:
  /// **'General Feedback'**
  String get generalFeedback;

  /// No description provided for @bugReport.
  ///
  /// In en, this message translates to:
  /// **'Bug Report'**
  String get bugReport;

  /// No description provided for @featureRequest.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get featureRequest;

  /// No description provided for @yourMessage.
  ///
  /// In en, this message translates to:
  /// **'Your Message'**
  String get yourMessage;

  /// No description provided for @submitFeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get submitFeedback;

  /// No description provided for @memorialImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load this image. Please try another photo.'**
  String get memorialImageLoadFailed;

  /// No description provided for @createMemorial.
  ///
  /// In en, this message translates to:
  /// **'Create Memorial'**
  String get createMemorial;

  /// No description provided for @memorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Memorial title'**
  String get memorialTitle;

  /// No description provided for @storyMessage.
  ///
  /// In en, this message translates to:
  /// **'Story / message'**
  String get storyMessage;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @memorialHeaderMessage.
  ///
  /// In en, this message translates to:
  /// **'Honor your beloved pet by planting a memory through nature.'**
  String get memorialHeaderMessage;

  /// No description provided for @addPetBeforeMemorial.
  ///
  /// In en, this message translates to:
  /// **'Add a pet before creating a memorial.'**
  String get addPetBeforeMemorial;

  /// No description provided for @addPetFirst.
  ///
  /// In en, this message translates to:
  /// **'Add Pet First'**
  String get addPetFirst;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get choosePhoto;

  /// No description provided for @memorialPhotoPreviewMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo upload will be connected later. Preview is local for now.'**
  String get memorialPhotoPreviewMessage;

  /// No description provided for @memorialCreated.
  ///
  /// In en, this message translates to:
  /// **'Memorial created.'**
  String get memorialCreated;

  /// No description provided for @greenMemorial.
  ///
  /// In en, this message translates to:
  /// **'Green Memorial'**
  String get greenMemorial;

  /// No description provided for @greenMemorialIntro.
  ///
  /// In en, this message translates to:
  /// **'Plant a tree in memory of your beloved pet.'**
  String get greenMemorialIntro;

  /// No description provided for @memorialInMemoryOf.
  ///
  /// In en, this message translates to:
  /// **'In memory of {petName} 🌱'**
  String memorialInMemoryOf(Object petName);

  /// No description provided for @memorialByOwner.
  ///
  /// In en, this message translates to:
  /// **'By {ownerName}'**
  String memorialByOwner(Object ownerName);

  /// No description provided for @favoriteProductsTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorite Products'**
  String get favoriteProductsTitle;

  /// No description provided for @productNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productNotFound;

  /// No description provided for @sellerRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Seller rating'**
  String get sellerRatingLabel;

  /// No description provided for @aboutSellerTitle.
  ///
  /// In en, this message translates to:
  /// **'About Seller'**
  String get aboutSellerTitle;

  /// No description provided for @newestFirst.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get newestFirst;

  /// No description provided for @sellerProductsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error loading seller products: {error}'**
  String sellerProductsLoadError(Object error);

  /// No description provided for @sellerNoActiveProducts.
  ///
  /// In en, this message translates to:
  /// **'This seller has no active products'**
  String get sellerNoActiveProducts;

  /// No description provided for @sellerInitials.
  ///
  /// In en, this message translates to:
  /// **'KP'**
  String get sellerInitials;

  /// No description provided for @passwordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get passwordUpdatedSuccessfully;

  /// No description provided for @passwordStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Password Strength:'**
  String get passwordStrengthLabel;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep your PetSupo account secure by updating your password regularly.'**
  String get changePasswordDescription;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPasswordLabel;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get enterCurrentPassword;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPasswordLabel;

  /// No description provided for @enterNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get enterNewPassword;

  /// No description provided for @enterConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get enterConfirmPassword;

  /// No description provided for @updatePasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordLabel;

  /// No description provided for @savedParksTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Parks'**
  String get savedParksTitle;

  /// No description provided for @noSavedParksYet.
  ///
  /// In en, this message translates to:
  /// **'No saved parks yet'**
  String get noSavedParksYet;

  /// No description provided for @adoptionFirstAnimal.
  ///
  /// In en, this message translates to:
  /// **'Add Your First Animal'**
  String get adoptionFirstAnimal;

  /// No description provided for @completedAdoptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Completed adoptions will appear here.'**
  String get completedAdoptionsEmpty;

  /// No description provided for @recentlyAddedAnimals.
  ///
  /// In en, this message translates to:
  /// **'Recently Added Animals'**
  String get recentlyAddedAnimals;

  /// No description provided for @noAnimalsAdded.
  ///
  /// In en, this message translates to:
  /// **'No animals added yet.'**
  String get noAnimalsAdded;

  /// No description provided for @speciesStatisticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Species statistics will appear after your first successful adoption.'**
  String get speciesStatisticsEmpty;

  /// No description provided for @petTaxiEstimateDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.'**
  String get petTaxiEstimateDisclaimer;

  /// No description provided for @unblockUserTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock user'**
  String get unblockUserTitle;

  /// No description provided for @unblockConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unblock {name}?'**
  String unblockConfirmation(Object name);

  /// No description provided for @unblockSuccess.
  ///
  /// In en, this message translates to:
  /// **'{name} has been unblocked'**
  String unblockSuccess(Object name);

  /// No description provided for @unblockFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to unblock user'**
  String get unblockFailed;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get blockedUsersTitle;

  /// No description provided for @mustBeSignedIn.
  ///
  /// In en, this message translates to:
  /// **'You must be signed in'**
  String get mustBeSignedIn;

  /// No description provided for @blockedUserCount.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked user'**
  String blockedUserCount(Object count);

  /// No description provided for @blockedUsersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} blocked users'**
  String blockedUsersCount(Object count);

  /// No description provided for @blockedUsersDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage users you have blocked from interacting with you.'**
  String get blockedUsersDescription;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @blockedUsersEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Users you block will appear here. You can unblock them anytime.'**
  String get blockedUsersEmptyDescription;

  /// No description provided for @blockedOn.
  ///
  /// In en, this message translates to:
  /// **'Blocked on {date}'**
  String blockedOn(Object date);

  /// No description provided for @unblockButton.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockButton;

  /// No description provided for @deleteAccountFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get deleteAccountFailed;

  /// No description provided for @deleteActionPermanent.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent.\n\nAll your dogs, chats, favorites, and activity will be permanently deleted.'**
  String get deleteActionPermanent;

  /// No description provided for @deleteConfirmationCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to confirm'**
  String get deleteConfirmationCodeHint;

  /// No description provided for @deleteConfirmationCode.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteConfirmationCode;

  /// No description provided for @deleteAccountPermanentNotice.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent and cannot be undone.'**
  String get deleteAccountPermanentNotice;

  /// No description provided for @whatWillBeDeleted.
  ///
  /// In en, this message translates to:
  /// **'What will be deleted'**
  String get whatWillBeDeleted;

  /// No description provided for @confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmation;

  /// No description provided for @privacySettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Privacy settings updated'**
  String get privacySettingsUpdated;

  /// No description provided for @privacySecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Security'**
  String get privacySecurityTitle;

  /// No description provided for @privacySecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Control your visibility, data sharing, and account privacy settings.'**
  String get privacySecurityDescription;

  /// No description provided for @dataExportRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Data export request submitted'**
  String get dataExportRequestSubmitted;

  /// No description provided for @deleteAccountDataNotice.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone and all your data will be permanently deleted.'**
  String get deleteAccountDataNotice;

  /// No description provided for @exitAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit app?'**
  String get exitAppTitle;

  /// No description provided for @exitAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to close PetSupo?'**
  String get exitAppMessage;

  /// No description provided for @exitButton.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitButton;

  /// No description provided for @petSupoBrand.
  ///
  /// In en, this message translates to:
  /// **'PetSupo'**
  String get petSupoBrand;

  /// No description provided for @aboutUsTitle.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUsTitle;

  /// No description provided for @aboutUsContent.
  ///
  /// In en, this message translates to:
  /// **'PetSupo is a digital platform designed to connect pet owners and improve the social lives of pets.\n\nThe application enables users to find suitable playmates for their dogs, discover nearby veterinary services, and access pet-related businesses such as pet shops, groomers, and pet hotels.\n\nPetSupo does not act as a service provider but as a facilitator between users and third-party services. Users are responsible for their interactions and decisions made through the platform.\n\nOur mission is to provide a safe, efficient, and user-friendly environment for pet owners worldwide.'**
  String get aboutUsContent;

  /// No description provided for @faqDescription.
  ///
  /// In en, this message translates to:
  /// **'Find quick answers about PetSupo features, privacy, subscriptions, and safety.'**
  String get faqDescription;

  /// No description provided for @reportTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get reportTitleRequired;

  /// No description provided for @reportSubmittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Report submitted successfully'**
  String get reportSubmittedSuccessfully;

  /// No description provided for @reportSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send report: {error}'**
  String reportSendFailed(Object error);

  /// No description provided for @attachScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Attach screenshot'**
  String get attachScreenshot;

  /// No description provided for @screenshotOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Optional, but helps us understand the issue faster.'**
  String get screenshotOptionalHint;

  /// No description provided for @reportProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a Problem'**
  String get reportProblemTitle;

  /// No description provided for @reportProblemDescription.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong. Your report helps us improve PetSupo.'**
  String get reportProblemDescription;

  /// No description provided for @reportIncorrectInformation.
  ///
  /// In en, this message translates to:
  /// **'Incorrect information'**
  String get reportIncorrectInformation;

  /// No description provided for @reportPaymentIssue.
  ///
  /// In en, this message translates to:
  /// **'Payment issue'**
  String get reportPaymentIssue;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @vetProfileLoadError.
  ///
  /// In en, this message translates to:
  /// **'Load error: {error}'**
  String vetProfileLoadError(Object error);

  /// No description provided for @vetProfileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Vet profile updated successfully'**
  String get vetProfileUpdatedSuccessfully;

  /// No description provided for @vetProfileSaveError.
  ///
  /// In en, this message translates to:
  /// **'Save error: {error}'**
  String vetProfileSaveError(Object error);

  /// No description provided for @editVetProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Vet Profile'**
  String get editVetProfileTitle;

  /// No description provided for @suggestClinicTitle.
  ///
  /// In en, this message translates to:
  /// **'Help us grow PetSupo'**
  String get suggestClinicTitle;

  /// No description provided for @suggestClinicDescription.
  ///
  /// In en, this message translates to:
  /// **'Suggest {vetName} to join PetSupo and help pet owners book appointments more easily.'**
  String suggestClinicDescription(Object vetName);

  /// No description provided for @shareInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share Invitation'**
  String get shareInvitation;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe Later'**
  String get maybeLater;

  /// No description provided for @vaccineDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vaccine Details'**
  String get vaccineDetailsTitle;

  /// No description provided for @clinicCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Clinic could not be loaded'**
  String get clinicCouldNotBeLoaded;

  /// No description provided for @relatedRecords.
  ///
  /// In en, this message translates to:
  /// **'Related records'**
  String get relatedRecords;

  /// No description provided for @selectAnOption.
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get selectAnOption;

  /// No description provided for @enterDetails.
  ///
  /// In en, this message translates to:
  /// **'Enter details'**
  String get enterDetails;

  /// No description provided for @futureDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select a future date and time.'**
  String get futureDateRequired;

  /// No description provided for @preVisitQuestionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Please complete required pre-visit questions.'**
  String get preVisitQuestionsRequired;

  /// No description provided for @noDetailedServicesProvided.
  ///
  /// In en, this message translates to:
  /// **'No detailed services provided.'**
  String get noDetailedServicesProvided;

  /// No description provided for @noDogsYetMatching.
  ///
  /// In en, this message translates to:
  /// **'No dogs yet — add yours and start matching! 🐾'**
  String get noDogsYetMatching;

  /// No description provided for @createProfileToConnect.
  ///
  /// In en, this message translates to:
  /// **'Create profile to connect 🐾'**
  String get createProfileToConnect;

  /// No description provided for @unknownBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Unknown business type → {sectors}'**
  String unknownBusinessType(Object sectors);

  /// No description provided for @persianLanguage.
  ///
  /// In en, this message translates to:
  /// **'فارسی'**
  String get persianLanguage;

  /// No description provided for @russianLanguage.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get russianLanguage;

  /// No description provided for @phoneAuthDebugError.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}\n\nMessage:\n{message}\n\n{details}'**
  String phoneAuthDebugError(Object code, Object details, Object message);

  /// No description provided for @phoneVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Phone verification could not be completed.'**
  String get phoneVerificationFailed;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change Number'**
  String get changeNumber;

  /// No description provided for @verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhoneTitle;

  /// No description provided for @enterCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter code sent to\n{phone}'**
  String enterCodeSentTo(Object phone);

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeLabel;

  /// No description provided for @newCodeSent.
  ///
  /// In en, this message translates to:
  /// **'New code sent'**
  String get newCodeSent;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @searchVeterinaryClinics.
  ///
  /// In en, this message translates to:
  /// **'Search veterinary clinics...'**
  String get searchVeterinaryClinics;

  /// No description provided for @howWouldYouLikeToStart.
  ///
  /// In en, this message translates to:
  /// **'How would you like to start?'**
  String get howWouldYouLikeToStart;

  /// No description provided for @welcomeToPetSopuWithWave.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PetSupo 👋'**
  String get welcomeToPetSopuWithWave;

  /// No description provided for @moreThanAnApp.
  ///
  /// In en, this message translates to:
  /// **'More than an app.\nA home for pets and their people.'**
  String get moreThanAnApp;

  /// No description provided for @viewPremiumPlans.
  ///
  /// In en, this message translates to:
  /// **'View Premium Plans'**
  String get viewPremiumPlans;

  /// No description provided for @promotionPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Promotion performance'**
  String get promotionPerformanceTitle;

  /// No description provided for @promotionCampaignStatus.
  ///
  /// In en, this message translates to:
  /// **'Campaign status'**
  String get promotionCampaignStatus;

  /// No description provided for @promotionCampaignActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get promotionCampaignActive;

  /// No description provided for @promotionCampaignExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get promotionCampaignExpired;

  /// No description provided for @promotionCampaignProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get promotionCampaignProcessing;

  /// No description provided for @promotionCampaignNeedsReconciliation.
  ///
  /// In en, this message translates to:
  /// **'Needs reconciliation'**
  String get promotionCampaignNeedsReconciliation;

  /// No description provided for @promotionSpend.
  ///
  /// In en, this message translates to:
  /// **'Spend'**
  String get promotionSpend;

  /// No description provided for @promotionImpressions.
  ///
  /// In en, this message translates to:
  /// **'Impressions'**
  String get promotionImpressions;

  /// No description provided for @promotionClicks.
  ///
  /// In en, this message translates to:
  /// **'Clicks'**
  String get promotionClicks;

  /// No description provided for @promotionCtr.
  ///
  /// In en, this message translates to:
  /// **'CTR'**
  String get promotionCtr;

  /// No description provided for @promotionDetailViews.
  ///
  /// In en, this message translates to:
  /// **'Detail views'**
  String get promotionDetailViews;

  /// No description provided for @promotionFinancialConversions.
  ///
  /// In en, this message translates to:
  /// **'Financial conversions'**
  String get promotionFinancialConversions;

  /// No description provided for @promotionNetRevenue.
  ///
  /// In en, this message translates to:
  /// **'Net attributed revenue'**
  String get promotionNetRevenue;

  /// No description provided for @promotionRoas.
  ///
  /// In en, this message translates to:
  /// **'ROAS'**
  String get promotionRoas;

  /// No description provided for @promotionStarts.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get promotionStarts;

  /// No description provided for @promotionEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get promotionEnds;

  /// No description provided for @promotionDurationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours'**
  String promotionDurationHours(Object hours);

  /// No description provided for @promotionFinancialSection.
  ///
  /// In en, this message translates to:
  /// **'Financial performance'**
  String get promotionFinancialSection;

  /// No description provided for @promotionFinancialAvailable.
  ///
  /// In en, this message translates to:
  /// **'Financial metrics are up to date.'**
  String get promotionFinancialAvailable;

  /// No description provided for @promotionFinancialProvisional.
  ///
  /// In en, this message translates to:
  /// **'Financial metrics are still being reconciled.'**
  String get promotionFinancialProvisional;

  /// No description provided for @promotionFinancialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Financial metrics are unavailable or not applicable.'**
  String get promotionFinancialUnavailable;

  /// No description provided for @promotionPetFinancialNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Financial metrics are not applicable to Pet Boost.'**
  String get promotionPetFinancialNotApplicable;

  /// No description provided for @promotionNoPerformanceData.
  ///
  /// In en, this message translates to:
  /// **'Your promotion is active. Performance data will appear as people see and interact with it.'**
  String get promotionNoPerformanceData;

  /// No description provided for @promotionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get promotionRetry;

  /// No description provided for @promotionLoadError.
  ///
  /// In en, this message translates to:
  /// **'Performance could not be loaded.'**
  String get promotionLoadError;

  /// No description provided for @promotionUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get promotionUpToDate;

  /// No description provided for @promotionReconciliationStatus.
  ///
  /// In en, this message translates to:
  /// **'Reconciliation'**
  String get promotionReconciliationStatus;

  /// No description provided for @promotionNa.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get promotionNa;

  /// No description provided for @promotionTargetPet.
  ///
  /// In en, this message translates to:
  /// **'Pet'**
  String get promotionTargetPet;

  /// No description provided for @promotionTargetProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get promotionTargetProduct;

  /// No description provided for @promotionTargetVetService.
  ///
  /// In en, this message translates to:
  /// **'Vet service'**
  String get promotionTargetVetService;

  /// No description provided for @promotionTargetGroomyService.
  ///
  /// In en, this message translates to:
  /// **'Groomy service'**
  String get promotionTargetGroomyService;

  /// No description provided for @petTaxiDocumentTaxPlate.
  ///
  /// In en, this message translates to:
  /// **'Tax plate'**
  String get petTaxiDocumentTaxPlate;

  /// No description provided for @petTaxiDocumentBusinessRegistration.
  ///
  /// In en, this message translates to:
  /// **'Business registration'**
  String get petTaxiDocumentBusinessRegistration;

  /// No description provided for @petTaxiDocumentVehicleRegistration.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration'**
  String get petTaxiDocumentVehicleRegistration;

  /// No description provided for @petTaxiDocumentDriverLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver license'**
  String get petTaxiDocumentDriverLicense;

  /// No description provided for @petTaxiDocumentTrafficInsurance.
  ///
  /// In en, this message translates to:
  /// **'Traffic insurance'**
  String get petTaxiDocumentTrafficInsurance;

  /// No description provided for @petTaxiDocumentStatusPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get petTaxiDocumentStatusPendingReview;

  /// No description provided for @petTaxiDocumentStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get petTaxiDocumentStatusApproved;

  /// No description provided for @petTaxiDocumentStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get petTaxiDocumentStatusRejected;

  /// No description provided for @petTaxiDocumentStatusMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get petTaxiDocumentStatusMissing;

  /// No description provided for @petTaxiDocumentExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get petTaxiDocumentExpired;

  /// No description provided for @petTaxiDocumentExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date: {date}'**
  String petTaxiDocumentExpiryDate(Object date);

  /// No description provided for @petTaxiDocumentExpiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This document has expired. Reject it and ask the business to upload a valid replacement.'**
  String get petTaxiDocumentExpiredMessage;

  /// No description provided for @petTaxiRejectDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject {document}'**
  String petTaxiRejectDocumentTitle(Object document);

  /// No description provided for @petTaxiAdminErrorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to perform this action.'**
  String get petTaxiAdminErrorPermissionDenied;

  /// No description provided for @petTaxiAdminErrorUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get petTaxiAdminErrorUnauthenticated;

  /// No description provided for @petTaxiAdminErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'The business or document could not be found.'**
  String get petTaxiAdminErrorNotFound;

  /// No description provided for @petTaxiAdminErrorInvalidArgument.
  ///
  /// In en, this message translates to:
  /// **'Please review the document details and try again.'**
  String get petTaxiAdminErrorInvalidArgument;

  /// No description provided for @petTaxiAdminErrorAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'This action has already been completed.'**
  String get petTaxiAdminErrorAlreadyExists;

  /// No description provided for @petTaxiAdminErrorFailedPrecondition.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be completed in the current document state.'**
  String get petTaxiAdminErrorFailedPrecondition;

  /// No description provided for @petTaxiAdminErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'The action could not be completed. Please try again.'**
  String get petTaxiAdminErrorGeneric;

  /// No description provided for @petTaxiAdminActionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Document updated'**
  String get petTaxiAdminActionCompleted;

  /// No description provided for @petTaxiUploadDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload document'**
  String get petTaxiUploadDocument;

  /// No description provided for @petTaxiTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get petTaxiTakePhoto;

  /// No description provided for @petTaxiChoosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get petTaxiChoosePhoto;

  /// No description provided for @petTaxiChoosePdf.
  ///
  /// In en, this message translates to:
  /// **'Choose PDF'**
  String get petTaxiChoosePdf;

  /// No description provided for @petTaxiSupportedDocumentFormats.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG or PNG (up to 25 MB)'**
  String get petTaxiSupportedDocumentFormats;

  /// No description provided for @petTaxiUnsupportedDocumentFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF, JPG or PNG document.'**
  String get petTaxiUnsupportedDocumentFormat;

  /// No description provided for @petTaxiDocumentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This document is larger than 25 MB.'**
  String get petTaxiDocumentTooLarge;

  /// No description provided for @petTaxiDocumentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Document upload failed. Please try again.'**
  String get petTaxiDocumentUploadFailed;

  /// No description provided for @petTaxiOpenDocumentFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open this document.'**
  String get petTaxiOpenDocumentFailed;

  /// No description provided for @businessRegisterOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get businessRegisterOptional;

  /// No description provided for @businessRegisterTaxPlateRequired.
  ///
  /// In en, this message translates to:
  /// **'Tax plate must be uploaded.'**
  String get businessRegisterTaxPlateRequired;

  /// No description provided for @businessRegisterMersisNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'MERSIS number is required.'**
  String get businessRegisterMersisNumberRequired;

  /// No description provided for @businessRegisterPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get businessRegisterPhoneOptional;

  /// No description provided for @businessRegisterWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get businessRegisterWhatsApp;

  /// No description provided for @businessRegisterDetectLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Detect your business location'**
  String get businessRegisterDetectLocationTitle;

  /// No description provided for @businessRegisterDetectLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'We use your location to detect your city and district.'**
  String get businessRegisterDetectLocationMessage;

  /// No description provided for @petTaxiDocumentPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera or photo access was denied. You can choose a photo or PDF instead.'**
  String get petTaxiDocumentPermissionDenied;

  /// No description provided for @petTaxiRequiredDocuments.
  ///
  /// In en, this message translates to:
  /// **'Required documents'**
  String get petTaxiRequiredDocuments;

  /// No description provided for @petTaxiRequiredDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Documents required for manual admin review'**
  String get petTaxiRequiredDocumentsSubtitle;

  /// No description provided for @petTaxiOptionalDocuments.
  ///
  /// In en, this message translates to:
  /// **'Optional / conditional documents'**
  String get petTaxiOptionalDocuments;

  /// No description provided for @petTaxiOptionalDocumentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload these if they apply to your service'**
  String get petTaxiOptionalDocumentsSubtitle;

  /// No description provided for @petTaxiComplianceTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance & legal confirmations'**
  String get petTaxiComplianceTitle;

  /// No description provided for @petTaxiComplianceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required confirmations before submitting'**
  String get petTaxiComplianceSubtitle;

  /// No description provided for @petTaxiPetSafetyEquipmentConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Pet safety equipment is available in the vehicle.'**
  String get petTaxiPetSafetyEquipmentConfirmation;

  /// No description provided for @petTaxiHygieneConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Hygiene and sanitation requirements are confirmed.'**
  String get petTaxiHygieneConfirmation;

  /// No description provided for @petTaxiDriverLicenseConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm the driver license is valid.'**
  String get petTaxiDriverLicenseConfirmation;

  /// No description provided for @petTaxiVehicleRegistrationConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm the vehicle registration belongs to the service vehicle.'**
  String get petTaxiVehicleRegistrationConfirmation;

  /// No description provided for @petTaxiTrafficInsuranceConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm traffic insurance is active.'**
  String get petTaxiTrafficInsuranceConfirmation;

  /// No description provided for @petTaxiTaxResponsibilityConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm tax obligations and invoice or receipt responsibilities belong to my business.'**
  String get petTaxiTaxResponsibilityConfirmation;

  /// No description provided for @petTaxiTransportRulesConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm I comply with city and country transportation rules.'**
  String get petTaxiTransportRulesConfirmation;

  /// No description provided for @petTaxiComplianceNotes.
  ///
  /// In en, this message translates to:
  /// **'Compliance notes for admin review'**
  String get petTaxiComplianceNotes;

  /// No description provided for @petTaxiOptionalIfApplicable.
  ///
  /// In en, this message translates to:
  /// **'Optional / if applicable'**
  String get petTaxiOptionalIfApplicable;

  /// No description provided for @petTaxiDocumentRequired.
  ///
  /// In en, this message translates to:
  /// **'{document} is required'**
  String petTaxiDocumentRequired(Object document);

  /// No description provided for @petTaxiDateRequired.
  ///
  /// In en, this message translates to:
  /// **'{date} is required'**
  String petTaxiDateRequired(Object date);

  /// No description provided for @petTaxiDateCannotBePast.
  ///
  /// In en, this message translates to:
  /// **'{date} cannot be in the past'**
  String petTaxiDateCannotBePast(Object date);

  /// No description provided for @petTaxiDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get petTaxiDocumentNumber;

  /// No description provided for @petTaxiDocumentNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Document number (optional)'**
  String get petTaxiDocumentNumberOptional;

  /// No description provided for @petTaxiDocumentNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Document number is required'**
  String get petTaxiDocumentNumberRequired;

  /// No description provided for @petTaxiVehicleRegistrationIssueDate.
  ///
  /// In en, this message translates to:
  /// **'Vehicle registration issue date'**
  String get petTaxiVehicleRegistrationIssueDate;

  /// No description provided for @petTaxiDriverLicenseExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Driver license expiry date'**
  String get petTaxiDriverLicenseExpiryDate;

  /// No description provided for @petTaxiTrafficInsuranceExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Traffic insurance expiry date'**
  String get petTaxiTrafficInsuranceExpiryDate;

  /// No description provided for @petTaxiSrcCertificateExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'SRC certificate expiry date'**
  String get petTaxiSrcCertificateExpiryDate;

  /// No description provided for @petTaxiPsychotechnicalExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Psychotechnical report expiry date'**
  String get petTaxiPsychotechnicalExpiryDate;

  /// No description provided for @petTaxiKaskoExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive insurance expiry date'**
  String get petTaxiKaskoExpiryDate;

  /// No description provided for @petTaxiValidTurkishPlate.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Turkish vehicle plate.'**
  String get petTaxiValidTurkishPlate;

  /// No description provided for @petTaxiRequiredDocumentsMissing.
  ///
  /// In en, this message translates to:
  /// **'Upload all required Pet Taxi documents.'**
  String get petTaxiRequiredDocumentsMissing;

  /// No description provided for @petTaxiComplianceConfirmationsMissing.
  ///
  /// In en, this message translates to:
  /// **'Confirm all required compliance statements.'**
  String get petTaxiComplianceConfirmationsMissing;

  /// No description provided for @petTaxiValidPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get petTaxiValidPhoneNumber;

  /// No description provided for @petTaxiValidCapacity.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid vehicle capacity.'**
  String get petTaxiValidCapacity;

  /// No description provided for @petTaxiCapacityMinimum.
  ///
  /// In en, this message translates to:
  /// **'Vehicle capacity must be at least 1.'**
  String get petTaxiCapacityMinimum;

  /// No description provided for @petTaxiCapacityMaximum.
  ///
  /// In en, this message translates to:
  /// **'Vehicle capacity cannot be greater than 15.'**
  String get petTaxiCapacityMaximum;

  /// No description provided for @petTaxiSelectVehicleType.
  ///
  /// In en, this message translates to:
  /// **'Select a vehicle type.'**
  String get petTaxiSelectVehicleType;

  /// No description provided for @petTaxiDriverFullName.
  ///
  /// In en, this message translates to:
  /// **'Driver full name'**
  String get petTaxiDriverFullName;

  /// No description provided for @petTaxiDriverPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Driver phone number'**
  String get petTaxiDriverPhoneNumber;

  /// No description provided for @petTaxiVehiclePlateNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle plate number'**
  String get petTaxiVehiclePlateNumber;

  /// No description provided for @petTaxiVehicleCapacity.
  ///
  /// In en, this message translates to:
  /// **'Vehicle capacity'**
  String get petTaxiVehicleCapacity;

  /// No description provided for @petTaxiVehicleSedan.
  ///
  /// In en, this message translates to:
  /// **'Sedan'**
  String get petTaxiVehicleSedan;

  /// No description provided for @petTaxiVehicleHatchback.
  ///
  /// In en, this message translates to:
  /// **'Hatchback'**
  String get petTaxiVehicleHatchback;

  /// No description provided for @petTaxiVehicleSuv.
  ///
  /// In en, this message translates to:
  /// **'SUV'**
  String get petTaxiVehicleSuv;

  /// No description provided for @petTaxiVehicleVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get petTaxiVehicleVan;

  /// No description provided for @petTaxiVehiclePetTransportVan.
  ///
  /// In en, this message translates to:
  /// **'Pet transport van'**
  String get petTaxiVehiclePetTransportVan;

  /// No description provided for @petTaxiVehicleLargeAnimalTransport.
  ///
  /// In en, this message translates to:
  /// **'Large animal transport'**
  String get petTaxiVehicleLargeAnimalTransport;

  /// No description provided for @adPrivacyOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy options'**
  String get adPrivacyOptionsTitle;

  /// No description provided for @adPrivacyOptionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage advertising consent and privacy choices.'**
  String get adPrivacyOptionsSubtitle;
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
