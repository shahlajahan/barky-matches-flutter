// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get userNotLoggedIn => 'کاربر وارد نشده است. در حال انتقال به صفحه ورود...';

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
  String get marketplaceDisclaimerTitle => 'پیش از ادامه';

  @override
  String get marketplaceDisclaimerMessage => 'پت‌سوپو پلتفرمی است که شما را به کسب‌وکارها و ارائه‌دهندگان مستقل خدمات متصل می‌کند. خدمت انتخاب‌شده توسط کسب‌وکار یا ارائه‌دهنده نمایش‌داده‌شده ارائه می‌شود. پت‌سوپو کیفیت یا اجرای این خدمت مستقل را تضمین نمی‌کند و مسئولیتی در قبال آن ندارد. لطفاً پیش از ادامه اطلاعات کسب‌وکار یا ارائه‌دهنده را بررسی کنید.';

  @override
  String get marketplaceDisclaimerAccept => 'پذیرش و ادامه';

  @override
  String get marketplaceDisclaimerCancel => 'لغو';

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
  String get checkoutPhoneHint => 'شماره به شکل 5XXXXXXXXX';

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
  String get checkoutCargoUpdatesQuestion => 'به‌روزرسانی‌های فاکتور و پیگیری ارسال را چگونه برایتان بفرستیم؟';

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
  String get checkoutDistanceSalesAgreement => 'قرارداد فروش از راه دور را می‌پذیرم';

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
  String get checkoutPleaseSelectCargoCompany => 'لطفاً یک شرکت حمل‌ونقل را انتخاب کنید';

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
  String get checkoutPaymentPageOpenedMessage => 'صفحه پرداخت باز شد. پرداخت را کامل کنید و سپس به برنامه برگردید.';

  @override
  String get checkoutBackButton => 'بازگشت';

  @override
  String get checkoutProceedToPayment => 'رفتن به پرداخت';

  @override
  String get checkoutContinueButton => 'ادامه';

  @override
  String get checkoutPaymentCompletedSuccessfully => 'پرداخت با موفقیت انجام شد';

  @override
  String get checkoutMultiSellerInfoTitle => 'یک پرداخت، سفارش‌های جداگانه';

  @override
  String get checkoutMultiSellerInfoBody => 'یک پرداخت انجام می‌دهید و برای هر فروشنده یک سفارش جداگانه ساخته می‌شود.';

  @override
  String checkoutSellerSection(Object sellerName) {
    return '$sellerName';
  }

  @override
  String checkoutSellerFallback(int number) {
    return 'فروشنده $number';
  }

  @override
  String get checkoutSellerSubtotal => 'جمع فروشنده';

  @override
  String get checkoutProductsTotal => 'جمع محصولات';

  @override
  String get checkoutShippingMethod => 'روش ارسال';

  @override
  String get checkoutShippingCost => 'هزینه ارسال';

  @override
  String get checkoutShippingTotal => 'جمع هزینه ارسال';

  @override
  String get checkoutEstimatedDelivery => 'زمان تقریبی تحویل';

  @override
  String get checkoutSellerTotal => 'جمع فروشنده';

  @override
  String get checkoutMultiOrderSuccessTitle => 'پرداخت موفق بود';

  @override
  String get checkoutMultiOrderSuccessBody => 'پرداخت شما تکمیل شد و برای هر فروشنده سفارش جداگانه‌ای ایجاد شد.';

  @override
  String checkoutSellerOrderLabel(int number) {
    return 'سفارش فروشنده $number';
  }

  @override
  String get checkoutOpenOrder => 'مشاهده سفارش';

  @override
  String get checkoutMultiOrderExit => 'بازگشت به خانه';

  @override
  String get checkoutPaymentCancelledOrIncomplete => 'پرداخت لغو شد یا تکمیل نشد';

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
  String get cancelAppointmentConfirmation => 'آیا مطمئن هستید که می‌خواهید این نوبت را لغو کنید؟';

  @override
  String get keepAppointmentButton => 'نگه‌داشتن نوبت';

  @override
  String get appointmentCancelled => 'نوبت لغو شد';

  @override
  String get cancellationNotAllowed => 'لغو برای این نوبت مجاز نیست.';

  @override
  String get cancelAppointmentFailed => 'لغو نوبت ممکن نبود. لطفاً دوباره تلاش کنید.';

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
  String get okButton => 'تأیید';

  @override
  String get somethingWentWrong => 'مشکلی پیش آمد';

  @override
  String get alreadyBookedAtThisTime => 'شما در این زمان از قبل رزرو دارید. لطفاً زمان دیگری انتخاب کنید.';

  @override
  String get invalidBookingData => 'داده‌های رزرو نامعتبر است. لطفاً دوباره تلاش کنید.';

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
  String get alreadyReviewedThisVet => 'شما قبلاً این دامپزشک را بررسی کرده‌اید';

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
  String get myDogs => 'حیوانات خانگی من';

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
  String get deleteAccountConfirmation => 'آیا مطمئن هستید که می‌خواهید حساب خود را حذف کنید؟ این عمل قابل بازگشت نیست.';

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
  String get passwordValidation => 'حداقل ۸ کاراکتر، شامل یک حرف و یک عدد.';

  @override
  String get passwordMismatch => 'رمزهای عبور مطابقت ندارند';

  @override
  String get confirmPasswordRequired => 'لطفاً رمز عبور خود را تأیید کنید';

  @override
  String get termsRequired => 'باید شرایط و ضوابط را بپذیرید';

  @override
  String get forgotPasswordDialogTitle => 'فراموشی رمز عبور';

  @override
  String get forgotPasswordDialogMessage => 'لطفاً ایمیل خود را برای بازنشانی رمز عبور وارد کنید.';

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
  String get userNotFound => 'کاربری با این ایمیل یافت نشد. لطفاً ثبت‌نام کنید.';

  @override
  String get authUserNotFound => 'کاربر یافت نشد';

  @override
  String get pleaseVerifyEmailBeforeSigningIn => 'لطفاً قبل از ورود ایمیل خود را تأیید کنید.';

  @override
  String get userCreationFailed => 'ایجاد کاربر ناموفق بود';

  @override
  String get verificationEmailCouldNotBeSent => 'ایمیل تأیید ارسال نشد';

  @override
  String get verificationSessionCouldNotBeCreated => 'نشست تأیید ایجاد نشد';

  @override
  String get emailAlreadyRegisteredTryLoggingIn => 'این ایمیل قبلاً ثبت شده است. ورود را امتحان کنید.';

  @override
  String get incorrectPassword => 'رمز عبور نادرست است. لطفاً دوباره امتحان کنید.';

  @override
  String get fillAllFields => 'لطفاً همه فیلدها را به درستی پر کنید';

  @override
  String errorOccurred(Object error) {
    return 'خطایی رخ داد: $error';
  }

  @override
  String get verifyEmailTitle => 'ایمیل خود را تأیید کنید';

  @override
  String get enterVerificationCodeSentToEmail => 'کد تأیید ارسال‌شده به ایمیل خود را وارد کنید';

  @override
  String get pleaseEnterSixDigitCode => 'لطفاً کد ۶ رقمی را وارد کنید';

  @override
  String get emailVerifiedSuccessfully => 'ایمیل با موفقیت تأیید شد';

  @override
  String get invalidVerificationCode => 'کد تأیید نامعتبر است. لطفاً دوباره تلاش کنید.';

  @override
  String get verificationCodeExpired => 'این کد منقضی شده است. یک کد جدید درخواست کنید.';

  @override
  String get unableToVerifyEmail => 'در حال حاضر امکان تأیید وجود ندارد. لطفاً دوباره تلاش کنید.';

  @override
  String get unableToSendVerificationCode => 'در حال حاضر امکان ارسال کد جدید وجود ندارد. لطفاً دوباره تلاش کنید.';

  @override
  String verificationCodeSentTo(Object email) {
    return 'کد به این آدرس ارسال شد: $email';
  }

  @override
  String get verificationCodeSentToLabel => 'کد تأیید به این آدرس ارسال شد';

  @override
  String get sendingVerificationCode => 'در حال ارسال...';

  @override
  String resendCodeAvailableIn(Object seconds) {
    return 'ارسال مجدد کد تا $seconds ثانیه دیگر در دسترس است';
  }

  @override
  String get changeEmail => 'تغییر ایمیل';

  @override
  String verificationCodeSent(Object email) {
    return 'کد تأیید به $email ارسال شد';
  }

  @override
  String get enterCodeLabel => 'کد ۶ رقمی را وارد کنید';

  @override
  String get verifyButton => 'تأیید';

  @override
  String get authWelcomeBackSubtitle => 'به PetSupo خوش برگشتید';

  @override
  String get authCreateAccountSubtitle => 'حساب PetSupo خود را بسازید';

  @override
  String get sessionExpiredPleaseSignInAgain => 'نشست شما منقضی شد. لطفاً دوباره وارد شوید.';

  @override
  String get signInToAccessPlaymate => 'لطفاً برای دسترسی به پلی‌میت وارد شوید';

  @override
  String get findPlaymates => 'دوست پیدا کن';

  @override
  String get signInToFindFriends => 'برای پتت دوست پیدا کن';

  @override
  String get addYourDog => 'سگ خود را اضافه کنید';

  @override
  String get addYourPetTitle => 'حیوان خانگی خود را اضافه کنید';

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
  String get ageUnit => 'واحد';

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
  String get editDog => 'ویرایش پروفایل حیوان خانگی';

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
    return 'سگی با نام \"$name\" قبلاً وجود دارد';
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
  String get pleaseFillRequiredFields => 'لطفاً تمام فیلدهای الزامی را به درستی پر کنید';

  @override
  String get addDogButton => 'افزودن حیوان خانگی';

  @override
  String get dogDetailsAddTitle => 'افزودن سگ';

  @override
  String get dogDetailsEditTitle => 'ویرایش پروفایل حیوان خانگی';

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
  String get adjustFiltersSuggestion => 'فیلترهای خود را تنظیم کنید یا فاصله را افزایش دهید.';

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
  String get noProductsMatchFilters => 'هیچ محصولی با فیلترهای شما مطابقت ندارد';

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
  String get upgradeToPremiumForMoreFilters => 'برای فیلترهای بیشتر به نسخه پرمیوم ارتقا دهید!';

  @override
  String get upgradeToPremiumTitle => 'ارتقا به پرمیوم';

  @override
  String get upgradeToPremiumSubtitle => 'قابلیت‌های پیشرفته و ابزارهای کسب‌وکار را فعال کنید';

  @override
  String get apply => 'اعمال';

  @override
  String get favoritesPageTitle => 'سگ‌های مورد علاقه';

  @override
  String get noFavoriteDogsYet => 'هنوز هیچ سگ مورد علاقه‌ای وجود ندارد!';

  @override
  String get addFavoriteSuggestion => 'به صفحه اصلی برگردید و چند سگ به علاقه‌مندی‌های خود اضافه کنید.';

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
  String get pleaseLoginToSchedulePlaydate => 'لطفاً برای برنامه‌ریزی قرار بازی وارد شوید';

  @override
  String get selectLocation => 'انتخاب مکان';

  @override
  String get enterLocation => 'مکان را وارد کنید (مثال: عرض جغرافیایی: ۴۱.۰۱۰۳، طول جغرافیایی: ۲۸.۶۷۲۴ یا آدرس)';

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
  String playdateRequestNotificationBody(Object requesterDog, Object requestedDog) {
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
  String get areYouSure => 'آیا مطمئن هستید که می‌خواهید این درخواست را رد کنید؟';

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
  String get requestAcceptedSuccess => 'درخواست پذیرفته شد و به لیست قرارهای بازی اضافه شد.';

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
  String get failedToScheduleReminder => 'عدم موفقیت در برنامه‌ریزی یادآور. لطفاً مجوزها را بررسی کنید.';

  @override
  String get scheduledLabel => 'برنامه‌ریزی‌شده:';

  @override
  String get pleaseLoginToViewPlaydateRequests => 'برای مشاهده درخواست‌های قرار بازی وارد شوید';

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
  String get playdateTimeNotScheduledYet => '⏳ زمان قرار بازی هنوز برنامه‌ریزی نشده است';

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
  String get playmateLocationNeededMessage => 'برای نمایش سگ‌های نزدیک از موقعیت شما استفاده می‌کنیم';

  @override
  String get playmateFiltersTitle => 'فیلترها';

  @override
  String get playmateBreedPremiumHint => 'نژاد (PetSupo Partner)';

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
  String get dogParkPermissionDenied => 'اجازه مکان رد شد. لطفاً آن را در تنظیمات فعال کنید.';

  @override
  String get dogParkBackgroundPermissionDenied => 'اجازه مکان پس‌زمینه رد شد. برخی قابلیت‌ها ممکن است محدود شوند.';

  @override
  String get dogParkLocationServicesDisabled => 'خدمات مکان غیرفعال است.';

  @override
  String get dogParkEnableLocationServices => 'لطفاً خدمات مکان را برای ادامه فعال کنید.';

  @override
  String get dogParkPermissionDeniedPermanent => 'اجازه مکان به صورت دائمی رد شد.';

  @override
  String get dogParkPermissionsDenied => 'اجازه‌های مکان به صورت دائمی رد شده‌اند. لطفاً آن‌ها را از تنظیمات فعال کنید.';

  @override
  String dogParkLocationError(Object error) {
    return 'خطا در دریافت مکان: $error';
  }

  @override
  String get dogParkPermissionRequired => 'اجازه مکان برای نمایش پارک‌های سگ نزدیک الزامی است.';

  @override
  String get dogParkRecommendedBadge => '⭐ پیشنهادی';

  @override
  String get dogParkPremiumBadge => '🔒 پریمیوم';

  @override
  String get dogParkSavedBadge => '❤️ ذخیره شد';

  @override
  String get dogParkRecommendedForPlaydates => 'برای قرارهای بازی پیشنهاد می‌شود';

  @override
  String get dogParkSavedToFavorites => 'در علاقه‌مندی‌ها ذخیره شد';

  @override
  String get dogParkSaveThisPark => 'این پارک را ذخیره کنید';

  @override
  String get dogParkGetDirections => 'مسیر را نشان بده';

  @override
  String get dogParkUserNotReadyYet => 'کاربر هنوز آماده نیست. لطفاً دوباره تلاش کنید.';

  @override
  String get dogParkNeedToAddDogFirst => 'ابتدا باید یک سگ اضافه کنید';

  @override
  String get dogParkSchedulePlaydateHere => 'در اینجا قرار بازی را برنامه‌ریزی کنید';

  @override
  String get dogParkSavedParksTitle => 'پارک‌های ذخیره‌شده';

  @override
  String get dogParkNoSavedParksYet => 'هنوز پارک ذخیره‌شده‌ای نیست';

  @override
  String get dogParkFindNearbyParks => 'پارک‌های نزدیک را پیدا کنید';

  @override
  String get dogParkLocationNeededTitle => 'موقعیت لازم است';

  @override
  String get dogParkUseYourLocationToShowNearbyDogParks => 'برای نمایش پارک‌های سگ نزدیک از موقعیت شما استفاده می‌کنیم';

  @override
  String get allowButton => 'اجازه دادن';

  @override
  String get dogParkBackgroundRecommended => 'اجازه مکان پس‌زمینه توصیه می‌شود. لطفاً آن را در تنظیمات فعال کنید.';

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
  String dogViewPlayDateScheduled(Object day, Object month, Object year, Object time) {
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
  String get boostVisibilityDescription => 'در جست‌وجوی Playmates بیشتر دیده شوید.';

  @override
  String get boost24HoursTitle => 'ارتقای 24 ساعته';

  @override
  String get boostQuickVisibilitySubtitle => 'برای دیده شدن سریع مناسب است';

  @override
  String get boostPrice29 => '۲۹ لیر';

  @override
  String get boost3DaysTitle => 'ارتقای 3 روزه';

  @override
  String get boostBetterExposureSubtitle => 'نمایش بهتر برای جست‌وجوی فعال';

  @override
  String get boostPrice69 => '۶۹ لیر';

  @override
  String get boost7DaysTitle => 'ارتقای 7 روزه';

  @override
  String get boostBestValueSubtitle => 'بهترین ارزش برای بیشترین دسترسی';

  @override
  String get boostPrice129 => '۱۲۹ لیر';

  @override
  String get boostActivated => 'ارتقا فعال شد 🚀';

  @override
  String boostFailed(Object error) {
    return 'ارتقا ناموفق بود: $error';
  }

  @override
  String get errorOpeningEdit => 'خطا در باز کردن ویرایش';

  @override
  String get boostBadge => 'ارتقایافته';

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
  String dogInfoLiked(Object name) {
    return 'شما سگ $name را پسندیدید';
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
  String get locationServicesDisabled => 'خدمات مکان غیرفعال است. استفاده از مکان پیش‌فرض.';

  @override
  String get locationPermissionRequired => 'اجازه مکان الزامی است. استفاده از مکان پیش‌فرض.';

  @override
  String get locationPermissionPermanentlyDenied => 'اجازه مکان به صورت دائمی رد شده است. استفاده از مکان پیش‌فرض.';

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
  String get notificationChannelDescription => 'این کانال برای اعلان‌های مهم استفاده می‌شود.';

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
  String get noDogFoundForAccount => 'هیچ سگی برای حساب شما یافت نشد. لطفاً ابتدا یک سگ اضافه کنید.';

  @override
  String get pleaseSelectYourDog => 'لطفاً یکی از سگ‌های خود را انتخاب کنید';

  @override
  String get cannotScheduleWithOwnDog => 'نمی‌توانید با سگ خودتان قرار بازی ترتیب دهید.';

  @override
  String get cannotScheduleWithTempUser => 'نمی‌توان با کاربر موقت قرار بازی ترتیب داد.';

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
  String get pleaseSelectDogForPlaydate => 'لطفاً یکی از سگ‌های خود را برای قرار بازی انتخاب کنید';

  @override
  String get years => 'سال';

  @override
  String get months => 'ماه';

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
  String get playdateSchedulingSubtitle => 'تاریخ، زمان، مکان و سگ‌ها را برای قرار بازی انتخاب کنید.';

  @override
  String get errorSelectDateAndTime => 'لطفاً تاریخ و زمان را انتخاب کنید.';

  @override
  String get errorMissingLocationCoordinates => 'مختصات مکان پارک موجود نیست.';

  @override
  String get errorPlaydateLeadTime => 'قرار بازی باید حداقل ۱۵ دقیقه زودتر برنامه‌ریزی شود.';

  @override
  String get playdateTimeConflict => 'این سگ در این زمان نزدیک، از قبل یک قرار بازی دارد 🐾';

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
  String get locationNotAcquired => 'مکان دریافت نشد. لطفاً دوباره امتحان کنید.';

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
  String get offerPremiumBadge => 'پرمیوم';

  @override
  String get offerFallbackTitle => 'پیشنهاد ویژه برای کاربران PetSupo';

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
  String get offerPremiumRequiredMessage => 'این پیشنهاد فقط برای اعضای پریمیوم است.';

  @override
  String get offerCancel => 'لغو';

  @override
  String get offerUpgrade => 'ارتقا';

  @override
  String get offerUnlockingMessage => 'در حال باز کردن پیشنهاد شما...';

  @override
  String get offerChooseContinueTitle => 'انتخاب کنید از کجا ادامه دهید';

  @override
  String get offerChooseContinueSubtitle => 'روش ارتباطی دلخواه خود را برای این پیشنهاد انتخاب کنید.';

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
  String get pamperYourPet => 'ناز و نوازش برای پت شما';

  @override
  String get petShopTitle => 'پت شاپ';

  @override
  String get shopNearYou => 'خرید نزدیک شما';

  @override
  String get featuredDeal => 'پیشنهاد ویژه';

  @override
  String get featuredDealsEmptyTitle => 'پیشنهادهای ویژه';

  @override
  String get featuredDealsEmptyDescription => 'پیشنهادهای ویژه شرکای PetSupo در اینجا نمایش داده می‌شوند.';

  @override
  String get premiumLabel => 'پریمیوم';

  @override
  String get goldLabel => 'PetSupo Partner';

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
  String get createMemoriesTogether => 'با هم خاطره بسازید';

  @override
  String get reportFoundTitle => 'گزارش پیدا شدن';

  @override
  String get reconnectFamilies => 'به بازگشت حیوانات به خانواده‌هایشان کمک کنید';

  @override
  String get lostPetsTitle => 'حیوانات گمشده';

  @override
  String get activeReportsNearby => 'گزارش‌های فعال گم‌شدن را ببینید';

  @override
  String get foundPetsTitle => 'حیوانات پیدا شده';

  @override
  String get waitingToReunite => 'در انتظار بازگشت به خانه';

  @override
  String get trainingTitle => 'آموزش';

  @override
  String get comingSoon => 'به‌زودی';

  @override
  String get trainingComingSoonMessage => 'بخش آموزش به زودی اضافه می‌شود 🐾';

  @override
  String get communityHub => 'جامعه کاربران';

  @override
  String get safetyAndRescue => 'ایمنی و نجات';

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
  String get expertCareForYourPet => 'مراقبت تخصصی برای حیوان خانگی شما';

  @override
  String get homeLocationNeededTitle => 'موقعیت لازم است';

  @override
  String get homeLocationNeededMessage => 'برای نمایش دامپزشکان نزدیک از موقعیت شما استفاده می‌کنیم';

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
  String get groomyDealName => 'استودیوی Groomy';

  @override
  String get groomyDealDesc => '۲۰٪ تخفیف آرایش این هفته';

  @override
  String get vetDealName => 'پیشنهاد VetPlus';

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
  String get businessRegisterLegalCompanyNameRequired => '• نام قانونی شرکت الزامی است.';

  @override
  String get businessRegisterPublicDisplayNameRequired => '• نام نمایشی عمومی الزامی است.';

  @override
  String get businessRegisterSelectCountry => '• لطفاً یک کشور انتخاب کنید.';

  @override
  String get businessRegisterSelectBusinessCategory => '• لطفاً حداقل یک دسته‌بندی کسب‌وکار انتخاب کنید.';

  @override
  String get businessRegisterEnterValidEmail => '• یک ایمیل معتبر وارد کنید (مثال: name@example.com).';

  @override
  String get businessRegisterPhoneIncomplete => '• شماره تلفن ناقص است.';

  @override
  String get businessRegisterSelectCityProvince => '• لطفاً شهر / استان را انتخاب کنید.';

  @override
  String get businessRegisterSelectDistrict => '• لطفاً منطقه را انتخاب کنید.';

  @override
  String get businessRegisterBusinessAddressRequired => '• آدرس کسب‌وکار الزامی است.';

  @override
  String get businessRegisterAllLegalDocumentsRequired => '• همه مدارک قانونی موردنیاز باید بارگذاری شوند.';

  @override
  String get businessRegisterDocumentsVerifiedBeforeContinuing => '• مدارک باید قبل از ادامه تأیید شوند.';

  @override
  String get businessRegisterAcceptPlatformTerms => '• باید شرایط پلتفرم را بپذیرید.';

  @override
  String get businessRegisterAcceptLegalResponsibility => '• باید اظهارنامه مسئولیت قانونی را بپذیرید.';

  @override
  String get businessRegisterFixHighlightedFields => 'لطفاً فیلدهای مشخص‌شده را اصلاح کنید';

  @override
  String get businessRegisterOk => 'باشه';

  @override
  String get businessRegisterFailedToLoadCountries => 'بارگذاری کشورها ناموفق بود';

  @override
  String get businessRegisterFailedToLoadCities => 'بارگذاری شهرها ناموفق بود';

  @override
  String get businessRegisterFailedToLoadDistricts => 'بارگذاری مناطق ناموفق بود';

  @override
  String get businessRegisterPlatformLegalAgreement => 'توافق‌نامه قانونی پلتفرم';

  @override
  String get businessRegisterReadAndAccept => 'خواندم و می‌پذیرم';

  @override
  String get businessRegisterLocationPermissionDenied => 'مجوز موقعیت مکانی رد شد';

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
  String get businessRegisterSelectAtLeastOneBusinessCategory => 'لطفاً حداقل یک دسته‌بندی کسب‌وکار انتخاب کنید';

  @override
  String get businessRegisterPleaseEnterBusinessAddress => 'لطفاً آدرس کسب‌وکار را وارد کنید';

  @override
  String get businessRegisterMustAcceptAllAgreements => 'باید همه توافق‌نامه‌ها را بپذیرید';

  @override
  String get businessRegisterDocumentsVerifiedBeforeSubmission => 'مدارک باید قبل از ارسال تأیید شوند';

  @override
  String get businessRegisterApplicationSubmittedSuccessfully => 'درخواست با موفقیت ارسال شد';

  @override
  String get businessRegisterSubmissionFailed => 'ارسال ناموفق بود';

  @override
  String get businessRegisterUnexpectedErrorOccurred => 'خطای غیرمنتظره‌ای رخ داد';

  @override
  String get businessRegisterTitle => 'ثبت کسب‌وکار';

  @override
  String get businessRegisterStepIdentityCategories => 'هویت کسب‌وکار و دسته‌بندی‌ها';

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
  String get businessRegisterBusinessIdentitySubtitle => 'مشخص کنید کسب‌وکار شما چگونه در PetSupo نمایش داده شود.';

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
  String get businessRegisterBusinessCategoriesSubtitle => 'همه بخش‌هایی را که این کسب‌وکار در آن فعالیت می‌کند انتخاب کنید.';

  @override
  String get businessRegisterContactLocation => 'تماس و موقعیت مکانی';

  @override
  String get businessRegisterContactLocationSubtitle => 'این اطلاعات به مشتریان کمک می‌کند شما را پیدا کنند و با شما تماس بگیرند.';

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
  String get businessRegisterMapPickerComingSoon => 'انتخاب‌گر نقشه به‌زودی اضافه می‌شود';

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
  String get businessRegisterCompanyTypeQuestion => 'نوع کسب‌وکار شما چیست؟';

  @override
  String get businessRegisterCompanyTypeHelper => 'مدارک لازم برای بارگذاری بر اساس نوع کسب‌وکار شما تعیین می‌شود.';

  @override
  String get businessRegisterCompanyTypeSoleProprietorship => 'شخص حقیقی (Şahıs İşletmesi)';

  @override
  String get businessRegisterCompanyTypeLimitedCompany => 'شرکت با مسئولیت محدود (Limited Şirket)';

  @override
  String get businessRegisterCompanyTypeJointStockCompany => 'شرکت سهامی (Anonim Şirket)';

  @override
  String get businessRegisterCompanyTypeRequired => '• لطفاً نوع شرکت خود را انتخاب کنید.';

  @override
  String get businessRegisterCompanyTypeLabel => 'نوع شرکت';

  @override
  String get businessRegisterCompanyTypeLegacyUnspecified => 'نامشخص / قدیمی';

  @override
  String get businessRegisterTaxNumberVkn => 'شماره مالیاتی (VKN)';

  @override
  String get businessRegisterAutoFilledFromDocument => 'به‌صورت خودکار از مدرک پر شد';

  @override
  String get businessRegisterDocumentVerificationInconsistencies => 'در تأیید مدرک ناسازگاری وجود دارد. بررسی مدیر لازم است.';

  @override
  String get businessRegisterMersisNumber => 'شماره MERSIS';

  @override
  String get businessRegisterDocumentsSecurelyEncrypted => 'مدارک شما به‌صورت امن رمزگذاری و خودکار تأیید می‌شوند';

  @override
  String get businessRegisterVerifiedFromDocument => 'از مدرک تأیید شد';

  @override
  String get businessRegisterAutoFilledAfterVerification => 'پس از تأیید مدرک خودکار پر می‌شود';

  @override
  String get businessRegisterUploadTradeRegistryFirst => 'ابتدا مدرک ثبت تجاری را بارگذاری کنید';

  @override
  String get businessRegisterWaitingForDocumentVerification => 'در انتظار تأیید مدرک...';

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
  String get businessRegisterDocumentVerifiedSuccessfully => 'مدرک با موفقیت تأیید شد';

  @override
  String get businessRegisterCouldNotReadDocument => 'مدرک خوانده نشد، لطفاً دوباره بارگذاری کنید';

  @override
  String get businessRegisterVeterinary => 'دامپزشکی';

  @override
  String get businessRegisterGroomy => 'آرایش حیوانات (Groomy)';

  @override
  String businessRegisterStepOfFour(Object step) {
    return 'مرحله $step از ۴';
  }

  @override
  String get businessRegisterLegalConfirmation => 'تأیید قانونی';

  @override
  String get businessRegisterAcceptTermsKvkk => 'شرایط پلتفرم و سیاست حفاظت از داده‌های KVKK را می‌پذیرم.';

  @override
  String get businessRegisterReadInsideApp => 'خواندن داخل برنامه';

  @override
  String get businessRegisterOpenOfficialLegalPage => 'باز کردن صفحه قانونی رسمی';

  @override
  String get businessRegisterLegalVersion => 'نسخه v1.0 • آخرین به‌روزرسانی مه ۲۰۲۶';

  @override
  String get businessRegisterAgreementSecurelyStored => 'توافق شما به‌صورت امن ذخیره می‌شود و از نظر قانونی الزام‌آور است';

  @override
  String get businessRegisterLegalResponsibilityDeclaration => 'اعلام می‌کنم همه مدارک ارسال‌شده دقیق هستند و مسئولیت کامل قانونی را طبق قانون تجارت ترکیه می‌پذیرم.';

  @override
  String get businessRegisterUploaded => 'بارگذاری شد';

  @override
  String get businessRegisterReplaceDocument => 'جایگزینی مدرک';

  @override
  String get businessRegisterReplaceDocumentConfirmation => 'آیا مطمئن هستید می‌خواهید این فایل را جایگزین کنید؟';

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
  String get myAppointmentsLoginRequired => 'لطفاً برای مشاهده نوبت‌های خود وارد شوید';

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
  String get userProfileGuestSubtitle => 'برای دسترسی به همه قابلیت‌ها وارد شوید';

  @override
  String get userProfileLoginSignUp => 'ورود / ثبت‌نام';

  @override
  String get userProfileLanguageEnglish => 'انگلیسی';

  @override
  String get userProfileLanguagePersian => 'فارسی';

  @override
  String get userProfileLanguageTurkish => 'ترکی';

  @override
  String get userProfileUnlockBusinessFeatures => 'باز کردن قابلیت‌های کسب‌وکار 🚀';

  @override
  String get userProfileUpgradeBusinessDescription => 'برای ثبت کسب‌وکار و شروع دریافت مشتری به PetSupo Partner ارتقا دهید.';

  @override
  String get userProfileUpgradeToGold => 'ارتقا به PetSupo Partner';

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
  String get userProfileApplicationUnderReviewDescription => 'درخواست کسب‌وکار شما با موفقیت ارسال شده و در حال بررسی است.';

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
  String get userProfileUpgradeToGoldToContinue => 'برای ادامه به PetSupo Partner ارتقا دهید';

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
  String get userProfileUsernameMinLength => 'نام کاربری باید حداقل ۳ کاراکتر باشد';

  @override
  String get userProfileUsernameMaxLength => 'نام کاربری باید حداکثر ۲۰ کاراکتر باشد';

  @override
  String get userProfileUsernameNoSpaces => 'نام کاربری نمی‌تواند فاصله داشته باشد';

  @override
  String get userProfilePhoneInvalidCharacters => 'شماره تلفن شامل کاراکتر نامعتبر است';

  @override
  String get userProfileBioMaxLength => 'بیوگرافی باید کمتر از ۱۵۰ کاراکتر باشد';

  @override
  String get userProfileUsernameAlreadyTaken => 'این نام کاربری قبلاً گرفته شده است';

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
    return 'شناسه کالا: $sku';
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
  String get sectorDashboardNotImplementedYet => 'داشبورد این بخش هنوز پیاده‌سازی نشده است';

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
  String get catalogStrengthAddItemsMessage => 'برای تقویت کاتالوگ، محصول، توضیحات، رسانه و موجودی اضافه کنید.';

  @override
  String get catalogStrengthWeakDetailsMessage => 'جزئیات محصول شما هنوز ضعیف است. رسانه، توضیحات و اطلاعات موجودی بیشتری اضافه کنید.';

  @override
  String get catalogStrengthMediumLabel => 'متوسط';

  @override
  String get catalogStrengthMediumMessage => 'شروع خوبی است. برای افزایش دیده‌شدن، توضیحات کامل‌تر و رسانه بیشتر اضافه کنید.';

  @override
  String get catalogStrengthStrongLabel => 'قوی';

  @override
  String get catalogStrengthStrongMessage => 'کیفیت کاتالوگ عالی است. فهرست‌های شما قوی و کامل به نظر می‌رسند.';

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
    return 'مالیات بر ارزش افزوده $percent٪';
  }

  @override
  String get myOrdersLoginRequired => 'لطفاً برای مشاهده سفارش‌های خود وارد شوید';

  @override
  String get myOrdersTitle => 'سفارش‌های من';

  @override
  String get myOrdersUnknownProduct => 'محصول';

  @override
  String get myOrdersUnknownSeller => 'فروشنده';

  @override
  String myOrdersProductAndMore(Object product, int count) {
    return '$product + $count مورد دیگر';
  }

  @override
  String get myOrdersOrderNumberUnavailable => 'ناموجود';

  @override
  String get myOrdersDateUnavailable => 'تاریخ ناموجود';

  @override
  String get myOrdersSortNewest => 'تاریخ: جدیدترین';

  @override
  String get myOrdersSortOldest => 'تاریخ: قدیمی‌ترین';

  @override
  String get myOrdersSortProductAz => 'محصول: الف تا ی';

  @override
  String get myOrdersSortProductZa => 'محصول: ی تا الف';

  @override
  String get myOrdersSortSellerAz => 'فروشنده: الف تا ی';

  @override
  String get myOrdersSortSellerZa => 'فروشنده: ی تا الف';

  @override
  String get myOrdersSortAmountHigh => 'مبلغ: بیشترین';

  @override
  String get myOrdersSortAmountLow => 'مبلغ: کمترین';

  @override
  String get myOrdersProcessingStatus => 'در حال پردازش';

  @override
  String get myOrdersRefundedStatus => 'بازپرداخت‌شده';

  @override
  String get myOrdersReturnedStatus => 'مرجوع‌شده';

  @override
  String get myOrdersRefundedOrReturnedStatus => 'بازپرداخت / مرجوعی';

  @override
  String get ordersTitle => 'سفارش‌ها';

  @override
  String get searchByOrderIdOrProductNameHint => 'جستجو با شماره سفارش یا نام محصول';

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
  String get invoiceSimulatedAsUploaded => 'فاکتور به‌عنوان بارگذاری‌شده شبیه‌سازی شد';

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
  String get paymentWillBeTransferredByPetsupo => 'پرداخت توسط Petsupo منتقل خواهد شد';

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
  String get returnShippedBackFailed => 'امکان ثبت بازگشت به‌عنوان ارسال‌شده نبود';

  @override
  String get returnTrackingNumberLabel => 'شماره پیگیری بازگشت';

  @override
  String get returnTrackingNumberHelperText => 'شماره پیگیری ارائه‌شده برای ارسال بازگشتی را وارد کنید.';

  @override
  String get returnCarrierHelperText => 'از همان حمل‌کننده‌ای که برای تحویل اصلی استفاده شده است، استفاده کنید.';

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
  String get upgradeHeroSubtitle => 'امکانات پریمیوم، دیده‌شدن بهتر، پیشنهادهای اختصاصی و ابزارهای کسب‌وکار را فعال کنید.';

  @override
  String get premiumPlanSubtitle => 'برای صاحبان فعال حیوانات خانگی';

  @override
  String get premiumPlanFeatureUnlimitedChat => 'گفت‌وگوی نامحدود';

  @override
  String get premiumPlanFeatureAdvancedMatchingFilters => 'فیلترهای پیشرفته تطابق';

  @override
  String get premiumPlanFeatureExclusivePetOffers => 'پیشنهادهای اختصاصی حیوانات خانگی';

  @override
  String get premiumPlanFeatureBetterProfileExperience => 'تجربه بهتر پروفایل';

  @override
  String get goldPlanSubtitle => 'برای متخصصان و کسب‌وکارهای مراقبت از حیوانات خانگی';

  @override
  String get mostPopularLabel => 'محبوب‌ترین';

  @override
  String get goldPlanFeatureEverythingInPremium => 'همه چیز در پریمیوم';

  @override
  String get goldPlanFeatureBusinessRegistrationAccess => 'دسترسی به ثبت کسب‌وکار';

  @override
  String get goldPlanFeatureBoostedVisibility => 'دیده‌شدن بیشتر';

  @override
  String get goldPlanFeatureBusinessDashboardAccess => 'دسترسی به داشبورد کسب‌وکار';

  @override
  String get goldPlanFeaturePremiumChatAndOffers => 'گفت‌وگو و پیشنهادهای پریمیوم';

  @override
  String get storeNotReadyTryAgain => 'فروشگاه آماده نیست. دوباره تلاش کنید.';

  @override
  String get processingLabel => 'در حال پردازش...';

  @override
  String get restoreRequestSent => 'درخواست بازیابی ارسال شد.';

  @override
  String get restorePurchases => 'بازیابی خریدها';

  @override
  String get mobileSubscriptionVerificationFailed => 'تأیید اشتراک انجام نشد. لطفاً بازیابی خریدها را دوباره امتحان کنید.';

  @override
  String get mobileSubscriptionOwnershipConflict => 'این اشتراک به حساب دیگری در Petsupo متصل است. لطفاً با حسابی که قبلاً برای این اشتراک استفاده کرده‌اید وارد شوید.';

  @override
  String get deleteAccountStoreSubscriptionNotice => 'حذف حساب PetSupo اشتراک App Store یا Google Play را لغو نمی‌کند. پیش از حذف حساب، پرداخت فروشگاه را جداگانه لغو کنید.';

  @override
  String get manageStoreSubscription => 'مدیریت اشتراک فروشگاه';

  @override
  String get upgradePaymentTerms => 'پرداخت شما هنگام تأیید از حساب App Store شما کسر می‌شود. اشتراک‌ها به‌صورت خودکار تمدید می‌شوند مگر اینکه حداقل 24 ساعت قبل از پایان دوره فعلی لغو شوند.';

  @override
  String get autoRenewableMonthlySubscription => 'اشتراک ماهانه با تمدید خودکار';

  @override
  String get securePaymentNotice => 'پرداخت امن • هر زمان خواستید لغو کنید • برنامه‌ها توسط App Store مدیریت می‌شوند';

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
    return '• سگ: $dogName';
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
  String get adoptionIncomeRange0_2000 => '۰ تا ۲٬۰۰۰';

  @override
  String get adoptionIncomeRange2000_5000 => '۲٬۰۰۰ تا ۵٬۰۰۰';

  @override
  String get adoptionIncomeRange5000_10000 => '۵٬۰۰۰ تا ۱۰٬۰۰۰';

  @override
  String get adoptionIncomeRange10000Plus => '۱۰٬۰۰۰ به بالا';

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
  String get adoptionYearsOfExperienceHint => '۰ تا ۶۰';

  @override
  String get adoptionEnterYearsOfExperience => '0..60 را وارد کنید';

  @override
  String get adoptionPreviousDogQuestion => 'قبلاً سگ داشته‌اید؟ (بله/خیر)';

  @override
  String get adoptionPreviousDogReasonLabel => 'دلیل اینکه سگ قبلی دیگر با شما نیست';

  @override
  String get adoptionPreviousDogReasonHint => 'کوتاه توضیح دهید';

  @override
  String get adoptionExplainPreviousDog => 'حداقل 10 کاراکتر';

  @override
  String get adoptionOtherPetsAtHome => 'حیوانات خانگی دیگری در خانه هستند';

  @override
  String get adoptionDescribeOtherPetsLabel => 'حیوانات خانگی دیگر خود را توصیف کنید';

  @override
  String get adoptionDescribeOtherPetsHint => 'مثال: 2 گربه، واکسینه شده';

  @override
  String get adoptionRequiredShort => 'الزامی است';

  @override
  String get adoptionDescribeOtherPetsRequired => 'لطفاً حیوانات خانگی دیگر خود را توضیح دهید';

  @override
  String get adoptionMotivationMessageLabel => 'پیام انگیزه';

  @override
  String get adoptionMotivationMinLength => 'انگیزه باید حداقل 20 کاراکتر باشد';

  @override
  String get adoptionStepFinancialCommitmentTitle => '4️⃣ مالی و تعهد';

  @override
  String get adoptionCanAffordVetExpenses => 'توان پرداخت هزینه‌های دامپزشکی را دارد؟';

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
  String get adoptionAgreeContractRequiredLabel => 'با امضای قرارداد سرپرستی موافقم (الزامی)';

  @override
  String get adoptionAgreeContractRequired => 'باید با قرارداد سرپرستی موافقت کنید';

  @override
  String get adoptionUploadIdPhoto => 'لطفاً یک عکس کارت شناسایی بارگذاری کنید';

  @override
  String get adoptionNextButton => 'بعدی';

  @override
  String smartPriceSuggestedRangeLabel(Object currency, Object max, Object min) {
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
  String get discountRate1Label => '۱٪ تخفیف';

  @override
  String get discountRate10Label => '۱۰٪ تخفیف';

  @override
  String get discountRate20Label => '۲۰٪ تخفیف';

  @override
  String get carrierYurticiKargo => 'پست Yurtiçi Kargo';

  @override
  String get carrierArasKargo => 'پست Aras Kargo';

  @override
  String get carrierMngKargo => 'پست MNG Kargo';

  @override
  String get carrierSuratKargo => 'پست Sürat Kargo';

  @override
  String get carrierPttKargo => 'پست PTT Kargo';

  @override
  String get carrierHepsiJet => 'پست HepsiJET';

  @override
  String get carrierKolayGelsin => 'پست Kolay Gelsin';

  @override
  String get carrierUpsTurkiye => 'پست UPS ترکیه';

  @override
  String get carrierDhlExpress => 'ارسال سریع DHL';

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
  String get productAlreadyExistsDescription => 'این محصول از قبل وجود دارد. ویرایشگر محصول باز می‌شود.';

  @override
  String get continueButton => 'ادامه';

  @override
  String get productNameMustBeAtLeast4Chars => 'نام محصول باید حداقل 4 کاراکتر باشد';

  @override
  String get invalidBarcode => 'بارکد نامعتبر است';

  @override
  String get invalidSku => 'SKU نامعتبر است';

  @override
  String get invalidWholesalePrice => 'قیمت عمده نامعتبر است';

  @override
  String get wholesaleMinQuantityMustBeAtLeast2 => 'حداقل تعداد عمده باید حداقل 2 باشد';

  @override
  String get kdvRateIsRequired => 'یک نرخ مالیات بر ارزش افزوده انتخاب کنید';

  @override
  String get sellerRelationshipLabel => 'رابطه فروشنده';

  @override
  String get sellerRelationshipIsRequired => 'یک رابطه فروشنده انتخاب کنید';

  @override
  String get sellerRelationshipBrandOwner => 'مالک برند';

  @override
  String get sellerRelationshipManufacturer => 'تولیدکننده';

  @override
  String get sellerRelationshipAuthorizedDistributor => 'توزیع‌کننده مجاز';

  @override
  String get sellerRelationshipAuthorizedDealer => 'نماینده مجاز';

  @override
  String get sellerRelationshipImporter => 'واردکننده';

  @override
  String get sellerRelationshipReseller => 'فروشنده مجدد';

  @override
  String get mediaMaxTwentyEntries => 'حداکثر می‌توانید ۲۰ مورد رسانه اضافه کنید';

  @override
  String get invalidPrice => 'قیمت نامعتبر است';

  @override
  String get invalidDiscountPrice => 'قیمت تخفیف نامعتبر است';

  @override
  String get discountMustBeLowerThanOriginalPrice => 'قیمت تخفیف باید کمتر از قیمت اصلی باشد';

  @override
  String get wholesalePriceMustBeLowerThanRetailPrice => 'قیمت عمده باید کمتر از قیمت خرده‌فروشی باشد';

  @override
  String get invalidStock => 'موجودی نامعتبر است';

  @override
  String get stockMustBeAtLeastWholesaleMinQuantity => 'موجودی باید حداقل برابر حداقل تعداد عمده باشد';

  @override
  String get inventoryStockFieldLabel => 'موجودی';

  @override
  String get invalidLowStockAlert => 'هشدار موجودی کم نامعتبر است';

  @override
  String get addAtLeast1Media => 'حداقل 1 رسانه اضافه کنید';

  @override
  String get descriptionMustBeAtLeast10Characters => 'توضیحات باید حداقل 10 کاراکتر باشد';

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
  String get selectAtLeast1CargoCarrier => 'حداقل 1 شرکت حمل‌ونقل را انتخاب کنید';

  @override
  String get returnWindowCannotBeLessThan14Days => 'بازه بازگشت نمی‌تواند کمتر از 14 روز باشد';

  @override
  String get returnCarrierIsRequired => 'حمل‌کننده بازگشت لازم است';

  @override
  String get shippingPayerMismatch => 'عدم تطابق پرداخت‌کننده حمل';

  @override
  String get productSavedStatus => 'محصول ذخیره شد ✅';

  @override
  String get productSubmittedForReviewStatus => 'محصول برای بررسی ارسال شد. تا زمان تایید نمایش داده نخواهد شد.';

  @override
  String get veterinaryProductsNotSupported => 'فروش و تبلیغ محصولات دارویی دامپزشکی از طریق اینترنت پشتیبانی نمی‌شود.';

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
  String smartDescriptionAccessories(Object brand, Object name, Object subCategory) {
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
  String get productAlreadyExistsOpeningEditStatus => 'محصول موجود است، ویرایشگر باز می‌شود...';

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
  String get noBarcodeSkuHint => 'بارکد اختیاری است. اگر خالی باشد SKU به‌صورت خودکار ایجاد می‌شود.';

  @override
  String get scanButtonLabel => 'اسکن';

  @override
  String get skuCodeLabel => 'کد SKU';

  @override
  String get autoGeneratedSkuHint => 'اگر خالی باشد به‌صورت خودکار ایجاد می‌شود';

  @override
  String get skuLockedAfterCreation => 'پس از ایجاد آگهی، SKU قابل تغییر نیست. برای استفاده از SKU دیگر، این آگهی را حذف کرده و آگهی جدیدی ایجاد کنید.';

  @override
  String get deleteProductConfirmTitle => 'این محصول حذف شود؟';

  @override
  String get deleteProductConfirmMessage => 'این محصول برای همیشه حذف خواهد شد. این عملیات قابل بازگشت نیست.';

  @override
  String get deleteProductConfirmAction => 'حذف';

  @override
  String get deleteProductCancelAction => 'انصراف';

  @override
  String get deleteProductInProgress => 'در حال حذف…';

  @override
  String get deleteProductSuccess => 'محصول حذف شد';

  @override
  String get deleteProductAlreadyGone => 'این آگهی دیگر وجود ندارد';

  @override
  String get deleteProductPermissionDenied => 'شما اجازه حذف این محصول را ندارید';

  @override
  String get deleteProductNetworkError => 'حذف محصول ممکن نشد. اتصال خود را بررسی کرده و دوباره تلاش کنید.';

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
  String get appointmentNoLongerAvailable => 'این نوبت دیگر در دسترس نیست.';

  @override
  String get appointmentAvailabilityChecking => 'در حال بررسی وضعیت نوبت...';

  @override
  String get appointmentAvailabilityCheckFailed => 'امکان بررسی این نوبت وجود نداشت. لطفاً دوباره تلاش کنید.';

  @override
  String get petLabel => 'Pet';

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
  String get visibleOnlyToBusinessAccountsHint => 'فقط برای حساب‌های تجاری قابل مشاهده است';

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
  String get sellerContractedCarrierOnlyLabel => 'فقط در صورت حمل‌کننده قراردادی';

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
  String get returnAvailableAfterDeliveryMessage => 'امکان ثبت مرجوعی پس از تحویل فعال می‌شود.';

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
  String get selectReturnItemsLabel => 'مواردی را که می‌خواهید مرجوع کنید انتخاب کنید';

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
  String get returnShippingTitle => 'حمل مرجوعی';

  @override
  String get returnShippingBuyerMessage => 'هزینه حمل مرجوعی بر عهده شماست.\n\nهزینه پیک جدا از مبلغ بازپرداخت است و ممکن است بازپرداخت نشود.';

  @override
  String get returnShippingSellerMessage => 'هزینه حمل مرجوعی بر عهده فروشنده است.';

  @override
  String get returnShippingContractedCarrierMessage => 'از شرکت حمل قراردادی فروشنده برای مرجوعی استفاده کنید.';

  @override
  String get returnShippingBuyerShipBackMessage => 'هزینه پیک بر عهده شماست و جدا از مبلغ بازپرداخت است.';

  @override
  String get returnShippingSellerShipBackMessage => 'فروشنده هزینه حمل مرجوعی را پرداخت می‌کند.';

  @override
  String get returnShippingAcknowledgement => 'سیاست حمل مرجوعی را درک می‌کنم.';

  @override
  String get returnShippingPolicyLoading => 'در حال بارگذاری سیاست حمل مرجوعی…';

  @override
  String returnShippingCarrierValue(Object carrier) {
    return 'شرکت حمل: $carrier';
  }

  @override
  String get returnShippingVerifiedCarrierHelper => 'از این شرکت حمل قراردادی تأییدشده استفاده کنید.';

  @override
  String get returnCarrierEnterHelperText => 'شرکت حمل استفاده‌شده برای این مرجوعی را وارد کنید.';

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
  String get shippingResponsibilityContractCarrierLabel => 'فقط در صورت حمل‌کننده قراردادی';

  @override
  String get returnCarrierLabel => 'حمل‌کننده بازگشت';

  @override
  String get returnImagesAdded => 'تصاویر اضافه شدند';

  @override
  String get refundRejectedStatusLabel => 'بازگشت وجه رد شد';

  @override
  String get refundDecisionTitle => 'تصمیم بازپرداخت';

  @override
  String get refundDecisionFullTitle => 'بازپرداخت کامل';

  @override
  String get refundDecisionFullDescription => 'تمام مبلغ واجد شرایط را بازپرداخت کنید.';

  @override
  String get refundDecisionFullRecommended => 'برای کالای آسیب‌دیده یا معیوب، کالای اشتباه، خطای فروشنده یا کالای تحویل‌نشده توصیه می‌شود.';

  @override
  String get refundDecisionPartialTitle => 'بازپرداخت جزئی';

  @override
  String get refundDecisionPartialDescription => 'فقط بخشی از مبلغ واجد شرایط را بازپرداخت کنید. ارائه دلیل الزامی است.';

  @override
  String get refundDecisionRejectTitle => 'رد بازپرداخت';

  @override
  String get refundDecisionRejectDescription => 'درخواست بازپرداخت را رد کنید. توضیح روشن الزامی است.';

  @override
  String get refundPartialAmountLabel => 'مبلغ بازپرداخت جزئی';

  @override
  String refundMaximumEligible(Object amount) {
    return 'حداکثر مبلغ مجاز: $amount';
  }

  @override
  String get refundAmountValidationError => 'مبلغی بیشتر از صفر و حداکثر برابر مبلغ مجاز وارد کنید.';

  @override
  String get refundDecisionReasonLabel => 'دلیل';

  @override
  String get refundReasonNotSelected => 'یک دلیل انتخاب کنید';

  @override
  String get refundSellerNotesLabel => 'یادداشت فروشنده';

  @override
  String get refundNotesOptional => 'اختیاری';

  @override
  String get refundNotesRequired => 'الزامی';

  @override
  String get refundBuyerExplanationLabel => 'توضیح قابل مشاهده برای خریدار';

  @override
  String get refundBuyerExplanationHelper => 'علت رد بازپرداخت را به‌روشنی توضیح دهید.';

  @override
  String get refundOriginalOrderLabel => 'سفارش اصلی';

  @override
  String get refundSummaryRefundLabel => 'بازپرداخت';

  @override
  String get refundDifferenceLabel => 'تفاوت';

  @override
  String get refundDecisionBuyerTitle => 'تصمیم بازپرداخت';

  @override
  String get refundDecisionLabel => 'تصمیم';

  @override
  String get refundSellerExplanationLabel => 'توضیح فروشنده';

  @override
  String get refundReasonItemReturnedDamaged => 'کالا آسیب‌دیده بازگردانده شد';

  @override
  String get refundReasonMissingAccessories => 'لوازم جانبی ناقص است';

  @override
  String get refundReasonCustomerCausedDamage => 'آسیب توسط مشتری ایجاد شده';

  @override
  String get refundReasonRestockingFee => 'هزینه بازگردانی به انبار';

  @override
  String get refundReasonPartialReturn => 'مرجوعی جزئی';

  @override
  String get refundReasonSellerMistake => 'خطای فروشنده';

  @override
  String get refundReasonWrongItem => 'کالای اشتباه';

  @override
  String get refundReasonDefectiveProduct => 'کالای معیوب';

  @override
  String get refundReasonItemNeverDelivered => 'کالا تحویل نشده';

  @override
  String get refundReasonOther => 'سایر';

  @override
  String get returnStatusWaitingSellerConfirmation => 'در انتظار تأیید فروشنده';

  @override
  String get returnStatusAutoReceived => 'دریافت خودکار';

  @override
  String get returnStatusDispute => 'اختلاف مرجوعی';

  @override
  String get waitingForSellerInspectionTitle => 'در انتظار بررسی فروشنده';

  @override
  String waitingForSellerInspectionMessage(Object date) {
    return 'فروشنده تا $date برای بررسی بسته مرجوعی فرصت دارد. در صورت عدم اقدام، فرایند به‌طور خودکار ادامه می‌یابد.';
  }

  @override
  String get inspectionDeadlineTitle => 'مهلت بررسی';

  @override
  String inspectionDaysRemaining(int days) {
    return '$days روز باقی مانده';
  }

  @override
  String get inspectionDeadlinePassed => 'مهلت گذشته است. تکمیل خودکار در انتظار است.';

  @override
  String get reportReturnProblemTitle => 'گزارش مشکل مرجوعی';

  @override
  String get reportProblemButton => 'گزارش مشکل';

  @override
  String get disputeReasonLabel => 'دلیل مشکل';

  @override
  String get disputeReasonPackageNotReceived => 'بسته دریافت نشده';

  @override
  String get disputeReasonWrongItemReturned => 'کالای اشتباه بازگردانده شده';

  @override
  String get disputeReasonEmptyPackage => 'بسته خالی';

  @override
  String get disputeReasonDamagedDuringReturn => 'آسیب در زمان بازگشت';

  @override
  String get disputeReasonTrackingIssue => 'مشکل رهگیری';

  @override
  String get adminReturnDisputesTitle => 'اختلاف‌های مرجوعی';

  @override
  String get adminReturnDisputesSubtitle => 'بررسی مرجوعی‌های مورد اختلاف بازار';

  @override
  String get noReturnDisputes => 'مرجوعی مورد اختلافی وجود ندارد';

  @override
  String get locationUpdatedSuccessfully => 'موقعیت مکانی با موفقیت به‌روزرسانی شد';

  @override
  String get centersLoadError => 'بارگذاری مراکز انجام نشد';

  @override
  String get noAppointments => 'هیچ نوبتی وجود ندارد.';

  @override
  String get noAppointmentsFound => 'هیچ نوبتی پیدا نشد.';

  @override
  String appointmentsCount(Object count) {
    return '$count نوبت';
  }

  @override
  String get any => 'فرقی ندارد';

  @override
  String get search => 'جستجو...';

  @override
  String get accessDenied => 'دسترسی رد شد';

  @override
  String get skip => 'رد کردن';

  @override
  String searchService(Object service) {
    return 'جستجوی $service...';
  }

  @override
  String get petHotels => 'هتل حیوانات';

  @override
  String noItemsYet(Object title) {
    return 'هنوز $title وجود ندارد';
  }

  @override
  String get noSavedPostsYet => 'هنوز پست ذخیره‌شده‌ای وجود ندارد';

  @override
  String uploadedAt(Object date) {
    return 'تاریخ بارگذاری: $date';
  }

  @override
  String get productDetails => 'جزئیات محصول';

  @override
  String get servicesCouldNotBeLoaded => 'خدمات بارگیری نشدند';

  @override
  String get veterinaryClinics => 'کلینیک‌های دامپزشکی';

  @override
  String get noVeterinaryClinicsFound => 'هیچ کلینیک دامپزشکی پیدا نشد.';

  @override
  String get securePayment => 'پرداخت امن';

  @override
  String get liveDriver => 'راننده آنلاین';

  @override
  String get driver => 'راننده';

  @override
  String get myRides => 'سفرهای من';

  @override
  String get clientMessages => 'پیام‌های مشتریان';

  @override
  String get preVisitForm => 'فرم پیش از مراجعه';

  @override
  String get vetRevenueTitle => 'درآمد';

  @override
  String get vetRevenueDescription => 'داده‌های تأییدشده پرداخت و تسویه تراکنش‌های دامپزشکی تکمیل‌شده.';

  @override
  String get vetRevenueRange7Days => '۷ روز';

  @override
  String get vetRevenueRange30Days => '۳۰ روز';

  @override
  String get vetRevenueRange90Days => '۹۰ روز';

  @override
  String get vetRevenueRangeThisYear => 'امسال';

  @override
  String get vetRevenueRangeAllTime => 'همه زمان‌ها';

  @override
  String get vetRevenueGrossRevenue => 'درآمد ناخالص';

  @override
  String get vetRevenuePetsupoCommission => 'کمیسیون PetSupo';

  @override
  String get vetRevenueNetRevenue => 'درآمد خالص';

  @override
  String get vetRevenuePendingSettlement => 'تسویه در انتظار';

  @override
  String get vetRevenuePaidTransactions => 'تراکنش‌های پرداخت‌شده';

  @override
  String get vetRevenuePendingPayments => 'پرداخت‌های در انتظار';

  @override
  String get vetRevenueRefunded => 'بازپرداخت‌شده';

  @override
  String get vetRevenueExpiredOpportunities => 'فرصت‌های منقضی‌شده';

  @override
  String get vetRevenueMissingFinancialData => 'داده مالی مفقود';

  @override
  String vetRevenueMissingFinancialWarning(int count) {
    return 'داده مالی $count رکورد پرداخت‌شده ناقص یا نامعتبر است و در مجموع محاسبه نشده است.';
  }

  @override
  String get vetRevenueMixedCurrencyWarning => 'چند ارز وجود دارد. مبالغ جداگانه نمایش داده می‌شوند و تبدیل یا جمع نمی‌شوند.';

  @override
  String get vetRevenueNoAppointmentsTitle => 'هنوز نوبتی وجود ندارد';

  @override
  String get vetRevenueNoAppointmentsMessage => 'با ایجاد نوبت دامپزشکی، تحلیل درآمد اینجا نمایش داده می‌شود.';

  @override
  String get vetRevenueNoRangeTitle => 'در این بازه رکوردی نیست';

  @override
  String get vetRevenueNoRangeMessage => 'برای مشاهده تراکنش‌های قدیمی‌تر بازه بزرگ‌تری انتخاب کنید.';

  @override
  String get vetRevenueLoadErrorTitle => 'داده درآمد در دسترس نیست';

  @override
  String get vetRevenueLoadErrorMessage => 'اتصال را بررسی و دوباره تلاش کنید. رکوردهای پرداخت تغییر نکرده‌اند.';

  @override
  String get vetRevenueRetry => 'تلاش دوباره';

  @override
  String get vetRevenueTrendTitle => 'روند درآمد';

  @override
  String get vetRevenueMixedCurrencyChartHidden => 'به دلیل وجود چند ارز، نمودار ترکیبی نمایش داده نمی‌شود.';

  @override
  String get vetRevenueNoRecognizedRevenue => 'در این بازه درآمد پرداخت‌شده تأییدشده‌ای نیست.';

  @override
  String get vetRevenueTopServices => 'خدمات برتر بر اساس درآمد ناخالص';

  @override
  String get vetRevenueTransactions => 'تراکنش‌ها';

  @override
  String get vetRevenueUncategorized => 'بدون دسته‌بندی';

  @override
  String get vetRevenueSearchHint => 'جستجوی مشتری، حیوان، خدمت یا تراکنش';

  @override
  String get vetRevenueAllPayments => 'همه پرداخت‌ها';

  @override
  String get vetRevenuePaid => 'پرداخت‌شده';

  @override
  String get vetRevenuePending => 'در انتظار';

  @override
  String get vetRevenueExpired => 'منقضی‌شده';

  @override
  String get vetRevenueMissingFinancial => 'داده مالی مفقود';

  @override
  String get vetRevenueSortDate => 'مرتب‌سازی بر اساس تاریخ';

  @override
  String get vetRevenueSortDirection => 'تغییر جهت مرتب‌سازی';

  @override
  String get vetRevenueDate => 'تاریخ';

  @override
  String get vetRevenueCustomer => 'مشتری';

  @override
  String get vetRevenuePet => 'حیوان';

  @override
  String get vetRevenueService => 'خدمت';

  @override
  String get vetRevenueGross => 'ناخالص';

  @override
  String get vetRevenueCommission => 'کمیسیون';

  @override
  String get vetRevenueNet => 'خالص';

  @override
  String get vetRevenuePayment => 'پرداخت';

  @override
  String get vetRevenueSettlement => 'تسویه';

  @override
  String get vetRevenueInvoice => 'فاکتور';

  @override
  String get vetRevenueTransactionReference => 'مرجع تراکنش';

  @override
  String get vetRevenueNoMatchingTransactions => 'تراکنشی مطابق جستجو و فیلتر نیست.';

  @override
  String vetRevenuePageOf(int page, int total) {
    return 'صفحه $page از $total';
  }

  @override
  String get vetWebOverviewSubtitle => 'نمای کلی عملکرد و عملیات کلینیک';

  @override
  String get vetWebAppointmentsSubtitle => 'بررسی و مدیریت نوبت‌های دامپزشکی';

  @override
  String get vetWebRevenueSubtitle => 'تحلیل تأییدشده پرداخت، کمیسیون و تسویه';

  @override
  String get vetWebVeterinaryLabel => 'دامپزشکی';

  @override
  String get petShopsTitle => 'فروشگاه‌های حیوانات';

  @override
  String get searchPetShopsHint => 'جستجوی فروشگاه حیوانات';

  @override
  String get noPetShopsFound => 'فروشگاه حیوانات پیدا نشد';

  @override
  String get noPetShopsFoundDescription => 'جستجوی دیگری را امتحان کنید یا بعداً دوباره بررسی کنید.';

  @override
  String get loadingPetShops => 'در حال یافتن فروشگاه‌های نزدیک شما…';

  @override
  String get petShopsLoadError => 'فروشگاه‌ها بارگیری نشدند. دوباره تلاش کنید.';

  @override
  String get retryButton => 'تلاش دوباره';

  @override
  String get shopInformationTitle => 'اطلاعات فروشگاه';

  @override
  String get noShopDescriptionAvailable => 'توضیحی برای فروشگاه موجود نیست.';

  @override
  String get locationNotAvailable => 'موقعیت مکانی موجود نیست';

  @override
  String get getDirectionsLabel => 'مسیریابی';

  @override
  String get connectLabel => 'ارتباط';

  @override
  String get callLabel => 'تماس';

  @override
  String get whatsappLabel => 'واتساپ';

  @override
  String get websiteLabel => 'وب‌سایت';

  @override
  String get signInToContactShop => 'برای تماس با این فروشگاه وارد شوید.';

  @override
  String get petShopUnavailable => 'فروشگاه در دسترس نیست';

  @override
  String get petShopUnavailableDescription => 'این فروشگاه حیوانات دیگر در دسترس نیست.';

  @override
  String get reviewsCouldNotBeLoaded => 'نظرها بارگیری نشدند.';

  @override
  String get noProductsAvailableFromShop => 'محصولی از این فروشگاه موجود نیست';

  @override
  String get petShopLocationNeededMessage => 'برای نمایش فروشگاه‌های حیوانات نزدیک از موقعیت شما استفاده می‌کنیم';

  @override
  String get infoTitle => 'اطلاعات';

  @override
  String get processTitle => 'فرآیند';

  @override
  String get categoriesTitle => 'دسته‌بندی‌ها';

  @override
  String get contactTitle => 'تماس';

  @override
  String get openFullProfile => 'نمایش پروفایل کامل';

  @override
  String get noShopCategoriesAvailable => 'دسته‌بندی فروشگاه موجود نیست.';

  @override
  String get browseShopProductsDescription => 'محصولات موجود در این فروشگاه حیوانات را ببینید.';

  @override
  String get viewAllProducts => 'مشاهده همه محصولات';

  @override
  String get continueWithGoogle => 'ادامه با گوگل';

  @override
  String get continueWithApple => 'ادامه با اپل';

  @override
  String get connectAppleAccount => 'اتصال حساب اپل';

  @override
  String get appleAccountConnected => 'حساب اپل متصل شد';

  @override
  String get orContinueWith => 'یا ادامه با';

  @override
  String get authenticationCancelled => 'احراز هویت لغو شد';

  @override
  String get unableToSignIn => 'ورود امکان‌پذیر نیست';

  @override
  String get emailRegisteredWithAnotherProvider => 'این ایمیل با روش ورود دیگری ثبت شده است';

  @override
  String get completeYourProfile => 'پروفایل خود را کامل کنید';

  @override
  String get cityLabel => 'شهر';

  @override
  String get districtLabel => 'منطقه';

  @override
  String get cityRequired => 'لطفاً شهر خود را وارد کنید';

  @override
  String get districtRequired => 'لطفاً منطقه خود را وارد کنید';

  @override
  String get continueLabel => 'ادامه';

  @override
  String get petTaxiRequestRideTab => 'درخواست سفر';

  @override
  String get petTaxiRidesSubtitle => 'سفرهای آینده و گذشته Pet Taxi شما';

  @override
  String get petTaxiFilterActive => 'فعال و آینده';

  @override
  String get petTaxiFilterCompleted => 'تکمیل‌شده';

  @override
  String get petTaxiFilterCancelled => 'لغوشده';

  @override
  String get petTaxiNoRidesTitle => 'هنوز سفر Pet Taxi ندارید';

  @override
  String get petTaxiNoRidesDescription => 'پس از درخواست سفر، رزروهای Pet Taxi شما در اینجا نمایش داده می‌شوند.';

  @override
  String get petTaxiNoRidesInFilter => 'در این دسته سفری وجود ندارد';

  @override
  String get petTaxiTryAnotherFilter => 'برای دیدن سفرهای دیگر، دسته دیگری را انتخاب کنید.';

  @override
  String get petTaxiRidesLoading => 'در حال بارگیری سفرهای Pet Taxi شما';

  @override
  String get petTaxiRidesLoadErrorTitle => 'سفرهای شما بارگیری نشدند';

  @override
  String get petTaxiRidesLoadErrorDescription => 'اتصال خود را بررسی و دوباره تلاش کنید. رزروهای شما تغییری نکرده‌اند.';

  @override
  String get petTaxiSignInRequiredTitle => 'برای دیدن سفرها وارد شوید';

  @override
  String get petTaxiSignInRequiredDescription => 'رزروهای Pet Taxi پس از ورود در دسترس هستند.';

  @override
  String get petTaxiProviderLabel => 'ارائه‌دهنده';

  @override
  String get petTaxiProviderFallback => 'ارائه‌دهنده Pet Taxi';

  @override
  String get petTaxiDestinationLabel => 'مقصد';

  @override
  String get petTaxiScheduleUnavailable => 'زمان‌بندی موجود نیست';

  @override
  String get petTaxiPriceUnavailable => 'در انتظار قیمت';

  @override
  String get petTaxiStatusPending => 'درخواست در انتظار';

  @override
  String get petTaxiStatusAwaitingPayment => 'در انتظار پرداخت';

  @override
  String get petTaxiStatusConfirmedPaid => 'تأیید و پرداخت‌شده';

  @override
  String get petTaxiStatusPaymentFailed => 'پرداخت ناموفق';

  @override
  String get petTaxiStatusRefundPending => 'در انتظار بازپرداخت';

  @override
  String get petTaxiStatusRefunded => 'بازپرداخت‌شده';

  @override
  String get petTaxiStatusDriverOnTheWay => 'راننده در راه است';

  @override
  String get petTaxiStatusArrived => 'راننده رسیده است';

  @override
  String get petTaxiStatusPetPickedUp => 'حیوان تحویل گرفته شد';

  @override
  String get petTaxiStatusOnTrip => 'در مسیر';

  @override
  String get petTaxiStatusCompleted => 'تکمیل‌شده';

  @override
  String get petTaxiStatusCancelledByUser => 'توسط شما لغو شد';

  @override
  String get petTaxiStatusCancelledByProvider => 'توسط ارائه‌دهنده لغو شد';

  @override
  String get petTaxiStatusUnknown => 'وضعیت موجود نیست';

  @override
  String get petTaxiPaymentPaid => 'پرداخت‌شده';

  @override
  String get petTaxiPaymentPending => 'پرداخت در حال پردازش';

  @override
  String get petTaxiPaymentFailed => 'پرداخت ناموفق';

  @override
  String get petTaxiPaymentRefunded => 'بازپرداخت‌شده';

  @override
  String get petTaxiPaymentUnpaid => 'پرداخت‌نشده';

  @override
  String get webSubscriptionPaymentUnavailable => 'پرداخت موقتاً در دسترس نیست';

  @override
  String get webSubscriptionCatalogLoadFailed => 'قیمت‌های پرداخت امن بارگیری نشد. اتصال خود را بررسی کرده و دوباره تلاش کنید.';

  @override
  String get webSubscriptionCatalogUnauthenticated => 'برای بارگیری قیمت اشتراک و ادامه امن وارد شوید.';

  @override
  String get webSubscriptionCatalogFunctionNotFound => 'سرویس پرداخت امن در این نسخه برنامه در دسترس نیست. صفحه را تازه‌سازی کرده و دوباره تلاش کنید.';

  @override
  String get webSubscriptionCatalogConfigurationMissing => 'پیکربندی پرداخت امن موقتاً در دسترس نیست. لطفاً بعداً دوباره تلاش کنید.';

  @override
  String get webSubscriptionCatalogNetworkFailed => 'دسترسی به سرویس پرداخت امن ممکن نشد. اتصال خود را بررسی کرده و دوباره تلاش کنید.';

  @override
  String get webSubscriptionCatalogMalformed => 'سرویس پرداخت امن پاسخ نامعتبر برگرداند. لطفاً دوباره تلاش کنید.';

  @override
  String get webSubscriptionThirtyDayAccess => 'دسترسی اشتراک برای ۳۰ روز';

  @override
  String get webSubscriptionContinueSecurePayment => 'ادامه به پرداخت امن';

  @override
  String get webSubscriptionPaymentTerms => 'پرداخت یک‌باره برای ۳۰ روز دسترسی. تمدید خودکار کارت انجام نمی‌شود.';

  @override
  String get webSubscriptionIsbankSecurePayment => 'پرداخت امن با İş Bank • دسترسی ۳۰ روزه • بدون تمدید خودکار';

  @override
  String get webSubscriptionCheckoutFailed => 'پرداخت امن آغاز نشد. دوباره تلاش کنید.';

  @override
  String get webSubscriptionVerifyingTitle => 'در حال تأیید پرداخت';

  @override
  String get webSubscriptionVerifyingMessage => 'لطفاً تا تأیید امن پرداخت بانکی منتظر بمانید.';

  @override
  String get webSubscriptionSuccessTitle => 'اشتراک فعال شد';

  @override
  String get webSubscriptionSuccessMessage => 'پرداخت شما تأیید شد و دسترسی اشتراک ۳۰ روزه فعال است.';

  @override
  String get webSubscriptionFailedTitle => 'پرداخت تأیید نشد';

  @override
  String get webSubscriptionFailedMessage => 'اشتراک شما فعال نشد. پرداخت تأییدنشده دسترسی ایجاد نمی‌کند.';

  @override
  String get webSubscriptionCancelledTitle => 'پرداخت لغو شد';

  @override
  String get webSubscriptionCancelledMessage => 'پرداخت لغو شد و اشتراک شما تغییری نکرد.';

  @override
  String get webSubscriptionPendingTitle => 'پرداخت هنوز در حال پردازش است';

  @override
  String get webSubscriptionPendingMessage => 'بانک هنوز تأیید را کامل نکرده است. این صفحه دوباره به‌صورت خودکار بررسی می‌کند.';

  @override
  String chatError(Object error) {
    return 'خطای چت: $error';
  }

  @override
  String get bankAccountSettingsTitle => 'حساب بانکی';

  @override
  String get bankAccountSettingsSubtitle => 'این حساب برای ارسال درآمد کسب‌وکار شما توسط PetSupo استفاده خواهد شد.';

  @override
  String get bankAccountInfoNotice => 'لطفاً مطمئن شوید که نام صاحب حساب و شماره شبا دقیقاً با حساب بانکی رسمی شما مطابقت دارد. اطلاعات نادرست ممکن است باعث تأخیر در پرداخت‌ها شود.';

  @override
  String get bankAccountSectionTitle => 'اطلاعات حساب';

  @override
  String get bankAccountHolderLabel => 'صاحب حساب';

  @override
  String get bankAccountBankNameLabel => 'نام بانک';

  @override
  String get bankAccountIbanLabel => 'شماره شبا (IBAN)';

  @override
  String get bankAccountBillingInfoLabel => 'اطلاعات صورتحساب (اختیاری)';

  @override
  String get bankAccountIbanInvalid => 'شماره شبا باید با TR شروع شده و ۲۴ رقم داشته باشد.';

  @override
  String get bankAccountSaveSuccess => 'اطلاعات حساب بانکی ذخیره شد.';

  @override
  String get diagnosticsSectionTitle => 'عیب‌یابی';

  @override
  String get diagnosticsSectionDescription => 'ابزارهای داخلی عیب‌یابی برای بررسی صف و آزمایش بارگذاری.';

  @override
  String get diagnosticsThrowButton => 'ایجاد خطا';

  @override
  String get diagnosticsTestButton => 'آزمایش';

  @override
  String get diagnosticsUploadButton => 'بارگذاری';

  @override
  String get diagnosticsRefreshButton => 'تازه‌سازی';

  @override
  String get diagnosticsClearButton => 'پاک کردن';

  @override
  String dogCardAgeWithBreed(Object age, Object breed) {
    return '$age ساله • $breed';
  }

  @override
  String dogCardAgeYears(Object age) {
    return '$age ساله';
  }

  @override
  String dogCardVaccines(int count) {
    return '$count واکسن';
  }

  @override
  String get dogParkPremiumMembersOnly => 'این پارک فقط برای اعضای Premium در دسترس است.';

  @override
  String get favoritesExplorePlaymates => 'هم‌بازی‌ها را پیدا کن 💛';

  @override
  String get vetServicesAvailableAfterLogin => 'خدمات دامپزشکی پس از ورود در دسترس است';

  @override
  String get loadingAccount => 'در حال بارگذاری حساب...';

  @override
  String get noNotificationsForGuest => 'اعلانی برای مهمان وجود ندارد';

  @override
  String get loginForNotifications => 'برای دریافت به‌روزرسانی‌ها و هشدارها وارد شوید';

  @override
  String get offerDetailsTitle => 'پیشنهاد';

  @override
  String get offerDiscountOffLabel => 'تخفیف';

  @override
  String get offerUseCodeLabel => 'استفاده از کد:';

  @override
  String get offerUseThisOffer => 'استفاده از این پیشنهاد';

  @override
  String get playdateScheduledAtLabel => 'قرار بازی در این مکان برنامه‌ریزی می‌شود:';

  @override
  String get continueToScheduling => 'ادامه برنامه‌ریزی';

  @override
  String get orderCancellationTitle => 'لغو سفارش';

  @override
  String get preShipmentCancellationAvailable => 'این سفارش هنوز ارسال نشده و قابل لغو است.';

  @override
  String get cancelOrderButton => 'لغو سفارش';

  @override
  String get cancelOrderTitle => 'سفارش لغو شود؟';

  @override
  String get cancelOrderConfirmation => 'آیا مطمئن هستید که می‌خواهید این سفارش را لغو کنید؟ سفارش هنوز ارسال نشده است.';

  @override
  String get cancelOrderRefundNotice => 'پس از لغو، مبلغ پرداختی شما بازپرداخت می‌شود.';

  @override
  String get cancellationReasonLabel => 'دلیل لغو';

  @override
  String get cancelReasonOrderedByMistake => 'سفارش اشتباهی';

  @override
  String get cancelReasonChangedMind => 'تغییر تصمیم';

  @override
  String get cancelReasonDuplicateOrder => 'سفارش تکراری';

  @override
  String get cancelReasonOther => 'سایر';

  @override
  String get cancellationReasonDetailsLabel => 'توضیحات دلیل لغو';

  @override
  String get cancellationRefundProcessing => 'سفارش لغو شد. بازپرداخت شما در حال پردازش است.';

  @override
  String get cancellationShipmentAlreadyStarted => 'به دلیل شروع ارسال، این سفارش دیگر قابل لغو نیست.';

  @override
  String get cancelOrderFailed => 'لغو سفارش انجام نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get cancellationRefundProcessingStatus => 'درخواست لغو ثبت شد · بازپرداخت در حال پردازش';

  @override
  String get cancellationRefundFailedStatus => 'بازپرداخت لغو نیاز به بررسی دارد';

  @override
  String get orderCancelledRefundCompleted => 'سفارش لغو شد · بازپرداخت تکمیل شد';

  @override
  String get foundPetDetailsTitle => 'جزئیات حیوان پیدا‌شده';

  @override
  String get viewOnMap => 'مشاهده روی نقشه';

  @override
  String get contactReporter => 'تماس با گزارش‌دهنده';

  @override
  String get foundPetReportedSuccess => 'حیوان پیدا‌شده با موفقیت گزارش شد!';

  @override
  String errorSubmittingReport(Object error) {
    return 'خطا در ارسال گزارش: $error';
  }

  @override
  String get tapToSelectImage => 'برای انتخاب تصویر ضربه بزنید';

  @override
  String get foundPetsSubtitle => 'به حیوانات پیدا‌شده کمک کنید سالم به خانه بازگردند';

  @override
  String get searchByNameHint => 'جستجو بر اساس نام...';

  @override
  String get noFoundPetsReportedYet => 'هنوز حیوان پیدا‌شده‌ای گزارش نشده است';

  @override
  String get reportedFoundPetsAppearHere => 'حیوانات پیدا‌شده گزارش‌شده اینجا نمایش داده می‌شوند';

  @override
  String get lostPetDetailsTitle => 'جزئیات حیوان گمشده';

  @override
  String get havePetInformationPrompt => 'درباره این حیوان اطلاعاتی دارید؟';

  @override
  String get callOwner => 'تماس با صاحب';

  @override
  String get emailOwner => 'ایمیل به صاحب';

  @override
  String get lostPetReportedSuccess => 'حیوان گمشده با موفقیت گزارش شد!';

  @override
  String get lostPetsSubtitle => 'به حیوانات گمشده کمک کنید راه خانه را پیدا کنند';

  @override
  String get noLostPetsReportedYet => 'هنوز حیوان گمشده‌ای گزارش نشده است';

  @override
  String get reportedLostPetsAppearHere => 'حیوانات گمشده گزارش‌شده اینجا نمایش داده می‌شوند';

  @override
  String get searchUsersHint => 'جستجوی کاربران...';

  @override
  String get noUsersFound => 'کاربری یافت نشد';

  @override
  String get searchPetsAndUsers => 'جستجوی حیوانات و کاربران';

  @override
  String get findPetLoversNearby => 'دوستداران حیوانات نزدیک خود را پیدا کنید';

  @override
  String get selectAtLeastOnePhotoOrVideo => 'لطفاً حداقل یک عکس/ویدیو انتخاب کنید';

  @override
  String errorCreatingPost(Object error) {
    return 'خطا در ایجاد پست: $error';
  }

  @override
  String get createPostTitle => 'ایجاد پست';

  @override
  String get share => 'اشتراک‌گذاری';

  @override
  String get addPhotosOrVideos => 'افزودن عکس/ویدیو';

  @override
  String get writeSomethingHint => 'چیزی بنویسید...';

  @override
  String get replyHint => 'پاسخ...';

  @override
  String get replySent => 'پاسخ ارسال شد';

  @override
  String get close => 'بستن';

  @override
  String get videoStoriesComingSoon => 'استوری‌های ویدیویی به‌زودی ارائه می‌شوند';

  @override
  String get petploreTitle => 'Petplore';

  @override
  String get explorePetMoments => 'لحظه‌های حیوانات را کاوش کنید';

  @override
  String followersCount(int count) {
    return '$count دنبال‌کننده';
  }

  @override
  String followingCount(int count) {
    return '$count دنبال‌شونده';
  }

  @override
  String get feed => 'خوراک';

  @override
  String get saved => 'ذخیره‌شده';

  @override
  String get myPosts => 'پست‌های من';

  @override
  String get loginRequired => 'ورود الزامی است';

  @override
  String genericError(Object error) {
    return 'خطا: $error';
  }

  @override
  String get noPostsYet => 'هنوز پستی نیست';

  @override
  String get noResults => 'نتیجه‌ای یافت نشد';

  @override
  String get commentsTitle => 'دیدگاه‌ها';

  @override
  String commentsError(Object error) {
    return 'خطای دیدگاه‌ها: $error';
  }

  @override
  String get noCommentsYet => 'هنوز دیدگاهی نیست';

  @override
  String get writeCommentHint => 'دیدگاهی بنویسید...';

  @override
  String get postsTitle => 'پست‌ها';

  @override
  String get storyUploaded => 'استوری بارگذاری شد';

  @override
  String storyUploadFailed(Object error) {
    return 'بارگذاری استوری ناموفق بود: $error';
  }

  @override
  String get addStory => 'افزودن استوری';

  @override
  String get storyDurationPrompt => 'لحظه‌ای از حیوان خود را برای ۲۴ ساعت به اشتراک بگذارید';

  @override
  String get seeWhosNearby => 'ببینید چه کسی نزدیک شماست 👀!';

  @override
  String get telegramLab => 'آزمایشگاه تلگرام';

  @override
  String get telegramBotApiTest => 'آزمایش API ربات تلگرام';

  @override
  String get telegramTestInstructions => 'برای ارسال پیام آزمایشی دکمه زیر را فشار دهید.';

  @override
  String get sendTelegramMessage => 'ارسال پیام تلگرام';

  @override
  String get telegramUsers => 'کاربران تلگرام';

  @override
  String get termsLastUpdated => 'آخرین به‌روزرسانی: ۹ مه ۲۰۲۵';

  @override
  String get termsIntroductionTitle => '۱. مقدمه';

  @override
  String get termsIntroductionBody => 'به PetSupo خوش آمدید! با ثبت‌نام، این شرایط و ضوابط را می‌پذیرید. این برنامه برای یافتن هم‌بازی برای سگ‌ها، ارتباط با صاحبان حیوانات و دسترسی به خدمات مرتبط طراحی شده است. این شرایط استفاده شما از برنامه و خدمات PetSupo را تنظیم می‌کند.';

  @override
  String get termsResponsibilitiesTitle => '۲. مسئولیت‌های کاربر';

  @override
  String get termsResponsibilitiesBody => '- برای استفاده از برنامه باید حداقل ۱۳ سال داشته باشید.\n- حفظ محرمانگی حساب و رمز عبور بر عهده شماست.\n- نباید از برنامه برای فعالیت‌های غیرقانونی یا ممنوع استفاده کنید.\n- هنگام ثبت‌نام باید اطلاعات دقیق و به‌روز ارائه دهید.';

  @override
  String get termsPrivacyTitle => '۳. جمع‌آوری داده و حریم خصوصی';

  @override
  String get termsPrivacyBody => 'برای ارائه خدمات، داده‌هایی مانند نام کاربری، ایمیل، موقعیت و اطلاعات حیوان را جمع‌آوری می‌کنیم. مطابق قانون حفاظت از داده‌های شخصی ترکیه و قوانین بین‌المللی، پیش از پردازش رضایت صریح می‌گیریم، داده‌ها را فقط برای اهداف اعلام‌شده استفاده می‌کنیم، تدابیر امنیتی به‌کار می‌بریم و امکان دسترسی، اصلاح یا حذف را فراهم می‌کنیم. برای اعمال حقوق خود با info@petsupo.com تماس بگیرید.';

  @override
  String get termsUserContentTitle => '۴. محتوای کاربر';

  @override
  String get termsUserContentBody => '- مالکیت محتوای بارگذاری‌شده برای شما باقی می‌ماند.\n- با بارگذاری، مجوزی غیرانحصاری و بدون حق امتیاز برای استفاده و نمایش محتوا در برنامه به PetSupo می‌دهید.\n- نباید محتوای غیرقانونی، توهین‌آمیز یا ناقض حقوق دیگران بارگذاری کنید.';

  @override
  String get termsLiabilityTitle => '۵. محدودیت مسئولیت';

  @override
  String get termsLiabilityBody => 'PetSupo در قبال خسارت ناشی از استفاده شما از برنامه، از جمله تعامل با کاربران یا حیوانات دیگر، مسئول نیست و صحت اطلاعات ارائه‌شده توسط کاربران را تضمین نمی‌کند.';

  @override
  String get termsGoverningLawTitle => '۶. قانون حاکم';

  @override
  String get termsGoverningLawBody => 'این شرایط تابع قوانین جمهوری ترکیه است. مگر آنکه قانون بین‌المللی خلاف آن را ایجاب کند، اختلاف‌ها در دادگاه‌های استانبول حل می‌شوند.';

  @override
  String get termsChangesTitle => '۷. تغییر شرایط';

  @override
  String get termsChangesBody => 'ممکن است این شرایط را به‌روزرسانی کنیم. تغییرات مهم از طریق ایمیل یا اعلان درون‌برنامه‌ای اطلاع داده می‌شود. ادامه استفاده به معنی پذیرش شرایط جدید است.';

  @override
  String get termsContactTitle => '۷. تماس';

  @override
  String get termsContactBody => 'برای پرسش درباره این شرایط با info@petsupo.com تماس بگیرید.';

  @override
  String get pendingBusinessApprovals => 'تأییدهای در انتظار کسب‌وکار';

  @override
  String get invalidRequest => 'درخواست نامعتبر';

  @override
  String get noPendingBusinessRequests => 'درخواست کسب‌وکار در انتظاری نیست';

  @override
  String riskCount(Object count) {
    return '$count خطر';
  }

  @override
  String get verifiedLabel => 'تأییدشده';

  @override
  String get approve => 'تأیید';

  @override
  String get suspend => 'تعلیق';

  @override
  String get restore => 'بازگردانی';

  @override
  String get businessApproved => 'کسب‌وکار تأیید شد';

  @override
  String get businessRejected => 'کسب‌وکار رد شد';

  @override
  String get businessSuspended => 'کسب‌وکار تعلیق شد';

  @override
  String get businessRestored => 'کسب‌وکار بازگردانی شد';

  @override
  String actionFailed(Object error) {
    return 'عملیات ناموفق بود: $error';
  }

  @override
  String get adminDashboard => 'داشبورد مدیر';

  @override
  String dashboardError(Object error) {
    return 'خطای داشبورد:\n$error';
  }

  @override
  String get platformOverview => 'نمای کلی پلتفرم';

  @override
  String get adminActivity => 'فعالیت مدیر';

  @override
  String get developerTools => 'ابزارهای توسعه‌دهنده';

  @override
  String get testTelegramBotApi => 'آزمایش API ربات تلگرام';

  @override
  String get diagnostics => 'عیب‌یابی';

  @override
  String get diagnosticsDescription => 'گزارش‌های خرابی و عیب‌یابی راه‌اندازی';

  @override
  String get telegramUsersDescription => 'مشاهده کاربران متصل تلگرام';

  @override
  String adminActivityError(Object error) {
    return 'خطای فعالیت:\n$error';
  }

  @override
  String get noAdminActivity => 'هنوز فعالیت مدیری ثبت نشده';

  @override
  String get diagnosticReport => 'گزارش عیب‌یابی';

  @override
  String get diagnosticReportNotFound => 'گزارش عیب‌یابی یافت نشد';

  @override
  String get reopen => 'بازگشایی';

  @override
  String get resolve => 'حل';

  @override
  String get ignore => 'نادیده گرفتن';

  @override
  String get stackTrace => 'ردیابی پشته';

  @override
  String get breadcrumbsLogs => 'مسیرها / گزارش‌ها';

  @override
  String get noLogs => 'گزارشی نیست';

  @override
  String get rawJson => 'JSON خام';

  @override
  String get diagnosticReports => 'گزارش‌های عیب‌یابی';

  @override
  String get filters => 'فیلترها';

  @override
  String get noDiagnosticReports => 'گزارش عیب‌یابی نیست';

  @override
  String reasonValue(Object value) {
    return 'دلیل: $value';
  }

  @override
  String featureValue(Object value) {
    return 'ویژگی: $value';
  }

  @override
  String platformValue(Object value) {
    return 'پلتفرم: $value';
  }

  @override
  String versionValue(Object value) {
    return 'نسخه: $value';
  }

  @override
  String receivedValue(Object value) {
    return 'دریافت: $value';
  }

  @override
  String messageValue(Object value) {
    return 'پیام: $value';
  }

  @override
  String createdValue(Object value) {
    return 'ایجاد: $value';
  }

  @override
  String get adminActions => 'اقدامات مدیر';

  @override
  String get moderationCase => 'پرونده نظارت';

  @override
  String targetValue(Object value) {
    return 'هدف: $value';
  }

  @override
  String reportsCount(Object count) {
    return 'گزارش‌ها: $count';
  }

  @override
  String riskScoreValue(Object value) {
    return 'امتیاز خطر: $value';
  }

  @override
  String priorityValue(Object value) {
    return 'اولویت: $value';
  }

  @override
  String firestoreError(Object error) {
    return 'خطای Firestore: $error';
  }

  @override
  String get refundReview => 'بررسی بازپرداخت';

  @override
  String appointmentIdValue(Object value) {
    return 'شناسه نوبت: $value';
  }

  @override
  String paymentStatusValue(Object value) {
    return 'وضعیت پرداخت: $value';
  }

  @override
  String refundStatusValue(Object value) {
    return 'وضعیت بازپرداخت: $value';
  }

  @override
  String appointmentTimeValue(Object value) {
    return 'زمان نوبت: $value';
  }

  @override
  String cancellationTimeValue(Object value) {
    return 'زمان لغو: $value';
  }

  @override
  String hoursBeforeAppointmentValue(Object value) {
    return 'ساعت تا نوبت: $value';
  }

  @override
  String businessValue(Object value) {
    return 'کسب‌وکار: $value';
  }

  @override
  String userValue(Object value) {
    return 'کاربر: $value';
  }

  @override
  String petValue(Object value) {
    return 'حیوان: $value';
  }

  @override
  String amountPaidValue(Object value) {
    return 'مبلغ پرداختی: $value';
  }

  @override
  String refundReasonValue(Object value) {
    return 'دلیل بازپرداخت: $value';
  }

  @override
  String refundErrorValue(Object value) {
    return 'خطای بازپرداخت: $value';
  }

  @override
  String get approveRefund => 'تأیید بازپرداخت';

  @override
  String get rejectRefund => 'رد بازپرداخت';

  @override
  String refundReviewFailed(Object error) {
    return 'بررسی بازپرداخت ناموفق بود: $error';
  }

  @override
  String get note => 'یادداشت';

  @override
  String refundQueueError(Object error) {
    return 'خطای صف بازپرداخت: $error';
  }

  @override
  String get refundRequests => 'درخواست‌های بازپرداخت';

  @override
  String get noPendingRefundRequests => 'درخواست بازپرداخت در انتظاری نیست';

  @override
  String get reportsTitle => 'گزارش‌ها';

  @override
  String appointmentValue(Object value) {
    return 'نوبت: $value';
  }

  @override
  String cancelledValue(Object value) {
    return 'لغوشده: $value';
  }

  @override
  String amountValue(Object value) {
    return 'مبلغ: $value';
  }

  @override
  String statusValue(Object value) {
    return 'وضعیت: $value';
  }

  @override
  String get confirmViolation => 'تأیید تخلف';

  @override
  String get markClean => 'علامت‌گذاری به‌عنوان سالم';

  @override
  String get businessMetrics => 'شاخص‌های کسب‌وکار';

  @override
  String get businessSearch => 'جستجوی کسب‌وکار';

  @override
  String get searchBusinessNameHint => 'جستجوی نام کسب‌وکار...';

  @override
  String get suspendedLabel => 'تعلیق‌شده';

  @override
  String get filterByStatus => 'فیلتر بر اساس وضعیت';

  @override
  String get complaintCenter => 'مرکز شکایات';

  @override
  String get noData => 'داده‌ای نیست';

  @override
  String get noComplaintsFound => 'شکایتی یافت نشد';

  @override
  String categoryValue(Object value) {
    return 'دسته‌بندی: $value';
  }

  @override
  String get complaintDetail => 'جزئیات شکایت';

  @override
  String severityValue(Object value) {
    return 'شدت: $value';
  }

  @override
  String get evidence => 'مدرک';

  @override
  String get dismiss => 'رد کردن';

  @override
  String get fraudAnalytics => 'تحلیل تقلب';

  @override
  String get errorLoadingAnalytics => 'خطا در بارگذاری تحلیل‌ها';

  @override
  String get adminMapMonitor => 'پایش نقشه مدیر';

  @override
  String get platformMetrics => 'شاخص‌های پلتفرم';

  @override
  String get noMetricsData => 'داده شاخصی نیست';

  @override
  String lastUpdatedValue(Object value) {
    return 'آخرین به‌روزرسانی: $value';
  }

  @override
  String get revenueTitle => 'درآمد';

  @override
  String get noRevenueData => 'داده درآمدی نیست';

  @override
  String get auditLogs => 'گزارش‌های ممیزی';

  @override
  String verifiedValue(Object value) {
    return 'تأییدشده: $value';
  }

  @override
  String documentNumberValue(Object value) {
    return 'شماره سند: $value';
  }

  @override
  String get open => 'باز کردن';

  @override
  String get petTaxiDocument => 'سند تاکسی حیوانات';

  @override
  String get openPdf => 'باز کردن PDF';

  @override
  String get suspendedBusinesses => 'کسب‌وکارهای تعلیق‌شده';

  @override
  String get noDataReceived => 'داده‌ای دریافت نشد';

  @override
  String get noSuspendedBusinesses => 'کسب‌وکار تعلیق‌شده‌ای نیست';

  @override
  String get subscriptionDetails => 'جزئیات اشتراک';

  @override
  String planValue(Object value) {
    return 'طرح: $value';
  }

  @override
  String priceValue(Object value) {
    return 'قیمت: $value';
  }

  @override
  String get cancelSubscription => 'لغو اشتراک';

  @override
  String get expireNow => 'انقضا در حال حاضر';

  @override
  String get makePremium => '⭐ تبدیل به پریمیوم';

  @override
  String get upgradeToPartner => '👑 ارتقا به شریک PetSupo';

  @override
  String get downgradeToPremium => '⬇ تنزل به پریمیوم';

  @override
  String get extendThirtyDays => 'تمدید ۳۰ روزه';

  @override
  String get subscriptionManagement => 'مدیریت اشتراک';

  @override
  String get searchUserIdHint => 'جستجوی شناسه کاربر...';

  @override
  String get loadingSubscription => 'در حال بارگذاری اشتراک...';

  @override
  String get feedbackDetail => 'جزئیات بازخورد';

  @override
  String ratingValue(Object value) {
    return 'امتیاز: $value';
  }

  @override
  String contextValue(Object value) {
    return 'زمینه: $value';
  }

  @override
  String get messageLabel => 'پیام';

  @override
  String get userFeedback => 'بازخورد کاربر';

  @override
  String get noPayoutsFound => 'پرداختی یافت نشد';

  @override
  String get payoutManagement => 'مدیریت پرداخت‌ها';

  @override
  String get readyLabel => 'آماده';

  @override
  String get searchPayoutsHint => 'جستجوی سفارش، فروشنده، خریدار یا مرجع...';

  @override
  String get payoutMarkedReady => 'پرداخت آماده علامت‌گذاری شد';

  @override
  String get confirmPayout => 'تأیید پرداخت';

  @override
  String get bankTransferReference => 'مرجع انتقال بانکی';

  @override
  String get bankReferenceHint => 'مرجع بانکی / EFT / FAST';

  @override
  String get payoutMarkedPaid => 'پرداخت انجام‌شده علامت‌گذاری شد';

  @override
  String sellerValue(Object value) {
    return 'فروشنده: $value';
  }

  @override
  String buyerValue(Object value) {
    return 'خریدار: $value';
  }

  @override
  String referenceValue(Object value) {
    return 'مرجع: $value';
  }

  @override
  String get markReady => 'علامت آماده';

  @override
  String get markPaid => 'علامت پرداخت‌شده';

  @override
  String openEntity(Object id, Object type) {
    return 'باز کردن $type: $id';
  }

  @override
  String get globalAdminSearchHint => 'جستجوی کاربران، سگ‌ها، کسب‌وکارها، گزارش‌ها و شکایات...';

  @override
  String get globalAdminSearch => 'جستجوی سراسری مدیر';

  @override
  String get notAuthenticated => 'احراز هویت نشده';

  @override
  String get adoptionRequestNotFound => 'درخواست سرپرستی یافت نشد';

  @override
  String get backToRequests => 'بازگشت به درخواست‌ها';

  @override
  String get messageApplicant => 'پیام به متقاضی';

  @override
  String get unknownPet => 'حیوان ناشناس';

  @override
  String get adoptionRequest => 'درخواست سرپرستی';

  @override
  String get waitingForOwnerResponse => 'در انتظار پاسخ صاحب';

  @override
  String get doneWithIcon => '✅ انجام شد';

  @override
  String failedWithIcon(Object error) {
    return '❌ ناموفق: $error';
  }

  @override
  String get availablePets => 'حیوانات در دسترس';

  @override
  String get petsCouldNotBeLoaded => 'حیوانات بارگذاری نشدند.';

  @override
  String get noPetsAvailable => 'حیوانی در دسترس نیست';

  @override
  String get noImages => 'تصویری نیست';

  @override
  String get viewAvailablePets => 'مشاهده حیوانات در دسترس';

  @override
  String get signInToContinue => 'برای ادامه وارد شوید';

  @override
  String get writeReviewFirst => 'لطفاً ابتدا نظر خود را بنویسید';

  @override
  String get reviewSubmitted => 'نظر ارسال شد';

  @override
  String get reviewExperienceHint => 'تجربه خود را با دیگران در میان بگذارید';

  @override
  String get submitReview => 'ارسال نظر';

  @override
  String get adoptionCenterDetails => 'جزئیات مرکز سرپرستی';

  @override
  String get adoptionServices => 'خدمات سرپرستی';

  @override
  String get petTypes => 'انواع حیوانات';

  @override
  String get workingDays => 'روزهای کاری';

  @override
  String get vetCheckIncluded => 'معاینه دامپزشک شامل می‌شود';

  @override
  String get homeVisitAvailable => 'بازدید در منزل موجود است';

  @override
  String get transportSupport => 'پشتیبانی حمل‌ونقل';

  @override
  String get fosterSupport => 'پشتیبانی نگهداری موقت';

  @override
  String get media => 'رسانه';

  @override
  String get logo => 'نشان';

  @override
  String get approvedBusinesses => 'کسب‌وکارهای تأییدشده';

  @override
  String get searchBusinessesHint => 'جستجوی کسب‌وکارها...';

  @override
  String get noApprovedBusinesses => 'کسب‌وکار تأییدشده‌ای نیست';

  @override
  String get basic => 'پایه';

  @override
  String get disclaimerAccepted => 'سلب مسئولیت پذیرفته شد';

  @override
  String get mismatchDetected => '⚠ مغایرت شناسایی شد';

  @override
  String get languageCodeTr => 'TR';

  @override
  String get languageCodeEn => 'EN';

  @override
  String get riskFlags => 'نشان‌های خطر';

  @override
  String get noRiskFlags => 'نشان خطری نیست';

  @override
  String get adminNotes => 'یادداشت‌های مدیر';

  @override
  String get adminNotesHint => 'یادداشت‌های داخلی نظارت را اضافه کنید...';

  @override
  String get saveNotes => 'ذخیره یادداشت‌ها';

  @override
  String get adminNotesSaved => 'یادداشت‌های مدیر ذخیره شد ✅';

  @override
  String saveFailed(Object error) {
    return 'ذخیره ناموفق بود: $error';
  }

  @override
  String get noQuickRepliesFound => 'پاسخ سریعی یافت نشد';

  @override
  String get quickReplies => 'پاسخ‌های سریع';

  @override
  String get chatFailedToLoad => 'گفتگو بارگذاری نشد';

  @override
  String get noMessagesYet => 'هنوز پیامی نیست';

  @override
  String get typeMessageHint => 'پیامی بنویسید...';

  @override
  String get noRequests => 'درخواستی نیست';

  @override
  String phoneValue(Object value) {
    return 'تلفن: $value';
  }

  @override
  String genderValue(Object value) {
    return 'جنسیت: $value';
  }

  @override
  String petStatusUpdated(Object name) {
    return 'وضعیت $name به‌روزرسانی شد';
  }

  @override
  String statusUpdateFailed(Object error) {
    return 'به‌روزرسانی وضعیت ناموفق بود: $error';
  }

  @override
  String get deletePetQuestion => 'حیوان حذف شود؟';

  @override
  String deletePetConfirmation(Object name) {
    return 'آیا از حذف $name مطمئن هستید؟ این عمل قابل بازگشت نیست.';
  }

  @override
  String petDeleted(Object name) {
    return '$name حذف شد';
  }

  @override
  String deleteFailedWithError(Object error) {
    return 'حذف ناموفق بود: $error';
  }

  @override
  String get searchPetsHint => 'جستجوی حیوانات';

  @override
  String get noAdoptablePetsYet => 'هنوز حیوانی برای سرپرستی نیست';

  @override
  String get addAdoptablePetsDescription => 'حیوانات آماده سرپرستی را اضافه و وضعیتشان را اینجا مدیریت کنید.';

  @override
  String failedToLoadPets(Object error) {
    return 'بارگذاری حیوانات ناموفق بود:\n$error';
  }

  @override
  String breedValue(Object value) {
    return 'نژاد: $value';
  }

  @override
  String ageValue(Object value) {
    return 'سن: $value';
  }

  @override
  String get edit => 'ویرایش';

  @override
  String get noAdoptionPetsYet => 'هنوز حیوانی برای سرپرستی نیست';

  @override
  String get addPetsForAdoption => 'حیوانات آماده سرپرستی را اضافه کنید.';

  @override
  String get editAdoptionCenter => 'ویرایش مرکز واگذاری';

  @override
  String get pleaseAddCoverImage => 'لطفاً تصویر جلد اضافه کنید';

  @override
  String get addGalleryImages => 'افزودن تصاویر گالری';

  @override
  String get petNameLabel => 'نام حیوان';

  @override
  String get ageMonthsLabel => 'سن (ماه)';

  @override
  String get visible => 'قابل مشاهده';

  @override
  String failedToSetCover(Object error) {
    return 'تنظیم جلد ناموفق بود: $error';
  }

  @override
  String get uploadPetMedia => 'بارگذاری رسانه حیوان';

  @override
  String uploadedPercent(Object percent) {
    return '$percent٪ بارگذاری شد';
  }

  @override
  String get noMediaYet => 'هنوز رسانه‌ای نیست';

  @override
  String get cover => 'جلد';

  @override
  String get adoptionCenterInfo => 'اطلاعات مرکز واگذاری';

  @override
  String get centerNameLabel => 'نام مرکز';

  @override
  String get instagram => 'اینستاگرام';

  @override
  String get address => 'نشانی';

  @override
  String get saveCenterInfo => 'ذخیره اطلاعات مرکز';

  @override
  String get latestAdoptionApplications => 'آخرین درخواست‌های واگذاری';

  @override
  String get viewAll => 'مشاهده همه';

  @override
  String get tapForMoreDetails => 'برای جزئیات بیشتر ضربه بزنید';

  @override
  String get setAvailable => 'تنظیم به موجود';

  @override
  String get setReserved => 'تنظیم به رزروشده';

  @override
  String get setAdopted => 'تنظیم به واگذارشده';

  @override
  String get setPaused => 'تنظیم به متوقف';

  @override
  String get clients => 'مشتریان';

  @override
  String get searchPetOrOwnerHint => 'جستجو با نام حیوان یا صاحب';

  @override
  String get couldNotLoadClients => 'مشتریان بارگیری نشدند.';

  @override
  String get addClient => 'افزودن مشتری';

  @override
  String get ownerNameLabel => 'نام صاحب';

  @override
  String get notes => 'یادداشت‌ها';

  @override
  String get price => 'قیمت';

  @override
  String get saveClient => 'ذخیره مشتری';

  @override
  String get petOwnerNamesRequired => 'نام حیوان و صاحب الزامی است';

  @override
  String get clientSaved => 'مشتری ذخیره شد';

  @override
  String lastGrooming(Object date) {
    return 'آخرین آرایش: $date';
  }

  @override
  String get noClientsYet => 'هنوز مشتری‌ای نیست';

  @override
  String get addFirstGroomingClient => 'اولین مشتری آرایش را برای پیگیری مراجعات اضافه کنید.';

  @override
  String get clientProfile => 'نمایه مشتری';

  @override
  String get openAppointmentBooking => 'رزرو نوبت را از صفحه کسب‌وکار باز کنید';

  @override
  String get groomingHistory => 'تاریخچه آرایش';

  @override
  String get ownerNotFound => 'صاحب پیدا نشد';

  @override
  String get signInRequired => 'ورود الزامی است';

  @override
  String get addGroomingVisit => 'افزودن مراجعه آرایش';

  @override
  String get serviceVisitTitle => 'عنوان خدمت / مراجعه';

  @override
  String get saveVisit => 'ذخیره مراجعه';

  @override
  String get visitSaved => 'مراجعه ذخیره شد';

  @override
  String get editClient => 'ویرایش مشتری';

  @override
  String get salonSchedule => 'برنامه سالن';

  @override
  String get manageGroomingAppointments => 'مدیریت نوبت‌های آرایش';

  @override
  String amountTry(Object amount) {
    return '$amount لیر';
  }

  @override
  String get uploadGroomingMedia => 'بارگذاری رسانه آرایش';

  @override
  String get add => 'افزودن';

  @override
  String get afterPlatformCommission => 'پس از کمیسیون پلتفرم';

  @override
  String get recentAppointments => 'نوبت‌های اخیر';

  @override
  String get latestGroomingRequests => 'آخرین درخواست‌ها و جلسات آرایش';

  @override
  String appointmentError(Object error) {
    return 'خطای نوبت: $error';
  }

  @override
  String get noGroomingAppointmentsYet => 'هنوز نوبت آرایشی نیست';

  @override
  String get deleteService => 'حذف خدمت';

  @override
  String get deleteServiceConfirmation => 'آیا از حذف این خدمت مطمئن هستید؟';

  @override
  String get serviceDeleted => 'خدمت حذف شد';

  @override
  String get deleteFailed => 'حذف ناموفق بود';

  @override
  String get availabilityUpdated => 'ظرفیت به‌روزرسانی شد';

  @override
  String updateFailed(Object error) {
    return 'به‌روزرسانی ناموفق بود: $error';
  }

  @override
  String get availability => 'ظرفیت';

  @override
  String get capacityBookingExplanation => 'ظرفیت برای جلوگیری از اقامت‌های هم‌زمان بیش از اتاق‌های موجود استفاده می‌شود.';

  @override
  String get roomCapacity => 'ظرفیت اتاق';

  @override
  String get maximumPetsRooms => 'حداکثر حیوان / اتاق';

  @override
  String currentCapacity(int count) {
    return 'ظرفیت فعلی: $count';
  }

  @override
  String get saveAvailability => 'ذخیره ظرفیت';

  @override
  String get checkIn => 'پذیرش';

  @override
  String get completeStay => 'تکمیل اقامت';

  @override
  String alreadyStatus(Object status) {
    return 'از قبل $status';
  }

  @override
  String bookingUpdated(Object status) {
    return 'رزرو به‌روزرسانی شد: $status';
  }

  @override
  String bookingError(Object error) {
    return 'خطای رزرو: $error';
  }

  @override
  String get hotelProfile => 'نمایه هتل';

  @override
  String get hotelOverview => 'نمای کلی هتل';

  @override
  String get pendingRequests => 'درخواست‌های در انتظار';

  @override
  String get uploadHotelMedia => 'بارگذاری رسانه هتل';

  @override
  String get proposeFinalPrice => 'پیشنهاد قیمت نهایی';

  @override
  String get editProposedPrice => 'ویرایش قیمت پیشنهادی';

  @override
  String get notifyCustomerConfirmation => 'این کار به مشتری اطلاع می‌دهد.';

  @override
  String get finalPrice => 'قیمت نهایی';

  @override
  String get customerMustPayBeforeTrip => 'مشتری باید پیش از شروع سفر این مبلغ را در برنامه بپردازد.';

  @override
  String get sendPrice => 'ارسال قیمت';

  @override
  String get petTaxiOverview => 'نمای کلی تاکسی حیوانات';

  @override
  String get driverOnline => 'راننده آنلاین';

  @override
  String get petTaxiAwaitingActivation => 'تاکسی حیوانات در انتظار فعال‌سازی است.';

  @override
  String get petTaxiAvailabilityUpdateFailed => 'وضعیت آنلاین بودن راننده به‌روزرسانی نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get serviceDetailsSaveFailed => 'جزئیات خدمت ذخیره نشد.';

  @override
  String get priceDeterminedAfterExamination => 'اگر قیمت نهایی پس از معاینه تعیین می‌شود، خالی بگذارید.';

  @override
  String get editing => 'در حال ویرایش';

  @override
  String get setPriceDurationDescription => 'قیمت و مدت تقریبی نمایش‌داده‌شده به صاحبان حیوان را تعیین کنید.';

  @override
  String get serviceDetailsBeforeBooking => 'این جزئیات به صاحبان حیوان کمک می‌کند پیش از رزرو خدمت را بشناسند.';

  @override
  String get addCustomService => 'افزودن خدمت سفارشی';

  @override
  String get create => 'ایجاد';

  @override
  String get paymentSuccessful => 'پرداخت موفق بود';

  @override
  String get paymentCancelled => 'پرداخت لغو شد';

  @override
  String paymentFailedWithError(Object error) {
    return 'پرداخت ناموفق بود: $error';
  }

  @override
  String get appointmentPayment => 'پرداخت نوبت';

  @override
  String get done => 'انجام شد';

  @override
  String get payNow => 'اکنون پرداخت کنید';

  @override
  String get titleLabel => 'عنوان';

  @override
  String get noQuickRepliesYet => 'هنوز پاسخ سریعی نیست';

  @override
  String get quickRepliesDescription => 'برای پرسش‌های رایج مشتریان پاسخ‌های قابل استفاده مجدد بسازید.';

  @override
  String get inbox => 'صندوق ورودی';

  @override
  String inboxError(Object error) {
    return 'خطای صندوق ورودی:\n$error';
  }

  @override
  String get emergency => 'اورژانسی';

  @override
  String get noClientMessagesYet => 'هنوز پیام مشتری‌ای نیست';

  @override
  String get clientMessagesDescription => 'وقتی صاحبان حیوان با درمانگاه تماس بگیرند، گفتگوها اینجا ظاهر می‌شوند.';

  @override
  String get passportNumberFormat => 'شماره گذرنامه باید فقط شامل حروف بزرگ، عدد، - یا / باشد';

  @override
  String get medicalProfileUpdated => 'نمایه پزشکی به‌روزرسانی شد';

  @override
  String profileUpdateFailed(Object error) {
    return 'به‌روزرسانی نمایه ناموفق بود: $error';
  }

  @override
  String get confirmMicrochipNumber => 'تأیید شماره میکروچیپ';

  @override
  String get review => 'بازبینی';

  @override
  String get saveAnyway => 'ذخیره با این حال';

  @override
  String get medicalProfile => 'نمایه پزشکی';

  @override
  String get saveMedicalProfile => 'ذخیره نمایه پزشکی';

  @override
  String get ownerProfileUpdated => 'نمایه صاحب به‌روزرسانی شد';

  @override
  String get ownerProfile => 'نمایه صاحب';

  @override
  String couldNotSaveVisit(Object error) {
    return 'مراجعه ذخیره نشد: $error';
  }

  @override
  String get deleteVisit => 'حذف مراجعه';

  @override
  String get deleteVisitConfirmation => 'این مراجعه از پرونده پزشکی حذف شود؟';

  @override
  String couldNotDeleteVisit(Object error) {
    return 'مراجعه حذف نشد: $error';
  }

  @override
  String get deleteVisitTooltip => 'حذف مراجعه';

  @override
  String get addVaccine => 'افزودن واکسن';

  @override
  String get vaccine => 'واکسن';

  @override
  String get reminder => 'یادآوری';

  @override
  String get notifyBeforeNextDueDate => 'پیش از موعد بعدی اطلاع بده';

  @override
  String get saveVaccine => 'ذخیره واکسن';

  @override
  String get patientNotFound => 'بیمار پیدا نشد';

  @override
  String get editOwnerProfile => 'ویرایش نمایه صاحب';

  @override
  String get ownerEmergencyContactDetails => 'اطلاعات صاحب و تماس اضطراری';

  @override
  String get editMedicalProfile => 'ویرایش نمایه پزشکی';

  @override
  String get clinicalVeterinaryInformation => 'اطلاعات بالینی و دامپزشکی';

  @override
  String get visits => 'مراجعات';

  @override
  String get vaccines => 'واکسن‌ها';

  @override
  String get ownerInformation => 'اطلاعات صاحب';

  @override
  String get visitsUnavailable => 'مراجعات در دسترس نیست';

  @override
  String visitsError(Object error) {
    return 'خطای مراجعات: $error';
  }

  @override
  String get followUp => 'پیگیری';

  @override
  String get editVisitTooltip => 'ویرایش مراجعه';

  @override
  String get editMedicalNotes => 'ویرایش یادداشت‌های پزشکی';

  @override
  String get medicalNotes => 'یادداشت‌های پزشکی';

  @override
  String get editVaccineTooltip => 'ویرایش واکسن';

  @override
  String get deleteVaccineTooltip => 'حذف واکسن';

  @override
  String get deleteVaccine => 'حذف واکسن';

  @override
  String get deleteVaccineConfirmation => 'آیا از حذف این سابقه واکسن مطمئن هستید؟';

  @override
  String get editVaccine => 'ویرایش واکسن';

  @override
  String get vaccineName => 'نام واکسن';

  @override
  String get updateVaccine => 'به‌روزرسانی واکسن';

  @override
  String get completeVaccine => 'تکمیل واکسن';

  @override
  String get clientNote => 'یادداشت مشتری';

  @override
  String get businessInfo => 'اطلاعات کسب‌وکار';

  @override
  String get clinicName => 'نام درمانگاه';

  @override
  String get emergencyServiceEnabled => 'خدمت اورژانسی فعال';

  @override
  String get saveBusinessInfo => 'ذخیره اطلاعات کسب‌وکار';

  @override
  String get openAppointmentsTab => 'زبانه نوبت‌ها را از بالا باز کنید';

  @override
  String get viewAllAppointments => 'مشاهده همه نوبت‌ها';

  @override
  String get checkConnectionTryAgain => 'اتصال خود را بررسی و دوباره تلاش کنید.';

  @override
  String get editServiceTooltip => 'ویرایش خدمت';

  @override
  String get deleteServiceTooltip => 'حذف خدمت';

  @override
  String get noServicesAddedYet => 'هنوز خدمتی اضافه نشده';

  @override
  String get addFirstServiceDescription => 'اولین خدمت را اضافه کنید تا در دسترس صاحبان حیوان باشد.';

  @override
  String get servicesPricing => 'خدمات و قیمت‌گذاری';

  @override
  String get addService => 'افزودن خدمت';

  @override
  String get noServicesYet => 'هنوز خدمتی نیست.';

  @override
  String servicePriceDuration(Object price, Object currency, Object duration) {
    return '$price $currency • $duration دقیقه';
  }

  @override
  String get serviceTitle => 'عنوان خدمت';

  @override
  String get durationMinutes => 'مدت (دقیقه)';

  @override
  String get requireDeposit => 'نیاز به بیعانه';

  @override
  String get depositAmount => 'مبلغ بیعانه (₺)';

  @override
  String get featured => 'ویژه';

  @override
  String get active => 'فعال';

  @override
  String get photoUploadedSuccessfully => 'عکس با موفقیت بارگذاری شد';

  @override
  String get photoDeleted => 'عکس حذف شد';

  @override
  String get coverImageUpdated => 'تصویر جلد به‌روزرسانی شد';

  @override
  String get galleryManagement => 'مدیریت گالری';

  @override
  String get coverImage => 'تصویر جلد';

  @override
  String get tapToChangeCover => 'برای تغییر جلد ضربه بزنید';

  @override
  String get uploadCoverImage => 'بارگذاری تصویر جلد';

  @override
  String get tapToUploadClinicCover => 'برای بارگذاری عکس جلد درمانگاه ضربه بزنید';

  @override
  String get galleryPhotos => 'عکس‌های گالری';

  @override
  String get noGalleryPhotosYet => 'هنوز عکس گالری‌ای نیست';

  @override
  String get uploadClinicPhotosDescription => 'برای افزایش اعتماد و دیده‌شدن عکس‌های درمانگاه را بارگذاری کنید.';

  @override
  String get uploadFirstPhoto => 'بارگذاری اولین عکس';

  @override
  String get dragToReorderGallery => 'برای مرتب‌سازی عکس‌های گالری بکشید';

  @override
  String get patients => 'بیماران';

  @override
  String get back => 'بازگشت';

  @override
  String get patientRecords => 'پرونده‌های بیماران';

  @override
  String shownCount(int count) {
    return '$count نمایش داده شده';
  }

  @override
  String get searchPetOwnerBreed => 'جستجوی حیوان، صاحب یا نژاد';

  @override
  String get clear => 'پاک کردن';

  @override
  String preVisitSettingsLoadFailed(Object error) {
    return 'بارگیری تنظیمات پیش از مراجعه ناموفق بود: $error';
  }

  @override
  String get preVisitSettingsSaved => 'تنظیمات فرم پیش از مراجعه ذخیره شد';

  @override
  String settingsSaveFailed(Object error) {
    return 'ذخیره تنظیمات ناموفق بود: $error';
  }

  @override
  String get preVisitForms => 'فرم‌های پیش از مراجعه';

  @override
  String get servicePreVisitForms => 'فرم‌های پیش از مراجعه خدمت';

  @override
  String get serviceMedicalIntakeDescription => 'هر خدمت می‌تواند پرسش‌های پذیرش پزشکی خود را داشته باشد.';

  @override
  String get servicesCouldNotBeLoadedPeriod => 'خدمات بارگیری نشدند.';

  @override
  String get noActiveServicesForForms => 'هنوز خدمت فعالی نیست. پیش از ساخت فرم، خدمت اضافه کنید.';

  @override
  String get enableForService => 'فعال‌سازی برای این خدمت';

  @override
  String get onlyServiceAsksQuestions => 'فقط این خدمت این پرسش‌ها را می‌پرسد.';

  @override
  String get noQuestionsForService => 'هنوز پرسشی برای این خدمت نیست.';

  @override
  String get question => 'پرسش';

  @override
  String get questionExample => 'مثلاً آیا حیوان شما امروز غذا خورده است؟';

  @override
  String get remove => 'حذف';

  @override
  String get questionType => 'نوع پرسش';

  @override
  String get textType => 'متن';

  @override
  String get longTextType => 'متن بلند';

  @override
  String get yesNoType => 'بله / خیر';

  @override
  String get singleChoice => 'تک‌گزینه‌ای';

  @override
  String get multipleChoice => 'چندگزینه‌ای';

  @override
  String get numberType => 'عدد';

  @override
  String get requiredLabel => 'Required';

  @override
  String get options => 'گزینه‌ها';

  @override
  String optionNumber(int number) {
    return 'گزینه $number';
  }

  @override
  String get addOption => 'افزودن گزینه';

  @override
  String get clinicSchedule => 'برنامه درمانگاه';

  @override
  String get appointments => 'نوبت‌ها';

  @override
  String totalCount(int count) {
    return 'مجموع $count';
  }

  @override
  String get services => 'خدمات';

  @override
  String get addServiceFlowComingNext => 'فرایند افزودن خدمت به‌زودی ارائه می‌شود';

  @override
  String get clinicServices => 'خدمات درمانگاه';

  @override
  String get manageVisibleVetServices => 'مدیریت خدمات دامپزشکی قابل مشاهده';

  @override
  String get clinicSettings => 'تنظیمات درمانگاه';

  @override
  String get emergencyAvailabilitySaveFailed => 'ذخیره دسترسی اورژانسی ناموفق بود';

  @override
  String managementNotAvailable(Object label) {
    return 'مدیریت $label هنوز در دسترس نیست';
  }

  @override
  String loadError(Object error) {
    return 'خطای بارگیری: $error';
  }

  @override
  String get workingHoursSaved => 'ساعات کاری ذخیره شد';

  @override
  String saveError(Object error) {
    return 'خطای ذخیره: $error';
  }

  @override
  String get workingHours => 'ساعات کاری';

  @override
  String get clinicWorkingHours => 'ساعات کاری درمانگاه';

  @override
  String get manageOpeningDays => 'مدیریت روزهای کاری و دسترسی نوبت';

  @override
  String get editGroomyProfile => 'ویرایش نمایه آرایشگاه';

  @override
  String get groomyDetails => 'جزئیات آرایشگاه';

  @override
  String get homeService => 'خدمت در منزل';

  @override
  String get pickupService => 'خدمت تحویل‌گیری';

  @override
  String get photos => 'عکس‌ها';

  @override
  String get complete => 'تکمیل';

  @override
  String get awaitingPayment => 'در انتظار پرداخت';

  @override
  String appointmentUpdated(Object status) {
    return 'نوبت به‌روزرسانی شد: $status';
  }

  @override
  String get galleryComingSoon => 'گالری به‌زودی';

  @override
  String get editHotelProfile => 'ویرایش نمایه هتل';

  @override
  String pricePerNight(Object price) {
    return '$price₺ / شب';
  }

  @override
  String bookStayAt(Object hotel) {
    return 'رزرو اقامت • $hotel';
  }

  @override
  String get hotelCareNotesHint => 'یادداشت‌های تغذیه، دارو یا مراقبت';

  @override
  String get requestBooking => 'درخواست رزرو';

  @override
  String get checkoutAfterCheckin => 'تاریخ خروج باید پس از ورود باشد';

  @override
  String get hotelBookingRequestSent => 'درخواست رزرو هتل شما ارسال شد.';

  @override
  String get noGalleryImagesYet => 'هنوز تصویری در گالری نیست';

  @override
  String get petHotelDetails => 'جزئیات هتل حیوانات';

  @override
  String get amenities => 'امکانات';

  @override
  String get petTaxiDetails => 'جزئیات تاکسی حیوانات';

  @override
  String get petTaxiManualReviewNotice => 'درخواست تاکسی حیوانات شما تا بررسی و تأیید دستی مدارک منتشر نمی‌شود.';

  @override
  String get petTaxiReplacementExpiryDateDriverLicense => 'تاریخ انقضای جدید گواهینامه رانندگی';

  @override
  String get petTaxiReplacementExpiryDateTrafficInsurance => 'تاریخ انقضای جدید بیمه شخص ثالث';

  @override
  String get petTaxiReplacementExpiryRequired => 'پیش از ارسال جایگزین، یک تاریخ معتبر در آینده انتخاب کنید.';

  @override
  String get petTaxiReplacementSubmitted => 'جایگزین برای بررسی ارسال شد.';

  @override
  String get petTaxiDocumentsRequiringReplacement => 'مدارک نیازمند جایگزینی';

  @override
  String get petTaxiRejected => 'رد شده';

  @override
  String get petTaxiReplaceDocument => 'جایگزینی';

  @override
  String get transportationLawNotice => 'قوانین حمل‌ونقل ممکن است بر اساس شهر یا کشور متفاوت باشد. کسب‌وکارها مسئول رعایت مقررات محلی حمل‌ونقل، بیمه و مالیات هستند.';

  @override
  String get legalDocumentsPrivacyNotice => 'مدارک قانونی فقط برای بررسی صاحب کسب‌وکار و مدیر نگهداری می‌شوند و به کاربران عمومی نمایش داده نمی‌شوند.';

  @override
  String get savePetTaxiDetails => 'ذخیره جزئیات تاکسی حیوانات';

  @override
  String get driverVehicle => 'راننده و خودرو';

  @override
  String get vehicleType => 'نوع خودرو';

  @override
  String get preview => 'پیش‌نمایش';

  @override
  String get editPetShopProfile => 'ویرایش نمایه پت‌شاپ';

  @override
  String get petShopDetails => 'جزئیات پت‌شاپ';

  @override
  String get shopTypes => 'انواع فروشگاه';

  @override
  String get priceLevel => 'سطح قیمت';

  @override
  String get low => 'کم';

  @override
  String get mid => 'متوسط';

  @override
  String get high => 'زیاد';

  @override
  String get delivery => 'ارسال';

  @override
  String get hasDelivery => 'دارای ارسال';

  @override
  String get offers => 'پیشنهادها';

  @override
  String get hasOffers => 'دارای پیشنهاد';

  @override
  String get rejectedBusinesses => 'کسب‌وکارهای ردشده';

  @override
  String get noRejectedBusinesses => 'کسب‌وکار ردشده‌ای نیست';

  @override
  String get inheritedFromRegistration => 'از ثبت‌نام پایه به ارث رسیده';

  @override
  String get veterinaryDetails => 'جزئیات دامپزشکی';

  @override
  String get licenseReviewNotice => 'این شماره هنگام تأیید بررسی خواهد شد.';

  @override
  String get licenseExpiryDateNumbered => '۱۲. تاریخ انقضای مجوز';

  @override
  String get workingDaysNumbered => '۲۰. روزهای کاری';

  @override
  String get acceptedAnimalTypesNumbered => '۲۴. انواع حیوانات پذیرفته‌شده';

  @override
  String get confirmInformationAccurate => '۴۱. تأیید می‌کنم اطلاعات ارائه‌شده صحیح است';

  @override
  String get agreeDisplayInformation => '۴۲. با نمایش اطلاعاتم در برنامه موافقم';

  @override
  String get agreeDisplayReviews => '۴۳. با نمایش نظرات کاربران موافقم';

  @override
  String get acceptPartnershipTerms => '۴۴. شرایط همکاری PetSupo را می‌پذیرم';

  @override
  String get submitVeterinaryDetails => 'ارسال جزئیات دامپزشکی';

  @override
  String get adoptionCenterTemporary => 'مرکز واگذاری (موقت)';

  @override
  String reviewsCountParenthesized(Object count) {
    return ' ($count نظر)';
  }

  @override
  String get messageSendingTimedOut => 'زمان ارسال پیام به پایان رسید';

  @override
  String messageFailed(Object error) {
    return 'ارسال پیام ناموفق بود: $error';
  }

  @override
  String get chatCreating => 'گفتگو در حال ایجاد است...';

  @override
  String get startChatting => 'گفتگو را شروع کنید 👋';

  @override
  String get writeMessageHint => 'پیام بنویسید...';

  @override
  String get noChatsYet => 'هنوز گفتگویی نیست';

  @override
  String get startChattingWithPetOwners => 'با صاحبان حیوان گفتگو کنید و برای حیوانتان دوستان تازه بیابید 👋';

  @override
  String get failedToLoadChats => 'گفتگوها بارگیری نشدند';

  @override
  String get personalChatsCouldNotLoad => 'گفتگوهای شخصی بارگیری نشدند.';

  @override
  String get businessConversations => 'گفتگوهای کسب‌وکار';

  @override
  String get signInToUseChats => 'برای استفاده از گفتگوها وارد شوید';

  @override
  String get chats => 'گفتگوها';

  @override
  String get connectWithPetOwners => 'با صاحبان حیوان ارتباط برقرار کنید';

  @override
  String get noChatsFound => 'گفتگویی پیدا نشد';

  @override
  String get tryAnotherKeyword => 'کلیدواژه یا نام کاربری دیگری را امتحان کنید.';

  @override
  String get messages => 'پیام‌ها';

  @override
  String get failedToLoadMessages => 'پیام‌ها بارگیری نشدند';

  @override
  String get noConversationsYet => 'هنوز مکالمه‌ای نیست';

  @override
  String get userInboxEmptyDescription => 'وقتی با یک کسب‌وکار تماس بگیرید،\nمکالمات شما اینجا ظاهر می‌شوند.';

  @override
  String get medicalRecords => 'سوابق پزشکی';

  @override
  String get vaccinesVisitsAndTreatments => 'واکسن‌ها، ویزیت‌ها و درمان‌ها';

  @override
  String amountInTry(Object amount) {
    return '$amount لیر';
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
  String get payoutEligibleTab => 'واجد شرایط';

  @override
  String get payoutBatchesTab => 'بسته‌ها';

  @override
  String get payoutExceptionsTab => 'استثناها';

  @override
  String get payoutSelectAllEligible => 'انتخاب همه فروشندگان واجد شرایط';

  @override
  String get payoutCreateBatch => 'ایجاد بسته پرداخت';

  @override
  String payoutBatchCreated(Object batchNumber) {
    return 'بسته $batchNumber ایجاد شد';
  }

  @override
  String payoutOperationFailed(Object details) {
    return 'عملیات پرداخت ناموفق بود. $details';
  }

  @override
  String get payoutLoadFailed => 'اطلاعات پرداخت بارگیری نشد.';

  @override
  String get payoutNoExceptions => 'استثنایی وجود ندارد';

  @override
  String get payoutDateFilter => 'دوره پرداخت';

  @override
  String get payoutToday => 'امروز';

  @override
  String get payoutYesterday => 'دیروز';

  @override
  String get payoutThisWeek => 'این هفته';

  @override
  String get payoutLastWeek => 'هفته گذشته';

  @override
  String get payoutThisMonth => 'این ماه';

  @override
  String get payoutValidBankOnly => 'حساب بانکی معتبر';

  @override
  String get payoutUnknownSeller => 'اطلاعات فروشنده موجود نیست';

  @override
  String get payoutBankMissing => 'بانک ثبت نشده';

  @override
  String get payoutIncludedOrders => 'سفارش‌های شامل‌شده';

  @override
  String get payoutPeriod => 'دوره';

  @override
  String get payoutGrossTotal => 'مجموع ناخالص';

  @override
  String get payoutCommissionTotal => 'مجموع کمیسیون';

  @override
  String get payoutNetPayable => 'خالص قابل پرداخت';

  @override
  String get payoutNoBatches => 'بسته پرداختی وجود ندارد';

  @override
  String get payoutSellers => 'فروشنده';

  @override
  String get payoutExportXlsx => 'خروجی XLSX';

  @override
  String get payoutValid => 'معتبر';

  @override
  String get payoutBlocked => 'مسدود';

  @override
  String get payoutMissingBusiness => 'اطلاعات کسب‌وکار ناقص';

  @override
  String get payoutMissingAccountHolder => 'نام صاحب حساب موجود نیست';

  @override
  String get payoutMissingIban => 'شماره شبا موجود نیست';

  @override
  String get payoutInvalidIban => 'شماره شبا نامعتبر است';

  @override
  String get payoutMissingBankName => 'نام بانک موجود نیست';

  @override
  String get payoutNonPositiveAmount => 'مبلغ خالص باید مثبت باشد';

  @override
  String get payoutSettlementIncomplete => 'تسویه تکمیل نشده';

  @override
  String get payoutCommissionUnknown => 'کمیسیون نیاز به بررسی دارد';

  @override
  String get payoutCustomerPaid => 'پرداخت مشتری';

  @override
  String get payoutSellerNetNotCalculated => 'خالص فروشنده: محاسبه نشده';

  @override
  String get payoutExcludedFromPayout => 'خارج از پرداخت';

  @override
  String get payoutRefundedOrCancelled => 'سفارش مرجوع یا لغوشده';

  @override
  String get payoutAlreadyBatched => 'قبلاً به بسته اختصاص یافته';

  @override
  String get payoutAlreadyPaid => 'قبلاً پرداخت شده';

  @override
  String get payoutUnsupportedCurrency => 'ارز پشتیبانی نمی‌شود';

  @override
  String get payoutIneligible => 'پرداخت واجد شرایط نیست';

  @override
  String get payoutStatusFilter => 'وضعیت پرداخت';

  @override
  String get payoutSettlementFilter => 'وضعیت تسویه';

  @override
  String get payoutBatchFilter => 'تخصیص دسته';

  @override
  String get payoutIncludedInBatch => 'در دسته قرار دارد';

  @override
  String get payoutNotIncludedInBatch => 'در دسته قرار ندارد';

  @override
  String get payoutSellerFilter => 'فروشنده / کسب‌وکار';

  @override
  String get payoutBankFilter => 'بانک';

  @override
  String get payoutMinimumAmount => 'حداقل پرداخت';

  @override
  String get payoutMaximumAmount => 'حداکثر پرداخت';

  @override
  String get payoutCustomRange => 'بازه سفارشی';

  @override
  String get financeOverviewTab => 'نمای کلی';

  @override
  String get financeWaitingTab => 'در انتظار';

  @override
  String get financeEligibleSellers => 'فروشندگان واجد شرایط';

  @override
  String get financeEligibleRecords => 'سوابق واجد شرایط';

  @override
  String get financeWaitingSellers => 'فروشندگان در انتظار';

  @override
  String get financeWaitingRecords => 'سوابق در انتظار';

  @override
  String get financeWaitingAmount => 'مبلغ در انتظار';

  @override
  String get financeBlockedRecords => 'سوابق مسدود';

  @override
  String get financeExceptionCount => 'استثناها';

  @override
  String get financeTodaySales => 'فروش امروز';

  @override
  String get financeTodayCommission => 'کمیسیون امروز';

  @override
  String get financeTodayRefunds => 'بازپرداخت امروز';

  @override
  String get financeTodayEligible => 'واجد شرایط امروز';

  @override
  String get financeTodayPaid => 'پرداخت امروز';

  @override
  String get financeOutstandingLiability => 'تعهد پرداخت‌نشده';

  @override
  String get financeMonthlyPlatformRevenue => 'درآمد ماهانه پلتفرم';

  @override
  String get financeNextEligibilityDate => 'تاریخ واجد شرایط بعدی';

  @override
  String get financeDaysRemaining => 'روزهای باقی‌مانده';

  @override
  String get financeOldestWaitingRecord => 'قدیمی‌ترین سابقه در انتظار';

  @override
  String get financeAmountEligibleNext => 'مبلغ واجد شرایط بعدی';

  @override
  String get financeSendForReview => 'ارسال برای بررسی';

  @override
  String get financeApproveBatch => 'تأیید';

  @override
  String get financeRejectBatch => 'رد دسته';

  @override
  String get sellerFinanceTitle => 'مالی و درآمد';

  @override
  String get sellerFinanceDetails => 'جزئیات';

  @override
  String get sellerFinanceAvailable => 'موجودی قابل برداشت';

  @override
  String get sellerFinanceWaiting => 'موجودی در انتظار';

  @override
  String get sellerFinanceProcessing => 'در دسته / در حال پردازش';

  @override
  String get sellerFinancePaidThisMonth => 'پرداخت‌شده این ماه';

  @override
  String get sellerFinanceTotalEarnings => 'کل درآمد';

  @override
  String get sellerFinanceBlocked => 'مبلغ مسدود';

  @override
  String get sellerFinanceBankBlocked => 'پرداخت شما به دلیل ناقص بودن اطلاعات بانکی مسدود است.';

  @override
  String get sellerFinanceBankReady => 'حساب بانکی برای پرداخت‌ها آماده است';

  @override
  String get sellerFinanceUpdateBank => 'به‌روزرسانی حساب بانکی';

  @override
  String get sellerFinanceWaitingExplanation => 'درآمدها ۲۱ روز پس از پرداخت موفق واجد شرایط می‌شوند.';

  @override
  String get sellerFinanceWaitingSchedule => 'برنامه انتظار';

  @override
  String get sellerFinanceLastPayout => 'آخرین پرداخت';

  @override
  String get sellerFinanceOrders => 'سفارش';

  @override
  String get sellerFinanceAppointments => 'نوبت';

  @override
  String get sellerFinanceBookings => 'رزرو';

  @override
  String get sellerFinanceRides => 'سفر';

  @override
  String get sellerFinanceRequests => 'درخواست';

  @override
  String get financeRecommendedAction => 'اقدام پیشنهادی';

  @override
  String get financeOpenSeller => 'باز کردن فروشنده';

  @override
  String get financeTomorrowEligible => 'قابل پرداخت در فردا';

  @override
  String get financeNext7Days => '۷ روز آینده';

  @override
  String get financeNext30Days => '۳۰ روز آینده';

  @override
  String get financeEstimatedPayable => 'پرداخت تخمینی';

  @override
  String get financeStartProcessing => 'شروع پردازش';

  @override
  String get sellerFinanceEstimatedNext => 'پرداخت بعدی تخمینی';

  @override
  String get sellerFinanceTimeline => 'خط زمانی پرداخت';

  @override
  String get sellerFinanceTimelineValue => 'پرداخت‌شده ← انتظار (۲۱ روز) ← واجد شرایط ← در بسته ← انتقال ← تکمیل';

  @override
  String get sellerFinanceEligibleRecords => 'رکوردهای واجد شرایط';

  @override
  String get sellerFinancePayoutHistory => 'تاریخچه پرداخت';

  @override
  String get sellerFinanceExceptions => 'استثناها';

  @override
  String get financeMarkFailed => 'علامت‌گذاری ناموفق';

  @override
  String get financeFailureReason => 'دلیل شکست';

  @override
  String get userProfileCreatorProgram => 'برنامه سازندگان';

  @override
  String get userProfileOpenCreatorDashboard => 'داشبورد سازنده';

  @override
  String get creatorDashboardTitle => 'داشبورد سازنده';

  @override
  String get creatorWelcomeBack => 'خوش آمدید';

  @override
  String get creatorLevelLabel => 'سطح سازنده';

  @override
  String get creatorCurrentCampaign => 'کمپین فعلی';

  @override
  String get creatorReferralCodeLabel => 'کد معرف';

  @override
  String get creatorReferralLinkLabel => 'لینک معرف';

  @override
  String get creatorCopyCode => 'کپی کد';

  @override
  String get creatorCopyLink => 'کپی لینک';

  @override
  String get creatorReferralCodeCopied => 'کد معرف کپی شد';

  @override
  String get creatorReferralLinkCopied => 'لینک معرف کپی شد';

  @override
  String get creatorQualifiedUsers => 'کاربران واجد شرایط';

  @override
  String get creatorVerifiedPartners => 'شرکای تأیید شده';

  @override
  String get creatorPendingRewards => 'پاداش‌های در انتظار';

  @override
  String get creatorPaidRewards => 'پاداش‌های پرداخت‌شده';

  @override
  String get creatorRecentActivity => 'فعالیت‌های اخیر';

  @override
  String get creatorNoActivityYet => 'هنوز فعالیتی وجود ندارد';

  @override
  String get creatorNoActivityMessage => 'به محض استفاده کسی از لینک معرف شما، فعالیت اینجا نمایش داده می‌شود.';

  @override
  String get creatorUpcomingPayout => 'پرداخت بعدی';

  @override
  String get creatorEstimatedPayout => 'مبلغ تخمینی پرداخت';

  @override
  String get creatorPayoutDate => 'تاریخ پرداخت';

  @override
  String get creatorPayoutMethod => 'روش پرداخت';

  @override
  String get creatorOpenFullDashboard => 'باز کردن داشبورد کامل';

  @override
  String get creatorOpenFullDashboardHint => 'نمودارها، تحلیل‌ها و گزارش کامل را در وب مشاهده کنید';

  @override
  String get creatorPerformanceOverview => 'نمای کلی عملکرد';

  @override
  String get creatorTotalClicks => 'کل کلیک‌ها';

  @override
  String get creatorRegistrations => 'ثبت‌نام‌ها';

  @override
  String get creatorConversionRate => 'نرخ تبدیل';

  @override
  String get creatorRewardBreakdown => 'تفکیک پاداش';

  @override
  String get creatorPayoutHistory => 'تاریخچه پرداخت';

  @override
  String get creatorAnalytics => 'تحلیل‌ها';

  @override
  String get creatorReferralsTab => 'معرفی‌ها';

  @override
  String get creatorRewardsTab => 'پاداش‌ها';

  @override
  String get creatorFilters => 'فیلترها';

  @override
  String get creatorExport => 'خروجی گرفتن';

  @override
  String get creatorTimeframe7d => '۷ روز';

  @override
  String get creatorTimeframe30d => '۳۰ روز';

  @override
  String get creatorTimeframe90d => '۹۰ روز';

  @override
  String get creatorTimeframe12m => '۱۲ ماه';

  @override
  String get creatorSignInRequiredTitle => 'ورود لازم است';

  @override
  String get creatorSignInRequiredMessage => 'برای مشاهده داشبورد سازنده وارد شوید';

  @override
  String get creatorAccessDeniedTitle => 'دسترسی سازنده لازم است';

  @override
  String get creatorAccessDeniedMessage => 'این داشبورد فقط برای سازندگان تأییدشده پت‌سوپو در دسترس است.';

  @override
  String get creatorGoToSignIn => 'رفتن به ورود';

  @override
  String get creatorBadgesAchievements => 'نشان‌ها و دستاوردها';

  @override
  String get creatorProgressToNextLevelPrefix => 'پیشرفت تا';

  @override
  String get creatorTotalEarned => 'کل درآمد';

  @override
  String get creatorShareYourLink => 'لینک معرف خود را به اشتراک بگذارید';

  @override
  String get creatorStatusPaid => 'پرداخت‌شده';

  @override
  String get creatorStatusScheduled => 'زمان‌بندی‌شده';

  @override
  String get creatorExportComingSoon => 'خروجی گرفتن به‌زودی';

  @override
  String get creatorFiltersComingSoon => 'فیلترهای پیشرفته به‌زودی';

  @override
  String get creatorStatusLabel => 'وضعیت';

  @override
  String get creatorStatusActive => 'فعال';

  @override
  String get creatorStatusInactive => 'غیرفعال';

  @override
  String get creatorSampleData => 'داده نمونه';

  @override
  String get creatorOpenDashboardFailed => 'باز کردن داشبورد ممکن نشد. دوباره امتحان کنید.';

  @override
  String get referralCodeOptionalLabel => 'کد معرف (اختیاری)';

  @override
  String get referralCodeInvalid => 'این کد معرف در دسترس نیست. می‌توانید بدون آن ادامه دهید.';

  @override
  String get moderationNoHistory => 'هنوز سابقه‌ای از نظارت وجود ندارد';

  @override
  String get complaintNoMessages => 'هنوز پیامی وجود ندارد.';

  @override
  String get generatedFinanceReports => 'گزارش‌های مالی ایجادشده';

  @override
  String get noReportFilesGenerated => 'هیچ فایل گزارشی ایجاد نشد.';

  @override
  String get noEligibleSellers => 'در حال حاضر فروشنده واجد شرایطی وجود ندارد';

  @override
  String get viewWaitingSellers => 'مشاهده فروشندگان در انتظار';

  @override
  String get clearSearch => 'پاک کردن جستجو';

  @override
  String get exportFinanceReport => 'خروجی گرفتن از گزارش مالی';

  @override
  String exportOperationFailed(Object error) {
    return 'عملیات خروجی ناموفق بود: $error';
  }

  @override
  String get generatedXlsx => 'XLSX ایجادشده';

  @override
  String get batchExportedReady => 'دسته اکنون خروجی گرفته شده و آماده پردازش است.';

  @override
  String get regenerate => 'ایجاد مجدد';

  @override
  String get downloadXlsx => 'دانلود XLSX';

  @override
  String previewBatch(Object batch) {
    return 'پیش‌نمایش $batch';
  }

  @override
  String get auditHistory => 'سابقه حسابرسی';

  @override
  String get noAuditEvents => 'رویداد حسابرسی یافت نشد.';

  @override
  String get settlementRetryRequested => 'درخواست تلاش مجدد تسویه ثبت شد.';

  @override
  String get financialSnapshot => 'خلاصه مالی';

  @override
  String get openOrder => 'باز کردن سفارش';

  @override
  String get openSeller => 'باز کردن فروشنده';

  @override
  String get openFinancialSnapshot => 'باز کردن خلاصه مالی';

  @override
  String get retrySettlement => 'تلاش مجدد تسویه';

  @override
  String get dateRange => 'بازه زمانی';

  @override
  String get allRecords => 'همه رکوردها';

  @override
  String get today => 'امروز';

  @override
  String get thisWeek => 'این هفته';

  @override
  String get thisMonth => 'این ماه';

  @override
  String get customRange => 'بازه سفارشی';

  @override
  String get statuses => 'وضعیت‌ها';

  @override
  String get sector => 'بخش';

  @override
  String get allSectors => 'همه بخش‌ها';

  @override
  String get petShop => 'فروشگاه حیوانات';

  @override
  String get vet => 'دامپزشک';

  @override
  String get groomy => 'گِرومی';

  @override
  String get hotel => 'هتل';

  @override
  String get taxi => 'تاکسی';

  @override
  String get sellerBusinessIdOptional => 'شناسه کسب‌وکار فروشنده (اختیاری)';

  @override
  String get currency => 'واحد پول';

  @override
  String get allCurrencies => 'همه ارزها';

  @override
  String get tryCurrency => 'TRY';

  @override
  String get reportLanguage => 'زبان گزارش';

  @override
  String get turkish => 'ترکی';

  @override
  String get english => 'انگلیسی';

  @override
  String get both => 'هر دو';

  @override
  String get documentType => 'نوع سند';

  @override
  String get accountantCopy => 'نسخه حسابدار';

  @override
  String get internalRecordsCopy => 'نسخه سوابق داخلی';

  @override
  String get generateReports => 'ایجاد گزارش‌ها';

  @override
  String get download => 'دانلود';

  @override
  String get adoptionImpactOverview => 'مرور کلی اثرگذاری';

  @override
  String get adoptionPerformanceShelterActivity => 'عملکرد واگذاری و فعالیت پناهگاه';

  @override
  String get noAnimalsAvailableAdoption => 'در حال حاضر حیوانی برای واگذاری موجود نیست.\nبرای شروع پذیرش درخواست‌ها، اولین حیوان را اضافه کنید.';

  @override
  String get adoptionTrend => 'روند واگذاری';

  @override
  String get noAdoptionsYet => 'هنوز واگذاری‌ای انجام نشده است.';

  @override
  String get speciesBreakdown => 'تفکیک گونه‌ها';

  @override
  String get speciesUnavailable => 'گونه در دسترس نیست';

  @override
  String get adopted => 'واگذارشده';

  @override
  String get revenueTrend => 'روند درآمد';

  @override
  String get noRevenueTrendYet => 'هنوز روند درآمدی وجود ندارد';

  @override
  String paymentsCount(Object count) {
    return '$count پرداخت';
  }

  @override
  String get revenueBreakdown => 'تفکیک درآمد';

  @override
  String get noRevenueActivityYet => 'هنوز فعالیت درآمدی وجود ندارد';

  @override
  String get settlementTimeline => 'خط زمانی تسویه';

  @override
  String waitingCount(Object count) {
    return '$count در انتظار';
  }

  @override
  String get noPayoutsYet => 'هنوز پرداختی وجود ندارد';

  @override
  String get turnOnLocationServices => 'Turn On Location Services';

  @override
  String get petTaxiLocationServicesMessage => 'Pet Taxi needs location services enabled to show your live position on the map.';

  @override
  String get notNow => 'Not Now';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get allowLocationAccess => 'Allow Location Access';

  @override
  String get petTaxiLocationPermissionMessage => 'Pet Taxi needs location permission to enable My Location and center the map on you.';

  @override
  String get ok => 'OK';

  @override
  String get locationPermissionBlocked => 'Location Permission Blocked';

  @override
  String get petTaxiLocationBlockedMessage => 'Location access is blocked for Pet Taxi. Open app settings to allow location permission.';

  @override
  String get petTaxiBottomSubtitle => 'Safe & trusted transportation for your pet';

  @override
  String get petTaxiNoPetsFound => 'No pets found';

  @override
  String get petTaxiAddPetPrompt => 'Add a pet to request a Pet Taxi ride.';

  @override
  String get dailySummary => 'Daily Summary';

  @override
  String get sellers => 'Sellers';

  @override
  String sellerQueryError(Object error) {
    return 'Error: $error';
  }

  @override
  String get noSellersFound => 'No sellers found';

  @override
  String get medicalNotSigned => 'Not signed in';

  @override
  String get medicalNoPets => 'No pets found';

  @override
  String get cancelBookingQuestion => 'Cancel booking?';

  @override
  String get taxiBusinessNotified => 'The taxi business will be notified.';

  @override
  String get keepBooking => 'Keep';

  @override
  String get cancelBooking => 'Cancel booking';

  @override
  String get petTaxiBookingTitle => 'Pet Taxi Booking';

  @override
  String get petTaxiBookingNotFound => 'Booking not found';

  @override
  String get updating => 'Updating...';

  @override
  String get petTaxiPaymentTitle => 'Pet Taxi payment';

  @override
  String get paymentRequiredBeforeTrip => 'Payment is required before the trip starts. Provider payout is prepared after trip completion.';

  @override
  String get bookPetTaxi => 'Book Pet Taxi';

  @override
  String get transportResponsibilityDisclaimer => 'PetSupo only provides booking infrastructure. Transportation responsibility belongs to the provider.';

  @override
  String get petSafeForTransportation => 'I confirm my pet is safe for transportation.';

  @override
  String get petTaxiBusinessSummary => 'Pet taxi business summary';

  @override
  String get noPetsBeforeTaxiBooking => 'No pets found. Add a pet profile before booking.';

  @override
  String get selectPetForTaxiBooking => 'Select pet for taxi booking';

  @override
  String get selectPickupDateTime => 'Select pickup date and time';

  @override
  String get futurePickupDateTimeRequired => 'Select a future pickup date and time';

  @override
  String get bookingSummaryA11y => 'Booking summary';

  @override
  String get bookingSummaryTitle => 'Booking Summary';

  @override
  String get estimatedPetTaxiPriceRange => 'Estimated pet taxi price range';

  @override
  String get estimatedPrice => 'Estimated Price';

  @override
  String get routeEstimateNeeded => 'Select pickup/dropoff locations and pickup time to calculate a real driving-route estimate.';

  @override
  String routeEstimateDetail(Object distance, Object duration) {
    return '$distance km driving route • $duration min. Estimated based on Istanbul taxi tariff + pet transport service premium. Bridge, highway, waiting and provider-specific fees may be added. Final price will be confirmed by provider.';
  }

  @override
  String get petTaxiRouteUnavailable => 'بین مکان‌های انتخاب‌شده مسیر قابل رانندگی پیدا نشد. لطفاً مبدأ و مقصد را بررسی کنید.';

  @override
  String get routeEstimateUnavailable => 'برآورد مسیر در حال حاضر در دسترس نیست. مکان‌های انتخاب‌شده را بررسی کرده و دوباره تلاش کنید.';

  @override
  String get createPetTaxiBooking => 'Create pet taxi booking';

  @override
  String get creatingBooking => 'Creating booking...';

  @override
  String get petTaxiTitle => 'Pet Taxi';

  @override
  String get petTaxiSubtitle => 'Book safe pet transportation with reviewed taxi businesses.';

  @override
  String get searchTaxiBusinesses => 'Search taxi businesses';

  @override
  String locationSearchFailed(Object error) {
    return 'Location search failed: $error';
  }

  @override
  String addressLookupFailed(Object error) {
    return 'Address lookup failed: $error';
  }

  @override
  String currentLocationLoadFailed(Object error) {
    return 'Could not load current location: $error';
  }

  @override
  String get useSelectedLocation => 'Use Selected Location';

  @override
  String get searchRealAddress => 'Search real address';

  @override
  String get streetBuildingDistrict => 'Street, building, district';

  @override
  String get useMyCurrentLocation => 'Use My Current Location';

  @override
  String get helpCenterTitle => 'مرکز راهنما';

  @override
  String get helpCenterIntro => 'به کمک درباره PetSupo نیاز دارید؟ پاسخ‌ها را پیدا کنید و به‌راحتی با پشتیبانی تماس بگیرید.';

  @override
  String get frequentlyAskedQuestions => 'پرسش‌های متداول';

  @override
  String get emailAppUnavailable => 'باز کردن برنامه ایمیل ممکن نیست';

  @override
  String get emailCopied => 'ایمیل کپی شد';

  @override
  String get privacyPolicyContent => 'PetSupo به حریم خصوصی شما احترام می‌گذارد و متعهد به حفاظت از داده‌های شخصی شماست.\n\n1. داده‌های جمع‌آوری‌شده\nممکن است اطلاعات شخصی، موقعیت مکانی، اطلاعات حیوان، رسانه و داده‌های دستگاه و اعلان را جمع‌آوری کنیم.\n\n2. استفاده از داده‌ها\nداده‌ها برای ارائه خدمات، تطبیق کاربران، بهبود برنامه و ارسال اعلان با اجازه شما استفاده می‌شوند.\n\n3. اشتراک‌گذاری داده\nما داده‌های شخصی شما را نمی‌فروشیم و فقط با ارائه‌دهندگان مورد اعتماد یا طبق قانون به اشتراک می‌گذاریم.\n\n4. نگهداری و امنیت\nداده‌ها در سرورهای اروپا به‌صورت امن نگهداری می‌شوند.\n\n5. مدت نگهداری\nداده‌ها فقط تا زمان لازم نگهداری می‌شوند.\n\n6. حقوق شما\nمی‌توانید به داده‌ها دسترسی داشته باشید، اصلاح یا حذف آن‌ها را درخواست کنید و رضایت خود را پس بگیرید.\n\n7. حذف حساب\nبرای حذف حساب با ما تماس بگیرید.\n\n8. حریم خصوصی کودکان\nPetSupo برای کودکان زیر ۱۳ سال نیست.\n\n9. تغییرات\nممکن است این سیاست را به‌روزرسانی کنیم.\n\n10. تماس\nبرای پرسش‌ها با ما تماس بگیرید:';

  @override
  String get privacyContactTitle => '۷. تماس';

  @override
  String get privacyContactPrompt => 'اگر درباره این سیاست حریم خصوصی یا داده‌های خود پرسشی دارید، با ما تماس بگیرید:';

  @override
  String get privacyResponseTime => 'در اسرع وقت پاسخ خواهیم داد.';

  @override
  String get termsEmailCopied => 'ایمیل کپی شد';

  @override
  String get termsOfServiceTitle => 'شرایط استفاده از خدمات';

  @override
  String get termsIntro => 'با استفاده از PetSupo، شرایط زیر را می‌پذیرید:';

  @override
  String get termsResponseTime => 'هدف ما پاسخ‌گویی در زمانی معقول است.';

  @override
  String get invoiceNumberDateRequired => 'شماره و تاریخ فاکتور الزامی است';

  @override
  String invoiceUploadFailed(Object error) {
    return 'بارگذاری فاکتور ناموفق بود: $error';
  }

  @override
  String invoiceStatusMessage(Object status) {
    return 'فاکتور $status';
  }

  @override
  String invoiceReviewFailed(Object error) {
    return 'بررسی فاکتور ناموفق بود: $error';
  }

  @override
  String get openInvoice => 'باز کردن فاکتور';

  @override
  String get invoiceNumber => 'شماره فاکتور';

  @override
  String get invoiceDate => 'تاریخ فاکتور';

  @override
  String get invoiceType => 'نوع فاکتور';

  @override
  String get individual => 'شخصی';

  @override
  String get company => 'شرکت';

  @override
  String get noteOptional => 'یادداشت (اختیاری)';

  @override
  String get rejectionReasonOptional => 'دلیل رد (اختیاری)';

  @override
  String get paymentSuccessTitle => 'پرداخت موفق بود';

  @override
  String get paymentSuccessMessage => 'پرداخت با موفقیت انجام شد ✅';

  @override
  String get paymentFailedTitle => 'پرداخت ناموفق بود';

  @override
  String get paymentFailedMessage => 'تأیید پرداخت ناموفق بود ❌';

  @override
  String get paymentCancelledTitle => 'پرداخت لغو شد';

  @override
  String get paymentCancelledMessage => 'پرداخت لغو شد ⚠️';

  @override
  String get submitComplaintTitle => 'ارسال شکایت';

  @override
  String get submitComplaintConfirmation => 'آیا مطمئن هستید که می‌خواهید این شکایت را ارسال کنید؟';

  @override
  String get complaintSubmittedSuccessfully => 'شکایت با موفقیت ارسال شد';

  @override
  String get unexpectedError => 'خطای غیرمنتظره';

  @override
  String get complaintCategory => 'دسته‌بندی';

  @override
  String get pleaseSelectRating => 'لطفاً امتیاز را انتخاب کنید';

  @override
  String get feedbackSubmittedSuccessfully => 'بازخورد با موفقیت ارسال شد';

  @override
  String feedbackSubmissionFailed(Object error) {
    return 'ارسال ناموفق بود: $error';
  }

  @override
  String get sendFeedback => 'ارسال بازخورد';

  @override
  String get feedbackIntro => 'با بازخوردها، ایده‌ها و پیشنهادهای خود به بهبود PetSupo کمک کنید.';

  @override
  String get rateYourExperience => 'تجربه خود را امتیاز دهید';

  @override
  String get feedbackCategory => 'دسته‌بندی بازخورد';

  @override
  String get generalFeedback => 'بازخورد عمومی';

  @override
  String get bugReport => 'گزارش خطا';

  @override
  String get featureRequest => 'درخواست قابلیت';

  @override
  String get yourMessage => 'پیام شما';

  @override
  String get submitFeedback => 'ارسال بازخورد';

  @override
  String get memorialImageLoadFailed => 'بارگذاری این تصویر ممکن نبود. لطفاً عکس دیگری امتحان کنید.';

  @override
  String get createMemorial => 'ایجاد یادبود';

  @override
  String get memorialTitle => 'عنوان یادبود';

  @override
  String get storyMessage => 'داستان / پیام';

  @override
  String get city => 'شهر';

  @override
  String get country => 'کشور';

  @override
  String get memorialHeaderMessage => 'با کاشتن خاطره‌ای در طبیعت، حیوان عزیزتان را گرامی بدارید.';

  @override
  String get addPetBeforeMemorial => 'پیش از ایجاد یادبود، یک حیوان اضافه کنید.';

  @override
  String get addPetFirst => 'ابتدا حیوان اضافه کنید';

  @override
  String get choosePhoto => 'انتخاب عکس';

  @override
  String get memorialPhotoPreviewMessage => 'بارگذاری عکس بعداً متصل می‌شود. پیش‌نمایش فعلاً محلی است.';

  @override
  String get memorialCreated => 'یادبود ایجاد شد.';

  @override
  String get greenMemorial => 'یادبود سبز';

  @override
  String get greenMemorialIntro => 'به یاد حیوان عزیزتان درختی بکارید.';

  @override
  String memorialInMemoryOf(Object petName) {
    return 'به یاد $petName 🌱';
  }

  @override
  String memorialByOwner(Object ownerName) {
    return 'توسط $ownerName';
  }

  @override
  String get favoriteProductsTitle => 'محصولات مورد علاقه';

  @override
  String get productNotFound => 'محصول پیدا نشد';

  @override
  String get sellerRatingLabel => 'امتیاز فروشنده';

  @override
  String get aboutSellerTitle => 'درباره فروشنده';

  @override
  String get newestFirst => 'جدیدترین‌ها اول';

  @override
  String sellerProductsLoadError(Object error) {
    return 'خطا در بارگذاری محصولات فروشنده: $error';
  }

  @override
  String get sellerNoActiveProducts => 'این فروشنده محصول فعال ندارد';

  @override
  String get sellerInitials => 'KP';

  @override
  String get passwordUpdatedSuccessfully => 'رمز عبور با موفقیت به‌روزرسانی شد';

  @override
  String get passwordStrengthLabel => 'قدرت رمز عبور:';

  @override
  String get changePasswordTitle => 'تغییر رمز عبور';

  @override
  String get changePasswordDescription => 'با به‌روزرسانی منظم رمز عبور، حساب PetSupo خود را ایمن نگه دارید.';

  @override
  String get currentPasswordLabel => 'رمز عبور فعلی';

  @override
  String get enterCurrentPassword => 'رمز عبور فعلی را وارد کنید';

  @override
  String get newPasswordLabel => 'رمز عبور جدید';

  @override
  String get enterNewPassword => 'رمز عبور جدید را وارد کنید';

  @override
  String get enterConfirmPassword => 'رمز عبور جدید را تأیید کنید';

  @override
  String get updatePasswordLabel => 'به‌روزرسانی رمز عبور';

  @override
  String get savedParksTitle => 'پارک‌های ذخیره‌شده';

  @override
  String get noSavedParksYet => 'هنوز پارکی ذخیره نشده است';

  @override
  String get adoptionFirstAnimal => 'اولین حیوان خود را اضافه کنید';

  @override
  String get completedAdoptionsEmpty => 'فرآیندهای واگذاری تکمیل‌شده اینجا نمایش داده می‌شوند.';

  @override
  String get recentlyAddedAnimals => 'حیوانات تازه اضافه‌شده';

  @override
  String get noAnimalsAdded => 'هنوز حیوانی اضافه نشده است.';

  @override
  String get speciesStatisticsEmpty => 'آمار گونه‌ها پس از اولین واگذاری موفق نمایش داده می‌شود.';

  @override
  String get petTaxiEstimateDisclaimer => 'این برآورد بر اساس تعرفه تاکسی استانبول و هزینه خدمات حمل حیوان خانگی است. هزینه‌های پل، بزرگراه، انتظار و هزینه‌های اختصاصی ارائه‌دهنده ممکن است اضافه شوند. قیمت نهایی توسط ارائه‌دهنده تأیید می‌شود.';

  @override
  String get unblockUserTitle => 'رفع انسداد کاربر';

  @override
  String unblockConfirmation(Object name) {
    return 'آیا مطمئن هستید که می‌خواهید انسداد $name را بردارید؟';
  }

  @override
  String unblockSuccess(Object name) {
    return 'انسداد $name برداشته شد';
  }

  @override
  String get unblockFailed => 'رفع انسداد کاربر ناموفق بود';

  @override
  String get blockedUsersTitle => 'کاربران مسدودشده';

  @override
  String get mustBeSignedIn => 'باید وارد حساب خود شوید';

  @override
  String blockedUserCount(Object count) {
    return '$count کاربر مسدودشده';
  }

  @override
  String blockedUsersCount(Object count) {
    return '$count کاربر مسدودشده';
  }

  @override
  String get blockedUsersDescription => 'کاربرانی را که از تعامل با شما منع کرده‌اید مدیریت کنید.';

  @override
  String get noBlockedUsers => 'کاربر مسدودشده‌ای وجود ندارد';

  @override
  String get blockedUsersEmptyDescription => 'کاربرانی که مسدود می‌کنید اینجا نمایش داده می‌شوند. هر زمان خواستید می‌توانید انسدادشان را بردارید.';

  @override
  String blockedOn(Object date) {
    return 'مسدودشده در $date';
  }

  @override
  String get unblockButton => 'رفع انسداد';

  @override
  String get deleteAccountFailed => 'حذف حساب ناموفق بود. لطفاً دوباره تلاش کنید.';

  @override
  String get deleteActionPermanent => 'این اقدام دائمی است.\n\nهمه سگ‌ها، گفتگوها، علاقه‌مندی‌ها و فعالیت‌های شما برای همیشه حذف خواهند شد.';

  @override
  String get deleteConfirmationCodeHint => 'برای تأیید DELETE را وارد کنید';

  @override
  String get deleteConfirmationCode => 'DELETE';

  @override
  String get deleteAccountPermanentNotice => 'این اقدام دائمی است و قابل بازگشت نیست.';

  @override
  String get whatWillBeDeleted => 'چه چیزهایی حذف می‌شوند';

  @override
  String get confirmation => 'تأیید';

  @override
  String get privacySettingsUpdated => 'تنظیمات حریم خصوصی به‌روزرسانی شد';

  @override
  String get privacySecurityTitle => 'حریم خصوصی و امنیت';

  @override
  String get privacySecurityDescription => 'نمایش‌پذیری، اشتراک‌گذاری داده و تنظیمات حریم خصوصی حساب خود را کنترل کنید.';

  @override
  String get dataExportRequestSubmitted => 'درخواست خروجی داده ارسال شد';

  @override
  String get deleteAccountDataNotice => 'این اقدام قابل بازگشت نیست و همه داده‌های شما برای همیشه حذف خواهند شد.';

  @override
  String get exitAppTitle => 'از برنامه خارج شوید؟';

  @override
  String get exitAppMessage => 'آیا می‌خواهید PetSupo را ببندید؟';

  @override
  String get exitButton => 'خروج';

  @override
  String get petSupoBrand => 'PetSupo';

  @override
  String get aboutUsTitle => 'درباره ما';

  @override
  String get aboutUsContent => 'PetSupo یک پلتفرم دیجیتال است که برای ارتباط صاحبان حیوانات خانگی و بهبود زندگی اجتماعی حیوانات طراحی شده است.\n\nاین برنامه به کاربران کمک می‌کند برای سگ‌های خود هم‌بازی مناسب پیدا کنند، خدمات دامپزشکی نزدیک را بیابند و به کسب‌وکارهای حیوانات خانگی مانند فروشگاه، آرایشگاه و هتل حیوانات دسترسی داشته باشند.\n\nPetSupo ارائه‌دهنده خدمات نیست، بلکه میان کاربران و خدمات شخص ثالث نقش تسهیل‌گر دارد. کاربران مسئول تعاملات و تصمیم‌های خود در این پلتفرم هستند.\n\nمأموریت ما فراهم کردن محیطی امن، کارآمد و کاربرپسند برای صاحبان حیوانات در سراسر جهان است.';

  @override
  String get faqDescription => 'پاسخ‌های سریع درباره ویژگی‌های PetSupo، حریم خصوصی، اشتراک‌ها و ایمنی پیدا کنید.';

  @override
  String get reportTitleRequired => 'لطفاً عنوانی وارد کنید';

  @override
  String get reportSubmittedSuccessfully => 'گزارش با موفقیت ارسال شد';

  @override
  String reportSendFailed(Object error) {
    return 'ارسال گزارش ناموفق بود: $error';
  }

  @override
  String get attachScreenshot => 'افزودن تصویر صفحه';

  @override
  String get screenshotOptionalHint => 'اختیاری است، اما به ما کمک می‌کند مشکل را سریع‌تر درک کنیم.';

  @override
  String get reportProblemTitle => 'گزارش مشکل';

  @override
  String get reportProblemDescription => 'بگویید چه چیزی اشتباه پیش رفت. گزارش شما به بهبود PetSupo کمک می‌کند.';

  @override
  String get reportIncorrectInformation => 'اطلاعات نادرست';

  @override
  String get reportPaymentIssue => 'مشکل پرداخت';

  @override
  String get submitReport => 'ارسال گزارش';

  @override
  String vetProfileLoadError(Object error) {
    return 'خطای بارگذاری: $error';
  }

  @override
  String get vetProfileUpdatedSuccessfully => 'پروفایل دامپزشک با موفقیت به‌روزرسانی شد';

  @override
  String vetProfileSaveError(Object error) {
    return 'خطای ذخیره: $error';
  }

  @override
  String get editVetProfileTitle => 'ویرایش پروفایل دامپزشک';

  @override
  String get suggestClinicTitle => 'به رشد PetSupo کمک کنید';

  @override
  String suggestClinicDescription(Object vetName) {
    return 'از $vetName دعوت کنید به PetSupo بپیوندد تا صاحبان حیوانات راحت‌تر وقت ملاقات رزرو کنند.';
  }

  @override
  String get shareInvitation => 'اشتراک‌گذاری دعوت‌نامه';

  @override
  String get maybeLater => 'شاید بعداً';

  @override
  String get vaccineDetailsTitle => 'جزئیات واکسن';

  @override
  String get clinicCouldNotBeLoaded => 'بارگذاری کلینیک ممکن نبود';

  @override
  String get relatedRecords => 'سوابق مرتبط';

  @override
  String get selectAnOption => 'یک گزینه انتخاب کنید';

  @override
  String get enterDetails => 'جزئیات را وارد کنید';

  @override
  String get futureDateRequired => 'لطفاً تاریخ و زمان آینده‌ای انتخاب کنید.';

  @override
  String get preVisitQuestionsRequired => 'لطفاً به پرسش‌های الزامی پیش از ویزیت پاسخ دهید.';

  @override
  String get noDetailedServicesProvided => 'خدمات دقیق ارائه نشده است.';

  @override
  String get noDogsYetMatching => 'هنوز سگی وجود ندارد — سگ خود را اضافه کنید و همسان‌یابی را شروع کنید! 🐾';

  @override
  String get createProfileToConnect => 'برای ارتباط، پروفایل بسازید 🐾';

  @override
  String unknownBusinessType(Object sectors) {
    return 'نوع کسب‌وکار ناشناخته → $sectors';
  }

  @override
  String get persianLanguage => 'فارسی';

  @override
  String get russianLanguage => 'Русский';

  @override
  String phoneAuthDebugError(Object code, Object details, Object message) {
    return 'کد: $code\n\nپیام:\n$message\n\n$details';
  }

  @override
  String get phoneVerificationFailed => 'تأیید تلفن تکمیل نشد.';

  @override
  String get changeNumber => 'تغییر شماره';

  @override
  String get verifyPhoneTitle => 'تأیید تلفن';

  @override
  String enterCodeSentTo(Object phone) {
    return 'کد ارسال‌شده به این شماره را وارد کنید\n$phone';
  }

  @override
  String get codeLabel => 'کد';

  @override
  String get newCodeSent => 'کد جدید ارسال شد';

  @override
  String get resendCode => 'ارسال مجدد کد';

  @override
  String get searchVeterinaryClinics => 'جستجوی کلینیک‌های دامپزشکی...';

  @override
  String get howWouldYouLikeToStart => 'چطور می‌خواهید شروع کنید؟';

  @override
  String get welcomeToPetSopuWithWave => 'به PetSupo خوش آمدید 👋';

  @override
  String get moreThanAnApp => 'بیش از یک برنامه.\nخانه‌ای برای حیوانات و صاحبانشان.';

  @override
  String get viewPremiumPlans => 'مشاهده طرح‌های پریمیوم';

  @override
  String get promotionPerformanceTitle => 'عملکرد تبلیغ';

  @override
  String get promotionCampaignStatus => 'وضعیت کمپین';

  @override
  String get promotionCampaignActive => 'فعال';

  @override
  String get promotionCampaignExpired => 'منقضی‌شده';

  @override
  String get promotionCampaignProcessing => 'در حال پردازش';

  @override
  String get promotionCampaignNeedsReconciliation => 'نیازمند تطبیق';

  @override
  String get promotionSpend => 'هزینه';

  @override
  String get promotionImpressions => 'نمایش‌ها';

  @override
  String get promotionClicks => 'کلیک‌ها';

  @override
  String get promotionCtr => 'نرخ کلیک';

  @override
  String get promotionDetailViews => 'مشاهده جزئیات';

  @override
  String get promotionFinancialConversions => 'تبدیل‌های مالی';

  @override
  String get promotionNetRevenue => 'درآمد خالص منتسب';

  @override
  String get promotionRoas => 'بازده هزینه تبلیغ';

  @override
  String get promotionStarts => 'شروع';

  @override
  String get promotionEnds => 'پایان';

  @override
  String promotionDurationHours(Object hours) {
    return '$hours ساعت';
  }

  @override
  String get promotionFinancialSection => 'عملکرد مالی';

  @override
  String get promotionFinancialAvailable => 'معیارهای مالی به‌روز هستند.';

  @override
  String get promotionFinancialProvisional => 'معیارهای مالی هنوز در حال تطبیق هستند.';

  @override
  String get promotionFinancialUnavailable => 'معیارهای مالی در دسترس نیستند یا کاربرد ندارند.';

  @override
  String get promotionPetFinancialNotApplicable => 'معیارهای مالی برای تبلیغ حیوان خانگی کاربرد ندارند.';

  @override
  String get promotionNoPerformanceData => 'تبلیغ شما فعال است. با مشاهده و تعامل کاربران، داده‌های عملکرد اینجا نمایش داده می‌شود.';

  @override
  String get promotionRetry => 'تلاش دوباره';

  @override
  String get promotionLoadError => 'عملکرد بارگذاری نشد.';

  @override
  String get promotionUpToDate => 'به‌روز';

  @override
  String get promotionReconciliationStatus => 'تطبیق';

  @override
  String get promotionNa => 'قابل اعمال نیست';

  @override
  String get promotionTargetPet => 'حیوان خانگی';

  @override
  String get promotionTargetProduct => 'محصول';

  @override
  String get promotionTargetVetService => 'خدمات دامپزشکی';

  @override
  String get promotionTargetGroomyService => 'خدمات گرومینگ';

  @override
  String get petTaxiDocumentTaxPlate => 'مالیات و ثبت کسب‌وکار';

  @override
  String get petTaxiDocumentBusinessRegistration => 'ثبت کسب‌وکار';

  @override
  String get petTaxiDocumentVehicleRegistration => 'مدرک ثبت خودرو';

  @override
  String get petTaxiDocumentDriverLicense => 'گواهینامه رانندگی';

  @override
  String get petTaxiDocumentTrafficInsurance => 'بیمه شخص ثالث';

  @override
  String get petTaxiDocumentStatusPendingReview => 'در انتظار بررسی';

  @override
  String get petTaxiDocumentStatusApproved => 'تأییدشده';

  @override
  String get petTaxiDocumentStatusRejected => 'ردشده';

  @override
  String get petTaxiDocumentStatusMissing => 'ناقص';

  @override
  String get petTaxiDocumentExpired => 'منقضی‌شده';

  @override
  String petTaxiDocumentExpiryDate(Object date) {
    return 'تاریخ انقضا: $date';
  }

  @override
  String get petTaxiDocumentExpiredMessage => 'اعتبار این مدرک منقضی شده است. مدرک را رد کنید و از کسب‌وکار بخواهید نسخه معتبر جدیدی بارگذاری کند.';

  @override
  String petTaxiRejectDocumentTitle(Object document) {
    return 'رد مدرک $document';
  }

  @override
  String get petTaxiAdminErrorPermissionDenied => 'شما اجازه انجام این کار را ندارید.';

  @override
  String get petTaxiAdminErrorUnauthenticated => 'جلسه شما منقضی شده است. لطفاً دوباره وارد شوید.';

  @override
  String get petTaxiAdminErrorNotFound => 'کسب‌وکار یا مدرک پیدا نشد.';

  @override
  String get petTaxiAdminErrorInvalidArgument => 'جزئیات مدرک را بررسی و دوباره تلاش کنید.';

  @override
  String get petTaxiAdminErrorAlreadyExists => 'این کار قبلاً انجام شده است.';

  @override
  String get petTaxiAdminErrorFailedPrecondition => 'این کار در وضعیت فعلی مدرک قابل انجام نیست.';

  @override
  String get petTaxiAdminErrorGeneric => 'عملیات انجام نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get petTaxiAdminActionCompleted => 'مدرک به‌روزرسانی شد';

  @override
  String get petTaxiUploadDocument => 'بارگذاری مدرک';

  @override
  String get petTaxiTakePhoto => 'گرفتن عکس';

  @override
  String get petTaxiChoosePhoto => 'انتخاب عکس';

  @override
  String get petTaxiChoosePdf => 'انتخاب PDF';

  @override
  String get petTaxiSupportedDocumentFormats => 'PDF، JPG یا PNG (حداکثر ۲۵ مگابایت)';

  @override
  String get petTaxiUnsupportedDocumentFormat => 'یک مدرک با فرمت PDF، JPG یا PNG انتخاب کنید.';

  @override
  String get petTaxiDocumentTooLarge => 'حجم این مدرک بیشتر از ۲۵ مگابایت است.';

  @override
  String get petTaxiDocumentUploadFailed => 'بارگذاری مدرک انجام نشد. دوباره تلاش کنید.';

  @override
  String get petTaxiOpenDocumentFailed => 'این مدرک باز نشد.';

  @override
  String get businessRegisterOptional => 'اختیاری';

  @override
  String get businessRegisterTaxPlateRequired => 'بارگذاری گواهی مالیاتی الزامی است.';

  @override
  String get businessRegisterMersisNumberRequired => 'شماره مرسیس الزامی است.';

  @override
  String get businessRegisterPhoneOptional => 'تلفن (اختیاری)';

  @override
  String get businessRegisterWhatsApp => 'واتساپ';

  @override
  String get businessRegisterDetectLocationTitle => 'مکان کسب‌وکار خود را پیدا کنید';

  @override
  String get businessRegisterDetectLocationMessage => 'برای تشخیص شهر و منطقه شما از موقعیت مکانی استفاده می‌کنیم.';

  @override
  String get petTaxiDocumentPermissionDenied => 'دسترسی دوربین یا عکس رد شد. می‌توانید به‌جای آن عکس یا PDF انتخاب کنید.';

  @override
  String get petTaxiRequiredDocuments => 'مدارک الزامی';

  @override
  String get petTaxiRequiredDocumentsSubtitle => 'مدارک لازم برای بررسی دستی مدیر';

  @override
  String get petTaxiOptionalDocuments => 'مدارک اختیاری / مشروط';

  @override
  String get petTaxiOptionalDocumentsSubtitle => 'اگر برای خدمات شما کاربرد دارد، آن را بارگذاری کنید';

  @override
  String get petTaxiComplianceTitle => 'تأییدیه‌های قانونی و انطباق';

  @override
  String get petTaxiComplianceSubtitle => 'تأییدیه‌های لازم پیش از ارسال';

  @override
  String get petTaxiPetSafetyEquipmentConfirmation => 'تأیید می‌کنم تجهیزات ایمنی حیوان در خودرو موجود است.';

  @override
  String get petTaxiHygieneConfirmation => 'تأیید می‌کنم الزامات بهداشت رعایت شده است.';

  @override
  String get petTaxiDriverLicenseConfirmation => 'تأیید می‌کنم گواهینامه راننده معتبر است.';

  @override
  String get petTaxiVehicleRegistrationConfirmation => 'تأیید می‌کنم سند خودرو متعلق به خودروی خدمات است.';

  @override
  String get petTaxiTrafficInsuranceConfirmation => 'تأیید می‌کنم بیمه شخص ثالث فعال است.';

  @override
  String get petTaxiTaxResponsibilityConfirmation => 'تأیید می‌کنم مسئولیت مالیات و فاکتور یا رسید بر عهده کسب‌وکار من است.';

  @override
  String get petTaxiTransportRulesConfirmation => 'تأیید می‌کنم قوانین حمل‌ونقل شهر و کشور را رعایت می‌کنم.';

  @override
  String get petTaxiComplianceNotes => 'یادداشت‌های انطباق برای بررسی مدیر';

  @override
  String get petTaxiOptionalIfApplicable => 'اختیاری / در صورت کاربرد';

  @override
  String petTaxiDocumentRequired(Object document) {
    return '$document الزامی است';
  }

  @override
  String petTaxiDateRequired(Object date) {
    return '$date الزامی است';
  }

  @override
  String petTaxiDateCannotBePast(Object date) {
    return '$date نمی‌تواند در گذشته باشد';
  }

  @override
  String get petTaxiDocumentNumber => 'شماره مدرک';

  @override
  String get petTaxiDocumentNumberOptional => 'شماره مدرک (اختیاری)';

  @override
  String get petTaxiDocumentNumberRequired => 'شماره مدرک الزامی است';

  @override
  String get petTaxiVehicleRegistrationIssueDate => 'تاریخ صدور سند خودرو';

  @override
  String get petTaxiDriverLicenseExpiryDate => 'تاریخ انقضای گواهینامه راننده';

  @override
  String get petTaxiTrafficInsuranceExpiryDate => 'تاریخ انقضای بیمه شخص ثالث';

  @override
  String get petTaxiSrcCertificateExpiryDate => 'تاریخ انقضای گواهی SRC';

  @override
  String get petTaxiPsychotechnicalExpiryDate => 'تاریخ انقضای گزارش روان‌فنی';

  @override
  String get petTaxiKaskoExpiryDate => 'تاریخ انقضای بیمه بدنه';

  @override
  String get petTaxiValidTurkishPlate => 'یک پلاک معتبر ترکی وارد کنید.';

  @override
  String get petTaxiRequiredDocumentsMissing => 'مدارک الزامی پت‌تاکسی را بارگذاری کنید.';

  @override
  String get petTaxiComplianceConfirmationsMissing => 'همه تأییدیه‌های الزامی انطباق را انتخاب کنید.';

  @override
  String get petTaxiValidPhoneNumber => 'یک شماره تلفن معتبر وارد کنید.';

  @override
  String get petTaxiValidCapacity => 'ظرفیت معتبر خودرو را وارد کنید.';

  @override
  String get petTaxiCapacityMinimum => 'ظرفیت خودرو باید حداقل ۱ باشد.';

  @override
  String get petTaxiCapacityMaximum => 'ظرفیت خودرو نمی‌تواند بیشتر از ۱۵ باشد.';

  @override
  String get petTaxiSelectVehicleType => 'نوع خودرو را انتخاب کنید.';

  @override
  String get petTaxiDriverFullName => 'نام و نام خانوادگی راننده';

  @override
  String get petTaxiDriverPhoneNumber => 'شماره تلفن راننده';

  @override
  String get petTaxiVehiclePlateNumber => 'شماره پلاک خودرو';

  @override
  String get petTaxiVehicleCapacity => 'ظرفیت خودرو';

  @override
  String get petTaxiVehicleSedan => 'سدان';

  @override
  String get petTaxiVehicleHatchback => 'هاچ‌بک';

  @override
  String get petTaxiVehicleSuv => 'SUV';

  @override
  String get petTaxiVehicleVan => 'ون';

  @override
  String get petTaxiVehiclePetTransportVan => 'ون حمل حیوانات خانگی';

  @override
  String get petTaxiVehicleLargeAnimalTransport => 'خودروی حمل حیوانات بزرگ';

  @override
  String get adPrivacyOptionsTitle => 'گزینه‌های حریم خصوصی';

  @override
  String get adPrivacyOptionsSubtitle => 'رضایت تبلیغات و انتخاب‌های حریم خصوصی را مدیریت کنید.';

  @override
  String get marketplaceSellerActivationRequired => 'فروش در بازار برای این کسب‌وکار هنوز فعال نشده است. لطفاً با یک مدیر تماس بگیرید.';

  @override
  String get marketplaceSellerActivationSectionTitle => 'فعال‌سازی فروشنده بازار';

  @override
  String get marketplaceSellerActivationStatusActive => 'فعال — این کسب‌وکار می‌تواند در بازار بفروشد';

  @override
  String get marketplaceSellerActivationStatusInactive => 'غیرفعال — این کسب‌وکار نمی‌تواند در بازار بفروشد';

  @override
  String get marketplaceSellerActivationGrantAction => 'اعطای دسترسی';

  @override
  String get marketplaceSellerActivationRevokeAction => 'لغو دسترسی';

  @override
  String get marketplaceSellerActivationGrantConfirmTitle => 'دسترسی بازار اعطا شود؟';

  @override
  String get marketplaceSellerActivationGrantConfirmMessage => 'این کار به کسب‌وکار اجازه می‌دهد محصولات بازار را ایجاد و ویرایش کند. هیچ محصولی را تأیید نمی‌کند، مدارک را بررسی نمی‌کند و انطباق قانونی را تأیید نمی‌کند.';

  @override
  String get marketplaceSellerActivationRevokeConfirmTitle => 'دسترسی بازار لغو شود؟';

  @override
  String get marketplaceSellerActivationRevokeConfirmMessage => 'این کار کسب‌وکار را از ایجاد یا ویرایش محصولات بازار باز می‌دارد. محصولات موجود با این عمل حذف یا پنهان نمی‌شوند.';

  @override
  String get marketplaceSellerActivationGrantSucceeded => 'دسترسی بازار اعطا شد.';

  @override
  String get marketplaceSellerActivationRevokeSucceeded => 'دسترسی بازار لغو شد.';

  @override
  String get marketplaceSellerActivationPermissionDenied => 'شما اجازه انجام این کار را ندارید.';

  @override
  String get marketplaceSellerActivationBusinessNotFound => 'کسب‌وکار یافت نشد.';

  @override
  String get marketplaceSellerActivationNetworkError => 'خطای شبکه. لطفاً دوباره تلاش کنید.';

  @override
  String get marketplaceSellerActivationGeneralError => 'مشکلی پیش آمد. لطفاً دوباره تلاش کنید.';

  @override
  String get pilotUnpublishForRevisionTitle => 'لغو انتشار برای بازنگری؟';

  @override
  String get pilotUnpublishForRevisionMessage => 'ویرایش این محصول انتشار آن را لغو می‌کند. تا زمانی که یک ادمین دوباره بررسی و تایید نکند، برای مشتریان قابل مشاهده نخواهد بود.';

  @override
  String get pilotUnpublishForRevisionConfirm => 'لغو و ویرایش';

  @override
  String get pilotStatusPendingReview => 'در انتظار بررسی';

  @override
  String get pilotStatusApproved => 'تایید‌شده (آزمایشی)';

  @override
  String get pilotStatusRevoked => 'لغو‌شده — نیاز به تایید مجدد';

  @override
  String get adminHubPilotProductApprovalsTitle => 'تاییدات محصول آزمایشی';

  @override
  String get adminHubPilotProductApprovalsSubtitle => 'بررسی و تایید فهرست‌های آزمایشی';

  @override
  String get pilotAdminListTitle => 'تاییدات محصول آزمایشی';

  @override
  String get pilotAdminListEmpty => 'هیچ محصولی در انتظار بررسی آزمایشی نیست';

  @override
  String get pilotAdminDetailTitle => 'بررسی محصول آزمایشی';

  @override
  String get pilotAdminCategoryLabel => 'دسته‌بندی آزمایشی';

  @override
  String get pilotAdminCategoryFood => 'غذا';

  @override
  String get pilotAdminCategoryTreats => 'تشویقی';

  @override
  String get pilotAdminCategoryLitter => 'خاک بهداشت';

  @override
  String get pilotAdminCategoryToys => 'اسباب‌بازی';

  @override
  String get pilotAdminCategoryCollarsLeads => 'قلاده و بند';

  @override
  String get pilotAdminCategoryBeds => 'تخت‌خواب';

  @override
  String get pilotAdminCategoryBowls => 'ظرف';

  @override
  String get pilotAdminCategoryGroomingTools => 'ابزار آرایش';

  @override
  String get pilotAdminAttestationLabel => 'تایید می‌کنم که این فهرست فاقد هرگونه ادعای ممنوع سلامتی، پزشکی یا درمانی است.';

  @override
  String get pilotAdminApproveButton => 'تایید';

  @override
  String get pilotAdminRevokeButton => 'لغو';

  @override
  String get pilotAdminApproveConfirmTitle => 'این محصول تایید شود؟';

  @override
  String get pilotAdminApproveConfirmMessage => 'این محصول فوراً برای مشتریان قابل مشاهده خواهد شد.';

  @override
  String get pilotAdminRevokeConfirmTitle => 'تایید لغو شود؟';

  @override
  String get pilotAdminRevokeConfirmMessage => 'این محصول فوراً از دید مشتریان پنهان خواهد شد.';

  @override
  String get pilotAdminStaleContentWarning => 'این محصول از زمان آخرین بررسی تغییر کرده است. پیش از تایید، به‌روزرسانی کنید.';

  @override
  String get pilotAdminOperationalClassificationNote => 'این تایید فقط یک دسته‌بندی عملیاتی آزمایشی است. این یک تایید قانونی، نظارتی یا انطباقی نیست.';

  @override
  String get pilotAdminErrorGeneric => 'مشکلی پیش آمد. لطفاً دوباره تلاش کنید.';

  @override
  String get pilotAdminErrorNotFound => 'این محصول یا کسب‌وکار یافت نشد.';

  @override
  String get pilotAdminErrorLimitExceeded => 'این فروشنده به حداکثر تعداد محصولات آزمایشی فعال رسیده است.';

  @override
  String get pilotAdminErrorStaleContent => 'محتوای محصول تغییر کرده است. لطفاً به‌روزرسانی کنید و دوباره تلاش کنید.';

  @override
  String get pilotAdminErrorStaleGeneration => 'رکورد کسب‌وکار این محصول تغییر کرده است. لطفاً به‌روزرسانی کنید و دوباره تلاش کنید.';

  @override
  String get pilotAdminErrorSellerNotActive => 'فعال‌سازی آزمایشی این فروشنده در حال حاضر فعال نیست.';

  @override
  String get pilotAdminRevokeReasonManual => 'تصمیم ادمین';

  @override
  String get pilotAdminRevokeReasonContentChanged => 'محتوا تغییر کرده است';

  @override
  String get petShopBrandsOptionalLabel => 'برندها (اختیاری)';

  @override
  String get petShopWorkingHoursLabel => 'ساعات کاری';

  @override
  String get petShopWorkingHoursHint => 'نمونه: ۱۰:۰۰–۲۱:۰۰';

  @override
  String get petShopWorkingHoursInvalidFormat => 'از قالب 10:00–21:00 استفاده کنید (۲۴ ساعته، جدا شده با خط تیره).';

  @override
  String get petShopWorkingHoursInvalidRange => 'ساعت پایان باید بعد از ساعت شروع باشد.';

  @override
  String get scheduleNavItem => 'برنامه';

  @override
  String get drawerSectionMain => 'منوی اصلی';

  @override
  String get drawerSectionSupport => 'پشتیبانی';

  @override
  String get drawerSectionLegal => 'قوانین';

  @override
  String get faqMenuItem => 'سوالات متداول';

  @override
  String get businessMediaTitle => 'رسانه کسب‌وکار';

  @override
  String get businessMediaDescription => 'لوگو، تصویر جلد و عکس‌های گالری اضافه کنید. همه اختیاری هستند.';

  @override
  String get businessMediaLogo => 'لوگو';

  @override
  String get businessMediaCover => 'تصویر جلد';

  @override
  String get businessMediaGallery => 'گالری';

  @override
  String get businessMediaOptional => 'اختیاری';

  @override
  String get businessMediaAddLogo => 'افزودن لوگو';

  @override
  String get businessMediaChangeLogo => 'تغییر لوگو';

  @override
  String get businessMediaRemoveLogo => 'حذف لوگو';

  @override
  String get businessMediaAddCover => 'افزودن جلد';

  @override
  String get businessMediaChangeCover => 'تغییر جلد';

  @override
  String get businessMediaRemoveCover => 'حذف جلد';

  @override
  String get businessMediaAddPhotos => 'افزودن عکس';

  @override
  String get businessMediaRemovePhoto => 'حذف عکس';

  @override
  String get businessMediaNoLogo => 'هنوز لوگویی نیست';

  @override
  String get businessMediaNoCover => 'هنوز تصویر جلدی نیست';

  @override
  String get businessMediaNoPhotos => 'هنوز عکسی در گالری نیست';

  @override
  String get businessMediaUploading => 'در حال بارگذاری…';

  @override
  String get businessMediaRetry => 'تلاش دوباره';

  @override
  String get businessMediaSaved => 'ذخیره شد';

  @override
  String get businessMediaGalleryFull => 'گالری شما پر است. برای افزودن عکس جدید، یکی را حذف کنید.';

  @override
  String get businessMediaRemoveConfirmTitle => 'این تصویر حذف شود؟';

  @override
  String get businessMediaRemoveConfirmBody => 'دیگر در نمایه عمومی شما نمایش داده نمی‌شود.';

  @override
  String get businessMediaRemoveConfirmAction => 'حذف';

  @override
  String get businessMediaCancel => 'انصراف';

  @override
  String get businessMediaErrorUpload => 'بارگذاری ناموفق بود. لطفاً دوباره تلاش کنید.';

  @override
  String get businessMediaErrorFormat => 'این قالب تصویر پشتیبانی نمی‌شود.';

  @override
  String get businessMediaErrorTooLarge => 'این تصویر بیش از حد بزرگ است.';

  @override
  String get businessMediaErrorNotOwner => 'شما مدیر این کسب‌وکار نیستید.';

  @override
  String get businessMediaErrorStale => 'این مورد جای دیگری به‌روزرسانی شد. صفحه را تازه کنید و دوباره تلاش کنید.';

  @override
  String get businessMediaErrorSignedOut => 'لطفاً دوباره وارد شوید.';

  @override
  String get businessMediaErrorGeneric => 'مشکلی پیش آمد. لطفاً دوباره تلاش کنید.';

  @override
  String get businessMediaImageUnavailable => 'تصویر در دسترس نیست';

  @override
  String businessMediaGalleryCount(int current, int max) {
    return '$current از $max عکس';
  }

  @override
  String get marketplaceDisabledError => 'ثبت محصول در بازارگاه هنوز باز نیست. لطفاً بعداً دوباره تلاش کنید.';

  @override
  String get invalidSellerRelationshipError => 'برای این محصول یک نسبت فروشنده معتبر انتخاب کنید.';

  @override
  String get invalidProductDataError => 'برخی از اطلاعات محصول نامعتبر است. لطفاً فرم را بررسی کنید.';

  @override
  String get mediaUploadFailedError => 'رسانه محصول بارگذاری نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get productSubmissionFailedError => 'محصول ثبت نشد. لطفاً دوباره تلاش کنید.';

  @override
  String get networkErrorTryAgain => 'خطای شبکه. لطفاً دوباره تلاش کنید.';
}
