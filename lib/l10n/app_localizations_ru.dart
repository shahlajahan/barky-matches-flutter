// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get userNotLoggedIn => 'Пользователь не вошёл в систему. Перенаправление на страницу входа...';

  @override
  String errorLoadingUserInfo(Object error) {
    return 'Ошибка загрузки информации о пользователе: $error';
  }

  @override
  String errorLoadingDogs(Object error) {
    return 'Ошибка загрузки собак: $error';
  }

  @override
  String get usernameCannotBeEmpty => 'Имя пользователя не может быть пустым';

  @override
  String get profileUpdatedSuccessfully => 'Профиль успешно обновлён';

  @override
  String errorUpdatingDog(Object error) {
    return 'Ошибка обновления данных собаки: $error';
  }

  @override
  String errorDeletingAccount(Object error) {
    return 'Ошибка удаления аккаунта: $error';
  }

  @override
  String get accountDeleted => 'Аккаунт удалён.';

  @override
  String errorDuringLogout(Object error) {
    return 'Ошибка при выходе: $error';
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
  String get checkoutPhoneHint => 'Номер в формате 5XXXXXXXXX';

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
  String get checkoutSmsOption => 'СМС';

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
  String get okButton => 'Хорошо';

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
  String get instagramTitle => 'Страница в Instagram';

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
  String get myProfile => 'Мой профиль';

  @override
  String get userProfile => 'Профиль пользователя';

  @override
  String get profileInformation => 'Информация профиля';

  @override
  String get myDogs => 'Мои питомцы';

  @override
  String get dogsAvailableForAdoption => 'Собаки, доступные для пристройства';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get usernameLabel => 'Имя пользователя';

  @override
  String get emailLabel => 'Электронная почта';

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get enterPhoneNumberOptional => 'Введите номер телефона (необязательно)';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountConfirmation => 'Вы уверены, что хотите удалить аккаунт? Это действие нельзя отменить.';

  @override
  String get updateProfile => 'Обновить профиль';

  @override
  String get editProfileTooltip => 'Редактировать профиль';

  @override
  String get deleteAccountTooltip => 'Удалить аккаунт';

  @override
  String get logoutTooltip => 'Выйти';

  @override
  String get noDogsAvailableForAdoption => 'Нет собак, доступных для усыновления';

  @override
  String get unknownUser => 'Неизвестный пользователь';

  @override
  String get notProvided => 'Не указано';

  @override
  String get noDogsAddedYet => 'Собаки пока не добавлены.';

  @override
  String get appTitle => 'Приложение PetSupo';

  @override
  String get loadingUserData => 'Загрузка данных пользователя...';

  @override
  String get welcomeToPetSopu => 'Добро пожаловать в PetSopu!';

  @override
  String get welcomeTo => 'Добро пожаловать';

  @override
  String get petSopu => 'Приложение PetSopu';

  @override
  String welcomeBack(Object username) {
    return 'С возвращением, $username!';
  }

  @override
  String helloMessage(Object username) {
    return 'Здравствуйте, $username!';
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
  String get phoneMinDigits => 'Номер телефона должен содержать не менее 10 цифр';

  @override
  String get passwordRequired => 'Пожалуйста, введите пароль';

  @override
  String get passwordValidation => 'Минимум 8 символов: буква и цифра.';

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
  String get authWelcomeBackSubtitle => 'С возвращением в PetSupo';

  @override
  String get authCreateAccountSubtitle => 'Создайте аккаунт PetSupo';

  @override
  String get sessionExpiredPleaseSignInAgain => 'Ваша сессия истекла. Пожалуйста, войдите снова.';

  @override
  String get signInToAccessPlaymate => 'Пожалуйста, войдите, чтобы открыть доступ к Плеймейт';

  @override
  String get findPlaymates => 'Найти друзей';

  @override
  String get signInToFindFriends => 'Найти друзей для вашего питомца';

  @override
  String get addYourDog => 'Добавьте свою собаку';

  @override
  String get addYourPetTitle => 'Добавьте питомца';

  @override
  String get nameLabel => 'Имя *';

  @override
  String get pleaseEnterDogName => 'Введите имя вашей собаки';

  @override
  String get selectBreedHint => 'Выберите породу';

  @override
  String get pleaseSelectBreed => 'Выберите породу';

  @override
  String get ageLabel => 'Возраст *';

  @override
  String get ageUnit => 'Ед.';

  @override
  String get pleaseEnterDogAge => 'Введите возраст вашей собаки';

  @override
  String get pleaseEnterValidAge => 'Введите корректный возраст';

  @override
  String get selectGenderHint => 'Выберите пол';

  @override
  String get pleaseSelectGender => 'Выберите пол';

  @override
  String get selectHealthStatusHint => 'Выберите состояние здоровья';

  @override
  String get pleaseSelectHealthStatus => 'Выберите состояние здоровья';

  @override
  String get neuteredLabel => 'Стерилизация *';

  @override
  String get yes => 'Да';

  @override
  String get no => 'Нет';

  @override
  String get pleaseSpecifyNeutered => 'Укажите, стерилизована ли собака';

  @override
  String get traitsLabel => 'Характеристики *';

  @override
  String get pleaseSelectAtLeastOneTrait => 'Выберите хотя бы одну черту характера';

  @override
  String get selectOwnerGenderHint => 'Пол владельца';

  @override
  String get pleaseSelectOwnerGender => 'Укажите свой пол';

  @override
  String get uploadImagesLabel => 'Загрузить изображения';

  @override
  String get pickFromGallery => 'Выбрать из галереи';

  @override
  String get takePhoto => 'Сделать фото';

  @override
  String get availableForAdoption => 'Доступна для усыновления';

  @override
  String get descriptionLabel => 'Описание';

  @override
  String get descriptionPlaceholder => 'Введите описание...';

  @override
  String get colorLabel => 'Цвет';

  @override
  String get weightLabel => 'Вес (кг)';

  @override
  String get selectCollarTypeHint => 'Выберите тип ошейника';

  @override
  String get clothingColorLabel => 'Цвет одежды';

  @override
  String get lostLocationLabel => 'Место пропажи *';

  @override
  String get foundLocationLabel => 'Место обнаружения *';

  @override
  String get contactInfoLabel => 'Контактная информация *';

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
    return 'Собака с именем \"$name\" уже существует';
  }

  @override
  String get locationRequired => 'Для добавления собаки необходимо указать местоположение.';

  @override
  String errorUploadingImage(Object error) {
    return 'Ошибка загрузки изображения: $error';
  }

  @override
  String errorAddingDog(Object error) {
    return 'Ошибка добавления собаки: $error';
  }

  @override
  String get pleaseFillRequiredFields => 'Пожалуйста, правильно заполните все обязательные поля';

  @override
  String get addDogButton => 'Добавить питомца';

  @override
  String get dogDetailsAddTitle => 'Добавить собаку';

  @override
  String get dogDetailsEditTitle => 'Редактировать собаку';

  @override
  String get dogDetailsNameLabel => 'Имя';

  @override
  String get dogDetailsAgeLabel => 'Возраст';

  @override
  String get dogDetailsDescriptionLabel => 'Описание';

  @override
  String get dogDetailsGenderLabel => 'Пол:';

  @override
  String get dogDetailsHealthLabel => 'Состояние здоровья:';

  @override
  String get dogDetailsTraitsLabel => 'Черты характера:';

  @override
  String get dogDetailsOwnerGenderLabel => 'Пол владельца:';

  @override
  String get dogDetailsGenderMale => 'Самец';

  @override
  String get dogDetailsGenderFemale => 'Самка';

  @override
  String get dogDetailsHealthHealthy => 'Здорова';

  @override
  String get dogDetailsHealthNeedsCare => 'Требуется уход';

  @override
  String get dogDetailsHealthUnderTreatment => 'Проходит лечение';

  @override
  String get dogDetailsOwnerGenderPreferNotToSay => 'Предпочитаю не указывать';

  @override
  String get dogDetailsPickImageButton => 'Выбрать изображение';

  @override
  String get dogDetailsAddButton => 'Добавить собаку';

  @override
  String get dogDetailsUpdateButton => 'Обновить данные';

  @override
  String get dogDetailsNeuteredLabel => 'Стерилизована:';

  @override
  String get dogDetailsAdoptionLabel => 'Доступна для пристройства:';

  @override
  String get editDogPermissionDenied => 'У вас нет разрешения на редактирование этой собаки.';

  @override
  String get editDogEnterName => 'Введите имя собаки';

  @override
  String get editDogEnterValidAge => 'Введите корректный возраст';

  @override
  String get editDogOwnerGenderMale => 'Мужчина';

  @override
  String get editDogOwnerGenderFemale => 'Женщина';

  @override
  String get editDogOwnerGenderOther => 'Другое';

  @override
  String get findPlaymateTitle => 'Найти друга для игр';

  @override
  String get noDogsMatchFilters => 'Нет собак, соответствующих вашим фильтрам.';

  @override
  String get adjustFiltersSuggestion => 'Попробуйте изменить фильтры или увеличить расстояние.';

  @override
  String get anyGender => 'Любой';

  @override
  String distanceLabel(Object distance) {
    return 'Расстояние: $distance км';
  }

  @override
  String get resetFiltersButton => 'Сбросить фильтры';

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
  String get favoritesPageTitle => 'Избранные собаки';

  @override
  String get noFavoriteDogsYet => 'В избранном пока нет собак!';

  @override
  String get addFavoriteSuggestion => 'Вернитесь на главную страницу и добавьте собак в избранное.';

  @override
  String get removeFavoriteTooltip => 'Удалить из избранного';

  @override
  String get schedulePlaydate => 'Назначить встречу';

  @override
  String get selectDateAndTime => 'Выберите дату и время';

  @override
  String get pickDate => 'Выбрать дату';

  @override
  String get pickTime => 'Выбрать время';

  @override
  String get selectYourDogHint => 'Выберите свою собаку';

  @override
  String get selectFriendsDogHint => 'Выберите собаку друга';

  @override
  String get selectYourDog => 'Выберите свою собаку';

  @override
  String get selectFriendsDog => 'Выберите собаку друга';

  @override
  String get pleaseLoginToSchedulePlaydate => 'Войдите, чтобы назначить встречу';

  @override
  String get selectLocation => 'Выберите место';

  @override
  String get enterLocation => 'Введите местоположение (например, широта: 41.0103, долгота: 28.6724 или адрес)';

  @override
  String get pickOnMap => 'Выбрать на карте';

  @override
  String get quickLocations => 'Быстрый выбор мест';

  @override
  String get parkA => 'Парк A';

  @override
  String get parkB => 'Парк B';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get cancel => 'Отмена';

  @override
  String get pleaseSelectBothDogs => 'Выберите обеих собак';

  @override
  String get pleaseLoginToCreateRequest => 'Войдите, чтобы создать запрос';

  @override
  String get playdateRequestTitle => 'Запрос на встречу';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
    return 'Собака $requesterDog хочет поиграть с собакой $requestedDog!';
  }

  @override
  String playdateRequestNotificationBody(Object requesterDog, Object requestedDog) {
    return 'Собака $requesterDog хочет поиграть с собакой $requestedDog!';
  }

  @override
  String get requestCreatedSuccess => 'Запрос успешно создан';

  @override
  String errorCreatingRequest(Object error) {
    return 'Ошибка создания запроса: $error';
  }

  @override
  String playdateScheduled(Object dogName, Object dateTime, Object location) {
    return 'Встреча с собакой $dogName назначена на $dateTime, место: $location!';
  }

  @override
  String get newPlaydateRequestTitle => 'Новый запрос на встречу!';

  @override
  String newPlaydateRequestBody(Object requesterDog, Object requestedDog) {
    return 'Собака $requesterDog хочет поиграть с собакой $requestedDog!';
  }

  @override
  String removedFromFavorites(Object dogName) {
    return 'Собака $dogName удалена из избранного!';
  }

  @override
  String addedToFavorites(Object dogName) {
    return 'Собака $dogName добавлена в избранное!';
  }

  @override
  String errorTogglingFavorite(Object error) {
    return 'Ошибка изменения избранного: $error';
  }

  @override
  String chatWithOwner(Object dogName) {
    return 'Начать чат с владельцем собаки $dogName!';
  }

  @override
  String errorSchedulingPlaydate(Object error) {
    return 'Ошибка назначения встречи: $error';
  }

  @override
  String get viewEditDogDetails => 'Просмотр и редактирование данных собаки';

  @override
  String editNotAllowed(Object dogName) {
    return 'Нет разрешения на редактирование собаки $dogName, onDogUpdated пуст';
  }

  @override
  String editDialogOpen(Object dogName) {
    return 'Диалог редактирования уже открыт или собака $dogName уже редактируется';
  }

  @override
  String openingEditDialog(Object dogName) {
    return 'Открывается EditDogDialog для собаки $dogName';
  }

  @override
  String dogUpdatedInDialog(Object dogName) {
    return 'Данные собаки $dogName обновлены в диалоге';
  }

  @override
  String dialogPopped(Object dogName) {
    return 'Диалог для собаки $dogName успешно закрыт';
  }

  @override
  String updatedDogReturned(Object dogName) {
    return 'Из диалога возвращены обновлённые данные собаки $dogName';
  }

  @override
  String errorInShowDialog(Object dogName, Object error) {
    return 'Ошибка showDialog для собаки $dogName: $error';
  }

  @override
  String dialogClosed(Object isEditing, Object isDialogOpen) {
    return 'Диалог закрыт, isEditing: $isEditing, isDialogOpen: $isDialogOpen';
  }

  @override
  String widgetNotMounted(Object isDialogOpen) {
    return 'Виджет не смонтирован, isDialogOpen сброшен на: $isDialogOpen';
  }

  @override
  String removedDislike(Object dogName) {
    return 'Отметка «Не нравится» для собаки $dogName удалена!';
  }

  @override
  String addedDislike(Object dogName) {
    return 'Собака $dogName вам больше не нравится!';
  }

  @override
  String dislikeNotificationFailed(Object message) {
    return 'Не удалось отправить уведомление об отметке «Не нравится»: $message';
  }

  @override
  String ensureNotificationsEnabled(Object dogName) {
    return 'Убедитесь, что у владельца собаки $dogName включены уведомления.';
  }

  @override
  String failedToDislike(Object message) {
    return 'Не удалось поставить отметку «Не нравится»: $message';
  }

  @override
  String errorSendingDislike(Object error) {
    return 'Ошибка отправки уведомления об отметке «Не нравится»: $error';
  }

  @override
  String disposing(Object dogName) {
    return 'Освобождение ресурсов для собаки $dogName';
  }

  @override
  String resetIsDialogOpen(Object isDialogOpen) {
    return 'Сброс isDialogOpen при отмене: $isDialogOpen';
  }

  @override
  String get notifications => 'Уведомления';

  @override
  String get playdateRequests => 'Запросы на встречи';

  @override
  String get noNotifications => 'Уведомлений пока нет.';

  @override
  String get noPlaydateRequests => 'Запросов на встречу пока нет.';

  @override
  String get accept => 'Принять';

  @override
  String get reject => 'Отклонить';

  @override
  String get status => 'Статус';

  @override
  String get delete => 'Удалить';

  @override
  String get rejectConfirmation => 'Подтверждение отклонения';

  @override
  String get areYouSure => 'Вы уверены, что хотите отклонить этот запрос?';

  @override
  String get notificationDeleted => 'Уведомление удалено';

  @override
  String errorDeletingNotification(Object error) {
    return 'Ошибка удаления уведомления: $error';
  }

  @override
  String get notificationsSection => 'Уведомления';

  @override
  String get playdateRequestsSection => 'Запросы на встречи';

  @override
  String get noTitle => 'Без заголовка';

  @override
  String get noBody => 'Нет текста';

  @override
  String get newLikeTitle => 'Новая отметка «Нравится»!';

  @override
  String newLikeBody(Object username, Object dogName) {
    return 'Пользователю $username понравилась ваша собака $dogName!';
  }

  @override
  String get playDateCanceledTitle => 'Запрос на встречу отменён';

  @override
  String playDateCanceledBody(Object dogName) {
    return 'Запрос на встречу с собакой $dogName отменён.';
  }

  @override
  String get playDateAcceptedTitle => 'Запрос на встречу принят!';

  @override
  String playDateAcceptedBodyRequester(Object dogName) {
    return 'Вы приняли запрос на встречу с собакой $dogName';
  }

  @override
  String playDateAcceptedBodyRequested(Object dogName, Object dateTime) {
    return 'Собака $dogName приняла ваш запрос на встречу с собакой $dogName на $dateTime';
  }

  @override
  String get playDateRejectedTitle => 'Запрос на встречу отклонён';

  @override
  String playDateRejectedBodyRequester(Object dogName) {
    return 'Вы отклонили запрос на встречу с собакой $dogName';
  }

  @override
  String playDateRejectedBodyRequested(Object dogName) {
    return 'Собака $dogName отклонила ваш запрос на встречу с собакой $dogName';
  }

  @override
  String errorLoadingNotifications(Object error) {
    return 'Ошибка обновления уведомлений: $error';
  }

  @override
  String errorInitializingOrLoadingRequests(Object error) {
    return 'Ошибка инициализации или загрузки запросов: $error';
  }

  @override
  String errorLoadingRequests(Object error) {
    return 'Ошибка загрузки запросов: $error';
  }

  @override
  String errorLoadingSpecificRequest(Object error) {
    return 'Ошибка загрузки выбранного запроса: $error';
  }

  @override
  String errorLoadingNotificationsStream(Object error) {
    return 'Ошибка загрузки потока уведомлений: $error';
  }

  @override
  String errorLoadingRequestsStream(Object error) {
    return 'Ошибка загрузки потока запросов: $error';
  }

  @override
  String errorUpdatingStatus(Object error) {
    return 'Ошибка обновления статуса: $error';
  }

  @override
  String errorUpdatingStatusUnexpected(Object error) {
    return 'Непредвиденная ошибка при обновлении статуса: $error';
  }

  @override
  String get pleaseLoginToRespond => 'Войдите, чтобы отвечать на запросы';

  @override
  String requestStatusUpdated(Object status) {
    return 'Статус запроса успешно изменён на «$status»';
  }

  @override
  String errorRespondingToRequest(Object error) {
    return 'Ошибка ответа на запрос: $error';
  }

  @override
  String errorRespondingToRequestUnexpected(Object error) {
    return 'Непредвиденная ошибка при ответе на запрос: $error';
  }

  @override
  String get pleaseLoginToAccept => 'Войдите, чтобы принимать запросы';

  @override
  String get requestAcceptedSuccess => 'Запрос принят и добавлен в список встреч.';

  @override
  String errorAcceptingRequest(Object error) {
    return 'Ошибка принятия запроса: $error';
  }

  @override
  String errorAcceptingRequestUnexpected(Object error) {
    return 'Непредвиденная ошибка при принятии запроса: $error';
  }

  @override
  String get pleaseLoginToReject => 'Войдите, чтобы отклонять запросы';

  @override
  String get requestRejectedSuccess => 'Запрос отклонён';

  @override
  String errorRejectingRequest(Object error) {
    return 'Ошибка отклонения запроса: $error';
  }

  @override
  String errorRejectingRequestUnexpected(Object error) {
    return 'Непредвиденная ошибка при отклонении запроса: $error';
  }

  @override
  String get failedToScheduleReminder => 'Не удалось запланировать напоминание. Проверьте разрешения.';

  @override
  String get scheduledLabel => 'Запланировано:';

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
  String get locationLabel => 'Местоположение:';

  @override
  String get unknownStatus => 'неизвестно';

  @override
  String get unknownTime => 'Время неизвестно';

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
  String get notScheduled => 'Не запланировано';

  @override
  String get upcomingPlaydateTitle => 'Предстоящая встреча';

  @override
  String upcomingPlaydateBodyRequester(Object dogName) {
    return 'Через 2 часа у вас встреча с собакой $dogName!';
  }

  @override
  String upcomingPlaydateBodyRequested(Object dogName) {
    return 'Через 2 часа у вас встреча с собакой $dogName!';
  }

  @override
  String get appFeatures => 'В нашем приложении вы можете:';

  @override
  String get appFeaturesMessage => 'В нашем приложении вы можете:';

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
  String get playmateBreedPremiumHint => 'Порода (PetSupo Partner)';

  @override
  String get playmateOwnerGenderPremiumHint => 'Пол владельца (Premium)';

  @override
  String get vetServices => 'Ветеринарные услуги';

  @override
  String get adoptionService => 'Пристройство';

  @override
  String get dogTrainingService => 'Дрессировка собак';

  @override
  String get dogParkService => 'Парк для собак';

  @override
  String get findFriendsService => 'Поиск друзей';

  @override
  String get getStarted => 'Начать';

  @override
  String get dogTraining => 'Дрессировка собак';

  @override
  String get dogPark => 'Парк для собак';

  @override
  String get findFriends => 'Найти друзей';

  @override
  String get dogTrainingComingSoon => 'Раздел дрессировки собак скоро откроется!';

  @override
  String get lostDogsComingSoon => 'Раздел потерянных собак скоро откроется!';

  @override
  String get petShopsComingSoon => 'Раздел зоомагазинов скоро откроется!';

  @override
  String get hospitalsComingSoon => 'Раздел клиник скоро откроется!';

  @override
  String get findFriendsComingSoon => 'Раздел поиска друзей скоро откроется!';

  @override
  String get menuTitle => 'Меню';

  @override
  String get homeMenuItem => 'Главная';

  @override
  String get myDogsMenuItem => 'Мои собаки';

  @override
  String get favoritesMenuItem => 'Избранное';

  @override
  String get adoptionCenterMenuItem => 'Центр пристройства';

  @override
  String get dogParkMenuItem => 'Парк для собак';

  @override
  String get reportLostDogMenuItem => 'Сообщить о потерянной собаке';

  @override
  String get lostDogsMenuItem => 'Потерянные собаки';

  @override
  String get reportFoundDogMenuItem => 'Сообщить о найденной собаке';

  @override
  String get foundDogsMenuItem => 'Найденные собаки';

  @override
  String get petShopsMenuItem => 'Зоомагазины';

  @override
  String get hospitalsMenuItem => 'Клиники';

  @override
  String get logoutMenuItem => 'Выйти';

  @override
  String get filterDogsMenuItem => 'Фильтр собак';

  @override
  String get homeNavItem => 'Главная';

  @override
  String get favoritesNavItem => 'Избранное';

  @override
  String get visitVetNavItem => 'Ветеринар';

  @override
  String get playdateNavItem => 'Встречи';

  @override
  String get profileNavItem => 'Профиль';

  @override
  String get notificationsTooltip => 'Уведомления';

  @override
  String get chatTooltip => 'Чат';

  @override
  String get chatNotImplemented => 'Чат пока не реализован';

  @override
  String get dogParkTitle => 'Парки для собак';

  @override
  String dogParkDateLabel(Object date) {
    return 'Дата: $date';
  }

  @override
  String get dogParkLoadMarkers => 'Загрузить метки парков';

  @override
  String get dogParkMoveToMarkers => 'Перейти к меткам';

  @override
  String get dogParkPermissionDenied => 'Доступ к местоположению запрещён. Разрешите его в настройках.';

  @override
  String get dogParkBackgroundPermissionDenied => 'Доступ к местоположению в фоновом режиме запрещён. Некоторые функции могут быть ограничены.';

  @override
  String get dogParkLocationServicesDisabled => 'Службы геолокации отключены.';

  @override
  String get dogParkEnableLocationServices => 'Чтобы продолжить, включите службы геолокации.';

  @override
  String get dogParkPermissionDeniedPermanent => 'Доступ к местоположению запрещён навсегда.';

  @override
  String get dogParkPermissionsDenied => 'Доступ к местоположению запрещён навсегда. Разрешите его в настройках.';

  @override
  String dogParkLocationError(Object error) {
    return 'Ошибка определения местоположения: $error';
  }

  @override
  String get dogParkPermissionRequired => 'Для отображения ближайших парков для собак необходим доступ к местоположению.';

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
  String get dogParkBackgroundRecommended => 'Рекомендуется разрешить доступ к местоположению в фоновом режиме. Включите его в настройках.';

  @override
  String get dogParkSettingsAction => 'Настройки';

  @override
  String dogParkDistanceLabel(Object distance) {
    return 'Расстояние: $distance км';
  }

  @override
  String get dogViewTitle => 'Сведения о собаке';

  @override
  String get dogViewNameLabel => 'Имя:';

  @override
  String get dogViewBreedLabel => 'Порода:';

  @override
  String get dogViewAgeLabel => 'Возраст:';

  @override
  String get dogViewGenderLabel => 'Пол:';

  @override
  String get dogViewHealthLabel => 'Здоровье:';

  @override
  String get dogViewNeuteredLabel => 'Стерилизована:';

  @override
  String get dogViewDescriptionLabel => 'Описание:';

  @override
  String get dogViewTraitsLabel => 'Черты характера:';

  @override
  String get dogViewOwnerGenderLabel => 'Пол владельца:';

  @override
  String get dogViewAvailableLabel => 'Доступна для пристройства:';

  @override
  String get dogViewYes => 'Да';

  @override
  String get dogViewNo => 'Нет';

  @override
  String get dogViewLikeTooltip => 'Нравится';

  @override
  String get dogViewDislikeTooltip => 'Не нравится';

  @override
  String get dogViewAddFavoriteTooltip => 'Добавить в избранное';

  @override
  String get dogViewChatTooltip => 'Чат';

  @override
  String get dogViewScheduleDate => 'Назначить дату';

  @override
  String get dogViewAdoption => 'Пристройство';

  @override
  String get dogViewChatStarted => 'Чат начат!';

  @override
  String dogViewPlayDateScheduled(Object day, Object month, Object year, Object time) {
    return 'Встреча назначена на $day/$month/$year в $time!';
  }

  @override
  String get dogViewAdoptionRequest => 'Запрос на пристройство отправлен!';

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
  String get boostPrice29 => '29 ₺';

  @override
  String get boost3DaysTitle => 'Буст на 3 дня';

  @override
  String get boostBetterExposureSubtitle => 'Лучше подходит для активного поиска';

  @override
  String get boostPrice69 => '69 ₺';

  @override
  String get boost7DaysTitle => 'Буст на 7 дней';

  @override
  String get boostBestValueSubtitle => 'Лучшее соотношение цены и охвата';

  @override
  String get boostPrice129 => '129 ₺';

  @override
  String get boostActivated => 'Буст активирован 🚀';

  @override
  String boostFailed(Object error) {
    return 'Не удалось активировать буст: $error';
  }

  @override
  String get errorOpeningEdit => 'Ошибка открытия редактирования';

  @override
  String get boostBadge => 'ПРОДВИГАЕТСЯ';

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
  String get dogInfoTitle => 'Информация о собаке';

  @override
  String get dogInfoBreedLabel => 'Порода:';

  @override
  String get dogInfoAgeLabel => 'Возраст:';

  @override
  String get dogInfoGenderLabel => 'Пол:';

  @override
  String get dogInfoHealthLabel => 'Состояние здоровья:';

  @override
  String get dogInfoNeuteredLabel => 'Стерилизована:';

  @override
  String get dogInfoDescriptionLabel => 'Описание:';

  @override
  String get dogInfoTraitsLabel => 'Черты характера:';

  @override
  String get dogInfoOwnerGenderLabel => 'Пол владельца:';

  @override
  String get dogInfoYes => 'Да';

  @override
  String get dogInfoNo => 'Нет';

  @override
  String get dogInfoLikeTooltip => 'Нравится';

  @override
  String get dogInfoDislikeTooltip => 'Не нравится';

  @override
  String get dogInfoChatTooltip => 'Чат';

  @override
  String get dogInfoAddFavoriteTooltip => 'Добавить в избранное';

  @override
  String get dogInfoSchedulePlaydateTooltip => 'Назначить встречу';

  @override
  String dogInfoPlaydateScheduled(Object dogName) {
    return 'Встреча с собакой $dogName назначена!';
  }

  @override
  String dogInfoLiked(Object name) {
    return 'Вам понравилась собака $name';
  }

  @override
  String dogInfoDisliked(Object dogName) {
    return 'Собака $dogName вам больше не нравится!';
  }

  @override
  String dogInfoChatWithOwner(Object dogName) {
    return 'Начать чат с владельцем собаки $dogName!';
  }

  @override
  String dogInfoRemovedFavorite(Object dogName) {
    return 'Собака $dogName удалена из избранного!';
  }

  @override
  String dogInfoAddedFavorite(Object dogName) {
    return 'Собака $dogName добавлена в избранное!';
  }

  @override
  String get noDogsFound => 'Собаки не найдены';

  @override
  String get noDogsForUser => 'У этого пользователя не найдено собак.';

  @override
  String get dogsOfThisUser => 'Собаки этого пользователя';

  @override
  String get playDateStatus_pending => 'Ожидает ответа';

  @override
  String get playDateStatus_accepted => 'Принят';

  @override
  String get playDateStatus_rejected => 'Отклонён';

  @override
  String get locationServicesDisabled => 'Службы геолокации отключены. Используется местоположение по умолчанию.';

  @override
  String get locationPermissionRequired => 'Необходим доступ к местоположению. Используется местоположение по умолчанию.';

  @override
  String get locationPermissionPermanentlyDenied => 'Доступ к местоположению запрещён навсегда. Используется местоположение по умолчанию.';

  @override
  String errorGettingLocation(Object error) {
    return 'Ошибка определения местоположения: $error';
  }

  @override
  String errorLoadingData(Object error) {
    return 'Ошибка загрузки данных: $error';
  }

  @override
  String errorLoadingOffers(Object error) {
    return 'Ошибка загрузки предложений: $error';
  }

  @override
  String errorApplyingFilters(Object error) {
    return 'Ошибка применения фильтров: $error';
  }

  @override
  String get notificationChannelName => 'Важные уведомления';

  @override
  String get notificationChannelDescription => 'Этот канал используется для важных уведомлений.';

  @override
  String get openAppAction => 'Открыть приложение';

  @override
  String get dismissAction => 'Закрыть';

  @override
  String get adoptionCenter => 'Центр усыновления';

  @override
  String get traitEnergetic => 'Энергичная';

  @override
  String get traitPlayful => 'Игривая';

  @override
  String get traitCalm => 'Спокойная';

  @override
  String get traitLoyal => 'Преданная';

  @override
  String get traitFriendly => 'Дружелюбная';

  @override
  String get traitProtective => 'Защитница';

  @override
  String get traitIntelligent => 'Умная';

  @override
  String get traitAffectionate => 'Ласковая';

  @override
  String get traitCurious => 'Любопытная';

  @override
  String get traitIndependent => 'Независимая';

  @override
  String get traitShy => 'Застенчивая';

  @override
  String get traitTrained => 'Обученная';

  @override
  String get traitSocial => 'Общительная';

  @override
  String get traitGoodWithKids => 'Ладит с детьми';

  @override
  String get breedAfghanHound => 'Афганская борзая';

  @override
  String get breedAiredaleTerrier => 'Эрдельтерьер';

  @override
  String get breedAkita => 'Акита';

  @override
  String get breedAlaskanMalamute => 'Аляскинский маламут';

  @override
  String get breedAmericanBulldog => 'Американский бульдог';

  @override
  String get breedAmericanPitBullTerrier => 'Питбуль';

  @override
  String get breedAustralianCattleDog => 'Австралийская пастушья собака';

  @override
  String get breedAustralianShepherd => 'Австралийская овчарка';

  @override
  String get breedBassetHound => 'Бассет-хаунд';

  @override
  String get breedBeagle => 'Бигль';

  @override
  String get breedBelgianMalinois => 'Бельгийская овчарка малинуа';

  @override
  String get breedBerneseMountainDog => 'Бернский зенненхунд';

  @override
  String get breedBichonFrise => 'Бишон-фризе';

  @override
  String get breedBloodhound => 'Бладхаунд';

  @override
  String get breedBorderCollie => 'Бордер-колли';

  @override
  String get breedBostonTerrier => 'Бостон-терьер';

  @override
  String get breedBoxer => 'Боксёр';

  @override
  String get breedBulldog => 'Бульдог';

  @override
  String get breedBullmastiff => 'Бульмастиф';

  @override
  String get breedCairnTerrier => 'Керн-терьер';

  @override
  String get breedCaneCorso => 'Кане-корсо';

  @override
  String get breedCavalierKingCharlesSpaniel => 'Кавалер-кинг-чарльз-спаниель';

  @override
  String get breedChihuahua => 'Чихуахуа';

  @override
  String get breedChowChow => 'Чау-чау';

  @override
  String get breedCockerSpaniel => 'Кокер-спаниель';

  @override
  String get breedCollie => 'Колли';

  @override
  String get breedDachshund => 'Такса';

  @override
  String get breedDalmatian => 'Далматин';

  @override
  String get breedDobermanPinscher => 'Доберман';

  @override
  String get breedEnglishSpringerSpaniel => 'Английский спрингер-спаниель';

  @override
  String get breedFrenchBulldog => 'Французский бульдог';

  @override
  String get breedGermanShepherd => 'Немецкая овчарка';

  @override
  String get breedGermanShorthairedPointer => 'Курцхаар';

  @override
  String get breedGoldenRetriever => 'Золотистый ретривер';

  @override
  String get breedGreatDane => 'Немецкий дог';

  @override
  String get breedGreatPyrenees => 'Пиренейская горная собака';

  @override
  String get breedHavanese => 'Гаванский бишон';

  @override
  String get breedIrishSetter => 'Ирландский сеттер';

  @override
  String get breedIrishWolfhound => 'Ирландский волкодав';

  @override
  String get breedJackRussellTerrier => 'Джек-рассел-терьер';

  @override
  String get breedLabradorRetriever => 'Лабрадор-ретривер';

  @override
  String get breedLhasaApso => 'Лхаса апсо';

  @override
  String get breedMaltese => 'Мальтийская болонка';

  @override
  String get breedMastiff => 'Мастиф';

  @override
  String get breedMiniatureSchnauzer => 'Цвергшнауцер';

  @override
  String get breedNewfoundland => 'Ньюфаундленд';

  @override
  String get breedPapillon => 'Папильон';

  @override
  String get breedPekingese => 'Пекинес';

  @override
  String get breedPomeranian => 'Померанский шпиц';

  @override
  String get breedPoodle => 'Пудель';

  @override
  String get breedPug => 'Мопс';

  @override
  String get breedRottweiler => 'Ротвейлер';

  @override
  String get breedSaintBernard => 'Сенбернар';

  @override
  String get breedSamoyed => 'Самоед';

  @override
  String get breedShetlandSheepdog => 'Шелти';

  @override
  String get breedShihTzu => 'Ши-тцу';

  @override
  String get breedSiberianHusky => 'Сибирский хаски';

  @override
  String get breedStaffordshireBullTerrier => 'Стаффордширский бультерьер';

  @override
  String get breedVizsla => 'Венгерская выжла';

  @override
  String get breedWeimaraner => 'Веймаранер';

  @override
  String get breedWestHighlandWhiteTerrier => 'Вест-хайленд-уайт-терьер';

  @override
  String get breedYorkshireTerrier => 'Йоркширский терьер';

  @override
  String get settings => 'Настройки';

  @override
  String get playdateRequestsTitle => 'Запросы на встречи и уведомления';

  @override
  String get sendRequestButton => 'Отправить запрос';

  @override
  String get confirmLocation => 'Подтвердить местоположение';

  @override
  String get cancelButton => 'Отменить действие';

  @override
  String get editDogHealthHealthy => 'Здоров';

  @override
  String get editDogHealthNeedsCare => 'Нуждается в уходе';

  @override
  String get editDogHealthUnderTreatment => 'На лечении';

  @override
  String get noDogFoundForAccount => 'Для вашего аккаунта не найдена собака. Сначала добавьте собаку.';

  @override
  String get pleaseSelectYourDog => 'Выберите одну из своих собак';

  @override
  String get cannotScheduleWithOwnDog => 'Нельзя назначить встречу с собственной собакой.';

  @override
  String get cannotScheduleWithTempUser => 'Нельзя назначить встречу с временным пользователем.';

  @override
  String playdateRequestFor(Object dogName) {
    return 'Запрос на встречу для собаки $dogName';
  }

  @override
  String get forAdoption => 'Для пристройства';

  @override
  String get neutered => 'Стерилизована';

  @override
  String get notNeutered => 'Не стерилизована';

  @override
  String get pleaseSelectDogForPlaydate => 'Выберите одну из своих собак для встречи';

  @override
  String get years => 'лет';

  @override
  String get months => 'месяцев';

  @override
  String get breed => 'Порода';

  @override
  String get gender => 'Пол';

  @override
  String get healthStatus => 'Состояние здоровья';

  @override
  String get neuteredStatus => 'Статус стерилизации';

  @override
  String get description => 'Описание';

  @override
  String get traits => 'Черты характера';

  @override
  String get addToFavorites => 'Добавить в избранное';

  @override
  String get newFavoriteTitle => 'Новое добавление в избранное!';

  @override
  String newFavoriteBody(Object userName, Object dogName) {
    return 'Пользователь $userName добавил вашу собаку $dogName в избранное!';
  }

  @override
  String get likes => 'Отметки «Нравится»';

  @override
  String get removeDislike => 'Убрать отметку «Не нравится»';

  @override
  String get dislike => 'Не нравится';

  @override
  String errorTogglingDislike(Object error) {
    return 'Ошибка изменения отметки «Не нравится»: $error';
  }

  @override
  String get sending => 'Отправка...';

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
  String get chat => 'Чат';

  @override
  String get adoptDog => 'Взять собаку';

  @override
  String errorSendingDislikeNotification(Object error) {
    return 'Ошибка отправки уведомления об отметке «Не нравится»: $error';
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
  String get dogDetailsHealthSick => 'Требуется уход';

  @override
  String get dogDetailsHealthRecovering => 'Проходит лечение';

  @override
  String get noImageSelected => 'Изображение не выбрано.';

  @override
  String get unknownGender => 'Пол неизвестен';

  @override
  String get unknownBreed => 'Неизвестная порода';

  @override
  String get unknownTrait => 'Неизвестная черта';

  @override
  String get noTraits => 'Черты характера не указаны';

  @override
  String get simpleTestPageTitle => 'Простая тестовая страница';

  @override
  String get simpleTestPageMessage => 'Это простая тестовая страница.';

  @override
  String likedBy(Object likers) {
    return 'Понравилось: $likers';
  }

  @override
  String get locationNotAcquired => 'Не удалось определить местоположение. Повторите попытку.';

  @override
  String get retryLocation => 'Повторить определение местоположения';

  @override
  String get addLike => 'Поставить этой собаке отметку «Нравится»';

  @override
  String get removeLike => 'Убрать отметку «Нравится»';

  @override
  String addedLike(Object dogName) {
    return 'Вам понравилась собака $dogName!';
  }

  @override
  String removedLike(Object dogName) {
    return 'Вы убрали отметку «Нравится» у собаки $dogName!';
  }

  @override
  String errorTogglingLike(Object error) {
    return 'Ошибка изменения отметки «Нравится»: $error';
  }

  @override
  String get errorNoOwnerFound => 'Не удалось найти действительного владельца этой собаки';

  @override
  String get offerHotDeal => '🔥 Горячее предложение';

  @override
  String get offerPremiumBadge => 'Премиум';

  @override
  String get offerFallbackTitle => 'Специальное предложение для пользователей PetSupo';

  @override
  String get offerFallbackProvider => 'Партнёрский бренд';

  @override
  String get offerUnlock => 'Открыть';

  @override
  String get offerView => 'Посмотреть';

  @override
  String offerDiscountPercent(Object discount) {
    return 'СКИДКА $discount%';
  }

  @override
  String get offerPremiumRequiredTitle => 'Требуется премиум-подписка';

  @override
  String get offerPremiumRequiredMessage => 'Это предложение доступно только премиум-пользователям.';

  @override
  String get offerCancel => 'Отмена';

  @override
  String get offerUpgrade => 'Улучшить подписку';

  @override
  String get offerUnlockingMessage => 'Открываем ваше предложение...';

  @override
  String get offerChooseContinueTitle => 'Выберите, где продолжить';

  @override
  String get offerChooseContinueSubtitle => 'Выберите удобный способ связи по этому предложению.';

  @override
  String get offerOpenWebsite => 'Открыть сайт';

  @override
  String get offerInstagram => 'Открыть Instagram';

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
  String get goldLabel => 'PetSupo Partner';

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
  String get petShopDealName => 'Предложение Pet Shop A';

  @override
  String get petShopDealDesc => 'Скидка 15% на весь корм';

  @override
  String get groomyDealName => 'Студия Groomy';

  @override
  String get groomyDealDesc => 'Скидка 20% на груминг на этой неделе';

  @override
  String get vetDealName => 'Предложение VetPlus';

  @override
  String get vetDealDesc => 'Для участников PetSupo Partner: бесплатный осмотр';

  @override
  String get offerWhatsApp => 'Открыть WhatsApp';

  @override
  String offerCodeCopied(Object code) {
    return 'Код скопирован: $code';
  }

  @override
  String get offerOpenError => 'Не удалось открыть предложение';

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
  String get businessRegisterOk => 'Хорошо';

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
  String get businessRegisterGroomy => 'Груминг (Groomy)';

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
  String get userProfileUpgradeBusinessDescription => 'Перейдите на PetSupo Partner, чтобы зарегистрировать бизнес и начать получать клиентов.';

  @override
  String get userProfileUpgradeToGold => 'Перейти на PetSupo Partner';

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
  String get userProfileUpgradeToGoldToContinue => 'Перейдите на PetSupo Partner, чтобы продолжить';

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
    return 'Артикул: $sku';
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
    return 'Идентификационный номер: $identityNumber';
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
  String get goldPlanSubtitle => 'Для специалистов и компаний в сфере ухода за питомцами';

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
    return '• Собака: $dogName';
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
  String get adoptionYearsOfExperienceHint => 'От 0 до 60';

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
  String get discountRate1Label => 'Скидка 1%';

  @override
  String get discountRate10Label => 'Скидка 10%';

  @override
  String get discountRate20Label => 'Скидка 20%';

  @override
  String get carrierYurticiKargo => 'Доставка Yurtiçi Kargo';

  @override
  String get carrierArasKargo => 'Доставка Aras Kargo';

  @override
  String get carrierMngKargo => 'Доставка MNG Kargo';

  @override
  String get carrierSuratKargo => 'Доставка Sürat Kargo';

  @override
  String get carrierPttKargo => 'Доставка PTT Kargo';

  @override
  String get carrierHepsiJet => 'Доставка HepsiJET';

  @override
  String get carrierKolayGelsin => 'Доставка Kolay Gelsin';

  @override
  String get carrierUpsTurkiye => 'Доставка UPS Türkiye';

  @override
  String get carrierDhlExpress => 'Экспресс-доставка DHL';

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
    return 'Объёмный вес: $value';
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

  @override
  String get locationUpdatedSuccessfully => 'Местоположение успешно обновлено';

  @override
  String get centersLoadError => 'Не удалось загрузить центры';

  @override
  String get noAppointments => 'Записей на приём нет.';

  @override
  String get noAppointmentsFound => 'Записи на приём не найдены.';

  @override
  String appointmentsCount(Object count) {
    return '$count записей на приём';
  }

  @override
  String get any => 'Любой';

  @override
  String get search => 'Поиск...';

  @override
  String get accessDenied => 'Доступ запрещён';

  @override
  String get skip => 'Пропустить';

  @override
  String searchService(Object service) {
    return 'Поиск: $service...';
  }

  @override
  String get petHotels => 'Зоогостиницы';

  @override
  String noItemsYet(Object title) {
    return 'Пока нет: $title';
  }

  @override
  String get noSavedPostsYet => 'Пока нет сохранённых публикаций';

  @override
  String uploadedAt(Object date) {
    return 'Загружено: $date';
  }

  @override
  String get productDetails => 'Информация о товаре';

  @override
  String get servicesCouldNotBeLoaded => 'Не удалось загрузить услуги.';

  @override
  String get veterinaryClinics => 'Ветеринарные клиники';

  @override
  String get noVeterinaryClinicsFound => 'Ветеринарные клиники не найдены.';

  @override
  String get securePayment => 'Безопасная оплата';

  @override
  String get liveDriver => 'Водитель онлайн';

  @override
  String get driver => 'Водитель';

  @override
  String get myRides => 'Мои поездки';

  @override
  String get clientMessages => 'Сообщения клиентов';

  @override
  String get preVisitForm => 'Форма перед визитом';

  @override
  String get vetRevenueTitle => 'Выручка';

  @override
  String get vetRevenueDescription => 'Проверенные данные платежей и расчётов по завершённым ветеринарным операциям.';

  @override
  String get vetRevenueRange7Days => '7 дней';

  @override
  String get vetRevenueRange30Days => '30 дней';

  @override
  String get vetRevenueRange90Days => '90 дней';

  @override
  String get vetRevenueRangeThisYear => 'Этот год';

  @override
  String get vetRevenueRangeAllTime => 'Всё время';

  @override
  String get vetRevenueGrossRevenue => 'Валовая выручка';

  @override
  String get vetRevenuePetsupoCommission => 'Комиссия PetSupo';

  @override
  String get vetRevenueNetRevenue => 'Чистая выручка';

  @override
  String get vetRevenuePendingSettlement => 'Ожидает расчёта';

  @override
  String get vetRevenuePaidTransactions => 'Оплаченные операции';

  @override
  String get vetRevenuePendingPayments => 'Ожидающие платежи';

  @override
  String get vetRevenueRefunded => 'Возвращено';

  @override
  String get vetRevenueExpiredOpportunities => 'Истёкшие возможности';

  @override
  String get vetRevenueMissingFinancialData => 'Нет финансовых данных';

  @override
  String vetRevenueMissingFinancialWarning(int count) {
    return 'У $count оплаченных записей отсутствуют или повреждены финансовые данные; они исключены из итогов.';
  }

  @override
  String get vetRevenueMixedCurrencyWarning => 'Обнаружено несколько валют. Суммы показаны отдельно и не конвертируются и не складываются.';

  @override
  String get vetRevenueNoAppointmentsTitle => 'Записей пока нет';

  @override
  String get vetRevenueNoAppointmentsMessage => 'Аналитика появится после создания ветеринарных записей.';

  @override
  String get vetRevenueNoRangeTitle => 'В этом периоде нет данных';

  @override
  String get vetRevenueNoRangeMessage => 'Выберите больший диапазон дат для просмотра ранних операций.';

  @override
  String get vetRevenueLoadErrorTitle => 'Данные о выручке недоступны';

  @override
  String get vetRevenueLoadErrorMessage => 'Проверьте соединение и повторите попытку. Платёжные записи не изменены.';

  @override
  String get vetRevenueRetry => 'Повторить';

  @override
  String get vetRevenueTrendTitle => 'Динамика выручки';

  @override
  String get vetRevenueMixedCurrencyChartHidden => 'Общий график скрыт, поскольку период содержит несколько валют.';

  @override
  String get vetRevenueNoRecognizedRevenue => 'В этом периоде нет подтверждённой оплаченной выручки.';

  @override
  String get vetRevenueTopServices => 'Лучшие услуги по валовой выручке';

  @override
  String get vetRevenueTransactions => 'Операции';

  @override
  String get vetRevenueUncategorized => 'Без категории';

  @override
  String get vetRevenueSearchHint => 'Поиск клиента, питомца, услуги или операции';

  @override
  String get vetRevenueAllPayments => 'Все платежи';

  @override
  String get vetRevenuePaid => 'Оплачено';

  @override
  String get vetRevenuePending => 'Ожидается';

  @override
  String get vetRevenueExpired => 'Истёк';

  @override
  String get vetRevenueMissingFinancial => 'Нет финансовых данных';

  @override
  String get vetRevenueSortDate => 'Сортировать по дате';

  @override
  String get vetRevenueSortDirection => 'Изменить направление сортировки';

  @override
  String get vetRevenueDate => 'Дата';

  @override
  String get vetRevenueCustomer => 'Клиент';

  @override
  String get vetRevenuePet => 'Питомец';

  @override
  String get vetRevenueService => 'Услуга';

  @override
  String get vetRevenueGross => 'Валовая';

  @override
  String get vetRevenueCommission => 'Комиссия';

  @override
  String get vetRevenueNet => 'Чистая';

  @override
  String get vetRevenuePayment => 'Платёж';

  @override
  String get vetRevenueSettlement => 'Расчёт';

  @override
  String get vetRevenueInvoice => 'Счёт';

  @override
  String get vetRevenueTransactionReference => 'Ссылка операции';

  @override
  String get vetRevenueNoMatchingTransactions => 'Нет операций, соответствующих поиску и фильтру.';

  @override
  String vetRevenuePageOf(int page, int total) {
    return 'Страница $page из $total';
  }

  @override
  String get vetWebOverviewSubtitle => 'Обзор работы и показателей клиники';

  @override
  String get vetWebAppointmentsSubtitle => 'Просмотр и управление ветеринарными записями';

  @override
  String get vetWebRevenueSubtitle => 'Проверенная аналитика платежей, комиссии и расчётов';

  @override
  String get vetWebVeterinaryLabel => 'Ветеринария';

  @override
  String get petShopsTitle => 'Зоомагазины';

  @override
  String get searchPetShopsHint => 'Поиск зоомагазинов';

  @override
  String get noPetShopsFound => 'Зоомагазины не найдены';

  @override
  String get noPetShopsFoundDescription => 'Попробуйте другой поиск или зайдите позже.';

  @override
  String get loadingPetShops => 'Ищем зоомагазины рядом с вами…';

  @override
  String get petShopsLoadError => 'Не удалось загрузить зоомагазины. Повторите попытку.';

  @override
  String get retryButton => 'Повторить';

  @override
  String get shopInformationTitle => 'Информация о магазине';

  @override
  String get noShopDescriptionAvailable => 'Описание магазина отсутствует.';

  @override
  String get locationNotAvailable => 'Местоположение недоступно';

  @override
  String get getDirectionsLabel => 'Проложить маршрут';

  @override
  String get connectLabel => 'Связаться';

  @override
  String get callLabel => 'Позвонить';

  @override
  String get whatsappLabel => 'WhatsApp';

  @override
  String get websiteLabel => 'Веб-сайт';

  @override
  String get signInToContactShop => 'Войдите, чтобы связаться с магазином.';

  @override
  String get petShopUnavailable => 'Магазин недоступен';

  @override
  String get petShopUnavailableDescription => 'Этот зоомагазин больше недоступен.';

  @override
  String get reviewsCouldNotBeLoaded => 'Не удалось загрузить отзывы.';

  @override
  String get noProductsAvailableFromShop => 'В этом магазине нет доступных товаров';

  @override
  String get petShopLocationNeededMessage => 'Мы используем ваше местоположение, чтобы показать зоомагазины поблизости';

  @override
  String get infoTitle => 'Информация';

  @override
  String get processTitle => 'Процесс';

  @override
  String get categoriesTitle => 'Категории';

  @override
  String get contactTitle => 'Контакты';

  @override
  String get openFullProfile => 'Открыть полный профиль';

  @override
  String get noShopCategoriesAvailable => 'Категории магазина недоступны.';

  @override
  String get browseShopProductsDescription => 'Посмотрите товары, доступные в этом зоомагазине.';

  @override
  String get viewAllProducts => 'Посмотреть все товары';

  @override
  String get continueWithGoogle => 'Продолжить с Google';

  @override
  String get continueWithApple => 'Продолжить с Apple';

  @override
  String get orContinueWith => 'или продолжить с';

  @override
  String get authenticationCancelled => 'Аутентификация отменена';

  @override
  String get unableToSignIn => 'Не удалось войти';

  @override
  String get emailRegisteredWithAnotherProvider => 'Этот адрес электронной почты уже зарегистрирован с другим способом входа';

  @override
  String get completeYourProfile => 'Заполните профиль';

  @override
  String get cityLabel => 'Город';

  @override
  String get districtLabel => 'Район';

  @override
  String get cityRequired => 'Укажите город';

  @override
  String get districtRequired => 'Укажите район';

  @override
  String get continueLabel => 'Продолжить';

  @override
  String get petTaxiRequestRideTab => 'Заказать поездку';

  @override
  String get petTaxiRidesSubtitle => 'Ваши предстоящие и прошлые поездки Pet Taxi';

  @override
  String get petTaxiFilterActive => 'Активные и предстоящие';

  @override
  String get petTaxiFilterCompleted => 'Завершённые';

  @override
  String get petTaxiFilterCancelled => 'Отменённые';

  @override
  String get petTaxiNoRidesTitle => 'Поездок Pet Taxi пока нет';

  @override
  String get petTaxiNoRidesDescription => 'После заказа поездки ваши бронирования Pet Taxi появятся здесь.';

  @override
  String get petTaxiNoRidesInFilter => 'В этой категории нет поездок';

  @override
  String get petTaxiTryAnotherFilter => 'Выберите другую категорию, чтобы увидеть остальные поездки.';

  @override
  String get petTaxiRidesLoading => 'Загружаем ваши поездки Pet Taxi';

  @override
  String get petTaxiRidesLoadErrorTitle => 'Не удалось загрузить поездки';

  @override
  String get petTaxiRidesLoadErrorDescription => 'Проверьте подключение и повторите попытку. Ваши бронирования не были изменены.';

  @override
  String get petTaxiSignInRequiredTitle => 'Войдите, чтобы увидеть поездки';

  @override
  String get petTaxiSignInRequiredDescription => 'Бронирования Pet Taxi доступны после входа.';

  @override
  String get petTaxiProviderLabel => 'Перевозчик';

  @override
  String get petTaxiProviderFallback => 'Перевозчик Pet Taxi';

  @override
  String get petTaxiDestinationLabel => 'Пункт назначения';

  @override
  String get petTaxiScheduleUnavailable => 'Время недоступно';

  @override
  String get petTaxiPriceUnavailable => 'Ожидается цена';

  @override
  String get petTaxiStatusPending => 'Запрос ожидает ответа';

  @override
  String get petTaxiStatusAwaitingPayment => 'Ожидается оплата';

  @override
  String get petTaxiStatusConfirmedPaid => 'Подтверждено и оплачено';

  @override
  String get petTaxiStatusPaymentFailed => 'Ошибка оплаты';

  @override
  String get petTaxiStatusRefundPending => 'Ожидается возврат';

  @override
  String get petTaxiStatusRefunded => 'Средства возвращены';

  @override
  String get petTaxiStatusDriverOnTheWay => 'Водитель в пути';

  @override
  String get petTaxiStatusArrived => 'Водитель прибыл';

  @override
  String get petTaxiStatusPetPickedUp => 'Питомец принят';

  @override
  String get petTaxiStatusOnTrip => 'В пути';

  @override
  String get petTaxiStatusCompleted => 'Завершено';

  @override
  String get petTaxiStatusCancelledByUser => 'Отменено вами';

  @override
  String get petTaxiStatusCancelledByProvider => 'Отменено перевозчиком';

  @override
  String get petTaxiStatusUnknown => 'Статус недоступен';

  @override
  String get petTaxiPaymentPaid => 'Оплачено';

  @override
  String get petTaxiPaymentPending => 'Платёж обрабатывается';

  @override
  String get petTaxiPaymentFailed => 'Ошибка оплаты';

  @override
  String get petTaxiPaymentRefunded => 'Средства возвращены';

  @override
  String get petTaxiPaymentUnpaid => 'Не оплачено';

  @override
  String get webSubscriptionPaymentUnavailable => 'Оплата временно недоступна';

  @override
  String get webSubscriptionCatalogLoadFailed => 'Не удалось загрузить цены для безопасной оплаты. Проверьте подключение и повторите попытку.';

  @override
  String get webSubscriptionCatalogUnauthenticated => 'Войдите, чтобы загрузить цены подписки и безопасно продолжить.';

  @override
  String get webSubscriptionCatalogFunctionNotFound => 'Сервис безопасной оплаты недоступен в этой версии приложения. Обновите страницу и повторите попытку.';

  @override
  String get webSubscriptionCatalogConfigurationMissing => 'Настройки безопасной оплаты временно недоступны. Повторите попытку позже.';

  @override
  String get webSubscriptionCatalogNetworkFailed => 'Не удалось связаться с сервисом безопасной оплаты. Проверьте подключение и повторите попытку.';

  @override
  String get webSubscriptionCatalogMalformed => 'Сервис безопасной оплаты вернул некорректный ответ. Повторите попытку.';

  @override
  String get webSubscriptionThirtyDayAccess => 'Доступ по подписке на 30 дней';

  @override
  String get webSubscriptionContinueSecurePayment => 'Перейти к безопасной оплате';

  @override
  String get webSubscriptionPaymentTerms => 'Разовый платёж за 30 дней доступа. Автоматического списания с карты нет.';

  @override
  String get webSubscriptionIsbankSecurePayment => 'Безопасная оплата через İş Bank • 30 дней доступа • Без автопродления';

  @override
  String get webSubscriptionCheckoutFailed => 'Не удалось начать безопасную оплату. Повторите попытку.';

  @override
  String get webSubscriptionVerifyingTitle => 'Проверяем платёж';

  @override
  String get webSubscriptionVerifyingMessage => 'Подождите, пока банковский платёж проходит безопасную проверку.';

  @override
  String get webSubscriptionSuccessTitle => 'Подписка активирована';

  @override
  String get webSubscriptionSuccessMessage => 'Платёж подтверждён, доступ по подписке активирован на 30 дней.';

  @override
  String get webSubscriptionFailedTitle => 'Не удалось подтвердить платёж';

  @override
  String get webSubscriptionFailedMessage => 'Подписка не активирована. Неподтверждённый платёж не предоставляет доступ.';

  @override
  String get webSubscriptionCancelledTitle => 'Платёж отменён';

  @override
  String get webSubscriptionCancelledMessage => 'Платёж отменён, подписка не изменена.';

  @override
  String get webSubscriptionPendingTitle => 'Платёж ещё обрабатывается';

  @override
  String get webSubscriptionPendingMessage => 'Банк ещё не завершил проверку. Страница автоматически проверит статус снова.';
}
