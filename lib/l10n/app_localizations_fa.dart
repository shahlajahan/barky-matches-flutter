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
  String adoptionRequestSent(Object dogName) {
    return 'درخواست پذیرش برای $dogName ارسال شد!';
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
  String get username => 'نام کاربری';

  @override
  String get email => 'ایمیل';

  @override
  String get phoneNumber => 'شماره تلفن';

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
  String get welcomeToBarkyMatches => 'به بارکی مچز خوش آمدید!';

  @override
  String get welcomeTo => 'خوش آمدید به';

  @override
  String get barkyMatches => 'بارکی مچز!';

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
  String get emailLabel => 'ایمیل';

  @override
  String get usernameLabel => 'نام کاربری';

  @override
  String get phoneLabel => 'شماره تلفن';

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
  String get phoneMinDigits => 'شماره تلفن باید حداقل ۱۰ رقم باشد';

  @override
  String get passwordRequired => 'لطفاً رمز عبور خود را وارد کنید';

  @override
  String get passwordValidation => 'رمز عبور باید حداقل ۸ کاراکتر باشد و شامل حروف و اعداد باشد';

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
  String get noAccountSignUp => 'حساب ندارید؟ ثبت‌نام کنید';

  @override
  String get haveAccountSignIn => 'قبلاً حساب دارید؟ وارد شوید';

  @override
  String get userNotFound => 'کاربری با این ایمیل یافت نشد. لطفاً ثبت‌نام کنید.';

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
  String verificationCodeSent(Object email) {
    return 'کد تأیید به $email ارسال شد';
  }

  @override
  String get enterCodeLabel => 'کد ۶ رقمی را وارد کنید';

  @override
  String get verifyButton => 'تأیید';

  @override
  String get signInToAccessPlaymate => 'لطفاً برای دسترسی به پلی‌میت وارد شوید';

  @override
  String get signInToFindFriends => 'لطفاً برای یافتن دوستان وارد شوید';

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
  String get save => 'ذخیره';

  @override
  String dogNameExists(Object name) {
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
  String get pleaseFillRequiredFields => 'لطفاً تمام فیلدهای الزامی را به درستی پر کنید';

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
  String dogDetailsNameExistsError(Object name) {
    return 'سگی با نام $name قبلاً وجود دارد!';
  }

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
  String get moreFiltersButton => 'فیلترهای بیشتر';

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
  String playdateRequestMessage(Object requesterDog, Object requestedDog) {
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
  String get newPlaydateRequest => 'درخواست قرار بازی جدید!';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
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
  String get newPlayDateRequestTitle => 'درخواست قرار بازی جدید!';

  @override
  String newPlayDateRequestBody(Object dogName) {
    return 'شما یک درخواست قرار بازی جدید از $dogName دارید.';
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
}
