// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

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
  String get cartTitle => 'Моя корзина';

  @override
  String get cartIsEmpty => 'Корзина пуста';

  @override
  String get totalLabel => 'Итого';

  @override
  String get checkoutButton => 'Оформить заказ';

  @override
  String get checkoutStepAddressTitle => 'Адрес';

  @override
  String get checkoutStepPaymentTitle => 'Оплата';

  @override
  String get checkoutStepConfirmTitle => 'Подтверждение';

  @override
  String get checkoutDeliveryAddressTitle => 'Адрес доставки';

  @override
  String get checkoutFullNameLabel => 'Имя и фамилия';

  @override
  String get checkoutFullNameHint => 'Имя и фамилия';

  @override
  String get checkoutPhoneHint => '5XXXXXXXXX';

  @override
  String get checkoutCityLabel => 'Город';

  @override
  String get checkoutCityHint => 'Стамбул';

  @override
  String get checkoutDistrictLabel => 'Район';

  @override
  String get checkoutDistrictHint => 'Кадыкёй';

  @override
  String get checkoutAddressLabel => 'Полный адрес';

  @override
  String get checkoutAddressHint => 'Подробный адрес';

  @override
  String get checkoutInvoiceDetailsTitle => 'Данные для счета';

  @override
  String get checkoutIndividualOption => 'Частное лицо';

  @override
  String get checkoutCompanyOption => 'Компания';

  @override
  String get checkoutIdentityNumberLabel => 'Номер удостоверения';

  @override
  String get checkoutIdentityNumberHint => '11 цифр';

  @override
  String get checkoutCompanyNameLabel => 'Название компании';

  @override
  String get checkoutTaxNumberLabel => 'Налоговый номер';

  @override
  String get checkoutTaxNumberHint => '10 цифр';

  @override
  String get checkoutTaxOfficeLabel => 'Налоговая';

  @override
  String get checkoutCargoUpdatesTitle => 'Обновления счета и доставки';

  @override
  String get checkoutCargoUpdatesQuestion => 'Как нам отправлять обновления по счету и доставке?';

  @override
  String get checkoutSmsOption => 'SMS';

  @override
  String get checkoutEmailOption => 'Электронная почта';

  @override
  String get checkoutSmsEmailOption => 'SMS + электронная почта';

  @override
  String get checkoutAgreementsTitle => 'Соглашения';

  @override
  String get checkoutKvkkDisclosure => 'Я прочитал(а) уведомление KVKK';

  @override
  String get checkoutViewButton => 'Просмотреть';

  @override
  String get checkoutPreInfoForm => 'Я принимаю форму предварительной информации';

  @override
  String get checkoutDistanceSalesAgreement => 'Я принимаю договор дистанционной продажи';

  @override
  String get checkoutMarketingOptional => 'Получать маркетинговые сообщения (необязательно)';

  @override
  String get checkoutDeliveryTitle => 'Доставка';

  @override
  String get checkoutPaymentSummaryTitle => 'Сводка платежа';

  @override
  String get checkoutSubtotalLabel => 'Промежуточный итог';

  @override
  String get checkoutVatLabel => 'НДС';

  @override
  String get checkoutShippingLabel => 'Доставка';

  @override
  String get checkoutPleaseSelectCargoCompany => 'Пожалуйста, выберите транспортную компанию';

  @override
  String get checkoutEnterNameSurname => 'Введите имя и фамилию';

  @override
  String get checkoutEnterValidEmail => 'Введите действительный email';

  @override
  String get checkoutEnterValidPhone => 'Введите действительный телефон';

  @override
  String get checkoutEnterCity => 'Введите город';

  @override
  String get checkoutEnterDistrict => 'Введите район';

  @override
  String get checkoutEnterFullAddress => 'Введите полный адрес';

  @override
  String get checkoutEnterValidIdentityNumber => 'Введите действительный номер удостоверения';

  @override
  String get checkoutEnterCompanyName => 'Введите название компании';

  @override
  String get checkoutEnterValidTaxNumber => 'Введите действительный налоговый номер';

  @override
  String get checkoutEnterTaxOffice => 'Введите налоговую';

  @override
  String get checkoutAcceptRequiredAgreements => 'Примите обязательные соглашения';

  @override
  String get checkoutPaymentPageOpenedMessage => 'Страница оплаты открыта. Завершите оплату и вернитесь в приложение.';

  @override
  String get checkoutBackButton => 'Назад';

  @override
  String get checkoutProceedToPayment => 'Перейти к оплате';

  @override
  String get checkoutContinueButton => 'Продолжить';

  @override
  String get checkoutPaymentCompletedSuccessfully => 'Оплата успешно завершена';

  @override
  String get checkoutPaymentCancelledOrIncomplete => 'Оплата была отменена или не завершена';

  @override
  String checkoutFailed(Object error) {
    return 'Ошибка оформления заказа: $error';
  }

  @override
  String adoptionRequestSent(Object dogName) {
    return 'Заявка на усыновление для $dogName отправлена!';
  }

  @override
  String get adoptionCentersTitle => 'Центры усыновления';

  @override
  String get availableDogsTitle => 'Доступные собаки';

  @override
  String get noAdoptionCentersAvailable => 'Нет доступных центров усыновления';

  @override
  String get noDogsAvailableInThisCenter => 'В этом центре нет доступных собак';

  @override
  String get adoptionRequestTitle => 'Заявка на усыновление';

  @override
  String get yourPhone => 'Ваш телефон';

  @override
  String get whyDoYouWantToAdopt => 'Почему вы хотите усыновить?';

  @override
  String get appointmentTitle => 'Запись';

  @override
  String get cancelAppointmentButton => 'Отменить запись';

  @override
  String get cancelAppointmentTitle => 'Отменить запись?';

  @override
  String get cancelAppointmentConfirmation => 'Вы уверены, что хотите отменить эту запись?';

  @override
  String get keepAppointmentButton => 'Оставить запись';

  @override
  String get appointmentCancelled => 'Запись отменена';

  @override
  String get cancellationNotAllowed => 'Отмена для этой записи недоступна.';

  @override
  String get cancelAppointmentFailed => 'Не удалось отменить запись. Попробуйте еще раз.';

  @override
  String get selectService => 'Выберите услугу';

  @override
  String get selectPet => 'Выберите питомца';

  @override
  String get dateAndTime => 'Дата и время';

  @override
  String get notesOptional => 'Заметки (необязательно)';

  @override
  String get selectDate => 'Выберите дату';

  @override
  String get selectTime => 'Выберите время';

  @override
  String get appointmentNoteHint => 'Добавьте заметку для клиники...';

  @override
  String get requestAppointment => 'Запросить запись';

  @override
  String get requestSentTitle => 'Запрос отправлен 🐾';

  @override
  String get requestSentMessage => 'Ваш запрос на запись отправлен в клинику.';

  @override
  String get okButton => 'OK';

  @override
  String get somethingWentWrong => 'Что-то пошло не так';

  @override
  String get alreadyBookedAtThisTime => 'У вас уже есть запись на это время. Пожалуйста, выберите другое время.';

  @override
  String get invalidBookingData => 'Недействительные данные записи. Пожалуйста, попробуйте снова.';

  @override
  String get serviceDefaultLabel => 'Услуга';

  @override
  String get ageYearsSuffix => ' лет';

  @override
  String get overviewTitle => 'Обзор';

  @override
  String get servicesTitle => 'Услуги';

  @override
  String get reviewsTitle => 'Отзывы';

  @override
  String get galleryTitle => 'Галерея';

  @override
  String get shopTitle => 'Магазин';

  @override
  String get aboutTitle => 'О клинике';

  @override
  String get workingHoursTitle => 'Часы работы';

  @override
  String get locationTitle => 'Местоположение';

  @override
  String get instagramTitle => 'Instagram';

  @override
  String get noClinicDescriptionAvailable => 'Описание клиники недоступно.';

  @override
  String get instagramNotAvailable => 'Instagram недоступен.';

  @override
  String get workingHoursNotAvailable => 'Часы работы недоступны';

  @override
  String get openStatusOpen => 'Открыто';

  @override
  String get openStatusClosingSoon => 'Скоро закрывается';

  @override
  String get openStatusClosed => 'Закрыто';

  @override
  String get mostRelevant => 'Самые полезные';

  @override
  String get newest => 'Новые';

  @override
  String get bookAppointment => 'Записаться';

  @override
  String get noServicesAvailable => 'Услуги недоступны';

  @override
  String errorLoadingServices(Object error) {
    return 'Ошибка загрузки услуг: $error';
  }

  @override
  String get noServicesProvided => 'Услуги не указаны.';

  @override
  String reviewsCountLabel(Object count) {
    return '$count отзывов';
  }

  @override
  String get topLabel => 'Топ';

  @override
  String get mostHelpful => 'Самые полезные';

  @override
  String get couldNotUpdateLike => 'Не удалось обновить лайк';

  @override
  String get justNow => 'Только что';

  @override
  String get noReviewsYet => 'Пока нет отзывов';

  @override
  String get beFirstToReview => 'Будьте первым, кто оставит отзыв';

  @override
  String get submit => 'Отправить';

  @override
  String get writeAReview => 'Написать отзыв';

  @override
  String get shareYourExperienceHint => 'Поделитесь своим опытом...';

  @override
  String get pleaseWriteSomething => 'Пожалуйста, напишите что-нибудь';

  @override
  String get pleaseLoginFirst => 'Сначала войдите в систему';

  @override
  String get alreadyReviewedThisVet => 'Вы уже оставили отзыв об этом ветеринаре';

  @override
  String get errorSubmittingReview => 'Ошибка отправки отзыва';

  @override
  String errorLoadingReviews(Object error) {
    return 'Ошибка загрузки отзывов: $error';
  }

  @override
  String get galleryNotAvailable => 'Галерея недоступна.';

  @override
  String get noGalleryMediaYet => 'В галерее пока нет медиа.';

  @override
  String get shopSectionComingSoon => 'Раздел магазина скоро будет подключен.';

  @override
  String durationMinutesShort(Object minutes) {
    return '$minutes мин';
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
  String get usernameLabel => 'Имя пользователя';

  @override
  String get emailLabel => 'Электронная почта';

  @override
  String get phoneLabel => 'Номер телефона';

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
  String get noDogsAvailableForAdoption => 'Нет собак, доступных для усыновления';

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
  String get welcomeTo => 'Добро пожаловать';

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
  String get signInTitle => 'Войти';

  @override
  String get signUpTitle => 'Зарегистрироваться';

  @override
  String get signInButton => 'Войти';

  @override
  String get signUpButton => 'Зарегистрироваться';

  @override
  String get continueAsGuest => 'Продолжить как гость';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get confirmPasswordLabel => 'Подтвердите пароль';

  @override
  String get rememberMeLabel => 'Запомнить меня';

  @override
  String get forgotPasswordLabel => 'Забыли пароль?';

  @override
  String get termsAndConditionsLabel => 'Я принимаю Условия использования';

  @override
  String get termsAndConditionsPrefix => 'Я принимаю ';

  @override
  String get termsAndConditionsText => 'Условия использования';

  @override
  String get receiveNewsLabel => 'Получать новости и обновления';

  @override
  String get emailRequired => 'Пожалуйста, введите электронную почту';

  @override
  String get emailInvalid => 'Пожалуйста, введите действительный адрес электронной почты';

  @override
  String get usernameRequired => 'Пожалуйста, введите имя пользователя';

  @override
  String get phoneRequired => 'Пожалуйста, введите номер телефона';

  @override
  String get phoneNumberTooShort => 'Номер телефона слишком короткий';

  @override
  String get phoneMinDigits => 'Phone number must be at least 10 digits';

  @override
  String get passwordRequired => 'Пожалуйста, введите пароль';

  @override
  String get passwordValidation => 'Пароль должен быть не короче 8 символов и содержать буквы и цифры';

  @override
  String get passwordMismatch => 'Пароли не совпадают';

  @override
  String get confirmPasswordRequired => 'Пожалуйста, подтвердите пароль';

  @override
  String get termsRequired => 'Необходимо принять Условия использования';

  @override
  String get forgotPasswordDialogTitle => 'Забыли пароль';

  @override
  String get forgotPasswordDialogMessage => 'Введите электронную почту, чтобы сбросить пароль.';

  @override
  String get sendButton => 'Отправить';

  @override
  String passwordResetSent(Object email) {
    return 'Письмо для сброса пароля отправлено на $email';
  }

  @override
  String get emailAddressHint => 'Адрес электронной почты';

  @override
  String get passwordResetEmailSent => 'Письмо для сброса пароля отправлено 📩';

  @override
  String get noAccountSignUp => 'Нет аккаунта? Зарегистрироваться';

  @override
  String get haveAccountSignIn => 'Уже есть аккаунт? Войти';

  @override
  String get userNotFound => 'Пользователь с этой электронной почтой не найден. Пожалуйста, зарегистрируйтесь.';

  @override
  String get authUserNotFound => 'Пользователь не найден';

  @override
  String get pleaseVerifyEmailBeforeSigningIn => 'Пожалуйста, подтвердите электронную почту перед входом.';

  @override
  String get userCreationFailed => 'Не удалось создать пользователя';

  @override
  String get verificationEmailCouldNotBeSent => 'Не удалось отправить письмо подтверждения';

  @override
  String get verificationSessionCouldNotBeCreated => 'Не удалось создать сеанс подтверждения';

  @override
  String get emailAlreadyRegisteredTryLoggingIn => 'Эта электронная почта уже зарегистрирована. Попробуйте войти.';

  @override
  String get incorrectPassword => 'Неверный пароль. Попробуйте еще раз.';

  @override
  String get fillAllFields => 'Пожалуйста, правильно заполните все поля';

  @override
  String errorOccurred(Object error) {
    return 'Произошла ошибка: $error';
  }

  @override
  String get verifyEmailTitle => 'Подтвердите электронную почту';

  @override
  String get enterVerificationCodeSentToEmail => 'Введите код подтверждения, отправленный на вашу электронную почту';

  @override
  String get pleaseEnterSixDigitCode => 'Пожалуйста, введите 6-значный код';

  @override
  String get emailVerifiedSuccessfully => 'Электронная почта успешно подтверждена';

  @override
  String get invalidVerificationCode => 'Недействительный код подтверждения';

  @override
  String verificationCodeSent(Object email) {
    return 'Код подтверждения отправлен на $email';
  }

  @override
  String get enterCodeLabel => 'Введите 6-значный код';

  @override
  String get verifyButton => 'Подтвердить';

  @override
  String get authWelcomeBackSubtitle => 'С возвращением в BarkyMatches';

  @override
  String get authCreateAccountSubtitle => 'Создайте аккаунт BarkyMatches';

  @override
  String get sessionExpiredPleaseSignInAgain => 'Ваша сессия истекла. Пожалуйста, войдите снова.';

  @override
  String get signInToAccessPlaymate => 'Пожалуйста, войдите, чтобы открыть доступ к Плеймейт';

  @override
  String get findPlaymates => 'Найти друзей';

  @override
  String get signInToFindFriends => 'Найти друзей для вашего питомца';

  @override
  String get addYourDog => 'Add Your Dog';

  @override
  String get nameLabel => 'Имя *';

  @override
  String get pleaseEnterDogName => 'Please enter your dog\'s name';

  @override
  String get selectBreedHint => 'Выберите породу';

  @override
  String get pleaseSelectBreed => 'Please select a breed';

  @override
  String get ageLabel => 'Возраст *';

  @override
  String get pleaseEnterDogAge => 'Please enter your dog\'s age';

  @override
  String get pleaseEnterValidAge => 'Please enter a valid age';

  @override
  String get selectGenderHint => 'Выберите пол';

  @override
  String get pleaseSelectGender => 'Please select a gender';

  @override
  String get selectHealthStatusHint => 'Выберите состояние здоровья';

  @override
  String get pleaseSelectHealthStatus => 'Please select a health status';

  @override
  String get neuteredLabel => 'Стерилизация *';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get pleaseSpecifyNeutered => 'Please specify if the dog is neutered';

  @override
  String get traitsLabel => 'Характеристики *';

  @override
  String get pleaseSelectAtLeastOneTrait => 'Please select at least one trait';

  @override
  String get selectOwnerGenderHint => 'Пол владельца';

  @override
  String get pleaseSelectOwnerGender => 'Please select your gender';

  @override
  String get uploadImagesLabel => 'Upload Images';

  @override
  String get pickFromGallery => 'Pick from Gallery';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get availableForAdoption => 'Доступна для усыновления';

  @override
  String get descriptionLabel => 'Описание';

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
  String get editDog => 'Редактировать собаку';

  @override
  String get photosLabel => 'Фото';

  @override
  String get chooseFromGallery => 'Выбрать из галереи';

  @override
  String get takeAPhoto => 'Сделать фото';

  @override
  String get noMedia => 'Нет медиа';

  @override
  String get save => 'Сохранить';

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
  String get pleaseFillRequiredFields => 'Пожалуйста, правильно заполните все обязательные поля';

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
  String get editDogPermissionDenied => 'You do not have permission to edit this dog.';

  @override
  String get editDogEnterName => 'Please enter the dog\'s name';

  @override
  String get editDogEnterValidAge => 'Please enter a valid age';

  @override
  String get editDogOwnerGenderMale => 'Мужчина';

  @override
  String get editDogOwnerGenderFemale => 'Женщина';

  @override
  String get editDogOwnerGenderOther => 'Другое';

  @override
  String get findPlaymateTitle => 'Find a Playmate';

  @override
  String get noDogsMatchFilters => 'No dogs match your filters.';

  @override
  String get adjustFiltersSuggestion => 'Try adjusting your filters or increasing the distance.';

  @override
  String get anyGender => 'Любой';

  @override
  String distanceLabel(Object distance) {
    return 'Расстояние: $distance км';
  }

  @override
  String get resetFiltersButton => 'Reset Filters';

  @override
  String get basketTitle => 'Корзина';

  @override
  String basketItemsCount(Object count) {
    return '$count товаров';
  }

  @override
  String get yourBasketIsEmpty => 'Ваша корзина пуста';

  @override
  String get sellerLabel => 'Продавец';

  @override
  String get allProductsTitle => 'Все товары';

  @override
  String get sellerProductsTitle => 'Товары продавца';

  @override
  String get searchProductsHint => 'Поиск товара, бренда, продавца...';

  @override
  String get allCategoriesLabel => 'Все категории';

  @override
  String get categoryLabel => 'Категория';

  @override
  String get shippingLabel => 'Доставка';

  @override
  String get freeShippingLabel => 'Бесплатная доставка';

  @override
  String get sellerPaysCargoLabel => 'Доставку оплачивает продавец';

  @override
  String get fixedCargoLabel => 'Фиксированная доставка';

  @override
  String get calculatedCargoLabel => 'Доставка по расчету';

  @override
  String get sortLabel => 'Сортировка';

  @override
  String get recommendedLabel => 'Рекомендуемые';

  @override
  String get priceLowLabel => 'Цена: по возрастанию';

  @override
  String get priceHighLabel => 'Цена: по убыванию';

  @override
  String get bestDiscountLabel => 'Лучшая скидка';

  @override
  String productsCount(Object count) {
    return '$count товаров';
  }

  @override
  String get noProductsMatchFilters => 'Нет товаров, соответствующих фильтрам';

  @override
  String errorLoadingProducts(Object error) {
    return 'Ошибка загрузки товаров: $error';
  }

  @override
  String get noActiveProductsFound => 'Активные товары не найдены';

  @override
  String addedToBasket(Object productName) {
    return '$productName добавлен в корзину';
  }

  @override
  String get addButton => 'Добавить';

  @override
  String get freeCargoLabel => 'Бесплатная доставка';

  @override
  String cargoPriceLabel(Object price) {
    return 'Доставка $price';
  }

  @override
  String get cargoCalculatedLabel => 'Доставка по расчету';

  @override
  String freeOverLabel(Object price) {
    return 'Бесплатно от $price';
  }

  @override
  String vatRateLabel(Object percent) {
    return 'НДС $percent%';
  }

  @override
  String get vatIncludedLabel => 'НДС включен';

  @override
  String daysLabel(Object days) {
    return '$days дней';
  }

  @override
  String get inStockLabel => 'В наличии';

  @override
  String get outOfStockLabel => 'Нет в наличии';

  @override
  String get subtotalLabel => 'Промежуточный итог';

  @override
  String get moreFiltersButton => 'Больше фильтров';

  @override
  String get petTypeLabel => 'Тип питомца';

  @override
  String get petTypeDog => 'Собака';

  @override
  String get petTypeCat => 'Кошка';

  @override
  String get petTypeBird => 'Птица';

  @override
  String get petTypeHorse => 'Лошадь';

  @override
  String get genderOther => 'Другое';

  @override
  String get breedPersian => 'Персидская';

  @override
  String get breedSiamese => 'Сиамская';

  @override
  String get breedMaineCoon => 'Мейн-кун';

  @override
  String get breedBritishShorthair => 'Британская короткошерстная';

  @override
  String get breedParrot => 'Попугай';

  @override
  String get breedCanary => 'Канарейка';

  @override
  String get breedBudgerigar => 'Волнистый попугай';

  @override
  String get breedArabian => 'Арабская';

  @override
  String get breedThoroughbred => 'Чистокровная';

  @override
  String get breedMustang => 'Мустанг';

  @override
  String get filterByBreed => 'Фильтр по породе';

  @override
  String get filterByGender => 'Фильтр по полу';

  @override
  String get filterByAge => 'Фильтр по возрасту';

  @override
  String get filterByNeuteredStatus => 'Фильтр по статусу стерилизации';

  @override
  String get selectNeuteredStatusHint => 'Выберите статус стерилизации';

  @override
  String get filterByHealthStatus => 'Фильтр по состоянию здоровья';

  @override
  String get upgradeToPremiumForMoreFilters => 'Обновите до Premium для большего числа фильтров!';

  @override
  String get upgradeToPremiumTitle => 'Обновить до Premium';

  @override
  String get upgradeToPremiumSubtitle => 'Откройте доступ к расширенным возможностям и бизнес-инструментам';

  @override
  String get apply => 'Применить';

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
  String get cancel => 'Отмена';

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
  String get notifications => 'Уведомления';

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
  String get pleaseLoginToViewPlaydateRequests => 'Войдите, чтобы просмотреть запросы на игровые встречи';

  @override
  String get pleaseLoginToSetReminders => 'Пожалуйста, войдите, чтобы настроить напоминания.';

  @override
  String reminderSetForMinutesBefore(Object minutesBefore) {
    return 'Напоминание установлено за $minutesBefore минут до встречи 🐾';
  }

  @override
  String get failedToSetReminder => 'Не удалось установить напоминание ❌';

  @override
  String get playdateAcceptedCardTitle => 'Игровая встреча принята 🐾';

  @override
  String playdateAcceptedCardBody(Object dogName) {
    return '$dogName принял вашу заявку на игровую встречу.\nРадуйтесь — впереди встреча с виляющими хвостами! 🐶💖';
  }

  @override
  String get playdateRejectedCardTitle => 'На этот раз нет';

  @override
  String playdateRejectedCardBody(Object dogName) {
    return '$dogName не смог принять это время.\nНичего страшного — попробуйте снова и держите лапы в движении 🐾';
  }

  @override
  String get dogTab => 'Собака';

  @override
  String get reminderTab => 'Напоминание';

  @override
  String get playdateTimeNotScheduledYet => '⏳ Время игровой встречи еще не назначено';

  @override
  String get thirtyMinutesBefore => 'За 30 минут';

  @override
  String get oneHourBefore => 'За 1 час';

  @override
  String get reminderSet => 'Напоминание установлено ✅';

  @override
  String get viewLocation => 'Посмотреть место';

  @override
  String get locationLabel => 'Location:';

  @override
  String get unknownStatus => 'unknown';

  @override
  String get unknownTime => 'Unknown time';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes мин назад';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours ч назад';
  }

  @override
  String daysAgo(Object days) {
    return '$days д назад';
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
  String get playmateService => 'Плеймейт';

  @override
  String get playmateSearchHint => 'Поиск собак...';

  @override
  String get playmateLocationNeededTitle => 'Нужно местоположение';

  @override
  String get playmateLocationNeededMessage => 'Мы используем ваше местоположение, чтобы показать собак поблизости';

  @override
  String get playmateFiltersTitle => 'Фильтры';

  @override
  String get playmateBreedPremiumHint => 'Порода (Gold)';

  @override
  String get playmateOwnerGenderPremiumHint => 'Пол владельца (Premium)';

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
  String get reportLostDogMenuItem => 'Сообщить о потерянной собаке';

  @override
  String get lostDogsMenuItem => 'Потерянные собаки';

  @override
  String get reportFoundDogMenuItem => 'Сообщить о найденной собаке';

  @override
  String get foundDogsMenuItem => 'Найденные собаки';

  @override
  String get petShopsMenuItem => 'Pet Shops';

  @override
  String get hospitalsMenuItem => 'Hospitals';

  @override
  String get logoutMenuItem => 'Logout';

  @override
  String get filterDogsMenuItem => 'Filter Dogs';

  @override
  String get homeNavItem => 'Главная';

  @override
  String get favoritesNavItem => 'Избранное';

  @override
  String get visitVetNavItem => 'Visit Vet';

  @override
  String get playdateNavItem => 'Playdate';

  @override
  String get profileNavItem => 'Профиль';

  @override
  String get notificationsTooltip => 'Notifications';

  @override
  String get chatTooltip => 'Chat';

  @override
  String get chatNotImplemented => 'Чат пока не реализован';

  @override
  String get dogParkTitle => 'Парки для собак';

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
  String get dogParkRecommendedBadge => '⭐ Рекомендуется';

  @override
  String get dogParkPremiumBadge => '🔒 Премиум';

  @override
  String get dogParkSavedBadge => '❤️ Сохранено';

  @override
  String get dogParkRecommendedForPlaydates => 'Рекомендуется для игровых встреч';

  @override
  String get dogParkSavedToFavorites => 'Сохранено в избранное';

  @override
  String get dogParkSaveThisPark => 'Сохранить этот парк';

  @override
  String get dogParkGetDirections => 'Построить маршрут';

  @override
  String get dogParkUserNotReadyYet => 'Пользователь еще не готов. Пожалуйста, попробуйте снова.';

  @override
  String get dogParkNeedToAddDogFirst => 'Сначала нужно добавить собаку';

  @override
  String get dogParkSchedulePlaydateHere => 'Запланировать игровую встречу здесь';

  @override
  String get dogParkSavedParksTitle => 'Сохраненные парки';

  @override
  String get dogParkNoSavedParksYet => 'Пока нет сохраненных парков';

  @override
  String get dogParkFindNearbyParks => 'Найти ближайшие парки';

  @override
  String get dogParkLocationNeededTitle => 'Требуется местоположение';

  @override
  String get dogParkUseYourLocationToShowNearbyDogParks => 'Мы используем ваше местоположение, чтобы показывать ближайшие собачьи парки';

  @override
  String get allowButton => 'Разрешить';

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
  String get distanceUnknown => 'Расстояние неизвестно';

  @override
  String boostDogTitle(Object dogName) {
    return 'Продвинуть $dogName';
  }

  @override
  String get boostVisibilityDescription => 'Получите больше видимости в поиске Playmates.';

  @override
  String get boost24HoursTitle => 'Буст на 24 часа';

  @override
  String get boostQuickVisibilitySubtitle => 'Подходит для быстрой видимости';

  @override
  String get boostPrice29 => '₺29';

  @override
  String get boost3DaysTitle => 'Буст на 3 дня';

  @override
  String get boostBetterExposureSubtitle => 'Лучше подходит для активного поиска';

  @override
  String get boostPrice69 => '₺69';

  @override
  String get boost7DaysTitle => 'Буст на 7 дней';

  @override
  String get boostBestValueSubtitle => 'Лучшее соотношение цены и охвата';

  @override
  String get boostPrice129 => '₺129';

  @override
  String get boostActivated => 'Буст активирован 🚀';

  @override
  String boostFailed(Object error) {
    return 'Не удалось активировать буст: $error';
  }

  @override
  String get errorOpeningEdit => 'Ошибка открытия редактирования';

  @override
  String get boostBadge => 'BOOSTED';

  @override
  String get boostButton => 'Буст';

  @override
  String get blockComingSoon => 'Блокировка скоро появится';

  @override
  String get blockMenuItem => 'Заблокировать пользователя';

  @override
  String get sendAdoptionRequest => 'Отправить заявку на усыновление';

  @override
  String ownerPrefix(Object owner) {
    return 'Владелец: $owner';
  }

  @override
  String get submitComplaintMenuItem => 'Подать жалобу';

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
  String get noDogsFound => 'Собаки не найдены';

  @override
  String get noDogsForUser => 'No dogs found for this user.';

  @override
  String get dogsOfThisUser => 'Собаки этого пользователя';

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
  String get adoptionCenter => 'Центр усыновления';

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
  String get editDogHealthHealthy => 'Здоров';

  @override
  String get editDogHealthNeedsCare => 'Нуждается в уходе';

  @override
  String get editDogHealthUnderTreatment => 'На лечении';

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
  String get schedulePlayDate => 'Запланировать игровую встречу';

  @override
  String get playdateSchedulingSubtitle => 'Выберите дату, время, место и собак для игровой встречи.';

  @override
  String get errorSelectDateAndTime => 'Пожалуйста, выберите дату и время.';

  @override
  String get errorMissingLocationCoordinates => 'Координаты места парка отсутствуют.';

  @override
  String get errorPlaydateLeadTime => 'Встречу нужно планировать как минимум за 15 минут.';

  @override
  String get playdateTimeConflict => 'У этой собаки уже есть встреча примерно на это время 🐾';

  @override
  String coordinatesLatLng(Object lat, Object lng) {
    return 'Широта: $lat, Долгота: $lng';
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
  String get genderMale => 'Самец';

  @override
  String get genderFemale => 'Самка';

  @override
  String get healthHealthy => 'Здоров';

  @override
  String get healthNeedsCare => 'Нуждается в уходе';

  @override
  String get healthUnderTreatment => 'На лечении';

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
  String get simpleTestPageTitle => 'Простая тестовая страница';

  @override
  String get simpleTestPageMessage => 'Это простая тестовая страница.';

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
  String get playdatesTitle => 'Игровые встречи';

  @override
  String get manageRequests => 'Управлять запросами';

  @override
  String get adoptionTitle => 'Усыновление';

  @override
  String get giveLove => 'Подарить любовь';

  @override
  String get alertsTitle => 'Оповещения';

  @override
  String get lostAndFound => 'Потерянные и найденные';

  @override
  String get vetTitle => 'Ветеринар';

  @override
  String get nearbyClinics => 'Клиники поблизости';

  @override
  String get groomyTitle => 'Груминг';

  @override
  String get bookGrooming => 'Записаться на груминг';

  @override
  String get pamperYourPet => 'Побалуйте своего питомца';

  @override
  String get petShopTitle => 'Зоомагазин';

  @override
  String get shopNearYou => 'Магазин рядом с вами';

  @override
  String get featuredDeal => 'Избранное предложение';

  @override
  String get premiumLabel => 'Премиум';

  @override
  String get goldLabel => 'Gold';

  @override
  String discountOff(Object percent) {
    return 'Скидка $percent%';
  }

  @override
  String get socialAndPlay => 'Общение и игры';

  @override
  String get careAndServices => 'Уход и услуги';

  @override
  String get outdoorAndLifestyle => 'Прогулки и стиль жизни';

  @override
  String get exploreNearbyParks => 'Посмотреть парки поблизости';

  @override
  String get createMemoriesTogether => 'Создавайте воспоминания вместе';

  @override
  String get reportFoundTitle => 'Сообщить о найденном';

  @override
  String get reconnectFamilies => 'Помогите питомцам вернуться домой';

  @override
  String get lostPetsTitle => 'Пропавшие питомцы';

  @override
  String get activeReportsNearby => 'Просмотреть активные объявления';

  @override
  String get foundPetsTitle => 'Найденные питомцы';

  @override
  String get waitingToReunite => 'Ждут возвращения домой';

  @override
  String get trainingTitle => 'Дрессировка';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get trainingComingSoonMessage => 'Раздел дрессировки скоро появится 🐾';

  @override
  String get communityHub => 'Центр сообщества';

  @override
  String get safetyAndRescue => 'Безопасность и спасение';

  @override
  String activeCount(Object count) {
    return '$count активных';
  }

  @override
  String get reportTitle => 'Сообщить';

  @override
  String get lostDogTitle => 'Потерянная собака';

  @override
  String get lostPetTitle => 'Потерянный питомец';

  @override
  String get foundDogTitle => 'Найденная собака';

  @override
  String get foundPetTitle => 'Найденный питомец';

  @override
  String get lostTitle => 'Потерянные';

  @override
  String get dogsTitle => 'Собаки';

  @override
  String get petsTitle => 'Питомцы';

  @override
  String get foundTitle => 'Найденные';

  @override
  String get homeDefaultUsername => 'Пользователь';

  @override
  String get homePetHotelTitle => 'Отель для питомцев';

  @override
  String get homeSafeStaySubtitle => 'Безопасное пребывание';

  @override
  String get homePetTaxiTitle => 'Такси для питомцев';

  @override
  String get homeRideSafelySubtitle => 'Безопасная поездка';

  @override
  String get homeGreenMemorialTitle => 'Зеленый мемориал';

  @override
  String get homeVeterinaryTitle => 'Ветеринария';

  @override
  String get expertCareForYourPet => 'Профессиональная забота о вашем питомце';

  @override
  String get homeLocationNeededTitle => 'Нужно местоположение';

  @override
  String get homeLocationNeededMessage => 'Мы используем ваше местоположение, чтобы показать ветеринаров поблизости';

  @override
  String get homeAllowButton => 'Разрешить';

  @override
  String get homeBusinessesTitle => 'Бизнесы';

  @override
  String get homeSearchHint => 'Искать услуги, магазины, сообщество...';

  @override
  String get homePetFriendlyPlaceTitle => 'Место, дружелюбное к питомцам';

  @override
  String get homeSponsoredLabel => 'Спонсировано';

  @override
  String get homeShopButton => 'Магазин';

  @override
  String get petShopDealName => 'Pet Shop A';

  @override
  String get petShopDealDesc => 'Скидка 15% на весь корм';

  @override
  String get groomyDealName => 'Groomy Studio';

  @override
  String get groomyDealDesc => 'Скидка 20% на груминг на этой неделе';

  @override
  String get vetDealName => 'VetPlus';

  @override
  String get vetDealDesc => 'Для участников Gold: бесплатный осмотр';

  @override
  String get offerWhatsApp => 'WhatsApp';

  @override
  String offerCodeCopied(Object code) {
    return 'Code copied: $code';
  }

  @override
  String get offerOpenError => 'Error opening offer';

  @override
  String get businessRegisterLegalCompanyNameRequired => '• Необходимо указать юридическое название компании.';

  @override
  String get businessRegisterPublicDisplayNameRequired => '• Необходимо указать публичное название.';

  @override
  String get businessRegisterSelectCountry => '• Пожалуйста, выберите страну.';

  @override
  String get businessRegisterSelectBusinessCategory => '• Пожалуйста, выберите хотя бы одну категорию бизнеса.';

  @override
  String get businessRegisterEnterValidEmail => '• Введите действительный адрес электронной почты (пример: name@example.com).';

  @override
  String get businessRegisterPhoneIncomplete => '• Номер телефона неполный.';

  @override
  String get businessRegisterSelectCityProvince => '• Пожалуйста, выберите город / область.';

  @override
  String get businessRegisterSelectDistrict => '• Пожалуйста, выберите район.';

  @override
  String get businessRegisterBusinessAddressRequired => '• Необходимо указать адрес бизнеса.';

  @override
  String get businessRegisterAllLegalDocumentsRequired => '• Все необходимые юридические документы должны быть загружены.';

  @override
  String get businessRegisterDocumentsVerifiedBeforeContinuing => '• Перед продолжением документы должны быть проверены.';

  @override
  String get businessRegisterAcceptPlatformTerms => '• Необходимо принять условия платформы.';

  @override
  String get businessRegisterAcceptLegalResponsibility => '• Необходимо принять декларацию юридической ответственности.';

  @override
  String get businessRegisterFixHighlightedFields => 'Пожалуйста, исправьте выделенные поля';

  @override
  String get businessRegisterOk => 'OK';

  @override
  String get businessRegisterFailedToLoadCountries => 'Не удалось загрузить страны';

  @override
  String get businessRegisterFailedToLoadCities => 'Не удалось загрузить города';

  @override
  String get businessRegisterFailedToLoadDistricts => 'Не удалось загрузить районы';

  @override
  String get businessRegisterPlatformLegalAgreement => 'Юридическое соглашение платформы';

  @override
  String get businessRegisterReadAndAccept => 'Я прочитал(а) и принимаю';

  @override
  String get businessRegisterLocationPermissionDenied => 'Доступ к местоположению запрещен';

  @override
  String get businessRegisterCouldNotDetectCity => 'Не удалось определить город';

  @override
  String get businessRegisterGroomer => 'Грумер';

  @override
  String get businessRegisterVeterinaryClinic => 'Ветеринарная клиника';

  @override
  String get businessRegisterDogTrainer => 'Кинолог';

  @override
  String get businessRegisterPetHotel => 'Отель для питомцев';

  @override
  String get businessRegisterDogWalker => 'Выгульщик собак';

  @override
  String get businessRegisterBreeder => 'Заводчик';

  @override
  String get businessRegisterInvalidEmail => 'Недействительный адрес электронной почты';

  @override
  String get businessRegisterInvalidPhone => 'Недействительный номер телефона';

  @override
  String get businessRegisterInvalidWebsite => 'Недействительный веб-сайт';

  @override
  String get businessRegisterCouldNotOpenLegalText => 'Не удалось открыть юридический текст';

  @override
  String get businessRegisterSelectAtLeastOneBusinessCategory => 'Пожалуйста, выберите хотя бы одну категорию бизнеса';

  @override
  String get businessRegisterPleaseEnterBusinessAddress => 'Пожалуйста, введите адрес бизнеса';

  @override
  String get businessRegisterMustAcceptAllAgreements => 'Необходимо принять все соглашения';

  @override
  String get businessRegisterDocumentsVerifiedBeforeSubmission => 'Перед отправкой документы должны быть проверены';

  @override
  String get businessRegisterApplicationSubmittedSuccessfully => 'Заявка успешно отправлена';

  @override
  String get businessRegisterSubmissionFailed => 'Не удалось отправить заявку';

  @override
  String get businessRegisterUnexpectedErrorOccurred => 'Произошла непредвиденная ошибка';

  @override
  String get businessRegisterTitle => 'Регистрация бизнеса';

  @override
  String get businessRegisterStepIdentityCategories => 'Идентификация бизнеса и категории';

  @override
  String get businessRegisterStepContactLocation => 'Контакты и местоположение';

  @override
  String get businessRegisterStepLegalDocuments => 'Юридические документы';

  @override
  String get businessRegisterStepAgreementConfirmation => 'Подтверждение соглашения';

  @override
  String get businessRegisterBack => 'Назад';

  @override
  String get businessRegisterContinue => 'Продолжить';

  @override
  String get businessRegisterSubmitApplication => 'Отправить заявку';

  @override
  String get businessRegisterCompleteSectorDetails => 'Заполнить сведения о секторе';

  @override
  String get businessRegisterBusinessIdentity => 'Идентификация бизнеса';

  @override
  String get businessRegisterBusinessIdentitySubtitle => 'Укажите, как ваш бизнес должен отображаться в PetSupo.';

  @override
  String get businessRegisterLegalCompanyName => 'Юридическое название компании';

  @override
  String get businessRegisterRequired => 'Обязательно';

  @override
  String get businessRegisterPublicDisplayName => 'Публичное название';

  @override
  String get businessRegisterCountry => 'Страна';

  @override
  String get businessRegisterBusinessCategories => 'Категории бизнеса';

  @override
  String get businessRegisterBusinessCategoriesSubtitle => 'Выберите все секторы, в которых работает этот бизнес.';

  @override
  String get businessRegisterContactLocation => 'Контакты и местоположение';

  @override
  String get businessRegisterContactLocationSubtitle => 'Эти данные помогают клиентам найти вас и связаться с вами.';

  @override
  String get businessRegisterPhone => 'Телефон';

  @override
  String get businessRegisterWebsiteOptional => 'Веб-сайт (необязательно)';

  @override
  String get businessRegisterLoadingCities => 'Загрузка городов...';

  @override
  String get businessRegisterCityProvince => 'Город / область';

  @override
  String get businessRegisterLoadingDistricts => 'Загрузка районов...';

  @override
  String get businessRegisterDistrict => 'Район';

  @override
  String get businessRegisterBusinessAddress => 'Адрес бизнеса';

  @override
  String get businessRegisterDetectCity => 'Определить город';

  @override
  String get businessRegisterMapPickerComingSoon => 'Выбор на карте будет добавлен скоро';

  @override
  String get businessRegisterPickLocation => 'Выбрать местоположение';

  @override
  String get businessRegisterLocationSelected => 'Местоположение выбрано';

  @override
  String get businessRegisterTaxPlate => 'Налоговая справка';

  @override
  String get businessRegisterTradeRegistryGazette => 'Вестник торгового реестра';

  @override
  String get businessRegisterAuthorizedSignatureDocument => 'Документ уполномоченной подписи';

  @override
  String get businessRegisterTaxNumberVkn => 'Налоговый номер (VKN)';

  @override
  String get businessRegisterAutoFilledFromDocument => 'Автоматически заполнено из документа';

  @override
  String get businessRegisterDocumentVerificationInconsistencies => 'В проверке документа есть несоответствия. Требуется проверка администратором.';

  @override
  String get businessRegisterMersisNumber => 'Номер MERSIS';

  @override
  String get businessRegisterDocumentsSecurelyEncrypted => 'Ваши документы надежно шифруются и проверяются автоматически';

  @override
  String get businessRegisterVerifiedFromDocument => 'Проверено по документу';

  @override
  String get businessRegisterAutoFilledAfterVerification => 'Автоматически заполняется после проверки документа';

  @override
  String get businessRegisterUploadTradeRegistryFirst => 'Сначала загрузите документ торгового реестра';

  @override
  String get businessRegisterWaitingForDocumentVerification => 'Ожидание проверки документа...';

  @override
  String get businessRegisterSteuernummer => 'Налоговый номер';

  @override
  String get businessRegisterTaxNumberRequired => 'Необходимо указать налоговый номер';

  @override
  String get businessRegisterGewerbeschein => 'Свидетельство о регистрации бизнеса';

  @override
  String get businessRegisterHandelsregisterauszug => 'Выписка из торгового реестра';

  @override
  String get businessRegisterEinNumber => 'Номер EIN';

  @override
  String get businessRegisterEinNumberRequired => 'Необходимо указать номер EIN';

  @override
  String get businessRegisterBusinessLicense => 'Бизнес-лицензия';

  @override
  String get businessRegisterIrsEinDocument => 'Документ IRS EIN';

  @override
  String get businessRegisterProcessingDocument => 'Обработка документа...';

  @override
  String get businessRegisterDocumentVerifiedSuccessfully => 'Документ успешно проверен';

  @override
  String get businessRegisterCouldNotReadDocument => 'Не удалось прочитать документ, пожалуйста, загрузите его повторно';

  @override
  String get businessRegisterVeterinary => 'Ветеринария';

  @override
  String get businessRegisterGroomy => 'Groomy';

  @override
  String businessRegisterStepOfFour(Object step) {
    return 'Шаг $step из 4';
  }

  @override
  String get businessRegisterLegalConfirmation => 'Юридическое подтверждение';

  @override
  String get businessRegisterAcceptTermsKvkk => 'Я принимаю условия платформы и политику защиты данных KVKK.';

  @override
  String get businessRegisterReadInsideApp => 'Читать в приложении';

  @override
  String get businessRegisterOpenOfficialLegalPage => 'Открыть официальную юридическую страницу';

  @override
  String get businessRegisterLegalVersion => 'Версия v1.0 • Последнее обновление: май 2026';

  @override
  String get businessRegisterAgreementSecurelyStored => 'Ваше согласие надежно хранится и имеет юридическую силу';

  @override
  String get businessRegisterLegalResponsibilityDeclaration => 'Я заявляю, что все отправленные документы точны, и принимаю полную юридическую ответственность по Турецкому торговому кодексу.';

  @override
  String get businessRegisterUploaded => 'Загружено';

  @override
  String get businessRegisterReplaceDocument => 'Заменить документ';

  @override
  String get businessRegisterReplaceDocumentConfirmation => 'Вы уверены, что хотите заменить этот файл?';

  @override
  String get businessRegisterReplace => 'Заменить';

  @override
  String get businessRegisterUpload => 'Загрузить';

  @override
  String userProfileInitError(Object error) {
    return 'Ошибка инициализации профиля: $error';
  }

  @override
  String userProfileImagePickError(Object error) {
    return 'Ошибка выбора фото: $error';
  }

  @override
  String get userProfileUnknownBusinessType => 'Неизвестный тип бизнеса';

  @override
  String get userProfileBusinessDashboard => 'Панель бизнеса';

  @override
  String get userProfileActivity => 'Активность';

  @override
  String get userProfileSavedParks => 'Сохраненные парки';

  @override
  String get userProfileMatches => 'Совпадения';

  @override
  String get userProfileMyOrders => 'Мои заказы';

  @override
  String get myAppointments => 'Мои записи';

  @override
  String get myAppointmentsLoginRequired => 'Пожалуйста, войдите, чтобы просмотреть свои записи';

  @override
  String get appointmentHistory => 'История записей';

  @override
  String get noAppointmentsYet => 'Пока нет записей';

  @override
  String get viewAppointment => 'Открыть запись';

  @override
  String get appointmentStatusPending => 'В ожидании';

  @override
  String get appointmentStatusAwaitingPayment => 'Ожидание оплаты';

  @override
  String get appointmentStatusConfirmed => 'Подтверждено';

  @override
  String get appointmentStatusConfirmedPaid => 'Подтверждено и оплачено';

  @override
  String get appointmentStatusPaymentExpired => 'Срок оплаты истек';

  @override
  String get appointmentStatusRejected => 'Отклонено';

  @override
  String get appointmentStatusCompleted => 'Завершено';

  @override
  String get appointmentStatusCancelledByUser => 'Отменено вами';

  @override
  String get appointmentStatusCancelledByVet => 'Отменено ветеринаром';

  @override
  String get appointmentStatusExpired => 'Срок истек';

  @override
  String get unpaidStatusLabel => 'Не оплачено';

  @override
  String get paymentNotRequiredStatusLabel => 'Оплата не требуется';

  @override
  String get refundUnderReviewStatusLabel => 'Возврат на проверке';

  @override
  String get refundRequestedStatusLabel => 'Возврат запрошен';

  @override
  String get refundCompletedStatusLabel => 'Возврат завершен';

  @override
  String get refundFailedStatusLabel => 'Возврат не удался';

  @override
  String get noRefundRequiredStatusLabel => 'Возврат не требуется';

  @override
  String get refundNotProcessedStatusLabel => 'Возврат еще не обработан';

  @override
  String get veterinaryClinicFallback => 'Ветклиника';

  @override
  String get veterinaryServiceFallback => 'Ветеринарная услуга';

  @override
  String get petFallback => 'Питомец';

  @override
  String get dogTypeLabel => 'собака';

  @override
  String get userProfileAdoptionRequests => 'Запросы на усыновление';

  @override
  String get userProfileBusiness => 'Бизнес';

  @override
  String get userProfileAdmin => 'Администратор';

  @override
  String get userProfileSupport => 'Поддержка';

  @override
  String get userProfileSendFeedback => 'Отправить отзыв';

  @override
  String get userProfileHelpCenter => 'Центр помощи';

  @override
  String get userProfilePrivacy => 'Конфиденциальность';

  @override
  String get userProfileReportProblem => 'Сообщить о проблеме';

  @override
  String get userProfileSubscriptionPlans => 'Подписка и планы';

  @override
  String get userProfileLanguage => 'Язык';

  @override
  String get userProfileTheme => 'Тема';

  @override
  String get userProfileChangePassword => 'Изменить пароль';

  @override
  String get userProfileGuestTitle => 'Вы просматриваете как гость';

  @override
  String get userProfileGuestSubtitle => 'Войдите, чтобы открыть все функции';

  @override
  String get userProfileLoginSignUp => 'Войти / Зарегистрироваться';

  @override
  String get userProfileLanguageEnglish => 'Английский';

  @override
  String get userProfileLanguagePersian => 'Персидский';

  @override
  String get userProfileLanguageTurkish => 'Турецкий';

  @override
  String get userProfileUnlockBusinessFeatures => 'Откройте бизнес-функции 🚀';

  @override
  String get userProfileUpgradeBusinessDescription => 'Перейдите на Gold, чтобы зарегистрировать бизнес и начать получать клиентов.';

  @override
  String get userProfileUpgradeToGold => 'Перейти на Gold';

  @override
  String get userProfileManageAdoptionCenter => 'Управление центром усыновления';

  @override
  String get userProfileOverview => 'Обзор';

  @override
  String get userProfileDogs => 'Собаки';

  @override
  String get userProfileRequests => 'Запросы';

  @override
  String get userProfileOverviewSection => 'Раздел обзора';

  @override
  String get userProfileDogsSection => 'Раздел собак';

  @override
  String get userProfileRequestsSection => 'Раздел запросов';

  @override
  String get userProfileSettingsSection => 'Раздел настроек';

  @override
  String get userProfileApplicationUnderReview => 'Заявка на рассмотрении';

  @override
  String get userProfileApplicationUnderReviewDescription => 'Ваша заявка на бизнес успешно отправлена и сейчас находится на рассмотрении.';

  @override
  String get userProfileAdminPanel => 'Панель администратора';

  @override
  String get userProfileManageBusinessCenter => 'Управление бизнес-центром';

  @override
  String get userProfileApplicationRejected => 'Заявка отклонена';

  @override
  String userProfileRejectionReason(Object reason) {
    return 'Причина: $reason';
  }

  @override
  String get userProfileUpgradeToGoldToContinue => 'Перейдите на Gold, чтобы продолжить';

  @override
  String get userProfileReApply => 'Подать повторно';

  @override
  String get userProfileBusinessStatus => 'Статус бизнеса';

  @override
  String get userProfileUnknownStatus => 'Неизвестно';

  @override
  String get userProfileChooseFromGallery => 'Выбрать из галереи';

  @override
  String get userProfileRemovePhoto => 'Удалить фото';

  @override
  String get userProfileImageSelectionFailed => 'Не удалось выбрать изображение.';

  @override
  String get userProfileUsernameMinLength => 'Имя пользователя должно содержать не менее 3 символов';

  @override
  String get userProfileUsernameMaxLength => 'Имя пользователя должно содержать не более 20 символов';

  @override
  String get userProfileUsernameNoSpaces => 'Имя пользователя не может содержать пробелы';

  @override
  String get userProfilePhoneInvalidCharacters => 'Телефон содержит недопустимые символы';

  @override
  String get userProfileBioMaxLength => 'Био должно быть короче 150 символов';

  @override
  String get userProfileUsernameAlreadyTaken => 'Имя пользователя уже занято';

  @override
  String get userProfileEmailUpdateFailed => 'Не удалось обновить электронную почту';

  @override
  String get userProfileUpdateFailed => 'Не удалось обновить профиль.';

  @override
  String get userProfileChangePhoto => 'Изменить фото';

  @override
  String get userProfileEnterUsername => 'Введите имя пользователя';

  @override
  String get userProfileEnterEmail => 'Введите электронную почту';

  @override
  String get userProfileOptionalPhoneNumber => 'Необязательный номер телефона';

  @override
  String get userProfileBio => 'Био';

  @override
  String get userProfileBioHint => 'Расскажите немного о себе';

  @override
  String get unnamedProduct => 'Безымянный товар';

  @override
  String barcodeLabel(Object barcode) {
    return 'Штрихкод: $barcode';
  }

  @override
  String skuLabel(Object sku) {
    return 'SKU: $sku';
  }

  @override
  String get dealBadge => '💸 Скидка';

  @override
  String get lowStockBadge => '⚡ Мало';

  @override
  String saveAmountLabel(Object amount) {
    return 'Экономия $amount';
  }

  @override
  String salePriceLabel(Object price) {
    return 'Цена продажи: $price';
  }

  @override
  String stockLabel(Object stock) {
    return 'Запас: $stock';
  }

  @override
  String get addToCartButton => 'В корзину';

  @override
  String get buyNowButton => 'Купить сейчас';

  @override
  String get addedToCart => 'Добавлено в корзину';

  @override
  String get mediaNotReadyYet => 'Медиа пока не готовы';

  @override
  String cargoLabel(Object price) {
    return 'Доставка: $price';
  }

  @override
  String carrierLabel(Object carrier) {
    return 'Перевозчик: $carrier';
  }

  @override
  String deliveryDaysRangeLabel(Object max, Object min) {
    return '$min-$max дней';
  }

  @override
  String get businessNotFound => 'Бизнес не найден';

  @override
  String get sectorDashboardNotImplementedYet => 'Панель этого сектора пока не реализована';

  @override
  String get goBackButton => 'Назад';

  @override
  String get backButton => 'Назад';

  @override
  String get veterinaryDashboardTitle => 'Ветеринарная панель';

  @override
  String get overviewTab => 'Обзор';

  @override
  String get appointmentsTab => 'Записи';

  @override
  String get shopProfileTitle => 'Профиль магазина';

  @override
  String get noDescriptionYet => 'Описание еще не добавлено.';

  @override
  String get noRevenueYet => 'Пока нет дохода';

  @override
  String get netRevenueLabel => 'Чистый доход';

  @override
  String get afterPlatformCommissionLabel => 'После комиссии платформы';

  @override
  String get grossSalesLabel => 'Валовые продажи';

  @override
  String get platformFeeLabel => 'Комиссия платформы';

  @override
  String get adjustmentsLabel => 'Корректировки';

  @override
  String get recentOrdersTitle => 'Недавние заказы';

  @override
  String get latestOrdersSubtitle => 'Последние 5 заказов';

  @override
  String get viewAllButton => 'Показать все';

  @override
  String get noDataLabel => 'Нет данных';

  @override
  String get noOrdersYet => 'Пока нет заказов';

  @override
  String orderNumberLabel(Object number) {
    return 'Заказ #$number';
  }

  @override
  String itemsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# товара',
      many: '# товаров',
      few: '# товара',
      one: '# товар',
    );
    return '$_temp0';
  }

  @override
  String trackingLabel(Object tracking) {
    return 'Отслеживание: $tracking';
  }

  @override
  String get trackShipmentButton => 'Отследить отправление';

  @override
  String get catalogStrengthUnavailable => 'Оценка каталога недоступна';

  @override
  String get catalogStrengthTitle => 'Оценка каталога';

  @override
  String get productsTitle => 'Товары';

  @override
  String get noProductsFound => 'Товары не найдены';

  @override
  String get lowStockLabel => 'Мало на складе';

  @override
  String get strengthLabel => 'Сила';

  @override
  String get shippableLabel => 'Можно отправить';

  @override
  String get withKdvLabel => 'С НДС';

  @override
  String get noProductsYet => 'Пока нет товаров';

  @override
  String get kdvIncludedLabel => 'НДС включен';

  @override
  String fromLabel(Object city) {
    return 'Из $city';
  }

  @override
  String returnsLabel(Object days) {
    return 'Возврат $days дн.';
  }

  @override
  String get pickupLabel => 'Самовывоз';

  @override
  String get sameDayLabel => 'В тот же день';

  @override
  String get offersTitle => 'Предложения';

  @override
  String get createOfferButton => 'Создать предложение';

  @override
  String get videoLabel => 'ВИДЕО';

  @override
  String get catalogStrengthWeakLabel => 'Слабый';

  @override
  String get catalogStrengthAddItemsMessage => 'Добавьте товары, описание, медиа и склад, чтобы усилить каталог.';

  @override
  String get catalogStrengthWeakDetailsMessage => 'Данные о товарах все еще слабые. Добавьте больше медиа, описаний и сведений о складе.';

  @override
  String get catalogStrengthMediumLabel => 'Средний';

  @override
  String get catalogStrengthMediumMessage => 'Хорошее начало. Добавьте более подробные описания и больше медиа для лучшей видимости.';

  @override
  String get catalogStrengthStrongLabel => 'Сильный';

  @override
  String get catalogStrengthStrongMessage => 'Отличное качество каталога. Ваши товары выглядят сильными и полными.';

  @override
  String get shippingCalculatedLabel => 'Доставка рассчитывается';

  @override
  String get fragileLabel => 'Хрупкое';

  @override
  String get oversizeLabel => 'Крупногабаритное';

  @override
  String originLabel(Object city) {
    return 'Откуда: $city';
  }

  @override
  String carriersCountLabel(Object count) {
    return '$count перевозчиков';
  }

  @override
  String kdvRateLabel(Object percent) {
    return 'НДС $percent%';
  }

  @override
  String get myOrdersLoginRequired => 'Пожалуйста, войдите, чтобы просмотреть свои заказы';

  @override
  String get myOrdersTitle => 'Мои заказы';

  @override
  String get ordersTitle => 'Заказы';

  @override
  String get searchByOrderIdOrProductNameHint => 'Поиск по номеру заказа или названию товара';

  @override
  String get allFilterLabel => 'Все';

  @override
  String get noMatchingOrders => 'Нет подходящих заказов';

  @override
  String get orderLabel => 'Заказ';

  @override
  String get itemsTitle => 'Товары';

  @override
  String qtyLabel(Object qty) {
    return 'Кол-во: $qty';
  }

  @override
  String get pendingStatusLabel => 'В ожидании';

  @override
  String get paidStatusLabel => 'Оплачен';

  @override
  String get confirmedStatusLabel => 'Подтвержден';

  @override
  String get preparingStatusLabel => 'Готовится';

  @override
  String get shippedStatusLabel => 'Отправлен';

  @override
  String get deliveredStatusLabel => 'Доставлен';

  @override
  String get completedStatusLabel => 'Завершено';

  @override
  String get failedStatusLabel => 'Неудачно';

  @override
  String get cancelledStatusLabel => 'Отменен';

  @override
  String get paymentFailedStatusLabel => 'Платеж не прошел';

  @override
  String get paidPayoutStatusLabel => 'Оплачено';

  @override
  String get readyForPayoutLabel => 'Готово к выплате';

  @override
  String get payoutPendingLabel => 'Выплата в ожидании';

  @override
  String get waitingForPaymentLabel => 'Ожидание оплаты';

  @override
  String get payoutNotSetLabel => 'Выплата не настроена';

  @override
  String get confirmOrderButton => 'Подтвердить заказ';

  @override
  String get startPreparingButton => 'Начать подготовку';

  @override
  String get openOrderButton => 'Открыть заказ';

  @override
  String get simulateUploadInvoiceButton => 'Симулировать загрузку счета';

  @override
  String get invoiceSimulatedAsUploaded => 'Счет симулирован как загруженный';

  @override
  String invoiceError(Object error) {
    return 'Ошибка счета: $error';
  }

  @override
  String orderStatusUpdated(Object status) {
    return 'Статус обновлен на $status';
  }

  @override
  String invoiceSummaryLabel(Object deadline, Object status) {
    return 'Счет: $status • Срок: $deadline';
  }

  @override
  String sellerNetLabel(Object amount) {
    return 'Чистая сумма продавца: $amount';
  }

  @override
  String referenceLabel(Object reference) {
    return 'Ссылка: $reference';
  }

  @override
  String buyerNameLabel(Object name) {
    return 'Имя: $name';
  }

  @override
  String buyerSurnameLabel(Object surname) {
    return 'Фамилия: $surname';
  }

  @override
  String buyerIdentityNumberLabel(Object identityNumber) {
    return 'ID: $identityNumber';
  }

  @override
  String buyerCityLabel(Object city) {
    return 'Город: $city';
  }

  @override
  String buyerAddressLabel(Object address) {
    return 'Адрес: $address';
  }

  @override
  String get buyerInfoTitle => 'Информация о покупателе';

  @override
  String invoiceTypeLabel(Object type) {
    return 'Тип счета: $type';
  }

  @override
  String get invoiceTitle => 'Счет';

  @override
  String get uploadDeadlineLabel => 'Срок загрузки';

  @override
  String get warningsLabel => 'Предупреждения';

  @override
  String get penaltyLabel => 'Штраф';

  @override
  String get invoiceSystemLabel => 'Система счета';

  @override
  String get invoiceNoLabel => '№ счета';

  @override
  String get dateLabel => 'Дата';

  @override
  String get cannotOpenInvoiceFile => 'Не удалось открыть файл счета';

  @override
  String get viewInvoiceButton => 'Просмотреть счет';

  @override
  String get noInvoiceLabel => 'Без счета';

  @override
  String get uploadingLabel => 'Загрузка...';

  @override
  String get invoiceUploadedLabel => 'Счет загружен';

  @override
  String get uploadInvoiceButton => 'Загрузить счет';

  @override
  String get invoiceUploadDeadlinePassed => 'Срок загрузки счета истек!';

  @override
  String get timelineTitle => 'Хронология';

  @override
  String get payoutTitle => 'Выплата';

  @override
  String amountLabel(Object amount) {
    return 'Сумма: $amount';
  }

  @override
  String get paymentWillBeTransferredByPetsupo => 'Оплата будет перечислена Petsupo';

  @override
  String get pendingPayoutLabel => 'Выплата в ожидании';

  @override
  String get waitingForCustomerPayment => 'Ожидание оплаты клиента';

  @override
  String get actionsTitle => 'Действия';

  @override
  String get payoutMarkedAsPaid => 'Выплата помечена как оплаченная';

  @override
  String get trackingNumberLabel => 'Номер отслеживания';

  @override
  String get trackingNumberRequired => 'Требуется номер отслеживания';

  @override
  String get returnCarrierRequired => 'Требуется перевозчик';

  @override
  String get returnShippedBackFailed => 'Не удалось отметить возврат как отправленный обратно';

  @override
  String get returnTrackingNumberLabel => 'Номер отслеживания возврата';

  @override
  String get returnTrackingNumberHelperText => 'Введите номер отслеживания, выданный для возвратной отправки.';

  @override
  String get returnCarrierHelperText => 'Используйте того же перевозчика, что и для первоначальной доставки.';

  @override
  String get originalShipmentTrackingLabel => 'Отслеживание первоначальной отправки';

  @override
  String get returnShipmentTrackingLabel => 'Отслеживание возвратной отправки';

  @override
  String get returnShippedBackTimelineLabel => 'Возврат отправлен обратно';

  @override
  String get carrierMissingFromOrder => 'Перевозчик отсутствует в заказе';

  @override
  String get enterTrackingNumber => 'Введите номер отслеживания';

  @override
  String get shipOrderButton => 'Отправить заказ';

  @override
  String get markAsDeliveredButton => 'Отметить как доставлен';

  @override
  String get goToCarrierWebsiteButton => 'Перейти на сайт перевозчика';

  @override
  String get noTimelineYet => 'Пока нет хронологии';

  @override
  String get orderNotFound => 'Заказ не найден';

  @override
  String get invoiceUploadedSuccessfully => 'Счет успешно загружен';

  @override
  String uploadFailed(Object error) {
    return 'Загрузка не удалась: $error';
  }

  @override
  String get orderShipped => 'Заказ отправлен';

  @override
  String get sellerTaxNumberMissing => 'Налоговый номер продавца отсутствует';

  @override
  String get buyerIdentityNumberMissing => 'Идентификационный номер покупателя отсутствует';

  @override
  String get buyerTaxNumberMissing => 'Налоговый номер покупателя отсутствует';

  @override
  String get invoiceSystemMismatch => 'Несоответствие типа счета';

  @override
  String get invoiceStatusPendingUploadLabel => 'Ожидание счета';

  @override
  String get invoiceStatusUploadedValidLabel => 'Счет загружен';

  @override
  String get invoiceStatusUploadedWithIssuesLabel => 'Требуется проверка';

  @override
  String get invoiceStatusLateLabel => 'Просрочен';

  @override
  String get invoiceStatusApprovedLabel => 'Счет подтвержден';

  @override
  String get invoiceStatusRejectedLabel => 'Счет отклонен';

  @override
  String get eArsivLabel => 'e-Архив';

  @override
  String get eFaturaLabel => 'e-Счет';

  @override
  String get fileIsEmpty => 'Файл пуст';

  @override
  String get fileTooLarge => 'Файл слишком большой';

  @override
  String get upgradePageTitle => 'Обновление';

  @override
  String get upgradeHeroTitle => 'Находите лучшие совпадения быстрее 🐾';

  @override
  String get upgradeHeroSubtitle => 'Откройте премиум-функции, лучшую видимость, эксклюзивные предложения и бизнес-инструменты.';

  @override
  String get premiumPlanSubtitle => 'Для активных владельцев питомцев';

  @override
  String get premiumPlanFeatureUnlimitedChat => 'Безлимитный чат';

  @override
  String get premiumPlanFeatureAdvancedMatchingFilters => 'Расширенные фильтры подбора';

  @override
  String get premiumPlanFeatureExclusivePetOffers => 'Эксклюзивные предложения для питомцев';

  @override
  String get premiumPlanFeatureBetterProfileExperience => 'Лучший опыт профиля';

  @override
  String get goldPlanSubtitle => 'Для бизнесов в сфере питомцев и опытных пользователей';

  @override
  String get mostPopularLabel => 'САМЫЙ ПОПУЛЯРНЫЙ';

  @override
  String get goldPlanFeatureEverythingInPremium => 'Все, что есть в Premium';

  @override
  String get goldPlanFeatureBusinessRegistrationAccess => 'Доступ к регистрации бизнеса';

  @override
  String get goldPlanFeatureBoostedVisibility => 'Повышенная видимость';

  @override
  String get goldPlanFeatureBusinessDashboardAccess => 'Доступ к панели бизнеса';

  @override
  String get goldPlanFeaturePremiumChatAndOffers => 'Премиум-чат и предложения';

  @override
  String get storeNotReadyTryAgain => 'Магазин пока не готов. Попробуйте еще раз.';

  @override
  String get processingLabel => 'Обработка...';

  @override
  String get restoreRequestSent => 'Запрос на восстановление отправлен.';

  @override
  String get restorePurchases => 'Восстановить покупки';

  @override
  String get upgradePaymentTerms => 'Сумма будет списана с вашего аккаунта App Store при подтверждении. Подписки продлеваются автоматически, если не отменены как минимум за 24 часа до конца текущего периода.';

  @override
  String get autoRenewableMonthlySubscription => 'Ежемесячная подписка с автопродлением';

  @override
  String get securePaymentNotice => 'Безопасная оплата • Можно отменить в любое время • Планами управляет App Store';

  @override
  String continueWithPlan(Object plan) {
    return 'Продолжить с $plan';
  }

  @override
  String get loadingLabel => 'Загрузка...';

  @override
  String get privacyPolicyLabel => 'Политика конфиденциальности';

  @override
  String get termsOfUseLabel => 'Условия использования';

  @override
  String adoptionRequestSubtitle(Object dogName) {
    return '• $dogName';
  }

  @override
  String get adoptionStepPersonalInfoTitle => '1️⃣ Личная информация';

  @override
  String get adoptionFullNameLabel => 'Имя и фамилия';

  @override
  String get adoptionFullNameHint => 'Введите имя и фамилию';

  @override
  String get adoptionEnterFullName => 'Введите имя и фамилию';

  @override
  String get genderLabel => 'Пол';

  @override
  String get adoptionSelectGender => 'Выберите пол';

  @override
  String get adoptionPhoneHint => 'например: +90 5xx xxx xxxx';

  @override
  String get adoptionEnterValidPhone => 'Введите действительный номер телефона';

  @override
  String get adoptionIncomeRangeLabel => 'Диапазон ежемесячного дохода';

  @override
  String get adoptionSelectIncomeRange => 'Выберите диапазон дохода';

  @override
  String get adoptionIncomeRange0_2000 => '0 - 2 000';

  @override
  String get adoptionIncomeRange2000_5000 => '2 000 - 5 000';

  @override
  String get adoptionIncomeRange5000_10000 => '5 000 - 10 000';

  @override
  String get adoptionIncomeRange10000Plus => '10 000+';

  @override
  String get adoptionStepHousingTitle => '2️⃣ Жилье';

  @override
  String get adoptionHousingTypeLabel => 'Тип жилья';

  @override
  String get adoptionHousingApartment => 'Квартира';

  @override
  String get adoptionHousingHouse => 'Дом';

  @override
  String get adoptionHousingVilla => 'Вилла';

  @override
  String get adoptionOwnershipLabel => 'Собственное / Аренда';

  @override
  String get adoptionOwnershipOwned => 'Собственное';

  @override
  String get adoptionOwnershipRented => 'Аренда';

  @override
  String get adoptionLandlordPermissionRequired => 'Разрешение арендодателя (обязательно)';

  @override
  String get adoptionHasGarden => 'Есть сад';

  @override
  String get adoptionFenceHeightLabel => 'Высота забора (см)';

  @override
  String get adoptionFenceHeightHint => 'например: 120';

  @override
  String get adoptionEnterValidFenceHeight => 'Введите число от 1 до 400';

  @override
  String get adoptionStepExperienceTitle => '3️⃣ Опыт';

  @override
  String get adoptionYearsOfExperienceLabel => 'Годы опыта';

  @override
  String get adoptionYearsOfExperienceHint => '0..60';

  @override
  String get adoptionEnterYearsOfExperience => 'Введите 0..60';

  @override
  String get adoptionPreviousDogQuestion => 'Была ли у вас раньше собака? (Да/Нет)';

  @override
  String get adoptionPreviousDogReasonLabel => 'Причина, по которой предыдущая собака больше не с вами';

  @override
  String get adoptionPreviousDogReasonHint => 'Кратко объясните';

  @override
  String get adoptionExplainPreviousDog => 'Не менее 10 символов';

  @override
  String get adoptionOtherPetsAtHome => 'Другие питомцы дома';

  @override
  String get adoptionDescribeOtherPetsLabel => 'Опишите других питомцев';

  @override
  String get adoptionDescribeOtherPetsHint => 'например: 2 кошки, привиты';

  @override
  String get adoptionRequiredShort => 'Обязательно';

  @override
  String get adoptionDescribeOtherPetsRequired => 'Пожалуйста, опишите других питомцев';

  @override
  String get adoptionMotivationMessageLabel => 'Сообщение с мотивацией';

  @override
  String get adoptionMotivationMinLength => 'Мотивация должна содержать не менее 20 символов';

  @override
  String get adoptionStepFinancialCommitmentTitle => '4️⃣ Финансы и обязательства';

  @override
  String get adoptionCanAffordVetExpenses => 'Может оплачивать расходы на ветеринара?';

  @override
  String get adoptionEmergencySavingsAvailable => 'Есть ли резерв на экстренные случаи?';

  @override
  String get adoptionUploadsSectionTitle => '📷 Загрузки';

  @override
  String get adoptionHousePhotosRequiredTitle => 'Фото дома (обязательно)';

  @override
  String get adoptionUploadAtLeastOnePhoto => 'Загрузите хотя бы 1 фото';

  @override
  String adoptionUploadedCount(Object count) {
    return 'Загружено: $count';
  }

  @override
  String get adoptionUploadButton => 'Загрузить';

  @override
  String get adoptionClearButton => 'Очистить';

  @override
  String get adoptionIdPhotoRequiredTitle => 'Фото удостоверения (обязательно)';

  @override
  String get adoptionNotUploaded => 'Не загружено';

  @override
  String get adoptionUploaded => 'Загружено';

  @override
  String get adoptionReplaceButton => 'Заменить';

  @override
  String get adoptionRemoveButton => 'Удалить';

  @override
  String get adoptionProofOfIncomeOptionalTitle => 'Подтверждение дохода (необязательно)';

  @override
  String get adoptionOptionalLabel => 'Необязательно';

  @override
  String get adoptionAgreeContractRequiredLabel => 'Я согласен(на) подписать договор усыновления (обязательно)';

  @override
  String get adoptionAgreeContractRequired => 'Вы должны согласиться с договором усыновления';

  @override
  String get adoptionUploadIdPhoto => 'Пожалуйста, загрузите фото удостоверения';

  @override
  String get adoptionNextButton => 'Далее';

  @override
  String smartPriceSuggestedRangeLabel(Object currency, Object max, Object min) {
    return 'Рекомендуемый диапазон: $min - $max $currency';
  }

  @override
  String smartPriceSuggestedPriceLabel(Object currency, Object price) {
    return 'Рекомендуемая цена: $price $currency';
  }

  @override
  String get bestPriceStrategyLabel => 'Лучшая цена';

  @override
  String get aggressiveLowStrategyLabel => 'Агрессивно низкая';

  @override
  String get competitiveStrategyLabel => 'Конкурентная';

  @override
  String get slightlyHighStrategyLabel => 'Немного высокая';

  @override
  String get tooExpensiveStrategyLabel => 'Слишком дорого';

  @override
  String get manualPricingLabel => 'Ручное ценообразование';

  @override
  String get bestPricePositionLabel => 'Лучшая цена 🏆';

  @override
  String get aggressiveLowPositionLabel => 'Агрессивно низкая ⚡';

  @override
  String get competitivePositionLabel => 'Конкурентная ✅';

  @override
  String get slightlyHighPositionLabel => 'Немного высокая 📈';

  @override
  String get tooExpensivePositionLabel => 'Слишком дорого ⚠️';

  @override
  String get marketSourceAggregateLabel => 'Агрегированные данные';

  @override
  String get marketSourceFallbackProductsLabel => 'Резервные товары';

  @override
  String get marketSourceNoneLabel => 'Нет рыночных данных';

  @override
  String get marketSourceInvalidPricesLabel => 'Некорректные цены';

  @override
  String get marketSourceErrorLabel => 'Ошибка';

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
  String get categoryFood => 'Корм';

  @override
  String get categoryAccessories => 'Аксессуары';

  @override
  String get categoryHealth => 'Здоровье';

  @override
  String get categoryToys => 'Игрушки';

  @override
  String get subCategoryDryFood => 'Сухой корм';

  @override
  String get subCategoryWetFood => 'Влажный корм';

  @override
  String get subCategoryTreats => 'Лакомства';

  @override
  String get subCategoryCollar => 'Ошейник';

  @override
  String get subCategoryLeash => 'Поводок';

  @override
  String get subCategoryClothing => 'Одежда';

  @override
  String get subCategoryVitamins => 'Витамины';

  @override
  String get subCategoryMedicine => 'Лекарство';

  @override
  String get subCategoryChewToy => 'Жевательная игрушка';

  @override
  String get subCategoryInteractive => 'Интерактивная игрушка';

  @override
  String get productAlreadyExistsTitle => 'Товар уже существует';

  @override
  String get productAlreadyExistsDescription => 'Этот товар уже существует. Открывается редактор товара.';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get productNameMustBeAtLeast4Chars => 'Название товара должно содержать не менее 4 символов';

  @override
  String get invalidBarcode => 'Недействительный штрихкод';

  @override
  String get invalidSku => 'Недействительный SKU';

  @override
  String get invalidWholesalePrice => 'Недействительная оптовая цена';

  @override
  String get wholesaleMinQuantityMustBeAtLeast2 => 'Минимальное оптовое количество должно быть не менее 2';

  @override
  String get kdvRateIsRequired => 'Выберите ставку НДС';

  @override
  String get invalidPrice => 'Недействительная цена';

  @override
  String get invalidDiscountPrice => 'Недействительная цена со скидкой';

  @override
  String get discountMustBeLowerThanOriginalPrice => 'Цена со скидкой должна быть ниже исходной цены';

  @override
  String get wholesalePriceMustBeLowerThanRetailPrice => 'Оптовая цена должна быть ниже розничной';

  @override
  String get invalidStock => 'Недействительный остаток';

  @override
  String get stockMustBeAtLeastWholesaleMinQuantity => 'Остаток должен быть не меньше минимального оптового количества';

  @override
  String get inventoryStockFieldLabel => 'Остаток';

  @override
  String get invalidLowStockAlert => 'Недействительное предупреждение о низком остатке';

  @override
  String get addAtLeast1Media => 'Добавьте хотя бы 1 медиафайл';

  @override
  String get descriptionMustBeAtLeast10Characters => 'Описание должно содержать не менее 10 символов';

  @override
  String get selectCategory => 'Выберите категорию';

  @override
  String get weightOrDesiIsRequired => 'Требуется вес или desi';

  @override
  String get lengthIsRequired => 'Требуется длина';

  @override
  String get widthIsRequired => 'Требуется ширина';

  @override
  String get heightIsRequired => 'Требуется высота';

  @override
  String get invalidDesiValue => 'Недействительное значение desi';

  @override
  String get fixedShippingFeeIsRequired => 'Требуется фиксированная стоимость доставки';

  @override
  String get invalidShippingFee => 'Недействительная стоимость доставки';

  @override
  String get freeShippingThresholdIsRequired => 'Требуется порог бесплатной доставки';

  @override
  String get invalidPreparationTime => 'Недействительное время подготовки';

  @override
  String get invalidMaxDeliveryDays => 'Недействительное максимальное время доставки';

  @override
  String get selectAtLeast1CargoCarrier => 'Выберите хотя бы 1 перевозчика';

  @override
  String get returnWindowCannotBeLessThan14Days => 'Срок возврата не может быть меньше 14 дней';

  @override
  String get returnCarrierIsRequired => 'Требуется перевозчик возврата';

  @override
  String get shippingPayerMismatch => 'Несоответствие плательщика доставки';

  @override
  String get productSavedStatus => 'Товар сохранён ✅';

  @override
  String get scanFailed => 'Сканирование не удалось';

  @override
  String estimatedPriceLabel(Object currency, Object price) {
    return 'Примерная цена: $price $currency';
  }

  @override
  String get loadedFromGlobalApi => 'Загружено из глобального API';

  @override
  String productFallbackName(Object short) {
    return 'Товар $short';
  }

  @override
  String fallbackEstimateLabel(Object currency, Object price) {
    return 'Резервная оценка: $price $currency';
  }

  @override
  String offlineEstimateLabel(Object currency, Object price) {
    return 'Оценка офлайн: $price $currency';
  }

  @override
  String errorEstimateLabel(Object currency, Object price) {
    return 'Оценка при ошибке: $price $currency';
  }

  @override
  String smartDescriptionDefault(Object brand, Object name) {
    return '$name от $brand — надежный выбор для владельцев питомцев.';
  }

  @override
  String get trustedBrand => 'Надёжный бренд';

  @override
  String get productDetectedStatus => 'Товар обнаружен';

  @override
  String get noProductFoundAnywhere => 'Товар нигде не найден';

  @override
  String get enterProductNameFirst => 'Сначала введите название товара';

  @override
  String smartDescriptionFood(Object brand, Object name, Object subCategory) {
    return '$name от $brand — практичный выбор для питомцев. Он относится к категории $subCategory и подходит для ежедневного использования.';
  }

  @override
  String smartDescriptionAccessories(Object brand, Object name, Object subCategory) {
    return '$name от $brand — полезный аксессуар в категории $subCategory.';
  }

  @override
  String smartDescriptionHealth(Object brand, Object name, Object subCategory) {
    return '$name от $brand создан для здоровья и благополучия питомцев в категории $subCategory.';
  }

  @override
  String smartDescriptionToys(Object brand, Object name, Object subCategory) {
    return '$name от $brand — увлекательная игрушка из категории $subCategory.';
  }

  @override
  String get descriptionSuggestionAdded => 'Предложение описания добавлено';

  @override
  String get noPricingDataYet => 'Пока нет данных о ценах';

  @override
  String get smartPriceSuggestionTitle => 'Умное предложение цены';

  @override
  String get waitingForPricingData => 'Ожидание данных о ценах...';

  @override
  String get tapToApplySuggestedPrice => 'Нажмите, чтобы применить рекомендованную цену';

  @override
  String get smartPricingEngineTitle => 'Умный механизм ценообразования';

  @override
  String get modeLabel => 'Режим';

  @override
  String get noMarketDataLabel => 'Нет рыночных данных';

  @override
  String get usingSmartEstimationLabel => 'Используется умная оценка 🧠';

  @override
  String get marketIntelligenceTitle => 'Аналитика рынка';

  @override
  String get avgPriceLabel => 'Средняя цена';

  @override
  String get medianPriceLabel => 'Медианная цена';

  @override
  String get sellerCountLabel => 'Количество продавцов';

  @override
  String get bestPriceLabel => 'Лучшая цена';

  @override
  String get highestPriceLabel => 'Самая высокая цена';

  @override
  String get yourGapVsMarketLabel => 'Ваш разрыв с рынком';

  @override
  String get positionLabel => 'Позиция';

  @override
  String get profitMarginLabel => 'Маржа прибыли';

  @override
  String get sourceLabel => 'Источник';

  @override
  String get searchingProductStatus => 'Поиск товара...';

  @override
  String get productAlreadyExistsOpeningEditStatus => 'Товар существует, открывается редактор...';

  @override
  String get fetchingProductDataStatus => 'Получение данных о товаре...';

  @override
  String get analyzingMarketStatus => 'Анализ рынка...';

  @override
  String get marketAvgLabel => 'Средняя цена';

  @override
  String get marketMedianLabel => 'Медианная цена';

  @override
  String get marketSellersLabel => 'Количество продавцов';

  @override
  String emergencyFallbackLabel(Object currency, Object price) {
    return 'Экстренная оценка: $price $currency';
  }

  @override
  String get productReadyStatus => 'Товар готов ✅';

  @override
  String get failedToLoadProductStatus => 'Не удалось загрузить товар';

  @override
  String get barcodeLookupFailed => 'Не удалось выполнить поиск по штрихкоду';

  @override
  String get editProductTitle => 'Редактировать товар';

  @override
  String get addProductTitle => 'Добавить товар';

  @override
  String get tapToReplaceOrAddMedia => 'Нажмите, чтобы заменить или добавить медиа';

  @override
  String get tapToAddMedia => 'Нажмите, чтобы добавить медиа';

  @override
  String get basicInfoSectionTitle => 'Основная информация';

  @override
  String get productNameMinCharsLabel => 'Название товара *';

  @override
  String get brandLabel => 'Бренд';

  @override
  String get barcodeFieldLabel => 'Штрихкод';

  @override
  String get enterBarcodeHint => 'Введите или отсканируйте штрихкод';

  @override
  String get noBarcodeSkuHint => 'Штрихкод необязателен. SKU будет создан автоматически, если поле пусто.';

  @override
  String get scanButtonLabel => 'Сканировать';

  @override
  String get skuCodeLabel => 'Код SKU';

  @override
  String get autoGeneratedSkuHint => 'Будет создан автоматически, если поле пусто';

  @override
  String get shippingAndDeliverySectionTitle => 'Доставка и отправка';

  @override
  String get thisProductHasADiscount => 'У этого товара есть скидка';

  @override
  String get originalPriceLabel => 'Исходная цена';

  @override
  String get priceLabel => 'Цена';

  @override
  String get appointmentDetailTitle => 'Детали записи';

  @override
  String get appointmentNotFound => 'Запись не найдена';

  @override
  String get petLabel => 'Питомец';

  @override
  String get statusLabel => 'Статус';

  @override
  String get paymentLabel => 'Оплата';

  @override
  String get goToPaymentButton => 'Перейти к оплате';

  @override
  String get markedAsCompletedSnack => 'Отмечено как выполненное';

  @override
  String get markAsCompletedButton => 'Отметить как выполненное';

  @override
  String get wholesalePriceLabel => 'Оптовая цена';

  @override
  String get minimumQuantityForWholesaleLabel => 'Минимальное количество для опта';

  @override
  String get wholesaleAppliesHint => 'Оптовая скидка применяется с этого количества';

  @override
  String get visibleOnlyToBusinessAccountsHint => 'Видно только бизнес-аккаунтам';

  @override
  String get usersWillSeeDiscountHint => 'Пользователи увидят бейдж скидки';

  @override
  String get discountPriceLabel => 'Цена со скидкой';

  @override
  String get kdvLabel => 'НДС';

  @override
  String get lengthLabel => 'Длина';

  @override
  String get widthLabel => 'Ширина';

  @override
  String get heightLabel => 'Высота';

  @override
  String calculatedDesiLabel(Object value) {
    return 'Рассчитанный desi: $value';
  }

  @override
  String get manualDesiOverrideOptionalLabel => 'Ручной desi (необязательно)';

  @override
  String get shippingModeLabel => 'Режим доставки';

  @override
  String get carrierCalculatedLabel => 'Рассчитывается перевозчиком';

  @override
  String get fixedShippingFeeLabel => 'Фиксированная стоимость доставки';

  @override
  String get sellerPaysShippingLabel => 'Доставку оплачивает продавец';

  @override
  String get enableFreeShippingCampaignLabel => 'Включить кампанию бесплатной доставки';

  @override
  String get freeShippingThresholdLabel => 'Порог бесплатной доставки';

  @override
  String get preparationTimeDaysLabel => 'Время подготовки (дней)';

  @override
  String get maxDeliveryTimeDaysLabel => 'Максимальное время доставки (дней)';

  @override
  String get cargoCompaniesTitle => 'Транспортные компании';

  @override
  String get allowReturnsLabel => 'Разрешить возвраты';

  @override
  String get returnWindowDaysLabel => 'Срок возврата (дней)';

  @override
  String get returnShippingPayerLabel => 'Плательщик возвратной доставки';

  @override
  String get sellerOptionLabel => 'Продавец';

  @override
  String get buyerOptionLabel => 'Покупатель';

  @override
  String get sellerContractedCarrierOnlyLabel => 'Только если перевозчик по договору';

  @override
  String get inventoryTitle => 'Запасы';

  @override
  String get lowStockAlertLabel => 'Предупреждение о низком остатке';

  @override
  String get mainCategoryLabel => 'Основная категория';

  @override
  String get subCategoryLabel => 'Подкатегория';

  @override
  String get generatingLabel => 'Создание...';

  @override
  String get suggestLabel => 'Предложить';

  @override
  String get updateProductTitle => 'Обновить товар';

  @override
  String get sellInstantlyButtonLabel => 'Продать сразу';

  @override
  String get shippingEstimateTitle => 'Оценка доставки';

  @override
  String desiLabel(Object value) {
    return 'Desi: $value';
  }

  @override
  String billableLabel(Object value) {
    return 'К оплате: $value';
  }

  @override
  String basePriceLabel(Object currency, Object value) {
    return 'База: $value $currency';
  }

  @override
  String extraLabel(Object currency, Object value) {
    return 'Дополнительно: $value $currency';
  }

  @override
  String totalPriceLabel(Object currency, Object value) {
    return 'Итого: $value $currency';
  }

  @override
  String get returnRequestsTitle => 'Запросы на возврат';

  @override
  String get returnAvailableAfterDeliveryMessage => 'Возврат доступен после доставки.';

  @override
  String get noReturnsYet => 'Пока нет запросов на возврат';

  @override
  String get requestReturnButton => 'Запросить возврат';

  @override
  String get returnRequestSubmitted => 'Запрос на возврат отправлен';

  @override
  String get selectReturnReasonLabel => 'Выберите причину';

  @override
  String get returnDescriptionHint => 'Опишите проблему...';

  @override
  String get selectReturnItemsLabel => 'Выберите товары для возврата';

  @override
  String returnRequestLabel(Object id) {
    return 'Возврат #$id';
  }

  @override
  String get reasonLabel => 'Причина';

  @override
  String get refundAmountLabel => 'Сумма возврата';

  @override
  String get returnAmountLabel => 'Примерная сумма возврата';

  @override
  String get shippingResponsibilityLabel => 'Доставка возврата';

  @override
  String get refundTypeLabel => 'Тип возврата';

  @override
  String get returnTimelineTitle => 'Сроки возврата';

  @override
  String get refundResultLabel => 'Результат возврата';

  @override
  String get returnActionCompleted => 'Возврат обновлён';

  @override
  String get approveReturnButton => 'Одобрить';

  @override
  String get rejectReturnButton => 'Отклонить';

  @override
  String get cancelReturnButton => 'Отменить возврат';

  @override
  String get markShippedBackButton => 'Отметить как отправлено обратно';

  @override
  String get markReceivedButton => 'Отметить как получено';

  @override
  String get triggerRefundButton => 'Запустить возврат средств';

  @override
  String get returnStatusPending => 'В ожидании';

  @override
  String get returnStatusApproved => 'Одобрено';

  @override
  String get returnStatusRejected => 'Отклонено';

  @override
  String get returnStatusShippedBack => 'Отправлено обратно';

  @override
  String get returnStatusReceivedBySeller => 'Получено продавцом';

  @override
  String get returnStatusRefundPending => 'Возврат в ожидании';

  @override
  String get returnStatusRefundFailed => 'Возврат не удался';

  @override
  String get returnStatusRefunded => 'Возвращено';

  @override
  String get returnStatusCancelled => 'Отменено';

  @override
  String get returnReasonDamaged => 'Повреждено';

  @override
  String get returnReasonWrongProduct => 'Неверный товар';

  @override
  String get returnReasonMissingParts => 'Не хватает деталей';

  @override
  String get returnReasonNotAsDescribed => 'Не соответствует описанию';

  @override
  String get returnReasonChangedMind => 'Передумал(а)';

  @override
  String get returnReasonOther => 'Другое';

  @override
  String get refundTypeFullLabel => 'Полный возврат';

  @override
  String get refundTypePartialLabel => 'Частичный возврат';

  @override
  String get refundTypeShippingLabel => 'Возврат доставки';

  @override
  String get shippingResponsibilitySellerLabel => 'Продавец';

  @override
  String get shippingResponsibilityBuyerLabel => 'Покупатель';

  @override
  String get shippingResponsibilityContractCarrierLabel => 'Только если перевозчик по договору';

  @override
  String get returnCarrierLabel => 'Перевозчик возврата';

  @override
  String get returnImagesAdded => 'Изображения добавлены';

  @override
  String get refundRejectedStatusLabel => 'Возврат отклонён';
}
