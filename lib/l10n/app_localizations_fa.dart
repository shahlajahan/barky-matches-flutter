// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get userNotLoggedIn =>
      'کاربر وارد نشده است. در حال انتقال به صفحه ورود...';

  @override
  String errorLoadingUserInfo(Object error) {
    return 'خطا در بارگذاری اطلاعات کاربر: $error';
  }

  @override
  String errorLoadingDogs(Object error) {
    return 'خطا در بارگذاری سگ‌ها: $error';
  }

  @override
  String get usernameCannotBeEmpty => 'نام کاربری نمی‌تواند خالی باشد';

  @override
  String get profileUpdatedSuccessfully => 'پروفایل با موفقیت به‌روزرسانی شد';

  @override
  String errorUpdatingDog(Object error) {
    return 'خطا در به‌روزرسانی سگ: $error';
  }

  @override
  String errorDeletingAccount(Object error) {
    return 'خطا در حذف حساب: $error';
  }

  @override
  String get accountDeleted => 'حساب حذف شد.';

  @override
  String errorDuringLogout(Object error) {
    return 'خطا هنگام خروج: $error';
  }

  @override
  String get cartTitle => 'سبد من';

  @override
  String get cartIsEmpty => 'سبد خالی است';

  @override
  String get totalLabel => 'مجموع';

  @override
  String get checkoutButton => 'پرداخت';

  @override
  String get checkoutStepAddressTitle => 'آدرس';

  @override
  String get checkoutStepPaymentTitle => 'پرداخت';

  @override
  String get checkoutStepConfirmTitle => 'تأیید';

  @override
  String get checkoutDeliveryAddressTitle => 'آدرس تحویل';

  @override
  String get checkoutFullNameLabel => 'نام و نام خانوادگی';

  @override
  String get checkoutFullNameHint => 'نام و نام خانوادگی';

  @override
  String get checkoutPhoneHint => '5XXXXXXXXX';

  @override
  String get checkoutCityLabel => 'شهر';

  @override
  String get checkoutCityHint => 'استانبول';

  @override
  String get checkoutDistrictLabel => 'منطقه';

  @override
  String get checkoutDistrictHint => 'کادیکوی';

  @override
  String get checkoutAddressLabel => 'آدرس کامل';

  @override
  String get checkoutAddressHint => 'جزئیات کامل آدرس';

  @override
  String get checkoutInvoiceDetailsTitle => 'اطلاعات فاکتور';

  @override
  String get checkoutIndividualOption => 'شخصی';

  @override
  String get checkoutCompanyOption => 'شرکتی';

  @override
  String get checkoutIdentityNumberLabel => 'شماره ملی';

  @override
  String get checkoutIdentityNumberHint => '11 رقم';

  @override
  String get checkoutCompanyNameLabel => 'نام شرکت';

  @override
  String get checkoutTaxNumberLabel => 'شماره مالیاتی';

  @override
  String get checkoutTaxNumberHint => '10 رقم';

  @override
  String get checkoutTaxOfficeLabel => 'اداره مالیات';

  @override
  String get checkoutCargoUpdatesTitle => 'به‌روزرسانی فاکتور و ارسال';

  @override
  String get checkoutCargoUpdatesQuestion =>
      'به‌روزرسانی‌های فاکتور و پیگیری ارسال را چگونه برایتان بفرستیم؟';

  @override
  String get checkoutSmsOption => 'پیامک';

  @override
  String get checkoutEmailOption => 'ایمیل';

  @override
  String get checkoutSmsEmailOption => 'پیامک + ایمیل';

  @override
  String get checkoutAgreementsTitle => 'توافق‌ها';

  @override
  String get checkoutKvkkDisclosure => 'اطلاع‌رسانی KVKK را خوانده‌ام';

  @override
  String get checkoutViewButton => 'مشاهده';

  @override
  String get checkoutPreInfoForm => 'فرم پیش‌اطلاع‌رسانی را می‌پذیرم';

  @override
  String get checkoutDistanceSalesAgreement =>
      'قرارداد فروش از راه دور را می‌پذیرم';

  @override
  String get checkoutMarketingOptional => 'دریافت پیام‌های بازاریابی (اختیاری)';

  @override
  String get checkoutDeliveryTitle => 'تحویل';

  @override
  String get checkoutPaymentSummaryTitle => 'خلاصه پرداخت';

  @override
  String get checkoutSubtotalLabel => 'جمع جزء';

  @override
  String get checkoutVatLabel => 'مالیات بر ارزش افزوده';

  @override
  String get checkoutShippingLabel => 'ارسال';

  @override
  String get checkoutPleaseSelectCargoCompany =>
      'لطفاً یک شرکت حمل‌ونقل را انتخاب کنید';

  @override
  String get checkoutEnterNameSurname => 'نام و نام خانوادگی را وارد کنید';

  @override
  String get checkoutEnterValidEmail => 'ایمیل معتبر وارد کنید';

  @override
  String get checkoutEnterValidPhone => 'شماره تلفن معتبر وارد کنید';

  @override
  String get checkoutEnterCity => 'شهر را وارد کنید';

  @override
  String get checkoutEnterDistrict => 'منطقه را وارد کنید';

  @override
  String get checkoutEnterFullAddress => 'آدرس کامل را وارد کنید';

  @override
  String get checkoutEnterValidIdentityNumber => 'شماره ملی معتبر وارد کنید';

  @override
  String get checkoutEnterCompanyName => 'نام شرکت را وارد کنید';

  @override
  String get checkoutEnterValidTaxNumber => 'شماره مالیاتی معتبر وارد کنید';

  @override
  String get checkoutEnterTaxOffice => 'اداره مالیات را وارد کنید';

  @override
  String get checkoutAcceptRequiredAgreements => 'توافق‌های الزامی را بپذیرید';

  @override
  String get checkoutPaymentPageOpenedMessage =>
      'صفحه پرداخت باز شد. پرداخت را کامل کنید و سپس به برنامه برگردید.';

  @override
  String get checkoutBackButton => 'بازگشت';

  @override
  String get checkoutProceedToPayment => 'رفتن به پرداخت';

  @override
  String get checkoutContinueButton => 'ادامه';

  @override
  String get checkoutPaymentCompletedSuccessfully =>
      'پرداخت با موفقیت انجام شد';

  @override
  String get checkoutPaymentCancelledOrIncomplete =>
      'پرداخت لغو شد یا تکمیل نشد';

  @override
  String checkoutFailed(Object error) {
    return 'پرداخت ناموفق بود: $error';
  }

  @override
  String adoptionRequestSent(Object dogName) {
    return 'درخواست پذیرش برای $dogName ارسال شد!';
  }

  @override
  String get adoptionCentersTitle => 'مراکز پذیرش';

  @override
  String get availableDogsTitle => 'سگ‌های موجود';

  @override
  String get noAdoptionCentersAvailable => 'هیچ مرکز پذیرشی موجود نیست';

  @override
  String get noDogsAvailableInThisCenter => 'هیچ سگی در این مرکز موجود نیست';

  @override
  String get adoptionRequestTitle => 'درخواست پذیرش';

  @override
  String get yourPhone => 'شماره تلفن شما';

  @override
  String get whyDoYouWantToAdopt => 'چرا می‌خواهید پذیرش کنید؟';

  @override
  String get appointmentTitle => 'نوبت';

  @override
  String get cancelAppointmentButton => 'لغو نوبت';

  @override
  String get cancelAppointmentTitle => 'نوبت لغو شود؟';

  @override
  String get cancelAppointmentConfirmation =>
      'آیا مطمئن هستید که می‌خواهید این نوبت را لغو کنید؟';

  @override
  String get keepAppointmentButton => 'نگه‌داشتن نوبت';

  @override
  String get appointmentCancelled => 'نوبت لغو شد';

  @override
  String get cancellationNotAllowed => 'لغو برای این نوبت مجاز نیست.';

  @override
  String get cancelAppointmentFailed =>
      'لغو نوبت ممکن نبود. لطفاً دوباره تلاش کنید.';

  @override
  String get selectService => 'انتخاب خدمت';

  @override
  String get selectPet => 'انتخاب حیوان';

  @override
  String get dateAndTime => 'تاریخ و زمان';

  @override
  String get notesOptional => 'یادداشت‌ها (اختیاری)';

  @override
  String get selectDate => 'انتخاب تاریخ';

  @override
  String get selectTime => 'انتخاب زمان';

  @override
  String get appointmentNoteHint => 'یک یادداشت برای کلینیک اضافه کنید...';

  @override
  String get requestAppointment => 'درخواست نوبت';

  @override
  String get requestSentTitle => 'درخواست ارسال شد 🐾';

  @override
  String get requestSentMessage => 'درخواست نوبت شما به کلینیک ارسال شد.';

  @override
  String get okButton => 'OK';

  @override
  String get somethingWentWrong => 'مشکلی پیش آمد';

  @override
  String get alreadyBookedAtThisTime =>
      'شما در این زمان از قبل رزرو دارید. لطفاً زمان دیگری انتخاب کنید.';

  @override
  String get invalidBookingData =>
      'داده‌های رزرو نامعتبر است. لطفاً دوباره تلاش کنید.';

  @override
  String get serviceDefaultLabel => 'خدمت';

  @override
  String get ageYearsSuffix => ' سال';

  @override
  String get overviewTitle => 'نمای کلی';

  @override
  String get servicesTitle => 'خدمات';

  @override
  String get reviewsTitle => 'نظرات';

  @override
  String get galleryTitle => 'گالری';

  @override
  String get shopTitle => 'فروشگاه';

  @override
  String get aboutTitle => 'درباره';

  @override
  String get workingHoursTitle => 'ساعات کاری';

  @override
  String get locationTitle => 'موقعیت';

  @override
  String get instagramTitle => 'اینستاگرام';

  @override
  String get noClinicDescriptionAvailable => 'توضیحی برای کلینیک موجود نیست.';

  @override
  String get instagramNotAvailable => 'اینستاگرام موجود نیست.';

  @override
  String get workingHoursNotAvailable => 'ساعات کاری موجود نیست';

  @override
  String get openStatusOpen => 'باز';

  @override
  String get openStatusClosingSoon => 'به‌زودی بسته می‌شود';

  @override
  String get openStatusClosed => 'بسته';

  @override
  String get mostRelevant => 'مرتبط‌ترین';

  @override
  String get newest => 'جدیدترین';

  @override
  String get bookAppointment => 'رزرو نوبت';

  @override
  String get noServicesAvailable => 'خدمتی موجود نیست';

  @override
  String errorLoadingServices(Object error) {
    return 'خطا در بارگذاری خدمات: $error';
  }

  @override
  String get noServicesProvided => 'خدمتی ارائه نشده است.';

  @override
  String reviewsCountLabel(Object count) {
    return '$count نظر';
  }

  @override
  String get topLabel => 'برتر';

  @override
  String get mostHelpful => 'مفیدترین';

  @override
  String get couldNotUpdateLike => 'به‌روزرسانی پسند ممکن نبود';

  @override
  String get justNow => 'همین الان';

  @override
  String get noReviewsYet => 'هنوز نظری ثبت نشده است';

  @override
  String get beFirstToReview => 'اولین نظر را شما بنویسید';

  @override
  String get submit => 'ارسال';

  @override
  String get writeAReview => 'نوشتن نظر';

  @override
  String get shareYourExperienceHint => 'تجربه خود را به اشتراک بگذارید...';

  @override
  String get pleaseWriteSomething => 'لطفاً چیزی بنویسید';

  @override
  String get pleaseLoginFirst => 'لطفاً ابتدا وارد شوید';

  @override
  String get alreadyReviewedThisVet =>
      'شما قبلاً این دامپزشک را بررسی کرده‌اید';

  @override
  String get errorSubmittingReview => 'خطا در ارسال نظر';

  @override
  String errorLoadingReviews(Object error) {
    return 'خطا در بارگذاری نظرات: $error';
  }

  @override
  String get galleryNotAvailable => 'گالری موجود نیست.';

  @override
  String get noGalleryMediaYet => 'هنوز رسانه‌ای در گالری نیست.';

  @override
  String get shopSectionComingSoon => 'بخش فروشگاه به‌زودی اضافه می‌شود.';

  @override
  String durationMinutesShort(Object minutes) {
    return '$minutes دقیقه';
  }

  @override
  String get myProfile => 'پروفایل من';

  @override
  String get userProfile => 'پروفایل کاربر';

  @override
  String get profileInformation => 'اطلاعات پروفایل';

  @override
  String get myDogs => 'سگ‌های من';

  @override
  String get dogsAvailableForAdoption => 'سگ‌های موجود برای پذیرش';

  @override
  String get editProfile => 'ویرایش پروفایل';

  @override
  String get usernameLabel => 'نام کاربری';

  @override
  String get emailLabel => 'ایمیل';

  @override
  String get phoneLabel => 'شماره تلفن';

  @override
  String get enterPhoneNumberOptional => 'شماره تلفن را وارد کنید (اختیاری)';

  @override
  String get deleteAccount => 'حذف حساب';

  @override
  String get deleteAccountConfirmation =>
      'آیا مطمئن هستید که می‌خواهید حساب خود را حذف کنید؟ این عمل قابل بازگشت نیست.';

  @override
  String get updateProfile => 'به‌روزرسانی پروفایل';

  @override
  String get editProfileTooltip => 'ویرایش پروفایل';

  @override
  String get deleteAccountTooltip => 'حذف حساب';

  @override
  String get logoutTooltip => 'خروج';

  @override
  String get noDogsAvailableForAdoption => 'هیچ سگی برای پذیرش موجود نیست.';

  @override
  String get unknownUser => 'کاربر ناشناس';

  @override
  String get notProvided => 'ارائه نشده';

  @override
  String get noDogsAddedYet => 'هنوز هیچ سگی اضافه نشده است.';

  @override
  String get appTitle => 'بارکی مچز';

  @override
  String get loadingUserData => 'در حال بارگذاری اطلاعات کاربر...';

  @override
  String get welcomeToPetSopu => 'به بارکی مچز خوش آمدید!';

  @override
  String get welcomeTo => 'خوش آمدید به';

  @override
  String get petSopu => 'بارکی مچز';

  @override
  String welcomeBack(Object username) {
    return 'خوش آمدید، $username!';
  }

  @override
  String helloMessage(Object username) {
    return 'سلام، $username!';
  }

  @override
  String get signInTitle => 'ورود';

  @override
  String get signUpTitle => 'ثبت‌نام';

  @override
  String get signInButton => 'ورود';

  @override
  String get signUpButton => 'ثبت‌نام';

  @override
  String get continueAsGuest => 'ادامه به‌عنوان مهمان';

  @override
  String get passwordLabel => 'رمز عبور';

  @override
  String get confirmPasswordLabel => 'تأیید رمز عبور';

  @override
  String get rememberMeLabel => 'مرا به خاطر بسپار';

  @override
  String get forgotPasswordLabel => 'رمز عبور را فراموش کردید؟';

  @override
  String get termsAndConditionsLabel => 'شرایط و ضوابط را می‌پذیرم';

  @override
  String get termsAndConditionsPrefix => 'می‌پذیرم: ';

  @override
  String get termsAndConditionsText => 'شرایط و ضوابط';

  @override
  String get receiveNewsLabel => 'دریافت اخبار و به‌روزرسانی‌ها';

  @override
  String get emailRequired => 'لطفاً ایمیل خود را وارد کنید';

  @override
  String get emailInvalid => 'لطفاً یک ایمیل معتبر وارد کنید';

  @override
  String get usernameRequired => 'لطفاً نام کاربری خود را وارد کنید';

  @override
  String get phoneRequired => 'لطفاً شماره تلفن خود را وارد کنید';

  @override
  String get phoneNumberTooShort => 'شماره تلفن خیلی کوتاه است';

  @override
  String get phoneMinDigits => 'شماره تلفن باید حداقل ۱۰ رقم باشد';

  @override
  String get passwordRequired => 'لطفاً رمز عبور خود را وارد کنید';

  @override
  String get passwordValidation =>
      'رمز عبور باید حداقل ۸ کاراکتر باشد و شامل حروف و اعداد باشد';

  @override
  String get passwordMismatch => 'رمزهای عبور مطابقت ندارند';

  @override
  String get confirmPasswordRequired => 'لطفاً رمز عبور خود را تأیید کنید';

  @override
  String get termsRequired => 'باید شرایط و ضوابط را بپذیرید';

  @override
  String get forgotPasswordDialogTitle => 'فراموشی رمز عبور';

  @override
  String get forgotPasswordDialogMessage =>
      'لطفاً ایمیل خود را برای بازنشانی رمز عبور وارد کنید.';

  @override
  String get sendButton => 'ارسال';

  @override
  String passwordResetSent(Object email) {
    return 'ایمیل بازنشانی رمز عبور به $email ارسال شد';
  }

  @override
  String get emailAddressHint => 'آدرس ایمیل';

  @override
  String get passwordResetEmailSent => 'ایمیل بازنشانی رمز عبور ارسال شد 📩';

  @override
  String get noAccountSignUp => 'حساب ندارید؟ ثبت‌نام کنید';

  @override
  String get haveAccountSignIn => 'قبلاً حساب دارید؟ وارد شوید';

  @override
  String get userNotFound =>
      'کاربری با این ایمیل یافت نشد. لطفاً ثبت‌نام کنید.';

  @override
  String get authUserNotFound => 'کاربر یافت نشد';

  @override
  String get pleaseVerifyEmailBeforeSigningIn =>
      'لطفاً قبل از ورود ایمیل خود را تأیید کنید.';

  @override
  String get userCreationFailed => 'ایجاد کاربر ناموفق بود';

  @override
  String get verificationEmailCouldNotBeSent => 'ایمیل تأیید ارسال نشد';

  @override
  String get verificationSessionCouldNotBeCreated => 'نشست تأیید ایجاد نشد';

  @override
  String get emailAlreadyRegisteredTryLoggingIn =>
      'این ایمیل قبلاً ثبت شده است. ورود را امتحان کنید.';

  @override
  String get incorrectPassword =>
      'رمز عبور نادرست است. لطفاً دوباره امتحان کنید.';

  @override
  String get fillAllFields => 'لطفاً همه فیلدها را به درستی پر کنید';

  @override
  String errorOccurred(Object error) {
    return 'خطایی رخ داد: $error';
  }

  @override
  String get verifyEmailTitle => 'ایمیل خود را تأیید کنید';

  @override
  String get enterVerificationCodeSentToEmail =>
      'کد تأیید ارسال‌شده به ایمیل خود را وارد کنید';

  @override
  String get pleaseEnterSixDigitCode => 'لطفاً کد ۶ رقمی را وارد کنید';

  @override
  String get emailVerifiedSuccessfully => 'ایمیل با موفقیت تأیید شد';

  @override
  String get invalidVerificationCode => 'کد تأیید نامعتبر است';

  @override
  String verificationCodeSent(Object email) {
    return 'کد تأیید به $email ارسال شد';
  }

  @override
  String get enterCodeLabel => 'کد ۶ رقمی را وارد کنید';

  @override
  String get verifyButton => 'تأیید';

  @override
  String get authWelcomeBackSubtitle => 'به BarkyMatches خوش برگشتید';

  @override
  String get authCreateAccountSubtitle => 'حساب BarkyMatches خود را بسازید';

  @override
  String get sessionExpiredPleaseSignInAgain =>
      'نشست شما منقضی شد. لطفاً دوباره وارد شوید.';

  @override
  String get signInToAccessPlaymate => 'لطفاً برای دسترسی به پلی‌میت وارد شوید';

  @override
  String get findPlaymates => 'دوست پیدا کن';

  @override
  String get signInToFindFriends => 'برای پتت دوست پیدا کن';

  @override
  String get addYourDog => 'سگ خود را اضافه کنید';

  @override
  String get nameLabel => 'نام *';

  @override
  String get pleaseEnterDogName => 'لطفاً نام سگ خود را وارد کنید';

  @override
  String get selectBreedHint => 'انتخاب نژاد';

  @override
  String get pleaseSelectBreed => 'لطفاً یک نژاد انتخاب کنید';

  @override
  String get ageLabel => 'سن *';

  @override
  String get pleaseEnterDogAge => 'لطفاً سن سگ خود را وارد کنید';

  @override
  String get pleaseEnterValidAge => 'لطفاً یک سن معتبر وارد کنید';

  @override
  String get selectGenderHint => 'انتخاب جنسیت';

  @override
  String get pleaseSelectGender => 'لطفاً یک جنسیت انتخاب کنید';

  @override
  String get selectHealthStatusHint => 'انتخاب وضعیت سلامتی';

  @override
  String get pleaseSelectHealthStatus => 'لطفاً یک وضعیت سلامتی انتخاب کنید';

  @override
  String get neuteredLabel => 'عقیم‌سازی *';

  @override
  String get yes => 'بله';

  @override
  String get no => 'خیر';

  @override
  String get pleaseSpecifyNeutered => 'لطفاً مشخص کنید که آیا سگ عقیم شده است';

  @override
  String get traitsLabel => 'ویژگی‌ها *';

  @override
  String get pleaseSelectAtLeastOneTrait => 'لطفاً حداقل یک ویژگی انتخاب کنید';

  @override
  String get selectOwnerGenderHint => 'جنسیت صاحب';

  @override
  String get pleaseSelectOwnerGender => 'لطفاً جنسیت خود را انتخاب کنید';

  @override
  String get uploadImagesLabel => 'بارگذاری تصاویر';

  @override
  String get pickFromGallery => 'انتخاب از گالری';

  @override
  String get takePhoto => 'گرفتن عکس';

  @override
  String get availableForAdoption => 'قابل پذیرش';

  @override
  String get descriptionLabel => 'توضیحات';

  @override
  String get descriptionPlaceholder => 'اینجا توضیحات را وارد کنید...';

  @override
  String get colorLabel => 'رنگ';

  @override
  String get weightLabel => 'وزن (کیلوگرم)';

  @override
  String get selectCollarTypeHint => 'انتخاب نوع قلاده';

  @override
  String get clothingColorLabel => 'رنگ لباس';

  @override
  String get lostLocationLabel => 'مکان گم شدن *';

  @override
  String get foundLocationLabel => 'مکان یافتن *';

  @override
  String get contactInfoLabel => 'اطلاعات تماس *';

  @override
  String get editDog => 'ویرایش سگ';

  @override
  String get photosLabel => 'عکس‌ها';

  @override
  String get chooseFromGallery => 'انتخاب از گالری';

  @override
  String get takeAPhoto => 'گرفتن عکس';

  @override
  String get noMedia => 'رسانه‌ای وجود ندارد';

  @override
  String get save => 'ذخیره';

  @override
  String dogNameAlreadyExists(Object name) {
    return 'سگی با نام $name قبلاً وجود دارد!';
  }

  @override
  String get locationRequired => 'مکان برای افزودن سگ الزامی است.';

  @override
  String errorUploadingImage(Object error) {
    return 'خطا در بارگذاری تصویر: $error';
  }

  @override
  String errorAddingDog(Object error) {
    return 'خطا در افزودن سگ: $error';
  }

  @override
  String get pleaseFillRequiredFields =>
      'لطفاً تمام فیلدهای الزامی را به درستی پر کنید';

  @override
  String get addDogButton => 'افزودن سگ';

  @override
  String get dogDetailsAddTitle => 'افزودن سگ';

  @override
  String get dogDetailsEditTitle => 'ویرایش سگ';

  @override
  String get dogDetailsNameLabel => 'نام';

  @override
  String get dogDetailsAgeLabel => 'سن';

  @override
  String get dogDetailsDescriptionLabel => 'توضیحات';

  @override
  String get dogDetailsGenderLabel => 'جنسیت:';

  @override
  String get dogDetailsHealthLabel => 'وضعیت سلامتی:';

  @override
  String get dogDetailsTraitsLabel => 'ویژگی‌ها:';

  @override
  String get dogDetailsOwnerGenderLabel => 'جنسیت صاحب:';

  @override
  String get dogDetailsGenderMale => 'نر';

  @override
  String get dogDetailsGenderFemale => 'ماده';

  @override
  String get dogDetailsHealthHealthy => 'سالم';

  @override
  String get dogDetailsHealthNeedsCare => 'نیاز به مراقبت';

  @override
  String get dogDetailsHealthUnderTreatment => 'تحت درمان';

  @override
  String get dogDetailsOwnerGenderPreferNotToSay => 'ترجیح می‌دهم نگویم';

  @override
  String get dogDetailsPickImageButton => 'انتخاب تصویر';

  @override
  String get dogDetailsAddButton => 'افزودن سگ';

  @override
  String get dogDetailsUpdateButton => 'به‌روزرسانی سگ';

  @override
  String get dogDetailsNeuteredLabel => 'عقیم‌سازی:';

  @override
  String get dogDetailsAdoptionLabel => 'قابل پذیرش:';

  @override
  String get editDogPermissionDenied => 'شما اجازه ویرایش این سگ را ندارید.';

  @override
  String get editDogEnterName => 'لطفاً نام سگ را وارد کنید';

  @override
  String get editDogEnterValidAge => 'لطفاً یک سن معتبر وارد کنید';

  @override
  String get editDogOwnerGenderMale => 'مرد';

  @override
  String get editDogOwnerGenderFemale => 'زن';

  @override
  String get editDogOwnerGenderOther => 'سایر';

  @override
  String get findPlaymateTitle => 'یافتن هم‌بازی';

  @override
  String get noDogsMatchFilters => 'هیچ سگی با فیلترهای شما مطابقت ندارد.';

  @override
  String get adjustFiltersSuggestion =>
      'فیلترهای خود را تنظیم کنید یا فاصله را افزایش دهید.';

  @override
  String get anyGender => 'هرگونه';

  @override
  String distanceLabel(Object distance) {
    return 'فاصله: $distance کیلومتر';
  }

  @override
  String get resetFiltersButton => 'بازنشانی فیلترها';

  @override
  String get basketTitle => 'سبد';

  @override
  String basketItemsCount(Object count) {
    return '$count مورد';
  }

  @override
  String get yourBasketIsEmpty => 'سبد شما خالی است';

  @override
  String get sellerLabel => 'فروشنده';

  @override
  String get allProductsTitle => 'همه محصولات';

  @override
  String get sellerProductsTitle => 'محصولات فروشنده';

  @override
  String get searchProductsHint => 'جستجوی محصول، برند، فروشنده...';

  @override
  String get allCategoriesLabel => 'همه دسته‌ها';

  @override
  String get categoryLabel => 'دسته‌بندی';

  @override
  String get shippingLabel => 'ارسال';

  @override
  String get freeShippingLabel => 'ارسال رایگان';

  @override
  String get sellerPaysCargoLabel => 'هزینه ارسال با فروشنده';

  @override
  String get fixedCargoLabel => 'ارسال ثابت';

  @override
  String get calculatedCargoLabel => 'ارسال محاسبه‌شده';

  @override
  String get sortLabel => 'مرتب‌سازی';

  @override
  String get recommendedLabel => 'پیشنهادی';

  @override
  String get priceLowLabel => 'قیمت پایین';

  @override
  String get priceHighLabel => 'قیمت بالا';

  @override
  String get bestDiscountLabel => 'بهترین تخفیف';

  @override
  String productsCount(Object count) {
    return '$count محصول';
  }

  @override
  String get noProductsMatchFilters =>
      'هیچ محصولی با فیلترهای شما مطابقت ندارد';

  @override
  String errorLoadingProducts(Object error) {
    return 'خطا در بارگذاری محصولات: $error';
  }

  @override
  String get noActiveProductsFound => 'محصول فعالی پیدا نشد';

  @override
  String addedToBasket(Object productName) {
    return '$productName به سبد اضافه شد';
  }

  @override
  String get addButton => 'افزودن';

  @override
  String get freeCargoLabel => 'ارسال رایگان';

  @override
  String cargoPriceLabel(Object price) {
    return 'ارسال $price';
  }

  @override
  String get cargoCalculatedLabel => 'ارسال محاسبه‌شده';

  @override
  String freeOverLabel(Object price) {
    return 'رایگان برای بالای $price';
  }

  @override
  String vatRateLabel(Object percent) {
    return 'مالیات بر ارزش افزوده $percent٪';
  }

  @override
  String get vatIncludedLabel => 'شامل مالیات بر ارزش افزوده';

  @override
  String daysLabel(Object days) {
    return '$days روز';
  }

  @override
  String get inStockLabel => 'موجود';

  @override
  String get outOfStockLabel => 'ناموجود';

  @override
  String get subtotalLabel => 'جمع جزء';

  @override
  String get moreFiltersButton => 'فیلترهای بیشتر';

  @override
  String get petTypeLabel => 'نوع حیوان';

  @override
  String get petTypeDog => 'سگ';

  @override
  String get petTypeCat => 'گربه';

  @override
  String get petTypeBird => 'پرنده';

  @override
  String get petTypeHorse => 'اسب';

  @override
  String get genderOther => 'سایر';

  @override
  String get breedPersian => 'پرشین';

  @override
  String get breedSiamese => 'سیامی';

  @override
  String get breedMaineCoon => 'مین‌کون';

  @override
  String get breedBritishShorthair => 'بریتیش شورت‌هیر';

  @override
  String get breedParrot => 'طوطی';

  @override
  String get breedCanary => 'قناری';

  @override
  String get breedBudgerigar => 'عروس هلندی';

  @override
  String get breedArabian => 'عربی';

  @override
  String get breedThoroughbred => 'خالص‌نژاد';

  @override
  String get breedMustang => 'موستانگ';

  @override
  String get filterByBreed => 'فیلتر بر اساس نژاد';

  @override
  String get filterByGender => 'فیلتر بر اساس جنسیت';

  @override
  String get filterByAge => 'فیلتر بر اساس سن';

  @override
  String get filterByNeuteredStatus => 'فیلتر بر اساس وضعیت عقیم‌سازی';

  @override
  String get selectNeuteredStatusHint => 'انتخاب وضعیت عقیم‌سازی';

  @override
  String get filterByHealthStatus => 'فیلتر بر اساس وضعیت سلامتی';

  @override
  String get upgradeToPremiumForMoreFilters =>
      'برای فیلترهای بیشتر به نسخه پرمیوم ارتقا دهید!';

  @override
  String get upgradeToPremiumTitle => 'ارتقا به پرمیوم';

  @override
  String get upgradeToPremiumSubtitle =>
      'قابلیت‌های پیشرفته و ابزارهای کسب‌وکار را فعال کنید';

  @override
  String get apply => 'اعمال';

  @override
  String get favoritesPageTitle => 'سگ‌های مورد علاقه';

  @override
  String get noFavoriteDogsYet => 'هنوز هیچ سگ مورد علاقه‌ای وجود ندارد!';

  @override
  String get addFavoriteSuggestion =>
      'به صفحه اصلی برگردید و چند سگ به علاقه‌مندی‌های خود اضافه کنید.';

  @override
  String get removeFavoriteTooltip => 'حذف از علاقه‌مندی‌ها';

  @override
  String get schedulePlaydate => 'برنامه‌ریزی قرار بازی';

  @override
  String get selectDateAndTime => 'انتخاب تاریخ و زمان';

  @override
  String get pickDate => 'انتخاب تاریخ';

  @override
  String get pickTime => 'انتخاب زمان';

  @override
  String get selectYourDogHint => 'سگ خود را انتخاب کنید';

  @override
  String get selectFriendsDogHint => 'سگ دوست را انتخاب کنید';

  @override
  String get selectYourDog => 'سگ خود را انتخاب کنید';

  @override
  String get selectFriendsDog => 'سگ دوست را انتخاب کنید';

  @override
  String get pleaseLoginToSchedulePlaydate =>
      'لطفاً برای برنامه‌ریزی قرار بازی وارد شوید';

  @override
  String get selectLocation => 'انتخاب مکان';

  @override
  String get enterLocation =>
      'مکان را وارد کنید (مثال: عرض جغرافیایی: ۴۱.۰۱۰۳، طول جغرافیایی: ۲۸.۶۷۲۴ یا آدرس)';

  @override
  String get pickOnMap => 'انتخاب از روی نقشه';

  @override
  String get quickLocations => 'مکان‌های سریع';

  @override
  String get parkA => 'پارک الف';

  @override
  String get parkB => 'پارک ب';

  @override
  String get confirm => 'تأیید';

  @override
  String get cancel => 'لغو';

  @override
  String get pleaseSelectBothDogs => 'لطفاً هر دو سگ را انتخاب کنید';

  @override
  String get pleaseLoginToCreateRequest => 'لطفاً برای ایجاد درخواست وارد شوید';

  @override
  String get playdateRequestTitle => 'درخواست قرار بازی';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog می‌خواهد با $requestedDog بازی کند!';
  }

  @override
  String playdateRequestNotificationBody(
    Object requesterDog,
    Object requestedDog,
  ) {
    return '$requesterDog می‌خواهد با $requestedDog بازی کند!';
  }

  @override
  String get requestCreatedSuccess => 'درخواست با موفقیت ایجاد شد';

  @override
  String errorCreatingRequest(Object error) {
    return 'خطا در ایجاد درخواست: $error';
  }

  @override
  String playdateScheduled(Object dogName, Object dateTime, Object location) {
    return 'قرار بازی با $dogName برای $dateTime در $location برنامه‌ریزی شد!';
  }

  @override
  String get newPlaydateRequestTitle => 'درخواست قرار بازی جدید!';

  @override
  String newPlaydateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog می‌خواهد با $requestedDog بازی کند!';
  }

  @override
  String removedFromFavorites(Object dogName) {
    return '$dogName از علاقه‌مندی‌ها حذف شد!';
  }

  @override
  String addedToFavorites(Object dogName) {
    return '$dogName به علاقه‌مندی‌ها اضافه شد!';
  }

  @override
  String errorTogglingFavorite(Object error) {
    return 'خطا در تغییر وضعیت علاقه‌مندی: $error';
  }

  @override
  String chatWithOwner(Object dogName) {
    return 'چت با صاحب $dogName!';
  }

  @override
  String errorSchedulingPlaydate(Object error) {
    return 'خطا در برنامه‌ریزی قرار بازی: $error';
  }

  @override
  String get viewEditDogDetails => 'مشاهده/ویرایش جزئیات سگ';

  @override
  String editNotAllowed(Object dogName) {
    return 'اجازه ویرایش برای $dogName ندارید، onDogUpdated خالی است';
  }

  @override
  String editDialogOpen(Object dogName) {
    return 'دیالوگ ویرایش برای $dogName قبلاً باز شده یا در حال ویرایش است';
  }

  @override
  String openingEditDialog(Object dogName) {
    return 'باز کردن EditDogDialog برای $dogName';
  }

  @override
  String dogUpdatedInDialog(Object dogName) {
    return '$dogName در دیالوگ به‌روزرسانی شد';
  }

  @override
  String dialogPopped(Object dogName) {
    return 'دیالوگ با موفقیت برای $dogName بسته شد';
  }

  @override
  String updatedDogReturned(Object dogName) {
    return 'سگ به‌روزرسانی‌شده از دیالوگ برگشت: $dogName';
  }

  @override
  String errorInShowDialog(Object dogName, Object error) {
    return 'خطا در showDialog برای $dogName: $error';
  }

  @override
  String dialogClosed(Object isEditing, Object isDialogOpen) {
    return 'دیالوگ بسته شد، isEditing: $isEditing، isDialogOpen: $isDialogOpen';
  }

  @override
  String widgetNotMounted(Object isDialogOpen) {
    return 'ویجت مانت نشده، isDialogOpen به: $isDialogOpen بازنشانی شد';
  }

  @override
  String removedDislike(Object dogName) {
    return 'دیسلایک برای $dogName حذف شد!';
  }

  @override
  String addedDislike(Object dogName) {
    return '$dogName دیسلایک شد!';
  }

  @override
  String dislikeNotificationFailed(Object message) {
    return 'ارسال اعلان دیسلایک ناموفق بود: $message';
  }

  @override
  String ensureNotificationsEnabled(Object dogName) {
    return 'لطفاً مطمئن شوید که اعلان‌ها برای صاحب $dogName فعال است.';
  }

  @override
  String failedToDislike(Object message) {
    return 'دیسلایک ناموفق بود: $message';
  }

  @override
  String errorSendingDislike(Object error) {
    return 'خطا در ارسال اعلان دیسلایک: $error';
  }

  @override
  String disposing(Object dogName) {
    return 'در حال دفع برای $dogName';
  }

  @override
  String resetIsDialogOpen(Object isDialogOpen) {
    return 'بازنشانی isDialogOpen هنگام لغو: $isDialogOpen';
  }

  @override
  String get notifications => 'اعلان‌ها';

  @override
  String get playdateRequests => 'درخواست‌های قرار بازی';

  @override
  String get noNotifications => 'هنوز هیچ اعلانی وجود ندارد.';

  @override
  String get noPlaydateRequests => 'هنوز هیچ درخواست قرار بازی وجود ندارد.';

  @override
  String get accept => 'پذیرش';

  @override
  String get reject => 'رد';

  @override
  String get status => 'وضعیت';

  @override
  String get delete => 'حذف';

  @override
  String get rejectConfirmation => 'تأیید رد';

  @override
  String get areYouSure =>
      'آیا مطمئن هستید که می‌خواهید این درخواست را رد کنید؟';

  @override
  String get notificationDeleted => 'اعلان حذف شد';

  @override
  String errorDeletingNotification(Object error) {
    return 'خطا در حذف اعلان: $error';
  }

  @override
  String get notificationsSection => 'اعلان‌ها';

  @override
  String get playdateRequestsSection => 'درخواست‌های قرار بازی';

  @override
  String get noTitle => 'بدون عنوان';

  @override
  String get noBody => 'بدون متن';

  @override
  String get newLikeTitle => 'لایک جدید!';

  @override
  String newLikeBody(Object username, Object dogName) {
    return '$username سگ شما $dogName را لایک کرد!';
  }

  @override
  String get playDateCanceledTitle => 'درخواست قرار بازی لغو شد';

  @override
  String playDateCanceledBody(Object dogName) {
    return 'درخواست قرار بازی با $dogName لغو شد.';
  }

  @override
  String get playDateAcceptedTitle => 'درخواست قرار بازی پذیرفته شد!';

  @override
  String playDateAcceptedBodyRequester(Object dogName) {
    return 'شما درخواست قرار بازی با $dogName را پذیرفتید';
  }

  @override
  String playDateAcceptedBodyRequested(Object dogName, Object dateTime) {
    return '$dogName درخواست قرار بازی شما با $dogName را در $dateTime پذیرفت';
  }

  @override
  String get playDateRejectedTitle => 'درخواست قرار بازی رد شد';

  @override
  String playDateRejectedBodyRequester(Object dogName) {
    return 'شما درخواست قرار بازی با $dogName را رد کردید';
  }

  @override
  String playDateRejectedBodyRequested(Object dogName) {
    return '$dogName درخواست قرار بازی شما با $dogName را رد کرد';
  }

  @override
  String errorLoadingNotifications(Object error) {
    return 'خطا در به‌روزرسانی اعلان‌ها: $error';
  }

  @override
  String errorInitializingOrLoadingRequests(Object error) {
    return 'خطا در مقداردهی اولیه یا بارگذاری درخواست‌ها: $error';
  }

  @override
  String errorLoadingRequests(Object error) {
    return 'خطا در بارگذاری درخواست‌ها: $error';
  }

  @override
  String errorLoadingSpecificRequest(Object error) {
    return 'خطا در بارگذاری درخواست خاص: $error';
  }

  @override
  String errorLoadingNotificationsStream(Object error) {
    return 'خطا در بارگذاری جریان اعلان‌ها: $error';
  }

  @override
  String errorLoadingRequestsStream(Object error) {
    return 'خطا در بارگذاری جریان درخواست‌ها: $error';
  }

  @override
  String errorUpdatingStatus(Object error) {
    return 'خطا در به‌روزرسانی وضعیت: $error';
  }

  @override
  String errorUpdatingStatusUnexpected(Object error) {
    return 'خطای غیرمنتظره در به‌روزرسانی وضعیت: $error';
  }

  @override
  String get pleaseLoginToRespond => 'لطفاً برای پاسخ به درخواست‌ها وارد شوید';

  @override
  String requestStatusUpdated(Object status) {
    return 'وضعیت درخواست با موفقیت $status شد';
  }

  @override
  String errorRespondingToRequest(Object error) {
    return 'خطا در پاسخ به درخواست: $error';
  }

  @override
  String errorRespondingToRequestUnexpected(Object error) {
    return 'خطای غیرمنتظره در پاسخ به درخواست: $error';
  }

  @override
  String get pleaseLoginToAccept => 'لطفاً برای پذیرش درخواست‌ها وارد شوید';

  @override
  String get requestAcceptedSuccess =>
      'درخواست پذیرفته شد و به لیست قرارهای بازی اضافه شد.';

  @override
  String errorAcceptingRequest(Object error) {
    return 'خطا در پذیرش درخواست: $error';
  }

  @override
  String errorAcceptingRequestUnexpected(Object error) {
    return 'خطای غیرمنتظره در پذیرش درخواست: $error';
  }

  @override
  String get pleaseLoginToReject => 'لطفاً برای رد درخواست‌ها وارد شوید';

  @override
  String get requestRejectedSuccess => 'درخواست رد شد';

  @override
  String errorRejectingRequest(Object error) {
    return 'خطا در رد درخواست: $error';
  }

  @override
  String errorRejectingRequestUnexpected(Object error) {
    return 'خطای غیرمنتظره در رد درخواست: $error';
  }

  @override
  String get failedToScheduleReminder =>
      'عدم موفقیت در برنامه‌ریزی یادآور. لطفاً مجوزها را بررسی کنید.';

  @override
  String get scheduledLabel => 'برنامه‌ریزی‌شده:';

  @override
  String get pleaseLoginToViewPlaydateRequests =>
      'برای مشاهده درخواست‌های قرار بازی وارد شوید';

  @override
  String get pleaseLoginToSetReminders => 'لطفاً برای تنظیم یادآور وارد شوید.';

  @override
  String reminderSetForMinutesBefore(Object minutesBefore) {
    return 'یادآور برای $minutesBefore دقیقه قبل تنظیم شد 🐾';
  }

  @override
  String get failedToSetReminder => 'تنظیم یادآور ناموفق بود ❌';

  @override
  String get playdateAcceptedCardTitle => 'قرار بازی پذیرفته شد 🐾';

  @override
  String playdateAcceptedCardBody(Object dogName) {
    return '$dogName درخواست قرار بازی شما را پذیرفت.\nخوشحال باشید — یک دیدار با تکان دادن دم در انتظار است! 🐶💖';
  }

  @override
  String get playdateRejectedCardTitle => 'این بار نه';

  @override
  String playdateRejectedCardBody(Object dogName) {
    return '$dogName این بار نتوانست قبول کند.\nنگران نباشید — دوباره امتحان کنید و بگذارید پنجه‌ها در حرکت بمانند 🐾';
  }

  @override
  String get dogTab => 'سگ';

  @override
  String get reminderTab => 'یادآور';

  @override
  String get playdateTimeNotScheduledYet =>
      '⏳ زمان قرار بازی هنوز برنامه‌ریزی نشده است';

  @override
  String get thirtyMinutesBefore => '30 دقیقه قبل';

  @override
  String get oneHourBefore => '1 ساعت قبل';

  @override
  String get reminderSet => 'یادآور تنظیم شد ✅';

  @override
  String get viewLocation => 'مشاهده مکان';

  @override
  String get locationLabel => 'مکان:';

  @override
  String get unknownStatus => 'ناشناخته';

  @override
  String get unknownTime => 'زمان ناشناخته';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes دقیقه پیش';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours ساعت پیش';
  }

  @override
  String daysAgo(Object days) {
    return '$days روز پیش';
  }

  @override
  String get notScheduled => 'برنامه‌ریزی‌نشده';

  @override
  String get upcomingPlaydateTitle => 'قرار بازی آینده';

  @override
  String upcomingPlaydateBodyRequester(Object dogName) {
    return 'شما ۲ ساعت دیگر با $dogName قرار بازی دارید!';
  }

  @override
  String upcomingPlaydateBodyRequested(Object dogName) {
    return 'شما ۲ ساعت دیگر با $dogName قرار بازی دارید!';
  }

  @override
  String get appFeatures => 'با برنامه ما می‌توانید:';

  @override
  String get appFeaturesMessage => 'با برنامه ما می‌توانید:';

  @override
  String get playmateService => 'پلی‌میت';

  @override
  String get playmateSearchHint => 'جستجوی سگ‌ها...';

  @override
  String get playmateLocationNeededTitle => 'موقعیت لازم است';

  @override
  String get playmateLocationNeededMessage =>
      'برای نمایش سگ‌های نزدیک از موقعیت شما استفاده می‌کنیم';

  @override
  String get playmateFiltersTitle => 'فیلترها';

  @override
  String get playmateBreedPremiumHint => 'نژاد (Gold)';

  @override
  String get playmateOwnerGenderPremiumHint => 'جنسیت صاحب (Premium)';

  @override
  String get vetServices => 'خدمات دامپزشکی';

  @override
  String get adoptionService => 'پذیرش';

  @override
  String get dogTrainingService => 'آموزش سگ';

  @override
  String get dogParkService => 'پارک سگ';

  @override
  String get findFriendsService => 'یافتن دوستان';

  @override
  String get getStarted => 'شروع کنید';

  @override
  String get dogTraining => 'آموزش سگ';

  @override
  String get dogPark => 'پارک سگ';

  @override
  String get findFriends => 'یافتن دوستان';

  @override
  String get dogTrainingComingSoon => 'آموزش سگ به زودی!';

  @override
  String get lostDogsComingSoon => 'سگ‌های گمشده به زودی!';

  @override
  String get petShopsComingSoon => 'فروشگاه‌های حیوانات به زودی!';

  @override
  String get hospitalsComingSoon => 'بیمارستان‌ها به زودی!';

  @override
  String get findFriendsComingSoon => 'یافتن دوستان به زودی!';

  @override
  String get menuTitle => 'منو';

  @override
  String get homeMenuItem => 'خانه';

  @override
  String get myDogsMenuItem => 'سگ‌های من';

  @override
  String get favoritesMenuItem => 'علاقه‌مندی‌ها';

  @override
  String get adoptionCenterMenuItem => 'مرکز پذیرش';

  @override
  String get dogParkMenuItem => 'پارک سگ';

  @override
  String get reportLostDogMenuItem => 'گزارش سگ گمشده';

  @override
  String get lostDogsMenuItem => 'سگ‌های گمشده';

  @override
  String get reportFoundDogMenuItem => 'گزارش سگ پیدا شده';

  @override
  String get foundDogsMenuItem => 'سگ‌های پیدا شده';

  @override
  String get petShopsMenuItem => 'فروشگاه‌های حیوانات';

  @override
  String get hospitalsMenuItem => 'بیمارستان‌ها';

  @override
  String get logoutMenuItem => 'خروج';

  @override
  String get filterDogsMenuItem => 'فیلتر سگ‌ها';

  @override
  String get homeNavItem => 'خانه';

  @override
  String get favoritesNavItem => 'علاقه‌مندی‌ها';

  @override
  String get visitVetNavItem => 'بازدید از دامپزشک';

  @override
  String get playdateNavItem => 'قرار بازی';

  @override
  String get profileNavItem => 'پروفایل';

  @override
  String get notificationsTooltip => 'اعلان‌ها';

  @override
  String get chatTooltip => 'چت';

  @override
  String get chatNotImplemented => 'قابلیت چت هنوز پیاده‌سازی نشده است';

  @override
  String get dogParkTitle => 'پارک‌های سگ';

  @override
  String dogParkDateLabel(Object date) {
    return 'تاریخ: $date';
  }

  @override
  String get dogParkLoadMarkers => 'بارگذاری نشانگرهای پارک';

  @override
  String get dogParkMoveToMarkers => 'انتقال به نشانگرها';

  @override
  String get dogParkPermissionDenied =>
      'اجازه مکان رد شد. لطفاً آن را در تنظیمات فعال کنید.';

  @override
  String get dogParkBackgroundPermissionDenied =>
      'اجازه مکان پس‌زمینه رد شد. برخی قابلیت‌ها ممکن است محدود شوند.';

  @override
  String get dogParkLocationServicesDisabled => 'خدمات مکان غیرفعال است.';

  @override
  String get dogParkEnableLocationServices =>
      'لطفاً خدمات مکان را برای ادامه فعال کنید.';

  @override
  String get dogParkPermissionDeniedPermanent =>
      'اجازه مکان به صورت دائمی رد شد.';

  @override
  String get dogParkPermissionsDenied =>
      'اجازه‌های مکان به صورت دائمی رد شده‌اند. لطفاً آن‌ها را از تنظیمات فعال کنید.';

  @override
  String dogParkLocationError(Object error) {
    return 'خطا در دریافت مکان: $error';
  }

  @override
  String get dogParkPermissionRequired =>
      'اجازه مکان برای نمایش پارک‌های سگ نزدیک الزامی است.';

  @override
  String get dogParkRecommendedBadge => '⭐ پیشنهادی';

  @override
  String get dogParkPremiumBadge => '🔒 پریمیوم';

  @override
  String get dogParkSavedBadge => '❤️ ذخیره شد';

  @override
  String get dogParkRecommendedForPlaydates =>
      'برای قرارهای بازی پیشنهاد می‌شود';

  @override
  String get dogParkSavedToFavorites => 'در علاقه‌مندی‌ها ذخیره شد';

  @override
  String get dogParkSaveThisPark => 'این پارک را ذخیره کنید';

  @override
  String get dogParkGetDirections => 'مسیر را نشان بده';

  @override
  String get dogParkUserNotReadyYet =>
      'کاربر هنوز آماده نیست. لطفاً دوباره تلاش کنید.';

  @override
  String get dogParkNeedToAddDogFirst => 'ابتدا باید یک سگ اضافه کنید';

  @override
  String get dogParkSchedulePlaydateHere =>
      'در اینجا قرار بازی را برنامه‌ریزی کنید';

  @override
  String get dogParkSavedParksTitle => 'پارک‌های ذخیره‌شده';

  @override
  String get dogParkNoSavedParksYet => 'هنوز پارک ذخیره‌شده‌ای نیست';

  @override
  String get dogParkFindNearbyParks => 'پارک‌های نزدیک را پیدا کنید';

  @override
  String get dogParkLocationNeededTitle => 'موقعیت لازم است';

  @override
  String get dogParkUseYourLocationToShowNearbyDogParks =>
      'برای نمایش پارک‌های سگ نزدیک از موقعیت شما استفاده می‌کنیم';

  @override
  String get allowButton => 'اجازه دادن';

  @override
  String get dogParkBackgroundRecommended =>
      'اجازه مکان پس‌زمینه توصیه می‌شود. لطفاً آن را در تنظیمات فعال کنید.';

  @override
  String get dogParkSettingsAction => 'تنظیمات';

  @override
  String dogParkDistanceLabel(Object distance) {
    return 'فاصله: $distance کیلومتر';
  }

  @override
  String get dogViewTitle => 'جزئیات سگ';

  @override
  String get dogViewNameLabel => 'نام:';

  @override
  String get dogViewBreedLabel => 'نژاد:';

  @override
  String get dogViewAgeLabel => 'سن:';

  @override
  String get dogViewGenderLabel => 'جنسیت:';

  @override
  String get dogViewHealthLabel => 'سلامتی:';

  @override
  String get dogViewNeuteredLabel => 'عقیم‌سازی:';

  @override
  String get dogViewDescriptionLabel => 'توضیحات:';

  @override
  String get dogViewTraitsLabel => 'ویژگی‌ها:';

  @override
  String get dogViewOwnerGenderLabel => 'جنسیت صاحب:';

  @override
  String get dogViewAvailableLabel => 'قابل پذیرش:';

  @override
  String get dogViewYes => 'بله';

  @override
  String get dogViewNo => 'خیر';

  @override
  String get dogViewLikeTooltip => 'لایک';

  @override
  String get dogViewDislikeTooltip => 'دیسلایک';

  @override
  String get dogViewAddFavoriteTooltip => 'اضافه کردن به علاقه‌مندی‌ها';

  @override
  String get dogViewChatTooltip => 'چت';

  @override
  String get dogViewScheduleDate => 'برنامه‌ریزی تاریخ';

  @override
  String get dogViewAdoption => 'پذیرش';

  @override
  String get dogViewChatStarted => 'چت شروع شد!';

  @override
  String dogViewPlayDateScheduled(
    Object day,
    Object month,
    Object year,
    Object time,
  ) {
    return 'قرار بازی برای $day/$month/$year در ساعت $time برنامه‌ریزی شد!';
  }

  @override
  String get dogViewAdoptionRequest => 'درخواست پذیرش ارسال شد!';

  @override
  String get distanceUnknown => 'فاصله نامشخص است';

  @override
  String boostDogTitle(Object dogName) {
    return 'ارتقای $dogName';
  }

  @override
  String get boostVisibilityDescription =>
      'در جست‌وجوی Playmates بیشتر دیده شوید.';

  @override
  String get boost24HoursTitle => 'ارتقای 24 ساعته';

  @override
  String get boostQuickVisibilitySubtitle => 'برای دیده شدن سریع مناسب است';

  @override
  String get boostPrice29 => '₺29';

  @override
  String get boost3DaysTitle => 'ارتقای 3 روزه';

  @override
  String get boostBetterExposureSubtitle => 'نمایش بهتر برای جست‌وجوی فعال';

  @override
  String get boostPrice69 => '₺69';

  @override
  String get boost7DaysTitle => 'ارتقای 7 روزه';

  @override
  String get boostBestValueSubtitle => 'بهترین ارزش برای بیشترین دسترسی';

  @override
  String get boostPrice129 => '₺129';

  @override
  String get boostActivated => 'ارتقا فعال شد 🚀';

  @override
  String boostFailed(Object error) {
    return 'ارتقا ناموفق بود: $error';
  }

  @override
  String get errorOpeningEdit => 'خطا در باز کردن ویرایش';

  @override
  String get boostBadge => 'BOOSTED';

  @override
  String get boostButton => 'ارتقا';

  @override
  String get blockComingSoon => 'قابلیت مسدودسازی به‌زودی می‌آید';

  @override
  String get blockMenuItem => 'مسدود کردن کاربر';

  @override
  String get sendAdoptionRequest => 'ارسال درخواست پذیرش';

  @override
  String ownerPrefix(Object owner) {
    return 'صاحب: $owner';
  }

  @override
  String get submitComplaintMenuItem => 'ارسال شکایت';

  @override
  String get dogInfoTitle => 'اطلاعات سگ';

  @override
  String get dogInfoBreedLabel => 'نژاد:';

  @override
  String get dogInfoAgeLabel => 'سن:';

  @override
  String get dogInfoGenderLabel => 'جنسیت:';

  @override
  String get dogInfoHealthLabel => 'وضعیت سلامتی:';

  @override
  String get dogInfoNeuteredLabel => 'عقیم‌سازی:';

  @override
  String get dogInfoDescriptionLabel => 'توضیحات:';

  @override
  String get dogInfoTraitsLabel => 'ویژگی‌ها:';

  @override
  String get dogInfoOwnerGenderLabel => 'جنسیت صاحب:';

  @override
  String get dogInfoYes => 'بله';

  @override
  String get dogInfoNo => 'خیر';

  @override
  String get dogInfoLikeTooltip => 'لایک';

  @override
  String get dogInfoDislikeTooltip => 'دیسلایک';

  @override
  String get dogInfoChatTooltip => 'چت';

  @override
  String get dogInfoAddFavoriteTooltip => 'اضافه کردن به علاقه‌مندی‌ها';

  @override
  String get dogInfoSchedulePlaydateTooltip => 'برنامه‌ریزی قرار بازی';

  @override
  String dogInfoPlaydateScheduled(Object dogName) {
    return 'قرار بازی با $dogName برنامه‌ریزی شد!';
  }

  @override
  String dogInfoLiked(Object dogName) {
    return '$dogName را لایک کردید!';
  }

  @override
  String dogInfoDisliked(Object dogName) {
    return '$dogName را دیسلایک کردید!';
  }

  @override
  String dogInfoChatWithOwner(Object dogName) {
    return 'چت با صاحب $dogName!';
  }

  @override
  String dogInfoRemovedFavorite(Object dogName) {
    return '$dogName از علاقه‌مندی‌ها حذف شد!';
  }

  @override
  String dogInfoAddedFavorite(Object dogName) {
    return '$dogName به علاقه‌مندی‌ها اضافه شد!';
  }

  @override
  String get noDogsFound => 'هیچ سگی یافت نشد';

  @override
  String get noDogsForUser => 'هیچ سگی برای این کاربر یافت نشد.';

  @override
  String get dogsOfThisUser => 'سگ‌های این کاربر';

  @override
  String get playDateStatus_pending => 'در انتظار';

  @override
  String get playDateStatus_accepted => 'پذیرفته‌شده';

  @override
  String get playDateStatus_rejected => 'ردشده';

  @override
  String get locationServicesDisabled =>
      'خدمات مکان غیرفعال است. استفاده از مکان پیش‌فرض.';

  @override
  String get locationPermissionRequired =>
      'اجازه مکان الزامی است. استفاده از مکان پیش‌فرض.';

  @override
  String get locationPermissionPermanentlyDenied =>
      'اجازه مکان به صورت دائمی رد شده است. استفاده از مکان پیش‌فرض.';

  @override
  String errorGettingLocation(Object error) {
    return 'خطا در دریافت مکان: $error';
  }

  @override
  String errorLoadingData(Object error) {
    return 'خطا در بارگذاری داده‌ها: $error';
  }

  @override
  String errorLoadingOffers(Object error) {
    return 'خطا در بارگذاری پیشنهادها: $error';
  }

  @override
  String errorApplyingFilters(Object error) {
    return 'خطا در اعمال فیلترها: $error';
  }

  @override
  String get notificationChannelName => 'اعلان‌های با اهمیت بالا';

  @override
  String get notificationChannelDescription =>
      'این کانال برای اعلان‌های مهم استفاده می‌شود.';

  @override
  String get openAppAction => 'باز کردن برنامه';

  @override
  String get dismissAction => 'رد کردن';

  @override
  String get adoptionCenter => 'مرکز پذیرش';

  @override
  String get traitEnergetic => 'پر انرژی';

  @override
  String get traitPlayful => 'بازیگوش';

  @override
  String get traitCalm => 'آرام';

  @override
  String get traitLoyal => 'وفادار';

  @override
  String get traitFriendly => 'دوستانه';

  @override
  String get traitProtective => 'محافظ';

  @override
  String get traitIntelligent => 'باهوش';

  @override
  String get traitAffectionate => 'مهربان';

  @override
  String get traitCurious => 'کنجکاو';

  @override
  String get traitIndependent => 'مستقل';

  @override
  String get traitShy => 'خجالتی';

  @override
  String get traitTrained => 'آموزش‌دیده';

  @override
  String get traitSocial => 'اجتماعی';

  @override
  String get traitGoodWithKids => 'خوب با کودکان';

  @override
  String get breedAfghanHound => 'سگ افغانی';

  @override
  String get breedAiredaleTerrier => 'آیردیل تریر';

  @override
  String get breedAkita => 'آکیتا';

  @override
  String get breedAlaskanMalamute => 'مالاموت آلاسکایی';

  @override
  String get breedAmericanBulldog => 'بولداگ آمریکایی';

  @override
  String get breedAmericanPitBullTerrier => 'پیت بول آمریکایی';

  @override
  String get breedAustralianCattleDog => 'سگ گله استرالیایی';

  @override
  String get breedAustralianShepherd => 'چوپان استرالیایی';

  @override
  String get breedBassetHound => 'باست هاند';

  @override
  String get breedBeagle => 'بیگل';

  @override
  String get breedBelgianMalinois => 'مالینویز بلژیکی';

  @override
  String get breedBerneseMountainDog => 'سگ کوهستانی برنزی';

  @override
  String get breedBichonFrise => 'بیچون فریزه';

  @override
  String get breedBloodhound => 'بلادهاند';

  @override
  String get breedBorderCollie => 'بوردر کالی';

  @override
  String get breedBostonTerrier => 'بوستون تریر';

  @override
  String get breedBoxer => 'باکسر';

  @override
  String get breedBulldog => 'بولداگ';

  @override
  String get breedBullmastiff => 'بول‌ماستیف';

  @override
  String get breedCairnTerrier => 'کرن تریر';

  @override
  String get breedCaneCorso => 'کین کورسو';

  @override
  String get breedCavalierKingCharlesSpaniel => 'کاوالیر کینگ چارلز اسپانیل';

  @override
  String get breedChihuahua => 'چیواوا';

  @override
  String get breedChowChow => 'چاو چاو';

  @override
  String get breedCockerSpaniel => 'کوکر اسپانیل';

  @override
  String get breedCollie => 'کالی';

  @override
  String get breedDachshund => 'داکسهوند';

  @override
  String get breedDalmatian => 'دالماسین';

  @override
  String get breedDobermanPinscher => 'دوبرمن پینچر';

  @override
  String get breedEnglishSpringerSpaniel => 'اسپرینگر اسپانیل انگلیسی';

  @override
  String get breedFrenchBulldog => 'بولداگ فرانسوی';

  @override
  String get breedGermanShepherd => 'ژرمن شپرد';

  @override
  String get breedGermanShorthairedPointer => 'پوینتر موکوتاه آلمانی';

  @override
  String get breedGoldenRetriever => 'گلدن رتریور';

  @override
  String get breedGreatDane => 'گریت دین';

  @override
  String get breedGreatPyrenees => 'گریت پیرنه';

  @override
  String get breedHavanese => 'هاوانیز';

  @override
  String get breedIrishSetter => 'ستتر ایرلندی';

  @override
  String get breedIrishWolfhound => 'گرگ‌سان ایرلندی';

  @override
  String get breedJackRussellTerrier => 'جک راسل تریر';

  @override
  String get breedLabradorRetriever => 'لابرادور رتریور';

  @override
  String get breedLhasaApso => 'لهاسا آپسو';

  @override
  String get breedMaltese => 'مالتیز';

  @override
  String get breedMastiff => 'ماستیف';

  @override
  String get breedMiniatureSchnauzer => 'شناوزر مینیاتوری';

  @override
  String get breedNewfoundland => 'نیوفاندلند';

  @override
  String get breedPapillon => 'پاپیون';

  @override
  String get breedPekingese => 'پکینزی';

  @override
  String get breedPomeranian => 'پامرانین';

  @override
  String get breedPoodle => 'پودل';

  @override
  String get breedPug => 'پاگ';

  @override
  String get breedRottweiler => 'روتوایلر';

  @override
  String get breedSaintBernard => 'سنت برنارد';

  @override
  String get breedSamoyed => 'سامویید';

  @override
  String get breedShetlandSheepdog => 'شپداگ شتلند';

  @override
  String get breedShihTzu => 'شیتزو';

  @override
  String get breedSiberianHusky => 'هاسکی سیبری';

  @override
  String get breedStaffordshireBullTerrier => 'استافوردشایر بول تریر';

  @override
  String get breedVizsla => 'ویزلا';

  @override
  String get breedWeimaraner => 'وایمارانر';

  @override
  String get breedWestHighlandWhiteTerrier => 'وست هایلند وایت تریر';

  @override
  String get breedYorkshireTerrier => 'یورکشایر تریر';

  @override
  String get settings => 'تنظیمات';

  @override
  String get playdateRequestsTitle => 'درخواست‌های قرار بازی و اعلان‌ها';

  @override
  String get sendRequestButton => 'ارسال درخواست';

  @override
  String get confirmLocation => 'تأیید مکان';

  @override
  String get cancelButton => 'لغو عمل';

  @override
  String get editDogHealthHealthy => 'سالم';

  @override
  String get editDogHealthNeedsCare => 'نیاز به مراقبت';

  @override
  String get editDogHealthUnderTreatment => 'تحت درمان';

  @override
  String get noDogFoundForAccount =>
      'هیچ سگی برای حساب شما یافت نشد. لطفاً ابتدا یک سگ اضافه کنید.';

  @override
  String get pleaseSelectYourDog => 'لطفاً یکی از سگ‌های خود را انتخاب کنید';

  @override
  String get cannotScheduleWithOwnDog =>
      'نمی‌توانید با سگ خودتان قرار بازی ترتیب دهید.';

  @override
  String get cannotScheduleWithTempUser =>
      'نمی‌توان با کاربر موقت قرار بازی ترتیب داد.';

  @override
  String playdateRequestFor(Object dogName) {
    return 'درخواست قرار بازی برای $dogName';
  }

  @override
  String get forAdoption => 'برای پذیرش';

  @override
  String get neutered => 'عقیم‌شده';

  @override
  String get notNeutered => 'عقیم‌نشده';

  @override
  String get pleaseSelectDogForPlaydate =>
      'لطفاً یکی از سگ‌های خود را برای قرار بازی انتخاب کنید';

  @override
  String get years => 'سال';

  @override
  String get breed => 'نژاد';

  @override
  String get gender => 'جنسیت';

  @override
  String get healthStatus => 'وضعیت سلامتی';

  @override
  String get neuteredStatus => 'وضعیت عقیم‌سازی';

  @override
  String get description => 'توضیحات';

  @override
  String get traits => 'ویژگی‌ها';

  @override
  String get addToFavorites => 'اضافه کردن به علاقه‌مندی‌ها';

  @override
  String get newFavoriteTitle => 'مورد علاقه جدید!';

  @override
  String newFavoriteBody(Object userName, Object dogName) {
    return '$userName سگ شما $dogName را به علاقه‌مندی‌ها اضافه کرد!';
  }

  @override
  String get likes => 'لایک‌ها';

  @override
  String get removeDislike => 'حذف دیسلایک';

  @override
  String get dislike => 'دیسلایک';

  @override
  String errorTogglingDislike(Object error) {
    return 'خطا در تغییر وضعیت دیسلایک: $error';
  }

  @override
  String get sending => 'در حال ارسال...';

  @override
  String get schedulePlayDate => 'برنامه‌ریزی قرار بازی';

  @override
  String get playdateSchedulingSubtitle =>
      'تاریخ، زمان، مکان و سگ‌ها را برای قرار بازی انتخاب کنید.';

  @override
  String get errorSelectDateAndTime => 'لطفاً تاریخ و زمان را انتخاب کنید.';

  @override
  String get errorMissingLocationCoordinates => 'مختصات مکان پارک موجود نیست.';

  @override
  String get errorPlaydateLeadTime =>
      'قرار بازی باید حداقل ۱۵ دقیقه زودتر برنامه‌ریزی شود.';

  @override
  String get playdateTimeConflict =>
      'این سگ در این زمان نزدیک، از قبل یک قرار بازی دارد 🐾';

  @override
  String coordinatesLatLng(Object lat, Object lng) {
    return 'عرض جغرافیایی: $lat، طول جغرافیایی: $lng';
  }

  @override
  String get chat => 'چت';

  @override
  String get adoptDog => 'پذیرش سگ';

  @override
  String errorSendingDislikeNotification(Object error) {
    return 'خطا در ارسال اعلان دیسلایک: $error';
  }

  @override
  String get genderMale => 'نر';

  @override
  String get genderFemale => 'ماده';

  @override
  String get healthHealthy => 'سالم';

  @override
  String get healthNeedsCare => 'نیاز به مراقبت';

  @override
  String get healthUnderTreatment => 'تحت درمان';

  @override
  String get dogDetailsHealthSick => 'نیاز به مراقبت';

  @override
  String get dogDetailsHealthRecovering => 'تحت درمان';

  @override
  String get noImageSelected => 'هیچ تصویری انتخاب نشده.';

  @override
  String get unknownGender => 'جنسیت نامشخص';

  @override
  String get unknownBreed => 'نژاد نامشخص';

  @override
  String get unknownTrait => 'ویژگی نامشخص';

  @override
  String get noTraits => 'هیچ ویژگی‌ای موجود نیست';

  @override
  String get simpleTestPageTitle => 'صفحه تست ساده';

  @override
  String get simpleTestPageMessage => 'این یک صفحه تست ساده است.';

  @override
  String likedBy(Object likers) {
    return 'لایک شده توسط: $likers';
  }

  @override
  String get locationNotAcquired =>
      'مکان دریافت نشد. لطفاً دوباره امتحان کنید.';

  @override
  String get retryLocation => 'تلاش مجدد برای دریافت مکان';

  @override
  String get addLike => 'این سگ را لایک کنید';

  @override
  String get removeLike => 'لغو لایک این سگ';

  @override
  String addedLike(Object dogName) {
    return 'شما $dogName را لایک کردید!';
  }

  @override
  String removedLike(Object dogName) {
    return 'لایک $dogName را لغو کردید!';
  }

  @override
  String errorTogglingLike(Object error) {
    return 'خطا در تغییر وضعیت لایک: $error';
  }

  @override
  String get errorNoOwnerFound => 'مالک معتبر برای این سگ یافت نشد';

  @override
  String get offerHotDeal => '🔥 پیشنهاد ویژه';

  @override
  String get offerPremiumBadge => 'پریمیوم';

  @override
  String get offerFallbackTitle => 'پیشنهاد ویژه برای کاربران Barky';

  @override
  String get offerFallbackProvider => 'برند همکار';

  @override
  String get offerUnlock => 'باز کردن';

  @override
  String get offerView => 'مشاهده';

  @override
  String offerDiscountPercent(Object discount) {
    return '$discount٪ تخفیف';
  }

  @override
  String get offerPremiumRequiredTitle => 'نیاز به پریمیوم';

  @override
  String get offerPremiumRequiredMessage =>
      'این پیشنهاد فقط برای اعضای پریمیوم است.';

  @override
  String get offerCancel => 'لغو';

  @override
  String get offerUpgrade => 'ارتقا';

  @override
  String get offerUnlockingMessage => 'در حال باز کردن پیشنهاد شما...';

  @override
  String get offerChooseContinueTitle => 'انتخاب کنید از کجا ادامه دهید';

  @override
  String get offerChooseContinueSubtitle =>
      'روش ارتباطی دلخواه خود را برای این پیشنهاد انتخاب کنید.';

  @override
  String get offerOpenWebsite => 'باز کردن وب‌سایت';

  @override
  String get offerInstagram => 'اینستاگرام';

  @override
  String get playdatesTitle => 'قرار بازی';

  @override
  String get manageRequests => 'مدیریت درخواست‌ها';

  @override
  String get adoptionTitle => 'سرپرستی';

  @override
  String get giveLove => 'محبت کن';

  @override
  String get alertsTitle => 'هشدارها';

  @override
  String get lostAndFound => 'گمشده و پیدا شده';

  @override
  String get vetTitle => 'دامپزشک';

  @override
  String get nearbyClinics => 'کلینیک‌های نزدیک';

  @override
  String get groomyTitle => 'آرایش حیوانات';

  @override
  String get bookGrooming => 'رزرو آرایش';

  @override
  String get petShopTitle => 'پت شاپ';

  @override
  String get shopNearYou => 'خرید نزدیک شما';

  @override
  String get featuredDeal => 'پیشنهاد ویژه';

  @override
  String get premiumLabel => 'پریمیوم';

  @override
  String get goldLabel => 'گلد';

  @override
  String discountOff(Object percent) {
    return '%$percent تخفیف';
  }

  @override
  String get socialAndPlay => 'اجتماعی و بازی';

  @override
  String get careAndServices => 'مراقبت و خدمات';

  @override
  String get outdoorAndLifestyle => 'فضای باز و سبک زندگی';

  @override
  String get exploreNearbyParks => 'پارک‌های نزدیک را ببین';

  @override
  String get trainingTitle => 'آموزش';

  @override
  String get comingSoon => 'به زودی';

  @override
  String get trainingComingSoonMessage => 'بخش آموزش به زودی اضافه می‌شود 🐾';

  @override
  String get communityHub => 'جامعه کاربران';

  @override
  String activeCount(Object count) {
    return '$count فعال';
  }

  @override
  String get reportTitle => 'گزارش';

  @override
  String get lostDogTitle => 'سگ گمشده';

  @override
  String get lostPetTitle => 'حیوان گمشده';

  @override
  String get foundDogTitle => 'سگ پیدا شده';

  @override
  String get foundPetTitle => 'حیوان پیدا شده';

  @override
  String get lostTitle => 'گمشده';

  @override
  String get dogsTitle => 'سگ‌ها';

  @override
  String get petsTitle => 'حیوانات';

  @override
  String get foundTitle => 'پیدا شده';

  @override
  String get homeDefaultUsername => 'کاربر';

  @override
  String get homePetHotelTitle => 'هتل حیوانات';

  @override
  String get homeSafeStaySubtitle => 'اقامت امن';

  @override
  String get homePetTaxiTitle => 'تاکسی حیوانات';

  @override
  String get homeRideSafelySubtitle => 'سفر امن';

  @override
  String get homeGreenMemorialTitle => 'یادبود سبز';

  @override
  String get homeVeterinaryTitle => 'دامپزشکی';

  @override
  String get homeLocationNeededTitle => 'موقعیت لازم است';

  @override
  String get homeLocationNeededMessage =>
      'برای نمایش دامپزشکان نزدیک از موقعیت شما استفاده می‌کنیم';

  @override
  String get homeAllowButton => 'اجازه دادن';

  @override
  String get homeBusinessesTitle => 'کسب‌وکارها';

  @override
  String get homeSearchHint => 'جستجوی خدمات، فروشگاه‌ها، جامعه...';

  @override
  String get homePetFriendlyPlaceTitle => 'مکان دوستدار حیوانات';

  @override
  String get homeSponsoredLabel => 'حمایت‌شده';

  @override
  String get homeShopButton => 'فروشگاه';

  @override
  String get petShopDealName => 'پت شاپ A';

  @override
  String get petShopDealDesc => '۱۵٪ تخفیف روی تمام غذاها';

  @override
  String get groomyDealName => 'Groomy Studio';

  @override
  String get groomyDealDesc => '۲۰٪ تخفیف آرایش این هفته';

  @override
  String get vetDealName => 'VetPlus';

  @override
  String get vetDealDesc => 'برای اعضای گلد، چکاپ رایگان';

  @override
  String get offerWhatsApp => 'واتساپ';

  @override
  String offerCodeCopied(Object code) {
    return 'کد کپی شد: $code';
  }

  @override
  String get offerOpenError => 'خطا در باز کردن پیشنهاد';

  @override
  String get businessRegisterLegalCompanyNameRequired =>
      '• نام قانونی شرکت الزامی است.';

  @override
  String get businessRegisterPublicDisplayNameRequired =>
      '• نام نمایشی عمومی الزامی است.';

  @override
  String get businessRegisterSelectCountry => '• لطفاً یک کشور انتخاب کنید.';

  @override
  String get businessRegisterSelectBusinessCategory =>
      '• لطفاً حداقل یک دسته‌بندی کسب‌وکار انتخاب کنید.';

  @override
  String get businessRegisterEnterValidEmail =>
      '• یک ایمیل معتبر وارد کنید (مثال: name@example.com).';

  @override
  String get businessRegisterPhoneIncomplete => '• شماره تلفن ناقص است.';

  @override
  String get businessRegisterSelectCityProvince =>
      '• لطفاً شهر / استان را انتخاب کنید.';

  @override
  String get businessRegisterSelectDistrict => '• لطفاً منطقه را انتخاب کنید.';

  @override
  String get businessRegisterBusinessAddressRequired =>
      '• آدرس کسب‌وکار الزامی است.';

  @override
  String get businessRegisterAllLegalDocumentsRequired =>
      '• همه مدارک قانونی موردنیاز باید بارگذاری شوند.';

  @override
  String get businessRegisterDocumentsVerifiedBeforeContinuing =>
      '• مدارک باید قبل از ادامه تأیید شوند.';

  @override
  String get businessRegisterAcceptPlatformTerms =>
      '• باید شرایط پلتفرم را بپذیرید.';

  @override
  String get businessRegisterAcceptLegalResponsibility =>
      '• باید اظهارنامه مسئولیت قانونی را بپذیرید.';

  @override
  String get businessRegisterFixHighlightedFields =>
      'لطفاً فیلدهای مشخص‌شده را اصلاح کنید';

  @override
  String get businessRegisterOk => 'باشه';

  @override
  String get businessRegisterFailedToLoadCountries =>
      'بارگذاری کشورها ناموفق بود';

  @override
  String get businessRegisterFailedToLoadCities => 'بارگذاری شهرها ناموفق بود';

  @override
  String get businessRegisterFailedToLoadDistricts =>
      'بارگذاری مناطق ناموفق بود';

  @override
  String get businessRegisterPlatformLegalAgreement =>
      'توافق‌نامه قانونی پلتفرم';

  @override
  String get businessRegisterReadAndAccept => 'خواندم و می‌پذیرم';

  @override
  String get businessRegisterLocationPermissionDenied =>
      'مجوز موقعیت مکانی رد شد';

  @override
  String get businessRegisterCouldNotDetectCity => 'شهر قابل تشخیص نبود';

  @override
  String get businessRegisterGroomer => 'آرایشگر حیوانات';

  @override
  String get businessRegisterVeterinaryClinic => 'کلینیک دامپزشکی';

  @override
  String get businessRegisterDogTrainer => 'مربی سگ';

  @override
  String get businessRegisterPetHotel => 'هتل حیوانات';

  @override
  String get businessRegisterDogWalker => 'گرداننده سگ';

  @override
  String get businessRegisterBreeder => 'پرورش‌دهنده';

  @override
  String get businessRegisterInvalidEmail => 'ایمیل نامعتبر است';

  @override
  String get businessRegisterInvalidPhone => 'تلفن نامعتبر است';

  @override
  String get businessRegisterInvalidWebsite => 'وب‌سایت نامعتبر است';

  @override
  String get businessRegisterCouldNotOpenLegalText => 'متن قانونی باز نشد';

  @override
  String get businessRegisterSelectAtLeastOneBusinessCategory =>
      'لطفاً حداقل یک دسته‌بندی کسب‌وکار انتخاب کنید';

  @override
  String get businessRegisterPleaseEnterBusinessAddress =>
      'لطفاً آدرس کسب‌وکار را وارد کنید';

  @override
  String get businessRegisterMustAcceptAllAgreements =>
      'باید همه توافق‌نامه‌ها را بپذیرید';

  @override
  String get businessRegisterDocumentsVerifiedBeforeSubmission =>
      'مدارک باید قبل از ارسال تأیید شوند';

  @override
  String get businessRegisterApplicationSubmittedSuccessfully =>
      'درخواست با موفقیت ارسال شد';

  @override
  String get businessRegisterSubmissionFailed => 'ارسال ناموفق بود';

  @override
  String get businessRegisterUnexpectedErrorOccurred =>
      'خطای غیرمنتظره‌ای رخ داد';

  @override
  String get businessRegisterTitle => 'ثبت کسب‌وکار';

  @override
  String get businessRegisterStepIdentityCategories =>
      'هویت کسب‌وکار و دسته‌بندی‌ها';

  @override
  String get businessRegisterStepContactLocation => 'تماس و موقعیت مکانی';

  @override
  String get businessRegisterStepLegalDocuments => 'مدارک قانونی';

  @override
  String get businessRegisterStepAgreementConfirmation => 'تأیید توافق‌نامه';

  @override
  String get businessRegisterBack => 'بازگشت';

  @override
  String get businessRegisterContinue => 'ادامه';

  @override
  String get businessRegisterSubmitApplication => 'ارسال درخواست';

  @override
  String get businessRegisterCompleteSectorDetails => 'تکمیل جزئیات بخش';

  @override
  String get businessRegisterBusinessIdentity => 'هویت کسب‌وکار';

  @override
  String get businessRegisterBusinessIdentitySubtitle =>
      'مشخص کنید کسب‌وکار شما چگونه در PetSupo نمایش داده شود.';

  @override
  String get businessRegisterLegalCompanyName => 'نام قانونی شرکت';

  @override
  String get businessRegisterRequired => 'الزامی';

  @override
  String get businessRegisterPublicDisplayName => 'نام نمایشی عمومی';

  @override
  String get businessRegisterCountry => 'کشور';

  @override
  String get businessRegisterBusinessCategories => 'دسته‌بندی‌های کسب‌وکار';

  @override
  String get businessRegisterBusinessCategoriesSubtitle =>
      'همه بخش‌هایی را که این کسب‌وکار در آن فعالیت می‌کند انتخاب کنید.';

  @override
  String get businessRegisterContactLocation => 'تماس و موقعیت مکانی';

  @override
  String get businessRegisterContactLocationSubtitle =>
      'این اطلاعات به مشتریان کمک می‌کند شما را پیدا کنند و با شما تماس بگیرند.';

  @override
  String get businessRegisterPhone => 'تلفن';

  @override
  String get businessRegisterWebsiteOptional => 'وب‌سایت (اختیاری)';

  @override
  String get businessRegisterLoadingCities => 'در حال بارگذاری شهرها...';

  @override
  String get businessRegisterCityProvince => 'شهر / استان';

  @override
  String get businessRegisterLoadingDistricts => 'در حال بارگذاری مناطق...';

  @override
  String get businessRegisterDistrict => 'منطقه';

  @override
  String get businessRegisterBusinessAddress => 'آدرس کسب‌وکار';

  @override
  String get businessRegisterDetectCity => 'تشخیص شهر';

  @override
  String get businessRegisterMapPickerComingSoon =>
      'انتخاب‌گر نقشه به‌زودی اضافه می‌شود';

  @override
  String get businessRegisterPickLocation => 'انتخاب موقعیت';

  @override
  String get businessRegisterLocationSelected => 'موقعیت انتخاب شد';

  @override
  String get businessRegisterTaxPlate => 'گواهی مالیاتی';

  @override
  String get businessRegisterTradeRegistryGazette => 'روزنامه ثبت تجاری';

  @override
  String get businessRegisterAuthorizedSignatureDocument => 'مدرک امضای مجاز';

  @override
  String get businessRegisterTaxNumberVkn => 'شماره مالیاتی (VKN)';

  @override
  String get businessRegisterAutoFilledFromDocument =>
      'به‌صورت خودکار از مدرک پر شد';

  @override
  String get businessRegisterDocumentVerificationInconsistencies =>
      'در تأیید مدرک ناسازگاری وجود دارد. بررسی مدیر لازم است.';

  @override
  String get businessRegisterMersisNumber => 'شماره MERSIS';

  @override
  String get businessRegisterDocumentsSecurelyEncrypted =>
      'مدارک شما به‌صورت امن رمزگذاری و خودکار تأیید می‌شوند';

  @override
  String get businessRegisterVerifiedFromDocument => 'از مدرک تأیید شد';

  @override
  String get businessRegisterAutoFilledAfterVerification =>
      'پس از تأیید مدرک خودکار پر می‌شود';

  @override
  String get businessRegisterUploadTradeRegistryFirst =>
      'ابتدا مدرک ثبت تجاری را بارگذاری کنید';

  @override
  String get businessRegisterWaitingForDocumentVerification =>
      'در انتظار تأیید مدرک...';

  @override
  String get businessRegisterSteuernummer => 'شماره مالیاتی';

  @override
  String get businessRegisterTaxNumberRequired => 'شماره مالیاتی الزامی است';

  @override
  String get businessRegisterGewerbeschein => 'گواهی کسب‌وکار';

  @override
  String get businessRegisterHandelsregisterauszug => 'گزیده ثبت تجاری';

  @override
  String get businessRegisterEinNumber => 'شماره EIN';

  @override
  String get businessRegisterEinNumberRequired => 'شماره EIN الزامی است';

  @override
  String get businessRegisterBusinessLicense => 'مجوز کسب‌وکار';

  @override
  String get businessRegisterIrsEinDocument => 'مدرک IRS EIN';

  @override
  String get businessRegisterProcessingDocument => 'در حال پردازش مدرک...';

  @override
  String get businessRegisterDocumentVerifiedSuccessfully =>
      'مدرک با موفقیت تأیید شد';

  @override
  String get businessRegisterCouldNotReadDocument =>
      'مدرک خوانده نشد، لطفاً دوباره بارگذاری کنید';

  @override
  String get businessRegisterVeterinary => 'دامپزشکی';

  @override
  String get businessRegisterGroomy => 'Groomy';

  @override
  String businessRegisterStepOfFour(Object step) {
    return 'مرحله $step از ۴';
  }

  @override
  String get businessRegisterLegalConfirmation => 'تأیید قانونی';

  @override
  String get businessRegisterAcceptTermsKvkk =>
      'شرایط پلتفرم و سیاست حفاظت از داده‌های KVKK را می‌پذیرم.';

  @override
  String get businessRegisterReadInsideApp => 'خواندن داخل برنامه';

  @override
  String get businessRegisterOpenOfficialLegalPage =>
      'باز کردن صفحه قانونی رسمی';

  @override
  String get businessRegisterLegalVersion =>
      'نسخه v1.0 • آخرین به‌روزرسانی مه ۲۰۲۶';

  @override
  String get businessRegisterAgreementSecurelyStored =>
      'توافق شما به‌صورت امن ذخیره می‌شود و از نظر قانونی الزام‌آور است';

  @override
  String get businessRegisterLegalResponsibilityDeclaration =>
      'اعلام می‌کنم همه مدارک ارسال‌شده دقیق هستند و مسئولیت کامل قانونی را طبق قانون تجارت ترکیه می‌پذیرم.';

  @override
  String get businessRegisterUploaded => 'بارگذاری شد';

  @override
  String get businessRegisterReplaceDocument => 'جایگزینی مدرک';

  @override
  String get businessRegisterReplaceDocumentConfirmation =>
      'آیا مطمئن هستید می‌خواهید این فایل را جایگزین کنید؟';

  @override
  String get businessRegisterReplace => 'جایگزین کردن';

  @override
  String get businessRegisterUpload => 'بارگذاری';

  @override
  String userProfileInitError(Object error) {
    return 'خطا در راه‌اندازی پروفایل: $error';
  }

  @override
  String userProfileImagePickError(Object error) {
    return 'خطا در انتخاب عکس: $error';
  }

  @override
  String get userProfileUnknownBusinessType => 'نوع کسب‌وکار نامشخص است';

  @override
  String get userProfileBusinessDashboard => 'داشبورد کسب‌وکار';

  @override
  String get userProfileActivity => 'فعالیت';

  @override
  String get userProfileSavedParks => 'پارک‌های ذخیره‌شده';

  @override
  String get userProfileMatches => 'همخوانی‌ها';

  @override
  String get userProfileMyOrders => 'سفارش‌های من';

  @override
  String get myAppointments => 'نوبت‌های من';

  @override
  String get myAppointmentsLoginRequired =>
      'لطفاً برای مشاهده نوبت‌های خود وارد شوید';

  @override
  String get appointmentHistory => 'تاریخچه نوبت‌ها';

  @override
  String get noAppointmentsYet => 'هنوز نوبتی وجود ندارد';

  @override
  String get viewAppointment => 'مشاهده نوبت';

  @override
  String get appointmentStatusPending => 'در انتظار';

  @override
  String get appointmentStatusAwaitingPayment => 'در انتظار پرداخت';

  @override
  String get appointmentStatusConfirmed => 'تأیید شد';

  @override
  String get appointmentStatusConfirmedPaid => 'تأیید و پرداخت شد';

  @override
  String get appointmentStatusPaymentExpired => 'مهلت پرداخت منقضی شد';

  @override
  String get appointmentStatusRejected => 'رد شد';

  @override
  String get appointmentStatusCompleted => 'تکمیل شد';

  @override
  String get appointmentStatusCancelledByUser => 'توسط شما لغو شد';

  @override
  String get appointmentStatusCancelledByVet => 'توسط دامپزشک لغو شد';

  @override
  String get appointmentStatusExpired => 'منقضی شد';

  @override
  String get unpaidStatusLabel => 'پرداخت‌نشده';

  @override
  String get paymentNotRequiredStatusLabel => 'نیازی به پرداخت نیست';

  @override
  String get refundUnderReviewStatusLabel => 'بازپرداخت در حال بررسی است';

  @override
  String get refundRequestedStatusLabel => 'درخواست بازپرداخت ثبت شد';

  @override
  String get refundCompletedStatusLabel => 'بازپرداخت تکمیل شد';

  @override
  String get refundFailedStatusLabel => 'بازپرداخت ناموفق بود';

  @override
  String get noRefundRequiredStatusLabel => 'نیازی به بازپرداخت نیست';

  @override
  String get refundNotProcessedStatusLabel => 'بازپرداخت هنوز پردازش نشده است';

  @override
  String get veterinaryClinicFallback => 'کلینیک دامپزشکی';

  @override
  String get veterinaryServiceFallback => 'خدمت دامپزشکی';

  @override
  String get petFallback => 'حیوان خانگی';

  @override
  String get dogTypeLabel => 'سگ';

  @override
  String get userProfileAdoptionRequests => 'درخواست‌های پذیرش';

  @override
  String get userProfileBusiness => 'کسب‌وکار';

  @override
  String get userProfileAdmin => 'مدیر';

  @override
  String get userProfileSupport => 'پشتیبانی';

  @override
  String get userProfileSendFeedback => 'ارسال بازخورد';

  @override
  String get userProfileHelpCenter => 'مرکز راهنما';

  @override
  String get userProfilePrivacy => 'حریم خصوصی';

  @override
  String get userProfileReportProblem => 'گزارش مشکل';

  @override
  String get userProfileSubscriptionPlans => 'اشتراک و طرح‌ها';

  @override
  String get userProfileLanguage => 'زبان';

  @override
  String get userProfileTheme => 'تم';

  @override
  String get userProfileChangePassword => 'تغییر رمز عبور';

  @override
  String get userProfileGuestTitle => 'شما به‌عنوان مهمان در حال مرور هستید';

  @override
  String get userProfileGuestSubtitle =>
      'برای دسترسی به همه قابلیت‌ها وارد شوید';

  @override
  String get userProfileLoginSignUp => 'ورود / ثبت‌نام';

  @override
  String get userProfileLanguageEnglish => 'انگلیسی';

  @override
  String get userProfileLanguagePersian => 'فارسی';

  @override
  String get userProfileLanguageTurkish => 'ترکی';

  @override
  String get userProfileUnlockBusinessFeatures =>
      'باز کردن قابلیت‌های کسب‌وکار 🚀';

  @override
  String get userProfileUpgradeBusinessDescription =>
      'برای ثبت کسب‌وکار و شروع دریافت مشتری به Gold ارتقا دهید.';

  @override
  String get userProfileUpgradeToGold => 'ارتقا به Gold';

  @override
  String get userProfileManageAdoptionCenter => 'مدیریت مرکز پذیرش';

  @override
  String get userProfileOverview => 'نمای کلی';

  @override
  String get userProfileDogs => 'سگ‌ها';

  @override
  String get userProfileRequests => 'درخواست‌ها';

  @override
  String get userProfileOverviewSection => 'بخش نمای کلی';

  @override
  String get userProfileDogsSection => 'بخش سگ‌ها';

  @override
  String get userProfileRequestsSection => 'بخش درخواست‌ها';

  @override
  String get userProfileSettingsSection => 'بخش تنظیمات';

  @override
  String get userProfileApplicationUnderReview => 'درخواست در حال بررسی است';

  @override
  String get userProfileApplicationUnderReviewDescription =>
      'درخواست کسب‌وکار شما با موفقیت ارسال شده و در حال بررسی است.';

  @override
  String get userProfileAdminPanel => 'پنل مدیر';

  @override
  String get userProfileManageBusinessCenter => 'مدیریت مرکز کسب‌وکار';

  @override
  String get userProfileApplicationRejected => 'درخواست رد شد';

  @override
  String userProfileRejectionReason(Object reason) {
    return 'دلیل: $reason';
  }

  @override
  String get userProfileUpgradeToGoldToContinue =>
      'برای ادامه به Gold ارتقا دهید';

  @override
  String get userProfileReApply => 'درخواست دوباره';

  @override
  String get userProfileBusinessStatus => 'وضعیت کسب‌وکار';

  @override
  String get userProfileUnknownStatus => 'نامشخص';

  @override
  String get userProfileChooseFromGallery => 'انتخاب از گالری';

  @override
  String get userProfileRemovePhoto => 'حذف عکس';

  @override
  String get userProfileImageSelectionFailed => 'انتخاب عکس ناموفق بود.';

  @override
  String get userProfileUsernameMinLength =>
      'نام کاربری باید حداقل ۳ کاراکتر باشد';

  @override
  String get userProfileUsernameMaxLength =>
      'نام کاربری باید حداکثر ۲۰ کاراکتر باشد';

  @override
  String get userProfileUsernameNoSpaces =>
      'نام کاربری نمی‌تواند فاصله داشته باشد';

  @override
  String get userProfilePhoneInvalidCharacters =>
      'شماره تلفن شامل کاراکتر نامعتبر است';

  @override
  String get userProfileBioMaxLength =>
      'بیوگرافی باید کمتر از ۱۵۰ کاراکتر باشد';

  @override
  String get userProfileUsernameAlreadyTaken =>
      'این نام کاربری قبلاً گرفته شده است';

  @override
  String get userProfileEmailUpdateFailed => 'به‌روزرسانی ایمیل ناموفق بود';

  @override
  String get userProfileUpdateFailed => 'به‌روزرسانی پروفایل ناموفق بود.';

  @override
  String get userProfileChangePhoto => 'تغییر عکس';

  @override
  String get userProfileEnterUsername => 'نام کاربری را وارد کنید';

  @override
  String get userProfileEnterEmail => 'ایمیل را وارد کنید';

  @override
  String get userProfileOptionalPhoneNumber => 'شماره تلفن اختیاری';

  @override
  String get userProfileBio => 'بیوگرافی';

  @override
  String get userProfileBioHint => 'کمی درباره خودتان به دیگران بگویید';

  @override
  String get unnamedProduct => 'محصول بدون نام';

  @override
  String barcodeLabel(Object barcode) {
    return 'بارکد: $barcode';
  }

  @override
  String skuLabel(Object sku) {
    return 'SKU: $sku';
  }

  @override
  String get dealBadge => '💸 تخفیف';

  @override
  String get lowStockBadge => '⚡ کم';

  @override
  String saveAmountLabel(Object amount) {
    return 'صرفه‌جویی $amount';
  }

  @override
  String salePriceLabel(Object price) {
    return 'فروش: $price';
  }

  @override
  String stockLabel(Object stock) {
    return 'موجودی: $stock';
  }

  @override
  String get addToCartButton => 'افزودن به سبد';

  @override
  String get buyNowButton => 'همین حالا بخرید';

  @override
  String get addedToCart => 'به سبد اضافه شد';

  @override
  String get mediaNotReadyYet => 'رسانه هنوز آماده نیست';

  @override
  String cargoLabel(Object price) {
    return 'ارسال: $price';
  }

  @override
  String carrierLabel(Object carrier) {
    return 'حمل‌کننده: $carrier';
  }

  @override
  String deliveryDaysRangeLabel(Object max, Object min) {
    return '$min-$max روز';
  }

  @override
  String get businessNotFound => 'کسب‌وکار پیدا نشد';

  @override
  String get sectorDashboardNotImplementedYet =>
      'داشبورد این بخش هنوز پیاده‌سازی نشده است';

  @override
  String get goBackButton => 'بازگشت';

  @override
  String get backButton => 'بازگشت';

  @override
  String get veterinaryDashboardTitle => 'داشبورد دامپزشکی';

  @override
  String get overviewTab => 'نمای کلی';

  @override
  String get appointmentsTab => 'نوبت‌ها';

  @override
  String get shopProfileTitle => 'پروفایل فروشگاه';

  @override
  String get noDescriptionYet => 'هنوز توضیحی اضافه نشده است.';

  @override
  String get noRevenueYet => 'هنوز درآمدی نیست';

  @override
  String get netRevenueLabel => 'درآمد خالص';

  @override
  String get afterPlatformCommissionLabel => 'پس از کمیسیون پلتفرم';

  @override
  String get grossSalesLabel => 'فروش ناخالص';

  @override
  String get platformFeeLabel => 'هزینه پلتفرم';

  @override
  String get adjustmentsLabel => 'تعدیلات';

  @override
  String get recentOrdersTitle => 'سفارش‌های اخیر';

  @override
  String get latestOrdersSubtitle => 'آخرین ۵ سفارش';

  @override
  String get viewAllButton => 'نمایش همه';

  @override
  String get noDataLabel => 'داده‌ای نیست';

  @override
  String get noOrdersYet => 'هنوز سفارشی نیست';

  @override
  String orderNumberLabel(Object number) {
    return 'سفارش #$number';
  }

  @override
  String itemsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# مورد',
      one: '# مورد',
    );
    return '$_temp0';
  }

  @override
  String trackingLabel(Object tracking) {
    return 'پیگیری: $tracking';
  }

  @override
  String get trackShipmentButton => 'پیگیری مرسوله';

  @override
  String get catalogStrengthUnavailable => 'قدرت کاتالوگ در دسترس نیست';

  @override
  String get catalogStrengthTitle => 'قدرت کاتالوگ';

  @override
  String get productsTitle => 'محصولات';

  @override
  String get noProductsFound => 'محصولی پیدا نشد';

  @override
  String get lowStockLabel => 'موجودی کم';

  @override
  String get strengthLabel => 'قدرت';

  @override
  String get shippableLabel => 'قابل ارسال';

  @override
  String get withKdvLabel => 'با KDV';

  @override
  String get noProductsYet => 'هنوز محصولی نیست';

  @override
  String get kdvIncludedLabel => 'شامل KDV';

  @override
  String fromLabel(Object city) {
    return 'از $city';
  }

  @override
  String returnsLabel(Object days) {
    return 'مرجوعی $days روزه';
  }

  @override
  String get pickupLabel => 'تحویل حضوری';

  @override
  String get sameDayLabel => 'همان روز';

  @override
  String get offersTitle => 'پیشنهادها';

  @override
  String get createOfferButton => 'ایجاد پیشنهاد';

  @override
  String get videoLabel => 'ویدیو';

  @override
  String get catalogStrengthWeakLabel => 'ضعیف';

  @override
  String get catalogStrengthAddItemsMessage =>
      'برای تقویت کاتالوگ، محصول، توضیحات، رسانه و موجودی اضافه کنید.';

  @override
  String get catalogStrengthWeakDetailsMessage =>
      'جزئیات محصول شما هنوز ضعیف است. رسانه، توضیحات و اطلاعات موجودی بیشتری اضافه کنید.';

  @override
  String get catalogStrengthMediumLabel => 'متوسط';

  @override
  String get catalogStrengthMediumMessage =>
      'شروع خوبی است. برای افزایش دیده‌شدن، توضیحات کامل‌تر و رسانه بیشتر اضافه کنید.';

  @override
  String get catalogStrengthStrongLabel => 'قوی';

  @override
  String get catalogStrengthStrongMessage =>
      'کیفیت کاتالوگ عالی است. فهرست‌های شما قوی و کامل به نظر می‌رسند.';

  @override
  String get shippingCalculatedLabel => 'هزینه ارسال محاسبه می‌شود';

  @override
  String get fragileLabel => 'شکننده';

  @override
  String get oversizeLabel => 'بزرگ‌ابعاد';

  @override
  String originLabel(Object city) {
    return 'مبدأ: $city';
  }

  @override
  String carriersCountLabel(Object count) {
    return '$count حامل';
  }

  @override
  String kdvRateLabel(Object percent) {
    return 'KDV $percent%';
  }

  @override
  String get myOrdersLoginRequired =>
      'لطفاً برای مشاهده سفارش‌های خود وارد شوید';

  @override
  String get myOrdersTitle => 'سفارش‌های من';

  @override
  String get ordersTitle => 'سفارش‌ها';

  @override
  String get searchByOrderIdOrProductNameHint =>
      'جستجو با شماره سفارش یا نام محصول';

  @override
  String get allFilterLabel => 'همه';

  @override
  String get noMatchingOrders => 'سفارشی مطابق یافت نشد';

  @override
  String get orderLabel => 'سفارش';

  @override
  String get itemsTitle => 'موارد';

  @override
  String qtyLabel(Object qty) {
    return 'تعداد: $qty';
  }

  @override
  String get pendingStatusLabel => 'در انتظار';

  @override
  String get paidStatusLabel => 'پرداخت شد';

  @override
  String get confirmedStatusLabel => 'تأیید شد';

  @override
  String get preparingStatusLabel => 'در حال آماده‌سازی';

  @override
  String get shippedStatusLabel => 'ارسال شد';

  @override
  String get deliveredStatusLabel => 'تحویل شد';

  @override
  String get completedStatusLabel => 'تکمیل شد';

  @override
  String get failedStatusLabel => 'ناموفق';

  @override
  String get cancelledStatusLabel => 'لغو شد';

  @override
  String get paymentFailedStatusLabel => 'پرداخت ناموفق';

  @override
  String get paidPayoutStatusLabel => 'پرداخت شد';

  @override
  String get readyForPayoutLabel => 'آماده پرداخت';

  @override
  String get payoutPendingLabel => 'پرداخت در انتظار';

  @override
  String get waitingForPaymentLabel => 'در انتظار پرداخت';

  @override
  String get payoutNotSetLabel => 'پرداخت تنظیم نشده';

  @override
  String get confirmOrderButton => 'تأیید سفارش';

  @override
  String get startPreparingButton => 'شروع آماده‌سازی';

  @override
  String get openOrderButton => 'باز کردن سفارش';

  @override
  String get simulateUploadInvoiceButton => 'شبیه‌سازی بارگذاری فاکتور';

  @override
  String get invoiceSimulatedAsUploaded =>
      'فاکتور به‌عنوان بارگذاری‌شده شبیه‌سازی شد';

  @override
  String invoiceError(Object error) {
    return 'خطای فاکتور: $error';
  }

  @override
  String orderStatusUpdated(Object status) {
    return 'وضعیت به $status به‌روزرسانی شد';
  }

  @override
  String invoiceSummaryLabel(Object deadline, Object status) {
    return 'فاکتور: $status • مهلت: $deadline';
  }

  @override
  String sellerNetLabel(Object amount) {
    return 'خالص فروشنده: $amount';
  }

  @override
  String referenceLabel(Object reference) {
    return 'مرجع: $reference';
  }

  @override
  String buyerNameLabel(Object name) {
    return 'نام: $name';
  }

  @override
  String buyerSurnameLabel(Object surname) {
    return 'نام خانوادگی: $surname';
  }

  @override
  String buyerIdentityNumberLabel(Object identityNumber) {
    return 'شماره ملی: $identityNumber';
  }

  @override
  String buyerCityLabel(Object city) {
    return 'شهر: $city';
  }

  @override
  String buyerAddressLabel(Object address) {
    return 'آدرس: $address';
  }

  @override
  String get buyerInfoTitle => 'اطلاعات خریدار';

  @override
  String invoiceTypeLabel(Object type) {
    return 'نوع فاکتور: $type';
  }

  @override
  String get invoiceTitle => 'فاکتور';

  @override
  String get uploadDeadlineLabel => 'مهلت بارگذاری';

  @override
  String get warningsLabel => 'هشدارها';

  @override
  String get penaltyLabel => 'جریمه';

  @override
  String get invoiceSystemLabel => 'سیستم فاکتور';

  @override
  String get invoiceNoLabel => 'شماره فاکتور';

  @override
  String get dateLabel => 'تاریخ';

  @override
  String get cannotOpenInvoiceFile => 'امکان باز کردن فایل فاکتور نیست';

  @override
  String get viewInvoiceButton => 'مشاهده فاکتور';

  @override
  String get noInvoiceLabel => 'بدون فاکتور';

  @override
  String get uploadingLabel => 'در حال بارگذاری...';

  @override
  String get invoiceUploadedLabel => 'فاکتور بارگذاری شد';

  @override
  String get uploadInvoiceButton => 'بارگذاری فاکتور';

  @override
  String get invoiceUploadDeadlinePassed => 'مهلت بارگذاری فاکتور گذشته است!';

  @override
  String get timelineTitle => 'تایم‌لاین';

  @override
  String get payoutTitle => 'پرداخت';

  @override
  String amountLabel(Object amount) {
    return 'مبلغ: $amount';
  }

  @override
  String get paymentWillBeTransferredByPetsupo =>
      'پرداخت توسط Petsupo منتقل خواهد شد';

  @override
  String get pendingPayoutLabel => 'پرداخت در انتظار';

  @override
  String get waitingForCustomerPayment => 'در انتظار پرداخت مشتری';

  @override
  String get actionsTitle => 'اقدام‌ها';

  @override
  String get payoutMarkedAsPaid => 'پرداخت به‌عنوان پرداخت‌شده علامت‌گذاری شد';

  @override
  String get trackingNumberLabel => 'شماره پیگیری';

  @override
  String get trackingNumberRequired => 'شماره پیگیری لازم است';

  @override
  String get returnCarrierRequired => 'حمل‌کننده لازم است';

  @override
  String get returnShippedBackFailed =>
      'امکان ثبت بازگشت به‌عنوان ارسال‌شده نبود';

  @override
  String get returnTrackingNumberLabel => 'شماره پیگیری بازگشت';

  @override
  String get returnTrackingNumberHelperText =>
      'شماره پیگیری ارائه‌شده برای ارسال بازگشتی را وارد کنید.';

  @override
  String get returnCarrierHelperText =>
      'از همان حمل‌کننده‌ای که برای تحویل اصلی استفاده شده است، استفاده کنید.';

  @override
  String get originalShipmentTrackingLabel => 'پیگیری ارسال اصلی';

  @override
  String get returnShipmentTrackingLabel => 'پیگیری ارسال بازگشتی';

  @override
  String get returnShippedBackTimelineLabel => 'بازگشت ارسال شد';

  @override
  String get carrierMissingFromOrder => 'حمل‌کننده در سفارش موجود نیست';

  @override
  String get enterTrackingNumber => 'شماره پیگیری را وارد کنید';

  @override
  String get shipOrderButton => 'ارسال سفارش';

  @override
  String get markAsDeliveredButton => 'علامت‌گذاری به‌عنوان تحویل‌شده';

  @override
  String get goToCarrierWebsiteButton => 'رفتن به وب‌سایت حمل‌کننده';

  @override
  String get noTimelineYet => 'هنوز تایم‌لاین وجود ندارد';

  @override
  String get orderNotFound => 'سفارش پیدا نشد';

  @override
  String get invoiceUploadedSuccessfully => 'فاکتور با موفقیت بارگذاری شد';

  @override
  String uploadFailed(Object error) {
    return 'بارگذاری ناموفق بود: $error';
  }

  @override
  String get orderShipped => 'سفارش ارسال شد';

  @override
  String get sellerTaxNumberMissing => 'شماره مالیاتی فروشنده موجود نیست';

  @override
  String get buyerIdentityNumberMissing => 'شماره ملی خریدار موجود نیست';

  @override
  String get buyerTaxNumberMissing => 'شماره مالیاتی خریدار موجود نیست';

  @override
  String get invoiceSystemMismatch => 'نوع فاکتور مطابقت ندارد';

  @override
  String get invoiceStatusPendingUploadLabel => 'در انتظار فاکتور';

  @override
  String get invoiceStatusUploadedValidLabel => 'فاکتور بارگذاری شد';

  @override
  String get invoiceStatusUploadedWithIssuesLabel => 'نیاز به بررسی';

  @override
  String get invoiceStatusLateLabel => 'دیر شده';

  @override
  String get invoiceStatusApprovedLabel => 'فاکتور تأیید شد';

  @override
  String get invoiceStatusRejectedLabel => 'فاکتور رد شد';

  @override
  String get eArsivLabel => 'e-آرشیو';

  @override
  String get eFaturaLabel => 'e-فاکتور';

  @override
  String get fileIsEmpty => 'فایل خالی است';

  @override
  String get fileTooLarge => 'فایل خیلی بزرگ است';

  @override
  String get upgradePageTitle => 'ارتقا';

  @override
  String get upgradeHeroTitle => 'سریع‌تر به تطابق‌های بهتر برسید 🐾';

  @override
  String get upgradeHeroSubtitle =>
      'امکانات پریمیوم، دیده‌شدن بهتر، پیشنهادهای اختصاصی و ابزارهای کسب‌وکار را فعال کنید.';

  @override
  String get premiumPlanSubtitle => 'برای صاحبان فعال حیوانات خانگی';

  @override
  String get premiumPlanFeatureUnlimitedChat => 'گفت‌وگوی نامحدود';

  @override
  String get premiumPlanFeatureAdvancedMatchingFilters =>
      'فیلترهای پیشرفته تطابق';

  @override
  String get premiumPlanFeatureExclusivePetOffers =>
      'پیشنهادهای اختصاصی حیوانات خانگی';

  @override
  String get premiumPlanFeatureBetterProfileExperience => 'تجربه بهتر پروفایل';

  @override
  String get goldPlanSubtitle =>
      'برای کسب‌وکارهای حیوانات خانگی و کاربران حرفه‌ای';

  @override
  String get mostPopularLabel => 'محبوب‌ترین';

  @override
  String get goldPlanFeatureEverythingInPremium => 'همه چیز در پریمیوم';

  @override
  String get goldPlanFeatureBusinessRegistrationAccess =>
      'دسترسی به ثبت کسب‌وکار';

  @override
  String get goldPlanFeatureBoostedVisibility => 'دیده‌شدن بیشتر';

  @override
  String get goldPlanFeatureBusinessDashboardAccess =>
      'دسترسی به داشبورد کسب‌وکار';

  @override
  String get goldPlanFeaturePremiumChatAndOffers =>
      'گفت‌وگو و پیشنهادهای پریمیوم';

  @override
  String get storeNotReadyTryAgain => 'فروشگاه آماده نیست. دوباره تلاش کنید.';

  @override
  String get processingLabel => 'در حال پردازش...';

  @override
  String get restoreRequestSent => 'درخواست بازیابی ارسال شد.';

  @override
  String get restorePurchases => 'بازیابی خریدها';

  @override
  String get upgradePaymentTerms =>
      'پرداخت شما هنگام تأیید از حساب App Store شما کسر می‌شود. اشتراک‌ها به‌صورت خودکار تمدید می‌شوند مگر اینکه حداقل 24 ساعت قبل از پایان دوره فعلی لغو شوند.';

  @override
  String get autoRenewableMonthlySubscription =>
      'اشتراک ماهانه با تمدید خودکار';

  @override
  String get securePaymentNotice =>
      'پرداخت امن • هر زمان خواستید لغو کنید • برنامه‌ها توسط App Store مدیریت می‌شوند';

  @override
  String continueWithPlan(Object plan) {
    return 'ادامه با $plan';
  }

  @override
  String get loadingLabel => 'در حال بارگذاری...';

  @override
  String get privacyPolicyLabel => 'حریم خصوصی';

  @override
  String get termsOfUseLabel => 'شرایط استفاده';

  @override
  String adoptionRequestSubtitle(Object dogName) {
    return '• $dogName';
  }

  @override
  String get adoptionStepPersonalInfoTitle => '1️⃣ اطلاعات شخصی';

  @override
  String get adoptionFullNameLabel => 'نام و نام خانوادگی';

  @override
  String get adoptionFullNameHint => 'نام و نام خانوادگی خود را وارد کنید';

  @override
  String get adoptionEnterFullName => 'نام و نام خانوادگی خود را وارد کنید';

  @override
  String get genderLabel => 'جنسیت';

  @override
  String get adoptionSelectGender => 'جنسیت را انتخاب کنید';

  @override
  String get adoptionPhoneHint => 'مثال: +90 5xx xxx xxxx';

  @override
  String get adoptionEnterValidPhone => 'شماره تلفن معتبر وارد کنید';

  @override
  String get adoptionIncomeRangeLabel => 'بازه درآمد ماهانه';

  @override
  String get adoptionSelectIncomeRange => 'بازه درآمد را انتخاب کنید';

  @override
  String get adoptionIncomeRange0_2000 => '0 - 2,000';

  @override
  String get adoptionIncomeRange2000_5000 => '2,000 - 5,000';

  @override
  String get adoptionIncomeRange5000_10000 => '5,000 - 10,000';

  @override
  String get adoptionIncomeRange10000Plus => '10,000+';

  @override
  String get adoptionStepHousingTitle => '2️⃣ مسکن';

  @override
  String get adoptionHousingTypeLabel => 'نوع مسکن';

  @override
  String get adoptionHousingApartment => 'آپارتمان';

  @override
  String get adoptionHousingHouse => 'خانه';

  @override
  String get adoptionHousingVilla => 'ویلا';

  @override
  String get adoptionOwnershipLabel => 'مالک / اجاره‌ای';

  @override
  String get adoptionOwnershipOwned => 'مالک';

  @override
  String get adoptionOwnershipRented => 'اجاره‌ای';

  @override
  String get adoptionLandlordPermissionRequired => 'اجازه صاحبخانه (الزامی)';

  @override
  String get adoptionHasGarden => 'حیاط دارد';

  @override
  String get adoptionFenceHeightLabel => 'ارتفاع حصار (سانتی‌متر)';

  @override
  String get adoptionFenceHeightHint => 'مثال: 120';

  @override
  String get adoptionEnterValidFenceHeight => '1..400 را وارد کنید';

  @override
  String get adoptionStepExperienceTitle => '3️⃣ تجربه';

  @override
  String get adoptionYearsOfExperienceLabel => 'سال‌های تجربه';

  @override
  String get adoptionYearsOfExperienceHint => '0..60';

  @override
  String get adoptionEnterYearsOfExperience => '0..60 را وارد کنید';

  @override
  String get adoptionPreviousDogQuestion => 'قبلاً سگ داشته‌اید؟ (بله/خیر)';

  @override
  String get adoptionPreviousDogReasonLabel =>
      'دلیل اینکه سگ قبلی دیگر با شما نیست';

  @override
  String get adoptionPreviousDogReasonHint => 'کوتاه توضیح دهید';

  @override
  String get adoptionExplainPreviousDog => 'حداقل 10 کاراکتر';

  @override
  String get adoptionOtherPetsAtHome => 'حیوانات خانگی دیگری در خانه هستند';

  @override
  String get adoptionDescribeOtherPetsLabel =>
      'حیوانات خانگی دیگر خود را توصیف کنید';

  @override
  String get adoptionDescribeOtherPetsHint => 'مثال: 2 گربه، واکسینه شده';

  @override
  String get adoptionRequiredShort => 'الزامی است';

  @override
  String get adoptionDescribeOtherPetsRequired =>
      'لطفاً حیوانات خانگی دیگر خود را توضیح دهید';

  @override
  String get adoptionMotivationMessageLabel => 'پیام انگیزه';

  @override
  String get adoptionMotivationMinLength => 'انگیزه باید حداقل 20 کاراکتر باشد';

  @override
  String get adoptionStepFinancialCommitmentTitle => '4️⃣ مالی و تعهد';

  @override
  String get adoptionCanAffordVetExpenses =>
      'توان پرداخت هزینه‌های دامپزشکی را دارد؟';

  @override
  String get adoptionEmergencySavingsAvailable => 'پس‌انداز اضطراری دارد؟';

  @override
  String get adoptionUploadsSectionTitle => '📷 بارگذاری‌ها';

  @override
  String get adoptionHousePhotosRequiredTitle => 'عکس‌های خانه (الزامی)';

  @override
  String get adoptionUploadAtLeastOnePhoto => 'حداقل 1 عکس بارگذاری کنید';

  @override
  String adoptionUploadedCount(Object count) {
    return '$count بارگذاری شد';
  }

  @override
  String get adoptionUploadButton => 'بارگذاری';

  @override
  String get adoptionClearButton => 'پاک کردن';

  @override
  String get adoptionIdPhotoRequiredTitle => 'عکس کارت شناسایی (الزامی)';

  @override
  String get adoptionNotUploaded => 'بارگذاری نشده';

  @override
  String get adoptionUploaded => 'بارگذاری شد';

  @override
  String get adoptionReplaceButton => 'جایگزین';

  @override
  String get adoptionRemoveButton => 'حذف';

  @override
  String get adoptionProofOfIncomeOptionalTitle => 'مدرک درآمد (اختیاری)';

  @override
  String get adoptionOptionalLabel => 'اختیاری';

  @override
  String get adoptionAgreeContractRequiredLabel =>
      'با امضای قرارداد سرپرستی موافقم (الزامی)';

  @override
  String get adoptionAgreeContractRequired =>
      'باید با قرارداد سرپرستی موافقت کنید';

  @override
  String get adoptionUploadIdPhoto => 'لطفاً یک عکس کارت شناسایی بارگذاری کنید';

  @override
  String get adoptionNextButton => 'بعدی';

  @override
  String smartPriceSuggestedRangeLabel(
    Object currency,
    Object max,
    Object min,
  ) {
    return 'بازه پیشنهادی: $min - $max $currency';
  }

  @override
  String smartPriceSuggestedPriceLabel(Object currency, Object price) {
    return 'قیمت پیشنهادی: $price $currency';
  }

  @override
  String get bestPriceStrategyLabel => 'بهترین قیمت';

  @override
  String get aggressiveLowStrategyLabel => 'قیمت پایین تهاجمی';

  @override
  String get competitiveStrategyLabel => 'رقابتی';

  @override
  String get slightlyHighStrategyLabel => 'کمی بالا';

  @override
  String get tooExpensiveStrategyLabel => 'خیلی گران';

  @override
  String get manualPricingLabel => 'قیمت‌گذاری دستی';

  @override
  String get bestPricePositionLabel => 'بهترین قیمت 🏆';

  @override
  String get aggressiveLowPositionLabel => 'قیمت پایین تهاجمی ⚡';

  @override
  String get competitivePositionLabel => 'رقابتی ✅';

  @override
  String get slightlyHighPositionLabel => 'کمی بالا 📈';

  @override
  String get tooExpensivePositionLabel => 'خیلی گران ⚠️';

  @override
  String get marketSourceAggregateLabel => 'داده‌های تجمیعی';

  @override
  String get marketSourceFallbackProductsLabel => 'محصولات جایگزین';

  @override
  String get marketSourceNoneLabel => 'داده‌ای از بازار نیست';

  @override
  String get marketSourceInvalidPricesLabel => 'قیمت‌های نامعتبر';

  @override
  String get marketSourceErrorLabel => 'خطا';

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
  String get categoryFood => 'غذا';

  @override
  String get categoryAccessories => 'لوازم جانبی';

  @override
  String get categoryHealth => 'سلامت';

  @override
  String get categoryToys => 'اسباب‌بازی‌ها';

  @override
  String get subCategoryDryFood => 'غذای خشک';

  @override
  String get subCategoryWetFood => 'غذای تر';

  @override
  String get subCategoryTreats => 'تشویقی‌ها';

  @override
  String get subCategoryCollar => 'قلاده';

  @override
  String get subCategoryLeash => 'بند';

  @override
  String get subCategoryClothing => 'پوشاک';

  @override
  String get subCategoryVitamins => 'ویتامین‌ها';

  @override
  String get subCategoryMedicine => 'دارو';

  @override
  String get subCategoryChewToy => 'اسباب‌بازی جویدنی';

  @override
  String get subCategoryInteractive => 'تعاملی';

  @override
  String get productAlreadyExistsTitle => 'محصول از قبل وجود دارد';

  @override
  String get productAlreadyExistsDescription =>
      'این محصول از قبل وجود دارد. ویرایشگر محصول باز می‌شود.';

  @override
  String get continueButton => 'ادامه';

  @override
  String get productNameMustBeAtLeast4Chars =>
      'نام محصول باید حداقل 4 کاراکتر باشد';

  @override
  String get invalidBarcode => 'بارکد نامعتبر است';

  @override
  String get invalidSku => 'SKU نامعتبر است';

  @override
  String get invalidWholesalePrice => 'قیمت عمده نامعتبر است';

  @override
  String get wholesaleMinQuantityMustBeAtLeast2 =>
      'حداقل تعداد عمده باید حداقل 2 باشد';

  @override
  String get kdvRateIsRequired => 'یک نرخ مالیات بر ارزش افزوده انتخاب کنید';

  @override
  String get invalidPrice => 'قیمت نامعتبر است';

  @override
  String get invalidDiscountPrice => 'قیمت تخفیف نامعتبر است';

  @override
  String get discountMustBeLowerThanOriginalPrice =>
      'قیمت تخفیف باید کمتر از قیمت اصلی باشد';

  @override
  String get wholesalePriceMustBeLowerThanRetailPrice =>
      'قیمت عمده باید کمتر از قیمت خرده‌فروشی باشد';

  @override
  String get invalidStock => 'موجودی نامعتبر است';

  @override
  String get stockMustBeAtLeastWholesaleMinQuantity =>
      'موجودی باید حداقل برابر حداقل تعداد عمده باشد';

  @override
  String get inventoryStockFieldLabel => 'موجودی';

  @override
  String get invalidLowStockAlert => 'هشدار موجودی کم نامعتبر است';

  @override
  String get addAtLeast1Media => 'حداقل 1 رسانه اضافه کنید';

  @override
  String get descriptionMustBeAtLeast10Characters =>
      'توضیحات باید حداقل 10 کاراکتر باشد';

  @override
  String get selectCategory => 'یک دسته را انتخاب کنید';

  @override
  String get weightOrDesiIsRequired => 'وزن یا دسی لازم است';

  @override
  String get lengthIsRequired => 'طول لازم است';

  @override
  String get widthIsRequired => 'عرض لازم است';

  @override
  String get heightIsRequired => 'ارتفاع لازم است';

  @override
  String get invalidDesiValue => 'مقدار دسی نامعتبر است';

  @override
  String get fixedShippingFeeIsRequired => 'هزینه حمل ثابت لازم است';

  @override
  String get invalidShippingFee => 'هزینه حمل نامعتبر است';

  @override
  String get freeShippingThresholdIsRequired => 'آستانه ارسال رایگان لازم است';

  @override
  String get invalidPreparationTime => 'زمان آماده‌سازی نامعتبر است';

  @override
  String get invalidMaxDeliveryDays => 'حداکثر روزهای تحویل نامعتبر است';

  @override
  String get selectAtLeast1CargoCarrier =>
      'حداقل 1 شرکت حمل‌ونقل را انتخاب کنید';

  @override
  String get returnWindowCannotBeLessThan14Days =>
      'بازه بازگشت نمی‌تواند کمتر از 14 روز باشد';

  @override
  String get returnCarrierIsRequired => 'حمل‌کننده بازگشت لازم است';

  @override
  String get shippingPayerMismatch => 'عدم تطابق پرداخت‌کننده حمل';

  @override
  String get productSavedStatus => 'محصول ذخیره شد ✅';

  @override
  String get scanFailed => 'اسکن ناموفق بود';

  @override
  String estimatedPriceLabel(Object currency, Object price) {
    return 'قیمت تخمینی: $price $currency';
  }

  @override
  String get loadedFromGlobalApi => 'از API جهانی بارگذاری شد';

  @override
  String productFallbackName(Object short) {
    return 'محصول $short';
  }

  @override
  String fallbackEstimateLabel(Object currency, Object price) {
    return 'برآورد جایگزین: $price $currency';
  }

  @override
  String offlineEstimateLabel(Object currency, Object price) {
    return 'برآورد آفلاین: $price $currency';
  }

  @override
  String errorEstimateLabel(Object currency, Object price) {
    return 'برآورد خطا: $price $currency';
  }

  @override
  String smartDescriptionDefault(Object brand, Object name) {
    return '$name از $brand یک گزینه قابل اعتماد برای صاحبان حیوانات خانگی است.';
  }

  @override
  String get trustedBrand => 'برند معتبر';

  @override
  String get productDetectedStatus => 'محصول شناسایی شد';

  @override
  String get noProductFoundAnywhere => 'هیچ محصولی در هیچ‌جا پیدا نشد';

  @override
  String get enterProductNameFirst => 'ابتدا نام محصول را وارد کنید';

  @override
  String smartDescriptionFood(Object brand, Object name, Object subCategory) {
    return '$name از $brand یک انتخاب کاربردی برای حیوانات خانگی است. در دسته $subCategory قرار می‌گیرد و برای استفاده روزانه مناسب است.';
  }

  @override
  String smartDescriptionAccessories(
    Object brand,
    Object name,
    Object subCategory,
  ) {
    return '$name از $brand یک لوازم جانبی کاربردی در دسته $subCategory است.';
  }

  @override
  String smartDescriptionHealth(Object brand, Object name, Object subCategory) {
    return '$name از $brand برای سلامت و رفاه حیوانات خانگی در دسته $subCategory طراحی شده است.';
  }

  @override
  String smartDescriptionToys(Object brand, Object name, Object subCategory) {
    return '$name از $brand یک اسباب‌بازی جذاب از دسته $subCategory است.';
  }

  @override
  String get descriptionSuggestionAdded => 'پیشنهاد توضیحات اضافه شد';

  @override
  String get noPricingDataYet => 'هنوز داده قیمتی وجود ندارد';

  @override
  String get smartPriceSuggestionTitle => 'پیشنهاد قیمت هوشمند';

  @override
  String get waitingForPricingData => 'در انتظار داده‌های قیمت...';

  @override
  String get tapToApplySuggestedPrice => 'برای اعمال قیمت پیشنهادی لمس کنید';

  @override
  String get smartPricingEngineTitle => 'موتور قیمت‌گذاری هوشمند';

  @override
  String get modeLabel => 'حالت';

  @override
  String get noMarketDataLabel => 'بدون داده بازار';

  @override
  String get usingSmartEstimationLabel => 'استفاده از برآورد هوشمند 🧠';

  @override
  String get marketIntelligenceTitle => 'تحلیل بازار';

  @override
  String get avgPriceLabel => 'میانگین قیمت';

  @override
  String get medianPriceLabel => 'میانه قیمت';

  @override
  String get sellerCountLabel => 'تعداد فروشندگان';

  @override
  String get bestPriceLabel => 'بهترین قیمت';

  @override
  String get highestPriceLabel => 'بالاترین قیمت';

  @override
  String get yourGapVsMarketLabel => 'فاصله شما با بازار';

  @override
  String get positionLabel => 'موقعیت';

  @override
  String get profitMarginLabel => 'حاشیه سود';

  @override
  String get sourceLabel => 'منبع';

  @override
  String get searchingProductStatus => 'در حال جستجوی محصول...';

  @override
  String get productAlreadyExistsOpeningEditStatus =>
      'محصول موجود است، ویرایشگر باز می‌شود...';

  @override
  String get fetchingProductDataStatus => 'در حال دریافت داده‌های محصول...';

  @override
  String get analyzingMarketStatus => 'در حال تحلیل بازار...';

  @override
  String get marketAvgLabel => 'میانگین قیمت';

  @override
  String get marketMedianLabel => 'میانه قیمت';

  @override
  String get marketSellersLabel => 'تعداد فروشندگان';

  @override
  String emergencyFallbackLabel(Object currency, Object price) {
    return 'برآورد اضطراری: $price $currency';
  }

  @override
  String get productReadyStatus => 'محصول آماده است ✅';

  @override
  String get failedToLoadProductStatus => 'بارگذاری محصول ناموفق بود';

  @override
  String get barcodeLookupFailed => 'جستجوی بارکد ناموفق بود';

  @override
  String get editProductTitle => 'ویرایش محصول';

  @override
  String get addProductTitle => 'افزودن محصول';

  @override
  String get tapToReplaceOrAddMedia => 'برای جایگزینی یا افزودن رسانه لمس کنید';

  @override
  String get tapToAddMedia => 'برای افزودن رسانه لمس کنید';

  @override
  String get basicInfoSectionTitle => 'اطلاعات پایه';

  @override
  String get productNameMinCharsLabel => 'نام محصول *';

  @override
  String get brandLabel => 'برند';

  @override
  String get barcodeFieldLabel => 'بارکد';

  @override
  String get enterBarcodeHint => 'بارکد را وارد یا اسکن کنید';

  @override
  String get noBarcodeSkuHint =>
      'بارکد اختیاری است. اگر خالی باشد SKU به‌صورت خودکار ایجاد می‌شود.';

  @override
  String get scanButtonLabel => 'اسکن';

  @override
  String get skuCodeLabel => 'کد SKU';

  @override
  String get autoGeneratedSkuHint =>
      'اگر خالی باشد به‌صورت خودکار ایجاد می‌شود';

  @override
  String get shippingAndDeliverySectionTitle => 'حمل‌ونقل و تحویل';

  @override
  String get thisProductHasADiscount => 'این محصول تخفیف دارد';

  @override
  String get originalPriceLabel => 'قیمت اصلی';

  @override
  String get priceLabel => 'قیمت';

  @override
  String get appointmentDetailTitle => 'جزئیات نوبت';

  @override
  String get appointmentNotFound => 'نوبت پیدا نشد';

  @override
  String get petLabel => 'حیوان خانگی';

  @override
  String get statusLabel => 'وضعیت';

  @override
  String get paymentLabel => 'پرداخت';

  @override
  String get goToPaymentButton => 'رفتن به پرداخت';

  @override
  String get markedAsCompletedSnack => 'به‌عنوان تکمیل‌شده علامت‌گذاری شد';

  @override
  String get markAsCompletedButton => 'علامت‌گذاری به‌عنوان تکمیل‌شده';

  @override
  String get wholesalePriceLabel => 'قیمت عمده';

  @override
  String get minimumQuantityForWholesaleLabel => 'حداقل تعداد برای عمده';

  @override
  String get wholesaleAppliesHint => 'تخفیف عمده از این تعداد اعمال می‌شود';

  @override
  String get visibleOnlyToBusinessAccountsHint =>
      'فقط برای حساب‌های تجاری قابل مشاهده است';

  @override
  String get usersWillSeeDiscountHint => 'کاربران نشان تخفیف را می‌بینند';

  @override
  String get discountPriceLabel => 'قیمت تخفیف';

  @override
  String get kdvLabel => 'مالیات بر ارزش افزوده';

  @override
  String get lengthLabel => 'طول';

  @override
  String get widthLabel => 'عرض';

  @override
  String get heightLabel => 'ارتفاع';

  @override
  String calculatedDesiLabel(Object value) {
    return 'دسی محاسبه‌شده: $value';
  }

  @override
  String get manualDesiOverrideOptionalLabel => 'جایگزینی دستی دسی (اختیاری)';

  @override
  String get shippingModeLabel => 'حالت حمل‌ونقل';

  @override
  String get carrierCalculatedLabel => 'محاسبه‌شده توسط حمل‌کننده';

  @override
  String get fixedShippingFeeLabel => 'هزینه حمل ثابت';

  @override
  String get sellerPaysShippingLabel => 'هزینه حمل با فروشنده است';

  @override
  String get enableFreeShippingCampaignLabel => 'فعال‌سازی کمپین ارسال رایگان';

  @override
  String get freeShippingThresholdLabel => 'آستانه ارسال رایگان';

  @override
  String get preparationTimeDaysLabel => 'زمان آماده‌سازی (روز)';

  @override
  String get maxDeliveryTimeDaysLabel => 'حداکثر زمان تحویل (روز)';

  @override
  String get cargoCompaniesTitle => 'شرکت‌های حمل‌ونقل';

  @override
  String get allowReturnsLabel => 'پذیرش بازگشت';

  @override
  String get returnWindowDaysLabel => 'بازه بازگشت (روز)';

  @override
  String get returnShippingPayerLabel => 'پرداخت‌کننده حمل بازگشت';

  @override
  String get sellerOptionLabel => 'فروشنده';

  @override
  String get buyerOptionLabel => 'خریدار';

  @override
  String get sellerContractedCarrierOnlyLabel =>
      'فقط در صورت حمل‌کننده قراردادی';

  @override
  String get inventoryTitle => 'موجودی';

  @override
  String get lowStockAlertLabel => 'هشدار موجودی کم';

  @override
  String get mainCategoryLabel => 'دسته اصلی';

  @override
  String get subCategoryLabel => 'زیر‌دسته';

  @override
  String get generatingLabel => 'در حال ایجاد...';

  @override
  String get suggestLabel => 'پیشنهاد';

  @override
  String get updateProductTitle => 'به‌روزرسانی محصول';

  @override
  String get sellInstantlyButtonLabel => 'فروش فوری';

  @override
  String get shippingEstimateTitle => 'برآورد حمل‌ونقل';

  @override
  String desiLabel(Object value) {
    return 'دسی: $value';
  }

  @override
  String billableLabel(Object value) {
    return 'قابل‌محاسبه: $value';
  }

  @override
  String basePriceLabel(Object currency, Object value) {
    return 'پایه: $value $currency';
  }

  @override
  String extraLabel(Object currency, Object value) {
    return 'اضافی: $value $currency';
  }

  @override
  String totalPriceLabel(Object currency, Object value) {
    return 'مجموع: $value $currency';
  }

  @override
  String get returnRequestsTitle => 'درخواست‌های مرجوعی';

  @override
  String get returnAvailableAfterDeliveryMessage =>
      'امکان ثبت مرجوعی پس از تحویل فعال می‌شود.';

  @override
  String get noReturnsYet => 'هنوز درخواستی برای مرجوعی ثبت نشده است';

  @override
  String get requestReturnButton => 'درخواست مرجوعی';

  @override
  String get returnRequestSubmitted => 'درخواست مرجوعی ارسال شد';

  @override
  String get selectReturnReasonLabel => 'دلیل را انتخاب کنید';

  @override
  String get returnDescriptionHint => 'مشکل را توضیح دهید...';

  @override
  String get selectReturnItemsLabel =>
      'مواردی را که می‌خواهید مرجوع کنید انتخاب کنید';

  @override
  String returnRequestLabel(Object id) {
    return 'مرجوعی #$id';
  }

  @override
  String get reasonLabel => 'دلیل';

  @override
  String get refundAmountLabel => 'مبلغ بازپرداخت';

  @override
  String get returnAmountLabel => 'مبلغ تقریبی بازپرداخت';

  @override
  String get shippingResponsibilityLabel => 'حمل بازگشت';

  @override
  String get refundTypeLabel => 'نوع بازپرداخت';

  @override
  String get returnTimelineTitle => 'خط زمان مرجوعی';

  @override
  String get refundResultLabel => 'نتیجه بازپرداخت';

  @override
  String get returnActionCompleted => 'مرجوعی به‌روزرسانی شد';

  @override
  String get approveReturnButton => 'تأیید';

  @override
  String get rejectReturnButton => 'رد کردن';

  @override
  String get cancelReturnButton => 'لغو مرجوعی';

  @override
  String get markShippedBackButton => 'علامت‌گذاری به‌عنوان ارسال‌شده';

  @override
  String get markReceivedButton => 'علامت‌گذاری به‌عنوان دریافت‌شده';

  @override
  String get triggerRefundButton => 'شروع بازپرداخت';

  @override
  String get returnStatusPending => 'در انتظار';

  @override
  String get returnStatusApproved => 'تأیید شد';

  @override
  String get returnStatusRejected => 'رد شد';

  @override
  String get returnStatusShippedBack => 'ارسال شد';

  @override
  String get returnStatusReceivedBySeller => 'دریافت‌شده توسط فروشنده';

  @override
  String get returnStatusRefundPending => 'بازپرداخت در انتظار';

  @override
  String get returnStatusRefundFailed => 'بازپرداخت ناموفق';

  @override
  String get returnStatusRefunded => 'بازپرداخت شد';

  @override
  String get returnStatusCancelled => 'لغو شد';

  @override
  String get returnReasonDamaged => 'آسیب‌دیده';

  @override
  String get returnReasonWrongProduct => 'محصول اشتباه';

  @override
  String get returnReasonMissingParts => 'قطعات گمشده';

  @override
  String get returnReasonNotAsDescribed => 'مطابق توضیحات نیست';

  @override
  String get returnReasonChangedMind => 'نظرم عوض شد';

  @override
  String get returnReasonOther => 'سایر';

  @override
  String get refundTypeFullLabel => 'بازپرداخت کامل';

  @override
  String get refundTypePartialLabel => 'بازپرداخت جزئی';

  @override
  String get refundTypeShippingLabel => 'بازپرداخت هزینه حمل';

  @override
  String get shippingResponsibilitySellerLabel => 'فروشنده';

  @override
  String get shippingResponsibilityBuyerLabel => 'خریدار';

  @override
  String get shippingResponsibilityContractCarrierLabel =>
      'فقط در صورت حمل‌کننده قراردادی';

  @override
  String get returnCarrierLabel => 'حمل‌کننده بازگشت';

  @override
  String get returnImagesAdded => 'تصاویر اضافه شدند';

  @override
  String get refundRejectedStatusLabel => 'بازگشت وجه رد شد';
}
