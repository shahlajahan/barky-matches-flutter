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
  String get marketplaceDisclaimerTitle => 'Перед продолжением';

  @override
  String get marketplaceDisclaimerMessage => 'PetSupo — это платформа, которая связывает вас с независимыми компаниями и поставщиками услуг. Выбранную услугу предоставляет указанная компания или поставщик. PetSupo не гарантирует качество или выполнение этой независимой услуги и не несёт за это ответственность. Перед продолжением ознакомьтесь с информацией о компании или поставщике.';

  @override
  String get marketplaceDisclaimerAccept => 'Принять и продолжить';

  @override
  String get marketplaceDisclaimerCancel => 'Отмена';

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
  String get checkoutMultiSellerInfoTitle => 'Один платёж, отдельные заказы';

  @override
  String get checkoutMultiSellerInfoBody => 'Вы совершите один платёж. Для каждого продавца будет создан отдельный заказ.';

  @override
  String checkoutSellerSection(Object sellerName) {
    return '$sellerName';
  }

  @override
  String checkoutSellerFallback(int number) {
    return 'Продавец $number';
  }

  @override
  String get checkoutSellerSubtotal => 'Итого у продавца';

  @override
  String get checkoutProductsTotal => 'Стоимость товаров';

  @override
  String get checkoutShippingMethod => 'Способ доставки';

  @override
  String get checkoutShippingCost => 'Стоимость доставки';

  @override
  String get checkoutShippingTotal => 'Общая стоимость доставки';

  @override
  String get checkoutEstimatedDelivery => 'Ожидаемая доставка';

  @override
  String get checkoutSellerTotal => 'Итого у продавца';

  @override
  String get checkoutMultiOrderSuccessTitle => 'Оплата прошла успешно';

  @override
  String get checkoutMultiOrderSuccessBody => 'Оплата завершена, и для каждого продавца создан отдельный заказ.';

  @override
  String checkoutSellerOrderLabel(int number) {
    return 'Заказ продавца $number';
  }

  @override
  String get checkoutOpenOrder => 'Посмотреть заказ';

  @override
  String get checkoutMultiOrderExit => 'На главную';

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
  String get selectDate => 'Выбрать дату';

  @override
  String get selectTime => 'Выберите время';

  @override
  String get appointmentNoteHint => 'Добавьте заметку для клиники...';

  @override
  String get requestAppointment => 'Запросить приём';

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
  String get noServicesAvailable => 'Нет доступных услуг';

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
  String get invalidVerificationCode => 'Недействительный код подтверждения. Попробуйте еще раз.';

  @override
  String get verificationCodeExpired => 'Срок действия кода истек. Запросите новый код.';

  @override
  String get unableToVerifyEmail => 'Сейчас не удается подтвердить почту. Попробуйте еще раз.';

  @override
  String get unableToSendVerificationCode => 'Сейчас не удается отправить новый код. Попробуйте еще раз.';

  @override
  String verificationCodeSentTo(Object email) {
    return 'Код отправлен на адрес: $email';
  }

  @override
  String get verificationCodeSentToLabel => 'Код подтверждения отправлен на';

  @override
  String get sendingVerificationCode => 'Отправка...';

  @override
  String resendCodeAvailableIn(Object seconds) {
    return 'Повторная отправка кода доступна через $seconds с';
  }

  @override
  String get changeEmail => 'Изменить электронную почту';

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
  String get editDog => 'Редактировать профиль питомца';

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
  String get dogDetailsEditTitle => 'Редактировать профиль питомца';

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
  String get featuredDealsEmptyTitle => 'Избранные предложения';

  @override
  String get featuredDealsEmptyDescription => 'Специальные предложения партнёров PetSupo появятся здесь.';

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
  String get businessRegisterCompanyTypeQuestion => 'Какой у вас тип бизнеса?';

  @override
  String get businessRegisterCompanyTypeHelper => 'Необходимые документы будут определены в зависимости от типа вашего бизнеса.';

  @override
  String get businessRegisterCompanyTypeSoleProprietorship => 'Şahıs İşletmesi (Индивидуальный предприниматель)';

  @override
  String get businessRegisterCompanyTypeLimitedCompany => 'Limited Şirket (Общество с ограниченной ответственностью)';

  @override
  String get businessRegisterCompanyTypeJointStockCompany => 'Anonim Şirket (Акционерное общество)';

  @override
  String get businessRegisterCompanyTypeRequired => '• Пожалуйста, выберите тип компании.';

  @override
  String get businessRegisterCompanyTypeLabel => 'Тип компании';

  @override
  String get businessRegisterCompanyTypeLegacyUnspecified => 'Не указано / устаревшая запись';

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
  String get myOrdersUnknownProduct => 'Товар';

  @override
  String get myOrdersUnknownSeller => 'Продавец';

  @override
  String myOrdersProductAndMore(Object product, int count) {
    return '$product + ещё $count';
  }

  @override
  String get myOrdersOrderNumberUnavailable => 'Недоступен';

  @override
  String get myOrdersDateUnavailable => 'Дата недоступна';

  @override
  String get myOrdersSortNewest => 'Дата: сначала новые';

  @override
  String get myOrdersSortOldest => 'Дата: сначала старые';

  @override
  String get myOrdersSortProductAz => 'Товар: А–Я';

  @override
  String get myOrdersSortProductZa => 'Товар: Я–А';

  @override
  String get myOrdersSortSellerAz => 'Продавец: А–Я';

  @override
  String get myOrdersSortSellerZa => 'Продавец: Я–А';

  @override
  String get myOrdersSortAmountHigh => 'Сумма: по убыванию';

  @override
  String get myOrdersSortAmountLow => 'Сумма: по возрастанию';

  @override
  String get myOrdersProcessingStatus => 'Обрабатывается';

  @override
  String get myOrdersRefundedStatus => 'Возврат средств';

  @override
  String get myOrdersReturnedStatus => 'Возвращён';

  @override
  String get myOrdersRefundedOrReturnedStatus => 'Возврат средств / товара';

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
  String get mobileSubscriptionVerificationFailed => 'Не удалось подтвердить подписку. Повторите восстановление покупок.';

  @override
  String get mobileSubscriptionOwnershipConflict => 'Эта подписка привязана к другой учетной записи Petsupo. Войдите в учетную запись, которая ранее использовалась для этой подписки.';

  @override
  String get deleteAccountStoreSubscriptionNotice => 'Удаление аккаунта PetSupo не отменяет подписку в App Store или Google Play. Отмените оплату в магазине отдельно перед удалением аккаунта.';

  @override
  String get manageStoreSubscription => 'Управление подпиской магазина';

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
  String get productSubmittedForReviewStatus => 'Товар отправлен на проверку. Он не будет виден до одобрения.';

  @override
  String get veterinaryProductsNotSupported => 'Продажа и продвижение ветеринарных лекарственных препаратов через интернет не поддерживается.';

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
  String get petLabel => 'Pet';

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
  String get returnShippingTitle => 'Доставка возврата';

  @override
  String get returnShippingBuyerMessage => 'Вы оплачиваете доставку возврата.\n\nСтоимость курьерской доставки не входит в возврат средств и может не возмещаться.';

  @override
  String get returnShippingSellerMessage => 'Продавец оплачивает доставку возврата.';

  @override
  String get returnShippingContractedCarrierMessage => 'Используйте перевозчика продавца по договору.';

  @override
  String get returnShippingBuyerShipBackMessage => 'Курьерская доставка оплачивается вами отдельно от возврата средств.';

  @override
  String get returnShippingSellerShipBackMessage => 'Продавец покрывает стоимость доставки возврата.';

  @override
  String get returnShippingAcknowledgement => 'Я понимаю правила оплаты доставки возврата.';

  @override
  String get returnShippingPolicyLoading => 'Загружаем правила доставки возврата…';

  @override
  String returnShippingCarrierValue(Object carrier) {
    return 'Перевозчик: $carrier';
  }

  @override
  String get returnShippingVerifiedCarrierHelper => 'Используйте этого подтверждённого перевозчика продавца.';

  @override
  String get returnCarrierEnterHelperText => 'Укажите перевозчика для этой отправки возврата.';

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
  String get refundDecisionTitle => 'Решение о возврате средств';

  @override
  String get refundDecisionFullTitle => 'Полный возврат';

  @override
  String get refundDecisionFullDescription => 'Вернуть всю доступную сумму.';

  @override
  String get refundDecisionFullRecommended => 'Рекомендуется для повреждённых или дефектных товаров, неверного товара, ошибки продавца или недоставленного товара.';

  @override
  String get refundDecisionPartialTitle => 'Частичный возврат';

  @override
  String get refundDecisionPartialDescription => 'Вернуть только часть доступной суммы. Требуется обоснование.';

  @override
  String get refundDecisionRejectTitle => 'Отклонить возврат';

  @override
  String get refundDecisionRejectDescription => 'Отклонить запрос на возврат средств. Требуется ясное объяснение.';

  @override
  String get refundPartialAmountLabel => 'Сумма частичного возврата';

  @override
  String refundMaximumEligible(Object amount) {
    return 'Максимально доступно: $amount';
  }

  @override
  String get refundAmountValidationError => 'Введите сумму больше нуля, не превышающую доступный возврат.';

  @override
  String get refundDecisionReasonLabel => 'Причина';

  @override
  String get refundReasonNotSelected => 'Выберите причину';

  @override
  String get refundSellerNotesLabel => 'Примечания продавца';

  @override
  String get refundNotesOptional => 'Необязательно';

  @override
  String get refundNotesRequired => 'Обязательно';

  @override
  String get refundBuyerExplanationLabel => 'Объяснение для покупателя';

  @override
  String get refundBuyerExplanationHelper => 'Чётко объясните причину отказа в возврате.';

  @override
  String get refundOriginalOrderLabel => 'Исходный заказ';

  @override
  String get refundSummaryRefundLabel => 'Возврат';

  @override
  String get refundDifferenceLabel => 'Разница';

  @override
  String get refundDecisionBuyerTitle => 'Решение о возврате средств';

  @override
  String get refundDecisionLabel => 'Решение';

  @override
  String get refundSellerExplanationLabel => 'Объяснение продавца';

  @override
  String get refundReasonItemReturnedDamaged => 'Товар возвращён повреждённым';

  @override
  String get refundReasonMissingAccessories => 'Отсутствуют принадлежности';

  @override
  String get refundReasonCustomerCausedDamage => 'Повреждение по вине покупателя';

  @override
  String get refundReasonRestockingFee => 'Плата за возврат на склад';

  @override
  String get refundReasonPartialReturn => 'Частичный возврат товара';

  @override
  String get refundReasonSellerMistake => 'Ошибка продавца';

  @override
  String get refundReasonWrongItem => 'Неверный товар';

  @override
  String get refundReasonDefectiveProduct => 'Дефектный товар';

  @override
  String get refundReasonItemNeverDelivered => 'Товар не был доставлен';

  @override
  String get refundReasonOther => 'Другое';

  @override
  String get returnStatusWaitingSellerConfirmation => 'Ожидается подтверждение продавца';

  @override
  String get returnStatusAutoReceived => 'Получено автоматически';

  @override
  String get returnStatusDispute => 'Спор по возврату';

  @override
  String get waitingForSellerInspectionTitle => 'Ожидается проверка продавца';

  @override
  String waitingForSellerInspectionMessage(Object date) {
    return 'Продавец должен проверить возвращённую посылку до $date. Если действий не будет, возврат продолжится автоматически.';
  }

  @override
  String get inspectionDeadlineTitle => 'Срок проверки';

  @override
  String inspectionDaysRemaining(int days) {
    return 'Осталось дней: $days';
  }

  @override
  String get inspectionDeadlinePassed => 'Срок истёк. Ожидается автоматическое завершение.';

  @override
  String get reportReturnProblemTitle => 'Сообщить о проблеме возврата';

  @override
  String get reportProblemButton => 'Сообщить о проблеме';

  @override
  String get disputeReasonLabel => 'Причина проблемы';

  @override
  String get disputeReasonPackageNotReceived => 'Посылка не получена';

  @override
  String get disputeReasonWrongItemReturned => 'Возвращён неверный товар';

  @override
  String get disputeReasonEmptyPackage => 'Пустая посылка';

  @override
  String get disputeReasonDamagedDuringReturn => 'Повреждено при возврате';

  @override
  String get disputeReasonTrackingIssue => 'Проблема отслеживания';

  @override
  String get adminReturnDisputesTitle => 'Споры по возвратам';

  @override
  String get adminReturnDisputesSubtitle => 'Проверка спорных возвратов маркетплейса';

  @override
  String get noReturnDisputes => 'Спорных возвратов нет';

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
  String get servicesCouldNotBeLoaded => 'Не удалось загрузить услуги';

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
  String get connectAppleAccount => 'Подключить аккаунт Apple';

  @override
  String get appleAccountConnected => 'Аккаунт Apple подключён';

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

  @override
  String chatError(Object error) {
    return 'Ошибка чата: $error';
  }

  @override
  String get bankAccountSettingsTitle => 'Банковский счёт';

  @override
  String get bankAccountSettingsSubtitle => 'Этот счёт будет использоваться, когда PetSupo будет отправлять доход вашего бизнеса.';

  @override
  String get bankAccountInfoNotice => 'Убедитесь, что имя владельца счёта и IBAN точно совпадают с данными вашего официального банковского счёта. Неверные данные могут задержать выплаты.';

  @override
  String get bankAccountSectionTitle => 'Данные счёта';

  @override
  String get bankAccountHolderLabel => 'Владелец счёта';

  @override
  String get bankAccountBankNameLabel => 'Название банка';

  @override
  String get bankAccountIbanLabel => 'IBAN';

  @override
  String get bankAccountBillingInfoLabel => 'Платёжная информация (необязательно)';

  @override
  String get bankAccountIbanInvalid => 'IBAN должен начинаться с TR и содержать 24 цифры.';

  @override
  String get bankAccountSaveSuccess => 'Информация о банковском счёте сохранена.';

  @override
  String get diagnosticsSectionTitle => 'Диагностика';

  @override
  String get diagnosticsSectionDescription => 'Внутренние инструменты диагностики для проверки очереди и тестирования загрузки.';

  @override
  String get diagnosticsThrowButton => 'Вызвать ошибку';

  @override
  String get diagnosticsTestButton => 'Проверить';

  @override
  String get diagnosticsUploadButton => 'Загрузить';

  @override
  String get diagnosticsRefreshButton => 'Обновить';

  @override
  String get diagnosticsClearButton => 'Очистить';

  @override
  String dogCardAgeWithBreed(Object age, Object breed) {
    return '$age г. • $breed';
  }

  @override
  String dogCardAgeYears(Object age) {
    return '$age г.';
  }

  @override
  String dogCardVaccines(int count) {
    return 'Вакцин: $count';
  }

  @override
  String get dogParkPremiumMembersOnly => 'Этот парк доступен только участникам Premium.';

  @override
  String get favoritesExplorePlaymates => 'Найти друзей для игр 💛';

  @override
  String get vetServicesAvailableAfterLogin => 'Ветеринарные услуги доступны после входа';

  @override
  String get loadingAccount => 'Загрузка аккаунта...';

  @override
  String get noNotificationsForGuest => 'Для гостя уведомлений нет';

  @override
  String get loginForNotifications => 'Войдите, чтобы получать обновления и оповещения';

  @override
  String get offerDetailsTitle => 'Предложение';

  @override
  String get offerDiscountOffLabel => 'СКИДКА';

  @override
  String get offerUseCodeLabel => 'Используйте код:';

  @override
  String get offerUseThisOffer => 'Использовать предложение';

  @override
  String get playdateScheduledAtLabel => 'Игровая встреча будет назначена здесь:';

  @override
  String get continueToScheduling => 'Продолжить планирование';

  @override
  String get orderCancellationTitle => 'Отмена заказа';

  @override
  String get preShipmentCancellationAvailable => 'Этот заказ еще не отправлен и может быть отменен.';

  @override
  String get cancelOrderButton => 'Отменить заказ';

  @override
  String get cancelOrderTitle => 'Отменить заказ?';

  @override
  String get cancelOrderConfirmation => 'Вы уверены, что хотите отменить заказ? Заказ еще не отправлен.';

  @override
  String get cancelOrderRefundNotice => 'После отмены платеж будет возвращен.';

  @override
  String get cancellationReasonLabel => 'Причина отмены';

  @override
  String get cancelReasonOrderedByMistake => 'Заказ оформлен по ошибке';

  @override
  String get cancelReasonChangedMind => 'Я передумал(а)';

  @override
  String get cancelReasonDuplicateOrder => 'Повторный заказ';

  @override
  String get cancelReasonOther => 'Другое';

  @override
  String get cancellationReasonDetailsLabel => 'Подробности причины отмены';

  @override
  String get cancellationRefundProcessing => 'Заказ отменен. Возврат обрабатывается.';

  @override
  String get cancellationShipmentAlreadyStarted => 'Заказ больше нельзя отменить, так как отправка уже началась.';

  @override
  String get cancelOrderFailed => 'Не удалось отменить заказ. Повторите попытку.';

  @override
  String get cancellationRefundProcessingStatus => 'Запрошена отмена · Возврат обрабатывается';

  @override
  String get cancellationRefundFailedStatus => 'Возврат по отмене требует проверки';

  @override
  String get orderCancelledRefundCompleted => 'Заказ отменен · Возврат завершен';

  @override
  String get foundPetDetailsTitle => 'Сведения о найденном питомце';

  @override
  String get viewOnMap => 'Посмотреть на карте';

  @override
  String get contactReporter => 'Связаться с автором объявления';

  @override
  String get foundPetReportedSuccess => 'Найденный питомец успешно зарегистрирован!';

  @override
  String errorSubmittingReport(Object error) {
    return 'Ошибка отправки объявления: $error';
  }

  @override
  String get tapToSelectImage => 'Нажмите, чтобы выбрать изображение';

  @override
  String get foundPetsSubtitle => 'Помогите найденным питомцам безопасно вернуться домой';

  @override
  String get searchByNameHint => 'Поиск по имени...';

  @override
  String get noFoundPetsReportedYet => 'Объявлений о найденных питомцах пока нет';

  @override
  String get reportedFoundPetsAppearHere => 'Объявления о найденных питомцах появятся здесь';

  @override
  String get lostPetDetailsTitle => 'Сведения о потерянном питомце';

  @override
  String get havePetInformationPrompt => 'У вас есть информация об этом питомце?';

  @override
  String get callOwner => 'Позвонить владельцу';

  @override
  String get emailOwner => 'Написать владельцу';

  @override
  String get lostPetReportedSuccess => 'Потерянный питомец успешно зарегистрирован!';

  @override
  String get lostPetsSubtitle => 'Помогите потерянным питомцам вернуться домой';

  @override
  String get noLostPetsReportedYet => 'Объявлений о потерянных питомцах пока нет';

  @override
  String get reportedLostPetsAppearHere => 'Объявления о потерянных питомцах появятся здесь';

  @override
  String get searchUsersHint => 'Поиск пользователей...';

  @override
  String get noUsersFound => 'Пользователи не найдены';

  @override
  String get searchPetsAndUsers => 'Поиск питомцев и пользователей';

  @override
  String get findPetLoversNearby => 'Найдите любителей животных поблизости';

  @override
  String get selectAtLeastOnePhotoOrVideo => 'Выберите хотя бы одно фото или видео';

  @override
  String errorCreatingPost(Object error) {
    return 'Ошибка создания публикации: $error';
  }

  @override
  String get createPostTitle => 'Создать публикацию';

  @override
  String get share => 'Поделиться';

  @override
  String get addPhotosOrVideos => 'Добавить фото или видео';

  @override
  String get writeSomethingHint => 'Напишите что-нибудь...';

  @override
  String get replyHint => 'Ответить...';

  @override
  String get replySent => 'Ответ отправлен';

  @override
  String get close => 'Закрыть';

  @override
  String get videoStoriesComingSoon => 'Видеостори скоро появятся';

  @override
  String get petploreTitle => 'Petplore';

  @override
  String get explorePetMoments => 'Исследуйте моменты из жизни питомцев';

  @override
  String followersCount(int count) {
    return '$count подписчиков';
  }

  @override
  String followingCount(int count) {
    return '$count подписок';
  }

  @override
  String get feed => 'Лента';

  @override
  String get saved => 'Сохранённые';

  @override
  String get myPosts => 'Мои публикации';

  @override
  String get loginRequired => 'Требуется вход';

  @override
  String genericError(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get noPostsYet => 'Публикаций пока нет';

  @override
  String get noResults => 'Ничего не найдено';

  @override
  String get commentsTitle => 'Комментарии';

  @override
  String commentsError(Object error) {
    return 'Ошибка комментариев: $error';
  }

  @override
  String get noCommentsYet => 'Комментариев пока нет';

  @override
  String get writeCommentHint => 'Напишите комментарий...';

  @override
  String get postsTitle => 'Публикации';

  @override
  String get storyUploaded => 'История загружена';

  @override
  String storyUploadFailed(Object error) {
    return 'Не удалось загрузить историю: $error';
  }

  @override
  String get addStory => 'Добавить историю';

  @override
  String get storyDurationPrompt => 'Поделитесь моментом из жизни питомца на 24 часа';

  @override
  String get seeWhosNearby => 'Узнайте, кто рядом 👀!';

  @override
  String get telegramLab => 'Лаборатория Telegram';

  @override
  String get telegramBotApiTest => 'Тест Telegram Bot API';

  @override
  String get telegramTestInstructions => 'Нажмите кнопку ниже, чтобы отправить тестовое сообщение.';

  @override
  String get sendTelegramMessage => 'Отправить сообщение Telegram';

  @override
  String get telegramUsers => 'Пользователи Telegram';

  @override
  String get termsLastUpdated => 'Последнее обновление: 9 мая 2025 г.';

  @override
  String get termsIntroductionTitle => '1. Введение';

  @override
  String get termsIntroductionBody => 'Добро пожаловать в PetSupo! Регистрируясь, вы принимаете настоящие Условия. Приложение помогает находить друзей для собак, общаться с владельцами питомцев и пользоваться связанными услугами. Эти условия регулируют использование приложения и сервисов PetSupo.';

  @override
  String get termsResponsibilitiesTitle => '2. Обязанности пользователя';

  @override
  String get termsResponsibilitiesBody => '- Для использования приложения вам должно быть не менее 13 лет.\n- Вы отвечаете за конфиденциальность учётной записи и пароля.\n- Запрещено использовать приложение для незаконной деятельности.\n- При регистрации необходимо предоставлять точные и актуальные сведения.';

  @override
  String get termsPrivacyTitle => '3. Сбор данных и конфиденциальность';

  @override
  String get termsPrivacyBody => 'Для предоставления услуг мы собираем имя пользователя, электронную почту, местоположение и сведения о питомцах. В соответствии с турецким законом о защите персональных данных и международными нормами мы получаем явное согласие, используем данные только для заявленных целей, применяем меры безопасности и предоставляем доступ, исправление или удаление данных. Для реализации прав напишите на info@petsupo.com.';

  @override
  String get termsUserContentTitle => '4. Пользовательский контент';

  @override
  String get termsUserContentBody => '- Вы сохраняете права на загруженный контент.\n- Загружая контент, вы предоставляете PetSupo неисключительную безвозмездную лицензию на его использование и показ в приложении.\n- Запрещено загружать незаконный, оскорбительный или нарушающий чужие права контент.';

  @override
  String get termsLiabilityTitle => '5. Ограничение ответственности';

  @override
  String get termsLiabilityBody => 'PetSupo не отвечает за ущерб, возникший при использовании приложения, включая взаимодействия с другими пользователями или питомцами, и не гарантирует точность сведений других пользователей.';

  @override
  String get termsGoverningLawTitle => '6. Применимое право';

  @override
  String get termsGoverningLawBody => 'Настоящие Условия регулируются законодательством Турецкой Республики. Если международное право не требует иного, споры рассматриваются судами Стамбула.';

  @override
  String get termsChangesTitle => '7. Изменения условий';

  @override
  String get termsChangesBody => 'Мы можем периодически обновлять Условия. О значимых изменениях сообщается по электронной почте или в приложении. Продолжение использования означает принятие новых условий.';

  @override
  String get termsContactTitle => '7. Контакты';

  @override
  String get termsContactBody => 'По вопросам об этих Условиях напишите на info@petsupo.com.';

  @override
  String get pendingBusinessApprovals => 'Ожидающие одобрения компаний';

  @override
  String get invalidRequest => 'Недопустимый запрос';

  @override
  String get noPendingBusinessRequests => 'Нет ожидающих запросов компаний';

  @override
  String riskCount(Object count) {
    return 'РИСК: $count';
  }

  @override
  String get verifiedLabel => 'ПОДТВЕРЖДЕНО';

  @override
  String get approve => 'Одобрить';

  @override
  String get suspend => 'Приостановить';

  @override
  String get restore => 'Восстановить';

  @override
  String get businessApproved => 'Компания одобрена';

  @override
  String get businessRejected => 'Компания отклонена';

  @override
  String get businessSuspended => 'Компания приостановлена';

  @override
  String get businessRestored => 'Компания восстановлена';

  @override
  String actionFailed(Object error) {
    return 'Не удалось выполнить действие: $error';
  }

  @override
  String get adminDashboard => 'Панель администратора';

  @override
  String dashboardError(Object error) {
    return 'Ошибка панели:\n$error';
  }

  @override
  String get platformOverview => 'Обзор платформы';

  @override
  String get adminActivity => 'Действия администратора';

  @override
  String get developerTools => 'Инструменты разработчика';

  @override
  String get testTelegramBotApi => 'Тестировать Telegram Bot API';

  @override
  String get diagnostics => 'Диагностика';

  @override
  String get diagnosticsDescription => 'Отчёты о сбоях и диагностика запуска';

  @override
  String get telegramUsersDescription => 'Просмотр подключённых пользователей Telegram';

  @override
  String adminActivityError(Object error) {
    return 'Ошибка действий:\n$error';
  }

  @override
  String get noAdminActivity => 'Действий администратора пока нет';

  @override
  String get diagnosticReport => 'Диагностический отчёт';

  @override
  String get diagnosticReportNotFound => 'Диагностический отчёт не найден';

  @override
  String get reopen => 'Открыть снова';

  @override
  String get resolve => 'Решить';

  @override
  String get ignore => 'Игнорировать';

  @override
  String get stackTrace => 'Трассировка стека';

  @override
  String get breadcrumbsLogs => 'Навигация / журналы';

  @override
  String get noLogs => 'Журналов нет';

  @override
  String get rawJson => 'Исходный JSON';

  @override
  String get diagnosticReports => 'Диагностические отчёты';

  @override
  String get filters => 'Фильтры';

  @override
  String get noDiagnosticReports => 'Диагностических отчётов нет';

  @override
  String reasonValue(Object value) {
    return 'Причина: $value';
  }

  @override
  String featureValue(Object value) {
    return 'Функция: $value';
  }

  @override
  String platformValue(Object value) {
    return 'Платформа: $value';
  }

  @override
  String versionValue(Object value) {
    return 'Версия: $value';
  }

  @override
  String receivedValue(Object value) {
    return 'Получено: $value';
  }

  @override
  String messageValue(Object value) {
    return 'Сообщение: $value';
  }

  @override
  String createdValue(Object value) {
    return 'Создано: $value';
  }

  @override
  String get adminActions => 'Действия администратора';

  @override
  String get moderationCase => 'Дело модерации';

  @override
  String targetValue(Object value) {
    return 'Объект: $value';
  }

  @override
  String reportsCount(Object count) {
    return 'Жалобы: $count';
  }

  @override
  String riskScoreValue(Object value) {
    return 'Оценка риска: $value';
  }

  @override
  String priorityValue(Object value) {
    return 'Приоритет: $value';
  }

  @override
  String firestoreError(Object error) {
    return 'Ошибка Firestore: $error';
  }

  @override
  String get refundReview => 'Проверка возврата';

  @override
  String appointmentIdValue(Object value) {
    return 'ID записи: $value';
  }

  @override
  String paymentStatusValue(Object value) {
    return 'Статус оплаты: $value';
  }

  @override
  String refundStatusValue(Object value) {
    return 'Статус возврата: $value';
  }

  @override
  String appointmentTimeValue(Object value) {
    return 'Время записи: $value';
  }

  @override
  String cancellationTimeValue(Object value) {
    return 'Время отмены: $value';
  }

  @override
  String hoursBeforeAppointmentValue(Object value) {
    return 'Часов до записи: $value';
  }

  @override
  String businessValue(Object value) {
    return 'Компания: $value';
  }

  @override
  String userValue(Object value) {
    return 'Пользователь: $value';
  }

  @override
  String petValue(Object value) {
    return 'Питомец: $value';
  }

  @override
  String amountPaidValue(Object value) {
    return 'Оплачено: $value';
  }

  @override
  String refundReasonValue(Object value) {
    return 'Причина возврата: $value';
  }

  @override
  String refundErrorValue(Object value) {
    return 'Ошибка возврата: $value';
  }

  @override
  String get approveRefund => 'Одобрить возврат';

  @override
  String get rejectRefund => 'Отклонить возврат';

  @override
  String refundReviewFailed(Object error) {
    return 'Не удалось проверить возврат: $error';
  }

  @override
  String get note => 'Примечание';

  @override
  String refundQueueError(Object error) {
    return 'Ошибка очереди возвратов: $error';
  }

  @override
  String get refundRequests => 'Запросы на возврат';

  @override
  String get noPendingRefundRequests => 'Нет ожидающих запросов на возврат';

  @override
  String get reportsTitle => 'Жалобы';

  @override
  String appointmentValue(Object value) {
    return 'Запись: $value';
  }

  @override
  String cancelledValue(Object value) {
    return 'Отменено: $value';
  }

  @override
  String amountValue(Object value) {
    return 'Сумма: $value';
  }

  @override
  String statusValue(Object value) {
    return 'Статус: $value';
  }

  @override
  String get confirmViolation => 'Подтвердить нарушение';

  @override
  String get markClean => 'Отметить как допустимое';

  @override
  String get businessMetrics => 'Показатели компаний';

  @override
  String get businessSearch => 'Поиск компаний';

  @override
  String get searchBusinessNameHint => 'Поиск по названию компании...';

  @override
  String get suspendedLabel => 'Приостановлено';

  @override
  String get filterByStatus => 'Фильтр по статусу';

  @override
  String get complaintCenter => 'Центр жалоб';

  @override
  String get noData => 'Нет данных';

  @override
  String get noComplaintsFound => 'Жалобы не найдены';

  @override
  String categoryValue(Object value) {
    return 'Категория: $value';
  }

  @override
  String get complaintDetail => 'Сведения о жалобе';

  @override
  String severityValue(Object value) {
    return 'Серьёзность: $value';
  }

  @override
  String get evidence => 'Доказательство';

  @override
  String get dismiss => 'Отклонить';

  @override
  String get fraudAnalytics => 'Аналитика мошенничества';

  @override
  String get errorLoadingAnalytics => 'Ошибка загрузки аналитики';

  @override
  String get adminMapMonitor => 'Мониторинг карты';

  @override
  String get platformMetrics => 'Показатели платформы';

  @override
  String get noMetricsData => 'Нет данных показателей';

  @override
  String lastUpdatedValue(Object value) {
    return 'Последнее обновление: $value';
  }

  @override
  String get revenueTitle => 'Доход';

  @override
  String get noRevenueData => 'Нет данных о доходе';

  @override
  String get auditLogs => 'Журналы аудита';

  @override
  String verifiedValue(Object value) {
    return 'Подтверждено: $value';
  }

  @override
  String documentNumberValue(Object value) {
    return 'Номер документа: $value';
  }

  @override
  String get open => 'Открыть';

  @override
  String get petTaxiDocument => 'Документ Pet Taxi';

  @override
  String get openPdf => 'Открыть PDF';

  @override
  String get suspendedBusinesses => 'Приостановленные компании';

  @override
  String get noDataReceived => 'Данные не получены';

  @override
  String get noSuspendedBusinesses => 'Нет приостановленных компаний';

  @override
  String get subscriptionDetails => 'Сведения о подписке';

  @override
  String planValue(Object value) {
    return 'План: $value';
  }

  @override
  String priceValue(Object value) {
    return 'Цена: $value';
  }

  @override
  String get cancelSubscription => 'Отменить подписку';

  @override
  String get expireNow => 'Завершить сейчас';

  @override
  String get makePremium => '⭐ Сделать Premium';

  @override
  String get upgradeToPartner => '👑 Повысить до партнёра PetSupo';

  @override
  String get downgradeToPremium => '⬇ Понизить до Premium';

  @override
  String get extendThirtyDays => 'Продлить на 30 дней';

  @override
  String get subscriptionManagement => 'Управление подписками';

  @override
  String get searchUserIdHint => 'Поиск ID пользователя...';

  @override
  String get loadingSubscription => 'Загрузка подписки...';

  @override
  String get feedbackDetail => 'Сведения об отзыве';

  @override
  String ratingValue(Object value) {
    return 'Оценка: $value';
  }

  @override
  String contextValue(Object value) {
    return 'Контекст: $value';
  }

  @override
  String get messageLabel => 'Сообщение';

  @override
  String get userFeedback => 'Отзывы пользователей';

  @override
  String get noPayoutsFound => 'Выплаты не найдены';

  @override
  String get payoutManagement => 'Управление выплатами';

  @override
  String get readyLabel => 'Готово';

  @override
  String get searchPayoutsHint => 'Поиск заказа, продавца, покупателя или ссылки...';

  @override
  String get payoutMarkedReady => 'Выплата отмечена как готовая';

  @override
  String get confirmPayout => 'Подтвердить выплату';

  @override
  String get bankTransferReference => 'Ссылка банковского перевода';

  @override
  String get bankReferenceHint => 'EFT / FAST / банковская ссылка';

  @override
  String get payoutMarkedPaid => 'Выплата отмечена как оплаченная';

  @override
  String sellerValue(Object value) {
    return 'Продавец: $value';
  }

  @override
  String buyerValue(Object value) {
    return 'Покупатель: $value';
  }

  @override
  String referenceValue(Object value) {
    return 'Ссылка: $value';
  }

  @override
  String get markReady => 'Отметить готовой';

  @override
  String get markPaid => 'Отметить оплаченной';

  @override
  String openEntity(Object id, Object type) {
    return 'Открыть $type: $id';
  }

  @override
  String get globalAdminSearchHint => 'Поиск пользователей, собак, компаний, жалоб и обращений...';

  @override
  String get globalAdminSearch => 'Глобальный поиск администратора';

  @override
  String get notAuthenticated => 'Пользователь не авторизован';

  @override
  String get adoptionRequestNotFound => 'Запрос на усыновление не найден';

  @override
  String get backToRequests => 'Назад к запросам';

  @override
  String get messageApplicant => 'Написать заявителю';

  @override
  String get unknownPet => 'Неизвестный питомец';

  @override
  String get adoptionRequest => 'Запрос на усыновление';

  @override
  String get waitingForOwnerResponse => 'Ожидание ответа владельца';

  @override
  String get doneWithIcon => '✅ Готово';

  @override
  String failedWithIcon(Object error) {
    return '❌ Ошибка: $error';
  }

  @override
  String get availablePets => 'Доступные питомцы';

  @override
  String get petsCouldNotBeLoaded => 'Не удалось загрузить питомцев.';

  @override
  String get noPetsAvailable => 'Нет доступных питомцев';

  @override
  String get noImages => 'Нет изображений';

  @override
  String get viewAvailablePets => 'Посмотреть доступных питомцев';

  @override
  String get signInToContinue => 'Войдите, чтобы продолжить';

  @override
  String get writeReviewFirst => 'Сначала напишите отзыв';

  @override
  String get reviewSubmitted => 'Отзыв отправлен';

  @override
  String get reviewExperienceHint => 'Расскажите другим о своём опыте';

  @override
  String get submitReview => 'Отправить отзыв';

  @override
  String get adoptionCenterDetails => 'Сведения о центре усыновления';

  @override
  String get adoptionServices => 'Услуги усыновления';

  @override
  String get petTypes => 'Виды питомцев';

  @override
  String get workingDays => 'Рабочие дни';

  @override
  String get vetCheckIncluded => 'Ветеринарный осмотр включён';

  @override
  String get homeVisitAvailable => 'Доступен выезд на дом';

  @override
  String get transportSupport => 'Транспортная поддержка';

  @override
  String get fosterSupport => 'Поддержка передержки';

  @override
  String get media => 'Медиа';

  @override
  String get logo => 'Логотип';

  @override
  String get approvedBusinesses => 'Одобренные компании';

  @override
  String get searchBusinessesHint => 'Поиск компаний...';

  @override
  String get noApprovedBusinesses => 'Нет одобренных компаний';

  @override
  String get basic => 'Базовый';

  @override
  String get disclaimerAccepted => 'Отказ от ответственности принят';

  @override
  String get mismatchDetected => '⚠ Обнаружено несоответствие';

  @override
  String get languageCodeTr => 'TR';

  @override
  String get languageCodeEn => 'EN';

  @override
  String get riskFlags => 'Флаги риска';

  @override
  String get noRiskFlags => 'Флагов риска нет';

  @override
  String get adminNotes => 'Заметки администратора';

  @override
  String get adminNotesHint => 'Добавьте внутренние заметки модерации...';

  @override
  String get saveNotes => 'Сохранить заметки';

  @override
  String get adminNotesSaved => 'Заметки администратора сохранены ✅';

  @override
  String saveFailed(Object error) {
    return 'Не удалось сохранить: $error';
  }

  @override
  String get noQuickRepliesFound => 'Быстрые ответы не найдены';

  @override
  String get quickReplies => 'Быстрые ответы';

  @override
  String get chatFailedToLoad => 'Не удалось загрузить чат';

  @override
  String get noMessagesYet => 'Сообщений пока нет';

  @override
  String get typeMessageHint => 'Введите сообщение...';

  @override
  String get noRequests => 'Запросов нет';

  @override
  String phoneValue(Object value) {
    return 'Телефон: $value';
  }

  @override
  String genderValue(Object value) {
    return 'Пол: $value';
  }

  @override
  String petStatusUpdated(Object name) {
    return 'Статус $name обновлён';
  }

  @override
  String statusUpdateFailed(Object error) {
    return 'Не удалось обновить статус: $error';
  }

  @override
  String get deletePetQuestion => 'Удалить питомца?';

  @override
  String deletePetConfirmation(Object name) {
    return 'Удалить $name? Это действие нельзя отменить.';
  }

  @override
  String petDeleted(Object name) {
    return '$name удалён';
  }

  @override
  String deleteFailedWithError(Object error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String get searchPetsHint => 'Поиск питомцев';

  @override
  String get noAdoptablePetsYet => 'Питомцев для усыновления пока нет';

  @override
  String get addAdoptablePetsDescription => 'Добавьте доступных для усыновления питомцев и управляйте их статусом здесь.';

  @override
  String failedToLoadPets(Object error) {
    return 'Не удалось загрузить питомцев:\n$error';
  }

  @override
  String breedValue(Object value) {
    return 'Порода: $value';
  }

  @override
  String ageValue(Object value) {
    return 'Возраст: $value';
  }

  @override
  String get edit => 'Изменить';

  @override
  String get noAdoptionPetsYet => 'Питомцев для усыновления пока нет';

  @override
  String get addPetsForAdoption => 'Добавьте питомцев, доступных для усыновления.';

  @override
  String get editAdoptionCenter => 'Редактировать центр пристройства';

  @override
  String get pleaseAddCoverImage => 'Добавьте обложку';

  @override
  String get addGalleryImages => 'Добавить изображения в галерею';

  @override
  String get petNameLabel => 'Имя питомца';

  @override
  String get ageMonthsLabel => 'Возраст (месяцы)';

  @override
  String get visible => 'Видимый';

  @override
  String failedToSetCover(Object error) {
    return 'Не удалось установить обложку: $error';
  }

  @override
  String get uploadPetMedia => 'Загрузить медиа питомца';

  @override
  String uploadedPercent(Object percent) {
    return 'Загружено: $percent%';
  }

  @override
  String get noMediaYet => 'Медиа пока нет';

  @override
  String get cover => 'Обложка';

  @override
  String get adoptionCenterInfo => 'Информация о центре пристройства';

  @override
  String get centerNameLabel => 'Название центра';

  @override
  String get instagram => 'Instagram';

  @override
  String get address => 'Адрес';

  @override
  String get saveCenterInfo => 'Сохранить информацию о центре';

  @override
  String get latestAdoptionApplications => 'Последние заявки на усыновление';

  @override
  String get viewAll => 'Посмотреть все';

  @override
  String get tapForMoreDetails => 'Нажмите, чтобы узнать больше';

  @override
  String get setAvailable => 'Сделать доступным';

  @override
  String get setReserved => 'Сделать зарезервированным';

  @override
  String get setAdopted => 'Отметить усыновлённым';

  @override
  String get setPaused => 'Приостановить';

  @override
  String get clients => 'Клиенты';

  @override
  String get searchPetOrOwnerHint => 'Поиск по имени питомца или владельца';

  @override
  String get couldNotLoadClients => 'Не удалось загрузить клиентов.';

  @override
  String get addClient => 'Добавить клиента';

  @override
  String get ownerNameLabel => 'Имя владельца';

  @override
  String get notes => 'Заметки';

  @override
  String get price => 'Цена';

  @override
  String get saveClient => 'Сохранить клиента';

  @override
  String get petOwnerNamesRequired => 'Необходимо указать имена питомца и владельца';

  @override
  String get clientSaved => 'Клиент сохранён';

  @override
  String lastGrooming(Object date) {
    return 'Последний груминг: $date';
  }

  @override
  String get noClientsYet => 'Клиентов пока нет';

  @override
  String get addFirstGroomingClient => 'Добавьте первого клиента, чтобы отслеживать посещения.';

  @override
  String get clientProfile => 'Профиль клиента';

  @override
  String get openAppointmentBooking => 'Откройте запись на приём со страницы компании';

  @override
  String get groomingHistory => 'История груминга';

  @override
  String get ownerNotFound => 'Владелец не найден';

  @override
  String get signInRequired => 'Требуется вход';

  @override
  String get addGroomingVisit => 'Добавить посещение груминга';

  @override
  String get serviceVisitTitle => 'Название услуги / посещения';

  @override
  String get saveVisit => 'Сохранить посещение';

  @override
  String get visitSaved => 'Посещение сохранено';

  @override
  String get editClient => 'Редактировать клиента';

  @override
  String get salonSchedule => 'Расписание салона';

  @override
  String get manageGroomingAppointments => 'Управление записями на груминг';

  @override
  String amountTry(Object amount) {
    return '$amount TRY';
  }

  @override
  String get uploadGroomingMedia => 'Загрузить медиа груминга';

  @override
  String get add => 'Добавить';

  @override
  String get afterPlatformCommission => 'После комиссии платформы';

  @override
  String get recentAppointments => 'Недавние записи';

  @override
  String get latestGroomingRequests => 'Последние запросы и сеансы груминга';

  @override
  String appointmentError(Object error) {
    return 'Ошибка записи: $error';
  }

  @override
  String get noGroomingAppointmentsYet => 'Записей на груминг пока нет';

  @override
  String get deleteService => 'Удалить услугу';

  @override
  String get deleteServiceConfirmation => 'Вы уверены, что хотите удалить эту услугу?';

  @override
  String get serviceDeleted => 'Услуга удалена';

  @override
  String get deleteFailed => 'Не удалось удалить';

  @override
  String get availabilityUpdated => 'Доступность обновлена';

  @override
  String updateFailed(Object error) {
    return 'Не удалось обновить: $error';
  }

  @override
  String get availability => 'Доступность';

  @override
  String get capacityBookingExplanation => 'Вместимость используется для предотвращения пересекающихся проживаний сверх числа доступных номеров.';

  @override
  String get roomCapacity => 'Вместимость номеров';

  @override
  String get maximumPetsRooms => 'Максимум питомцев / номеров';

  @override
  String currentCapacity(int count) {
    return 'Текущая вместимость: $count';
  }

  @override
  String get saveAvailability => 'Сохранить доступность';

  @override
  String get checkIn => 'Заселить';

  @override
  String get completeStay => 'Завершить проживание';

  @override
  String alreadyStatus(Object status) {
    return 'Уже $status';
  }

  @override
  String bookingUpdated(Object status) {
    return 'Бронирование обновлено: $status';
  }

  @override
  String bookingError(Object error) {
    return 'Ошибка бронирования: $error';
  }

  @override
  String get hotelProfile => 'Профиль отеля';

  @override
  String get hotelOverview => 'Обзор отеля';

  @override
  String get pendingRequests => 'Ожидающие запросы';

  @override
  String get uploadHotelMedia => 'Загрузить медиа отеля';

  @override
  String get proposeFinalPrice => 'Предложить итоговую цену';

  @override
  String get editProposedPrice => 'Изменить предложенную цену';

  @override
  String get notifyCustomerConfirmation => 'Клиент получит уведомление.';

  @override
  String get finalPrice => 'Итоговая цена';

  @override
  String get customerMustPayBeforeTrip => 'Клиент должен оплатить эту сумму в приложении до начала поездки.';

  @override
  String get sendPrice => 'Отправить цену';

  @override
  String get petTaxiOverview => 'Обзор зоотакси';

  @override
  String get driverOnline => 'Водитель онлайн';

  @override
  String get petTaxiAwaitingActivation => 'Зоотакси ожидает активации.';

  @override
  String get petTaxiAvailabilityUpdateFailed => 'Не удалось обновить статус водителя. Повторите попытку.';

  @override
  String get serviceDetailsSaveFailed => 'Не удалось сохранить сведения об услуге.';

  @override
  String get priceDeterminedAfterExamination => 'Оставьте поле пустым, если итоговая цена определяется после осмотра.';

  @override
  String get editing => 'Редактирование';

  @override
  String get setPriceDurationDescription => 'Укажите цену и примерную длительность для владельцев питомцев.';

  @override
  String get serviceDetailsBeforeBooking => 'Эти сведения помогают владельцам понять услугу до бронирования.';

  @override
  String get addCustomService => 'Добавить свою услугу';

  @override
  String get create => 'Создать';

  @override
  String get paymentSuccessful => 'Оплата прошла успешно';

  @override
  String get paymentCancelled => 'Оплата отменена';

  @override
  String paymentFailedWithError(Object error) {
    return 'Ошибка оплаты: $error';
  }

  @override
  String get appointmentPayment => 'Оплата приёма';

  @override
  String get done => 'Готово';

  @override
  String get payNow => 'Оплатить сейчас';

  @override
  String get titleLabel => 'Заголовок';

  @override
  String get noQuickRepliesYet => 'Быстрых ответов пока нет';

  @override
  String get quickRepliesDescription => 'Создавайте повторно используемые ответы на частые вопросы клиентов.';

  @override
  String get inbox => 'Входящие';

  @override
  String inboxError(Object error) {
    return 'Ошибка входящих:\n$error';
  }

  @override
  String get emergency => 'Экстренно';

  @override
  String get noClientMessagesYet => 'Сообщений клиентов пока нет';

  @override
  String get clientMessagesDescription => 'Когда владельцы питомцев свяжутся с клиникой, переписки появятся здесь.';

  @override
  String get passportNumberFormat => 'Номер паспорта может содержать только заглавные буквы, цифры, - или /';

  @override
  String get medicalProfileUpdated => 'Медицинский профиль обновлён';

  @override
  String profileUpdateFailed(Object error) {
    return 'Не удалось обновить профиль: $error';
  }

  @override
  String get confirmMicrochipNumber => 'Подтвердить номер микрочипа';

  @override
  String get review => 'Проверить';

  @override
  String get saveAnyway => 'Всё равно сохранить';

  @override
  String get medicalProfile => 'Медицинский профиль';

  @override
  String get saveMedicalProfile => 'Сохранить медицинский профиль';

  @override
  String get ownerProfileUpdated => 'Профиль владельца обновлён';

  @override
  String get ownerProfile => 'Профиль владельца';

  @override
  String couldNotSaveVisit(Object error) {
    return 'Не удалось сохранить посещение: $error';
  }

  @override
  String get deleteVisit => 'Удалить посещение';

  @override
  String get deleteVisitConfirmation => 'Удалить это посещение из медицинской карты?';

  @override
  String couldNotDeleteVisit(Object error) {
    return 'Не удалось удалить посещение: $error';
  }

  @override
  String get deleteVisitTooltip => 'Удалить посещение';

  @override
  String get addVaccine => 'Добавить вакцину';

  @override
  String get vaccine => 'Вакцина';

  @override
  String get reminder => 'Напоминание';

  @override
  String get notifyBeforeNextDueDate => 'Уведомить до следующей даты вакцинации';

  @override
  String get saveVaccine => 'Сохранить вакцину';

  @override
  String get patientNotFound => 'Пациент не найден';

  @override
  String get editOwnerProfile => 'Редактировать профиль владельца';

  @override
  String get ownerEmergencyContactDetails => 'Данные владельца и экстренного контакта';

  @override
  String get editMedicalProfile => 'Редактировать медицинский профиль';

  @override
  String get clinicalVeterinaryInformation => 'Клиническая и ветеринарная информация';

  @override
  String get visits => 'Посещения';

  @override
  String get vaccines => 'Вакцины';

  @override
  String get ownerInformation => 'Информация о владельце';

  @override
  String get visitsUnavailable => 'Посещения недоступны';

  @override
  String visitsError(Object error) {
    return 'Ошибка посещений: $error';
  }

  @override
  String get followUp => 'Повторный приём';

  @override
  String get editVisitTooltip => 'Редактировать посещение';

  @override
  String get editMedicalNotes => 'Редактировать медицинские заметки';

  @override
  String get medicalNotes => 'Медицинские заметки';

  @override
  String get editVaccineTooltip => 'Редактировать вакцину';

  @override
  String get deleteVaccineTooltip => 'Удалить вакцину';

  @override
  String get deleteVaccine => 'Удалить вакцину';

  @override
  String get deleteVaccineConfirmation => 'Вы уверены, что хотите удалить эту запись о вакцинации?';

  @override
  String get editVaccine => 'Редактировать вакцину';

  @override
  String get vaccineName => 'Название вакцины';

  @override
  String get updateVaccine => 'Обновить вакцину';

  @override
  String get completeVaccine => 'Завершить вакцинацию';

  @override
  String get clientNote => 'Заметка клиента';

  @override
  String get businessInfo => 'Информация о компании';

  @override
  String get clinicName => 'Название клиники';

  @override
  String get emergencyServiceEnabled => 'Экстренная помощь включена';

  @override
  String get saveBusinessInfo => 'Сохранить информацию';

  @override
  String get openAppointmentsTab => 'Откройте вкладку записей сверху';

  @override
  String get viewAllAppointments => 'Посмотреть все записи';

  @override
  String get checkConnectionTryAgain => 'Проверьте подключение и повторите попытку.';

  @override
  String get editServiceTooltip => 'Редактировать услугу';

  @override
  String get deleteServiceTooltip => 'Удалить услугу';

  @override
  String get noServicesAddedYet => 'Услуги пока не добавлены';

  @override
  String get addFirstServiceDescription => 'Добавьте первую услугу, чтобы она стала доступна владельцам питомцев.';

  @override
  String get servicesPricing => 'Услуги и цены';

  @override
  String get addService => 'Добавить услугу';

  @override
  String get noServicesYet => 'Услуг пока нет.';

  @override
  String servicePriceDuration(Object price, Object currency, Object duration) {
    return '$price $currency • $duration мин';
  }

  @override
  String get serviceTitle => 'Название услуги';

  @override
  String get durationMinutes => 'Длительность (мин)';

  @override
  String get requireDeposit => 'Требовать предоплату';

  @override
  String get depositAmount => 'Размер предоплаты (₺)';

  @override
  String get featured => 'Рекомендуемая';

  @override
  String get active => 'Активная';

  @override
  String get photoUploadedSuccessfully => 'Фото успешно загружено';

  @override
  String get photoDeleted => 'Фото удалено';

  @override
  String get coverImageUpdated => 'Обложка обновлена';

  @override
  String get galleryManagement => 'Управление галереей';

  @override
  String get coverImage => 'Обложка';

  @override
  String get tapToChangeCover => 'Нажмите, чтобы изменить обложку';

  @override
  String get uploadCoverImage => 'Загрузить обложку';

  @override
  String get tapToUploadClinicCover => 'Нажмите, чтобы загрузить обложку клиники';

  @override
  String get galleryPhotos => 'Фотографии галереи';

  @override
  String get noGalleryPhotosYet => 'В галерее пока нет фотографий';

  @override
  String get uploadClinicPhotosDescription => 'Загрузите фотографии клиники, чтобы повысить доверие и видимость.';

  @override
  String get uploadFirstPhoto => 'Загрузить первое фото';

  @override
  String get dragToReorderGallery => 'Перетащите фотографии, чтобы изменить порядок';

  @override
  String get patients => 'Пациенты';

  @override
  String get back => 'Назад';

  @override
  String get patientRecords => 'Карты пациентов';

  @override
  String shownCount(int count) {
    return 'Показано: $count';
  }

  @override
  String get searchPetOwnerBreed => 'Поиск питомца, владельца или породы';

  @override
  String get clear => 'Очистить';

  @override
  String preVisitSettingsLoadFailed(Object error) {
    return 'Не удалось загрузить настройки предварительной формы: $error';
  }

  @override
  String get preVisitSettingsSaved => 'Настройки предварительной формы сохранены';

  @override
  String settingsSaveFailed(Object error) {
    return 'Не удалось сохранить настройки: $error';
  }

  @override
  String get preVisitForms => 'Предварительные формы';

  @override
  String get servicePreVisitForms => 'Предварительные формы услуг';

  @override
  String get serviceMedicalIntakeDescription => 'У каждой услуги могут быть свои вопросы для медицинского приёма.';

  @override
  String get servicesCouldNotBeLoadedPeriod => 'Не удалось загрузить услуги.';

  @override
  String get noActiveServicesForForms => 'Активных услуг пока нет. Добавьте услуги перед созданием форм.';

  @override
  String get enableForService => 'Включить для этой услуги';

  @override
  String get onlyServiceAsksQuestions => 'Эти вопросы будут задаваться только для этой услуги.';

  @override
  String get noQuestionsForService => 'Для этой услуги пока нет вопросов.';

  @override
  String get question => 'Вопрос';

  @override
  String get questionExample => 'Например: ваш питомец сегодня ел?';

  @override
  String get remove => 'Удалить';

  @override
  String get questionType => 'Тип вопроса';

  @override
  String get textType => 'Текст';

  @override
  String get longTextType => 'Длинный текст';

  @override
  String get yesNoType => 'Да / Нет';

  @override
  String get singleChoice => 'Один вариант';

  @override
  String get multipleChoice => 'Несколько вариантов';

  @override
  String get numberType => 'Число';

  @override
  String get requiredLabel => 'Required';

  @override
  String get options => 'Варианты';

  @override
  String optionNumber(int number) {
    return 'Вариант $number';
  }

  @override
  String get addOption => 'Добавить вариант';

  @override
  String get clinicSchedule => 'Расписание клиники';

  @override
  String get appointments => 'Записи';

  @override
  String totalCount(int count) {
    return 'Всего: $count';
  }

  @override
  String get services => 'Услуги';

  @override
  String get addServiceFlowComingNext => 'Добавление услуг скоро появится';

  @override
  String get clinicServices => 'Услуги клиники';

  @override
  String get manageVisibleVetServices => 'Управление видимыми ветеринарными услугами';

  @override
  String get clinicSettings => 'Настройки клиники';

  @override
  String get emergencyAvailabilitySaveFailed => 'Не удалось сохранить доступность экстренной помощи';

  @override
  String managementNotAvailable(Object label) {
    return 'Управление «$label» пока недоступно';
  }

  @override
  String loadError(Object error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get workingHoursSaved => 'Рабочие часы сохранены';

  @override
  String saveError(Object error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get workingHours => 'Рабочие часы';

  @override
  String get clinicWorkingHours => 'Рабочие часы клиники';

  @override
  String get manageOpeningDays => 'Управляйте рабочими днями и доступностью записей';

  @override
  String get editGroomyProfile => 'Редактировать профиль груминга';

  @override
  String get groomyDetails => 'Сведения о груминге';

  @override
  String get homeService => 'Выезд на дом';

  @override
  String get pickupService => 'Забор питомца';

  @override
  String get photos => 'Фотографии';

  @override
  String get complete => 'Завершить';

  @override
  String get awaitingPayment => 'Ожидается оплата';

  @override
  String appointmentUpdated(Object status) {
    return 'Запись обновлена: $status';
  }

  @override
  String get galleryComingSoon => 'Галерея скоро появится';

  @override
  String get editHotelProfile => 'Редактировать профиль отеля';

  @override
  String pricePerNight(Object price) {
    return '$price₺ / ночь';
  }

  @override
  String bookStayAt(Object hotel) {
    return 'Забронировать проживание • $hotel';
  }

  @override
  String get hotelCareNotesHint => 'Питание, лекарства или заметки по уходу';

  @override
  String get requestBooking => 'Запросить бронирование';

  @override
  String get checkoutAfterCheckin => 'Дата выезда должна быть позже даты заезда';

  @override
  String get hotelBookingRequestSent => 'Запрос на бронирование отеля отправлен.';

  @override
  String get noGalleryImagesYet => 'Изображений в галерее пока нет';

  @override
  String get petHotelDetails => 'Сведения о зоогостинице';

  @override
  String get amenities => 'Удобства';

  @override
  String get petTaxiDetails => 'Сведения о зоотакси';

  @override
  String get petTaxiManualReviewNotice => 'Заявка на зоотакси не будет опубликована до ручной проверки и одобрения документов.';

  @override
  String get petTaxiReplacementExpiryDateDriverLicense => 'Новая дата окончания водительского удостоверения';

  @override
  String get petTaxiReplacementExpiryDateTrafficInsurance => 'Новая дата окончания страховки автомобиля';

  @override
  String get petTaxiReplacementExpiryRequired => 'Перед отправкой замены выберите действительную будущую дату.';

  @override
  String get petTaxiReplacementSubmitted => 'Замена отправлена на проверку.';

  @override
  String get petTaxiDocumentsRequiringReplacement => 'Документы, требующие замены';

  @override
  String get petTaxiRejected => 'Отклонено';

  @override
  String get petTaxiReplaceDocument => 'Заменить';

  @override
  String get transportationLawNotice => 'Транспортное законодательство зависит от города и страны. Компания обязана соблюдать местные правила перевозки, страхования и налогообложения.';

  @override
  String get legalDocumentsPrivacyNotice => 'Юридические документы хранятся только для проверки владельцем компании и администратором. Они не показываются обычным пользователям.';

  @override
  String get savePetTaxiDetails => 'Сохранить сведения о зоотакси';

  @override
  String get driverVehicle => 'Водитель и автомобиль';

  @override
  String get vehicleType => 'Тип автомобиля';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get editPetShopProfile => 'Редактировать профиль зоомагазина';

  @override
  String get petShopDetails => 'Сведения о зоомагазине';

  @override
  String get shopTypes => 'Типы магазина';

  @override
  String get priceLevel => 'Уровень цен';

  @override
  String get low => 'Низкий';

  @override
  String get mid => 'Средний';

  @override
  String get high => 'Высокий';

  @override
  String get delivery => 'Доставка';

  @override
  String get hasDelivery => 'Есть доставка';

  @override
  String get offers => 'Предложения';

  @override
  String get hasOffers => 'Есть предложения';

  @override
  String get rejectedBusinesses => 'Отклонённые компании';

  @override
  String get noRejectedBusinesses => 'Отклонённых компаний нет';

  @override
  String get inheritedFromRegistration => 'Унаследовано из основной регистрации';

  @override
  String get veterinaryDetails => 'Ветеринарные сведения';

  @override
  String get licenseReviewNotice => 'Этот номер будет проверен во время верификации.';

  @override
  String get licenseExpiryDateNumbered => '12. Дата окончания лицензии';

  @override
  String get workingDaysNumbered => '20. Рабочие дни';

  @override
  String get acceptedAnimalTypesNumbered => '24. Принимаемые виды животных';

  @override
  String get confirmInformationAccurate => '41. Я подтверждаю точность предоставленной информации';

  @override
  String get agreeDisplayInformation => '42. Я согласен на отображение моих данных в приложении';

  @override
  String get agreeDisplayReviews => '43. Я согласен на отображение отзывов пользователей';

  @override
  String get acceptPartnershipTerms => '44. Я принимаю условия партнёрства PetSupo';

  @override
  String get submitVeterinaryDetails => 'Отправить ветеринарные сведения';

  @override
  String get adoptionCenterTemporary => 'Центр пристройства (ВРЕМЕННО)';

  @override
  String reviewsCountParenthesized(Object count) {
    return ' (отзывов: $count)';
  }

  @override
  String get messageSendingTimedOut => 'Время отправки сообщения истекло';

  @override
  String messageFailed(Object error) {
    return 'Не удалось отправить сообщение: $error';
  }

  @override
  String get chatCreating => 'Чат создаётся...';

  @override
  String get startChatting => 'Начните общение 👋';

  @override
  String get writeMessageHint => 'Напишите сообщение...';

  @override
  String get noChatsYet => 'Чатов пока нет';

  @override
  String get startChattingWithPetOwners => 'Общайтесь с владельцами питомцев и находите новых друзей для своего питомца 👋';

  @override
  String get failedToLoadChats => 'Не удалось загрузить чаты';

  @override
  String get personalChatsCouldNotLoad => 'Не удалось загрузить личные чаты.';

  @override
  String get businessConversations => 'Переписки с компаниями';

  @override
  String get signInToUseChats => 'Войдите, чтобы использовать чаты';

  @override
  String get chats => 'Чаты';

  @override
  String get connectWithPetOwners => 'Общайтесь с владельцами питомцев';

  @override
  String get noChatsFound => 'Чаты не найдены';

  @override
  String get tryAnotherKeyword => 'Попробуйте другое ключевое слово или имя пользователя.';

  @override
  String get messages => 'Сообщения';

  @override
  String get failedToLoadMessages => 'Не удалось загрузить сообщения';

  @override
  String get noConversationsYet => 'Переписок пока нет';

  @override
  String get userInboxEmptyDescription => 'Когда вы свяжетесь с компанией,\nпереписка появится здесь.';

  @override
  String get medicalRecords => 'Медицинские записи';

  @override
  String get vaccinesVisitsAndTreatments => 'Вакцинации, осмотры и лечение';

  @override
  String amountInTry(Object amount) {
    return '$amount тур. лир';
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
  String get payoutEligibleTab => 'Доступные';

  @override
  String get payoutBatchesTab => 'Пакеты';

  @override
  String get payoutExceptionsTab => 'Исключения';

  @override
  String get payoutSelectAllEligible => 'Выбрать всех доступных продавцов';

  @override
  String get payoutCreateBatch => 'Создать пакет выплат';

  @override
  String payoutBatchCreated(Object batchNumber) {
    return 'Пакет $batchNumber создан';
  }

  @override
  String payoutOperationFailed(Object details) {
    return 'Операция выплаты не выполнена. $details';
  }

  @override
  String get payoutLoadFailed => 'Не удалось загрузить данные выплат.';

  @override
  String get payoutNoExceptions => 'Исключений нет';

  @override
  String get payoutDateFilter => 'Период выплаты';

  @override
  String get payoutToday => 'Сегодня';

  @override
  String get payoutYesterday => 'Вчера';

  @override
  String get payoutThisWeek => 'Эта неделя';

  @override
  String get payoutLastWeek => 'Прошлая неделя';

  @override
  String get payoutThisMonth => 'Этот месяц';

  @override
  String get payoutValidBankOnly => 'Действительный банковский счёт';

  @override
  String get payoutUnknownSeller => 'Данные продавца недоступны';

  @override
  String get payoutBankMissing => 'Банк не указан';

  @override
  String get payoutIncludedOrders => 'Включённые заказы';

  @override
  String get payoutPeriod => 'Период';

  @override
  String get payoutGrossTotal => 'Сумма до комиссии';

  @override
  String get payoutCommissionTotal => 'Комиссия';

  @override
  String get payoutNetPayable => 'К выплате';

  @override
  String get payoutNoBatches => 'Пакетов выплат нет';

  @override
  String get payoutSellers => 'продавцов';

  @override
  String get payoutExportXlsx => 'Экспорт XLSX';

  @override
  String get payoutValid => 'Действительно';

  @override
  String get payoutBlocked => 'Заблокировано';

  @override
  String get payoutMissingBusiness => 'Нет данных компании';

  @override
  String get payoutMissingAccountHolder => 'Нет владельца счёта';

  @override
  String get payoutMissingIban => 'Нет IBAN';

  @override
  String get payoutInvalidIban => 'Неверный IBAN';

  @override
  String get payoutMissingBankName => 'Нет названия банка';

  @override
  String get payoutNonPositiveAmount => 'Сумма должна быть положительной';

  @override
  String get payoutSettlementIncomplete => 'Расчёт не завершён';

  @override
  String get payoutCommissionUnknown => 'Комиссия требует проверки';

  @override
  String get payoutCustomerPaid => 'Оплачено клиентом';

  @override
  String get payoutSellerNetNotCalculated => 'Нетто продавца: не рассчитано';

  @override
  String get payoutExcludedFromPayout => 'Исключено из выплаты';

  @override
  String get payoutRefundedOrCancelled => 'Возвращённый или отменённый заказ';

  @override
  String get payoutAlreadyBatched => 'Уже включено в пакет';

  @override
  String get payoutAlreadyPaid => 'Уже оплачено';

  @override
  String get payoutUnsupportedCurrency => 'Валюта не поддерживается';

  @override
  String get payoutIneligible => 'Выплата недоступна';

  @override
  String get payoutStatusFilter => 'Статус выплаты';

  @override
  String get payoutSettlementFilter => 'Статус расчёта';

  @override
  String get payoutBatchFilter => 'Платёжный пакет';

  @override
  String get payoutIncludedInBatch => 'Включено в пакет';

  @override
  String get payoutNotIncludedInBatch => 'Не включено в пакет';

  @override
  String get payoutSellerFilter => 'Продавец / компания';

  @override
  String get payoutBankFilter => 'Банк';

  @override
  String get payoutMinimumAmount => 'Минимальная выплата';

  @override
  String get payoutMaximumAmount => 'Максимальная выплата';

  @override
  String get payoutCustomRange => 'Произвольный период';

  @override
  String get financeOverviewTab => 'Обзор';

  @override
  String get financeWaitingTab => 'Ожидание';

  @override
  String get financeEligibleSellers => 'Доступные продавцы';

  @override
  String get financeEligibleRecords => 'Доступные записи';

  @override
  String get financeWaitingSellers => 'Продавцы в ожидании';

  @override
  String get financeWaitingRecords => 'Записи в ожидании';

  @override
  String get financeWaitingAmount => 'Сумма в ожидании';

  @override
  String get financeBlockedRecords => 'Заблокированные записи';

  @override
  String get financeExceptionCount => 'Исключения';

  @override
  String get financeTodaySales => 'Продажи сегодня';

  @override
  String get financeTodayCommission => 'Комиссия сегодня';

  @override
  String get financeTodayRefunds => 'Возвраты сегодня';

  @override
  String get financeTodayEligible => 'Доступно сегодня';

  @override
  String get financeTodayPaid => 'Выплачено сегодня';

  @override
  String get financeOutstandingLiability => 'Непогашенные обязательства';

  @override
  String get financeMonthlyPlatformRevenue => 'Месячный доход платформы';

  @override
  String get financeNextEligibilityDate => 'Следующая дата доступности';

  @override
  String get financeDaysRemaining => 'Осталось дней';

  @override
  String get financeOldestWaitingRecord => 'Самая старая ожидающая запись';

  @override
  String get financeAmountEligibleNext => 'Следующая доступная сумма';

  @override
  String get financeSendForReview => 'Отправить на проверку';

  @override
  String get financeApproveBatch => 'Утвердить';

  @override
  String get financeRejectBatch => 'Отклонить пакет';

  @override
  String get sellerFinanceTitle => 'Финансы и доходы';

  @override
  String get sellerFinanceDetails => 'Подробнее';

  @override
  String get sellerFinanceAvailable => 'Доступный баланс';

  @override
  String get sellerFinanceWaiting => 'Баланс в ожидании';

  @override
  String get sellerFinanceProcessing => 'В пакете / обработке';

  @override
  String get sellerFinancePaidThisMonth => 'Выплачено в этом месяце';

  @override
  String get sellerFinanceTotalEarnings => 'Общий доход';

  @override
  String get sellerFinanceBlocked => 'Заблокированная сумма';

  @override
  String get sellerFinanceBankBlocked => 'Выплата заблокирована из-за неполных банковских данных.';

  @override
  String get sellerFinanceBankReady => 'Банковский счёт готов для выплат';

  @override
  String get sellerFinanceUpdateBank => 'Обновить банковский счёт';

  @override
  String get sellerFinanceWaitingExplanation => 'Доход становится доступным через 21 день после успешной оплаты.';

  @override
  String get sellerFinanceWaitingSchedule => 'График ожидания';

  @override
  String get sellerFinanceLastPayout => 'Последняя выплата';

  @override
  String get sellerFinanceOrders => 'заказов';

  @override
  String get sellerFinanceAppointments => 'приёмов';

  @override
  String get sellerFinanceBookings => 'бронирований';

  @override
  String get sellerFinanceRides => 'поездок';

  @override
  String get sellerFinanceRequests => 'запросов';

  @override
  String get financeRecommendedAction => 'Рекомендуемое действие';

  @override
  String get financeOpenSeller => 'Открыть продавца';

  @override
  String get financeTomorrowEligible => 'Станет доступно завтра';

  @override
  String get financeNext7Days => 'Следующие 7 дней';

  @override
  String get financeNext30Days => 'Следующие 30 дней';

  @override
  String get financeEstimatedPayable => 'Расчётная выплата';

  @override
  String get financeStartProcessing => 'Начать обработку';

  @override
  String get sellerFinanceEstimatedNext => 'Расчётная следующая выплата';

  @override
  String get sellerFinanceTimeline => 'Этапы выплаты';

  @override
  String get sellerFinanceTimelineValue => 'Оплачено → Ожидание (21 день) → Доступно → В пакете → Переведено → Завершено';

  @override
  String get sellerFinanceEligibleRecords => 'Доступные записи';

  @override
  String get sellerFinancePayoutHistory => 'История выплат';

  @override
  String get sellerFinanceExceptions => 'Исключения';

  @override
  String get financeMarkFailed => 'Отметить неудачной';

  @override
  String get financeFailureReason => 'Причина сбоя';

  @override
  String get userProfileCreatorProgram => 'Программа авторов';

  @override
  String get userProfileOpenCreatorDashboard => 'Панель автора';

  @override
  String get creatorDashboardTitle => 'Панель автора';

  @override
  String get creatorWelcomeBack => 'С возвращением';

  @override
  String get creatorLevelLabel => 'Уровень автора';

  @override
  String get creatorCurrentCampaign => 'Текущая кампания';

  @override
  String get creatorReferralCodeLabel => 'Реферальный код';

  @override
  String get creatorReferralLinkLabel => 'Реферальная ссылка';

  @override
  String get creatorCopyCode => 'Копировать код';

  @override
  String get creatorCopyLink => 'Копировать ссылку';

  @override
  String get creatorReferralCodeCopied => 'Реферальный код скопирован';

  @override
  String get creatorReferralLinkCopied => 'Реферальная ссылка скопирована';

  @override
  String get creatorQualifiedUsers => 'Квалифицированные пользователи';

  @override
  String get creatorVerifiedPartners => 'Подтверждённые партнёры';

  @override
  String get creatorPendingRewards => 'Ожидающие вознаграждения';

  @override
  String get creatorPaidRewards => 'Выплаченные вознаграждения';

  @override
  String get creatorRecentActivity => 'Последние действия';

  @override
  String get creatorNoActivityYet => 'Пока нет активности';

  @override
  String get creatorNoActivityMessage => 'Как только кто-то воспользуется вашей реферальной ссылкой, активность появится здесь.';

  @override
  String get creatorUpcomingPayout => 'Ближайшая выплата';

  @override
  String get creatorEstimatedPayout => 'Ожидаемая выплата';

  @override
  String get creatorPayoutDate => 'Дата выплаты';

  @override
  String get creatorPayoutMethod => 'Способ выплаты';

  @override
  String get creatorOpenFullDashboard => 'Открыть полную панель';

  @override
  String get creatorOpenFullDashboardHint => 'Смотрите подробные графики, аналитику и отчёты в веб-версии';

  @override
  String get creatorPerformanceOverview => 'Обзор эффективности';

  @override
  String get creatorTotalClicks => 'Всего кликов';

  @override
  String get creatorRegistrations => 'Регистрации';

  @override
  String get creatorConversionRate => 'Конверсия';

  @override
  String get creatorRewardBreakdown => 'Структура вознаграждений';

  @override
  String get creatorPayoutHistory => 'История выплат';

  @override
  String get creatorAnalytics => 'Аналитика';

  @override
  String get creatorReferralsTab => 'Рефералы';

  @override
  String get creatorRewardsTab => 'Вознаграждения';

  @override
  String get creatorFilters => 'Фильтры';

  @override
  String get creatorExport => 'Экспорт';

  @override
  String get creatorTimeframe7d => '7 дней';

  @override
  String get creatorTimeframe30d => '30 дней';

  @override
  String get creatorTimeframe90d => '90 дней';

  @override
  String get creatorTimeframe12m => '12 месяцев';

  @override
  String get creatorSignInRequiredTitle => 'Требуется вход';

  @override
  String get creatorSignInRequiredMessage => 'Войдите, чтобы увидеть панель автора';

  @override
  String get creatorAccessDeniedTitle => 'Требуется доступ автора';

  @override
  String get creatorAccessDeniedMessage => 'Эта панель доступна только одобренным авторам PetSupo.';

  @override
  String get creatorGoToSignIn => 'Перейти к входу';

  @override
  String get creatorBadgesAchievements => 'Значки и достижения';

  @override
  String get creatorProgressToNextLevelPrefix => 'Прогресс до';

  @override
  String get creatorTotalEarned => 'Всего заработано';

  @override
  String get creatorShareYourLink => 'Поделитесь реферальной ссылкой';

  @override
  String get creatorStatusPaid => 'Выплачено';

  @override
  String get creatorStatusScheduled => 'Запланировано';

  @override
  String get creatorExportComingSoon => 'Экспорт скоро появится';

  @override
  String get creatorFiltersComingSoon => 'Расширенные фильтры скоро появятся';

  @override
  String get creatorStatusLabel => 'Статус';

  @override
  String get creatorStatusActive => 'Активен';

  @override
  String get creatorStatusInactive => 'Неактивен';

  @override
  String get creatorSampleData => 'Демонстрационные данные';

  @override
  String get creatorOpenDashboardFailed => 'Не удалось открыть панель. Попробуйте ещё раз.';

  @override
  String get referralCodeOptionalLabel => 'Реферальный код (необязательно)';

  @override
  String get referralCodeInvalid => 'Этот реферальный код недоступен. Можно продолжить без него.';

  @override
  String get moderationNoHistory => 'История модерации пока отсутствует';

  @override
  String get complaintNoMessages => 'Сообщений пока нет.';

  @override
  String get generatedFinanceReports => 'Созданные финансовые отчеты';

  @override
  String get noReportFilesGenerated => 'Файлы отчетов не созданы.';

  @override
  String get noEligibleSellers => 'Сейчас нет подходящих продавцов';

  @override
  String get viewWaitingSellers => 'Показать продавцов в ожидании';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get exportFinanceReport => 'Экспорт финансового отчета';

  @override
  String exportOperationFailed(Object error) {
    return 'Ошибка экспорта: $error';
  }

  @override
  String get generatedXlsx => 'Созданный XLSX';

  @override
  String get batchExportedReady => 'Пакет экспортирован и готов к обработке.';

  @override
  String get regenerate => 'Создать заново';

  @override
  String get downloadXlsx => 'Скачать XLSX';

  @override
  String previewBatch(Object batch) {
    return 'Предпросмотр $batch';
  }

  @override
  String get auditHistory => 'История аудита';

  @override
  String get noAuditEvents => 'События аудита не найдены.';

  @override
  String get settlementRetryRequested => 'Запрошена повторная попытка расчета.';

  @override
  String get financialSnapshot => 'Финансовый обзор';

  @override
  String get openOrder => 'Открыть заказ';

  @override
  String get openSeller => 'Открыть продавца';

  @override
  String get openFinancialSnapshot => 'Открыть финансовый обзор';

  @override
  String get retrySettlement => 'Повторить расчет';

  @override
  String get dateRange => 'Диапазон дат';

  @override
  String get allRecords => 'Все записи';

  @override
  String get today => 'Сегодня';

  @override
  String get thisWeek => 'Эта неделя';

  @override
  String get thisMonth => 'Этот месяц';

  @override
  String get customRange => 'Произвольный диапазон';

  @override
  String get statuses => 'Статусы';

  @override
  String get sector => 'Сектор';

  @override
  String get allSectors => 'Все секторы';

  @override
  String get petShop => 'Зоомагазин';

  @override
  String get vet => 'Ветеринар';

  @override
  String get groomy => 'Groomy';

  @override
  String get hotel => 'Отель';

  @override
  String get taxi => 'Такси';

  @override
  String get sellerBusinessIdOptional => 'ID бизнеса продавца (необязательно)';

  @override
  String get currency => 'Валюта';

  @override
  String get allCurrencies => 'Все валюты';

  @override
  String get tryCurrency => 'TRY';

  @override
  String get reportLanguage => 'Язык отчета';

  @override
  String get turkish => 'Турецкий';

  @override
  String get english => 'Английский';

  @override
  String get both => 'Оба';

  @override
  String get documentType => 'Тип документа';

  @override
  String get accountantCopy => 'Копия для бухгалтера';

  @override
  String get internalRecordsCopy => 'Копия внутренних записей';

  @override
  String get generateReports => 'Создать отчеты';

  @override
  String get download => 'Скачать';

  @override
  String get adoptionImpactOverview => 'Обзор влияния';

  @override
  String get adoptionPerformanceShelterActivity => 'Эффективность пристройства и активность приюта';

  @override
  String get noAnimalsAvailableAdoption => 'Сейчас нет животных, доступных для пристройства.\nДобавьте первое животное, чтобы начать принимать заявки.';

  @override
  String get adoptionTrend => 'Тенденция пристройства';

  @override
  String get noAdoptionsYet => 'Пристройств пока нет.';

  @override
  String get speciesBreakdown => 'Распределение по видам';

  @override
  String get speciesUnavailable => 'Вид недоступен';

  @override
  String get adopted => 'Пристроен';

  @override
  String get revenueTrend => 'Динамика доходов';

  @override
  String get noRevenueTrendYet => 'Динамика доходов пока отсутствует';

  @override
  String paymentsCount(Object count) {
    return 'Платежей: $count';
  }

  @override
  String get revenueBreakdown => 'Распределение доходов';

  @override
  String get noRevenueActivityYet => 'Доходной активности пока нет';

  @override
  String get settlementTimeline => 'Хронология расчетов';

  @override
  String waitingCount(Object count) {
    return 'В ожидании: $count';
  }

  @override
  String get noPayoutsYet => 'Выплат пока нет';

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
  String get petTaxiRouteUnavailable => 'Между выбранными местами не удалось найти автомобильный маршрут. Проверьте точки посадки и назначения.';

  @override
  String get routeEstimateUnavailable => 'Оценка маршрута сейчас недоступна. Проверьте выбранные места и попробуйте снова.';

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
  String get helpCenterTitle => 'Центр помощи';

  @override
  String get helpCenterIntro => 'Нужна помощь с PetSupo? Найдите ответы и легко свяжитесь с поддержкой.';

  @override
  String get frequentlyAskedQuestions => 'Часто задаваемые вопросы';

  @override
  String get emailAppUnavailable => 'Не удалось открыть почтовое приложение';

  @override
  String get emailCopied => 'Электронная почта скопирована';

  @override
  String get privacyPolicyContent => 'PetSupo уважает вашу конфиденциальность и стремится защищать персональные данные.\n\n1. Собираемые данные\nМы можем собирать личную информацию, данные о местоположении, питомцах, медиафайлах и устройстве.\n\n2. Использование данных\nДанные используются для работы сервисов, подбора пользователей, улучшения приложения и отправки уведомлений с вашего разрешения.\n\n3. Обмен данными\nМы не продаем персональные данные. Они передаются только надежным поставщикам или по требованию закона.\n\n4. Хранение и безопасность\nДанные безопасно хранятся на серверах в Европе.\n\n5. Срок хранения\nМы храним данные только необходимое время.\n\n6. Ваши права\nВы можете получить доступ к данным, исправить или удалить их и отозвать согласие.\n\n7. Удаление аккаунта\nСвяжитесь с нами для удаления аккаунта.\n\n8. Конфиденциальность детей\nPetSupo не предназначен для детей младше 13 лет.\n\n9. Изменения\nМы можем обновлять эту политику.\n\n10. Контакты\nПо вопросам свяжитесь с нами:';

  @override
  String get privacyContactTitle => '7. Контакты';

  @override
  String get privacyContactPrompt => 'Если у вас есть вопросы о политике конфиденциальности или ваших данных, свяжитесь с нами:';

  @override
  String get privacyResponseTime => 'Мы ответим как можно скорее.';

  @override
  String get termsEmailCopied => 'Электронная почта скопирована';

  @override
  String get termsOfServiceTitle => 'Условия использования';

  @override
  String get termsIntro => 'Используя PetSupo, вы соглашаетесь со следующими условиями:';

  @override
  String get termsResponseTime => 'Мы постараемся ответить в разумные сроки.';

  @override
  String get invoiceNumberDateRequired => 'Требуются номер и дата счета';

  @override
  String invoiceUploadFailed(Object error) {
    return 'Ошибка загрузки счета: $error';
  }

  @override
  String invoiceStatusMessage(Object status) {
    return 'Счет $status';
  }

  @override
  String invoiceReviewFailed(Object error) {
    return 'Ошибка проверки счета: $error';
  }

  @override
  String get openInvoice => 'Открыть счет';

  @override
  String get invoiceNumber => 'Номер счета';

  @override
  String get invoiceDate => 'Дата счета';

  @override
  String get invoiceType => 'Тип счета';

  @override
  String get individual => 'Физическое лицо';

  @override
  String get company => 'Компания';

  @override
  String get noteOptional => 'Примечание (необязательно)';

  @override
  String get rejectionReasonOptional => 'Причина отклонения (необязательно)';

  @override
  String get paymentSuccessTitle => 'Платеж выполнен';

  @override
  String get paymentSuccessMessage => 'Платеж успешно завершен ✅';

  @override
  String get paymentFailedTitle => 'Ошибка платежа';

  @override
  String get paymentFailedMessage => 'Не удалось проверить платеж ❌';

  @override
  String get paymentCancelledTitle => 'Платеж отменен';

  @override
  String get paymentCancelledMessage => 'Платеж был отменен ⚠️';

  @override
  String get submitComplaintTitle => 'Отправить жалобу';

  @override
  String get submitComplaintConfirmation => 'Вы уверены, что хотите отправить эту жалобу?';

  @override
  String get complaintSubmittedSuccessfully => 'Жалоба успешно отправлена';

  @override
  String get unexpectedError => 'Непредвиденная ошибка';

  @override
  String get complaintCategory => 'Категория';

  @override
  String get pleaseSelectRating => 'Выберите оценку';

  @override
  String get feedbackSubmittedSuccessfully => 'Отзыв успешно отправлен';

  @override
  String feedbackSubmissionFailed(Object error) {
    return 'Ошибка отправки: $error';
  }

  @override
  String get sendFeedback => 'Отправить отзыв';

  @override
  String get feedbackIntro => 'Помогите улучшить PetSupo своими отзывами, идеями и предложениями.';

  @override
  String get rateYourExperience => 'Оцените свой опыт';

  @override
  String get feedbackCategory => 'Категория отзыва';

  @override
  String get generalFeedback => 'Общий отзыв';

  @override
  String get bugReport => 'Сообщение об ошибке';

  @override
  String get featureRequest => 'Запрос функции';

  @override
  String get yourMessage => 'Ваше сообщение';

  @override
  String get submitFeedback => 'Отправить отзыв';

  @override
  String get memorialImageLoadFailed => 'Не удалось загрузить это изображение. Попробуйте другое фото.';

  @override
  String get createMemorial => 'Создать мемориал';

  @override
  String get memorialTitle => 'Название мемориала';

  @override
  String get storyMessage => 'История / сообщение';

  @override
  String get city => 'Город';

  @override
  String get country => 'Страна';

  @override
  String get memorialHeaderMessage => 'Почтите память любимого питомца, создав воспоминание в природе.';

  @override
  String get addPetBeforeMemorial => 'Добавьте питомца перед созданием мемориала.';

  @override
  String get addPetFirst => 'Сначала добавить питомца';

  @override
  String get choosePhoto => 'Выбрать фото';

  @override
  String get memorialPhotoPreviewMessage => 'Загрузка фото будет подключена позже. Сейчас доступен локальный просмотр.';

  @override
  String get memorialCreated => 'Мемориал создан.';

  @override
  String get greenMemorial => 'Зеленый мемориал';

  @override
  String get greenMemorialIntro => 'Посадите дерево в память о любимом питомце.';

  @override
  String memorialInMemoryOf(Object petName) {
    return 'В память о $petName 🌱';
  }

  @override
  String memorialByOwner(Object ownerName) {
    return 'Автор: $ownerName';
  }

  @override
  String get favoriteProductsTitle => 'Избранные товары';

  @override
  String get productNotFound => 'Товар не найден';

  @override
  String get sellerRatingLabel => 'Рейтинг продавца';

  @override
  String get aboutSellerTitle => 'О продавце';

  @override
  String get newestFirst => 'Сначала новые';

  @override
  String sellerProductsLoadError(Object error) {
    return 'Ошибка загрузки товаров продавца: $error';
  }

  @override
  String get sellerNoActiveProducts => 'У этого продавца нет активных товаров';

  @override
  String get sellerInitials => 'KP';

  @override
  String get passwordUpdatedSuccessfully => 'Пароль успешно обновлён';

  @override
  String get passwordStrengthLabel => 'Надёжность пароля:';

  @override
  String get changePasswordTitle => 'Изменить пароль';

  @override
  String get changePasswordDescription => 'Регулярно обновляйте пароль, чтобы защитить аккаунт PetSupo.';

  @override
  String get currentPasswordLabel => 'Текущий пароль';

  @override
  String get enterCurrentPassword => 'Введите текущий пароль';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String get enterNewPassword => 'Введите новый пароль';

  @override
  String get enterConfirmPassword => 'Подтвердите новый пароль';

  @override
  String get updatePasswordLabel => 'Обновить пароль';

  @override
  String get savedParksTitle => 'Сохранённые парки';

  @override
  String get noSavedParksYet => 'Сохранённых парков пока нет';

  @override
  String get adoptionFirstAnimal => 'Добавьте первое животное';

  @override
  String get completedAdoptionsEmpty => 'Завершённые пристройства появятся здесь.';

  @override
  String get recentlyAddedAnimals => 'Недавно добавленные животные';

  @override
  String get noAnimalsAdded => 'Животные ещё не добавлены.';

  @override
  String get speciesStatisticsEmpty => 'Статистика видов появится после первого успешного пристройства.';

  @override
  String get petTaxiEstimateDisclaimer => 'Расчёт основан на тарифе такси Стамбула и доплате за перевозку питомца. Могут добавляться сборы за мосты, автомагистрали, ожидание и услуги конкретного перевозчика. Окончательная цена будет подтверждена перевозчиком.';

  @override
  String get unblockUserTitle => 'Разблокировать пользователя';

  @override
  String unblockConfirmation(Object name) {
    return 'Вы уверены, что хотите разблокировать $name?';
  }

  @override
  String unblockSuccess(Object name) {
    return 'Пользователь $name разблокирован';
  }

  @override
  String get unblockFailed => 'Не удалось разблокировать пользователя';

  @override
  String get blockedUsersTitle => 'Заблокированные пользователи';

  @override
  String get mustBeSignedIn => 'Необходимо войти в аккаунт';

  @override
  String blockedUserCount(Object count) {
    return 'Заблокирован $count пользователь';
  }

  @override
  String blockedUsersCount(Object count) {
    return 'Заблокировано пользователей: $count';
  }

  @override
  String get blockedUsersDescription => 'Управляйте пользователями, которым вы запретили взаимодействовать с вами.';

  @override
  String get noBlockedUsers => 'Нет заблокированных пользователей';

  @override
  String get blockedUsersEmptyDescription => 'Заблокированные пользователи появятся здесь. Вы сможете разблокировать их в любое время.';

  @override
  String blockedOn(Object date) {
    return 'Заблокирован: $date';
  }

  @override
  String get unblockButton => 'Разблокировать';

  @override
  String get deleteAccountFailed => 'Не удалось удалить аккаунт. Повторите попытку.';

  @override
  String get deleteActionPermanent => 'Это действие необратимо.\n\nВсе ваши собаки, чаты, избранное и активность будут удалены навсегда.';

  @override
  String get deleteConfirmationCodeHint => 'Введите DELETE для подтверждения';

  @override
  String get deleteConfirmationCode => 'DELETE';

  @override
  String get deleteAccountPermanentNotice => 'Это действие необратимо и не может быть отменено.';

  @override
  String get whatWillBeDeleted => 'Что будет удалено';

  @override
  String get confirmation => 'Подтверждение';

  @override
  String get privacySettingsUpdated => 'Настройки конфиденциальности обновлены';

  @override
  String get privacySecurityTitle => 'Конфиденциальность и безопасность';

  @override
  String get privacySecurityDescription => 'Управляйте видимостью, обменом данными и настройками конфиденциальности аккаунта.';

  @override
  String get dataExportRequestSubmitted => 'Запрос на экспорт данных отправлен';

  @override
  String get deleteAccountDataNotice => 'Это действие нельзя отменить, и все ваши данные будут удалены навсегда.';

  @override
  String get exitAppTitle => 'Выйти из приложения?';

  @override
  String get exitAppMessage => 'Вы хотите закрыть PetSupo?';

  @override
  String get exitButton => 'Выйти';

  @override
  String get petSupoBrand => 'PetSupo';

  @override
  String get aboutUsTitle => 'О нас';

  @override
  String get aboutUsContent => 'PetSupo — цифровая платформа, созданная для общения владельцев питомцев и улучшения социальной жизни животных.\n\nПриложение помогает находить подходящих друзей для собак, открывать ближайшие ветеринарные услуги и пользоваться услугами зоомагазинов, грумеров и зоогостиниц.\n\nPetSupo не является поставщиком услуг, а лишь помогает пользователям взаимодействовать со сторонними сервисами. Пользователи самостоятельно отвечают за свои взаимодействия и решения.\n\nНаша миссия — создать безопасную, эффективную и удобную среду для владельцев питомцев по всему миру.';

  @override
  String get faqDescription => 'Найдите быстрые ответы о функциях PetSupo, конфиденциальности, подписках и безопасности.';

  @override
  String get reportTitleRequired => 'Введите заголовок';

  @override
  String get reportSubmittedSuccessfully => 'Жалоба успешно отправлена';

  @override
  String reportSendFailed(Object error) {
    return 'Не удалось отправить жалобу: $error';
  }

  @override
  String get attachScreenshot => 'Прикрепить скриншот';

  @override
  String get screenshotOptionalHint => 'Необязательно, но это поможет нам быстрее понять проблему.';

  @override
  String get reportProblemTitle => 'Сообщить о проблеме';

  @override
  String get reportProblemDescription => 'Расскажите, что пошло не так. Ваше сообщение поможет нам улучшить PetSupo.';

  @override
  String get reportIncorrectInformation => 'Неверная информация';

  @override
  String get reportPaymentIssue => 'Проблема с оплатой';

  @override
  String get submitReport => 'Отправить жалобу';

  @override
  String vetProfileLoadError(Object error) {
    return 'Ошибка загрузки: $error';
  }

  @override
  String get vetProfileUpdatedSuccessfully => 'Профиль ветеринара успешно обновлён';

  @override
  String vetProfileSaveError(Object error) {
    return 'Ошибка сохранения: $error';
  }

  @override
  String get editVetProfileTitle => 'Редактировать профиль ветеринара';

  @override
  String get suggestClinicTitle => 'Помогите развивать PetSupo';

  @override
  String suggestClinicDescription(Object vetName) {
    return 'Предложите ветеринару $vetName присоединиться к PetSupo, чтобы владельцы питомцев могли проще записываться на приём.';
  }

  @override
  String get shareInvitation => 'Поделиться приглашением';

  @override
  String get maybeLater => 'Возможно, позже';

  @override
  String get vaccineDetailsTitle => 'Сведения о вакцине';

  @override
  String get clinicCouldNotBeLoaded => 'Не удалось загрузить клинику';

  @override
  String get relatedRecords => 'Связанные записи';

  @override
  String get selectAnOption => 'Выберите вариант';

  @override
  String get enterDetails => 'Введите подробности';

  @override
  String get futureDateRequired => 'Выберите будущие дату и время.';

  @override
  String get preVisitQuestionsRequired => 'Ответьте на обязательные вопросы перед визитом.';

  @override
  String get noDetailedServicesProvided => 'Подробные услуги не указаны.';

  @override
  String get noDogsYetMatching => 'Собак пока нет — добавьте свою и начните поиск друзей! 🐾';

  @override
  String get createProfileToConnect => 'Создайте профиль, чтобы общаться 🐾';

  @override
  String unknownBusinessType(Object sectors) {
    return 'Неизвестный тип бизнеса → $sectors';
  }

  @override
  String get persianLanguage => 'فارسی';

  @override
  String get russianLanguage => 'Русский';

  @override
  String phoneAuthDebugError(Object code, Object details, Object message) {
    return 'Код: $code\n\nСообщение:\n$message\n\n$details';
  }

  @override
  String get phoneVerificationFailed => 'Не удалось завершить проверку телефона.';

  @override
  String get changeNumber => 'Изменить номер';

  @override
  String get verifyPhoneTitle => 'Подтвердить телефон';

  @override
  String enterCodeSentTo(Object phone) {
    return 'Введите код, отправленный на номер\n$phone';
  }

  @override
  String get codeLabel => 'Код';

  @override
  String get newCodeSent => 'Новый код отправлен';

  @override
  String get resendCode => 'Отправить код повторно';

  @override
  String get searchVeterinaryClinics => 'Поиск ветеринарных клиник...';

  @override
  String get howWouldYouLikeToStart => 'Как вы хотите начать?';

  @override
  String get welcomeToPetSopuWithWave => 'Добро пожаловать в PetSupo 👋';

  @override
  String get moreThanAnApp => 'Больше, чем приложение.\nДом для питомцев и их людей.';

  @override
  String get viewPremiumPlans => 'Посмотреть премиум-планы';

  @override
  String get promotionPerformanceTitle => 'Эффективность продвижения';

  @override
  String get promotionCampaignStatus => 'Статус кампании';

  @override
  String get promotionCampaignActive => 'Активна';

  @override
  String get promotionCampaignExpired => 'Истекла';

  @override
  String get promotionCampaignProcessing => 'Обрабатывается';

  @override
  String get promotionCampaignNeedsReconciliation => 'Требуется сверка';

  @override
  String get promotionSpend => 'Расходы';

  @override
  String get promotionImpressions => 'Показы';

  @override
  String get promotionClicks => 'Клики';

  @override
  String get promotionCtr => 'CTR';

  @override
  String get promotionDetailViews => 'Просмотры деталей';

  @override
  String get promotionFinancialConversions => 'Финансовые конверсии';

  @override
  String get promotionNetRevenue => 'Атрибутированный доход';

  @override
  String get promotionRoas => 'ROAS';

  @override
  String get promotionStarts => 'Начало';

  @override
  String get promotionEnds => 'Конец';

  @override
  String promotionDurationHours(Object hours) {
    return '$hours часов';
  }

  @override
  String get promotionFinancialSection => 'Финансовая эффективность';

  @override
  String get promotionFinancialAvailable => 'Финансовые показатели актуальны.';

  @override
  String get promotionFinancialProvisional => 'Финансовые показатели ещё сверяются.';

  @override
  String get promotionFinancialUnavailable => 'Финансовые показатели недоступны или неприменимы.';

  @override
  String get promotionPetFinancialNotApplicable => 'Финансовые показатели неприменимы к продвижению питомца.';

  @override
  String get promotionNoPerformanceData => 'Продвижение активно. Данные появятся после просмотров и взаимодействий пользователей.';

  @override
  String get promotionRetry => 'Повторить';

  @override
  String get promotionLoadError => 'Не удалось загрузить эффективность.';

  @override
  String get promotionUpToDate => 'Актуально';

  @override
  String get promotionReconciliationStatus => 'Сверка';

  @override
  String get promotionNa => 'Н/Д';

  @override
  String get promotionTargetPet => 'Питомец';

  @override
  String get promotionTargetProduct => 'Товар';

  @override
  String get promotionTargetVetService => 'Ветеринарная услуга';

  @override
  String get promotionTargetGroomyService => 'Услуга Groomy';

  @override
  String get petTaxiDocumentTaxPlate => 'Налоговая табличка';

  @override
  String get petTaxiDocumentBusinessRegistration => 'Регистрация бизнеса';

  @override
  String get petTaxiDocumentVehicleRegistration => 'Регистрация автомобиля';

  @override
  String get petTaxiDocumentDriverLicense => 'Водительское удостоверение';

  @override
  String get petTaxiDocumentTrafficInsurance => 'Страховка автомобиля';

  @override
  String get petTaxiDocumentStatusPendingReview => 'На проверке';

  @override
  String get petTaxiDocumentStatusApproved => 'Одобрено';

  @override
  String get petTaxiDocumentStatusRejected => 'Отклонено';

  @override
  String get petTaxiDocumentStatusMissing => 'Отсутствует';

  @override
  String get petTaxiDocumentExpired => 'Срок истёк';

  @override
  String petTaxiDocumentExpiryDate(Object date) {
    return 'Срок действия: $date';
  }

  @override
  String get petTaxiDocumentExpiredMessage => 'Срок действия этого документа истёк. Отклоните его и попросите компанию загрузить действующую замену.';

  @override
  String petTaxiRejectDocumentTitle(Object document) {
    return 'Отклонить документ «$document»';
  }

  @override
  String get petTaxiAdminErrorPermissionDenied => 'У вас нет разрешения на это действие.';

  @override
  String get petTaxiAdminErrorUnauthenticated => 'Срок действия сеанса истёк. Войдите снова.';

  @override
  String get petTaxiAdminErrorNotFound => 'Компания или документ не найдены.';

  @override
  String get petTaxiAdminErrorInvalidArgument => 'Проверьте данные документа и повторите попытку.';

  @override
  String get petTaxiAdminErrorAlreadyExists => 'Это действие уже выполнено.';

  @override
  String get petTaxiAdminErrorFailedPrecondition => 'Это действие невозможно в текущем состоянии документа.';

  @override
  String get petTaxiAdminErrorGeneric => 'Не удалось выполнить действие. Повторите попытку.';

  @override
  String get petTaxiAdminActionCompleted => 'Документ обновлён';

  @override
  String get petTaxiUploadDocument => 'Загрузить документ';

  @override
  String get petTaxiTakePhoto => 'Сделать фото';

  @override
  String get petTaxiChoosePhoto => 'Выбрать фото';

  @override
  String get petTaxiChoosePdf => 'Выбрать PDF';

  @override
  String get petTaxiSupportedDocumentFormats => 'PDF, JPG или PNG (до 25 МБ)';

  @override
  String get petTaxiUnsupportedDocumentFormat => 'Выберите документ в формате PDF, JPG или PNG.';

  @override
  String get petTaxiDocumentTooLarge => 'Размер документа превышает 25 МБ.';

  @override
  String get petTaxiDocumentUploadFailed => 'Не удалось загрузить документ. Повторите попытку.';

  @override
  String get petTaxiOpenDocumentFailed => 'Не удалось открыть этот документ.';

  @override
  String get businessRegisterOptional => 'Необязательно';

  @override
  String get businessRegisterTaxPlateRequired => 'Необходимо загрузить налоговое свидетельство.';

  @override
  String get businessRegisterMersisNumberRequired => 'Требуется номер MERSIS.';

  @override
  String get businessRegisterPhoneOptional => 'Телефон (необязательно)';

  @override
  String get businessRegisterWhatsApp => 'WhatsApp';

  @override
  String get businessRegisterDetectLocationTitle => 'Определить местоположение компании';

  @override
  String get businessRegisterDetectLocationMessage => 'Мы используем ваше местоположение, чтобы определить город и район.';

  @override
  String get petTaxiDocumentPermissionDenied => 'Доступ к камере или фотографиям запрещён. Вместо этого можно выбрать фото или PDF.';

  @override
  String get petTaxiRequiredDocuments => 'Обязательные документы';

  @override
  String get petTaxiRequiredDocumentsSubtitle => 'Документы, необходимые для ручной проверки администратором';

  @override
  String get petTaxiOptionalDocuments => 'Необязательные / условные документы';

  @override
  String get petTaxiOptionalDocumentsSubtitle => 'Загрузите их, если они относятся к вашей услуге';

  @override
  String get petTaxiComplianceTitle => 'Подтверждения соответствия и закона';

  @override
  String get petTaxiComplianceSubtitle => 'Обязательные подтверждения перед отправкой';

  @override
  String get petTaxiPetSafetyEquipmentConfirmation => 'Подтверждаю наличие оборудования для безопасности животных в автомобиле.';

  @override
  String get petTaxiHygieneConfirmation => 'Подтверждаю соблюдение требований гигиены.';

  @override
  String get petTaxiDriverLicenseConfirmation => 'Подтверждаю, что водительские права действительны.';

  @override
  String get petTaxiVehicleRegistrationConfirmation => 'Подтверждаю, что регистрация автомобиля относится к транспортному средству услуги.';

  @override
  String get petTaxiTrafficInsuranceConfirmation => 'Подтверждаю, что страховка автомобиля действительна.';

  @override
  String get petTaxiTaxResponsibilityConfirmation => 'Подтверждаю, что налоговые обязательства и ответственность за счета или чеки относятся к моей компании.';

  @override
  String get petTaxiTransportRulesConfirmation => 'Подтверждаю соблюдение правил перевозки города и страны.';

  @override
  String get petTaxiComplianceNotes => 'Примечания для проверки администратором';

  @override
  String get petTaxiOptionalIfApplicable => 'Необязательно / если применимо';

  @override
  String petTaxiDocumentRequired(Object document) {
    return 'Требуется документ: $document';
  }

  @override
  String petTaxiDateRequired(Object date) {
    return 'Требуется дата: $date';
  }

  @override
  String petTaxiDateCannotBePast(Object date) {
    return 'Дата $date не может быть в прошлом';
  }

  @override
  String get petTaxiDocumentNumber => 'Номер документа';

  @override
  String get petTaxiDocumentNumberOptional => 'Номер документа (необязательно)';

  @override
  String get petTaxiDocumentNumberRequired => 'Требуется номер документа';

  @override
  String get petTaxiVehicleRegistrationIssueDate => 'Дата выдачи регистрации автомобиля';

  @override
  String get petTaxiDriverLicenseExpiryDate => 'Срок действия водительских прав';

  @override
  String get petTaxiTrafficInsuranceExpiryDate => 'Срок действия страховки автомобиля';

  @override
  String get petTaxiSrcCertificateExpiryDate => 'Срок действия сертификата SRC';

  @override
  String get petTaxiPsychotechnicalExpiryDate => 'Срок действия психотехнического отчёта';

  @override
  String get petTaxiKaskoExpiryDate => 'Срок действия каско';

  @override
  String get petTaxiValidTurkishPlate => 'Введите действительный турецкий номер автомобиля.';

  @override
  String get petTaxiRequiredDocumentsMissing => 'Загрузите все обязательные документы Pet Taxi.';

  @override
  String get petTaxiComplianceConfirmationsMissing => 'Подтвердите все обязательные заявления о соответствии.';

  @override
  String get petTaxiValidPhoneNumber => 'Введите действительный номер телефона.';

  @override
  String get petTaxiValidCapacity => 'Введите действительную вместимость автомобиля.';

  @override
  String get petTaxiCapacityMinimum => 'Вместимость автомобиля должна быть не менее 1.';

  @override
  String get petTaxiCapacityMaximum => 'Вместимость автомобиля не может превышать 15.';

  @override
  String get petTaxiSelectVehicleType => 'Выберите тип автомобиля.';

  @override
  String get petTaxiDriverFullName => 'Полное имя водителя';

  @override
  String get petTaxiDriverPhoneNumber => 'Телефон водителя';

  @override
  String get petTaxiVehiclePlateNumber => 'Номер автомобиля';

  @override
  String get petTaxiVehicleCapacity => 'Вместимость автомобиля';

  @override
  String get petTaxiVehicleSedan => 'Седан';

  @override
  String get petTaxiVehicleHatchback => 'Хэтчбек';

  @override
  String get petTaxiVehicleSuv => 'Внедорожник';

  @override
  String get petTaxiVehicleVan => 'Фургон';

  @override
  String get petTaxiVehiclePetTransportVan => 'Фургон для перевозки животных';

  @override
  String get petTaxiVehicleLargeAnimalTransport => 'Транспорт для крупных животных';
}
