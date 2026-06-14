// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get userNotLoggedIn => 'Kullanıcı giriş yapmadı. Giriş sayfasına yönlendiriliyor...';

  @override
  String errorLoadingUserInfo(Object error) {
    return 'Kullanıcı bilgileri yüklenirken hata: $error';
  }

  @override
  String errorLoadingDogs(Object error) {
    return 'Köpekler yüklenirken hata: $error';
  }

  @override
  String get usernameCannotBeEmpty => 'Kullanıcı adı boş olamaz';

  @override
  String get profileUpdatedSuccessfully => 'Profil başarıyla güncellendi';

  @override
  String errorUpdatingDog(Object error) {
    return 'Köpek güncellenirken hata: $error';
  }

  @override
  String errorDeletingAccount(Object error) {
    return 'Hesap silinirken hata: $error';
  }

  @override
  String get accountDeleted => 'Hesap silindi.';

  @override
  String errorDuringLogout(Object error) {
    return 'Çıkış sırasında hata: $error';
  }

  @override
  String get cartTitle => 'Sepetim';

  @override
  String get cartIsEmpty => 'Sepet boş';

  @override
  String get totalLabel => 'Toplam';

  @override
  String get checkoutButton => 'Ödeme';

  @override
  String get checkoutStepAddressTitle => 'Adres';

  @override
  String get checkoutStepPaymentTitle => 'Ödeme';

  @override
  String get checkoutStepConfirmTitle => 'Onay';

  @override
  String get checkoutDeliveryAddressTitle => 'Teslimat Adresi';

  @override
  String get checkoutFullNameLabel => 'Ad Soyad';

  @override
  String get checkoutFullNameHint => 'Ad Soyad';

  @override
  String get checkoutPhoneHint => '5XXXXXXXXX';

  @override
  String get checkoutCityLabel => 'Şehir';

  @override
  String get checkoutCityHint => 'İstanbul';

  @override
  String get checkoutDistrictLabel => 'İlçe';

  @override
  String get checkoutDistrictHint => 'Kadıköy';

  @override
  String get checkoutAddressLabel => 'Açık Adres';

  @override
  String get checkoutAddressHint => 'Açık adres detayları';

  @override
  String get checkoutInvoiceDetailsTitle => 'Fatura Bilgileri';

  @override
  String get checkoutIndividualOption => 'Bireysel';

  @override
  String get checkoutCompanyOption => 'Şirket';

  @override
  String get checkoutIdentityNumberLabel => 'Kimlik Numarası';

  @override
  String get checkoutIdentityNumberHint => '11 haneli';

  @override
  String get checkoutCompanyNameLabel => 'Şirket Adı';

  @override
  String get checkoutTaxNumberLabel => 'Vergi Numarası';

  @override
  String get checkoutTaxNumberHint => '10 haneli';

  @override
  String get checkoutTaxOfficeLabel => 'Vergi Dairesi';

  @override
  String get checkoutCargoUpdatesTitle => 'Fatura ve Kargo Güncellemeleri';

  @override
  String get checkoutCargoUpdatesQuestion => 'Fatura ve kargo takip güncellemelerini nasıl gönderelim?';

  @override
  String get checkoutSmsOption => 'SMS';

  @override
  String get checkoutEmailOption => 'E-posta';

  @override
  String get checkoutSmsEmailOption => 'SMS + E-posta';

  @override
  String get checkoutAgreementsTitle => 'Sözleşmeler';

  @override
  String get checkoutKvkkDisclosure => 'KVKK aydınlatmasını okudum';

  @override
  String get checkoutViewButton => 'Gör';

  @override
  String get checkoutPreInfoForm => 'Ön bilgilendirme formunu kabul ediyorum';

  @override
  String get checkoutDistanceSalesAgreement => 'Mesafeli satış sözleşmesini kabul ediyorum';

  @override
  String get checkoutMarketingOptional => 'Pazarlama mesajları almak istiyorum (isteğe bağlı)';

  @override
  String get checkoutDeliveryTitle => 'Teslimat';

  @override
  String get checkoutPaymentSummaryTitle => 'Ödeme Özeti';

  @override
  String get checkoutSubtotalLabel => 'Ara Toplam';

  @override
  String get checkoutVatLabel => 'KDV';

  @override
  String get checkoutShippingLabel => 'Kargo';

  @override
  String get checkoutPleaseSelectCargoCompany => 'Lütfen bir kargo şirketi seçin';

  @override
  String get checkoutEnterNameSurname => 'Ad ve soyad girin';

  @override
  String get checkoutEnterValidEmail => 'Geçerli e-posta girin';

  @override
  String get checkoutEnterValidPhone => 'Geçerli telefon girin';

  @override
  String get checkoutEnterCity => 'Şehir girin';

  @override
  String get checkoutEnterDistrict => 'İlçe girin';

  @override
  String get checkoutEnterFullAddress => 'Tam adres girin';

  @override
  String get checkoutEnterValidIdentityNumber => 'Geçerli kimlik numarası girin';

  @override
  String get checkoutEnterCompanyName => 'Şirket adı girin';

  @override
  String get checkoutEnterValidTaxNumber => 'Geçerli vergi numarası girin';

  @override
  String get checkoutEnterTaxOffice => 'Vergi dairesi girin';

  @override
  String get checkoutAcceptRequiredAgreements => 'Gerekli sözleşmeleri kabul edin';

  @override
  String get checkoutPaymentPageOpenedMessage => 'Ödeme sayfası açıldı. Ödemeyi tamamlayıp uygulamaya geri dönün.';

  @override
  String get checkoutBackButton => 'Geri';

  @override
  String get checkoutProceedToPayment => 'Ödemeye Geç';

  @override
  String get checkoutContinueButton => 'Devam';

  @override
  String get checkoutPaymentCompletedSuccessfully => 'Ödeme başarıyla tamamlandı';

  @override
  String get checkoutPaymentCancelledOrIncomplete => 'Ödeme iptal edildi veya tamamlanmadı';

  @override
  String checkoutFailed(Object error) {
    return 'Ödeme işlemi başarısız oldu: $error';
  }

  @override
  String adoptionRequestSent(Object dogName) {
    return '$dogName için sahiplenme talebi gönderildi!';
  }

  @override
  String get adoptionCentersTitle => 'Sahiplendirme Merkezleri';

  @override
  String get availableDogsTitle => 'Mevcut Köpekler';

  @override
  String get noAdoptionCentersAvailable => 'Mevcut sahiplenme merkezi yok';

  @override
  String get noDogsAvailableInThisCenter => 'Bu merkezde mevcut köpek yok';

  @override
  String get adoptionRequestTitle => 'Sahiplenme Talebi';

  @override
  String get yourPhone => 'Telefon Numaranız';

  @override
  String get whyDoYouWantToAdopt => 'Neden sahiplenmek istiyorsunuz?';

  @override
  String get appointmentTitle => 'Randevu';

  @override
  String get cancelAppointmentButton => 'Randevuyu İptal Et';

  @override
  String get cancelAppointmentTitle => 'Randevu iptal edilsin mi?';

  @override
  String get cancelAppointmentConfirmation => 'Bu randevuyu iptal etmek istediğinizden emin misiniz?';

  @override
  String get keepAppointmentButton => 'Randevuyu Koru';

  @override
  String get appointmentCancelled => 'Randevu iptal edildi';

  @override
  String get cancellationNotAllowed => 'Bu randevu için iptal yapılamaz.';

  @override
  String get cancelAppointmentFailed => 'Randevu iptal edilemedi. Lütfen tekrar deneyin.';

  @override
  String get selectService => 'Hizmet Seçin';

  @override
  String get selectPet => 'Evcil Hayvan Seçin';

  @override
  String get dateAndTime => 'Tarih ve Saat';

  @override
  String get notesOptional => 'Notlar (isteğe bağlı)';

  @override
  String get selectDate => 'Tarih Seçin';

  @override
  String get selectTime => 'Saat Seçin';

  @override
  String get appointmentNoteHint => 'Klinik için bir not ekleyin...';

  @override
  String get requestAppointment => 'Randevu Talep Et';

  @override
  String get requestSentTitle => 'İstek Gönderildi 🐾';

  @override
  String get requestSentMessage => 'Randevu talebiniz kliniğe gönderildi.';

  @override
  String get okButton => 'OK';

  @override
  String get somethingWentWrong => 'Bir şeyler ters gitti';

  @override
  String get alreadyBookedAtThisTime => 'Bu saatte zaten bir rezervasyonunuz var. Lütfen başka bir saat seçin.';

  @override
  String get invalidBookingData => 'Geçersiz rezervasyon verisi. Lütfen tekrar deneyin.';

  @override
  String get serviceDefaultLabel => 'Hizmet';

  @override
  String get ageYearsSuffix => ' yaş';

  @override
  String get overviewTitle => 'Genel Bakış';

  @override
  String get servicesTitle => 'Hizmetler';

  @override
  String get reviewsTitle => 'Yorumlar';

  @override
  String get galleryTitle => 'Galeri';

  @override
  String get shopTitle => 'Mağaza';

  @override
  String get aboutTitle => 'Hakkında';

  @override
  String get workingHoursTitle => 'Çalışma Saatleri';

  @override
  String get locationTitle => 'Konum';

  @override
  String get instagramTitle => 'Instagram';

  @override
  String get noClinicDescriptionAvailable => 'Klinik açıklaması mevcut değil.';

  @override
  String get instagramNotAvailable => 'Instagram mevcut değil.';

  @override
  String get workingHoursNotAvailable => 'Çalışma saatleri mevcut değil';

  @override
  String get openStatusOpen => 'Açık';

  @override
  String get openStatusClosingSoon => 'Kapanıyor';

  @override
  String get openStatusClosed => 'Kapalı';

  @override
  String get mostRelevant => 'En alakalı';

  @override
  String get newest => 'En yeni';

  @override
  String get bookAppointment => 'Randevu Al';

  @override
  String get noServicesAvailable => 'Mevcut hizmet yok';

  @override
  String errorLoadingServices(Object error) {
    return 'Hizmetler yüklenirken hata: $error';
  }

  @override
  String get noServicesProvided => 'Sağlanan hizmet yok.';

  @override
  String reviewsCountLabel(Object count) {
    return '$count yorum';
  }

  @override
  String get topLabel => 'En iyi';

  @override
  String get mostHelpful => 'En faydalı';

  @override
  String get couldNotUpdateLike => 'Beğeni güncellenemedi';

  @override
  String get justNow => 'Az önce';

  @override
  String get noReviewsYet => 'Henüz yorum yok';

  @override
  String get beFirstToReview => 'İlk yorumu siz yapın';

  @override
  String get submit => 'Gönder';

  @override
  String get writeAReview => 'Yorum yaz';

  @override
  String get shareYourExperienceHint => 'Deneyiminizi paylaşın...';

  @override
  String get pleaseWriteSomething => 'Lütfen bir şey yazın';

  @override
  String get pleaseLoginFirst => 'Lütfen önce giriş yapın';

  @override
  String get alreadyReviewedThisVet => 'Bu veterineri zaten değerlendirdiniz';

  @override
  String get errorSubmittingReview => 'Yorum gönderilirken hata';

  @override
  String errorLoadingReviews(Object error) {
    return 'Yorumlar yüklenirken hata: $error';
  }

  @override
  String get galleryNotAvailable => 'Galeri mevcut değil.';

  @override
  String get noGalleryMediaYet => 'Henüz galeri medyası yok.';

  @override
  String get shopSectionComingSoon => 'Mağaza bölümü buraya bağlanacak.';

  @override
  String durationMinutesShort(Object minutes) {
    return '$minutes dk';
  }

  @override
  String get myProfile => 'Profilim';

  @override
  String get userProfile => 'Kullanıcı Profili';

  @override
  String get profileInformation => 'Profil Bilgileri';

  @override
  String get myDogs => 'Köpeklerim';

  @override
  String get dogsAvailableForAdoption => 'Sahiplenmek için mevcut köpekler';

  @override
  String get editProfile => 'Profili Düzenle';

  @override
  String get usernameLabel => 'Kullanıcı Adı';

  @override
  String get emailLabel => 'E-posta';

  @override
  String get phoneLabel => 'Telefon Numarası';

  @override
  String get enterPhoneNumberOptional => 'Telefon numarasını girin (isteğe bağlı)';

  @override
  String get deleteAccount => 'Hesabı Sil';

  @override
  String get deleteAccountConfirmation => 'Hesabınızı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get updateProfile => 'Profili Güncelle';

  @override
  String get editProfileTooltip => 'Profili Düzenle';

  @override
  String get deleteAccountTooltip => 'Hesabı Sil';

  @override
  String get logoutTooltip => 'Çıkış Yap';

  @override
  String get noDogsAvailableForAdoption => 'Sahiplenmek için köpek bulunamadı.';

  @override
  String get unknownUser => 'Bilinmeyen Kullanıcı';

  @override
  String get notProvided => 'Sağlanmadı';

  @override
  String get noDogsAddedYet => 'Henüz köpek eklenmedi.';

  @override
  String get appTitle => 'Barky Matches';

  @override
  String get loadingUserData => 'Kullanıcı verileri yükleniyor...';

  @override
  String get welcomeToPetSopu => 'Barky Matches\'e hoş geldiniz!';

  @override
  String get welcomeTo => 'Hoş geldiniz';

  @override
  String get petSopu => 'Barky Matches';

  @override
  String welcomeBack(Object username) {
    return 'Tekrar hoş geldiniz, $username!';
  }

  @override
  String helloMessage(Object username) {
    return 'Merhaba, $username!';
  }

  @override
  String get signInTitle => 'Giriş Yap';

  @override
  String get signUpTitle => 'Kayıt Ol';

  @override
  String get signInButton => 'Giriş Yap';

  @override
  String get signUpButton => 'Kayıt Ol';

  @override
  String get continueAsGuest => 'Misafir olarak devam et';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get confirmPasswordLabel => 'Şifreyi Onayla';

  @override
  String get rememberMeLabel => 'Beni Hatırla';

  @override
  String get forgotPasswordLabel => 'Şifremi Unuttum?';

  @override
  String get termsAndConditionsLabel => 'Şartlar ve Koşulları kabul ediyorum';

  @override
  String get termsAndConditionsPrefix => 'Şunları kabul ediyorum: ';

  @override
  String get termsAndConditionsText => 'Şartlar ve Koşullar';

  @override
  String get receiveNewsLabel => 'Haberler ve güncellemeler al';

  @override
  String get emailRequired => 'Lütfen e-postanızı girin';

  @override
  String get emailInvalid => 'Lütfen geçerli bir e-posta girin';

  @override
  String get usernameRequired => 'Lütfen kullanıcı adınızı girin';

  @override
  String get phoneRequired => 'Lütfen telefon numaranızı girin';

  @override
  String get phoneNumberTooShort => 'Telefon numarası çok kısa';

  @override
  String get phoneMinDigits => 'Telefon numarası en az 10 haneli olmalıdır';

  @override
  String get passwordRequired => 'Lütfen şifrenizi girin';

  @override
  String get passwordValidation => 'Şifre en az 8 karakter olmalı ve hem harf hem de sayı içermelidir';

  @override
  String get passwordMismatch => 'Şifreler eşleşmiyor';

  @override
  String get confirmPasswordRequired => 'Lütfen şifrenizi onaylayın';

  @override
  String get termsRequired => 'Şartlar ve Koşulları kabul etmelisiniz';

  @override
  String get forgotPasswordDialogTitle => 'Şifremi Unuttum';

  @override
  String get forgotPasswordDialogMessage => 'Şifrenizi sıfırlamak için lütfen e-postanızı girin.';

  @override
  String get sendButton => 'Gönder';

  @override
  String passwordResetSent(Object email) {
    return '$email adresine şifre sıfırlama e-postası gönderildi';
  }

  @override
  String get emailAddressHint => 'E-posta adresi';

  @override
  String get passwordResetEmailSent => 'Şifre sıfırlama e-postası gönderildi 📩';

  @override
  String get noAccountSignUp => 'Hesabınız yok mu? Kayıt Ol';

  @override
  String get haveAccountSignIn => 'Zaten hesabınız var mı? Giriş Yap';

  @override
  String get userNotFound => 'Bu e-posta ile kullanıcı bulunamadı. Lütfen kayıt olun.';

  @override
  String get authUserNotFound => 'Kullanıcı bulunamadı';

  @override
  String get pleaseVerifyEmailBeforeSigningIn => 'Giriş yapmadan önce lütfen e-postanızı doğrulayın.';

  @override
  String get userCreationFailed => 'Kullanıcı oluşturulamadı';

  @override
  String get verificationEmailCouldNotBeSent => 'Doğrulama e-postası gönderilemedi';

  @override
  String get verificationSessionCouldNotBeCreated => 'Doğrulama oturumu oluşturulamadı';

  @override
  String get emailAlreadyRegisteredTryLoggingIn => 'Bu e-posta zaten kayıtlı. Giriş yapmayı deneyin.';

  @override
  String get incorrectPassword => 'Yanlış şifre. Lütfen tekrar deneyin.';

  @override
  String get fillAllFields => 'Lütfen tüm alanları doğru şekilde doldurun';

  @override
  String errorOccurred(Object error) {
    return 'Bir hata oluştu: $error';
  }

  @override
  String get verifyEmailTitle => 'E-postanızı Doğrulayın';

  @override
  String get enterVerificationCodeSentToEmail => 'E-postanıza gönderilen doğrulama kodunu girin';

  @override
  String get pleaseEnterSixDigitCode => 'Lütfen 6 haneli kodu girin';

  @override
  String get emailVerifiedSuccessfully => 'E-posta başarıyla doğrulandı';

  @override
  String get invalidVerificationCode => 'Geçersiz doğrulama kodu';

  @override
  String verificationCodeSent(Object email) {
    return '$email adresine bir doğrulama kodu gönderildi';
  }

  @override
  String get enterCodeLabel => '6 haneli kodu girin';

  @override
  String get verifyButton => 'Doğrula';

  @override
  String get authWelcomeBackSubtitle => 'BarkyMatches\'a tekrar hoş geldiniz';

  @override
  String get authCreateAccountSubtitle => 'BarkyMatches hesabınızı oluşturun';

  @override
  String get sessionExpiredPleaseSignInAgain => 'Oturumunuz sona erdi. Lütfen tekrar giriş yapın.';

  @override
  String get signInToAccessPlaymate => 'Playmate\'e erişmek için lütfen giriş yapın';

  @override
  String get findPlaymates => 'Arkadaş Bul';

  @override
  String get signInToFindFriends => 'Evcil hayvanın için arkadaş bul';

  @override
  String get addYourDog => 'Köpeğinizi Ekleyin';

  @override
  String get nameLabel => 'İsim *';

  @override
  String get pleaseEnterDogName => 'Lütfen köpeğinizin ismini girin';

  @override
  String get selectBreedHint => 'Irk Seçin';

  @override
  String get pleaseSelectBreed => 'Lütfen bir ırk seçin';

  @override
  String get ageLabel => 'Yaş *';

  @override
  String get pleaseEnterDogAge => 'Lütfen köpeğinizin yaşını girin';

  @override
  String get pleaseEnterValidAge => 'Lütfen geçerli bir yaş girin';

  @override
  String get selectGenderHint => 'Cinsiyet Seçin';

  @override
  String get pleaseSelectGender => 'Lütfen bir cinsiyet seçin';

  @override
  String get selectHealthStatusHint => 'Sağlık Durumu Seçin';

  @override
  String get pleaseSelectHealthStatus => 'Lütfen bir sağlık durumu seçin';

  @override
  String get neuteredLabel => 'Kısırlaştırma *';

  @override
  String get yes => 'Evet';

  @override
  String get no => 'Hayır';

  @override
  String get pleaseSpecifyNeutered => 'Lütfen köpeğin kısırlaştırılıp kısırlaştırılmadığını belirtin';

  @override
  String get traitsLabel => 'Özellikler *';

  @override
  String get pleaseSelectAtLeastOneTrait => 'Lütfen en az bir özellik seçin';

  @override
  String get selectOwnerGenderHint => 'Sahip Cinsiyeti';

  @override
  String get pleaseSelectOwnerGender => 'Lütfen cinsiyetinizi seçin';

  @override
  String get uploadImagesLabel => 'Resim Yükle';

  @override
  String get pickFromGallery => 'Galeriden Seç';

  @override
  String get takePhoto => 'Fotoğraf Çek';

  @override
  String get availableForAdoption => 'Sahiplenmek için Uygun';

  @override
  String get descriptionLabel => 'Açıklama';

  @override
  String get descriptionPlaceholder => 'Buraya bir açıklama girin...';

  @override
  String get colorLabel => 'Renk';

  @override
  String get weightLabel => 'Ağırlık (kg)';

  @override
  String get selectCollarTypeHint => 'Tasma Tipi Seçin';

  @override
  String get clothingColorLabel => 'Kıyafet Rengi';

  @override
  String get lostLocationLabel => 'Kayıp Konumu *';

  @override
  String get foundLocationLabel => 'Bulunan Konum *';

  @override
  String get contactInfoLabel => 'İletişim Bilgileri *';

  @override
  String get editDog => 'Köpeği Düzenle';

  @override
  String get photosLabel => 'Fotoğraflar';

  @override
  String get chooseFromGallery => 'Galeriden seçin';

  @override
  String get takeAPhoto => 'Fotoğraf çekin';

  @override
  String get noMedia => 'Medya yok';

  @override
  String get save => 'Kaydet';

  @override
  String dogNameAlreadyExists(Object name) {
    return '$name adında bir köpek zaten mevcut!';
  }

  @override
  String get locationRequired => 'Köpek eklemek için konum gerekli.';

  @override
  String errorUploadingImage(Object error) {
    return 'Resim yüklenirken hata: $error';
  }

  @override
  String errorAddingDog(Object error) {
    return 'Köpek eklenirken hata: $error';
  }

  @override
  String get pleaseFillRequiredFields => 'Lütfen tüm gerekli alanları doğru şekilde doldurun';

  @override
  String get addDogButton => 'Köpek Ekle';

  @override
  String get dogDetailsAddTitle => 'Köpek Ekle';

  @override
  String get dogDetailsEditTitle => 'Köpeği Düzenle';

  @override
  String get dogDetailsNameLabel => 'İsim';

  @override
  String get dogDetailsAgeLabel => 'Yaş';

  @override
  String get dogDetailsDescriptionLabel => 'Açıklama';

  @override
  String get dogDetailsGenderLabel => 'Cinsiyet:';

  @override
  String get dogDetailsHealthLabel => 'Sağlık Durumu:';

  @override
  String get dogDetailsTraitsLabel => 'Özellikler:';

  @override
  String get dogDetailsOwnerGenderLabel => 'Sahip Cinsiyeti:';

  @override
  String get dogDetailsGenderMale => 'Erkek';

  @override
  String get dogDetailsGenderFemale => 'Dişi';

  @override
  String get dogDetailsHealthHealthy => 'Sağlıklı';

  @override
  String get dogDetailsHealthNeedsCare => 'Bakım Gerekiyor';

  @override
  String get dogDetailsHealthUnderTreatment => 'Tedavi Altında';

  @override
  String get dogDetailsOwnerGenderPreferNotToSay => 'Söylememeyi tercih ederim';

  @override
  String get dogDetailsPickImageButton => 'Resim Seç';

  @override
  String get dogDetailsAddButton => 'Köpek Ekle';

  @override
  String get dogDetailsUpdateButton => 'Köpeği Güncelle';

  @override
  String get dogDetailsNeuteredLabel => 'Kısırlaştırma:';

  @override
  String get dogDetailsAdoptionLabel => 'Sahiplenmek için Uygun:';

  @override
  String get editDogPermissionDenied => 'Bu köpeği düzenleme izniniz yok.';

  @override
  String get editDogEnterName => 'Lütfen köpeğin ismini girin';

  @override
  String get editDogEnterValidAge => 'Lütfen geçerli bir yaş girin';

  @override
  String get editDogOwnerGenderMale => 'Erkek';

  @override
  String get editDogOwnerGenderFemale => 'Dişi';

  @override
  String get editDogOwnerGenderOther => 'Diğer';

  @override
  String get findPlaymateTitle => 'Oyun Arkadaşı Bul';

  @override
  String get noDogsMatchFilters => 'Filtrelerinize uyan köpek bulunamadı.';

  @override
  String get adjustFiltersSuggestion => 'Filtrelerinizi ayarlamayı veya mesafeyi artırmayı deneyin.';

  @override
  String get anyGender => 'Herhangi';

  @override
  String distanceLabel(Object distance) {
    return 'Mesafe: $distance km';
  }

  @override
  String get resetFiltersButton => 'Filtreleri Sıfırla';

  @override
  String get basketTitle => 'Sepet';

  @override
  String basketItemsCount(Object count) {
    return '$count ürün';
  }

  @override
  String get yourBasketIsEmpty => 'Sepetiniz boş';

  @override
  String get sellerLabel => 'Satıcı';

  @override
  String get allProductsTitle => 'Tüm Ürünler';

  @override
  String get sellerProductsTitle => 'Satıcının Ürünleri';

  @override
  String get searchProductsHint => 'Ürün, marka, satıcı ara...';

  @override
  String get allCategoriesLabel => 'Tüm Kategoriler';

  @override
  String get categoryLabel => 'Kategori';

  @override
  String get shippingLabel => 'Kargo';

  @override
  String get freeShippingLabel => 'Ücretsiz kargo';

  @override
  String get sellerPaysCargoLabel => 'Kargoyu satıcı öder';

  @override
  String get fixedCargoLabel => 'Sabit kargo';

  @override
  String get calculatedCargoLabel => 'Hesaplanan kargo';

  @override
  String get sortLabel => 'Sırala';

  @override
  String get recommendedLabel => 'Önerilen';

  @override
  String get priceLowLabel => 'Fiyat düşük';

  @override
  String get priceHighLabel => 'Fiyat yüksek';

  @override
  String get bestDiscountLabel => 'En iyi indirim';

  @override
  String productsCount(Object count) {
    return '$count ürün';
  }

  @override
  String get noProductsMatchFilters => 'Filtrelerinizle eşleşen ürün yok';

  @override
  String errorLoadingProducts(Object error) {
    return 'Ürünler yüklenirken hata: $error';
  }

  @override
  String get noActiveProductsFound => 'Aktif ürün bulunamadı';

  @override
  String addedToBasket(Object productName) {
    return '$productName sepete eklendi';
  }

  @override
  String get addButton => 'Ekle';

  @override
  String get freeCargoLabel => 'Ücretsiz kargo';

  @override
  String cargoPriceLabel(Object price) {
    return 'Kargo $price';
  }

  @override
  String get cargoCalculatedLabel => 'Hesaplanan kargo';

  @override
  String freeOverLabel(Object price) {
    return '$price üzeri ücretsiz';
  }

  @override
  String vatRateLabel(Object percent) {
    return 'KDV %$percent';
  }

  @override
  String get vatIncludedLabel => 'KDV dahil';

  @override
  String daysLabel(Object days) {
    return '$days gün';
  }

  @override
  String get inStockLabel => 'Stokta';

  @override
  String get outOfStockLabel => 'Tükendi';

  @override
  String get subtotalLabel => 'Ara Toplam';

  @override
  String get moreFiltersButton => 'Daha Fazla Filtre';

  @override
  String get petTypeLabel => 'Evcil Hayvan Türü';

  @override
  String get petTypeDog => 'Köpek';

  @override
  String get petTypeCat => 'Kedi';

  @override
  String get petTypeBird => 'Kuş';

  @override
  String get petTypeHorse => 'At';

  @override
  String get genderOther => 'Diğer';

  @override
  String get breedPersian => 'Persian';

  @override
  String get breedSiamese => 'Siyam';

  @override
  String get breedMaineCoon => 'Maine Coon';

  @override
  String get breedBritishShorthair => 'British Shorthair';

  @override
  String get breedParrot => 'Papağan';

  @override
  String get breedCanary => 'Kanarya';

  @override
  String get breedBudgerigar => 'Muhabbet kuşu';

  @override
  String get breedArabian => 'Arap';

  @override
  String get breedThoroughbred => 'Safkan';

  @override
  String get breedMustang => 'Mustang';

  @override
  String get filterByBreed => 'Irka Göre Filtrele';

  @override
  String get filterByGender => 'Cinsiyete Göre Filtrele';

  @override
  String get filterByAge => 'Yaşa Göre Filtrele';

  @override
  String get filterByNeuteredStatus => 'Kısırlaştırma Durumuna Göre Filtrele';

  @override
  String get selectNeuteredStatusHint => 'Kısırlaştırma Durumu Seçin';

  @override
  String get filterByHealthStatus => 'Sağlık Durumuna Göre Filtrele';

  @override
  String get upgradeToPremiumForMoreFilters => 'Daha fazla filtre için Premium\'a yükseltin!';

  @override
  String get upgradeToPremiumTitle => 'Premium\'a Yükseltin';

  @override
  String get upgradeToPremiumSubtitle => 'Gelişmiş özellikler ve işletme araçlarının kilidini açın';

  @override
  String get apply => 'Uygula';

  @override
  String get favoritesPageTitle => 'Favori Köpekler';

  @override
  String get noFavoriteDogsYet => 'Henüz favori köpek yok!';

  @override
  String get addFavoriteSuggestion => 'Ana sayfaya dönün ve bazı köpekleri favorilerinize ekleyin.';

  @override
  String get removeFavoriteTooltip => 'Favoriden Kaldır';

  @override
  String get schedulePlaydate => 'Oyun Randevusu Planla';

  @override
  String get selectDateAndTime => 'Tarih ve Saat Seçin';

  @override
  String get pickDate => 'Tarih Seç';

  @override
  String get pickTime => 'Saat Seç';

  @override
  String get selectYourDogHint => 'Köpeğinizi seçin';

  @override
  String get selectFriendsDogHint => 'Arkadaşın köpeğini seçin';

  @override
  String get selectYourDog => 'Köpeğinizi Seçin';

  @override
  String get selectFriendsDog => 'Arkadaşın Köpeğini Seçin';

  @override
  String get pleaseLoginToSchedulePlaydate => 'Oyun randevusu planlamak için lütfen giriş yapın';

  @override
  String get selectLocation => 'Konum Seç';

  @override
  String get enterLocation => 'Konum girin (örneğin: Enlem: 41.0103, Boylam: 28.6724 veya adres)';

  @override
  String get pickOnMap => 'Haritadan Seç';

  @override
  String get quickLocations => 'Hızlı Konumlar';

  @override
  String get parkA => 'Park A';

  @override
  String get parkB => 'Park B';

  @override
  String get confirm => 'Onayla';

  @override
  String get cancel => 'İptal';

  @override
  String get pleaseSelectBothDogs => 'Lütfen her iki köpeği de seçin';

  @override
  String get pleaseLoginToCreateRequest => 'Talep oluşturmak için lütfen giriş yapın';

  @override
  String get playdateRequestTitle => 'Oyun Randevusu Talebi';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog, $requestedDog ile oynamak istiyor!';
  }

  @override
  String playdateRequestNotificationBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog, $requestedDog ile oynamak istiyor!';
  }

  @override
  String get requestCreatedSuccess => 'Talep başarıyla oluşturuldu';

  @override
  String errorCreatingRequest(Object error) {
    return 'Talep oluştururken hata: $error';
  }

  @override
  String playdateScheduled(Object dogName, Object dateTime, Object location) {
    return '$dogName ile $dateTime tarihinde $location konumunda oyun randevusu planlandı!';
  }

  @override
  String get newPlaydateRequestTitle => 'Yeni Oyun Randevusu Talebi!';

  @override
  String newPlaydateRequestBody(Object requesterDog, Object requestedDog) {
    return '$requesterDog, $requestedDog ile oynamak istiyor!';
  }

  @override
  String removedFromFavorites(Object dogName) {
    return '$dogName favorilerden kaldırıldı!';
  }

  @override
  String addedToFavorites(Object dogName) {
    return '$dogName favorilere eklendi!';
  }

  @override
  String errorTogglingFavorite(Object error) {
    return 'Favori değiştirme hatası: $error';
  }

  @override
  String chatWithOwner(Object dogName) {
    return '$dogName sahibine mesaj at!';
  }

  @override
  String errorSchedulingPlaydate(Object error) {
    return 'Oyun randevusu planlama hatası: $error';
  }

  @override
  String get viewEditDogDetails => 'Köpek detaylarını görüntüle/düzenle';

  @override
  String editNotAllowed(Object dogName) {
    return '$dogName için düzenleme izni yok, onDogUpdated boş';
  }

  @override
  String editDialogOpen(Object dogName) {
    return '$dogName için düzenleme diyaloğu zaten açık veya düzenleme devam ediyor';
  }

  @override
  String openingEditDialog(Object dogName) {
    return '$dogName için EditDogDialog açılıyor';
  }

  @override
  String dogUpdatedInDialog(Object dogName) {
    return '$dogName diyaloğunda güncellendi';
  }

  @override
  String dialogPopped(Object dogName) {
    return '$dogName için diyalog başarıyla kapatıldı';
  }

  @override
  String updatedDogReturned(Object dogName) {
    return 'Güncellenmiş köpek diyaloğundan döndü: $dogName';
  }

  @override
  String errorInShowDialog(Object dogName, Object error) {
    return '$dogName için showDialog hatası: $error';
  }

  @override
  String dialogClosed(Object isEditing, Object isDialogOpen) {
    return 'Diyalog kapandı, isEditing: $isEditing, isDialogOpen: $isDialogOpen';
  }

  @override
  String widgetNotMounted(Object isDialogOpen) {
    return 'Widget bağlı değil, isDialogOpen şu değere sıfırlandı: $isDialogOpen';
  }

  @override
  String removedDislike(Object dogName) {
    return '$dogName için dislike kaldırıldı!';
  }

  @override
  String addedDislike(Object dogName) {
    return '$dogName dislike edildi!';
  }

  @override
  String dislikeNotificationFailed(Object message) {
    return 'Dislike bildirimi başarısız: $message';
  }

  @override
  String ensureNotificationsEnabled(Object dogName) {
    return 'Lütfen $dogName sahibinin bildirimlerinin etkin olduğundan emin olun.';
  }

  @override
  String failedToDislike(Object message) {
    return 'Dislike başarısız: $message';
  }

  @override
  String errorSendingDislike(Object error) {
    return 'Dislike bildirimi gönderme hatası: $error';
  }

  @override
  String disposing(Object dogName) {
    return '$dogName için dispose ediliyor';
  }

  @override
  String resetIsDialogOpen(Object isDialogOpen) {
    return 'İptal sırasında isDialogOpen sıfırlandı: $isDialogOpen';
  }

  @override
  String get notifications => 'Bildirimler';

  @override
  String get playdateRequests => 'Oyun Randevusu Talepleri';

  @override
  String get noNotifications => 'Henüz bildirim yok.';

  @override
  String get noPlaydateRequests => 'Henüz oyun randevusu talebi yok.';

  @override
  String get accept => 'Kabul Et';

  @override
  String get reject => 'Reddet';

  @override
  String get status => 'Durum';

  @override
  String get delete => 'Sil';

  @override
  String get rejectConfirmation => 'Reddetme Onayı';

  @override
  String get areYouSure => 'Bu talebi reddetmek istediğinizden emin misiniz?';

  @override
  String get notificationDeleted => 'Bildirim silindi';

  @override
  String errorDeletingNotification(Object error) {
    return 'Bildirim silinirken hata: $error';
  }

  @override
  String get notificationsSection => 'Bildirimler';

  @override
  String get playdateRequestsSection => 'Oyun Randevusu Talepleri';

  @override
  String get noTitle => 'Başlık Yok';

  @override
  String get noBody => 'Gövde Yok';

  @override
  String get newLikeTitle => 'Yeni Beğeni!';

  @override
  String newLikeBody(Object username, Object dogName) {
    return '$username, $dogName köpeğinizi beğendi!';
  }

  @override
  String get playDateCanceledTitle => 'Oyun Randevusu Talebi İptal Edildi';

  @override
  String playDateCanceledBody(Object dogName) {
    return '$dogName ile oyun randevusu talebi iptal edildi.';
  }

  @override
  String get playDateAcceptedTitle => 'Oyun Randevusu Talebi Kabul Edildi!';

  @override
  String playDateAcceptedBodyRequester(Object dogName) {
    return '$dogName ile oyun randevusu talebini kabul ettiniz';
  }

  @override
  String playDateAcceptedBodyRequested(Object dogName, Object dateTime) {
    return '$dogName, $dogName ile $dateTime tarihinde oyun randevusu talebinizi kabul etti';
  }

  @override
  String get playDateRejectedTitle => 'Oyun Randevusu Talebi Reddedildi';

  @override
  String playDateRejectedBodyRequester(Object dogName) {
    return '$dogName ile oyun randevusu talebini reddettiniz';
  }

  @override
  String playDateRejectedBodyRequested(Object dogName) {
    return '$dogName, $dogName ile oyun randevusu talebinizi reddetti';
  }

  @override
  String errorLoadingNotifications(Object error) {
    return 'Bildirimler güncellenirken hata: $error';
  }

  @override
  String errorInitializingOrLoadingRequests(Object error) {
    return 'Talepler başlatılırken veya yüklenirken hata: $error';
  }

  @override
  String errorLoadingRequests(Object error) {
    return 'Talepler yüklenirken hata: $error';
  }

  @override
  String errorLoadingSpecificRequest(Object error) {
    return 'Belirli bir talep yüklenirken hata: $error';
  }

  @override
  String errorLoadingNotificationsStream(Object error) {
    return 'Bildirim akışı yüklenirken hata: $error';
  }

  @override
  String errorLoadingRequestsStream(Object error) {
    return 'Talep akışı yüklenirken hata: $error';
  }

  @override
  String errorUpdatingStatus(Object error) {
    return 'Durum güncellenirken hata: $error';
  }

  @override
  String errorUpdatingStatusUnexpected(Object error) {
    return 'Durum güncellenirken beklenmeyen hata: $error';
  }

  @override
  String get pleaseLoginToRespond => 'Taleplere yanıt vermek için lütfen giriş yapın';

  @override
  String requestStatusUpdated(Object status) {
    return 'Talep $status başarıyla güncellendi';
  }

  @override
  String errorRespondingToRequest(Object error) {
    return 'Talebe yanıt verirken hata: $error';
  }

  @override
  String errorRespondingToRequestUnexpected(Object error) {
    return 'Talebe yanıt verirken beklenmeyen hata: $error';
  }

  @override
  String get pleaseLoginToAccept => 'Talepleri kabul etmek için lütfen giriş yapın';

  @override
  String get requestAcceptedSuccess => 'Talep kabul edildi ve oyun randevuları listesine eklendi.';

  @override
  String errorAcceptingRequest(Object error) {
    return 'Talep kabul edilirken hata: $error';
  }

  @override
  String errorAcceptingRequestUnexpected(Object error) {
    return 'Talep kabul edilirken beklenmeyen hata: $error';
  }

  @override
  String get pleaseLoginToReject => 'Talepleri reddetmek için lütfen giriş yapın';

  @override
  String get requestRejectedSuccess => 'Talep reddedildi';

  @override
  String errorRejectingRequest(Object error) {
    return 'Talep reddedilirken hata: $error';
  }

  @override
  String errorRejectingRequestUnexpected(Object error) {
    return 'Talep reddedilirken beklenmeyen hata: $error';
  }

  @override
  String get failedToScheduleReminder => 'Hatırlatıcı planlama başarısız. İzinleri kontrol edin.';

  @override
  String get scheduledLabel => 'Planlandı:';

  @override
  String get pleaseLoginToViewPlaydateRequests => 'Oyun randevusu taleplerini görmek için giriş yapın';

  @override
  String get pleaseLoginToSetReminders => 'Hatırlatıcı ayarlamak için lütfen giriş yapın.';

  @override
  String reminderSetForMinutesBefore(Object minutesBefore) {
    return 'Hatırlatıcı, $minutesBefore dakika öncesi için ayarlandı 🐾';
  }

  @override
  String get failedToSetReminder => 'Hatırlatıcı ayarlanamadı ❌';

  @override
  String get playdateAcceptedCardTitle => 'Oyun Randevusu Kabul Edildi 🐾';

  @override
  String playdateAcceptedCardBody(Object dogName) {
    return '$dogName oyun randevusu talebinizi kabul etti.\nMutlu olun — kuyruk sallayan bir buluşma sizi bekliyor! 🐶💖';
  }

  @override
  String get playdateRejectedCardTitle => 'Bu Sefer Olmadı';

  @override
  String playdateRejectedCardBody(Object dogName) {
    return '$dogName bu sefer kabul edemedi.\nSorun değil — tekrar deneyin ve patileri hareket ettirmeye devam edin 🐾';
  }

  @override
  String get dogTab => 'Köpek';

  @override
  String get reminderTab => 'Hatırlatıcı';

  @override
  String get playdateTimeNotScheduledYet => '⏳ Oyun randevusu saati henüz planlanmadı';

  @override
  String get thirtyMinutesBefore => '30 dakika önce';

  @override
  String get oneHourBefore => '1 saat önce';

  @override
  String get reminderSet => 'Hatırlatıcı ayarlandı ✅';

  @override
  String get viewLocation => 'Konumu göster';

  @override
  String get locationLabel => 'Konum:';

  @override
  String get unknownStatus => 'bilinmeyen';

  @override
  String get unknownTime => 'Bilinmeyen zaman';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes dakika önce';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours saat önce';
  }

  @override
  String daysAgo(Object days) {
    return '$days gün önce';
  }

  @override
  String get notScheduled => 'Planlanmadı';

  @override
  String get upcomingPlaydateTitle => 'Yaklaşan Oyun Randevusu';

  @override
  String upcomingPlaydateBodyRequester(Object dogName) {
    return '$dogName ile 2 saat içinde bir oyun randevunuz var!';
  }

  @override
  String upcomingPlaydateBodyRequested(Object dogName) {
    return '$dogName ile 2 saat içinde bir oyun randevunuz var!';
  }

  @override
  String get appFeatures => 'Uygulamamızla şunları yapabilirsiniz:';

  @override
  String get appFeaturesMessage => 'Uygulamamızla şunları yapabilirsiniz:';

  @override
  String get playmateService => 'Oyun Arkadaşı';

  @override
  String get playmateSearchHint => 'Köpek ara...';

  @override
  String get playmateLocationNeededTitle => 'Konum gerekli';

  @override
  String get playmateLocationNeededMessage => 'Yakındaki köpekleri göstermek için konumunuzu kullanıyoruz';

  @override
  String get playmateFiltersTitle => 'Filtreler';

  @override
  String get playmateBreedPremiumHint => 'Irk (Gold)';

  @override
  String get playmateOwnerGenderPremiumHint => 'Sahip Cinsiyeti (Premium)';

  @override
  String get vetServices => 'Veteriner Hizmetleri';

  @override
  String get adoptionService => 'Sahiplenme';

  @override
  String get dogTrainingService => 'Köpek Eğitimi';

  @override
  String get dogParkService => 'Köpek Parkı';

  @override
  String get findFriendsService => 'Arkadaş Bul';

  @override
  String get getStarted => 'Başla';

  @override
  String get dogTraining => 'Köpek Eğitimi';

  @override
  String get dogPark => 'Köpek Parkı';

  @override
  String get findFriends => 'Arkadaş Bul';

  @override
  String get dogTrainingComingSoon => 'Köpek Eğitimi Yakında!';

  @override
  String get lostDogsComingSoon => 'Kayıp Köpekler Yakında!';

  @override
  String get petShopsComingSoon => 'Evcil Hayvan Mağazaları Yakında!';

  @override
  String get hospitalsComingSoon => 'Hastaneler Yakında!';

  @override
  String get findFriendsComingSoon => 'Arkadaş Bul Yakında!';

  @override
  String get menuTitle => 'Menü';

  @override
  String get homeMenuItem => 'Ana Sayfa';

  @override
  String get myDogsMenuItem => 'Köpeklerim';

  @override
  String get favoritesMenuItem => 'Favoriler';

  @override
  String get adoptionCenterMenuItem => 'Sahiplenme Merkezi';

  @override
  String get dogParkMenuItem => 'Köpek Parkı';

  @override
  String get reportLostDogMenuItem => 'Kayıp Köpek Bildir';

  @override
  String get lostDogsMenuItem => 'Kayıp Köpekler';

  @override
  String get reportFoundDogMenuItem => 'Bulunan Köpek Bildir';

  @override
  String get foundDogsMenuItem => 'Bulunan Köpekler';

  @override
  String get petShopsMenuItem => 'Evcil Hayvan Mağazaları';

  @override
  String get hospitalsMenuItem => 'Hastaneler';

  @override
  String get logoutMenuItem => 'Çıkış Yap';

  @override
  String get filterDogsMenuItem => 'Köpekleri Filtrele';

  @override
  String get homeNavItem => 'Ana Sayfa';

  @override
  String get favoritesNavItem => 'Favoriler';

  @override
  String get visitVetNavItem => 'Veteriner Ziyareti';

  @override
  String get playdateNavItem => 'Oyun Randevusu';

  @override
  String get profileNavItem => 'Profil';

  @override
  String get notificationsTooltip => 'Bildirimler';

  @override
  String get chatTooltip => 'Sohbet';

  @override
  String get chatNotImplemented => 'Sohbet özelliği henüz uygulanmadı';

  @override
  String get dogParkTitle => 'Köpek Parkları';

  @override
  String dogParkDateLabel(Object date) {
    return 'Tarih: $date';
  }

  @override
  String get dogParkLoadMarkers => 'Park İşaretlerini Yükle';

  @override
  String get dogParkMoveToMarkers => 'İşaretlere Git';

  @override
  String get dogParkPermissionDenied => 'Konum izni reddedildi. Lütfen ayarlarınızda etkinleştirin.';

  @override
  String get dogParkBackgroundPermissionDenied => 'Arka plan konum izni reddedildi. Bazı özellikler sınırlı olabilir.';

  @override
  String get dogParkLocationServicesDisabled => 'Konum hizmetleri devre dışı.';

  @override
  String get dogParkEnableLocationServices => 'Devam etmek için lütfen konum hizmetlerini etkinleştirin.';

  @override
  String get dogParkPermissionDeniedPermanent => 'Konum izni kalıcı olarak reddedildi.';

  @override
  String get dogParkPermissionsDenied => 'Konum izinleri kalıcı olarak reddedildi. Lütfen ayarlarınızda etkinleştirin.';

  @override
  String dogParkLocationError(Object error) {
    return 'Konum alınırken hata: $error';
  }

  @override
  String get dogParkPermissionRequired => 'Yakındaki köpek parklarını göstermek için konum izni gerekli.';

  @override
  String get dogParkRecommendedBadge => '⭐ Önerilen';

  @override
  String get dogParkPremiumBadge => '🔒 Premium';

  @override
  String get dogParkSavedBadge => '❤️ Kaydedildi';

  @override
  String get dogParkRecommendedForPlaydates => 'Oyun buluşmaları için önerilir';

  @override
  String get dogParkSavedToFavorites => 'Favorilere kaydedildi';

  @override
  String get dogParkSaveThisPark => 'Bu parkı kaydet';

  @override
  String get dogParkGetDirections => 'Yol tarifi al';

  @override
  String get dogParkUserNotReadyYet => 'Kullanıcı henüz hazır değil. Lütfen tekrar deneyin.';

  @override
  String get dogParkNeedToAddDogFirst => 'Önce bir köpek eklemeniz gerekiyor';

  @override
  String get dogParkSchedulePlaydateHere => 'Burada oyun randevusu planla';

  @override
  String get dogParkSavedParksTitle => 'Kayıtlı Parklar';

  @override
  String get dogParkNoSavedParksYet => 'Henüz kayıtlı park yok';

  @override
  String get dogParkFindNearbyParks => 'Yakındaki parkları bul';

  @override
  String get dogParkLocationNeededTitle => 'Konum gerekli';

  @override
  String get dogParkUseYourLocationToShowNearbyDogParks => 'Yakındaki köpek parklarını göstermek için konumunuzu kullanıyoruz';

  @override
  String get allowButton => 'İzin Ver';

  @override
  String get dogParkBackgroundRecommended => 'Arka plan konum izni önerilir. Lütfen ayarlarınızda etkinleştirin.';

  @override
  String get dogParkSettingsAction => 'Ayarlar';

  @override
  String dogParkDistanceLabel(Object distance) {
    return 'Mesafe: $distance km';
  }

  @override
  String get dogViewTitle => 'Köpek Detayları';

  @override
  String get dogViewNameLabel => 'İsim:';

  @override
  String get dogViewBreedLabel => 'Irk:';

  @override
  String get dogViewAgeLabel => 'Yaş:';

  @override
  String get dogViewGenderLabel => 'Cinsiyet:';

  @override
  String get dogViewHealthLabel => 'Sağlık:';

  @override
  String get dogViewNeuteredLabel => 'Kısırlaştırma:';

  @override
  String get dogViewDescriptionLabel => 'Açıklama:';

  @override
  String get dogViewTraitsLabel => 'Özellikler:';

  @override
  String get dogViewOwnerGenderLabel => 'Sahip Cinsiyeti:';

  @override
  String get dogViewAvailableLabel => 'Sahiplenmek için Uygun:';

  @override
  String get dogViewYes => 'Evet';

  @override
  String get dogViewNo => 'Hayır';

  @override
  String get dogViewLikeTooltip => 'Beğen';

  @override
  String get dogViewDislikeTooltip => 'Dislike';

  @override
  String get dogViewAddFavoriteTooltip => 'Favorilere Ekle';

  @override
  String get dogViewChatTooltip => 'Sohbet';

  @override
  String get dogViewScheduleDate => 'Tarih Planla';

  @override
  String get dogViewAdoption => 'Sahiplenme';

  @override
  String get dogViewChatStarted => 'Sohbet başlatıldı!';

  @override
  String dogViewPlayDateScheduled(Object day, Object month, Object year, Object time) {
    return '$day/$month/$year tarihinde $time saatinde oyun randevusu planlandı!';
  }

  @override
  String get dogViewAdoptionRequest => 'Sahiplenme talebi gönderildi!';

  @override
  String get distanceUnknown => 'Mesafe bilinmiyor';

  @override
  String boostDogTitle(Object dogName) {
    return '$dogName için yükselt';
  }

  @override
  String get boostVisibilityDescription => 'Playmates keşfinde daha fazla görünürlük elde edin.';

  @override
  String get boost24HoursTitle => '24 Saatlik Boost';

  @override
  String get boostQuickVisibilitySubtitle => 'Hızlı görünürlük için iyi';

  @override
  String get boostPrice29 => '₺29';

  @override
  String get boost3DaysTitle => '3 Günlük Boost';

  @override
  String get boostBetterExposureSubtitle => 'Aktif keşif için daha iyi görünürlük';

  @override
  String get boostPrice69 => '₺69';

  @override
  String get boost7DaysTitle => '7 Günlük Boost';

  @override
  String get boostBestValueSubtitle => 'Maksimum erişim için en iyi değer';

  @override
  String get boostPrice129 => '₺129';

  @override
  String get boostActivated => 'Boost etkinleştirildi 🚀';

  @override
  String boostFailed(Object error) {
    return 'Boost başarısız: $error';
  }

  @override
  String get errorOpeningEdit => 'Düzenleme açılırken hata oluştu';

  @override
  String get boostBadge => 'BOOSTED';

  @override
  String get boostButton => 'Boost';

  @override
  String get blockComingSoon => 'Engelleme yakında geliyor';

  @override
  String get blockMenuItem => 'Kullanıcıyı Engelle';

  @override
  String get sendAdoptionRequest => 'Sahiplenme Talebi Gönder';

  @override
  String ownerPrefix(Object owner) {
    return 'Sahibi: $owner';
  }

  @override
  String get submitComplaintMenuItem => 'Şikayet Gönder';

  @override
  String get dogInfoTitle => 'Köpek Bilgileri';

  @override
  String get dogInfoBreedLabel => 'Irk:';

  @override
  String get dogInfoAgeLabel => 'Yaş:';

  @override
  String get dogInfoGenderLabel => 'Cinsiyet:';

  @override
  String get dogInfoHealthLabel => 'Sağlık Durumu:';

  @override
  String get dogInfoNeuteredLabel => 'Kısırlaştırma:';

  @override
  String get dogInfoDescriptionLabel => 'Açıklama:';

  @override
  String get dogInfoTraitsLabel => 'Özellikler:';

  @override
  String get dogInfoOwnerGenderLabel => 'Sahip Cinsiyeti:';

  @override
  String get dogInfoYes => 'Evet';

  @override
  String get dogInfoNo => 'Hayır';

  @override
  String get dogInfoLikeTooltip => 'Beğen';

  @override
  String get dogInfoDislikeTooltip => 'Dislike';

  @override
  String get dogInfoChatTooltip => 'Sohbet';

  @override
  String get dogInfoAddFavoriteTooltip => 'Favorilere Ekle';

  @override
  String get dogInfoSchedulePlaydateTooltip => 'Oyun Randevusu Planla';

  @override
  String dogInfoPlaydateScheduled(Object dogName) {
    return '$dogName ile oyun randevusu planlandı!';
  }

  @override
  String dogInfoLiked(Object dogName) {
    return '$dogName beğenildi!';
  }

  @override
  String dogInfoDisliked(Object dogName) {
    return '$dogName dislike edildi!';
  }

  @override
  String dogInfoChatWithOwner(Object dogName) {
    return '$dogName sahibine mesaj at!';
  }

  @override
  String dogInfoRemovedFavorite(Object dogName) {
    return '$dogName favorilerden kaldırıldı!';
  }

  @override
  String dogInfoAddedFavorite(Object dogName) {
    return '$dogName favorilere eklendi!';
  }

  @override
  String get noDogsFound => 'Köpek Bulunamadı';

  @override
  String get noDogsForUser => 'Bu kullanıcı için köpek bulunamadı.';

  @override
  String get dogsOfThisUser => 'Bu Kullanıcının Köpekleri';

  @override
  String get playDateStatus_pending => 'Beklemede';

  @override
  String get playDateStatus_accepted => 'Kabul Edildi';

  @override
  String get playDateStatus_rejected => 'Reddedildi';

  @override
  String get locationServicesDisabled => 'Konum hizmetleri devre dışı. Varsayılan konum kullanılıyor.';

  @override
  String get locationPermissionRequired => 'Konum izni gerekli. Varsayılan konum kullanılıyor.';

  @override
  String get locationPermissionPermanentlyDenied => 'Konum izni kalıcı olarak reddedildi. Varsayılan konum kullanılıyor.';

  @override
  String errorGettingLocation(Object error) {
    return 'Konum alınırken hata: $error';
  }

  @override
  String errorLoadingData(Object error) {
    return 'Veri yüklenirken hata: $error';
  }

  @override
  String errorLoadingOffers(Object error) {
    return 'Teklifler yüklenirken hata: $error';
  }

  @override
  String errorApplyingFilters(Object error) {
    return 'Filtreler uygulanırken hata: $error';
  }

  @override
  String get notificationChannelName => 'Yüksek Önemli Bildirimler';

  @override
  String get notificationChannelDescription => 'Bu kanal önemli bildirimler için kullanılır.';

  @override
  String get openAppAction => 'Uygulamayı Aç';

  @override
  String get dismissAction => 'Kapat';

  @override
  String get adoptionCenter => 'Sahiplenme Merkezi';

  @override
  String get traitEnergetic => 'Enerjik';

  @override
  String get traitPlayful => 'Oyunbaz';

  @override
  String get traitCalm => 'Sakin';

  @override
  String get traitLoyal => 'Sadık';

  @override
  String get traitFriendly => 'Dost Canlısı';

  @override
  String get traitProtective => 'Koruyucu';

  @override
  String get traitIntelligent => 'Zeki';

  @override
  String get traitAffectionate => 'Sevgi Dolu';

  @override
  String get traitCurious => 'Meraklı';

  @override
  String get traitIndependent => 'Bağımsız';

  @override
  String get traitShy => 'Utangaç';

  @override
  String get traitTrained => 'Eğitimli';

  @override
  String get traitSocial => 'Sosyal';

  @override
  String get traitGoodWithKids => 'Çocuklarla İyi';

  @override
  String get breedAfghanHound => 'Afgan Tazısı';

  @override
  String get breedAiredaleTerrier => 'Airedale Terrier';

  @override
  String get breedAkita => 'Akita';

  @override
  String get breedAlaskanMalamute => 'Alaska Malamutu';

  @override
  String get breedAmericanBulldog => 'Amerikan Bulldog';

  @override
  String get breedAmericanPitBullTerrier => 'Amerikan Pit Bull Terrier';

  @override
  String get breedAustralianCattleDog => 'Avustralya Sığır Köpeği';

  @override
  String get breedAustralianShepherd => 'Avustralya Çoban Köpeği';

  @override
  String get breedBassetHound => 'Basset Hound';

  @override
  String get breedBeagle => 'Beagle';

  @override
  String get breedBelgianMalinois => 'Belçika Malinois';

  @override
  String get breedBerneseMountainDog => 'Bernese Dağ Köpeği';

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
  String get breedDalmatian => 'Dalmaçyalı';

  @override
  String get breedDobermanPinscher => 'Doberman Pinscher';

  @override
  String get breedEnglishSpringerSpaniel => 'İngiliz Springer Spaniel';

  @override
  String get breedFrenchBulldog => 'Fransız Bulldog';

  @override
  String get breedGermanShepherd => 'Alman Çoban Köpeği';

  @override
  String get breedGermanShorthairedPointer => 'Alman Kısasakal Pointer';

  @override
  String get breedGoldenRetriever => 'Golden Retriever';

  @override
  String get breedGreatDane => 'Büyük Dane';

  @override
  String get breedGreatPyrenees => 'Büyük Pirene';

  @override
  String get breedHavanese => 'Havanese';

  @override
  String get breedIrishSetter => 'İrlanda Setter';

  @override
  String get breedIrishWolfhound => 'İrlanda Kurt Köpeği';

  @override
  String get breedJackRussellTerrier => 'Jack Russell Terrier';

  @override
  String get breedLabradorRetriever => 'Labrador Retriever';

  @override
  String get breedLhasaApso => 'Lhasa Apso';

  @override
  String get breedMaltese => 'Malta Köpeği';

  @override
  String get breedMastiff => 'Mastiff';

  @override
  String get breedMiniatureSchnauzer => 'Minik Schnauzer';

  @override
  String get breedNewfoundland => 'Newfoundland';

  @override
  String get breedPapillon => 'Papillon';

  @override
  String get breedPekingese => 'Pekinez';

  @override
  String get breedPomeranian => 'Pomeranian';

  @override
  String get breedPoodle => 'Kaniş';

  @override
  String get breedPug => 'Pug';

  @override
  String get breedRottweiler => 'Rottweiler';

  @override
  String get breedSaintBernard => 'Saint Bernard';

  @override
  String get breedSamoyed => 'Samoyed';

  @override
  String get breedShetlandSheepdog => 'Shetland Çoban Köpeği';

  @override
  String get breedShihTzu => 'Shih Tzu';

  @override
  String get breedSiberianHusky => 'Sibirya Kurdu';

  @override
  String get breedStaffordshireBullTerrier => 'Staffordshire Bull Terrier';

  @override
  String get breedVizsla => 'Vizsla';

  @override
  String get breedWeimaraner => 'Weimaraner';

  @override
  String get breedWestHighlandWhiteTerrier => 'Batı Highland Beyaz Terrier';

  @override
  String get breedYorkshireTerrier => 'Yorkshire Terrier';

  @override
  String get settings => 'Ayarlar';

  @override
  String get playdateRequestsTitle => 'Oyun Randevusu Talepleri ve Bildirimler';

  @override
  String get sendRequestButton => 'Talep Gönder';

  @override
  String get confirmLocation => 'Konumu Onayla';

  @override
  String get cancelButton => 'İptal Et';

  @override
  String get editDogHealthHealthy => 'Sağlıklı';

  @override
  String get editDogHealthNeedsCare => 'Bakım Gerekiyor';

  @override
  String get editDogHealthUnderTreatment => 'Tedavi Altında';

  @override
  String get noDogFoundForAccount => 'Hesabınız için köpek bulunamadı. Lütfen önce bir köpek ekleyin.';

  @override
  String get pleaseSelectYourDog => 'Lütfen köpeklerinizden birini seçin';

  @override
  String get cannotScheduleWithOwnDog => 'Kendi köpeğinizle oyun randevusu planlayamazsınız.';

  @override
  String get cannotScheduleWithTempUser => 'Geçici bir kullanıcıyla oyun randevusu planlanamaz.';

  @override
  String playdateRequestFor(Object dogName) {
    return '$dogName için oyun randevusu talebi';
  }

  @override
  String get forAdoption => 'Sahiplenmek için';

  @override
  String get neutered => 'Kısırlaştırılmış';

  @override
  String get notNeutered => 'Kısırlaştırılmamış';

  @override
  String get pleaseSelectDogForPlaydate => 'Lütfen oyun randevusu için köpeklerinizden birini seçin';

  @override
  String get years => 'yıl';

  @override
  String get breed => 'Irk';

  @override
  String get gender => 'Cinsiyet';

  @override
  String get healthStatus => 'Sağlık Durumu';

  @override
  String get neuteredStatus => 'Kısırlaştırma Durumu';

  @override
  String get description => 'Açıklama';

  @override
  String get traits => 'Özellikler';

  @override
  String get addToFavorites => 'Favorilere Ekle';

  @override
  String get newFavoriteTitle => 'Yeni Favori!';

  @override
  String newFavoriteBody(Object userName, Object dogName) {
    return '$userName, $dogName köpeğinizi favorilere ekledi!';
  }

  @override
  String get likes => 'Beğeniler';

  @override
  String get removeDislike => 'Dislike\'ı Kaldır';

  @override
  String get dislike => 'Dislike';

  @override
  String errorTogglingDislike(Object error) {
    return 'Dislike değiştirme hatası: $error';
  }

  @override
  String get sending => 'Gönderiliyor...';

  @override
  String get schedulePlayDate => 'Oyun Randevusu Planla';

  @override
  String get playdateSchedulingSubtitle => 'Oyun randevusu için tarih, saat, konum ve köpekleri seçin.';

  @override
  String get errorSelectDateAndTime => 'Lütfen tarih ve saat seçin.';

  @override
  String get errorMissingLocationCoordinates => 'Park konumu koordinatları eksik.';

  @override
  String get errorPlaydateLeadTime => 'Oyun randevusu en az 15 dakika önceden planlanmalıdır.';

  @override
  String get playdateTimeConflict => 'Bu köpeğin bu saate yakın bir oyun randevusu zaten var 🐾';

  @override
  String coordinatesLatLng(Object lat, Object lng) {
    return 'Enlem: $lat, Boylam: $lng';
  }

  @override
  String get chat => 'Sohbet';

  @override
  String get adoptDog => 'Köpeği Sahiplen';

  @override
  String errorSendingDislikeNotification(Object error) {
    return 'Dislike bildirimi gönderme hatası: $error';
  }

  @override
  String get genderMale => 'Erkek';

  @override
  String get genderFemale => 'Dişi';

  @override
  String get healthHealthy => 'Sağlıklı';

  @override
  String get healthNeedsCare => 'Bakım Gerekiyor';

  @override
  String get healthUnderTreatment => 'Tedavi Altında';

  @override
  String get dogDetailsHealthSick => 'Bakım Gerekiyor';

  @override
  String get dogDetailsHealthRecovering => 'Tedavi Altında';

  @override
  String get noImageSelected => 'Hiçbir resim seçilmedi.';

  @override
  String get unknownGender => 'Bilinmeyen Cinsiyet';

  @override
  String get unknownBreed => 'Bilinmeyen Irk';

  @override
  String get unknownTrait => 'Bilinmeyen Özellik';

  @override
  String get noTraits => 'Hiçbir özellik mevcut değil';

  @override
  String get simpleTestPageTitle => 'Basit Test Sayfası';

  @override
  String get simpleTestPageMessage => 'Bu basit bir test sayfasıdır.';

  @override
  String likedBy(Object likers) {
    return 'Beğenenler: $likers';
  }

  @override
  String get locationNotAcquired => 'Konum alınamadı. Lütfen tekrar deneyin.';

  @override
  String get retryLocation => 'Konumu Tekrar Dene';

  @override
  String get addLike => 'Bu köpeği beğen';

  @override
  String get removeLike => 'Bu köpeğin beğenisini kaldır';

  @override
  String addedLike(Object dogName) {
    return '$dogName köpeğini beğendiniz!';
  }

  @override
  String removedLike(Object dogName) {
    return '$dogName köpeğinin beğenisini kaldırdınız!';
  }

  @override
  String errorTogglingLike(Object error) {
    return 'Beğeni değiştirme hatası: $error';
  }

  @override
  String get errorNoOwnerFound => 'Bu köpek için geçerli bir sahip bulunamadı';

  @override
  String get offerHotDeal => '🔥 Fırsat';

  @override
  String get offerPremiumBadge => 'Premium';

  @override
  String get offerFallbackTitle => 'Barky kullanıcılarına özel teklif';

  @override
  String get offerFallbackProvider => 'İş ortağı marka';

  @override
  String get offerUnlock => 'Aç';

  @override
  String get offerView => 'Görüntüle';

  @override
  String offerDiscountPercent(Object discount) {
    return '%$discount İNDİRİM';
  }

  @override
  String get offerPremiumRequiredTitle => 'Premium Gerekli';

  @override
  String get offerPremiumRequiredMessage => 'Bu teklif yalnızca premium üyeler içindir.';

  @override
  String get offerCancel => 'İptal';

  @override
  String get offerUpgrade => 'Yükselt';

  @override
  String get offerUnlockingMessage => 'Teklifiniz açılıyor...';

  @override
  String get offerChooseContinueTitle => 'Nasıl devam etmek istersiniz?';

  @override
  String get offerChooseContinueSubtitle => 'Bu teklif için tercih ettiğiniz iletişim seçeneğini seçin.';

  @override
  String get offerOpenWebsite => 'Web Sitesini Aç';

  @override
  String get offerInstagram => 'Instagram';

  @override
  String get playdatesTitle => 'Oyun Buluşmaları';

  @override
  String get manageRequests => 'İstekleri yönet';

  @override
  String get adoptionTitle => 'Sahiplendirme';

  @override
  String get giveLove => 'Sevgi ver';

  @override
  String get alertsTitle => 'Uyarılar';

  @override
  String get lostAndFound => 'Kayıp & Bulunan';

  @override
  String get vetTitle => 'Veteriner';

  @override
  String get nearbyClinics => 'Yakındaki klinikler';

  @override
  String get groomyTitle => 'Bakım';

  @override
  String get bookGrooming => 'Bakım randevusu al';

  @override
  String get pamperYourPet => 'Dostunuzu şımartın';

  @override
  String get petShopTitle => 'Pet Shop';

  @override
  String get shopNearYou => 'Yakındaki ürünleri keşfet';

  @override
  String get featuredDeal => 'Öne Çıkan Fırsat';

  @override
  String get premiumLabel => 'Premium';

  @override
  String get goldLabel => 'Gold';

  @override
  String discountOff(Object percent) {
    return '%$percent İndirim';
  }

  @override
  String get socialAndPlay => 'Sosyal & Oyun';

  @override
  String get careAndServices => 'Bakım & Hizmetler';

  @override
  String get outdoorAndLifestyle => 'Açık Hava & Yaşam';

  @override
  String get exploreNearbyParks => 'Yakındaki parkları keşfet';

  @override
  String get createMemoriesTogether => 'Birlikte anılar biriktirin';

  @override
  String get reportFoundTitle => 'Bulundu Bildir';

  @override
  String get reconnectFamilies => 'Evcil dostları ailelerine kavuşturmaya yardım et';

  @override
  String get lostPetsTitle => 'Kayıp Dostlar';

  @override
  String get activeReportsNearby => 'Aktif kayıp ilanlarını görüntüle';

  @override
  String get foundPetsTitle => 'Bulunan Dostlar';

  @override
  String get waitingToReunite => 'Yuvalarına dönmeyi bekleyen dostlar';

  @override
  String get trainingTitle => 'Eğitim';

  @override
  String get comingSoon => 'Çok yakında';

  @override
  String get trainingComingSoonMessage => 'Eğitim özelliği yakında geliyor 🐾';

  @override
  String get communityHub => 'Topluluk Merkezi';

  @override
  String get safetyAndRescue => 'Güvenlik ve Kurtarma';

  @override
  String activeCount(Object count) {
    return '$count aktif';
  }

  @override
  String get reportTitle => 'Bildirim';

  @override
  String get lostDogTitle => 'Kayıp Köpek';

  @override
  String get lostPetTitle => 'Kayıp Evcil Hayvan';

  @override
  String get foundDogTitle => 'Bulunan Köpek';

  @override
  String get foundPetTitle => 'Bulunan Evcil Hayvan';

  @override
  String get lostTitle => 'Kayıp';

  @override
  String get dogsTitle => 'Köpekler';

  @override
  String get petsTitle => 'Evcil Hayvanlar';

  @override
  String get foundTitle => 'Bulunan';

  @override
  String get homeDefaultUsername => 'Kullanıcı';

  @override
  String get homePetHotelTitle => 'Pet Otel';

  @override
  String get homeSafeStaySubtitle => 'Güvenli konaklama';

  @override
  String get homePetTaxiTitle => 'Pet Taksi';

  @override
  String get homeRideSafelySubtitle => 'Güvenle yolculuk';

  @override
  String get homeGreenMemorialTitle => 'Yeşil Anıt';

  @override
  String get homeVeterinaryTitle => 'Veteriner';

  @override
  String get expertCareForYourPet => 'Evcil dostunuz için uzman bakım';

  @override
  String get homeLocationNeededTitle => 'Konum gerekli';

  @override
  String get homeLocationNeededMessage => 'Yakındaki veterinerleri göstermek için konumunuzu kullanıyoruz';

  @override
  String get homeAllowButton => 'İzin ver';

  @override
  String get homeBusinessesTitle => 'İşletmeler';

  @override
  String get homeSearchHint => 'Hizmet, mağaza, topluluk ara...';

  @override
  String get homePetFriendlyPlaceTitle => 'Pet Dostu Mekan';

  @override
  String get homeSponsoredLabel => 'Sponsorlu';

  @override
  String get homeShopButton => 'Mağaza';

  @override
  String get petShopDealName => 'Pet Shop A';

  @override
  String get petShopDealDesc => 'Tüm mamalarda %15 indirim';

  @override
  String get groomyDealName => 'Groomy Studio';

  @override
  String get groomyDealDesc => 'Bu hafta bakımda %20 indirim';

  @override
  String get vetDealName => 'VetPlus';

  @override
  String get vetDealDesc => 'Gold üyeler için ücretsiz kontrol';

  @override
  String get offerWhatsApp => 'WhatsApp';

  @override
  String offerCodeCopied(Object code) {
    return 'Kod kopyalandı: $code';
  }

  @override
  String get offerOpenError => 'Teklif açılırken hata oluştu';

  @override
  String get businessRegisterLegalCompanyNameRequired => '• Yasal şirket adı gereklidir.';

  @override
  String get businessRegisterPublicDisplayNameRequired => '• Görünen işletme adı gereklidir.';

  @override
  String get businessRegisterSelectCountry => '• Lütfen bir ülke seçin.';

  @override
  String get businessRegisterSelectBusinessCategory => '• Lütfen en az bir işletme kategorisi seçin.';

  @override
  String get businessRegisterEnterValidEmail => '• Geçerli bir e-posta adresi girin (örnek: name@example.com).';

  @override
  String get businessRegisterPhoneIncomplete => '• Telefon numarası eksik.';

  @override
  String get businessRegisterSelectCityProvince => '• Lütfen şehir / il seçin.';

  @override
  String get businessRegisterSelectDistrict => '• Lütfen ilçe seçin.';

  @override
  String get businessRegisterBusinessAddressRequired => '• İşletme adresi gereklidir.';

  @override
  String get businessRegisterAllLegalDocumentsRequired => '• Gerekli tüm yasal belgeler yüklenmelidir.';

  @override
  String get businessRegisterDocumentsVerifiedBeforeContinuing => '• Devam etmeden önce belgeler doğrulanmalıdır.';

  @override
  String get businessRegisterAcceptPlatformTerms => '• Platform şartlarını kabul etmelisiniz.';

  @override
  String get businessRegisterAcceptLegalResponsibility => '• Yasal sorumluluk beyanını kabul etmelisiniz.';

  @override
  String get businessRegisterFixHighlightedFields => 'Lütfen vurgulanan alanları düzeltin';

  @override
  String get businessRegisterOk => 'Tamam';

  @override
  String get businessRegisterFailedToLoadCountries => 'Ülkeler yüklenemedi';

  @override
  String get businessRegisterFailedToLoadCities => 'Şehirler yüklenemedi';

  @override
  String get businessRegisterFailedToLoadDistricts => 'İlçeler yüklenemedi';

  @override
  String get businessRegisterPlatformLegalAgreement => 'Platform Yasal Sözleşmesi';

  @override
  String get businessRegisterReadAndAccept => 'Okudum ve kabul ediyorum';

  @override
  String get businessRegisterLocationPermissionDenied => 'Konum izni reddedildi';

  @override
  String get businessRegisterCouldNotDetectCity => 'Şehir tespit edilemedi';

  @override
  String get businessRegisterGroomer => 'Kuaför';

  @override
  String get businessRegisterVeterinaryClinic => 'Veteriner Kliniği';

  @override
  String get businessRegisterDogTrainer => 'Köpek Eğitmeni';

  @override
  String get businessRegisterPetHotel => 'Evcil Hayvan Oteli';

  @override
  String get businessRegisterDogWalker => 'Köpek Gezdirici';

  @override
  String get businessRegisterBreeder => 'Yetiştirici';

  @override
  String get businessRegisterInvalidEmail => 'Geçersiz e-posta';

  @override
  String get businessRegisterInvalidPhone => 'Geçersiz telefon';

  @override
  String get businessRegisterInvalidWebsite => 'Geçersiz web sitesi';

  @override
  String get businessRegisterCouldNotOpenLegalText => 'Yasal metin açılamadı';

  @override
  String get businessRegisterSelectAtLeastOneBusinessCategory => 'Lütfen en az bir işletme kategorisi seçin';

  @override
  String get businessRegisterPleaseEnterBusinessAddress => 'Lütfen işletme adresini girin';

  @override
  String get businessRegisterMustAcceptAllAgreements => 'Tüm sözleşmeleri kabul etmelisiniz';

  @override
  String get businessRegisterDocumentsVerifiedBeforeSubmission => 'Göndermeden önce belgeler doğrulanmalıdır';

  @override
  String get businessRegisterApplicationSubmittedSuccessfully => 'Başvuru başarıyla gönderildi';

  @override
  String get businessRegisterSubmissionFailed => 'Gönderim başarısız oldu';

  @override
  String get businessRegisterUnexpectedErrorOccurred => 'Beklenmeyen bir hata oluştu';

  @override
  String get businessRegisterTitle => 'İşletme Kaydı';

  @override
  String get businessRegisterStepIdentityCategories => 'İşletme kimliği ve kategoriler';

  @override
  String get businessRegisterStepContactLocation => 'İletişim ve konum';

  @override
  String get businessRegisterStepLegalDocuments => 'Yasal belgeler';

  @override
  String get businessRegisterStepAgreementConfirmation => 'Sözleşme onayı';

  @override
  String get businessRegisterBack => 'Geri';

  @override
  String get businessRegisterContinue => 'Devam';

  @override
  String get businessRegisterSubmitApplication => 'Başvuruyu Gönder';

  @override
  String get businessRegisterCompleteSectorDetails => 'Sektör Detaylarını Tamamla';

  @override
  String get businessRegisterBusinessIdentity => 'İşletme kimliği';

  @override
  String get businessRegisterBusinessIdentitySubtitle => 'İşletmenizin PetSupo\'da nasıl görüneceğini belirtin.';

  @override
  String get businessRegisterLegalCompanyName => 'Yasal Şirket Adı';

  @override
  String get businessRegisterRequired => 'Gerekli';

  @override
  String get businessRegisterPublicDisplayName => 'Görünen İşletme Adı';

  @override
  String get businessRegisterCountry => 'Ülke';

  @override
  String get businessRegisterBusinessCategories => 'İşletme kategorileri';

  @override
  String get businessRegisterBusinessCategoriesSubtitle => 'Bu işletmenin faaliyet gösterdiği tüm sektörleri seçin.';

  @override
  String get businessRegisterContactLocation => 'İletişim ve konum';

  @override
  String get businessRegisterContactLocationSubtitle => 'Bu bilgiler müşterilerin sizi bulmasına ve sizinle iletişim kurmasına yardımcı olur.';

  @override
  String get businessRegisterPhone => 'Telefon';

  @override
  String get businessRegisterWebsiteOptional => 'Web sitesi (isteğe bağlı)';

  @override
  String get businessRegisterLoadingCities => 'Şehirler yükleniyor...';

  @override
  String get businessRegisterCityProvince => 'Şehir / İl';

  @override
  String get businessRegisterLoadingDistricts => 'İlçeler yükleniyor...';

  @override
  String get businessRegisterDistrict => 'İlçe';

  @override
  String get businessRegisterBusinessAddress => 'İşletme Adresi';

  @override
  String get businessRegisterDetectCity => 'Şehri Algıla';

  @override
  String get businessRegisterMapPickerComingSoon => 'Harita seçici yakında eklenecek';

  @override
  String get businessRegisterPickLocation => 'Konum Seç';

  @override
  String get businessRegisterLocationSelected => 'Konum seçildi';

  @override
  String get businessRegisterTaxPlate => 'Vergi Levhası';

  @override
  String get businessRegisterTradeRegistryGazette => 'Ticaret Sicil Gazetesi';

  @override
  String get businessRegisterAuthorizedSignatureDocument => 'Yetkili İmza Belgesi';

  @override
  String get businessRegisterTaxNumberVkn => 'Vergi Numarası (VKN)';

  @override
  String get businessRegisterAutoFilledFromDocument => 'Belgeden otomatik dolduruldu';

  @override
  String get businessRegisterDocumentVerificationInconsistencies => 'Belge doğrulamasında tutarsızlıklar var. Yönetici incelemesi gerekiyor.';

  @override
  String get businessRegisterMersisNumber => 'MERSİS Numarası';

  @override
  String get businessRegisterDocumentsSecurelyEncrypted => 'Belgeleriniz güvenli şekilde şifrelenir ve otomatik olarak doğrulanır';

  @override
  String get businessRegisterVerifiedFromDocument => 'Belgeden doğrulandı';

  @override
  String get businessRegisterAutoFilledAfterVerification => 'Belge doğrulamasından sonra otomatik doldurulur';

  @override
  String get businessRegisterUploadTradeRegistryFirst => 'Önce Ticaret Sicil belgesini yükleyin';

  @override
  String get businessRegisterWaitingForDocumentVerification => 'Belge doğrulaması bekleniyor...';

  @override
  String get businessRegisterSteuernummer => 'Vergi Numarası';

  @override
  String get businessRegisterTaxNumberRequired => 'Vergi numarası gereklidir';

  @override
  String get businessRegisterGewerbeschein => 'İşyeri Açma Belgesi';

  @override
  String get businessRegisterHandelsregisterauszug => 'Ticaret Sicili Özeti';

  @override
  String get businessRegisterEinNumber => 'EIN Numarası';

  @override
  String get businessRegisterEinNumberRequired => 'EIN numarası gereklidir';

  @override
  String get businessRegisterBusinessLicense => 'İşletme Lisansı';

  @override
  String get businessRegisterIrsEinDocument => 'IRS EIN Belgesi';

  @override
  String get businessRegisterProcessingDocument => 'Belge işleniyor...';

  @override
  String get businessRegisterDocumentVerifiedSuccessfully => 'Belge başarıyla doğrulandı';

  @override
  String get businessRegisterCouldNotReadDocument => 'Belge okunamadı, lütfen tekrar yükleyin';

  @override
  String get businessRegisterVeterinary => 'Veteriner';

  @override
  String get businessRegisterGroomy => 'Groomy';

  @override
  String businessRegisterStepOfFour(Object step) {
    return '4 adımdan $step. adım';
  }

  @override
  String get businessRegisterLegalConfirmation => 'Yasal Onay';

  @override
  String get businessRegisterAcceptTermsKvkk => 'Platform Şartları\'nı ve KVKK Aydınlatma Metni\'ni kabul ediyorum.';

  @override
  String get businessRegisterReadInsideApp => 'Uygulama içinde oku';

  @override
  String get businessRegisterOpenOfficialLegalPage => 'Resmi yasal sayfayı aç';

  @override
  String get businessRegisterLegalVersion => 'Sürüm v1.0 • Son güncelleme Mayıs 2026';

  @override
  String get businessRegisterAgreementSecurelyStored => 'Onayınız güvenli şekilde saklanır ve yasal olarak bağlayıcıdır';

  @override
  String get businessRegisterLegalResponsibilityDeclaration => 'Gönderilen tüm belgelerin doğru olduğunu beyan eder ve Türk Ticaret Kanunu kapsamında tüm yasal sorumluluğu kabul ederim.';

  @override
  String get businessRegisterUploaded => 'Yüklendi';

  @override
  String get businessRegisterReplaceDocument => 'Belgeyi değiştir';

  @override
  String get businessRegisterReplaceDocumentConfirmation => 'Bu dosyayı değiştirmek istediğinizden emin misiniz?';

  @override
  String get businessRegisterReplace => 'Değiştir';

  @override
  String get businessRegisterUpload => 'Yükle';

  @override
  String userProfileInitError(Object error) {
    return 'Profil başlatma hatası: $error';
  }

  @override
  String userProfileImagePickError(Object error) {
    return 'Fotoğraf seçme hatası: $error';
  }

  @override
  String get userProfileUnknownBusinessType => 'Bilinmeyen işletme türü';

  @override
  String get userProfileBusinessDashboard => 'İşletme Paneli';

  @override
  String get userProfileActivity => 'Aktivite';

  @override
  String get userProfileSavedParks => 'Kaydedilen Parklar';

  @override
  String get userProfileMatches => 'Eşleşmeler';

  @override
  String get userProfileMyOrders => 'Siparişlerim';

  @override
  String get myAppointments => 'Randevularım';

  @override
  String get myAppointmentsLoginRequired => 'Randevularınızı görmek için lütfen giriş yapın';

  @override
  String get appointmentHistory => 'Randevu Geçmişi';

  @override
  String get noAppointmentsYet => 'Henüz randevu yok';

  @override
  String get viewAppointment => 'Randevuyu Gör';

  @override
  String get appointmentStatusPending => 'Beklemede';

  @override
  String get appointmentStatusAwaitingPayment => 'Ödeme Bekleniyor';

  @override
  String get appointmentStatusConfirmed => 'Onaylandı';

  @override
  String get appointmentStatusConfirmedPaid => 'Onaylandı ve Ödendi';

  @override
  String get appointmentStatusPaymentExpired => 'Ödeme Süresi Doldu';

  @override
  String get appointmentStatusRejected => 'Reddedildi';

  @override
  String get appointmentStatusCompleted => 'Tamamlandı';

  @override
  String get appointmentStatusCancelledByUser => 'Siz iptal ettiniz';

  @override
  String get appointmentStatusCancelledByVet => 'Veteriner iptal etti';

  @override
  String get appointmentStatusExpired => 'Süresi doldu';

  @override
  String get unpaidStatusLabel => 'Ödenmedi';

  @override
  String get paymentNotRequiredStatusLabel => 'Ödeme gerekmiyor';

  @override
  String get refundUnderReviewStatusLabel => 'İade incelemede';

  @override
  String get refundRequestedStatusLabel => 'İade talep edildi';

  @override
  String get refundCompletedStatusLabel => 'İade tamamlandı';

  @override
  String get refundFailedStatusLabel => 'İade başarısız';

  @override
  String get noRefundRequiredStatusLabel => 'İade gerekmiyor';

  @override
  String get refundNotProcessedStatusLabel => 'İade henüz işlenmedi';

  @override
  String get veterinaryClinicFallback => 'Veteriner kliniği';

  @override
  String get veterinaryServiceFallback => 'Veteriner hizmeti';

  @override
  String get petFallback => 'Evcil hayvan';

  @override
  String get dogTypeLabel => 'köpek';

  @override
  String get userProfileAdoptionRequests => 'Sahiplenme Talepleri';

  @override
  String get userProfileBusiness => 'İşletme';

  @override
  String get userProfileAdmin => 'Admin';

  @override
  String get userProfileSupport => 'Destek';

  @override
  String get userProfileSendFeedback => 'Geri Bildirim Gönder';

  @override
  String get userProfileHelpCenter => 'Yardım Merkezi';

  @override
  String get userProfilePrivacy => 'Gizlilik';

  @override
  String get userProfileReportProblem => 'Sorun Bildir';

  @override
  String get userProfileSubscriptionPlans => 'Abonelik ve Planlar';

  @override
  String get userProfileLanguage => 'Dil';

  @override
  String get userProfileTheme => 'Tema';

  @override
  String get userProfileChangePassword => 'Şifre Değiştir';

  @override
  String get userProfileGuestTitle => 'Misafir olarak geziniyorsunuz';

  @override
  String get userProfileGuestSubtitle => 'Tüm özelliklerin kilidini açmak için giriş yapın';

  @override
  String get userProfileLoginSignUp => 'Giriş Yap / Kayıt Ol';

  @override
  String get userProfileLanguageEnglish => 'İngilizce';

  @override
  String get userProfileLanguagePersian => 'Farsça';

  @override
  String get userProfileLanguageTurkish => 'Türkçe';

  @override
  String get userProfileUnlockBusinessFeatures => 'İşletme Özelliklerini Aç 🚀';

  @override
  String get userProfileUpgradeBusinessDescription => 'İşletmenizi kaydetmek ve müşteri almaya başlamak için Gold\'a yükseltin.';

  @override
  String get userProfileUpgradeToGold => 'Gold\'a Yükselt';

  @override
  String get userProfileManageAdoptionCenter => 'Sahiplenme Merkezini Yönet';

  @override
  String get userProfileOverview => 'Genel Bakış';

  @override
  String get userProfileDogs => 'Köpekler';

  @override
  String get userProfileRequests => 'Talepler';

  @override
  String get userProfileOverviewSection => 'Genel Bakış Bölümü';

  @override
  String get userProfileDogsSection => 'Köpekler Bölümü';

  @override
  String get userProfileRequestsSection => 'Talepler Bölümü';

  @override
  String get userProfileSettingsSection => 'Ayarlar Bölümü';

  @override
  String get userProfileApplicationUnderReview => 'Başvuru İnceleniyor';

  @override
  String get userProfileApplicationUnderReviewDescription => 'İşletme başvurunuz başarıyla gönderildi ve şu anda inceleniyor.';

  @override
  String get userProfileAdminPanel => 'Admin Paneli';

  @override
  String get userProfileManageBusinessCenter => 'İşletme Merkezini Yönet';

  @override
  String get userProfileApplicationRejected => 'Başvuru Reddedildi';

  @override
  String userProfileRejectionReason(Object reason) {
    return 'Neden: $reason';
  }

  @override
  String get userProfileUpgradeToGoldToContinue => 'Devam etmek için Gold\'a yükseltin';

  @override
  String get userProfileReApply => 'Yeniden Başvur';

  @override
  String get userProfileBusinessStatus => 'İşletme Durumu';

  @override
  String get userProfileUnknownStatus => 'Bilinmiyor';

  @override
  String get userProfileChooseFromGallery => 'Galeriden Seç';

  @override
  String get userProfileRemovePhoto => 'Fotoğrafı Kaldır';

  @override
  String get userProfileImageSelectionFailed => 'Fotoğraf seçilemedi.';

  @override
  String get userProfileUsernameMinLength => 'Kullanıcı adı en az 3 karakter olmalı';

  @override
  String get userProfileUsernameMaxLength => 'Kullanıcı adı en fazla 20 karakter olmalı';

  @override
  String get userProfileUsernameNoSpaces => 'Kullanıcı adı boşluk içeremez';

  @override
  String get userProfilePhoneInvalidCharacters => 'Telefon geçersiz karakterler içeriyor';

  @override
  String get userProfileBioMaxLength => 'Biyografi 150 karakterden kısa olmalı';

  @override
  String get userProfileUsernameAlreadyTaken => 'Kullanıcı adı zaten alınmış';

  @override
  String get userProfileEmailUpdateFailed => 'E-posta güncellenemedi';

  @override
  String get userProfileUpdateFailed => 'Profil güncellenemedi.';

  @override
  String get userProfileChangePhoto => 'Fotoğrafı Değiştir';

  @override
  String get userProfileEnterUsername => 'Kullanıcı adı girin';

  @override
  String get userProfileEnterEmail => 'E-posta girin';

  @override
  String get userProfileOptionalPhoneNumber => 'İsteğe bağlı telefon numarası';

  @override
  String get userProfileBio => 'Biyografi';

  @override
  String get userProfileBioHint => 'Kendinizden biraz bahsedin';

  @override
  String get unnamedProduct => 'Adsız Ürün';

  @override
  String barcodeLabel(Object barcode) {
    return 'Barkod: $barcode';
  }

  @override
  String skuLabel(Object sku) {
    return 'SKU: $sku';
  }

  @override
  String get dealBadge => '💸 İndirim';

  @override
  String get lowStockBadge => '⚡ Az';

  @override
  String saveAmountLabel(Object amount) {
    return '$amount tasarruf';
  }

  @override
  String salePriceLabel(Object price) {
    return 'Satış: $price';
  }

  @override
  String stockLabel(Object stock) {
    return 'Stok: $stock';
  }

  @override
  String get addToCartButton => 'Sepete Ekle';

  @override
  String get buyNowButton => 'Şimdi Satın Al';

  @override
  String get addedToCart => 'Sepete eklendi';

  @override
  String get mediaNotReadyYet => 'Medya henüz hazır değil';

  @override
  String cargoLabel(Object price) {
    return 'Kargo: $price';
  }

  @override
  String carrierLabel(Object carrier) {
    return 'Kargo: $carrier';
  }

  @override
  String deliveryDaysRangeLabel(Object max, Object min) {
    return '$min-$max gün';
  }

  @override
  String get businessNotFound => 'İşletme bulunamadı';

  @override
  String get sectorDashboardNotImplementedYet => 'Bu sektör paneli henüz uygulanmadı';

  @override
  String get goBackButton => 'Geri Dön';

  @override
  String get backButton => 'Geri';

  @override
  String get veterinaryDashboardTitle => 'Veteriner Paneli';

  @override
  String get overviewTab => 'Genel Bakış';

  @override
  String get appointmentsTab => 'Randevular';

  @override
  String get shopProfileTitle => 'Mağaza Profili';

  @override
  String get noDescriptionYet => 'Henüz açıklama eklenmedi.';

  @override
  String get noRevenueYet => 'Henüz gelir yok';

  @override
  String get netRevenueLabel => 'Net Gelir';

  @override
  String get afterPlatformCommissionLabel => 'Platform komisyonundan sonra';

  @override
  String get grossSalesLabel => 'Brüt Satışlar';

  @override
  String get platformFeeLabel => 'Platform Ücreti';

  @override
  String get adjustmentsLabel => 'Düzeltmeler';

  @override
  String get recentOrdersTitle => 'Son Siparişler';

  @override
  String get latestOrdersSubtitle => 'Son 5 sipariş';

  @override
  String get viewAllButton => 'Tümünü gör';

  @override
  String get noDataLabel => 'Veri yok';

  @override
  String get noOrdersYet => 'Henüz sipariş yok';

  @override
  String orderNumberLabel(Object number) {
    return 'Sipariş #$number';
  }

  @override
  String itemsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# ürün',
      one: '# ürün',
    );
    return '$_temp0';
  }

  @override
  String trackingLabel(Object tracking) {
    return 'Takip: $tracking';
  }

  @override
  String get trackShipmentButton => 'Gönderiyi Takip Et';

  @override
  String get catalogStrengthUnavailable => 'Katalog gücü kullanılamıyor';

  @override
  String get catalogStrengthTitle => 'Katalog Gücü';

  @override
  String get productsTitle => 'Ürünler';

  @override
  String get noProductsFound => 'Ürün bulunamadı';

  @override
  String get lowStockLabel => 'Az Stok';

  @override
  String get strengthLabel => 'Güç';

  @override
  String get shippableLabel => 'Kargolanabilir';

  @override
  String get withKdvLabel => 'KDV ile';

  @override
  String get noProductsYet => 'Henüz ürün yok';

  @override
  String get kdvIncludedLabel => 'KDV dahil';

  @override
  String fromLabel(Object city) {
    return '$city çıkışlı';
  }

  @override
  String returnsLabel(Object days) {
    return '${days}g iade';
  }

  @override
  String get pickupLabel => 'Teslim al';

  @override
  String get sameDayLabel => 'Aynı gün';

  @override
  String get offersTitle => 'Teklifler';

  @override
  String get createOfferButton => 'Teklif Oluştur';

  @override
  String get videoLabel => 'VİDEO';

  @override
  String get catalogStrengthWeakLabel => 'Zayıf';

  @override
  String get catalogStrengthAddItemsMessage => 'Kataloğunuzu güçlendirmek için ürün, açıklama, medya ve stok ekleyin.';

  @override
  String get catalogStrengthWeakDetailsMessage => 'Ürün detaylarınız hâlâ zayıf. Daha fazla medya, açıklama ve stok bilgisi ekleyin.';

  @override
  String get catalogStrengthMediumLabel => 'Orta';

  @override
  String get catalogStrengthMediumMessage => 'İyi başlangıç. Görünürlüğü artırmak için daha zengin açıklamalar ve daha fazla ürün medyası ekleyin.';

  @override
  String get catalogStrengthStrongLabel => 'Güçlü';

  @override
  String get catalogStrengthStrongMessage => 'Harika katalog kalitesi. Ürünleriniz güçlü ve eksiksiz görünüyor.';

  @override
  String get shippingCalculatedLabel => 'Kargo hesaplanıyor';

  @override
  String get fragileLabel => 'Kırılgan';

  @override
  String get oversizeLabel => 'Büyük boy';

  @override
  String originLabel(Object city) {
    return 'Çıkış: $city';
  }

  @override
  String carriersCountLabel(Object count) {
    return '$count taşıyıcı';
  }

  @override
  String kdvRateLabel(Object percent) {
    return 'KDV %$percent';
  }

  @override
  String get myOrdersLoginRequired => 'Siparişlerinizi görmek için lütfen giriş yapın';

  @override
  String get myOrdersTitle => 'Siparişlerim';

  @override
  String get ordersTitle => 'Siparişler';

  @override
  String get searchByOrderIdOrProductNameHint => 'Sipariş numarası veya ürün adıyla ara';

  @override
  String get allFilterLabel => 'Tümü';

  @override
  String get noMatchingOrders => 'Eşleşen sipariş yok';

  @override
  String get orderLabel => 'Sipariş';

  @override
  String get itemsTitle => 'Ürünler';

  @override
  String qtyLabel(Object qty) {
    return 'Adet: $qty';
  }

  @override
  String get pendingStatusLabel => 'Beklemede';

  @override
  String get paidStatusLabel => 'Ödendi';

  @override
  String get confirmedStatusLabel => 'Onaylandı';

  @override
  String get preparingStatusLabel => 'Hazırlanıyor';

  @override
  String get shippedStatusLabel => 'Kargolandı';

  @override
  String get deliveredStatusLabel => 'Teslim edildi';

  @override
  String get completedStatusLabel => 'Tamamlandı';

  @override
  String get failedStatusLabel => 'Başarısız';

  @override
  String get cancelledStatusLabel => 'İptal edildi';

  @override
  String get paymentFailedStatusLabel => 'Ödeme başarısız';

  @override
  String get paidPayoutStatusLabel => 'Ödendi';

  @override
  String get readyForPayoutLabel => 'Ödeme için hazır';

  @override
  String get payoutPendingLabel => 'Ödeme beklemede';

  @override
  String get waitingForPaymentLabel => 'Ödeme bekleniyor';

  @override
  String get payoutNotSetLabel => 'Ödeme ayarlanmadı';

  @override
  String get confirmOrderButton => 'Siparişi Onayla';

  @override
  String get startPreparingButton => 'Hazırlamaya Başla';

  @override
  String get openOrderButton => 'Siparişi Aç';

  @override
  String get simulateUploadInvoiceButton => 'Fatura Yüklemeyi Simüle Et';

  @override
  String get invoiceSimulatedAsUploaded => 'Fatura yüklendi olarak simüle edildi';

  @override
  String invoiceError(Object error) {
    return 'Fatura hatası: $error';
  }

  @override
  String orderStatusUpdated(Object status) {
    return 'Durum $status olarak güncellendi';
  }

  @override
  String invoiceSummaryLabel(Object deadline, Object status) {
    return 'Fatura: $status • Son tarih: $deadline';
  }

  @override
  String sellerNetLabel(Object amount) {
    return 'Satıcı neti: $amount';
  }

  @override
  String referenceLabel(Object reference) {
    return 'Referans: $reference';
  }

  @override
  String buyerNameLabel(Object name) {
    return 'Ad: $name';
  }

  @override
  String buyerSurnameLabel(Object surname) {
    return 'Soyad: $surname';
  }

  @override
  String buyerIdentityNumberLabel(Object identityNumber) {
    return 'Kimlik No: $identityNumber';
  }

  @override
  String buyerCityLabel(Object city) {
    return 'Şehir: $city';
  }

  @override
  String buyerAddressLabel(Object address) {
    return 'Adres: $address';
  }

  @override
  String get buyerInfoTitle => 'Alıcı Bilgileri';

  @override
  String invoiceTypeLabel(Object type) {
    return 'Fatura Tipi: $type';
  }

  @override
  String get invoiceTitle => 'Fatura';

  @override
  String get uploadDeadlineLabel => 'Yükleme Son Tarihi';

  @override
  String get warningsLabel => 'Uyarılar';

  @override
  String get penaltyLabel => 'Ceza';

  @override
  String get invoiceSystemLabel => 'Fatura Sistemi';

  @override
  String get invoiceNoLabel => 'Fatura No';

  @override
  String get dateLabel => 'Tarih';

  @override
  String get cannotOpenInvoiceFile => 'Fatura dosyası açılamıyor';

  @override
  String get viewInvoiceButton => 'Faturayı Görüntüle';

  @override
  String get noInvoiceLabel => 'Fatura Yok';

  @override
  String get uploadingLabel => 'Yükleniyor...';

  @override
  String get invoiceUploadedLabel => 'Fatura Yüklendi';

  @override
  String get uploadInvoiceButton => 'Fatura Yükle';

  @override
  String get invoiceUploadDeadlinePassed => 'Fatura yükleme son tarihi geçti!';

  @override
  String get timelineTitle => 'Zaman Çizelgesi';

  @override
  String get payoutTitle => 'Ödeme';

  @override
  String amountLabel(Object amount) {
    return 'Tutar: $amount';
  }

  @override
  String get paymentWillBeTransferredByPetsupo => 'Ödeme Petsupo tarafından aktarılacak';

  @override
  String get pendingPayoutLabel => 'Ödeme beklemede';

  @override
  String get waitingForCustomerPayment => 'Müşteri ödemesi bekleniyor';

  @override
  String get actionsTitle => 'İşlemler';

  @override
  String get payoutMarkedAsPaid => 'Ödeme ödendi olarak işaretlendi';

  @override
  String get trackingNumberLabel => 'Takip Numarası';

  @override
  String get trackingNumberRequired => 'Takip numarası gerekli';

  @override
  String get returnCarrierRequired => 'Kargo firması gerekli';

  @override
  String get returnShippedBackFailed => 'İade gönderildi olarak işaretlenemedi';

  @override
  String get returnTrackingNumberLabel => 'İade Takip Numarası';

  @override
  String get returnTrackingNumberHelperText => 'İade gönderisi için verilen takip numarasını girin.';

  @override
  String get returnCarrierHelperText => 'Orijinal teslimatta kullanılan kargo firmasını kullanın.';

  @override
  String get originalShipmentTrackingLabel => 'Orijinal Gönderi Takibi';

  @override
  String get returnShipmentTrackingLabel => 'İade Gönderi Takibi';

  @override
  String get returnShippedBackTimelineLabel => 'İade geri gönderildi';

  @override
  String get carrierMissingFromOrder => 'Siparişte kargo bilgisi yok';

  @override
  String get enterTrackingNumber => 'Takip numarası girin';

  @override
  String get shipOrderButton => 'Siparişi Kargola';

  @override
  String get markAsDeliveredButton => 'Teslim Edildi Olarak İşaretle';

  @override
  String get goToCarrierWebsiteButton => 'Kargo Sitesine Git';

  @override
  String get noTimelineYet => 'Henüz zaman çizelgesi yok';

  @override
  String get orderNotFound => 'Sipariş bulunamadı';

  @override
  String get invoiceUploadedSuccessfully => 'Fatura başarıyla yüklendi';

  @override
  String uploadFailed(Object error) {
    return 'Yükleme başarısız: $error';
  }

  @override
  String get orderShipped => 'Sipariş kargolandı';

  @override
  String get sellerTaxNumberMissing => 'Satıcı vergi numarası eksik';

  @override
  String get buyerIdentityNumberMissing => 'Alıcı kimlik numarası eksik';

  @override
  String get buyerTaxNumberMissing => 'Alıcı vergi numarası eksik';

  @override
  String get invoiceSystemMismatch => 'Fatura tipi uyuşmuyor';

  @override
  String get invoiceStatusPendingUploadLabel => 'Fatura bekleniyor';

  @override
  String get invoiceStatusUploadedValidLabel => 'Fatura yüklendi';

  @override
  String get invoiceStatusUploadedWithIssuesLabel => 'Kontrol gerekli';

  @override
  String get invoiceStatusLateLabel => 'Gecikti';

  @override
  String get invoiceStatusApprovedLabel => 'Fatura onaylandı';

  @override
  String get invoiceStatusRejectedLabel => 'Fatura reddedildi';

  @override
  String get eArsivLabel => 'e-Arşiv';

  @override
  String get eFaturaLabel => 'e-Fatura';

  @override
  String get fileIsEmpty => 'Dosya boş';

  @override
  String get fileTooLarge => 'Dosya çok büyük';

  @override
  String get upgradePageTitle => 'Yükselt';

  @override
  String get upgradeHeroTitle => 'Daha iyi eşleşmeleri daha hızlı bulun 🐾';

  @override
  String get upgradeHeroSubtitle => 'Premium özelliklerin, daha iyi görünürlüğün, özel tekliflerin ve işletme araçlarının kilidini açın.';

  @override
  String get premiumPlanSubtitle => 'Aktif evcil hayvan sahipleri için';

  @override
  String get premiumPlanFeatureUnlimitedChat => 'Sınırsız sohbet';

  @override
  String get premiumPlanFeatureAdvancedMatchingFilters => 'Gelişmiş eşleşme filtreleri';

  @override
  String get premiumPlanFeatureExclusivePetOffers => 'Özel evcil hayvan teklifleri';

  @override
  String get premiumPlanFeatureBetterProfileExperience => 'Daha iyi profil deneyimi';

  @override
  String get goldPlanSubtitle => 'Evcil hayvan işletmeleri ve yoğun kullanıcılar için';

  @override
  String get mostPopularLabel => 'EN POPÜLER';

  @override
  String get goldPlanFeatureEverythingInPremium => 'Premium\'daki her şey';

  @override
  String get goldPlanFeatureBusinessRegistrationAccess => 'İşletme kaydı erişimi';

  @override
  String get goldPlanFeatureBoostedVisibility => 'Artırılmış görünürlük';

  @override
  String get goldPlanFeatureBusinessDashboardAccess => 'İşletme paneli erişimi';

  @override
  String get goldPlanFeaturePremiumChatAndOffers => 'Premium sohbet ve teklifler';

  @override
  String get storeNotReadyTryAgain => 'Mağaza hazır değil. Tekrar deneyin.';

  @override
  String get processingLabel => 'İşleniyor...';

  @override
  String get restoreRequestSent => 'Geri yükleme isteği gönderildi.';

  @override
  String get restorePurchases => 'Satın Alımları Geri Yükle';

  @override
  String get upgradePaymentTerms => 'Ödemeniz onaylandığında App Store hesabınızdan tahsil edilir. Geçerli dönem bitmeden en az 24 saat önce iptal edilmediği sürece abonelikler otomatik yenilenir.';

  @override
  String get autoRenewableMonthlySubscription => 'Otomatik yenilenen aylık abonelik';

  @override
  String get securePaymentNotice => 'Güvenli ödeme • İstediğiniz zaman iptal edin • Planlar App Store tarafından yönetilir';

  @override
  String continueWithPlan(Object plan) {
    return '$plan ile devam et';
  }

  @override
  String get loadingLabel => 'Yükleniyor...';

  @override
  String get privacyPolicyLabel => 'Gizlilik Politikası';

  @override
  String get termsOfUseLabel => 'Kullanım Şartları';

  @override
  String adoptionRequestSubtitle(Object dogName) {
    return '• $dogName';
  }

  @override
  String get adoptionStepPersonalInfoTitle => '1️⃣ Kişisel Bilgiler';

  @override
  String get adoptionFullNameLabel => 'Ad Soyad';

  @override
  String get adoptionFullNameHint => 'Adınızı ve soyadınızı girin';

  @override
  String get adoptionEnterFullName => 'Adınızı ve soyadınızı girin';

  @override
  String get genderLabel => 'Cinsiyet';

  @override
  String get adoptionSelectGender => 'Cinsiyet seçin';

  @override
  String get adoptionPhoneHint => 'örn. +90 5xx xxx xxxx';

  @override
  String get adoptionEnterValidPhone => 'Geçerli bir telefon numarası girin';

  @override
  String get adoptionIncomeRangeLabel => 'Aylık Gelir Aralığı';

  @override
  String get adoptionSelectIncomeRange => 'Gelir aralığı seçin';

  @override
  String get adoptionIncomeRange0_2000 => '0 - 2.000';

  @override
  String get adoptionIncomeRange2000_5000 => '2.000 - 5.000';

  @override
  String get adoptionIncomeRange5000_10000 => '5.000 - 10.000';

  @override
  String get adoptionIncomeRange10000Plus => '10.000+';

  @override
  String get adoptionStepHousingTitle => '2️⃣ Konut';

  @override
  String get adoptionHousingTypeLabel => 'Konut tipi';

  @override
  String get adoptionHousingApartment => 'Daire';

  @override
  String get adoptionHousingHouse => 'Ev';

  @override
  String get adoptionHousingVilla => 'Villa';

  @override
  String get adoptionOwnershipLabel => 'Sahip / Kiralık';

  @override
  String get adoptionOwnershipOwned => 'Sahip';

  @override
  String get adoptionOwnershipRented => 'Kiralık';

  @override
  String get adoptionLandlordPermissionRequired => 'Ev sahibi izni (gerekli)';

  @override
  String get adoptionHasGarden => 'Bahçe var';

  @override
  String get adoptionFenceHeightLabel => 'Çit yüksekliği (cm)';

  @override
  String get adoptionFenceHeightHint => 'örn. 120';

  @override
  String get adoptionEnterValidFenceHeight => '1..400 girin';

  @override
  String get adoptionStepExperienceTitle => '3️⃣ Deneyim';

  @override
  String get adoptionYearsOfExperienceLabel => 'Deneyim yılı';

  @override
  String get adoptionYearsOfExperienceHint => '0..60';

  @override
  String get adoptionEnterYearsOfExperience => '0..60 girin';

  @override
  String get adoptionPreviousDogQuestion => 'Daha önce köpeğiniz oldu mu? (Evet/Hayır)';

  @override
  String get adoptionPreviousDogReasonLabel => 'Önceki köpeğiniz artık neden sizinle değil?';

  @override
  String get adoptionPreviousDogReasonHint => 'Kısaca açıklayın';

  @override
  String get adoptionExplainPreviousDog => 'En az 10 karakter';

  @override
  String get adoptionOtherPetsAtHome => 'Evde başka evcil hayvanlar var';

  @override
  String get adoptionDescribeOtherPetsLabel => 'Diğer evcil hayvanlarınızı anlatın';

  @override
  String get adoptionDescribeOtherPetsHint => 'örn. 2 kedi, aşılı';

  @override
  String get adoptionRequiredShort => 'Gerekli';

  @override
  String get adoptionDescribeOtherPetsRequired => 'Lütfen diğer evcil hayvanlarınızı anlatın';

  @override
  String get adoptionMotivationMessageLabel => 'Motivasyon mesajı';

  @override
  String get adoptionMotivationMinLength => 'Motivasyon en az 20 karakter olmalıdır';

  @override
  String get adoptionStepFinancialCommitmentTitle => '4️⃣ Finansal ve Taahhüt';

  @override
  String get adoptionCanAffordVetExpenses => 'Veteriner masraflarını karşılayabilir mi?';

  @override
  String get adoptionEmergencySavingsAvailable => 'Acil durum birikimi var mı?';

  @override
  String get adoptionUploadsSectionTitle => '📷 Yüklemeler';

  @override
  String get adoptionHousePhotosRequiredTitle => 'Ev fotoğrafları (gerekli)';

  @override
  String get adoptionUploadAtLeastOnePhoto => 'En az 1 fotoğraf yükleyin';

  @override
  String adoptionUploadedCount(Object count) {
    return '$count yüklendi';
  }

  @override
  String get adoptionUploadButton => 'Yükle';

  @override
  String get adoptionClearButton => 'Temizle';

  @override
  String get adoptionIdPhotoRequiredTitle => 'Kimlik fotoğrafı (gerekli)';

  @override
  String get adoptionNotUploaded => 'Yüklenmedi';

  @override
  String get adoptionUploaded => 'Yüklendi';

  @override
  String get adoptionReplaceButton => 'Değiştir';

  @override
  String get adoptionRemoveButton => 'Kaldır';

  @override
  String get adoptionProofOfIncomeOptionalTitle => 'Gelir belgesi (isteğe bağlı)';

  @override
  String get adoptionOptionalLabel => 'İsteğe bağlı';

  @override
  String get adoptionAgreeContractRequiredLabel => 'Sahiplenme sözleşmesini imzalamayı kabul ediyorum (gerekli)';

  @override
  String get adoptionAgreeContractRequired => 'Sahiplenme sözleşmesini kabul etmelisiniz';

  @override
  String get adoptionUploadIdPhoto => 'Lütfen bir kimlik fotoğrafı yükleyin';

  @override
  String get adoptionNextButton => 'İleri';

  @override
  String smartPriceSuggestedRangeLabel(Object currency, Object max, Object min) {
    return 'Önerilen aralık: $min - $max $currency';
  }

  @override
  String smartPriceSuggestedPriceLabel(Object currency, Object price) {
    return 'Önerilen fiyat: $price $currency';
  }

  @override
  String get bestPriceStrategyLabel => 'En iyi fiyat';

  @override
  String get aggressiveLowStrategyLabel => 'Agresif düşük';

  @override
  String get competitiveStrategyLabel => 'Rekabetçi';

  @override
  String get slightlyHighStrategyLabel => 'Biraz yüksek';

  @override
  String get tooExpensiveStrategyLabel => 'Çok pahalı';

  @override
  String get manualPricingLabel => 'Manuel fiyatlandırma';

  @override
  String get bestPricePositionLabel => 'En İyi Fiyat 🏆';

  @override
  String get aggressiveLowPositionLabel => 'Agresif Düşük ⚡';

  @override
  String get competitivePositionLabel => 'Rekabetçi ✅';

  @override
  String get slightlyHighPositionLabel => 'Biraz Yüksek 📈';

  @override
  String get tooExpensivePositionLabel => 'Çok Pahalı ⚠️';

  @override
  String get marketSourceAggregateLabel => 'Toplu veri';

  @override
  String get marketSourceFallbackProductsLabel => 'Yedek ürünler';

  @override
  String get marketSourceNoneLabel => 'Piyasa verisi yok';

  @override
  String get marketSourceInvalidPricesLabel => 'Geçersiz fiyatlar';

  @override
  String get marketSourceErrorLabel => 'Hata';

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
  String get categoryFood => 'Yiyecek';

  @override
  String get categoryAccessories => 'Aksesuarlar';

  @override
  String get categoryHealth => 'Sağlık';

  @override
  String get categoryToys => 'Oyuncaklar';

  @override
  String get subCategoryDryFood => 'Kuru Mama';

  @override
  String get subCategoryWetFood => 'Yaş Mama';

  @override
  String get subCategoryTreats => 'Ödül Mamaları';

  @override
  String get subCategoryCollar => 'Yaka Tasması';

  @override
  String get subCategoryLeash => 'Tasma';

  @override
  String get subCategoryClothing => 'Giyim';

  @override
  String get subCategoryVitamins => 'Vitaminler';

  @override
  String get subCategoryMedicine => 'İlaç';

  @override
  String get subCategoryChewToy => 'Çiğneme Oyuncağı';

  @override
  String get subCategoryInteractive => 'Etkileşimli';

  @override
  String get productAlreadyExistsTitle => 'Ürün zaten mevcut';

  @override
  String get productAlreadyExistsDescription => 'Bu ürün zaten mevcut. Ürün düzenleyici açılıyor.';

  @override
  String get continueButton => 'Devam';

  @override
  String get productNameMustBeAtLeast4Chars => 'Ürün adı en az 4 karakter olmalıdır';

  @override
  String get invalidBarcode => 'Geçersiz barkod';

  @override
  String get invalidSku => 'Geçersiz SKU';

  @override
  String get invalidWholesalePrice => 'Geçersiz toptan fiyat';

  @override
  String get wholesaleMinQuantityMustBeAtLeast2 => 'Toptan minimum adet en az 2 olmalıdır';

  @override
  String get kdvRateIsRequired => 'Bir KDV oranı seçin';

  @override
  String get invalidPrice => 'Geçersiz fiyat';

  @override
  String get invalidDiscountPrice => 'Geçersiz indirimli fiyat';

  @override
  String get discountMustBeLowerThanOriginalPrice => 'İndirimli fiyat orijinal fiyattan düşük olmalıdır';

  @override
  String get wholesalePriceMustBeLowerThanRetailPrice => 'Toptan fiyat perakende fiyattan düşük olmalıdır';

  @override
  String get invalidStock => 'Geçersiz stok';

  @override
  String get stockMustBeAtLeastWholesaleMinQuantity => 'Stok, toptan minimum adetten az olamaz';

  @override
  String get inventoryStockFieldLabel => 'Stok';

  @override
  String get invalidLowStockAlert => 'Geçersiz düşük stok uyarısı';

  @override
  String get addAtLeast1Media => 'En az 1 medya öğesi ekleyin';

  @override
  String get descriptionMustBeAtLeast10Characters => 'Açıklama en az 10 karakter olmalıdır';

  @override
  String get selectCategory => 'Bir kategori seçin';

  @override
  String get weightOrDesiIsRequired => 'Ağırlık veya desi gerekli';

  @override
  String get lengthIsRequired => 'Uzunluk gerekli';

  @override
  String get widthIsRequired => 'Genişlik gerekli';

  @override
  String get heightIsRequired => 'Yükseklik gerekli';

  @override
  String get invalidDesiValue => 'Geçersiz desi değeri';

  @override
  String get fixedShippingFeeIsRequired => 'Sabit kargo ücreti gerekli';

  @override
  String get invalidShippingFee => 'Geçersiz kargo ücreti';

  @override
  String get freeShippingThresholdIsRequired => 'Ücretsiz kargo eşiği gerekli';

  @override
  String get invalidPreparationTime => 'Geçersiz hazırlık süresi';

  @override
  String get invalidMaxDeliveryDays => 'Geçersiz maksimum teslimat süresi';

  @override
  String get selectAtLeast1CargoCarrier => 'En az 1 kargo firması seçin';

  @override
  String get returnWindowCannotBeLessThan14Days => 'İade süresi 14 günden az olamaz';

  @override
  String get returnCarrierIsRequired => 'İade taşıyıcısı gerekli';

  @override
  String get shippingPayerMismatch => 'Kargo ödeyen uyuşmuyor';

  @override
  String get productSavedStatus => 'Ürün kaydedildi ✅';

  @override
  String get scanFailed => 'Tarama başarısız';

  @override
  String estimatedPriceLabel(Object currency, Object price) {
    return 'Tahmini fiyat: $price $currency';
  }

  @override
  String get loadedFromGlobalApi => 'Küresel API\'den yüklendi';

  @override
  String productFallbackName(Object short) {
    return 'Ürün $short';
  }

  @override
  String fallbackEstimateLabel(Object currency, Object price) {
    return 'Yedek tahmin: $price $currency';
  }

  @override
  String offlineEstimateLabel(Object currency, Object price) {
    return 'Çevrimdışı tahmin: $price $currency';
  }

  @override
  String errorEstimateLabel(Object currency, Object price) {
    return 'Hata tahmini: $price $currency';
  }

  @override
  String smartDescriptionDefault(Object brand, Object name) {
    return '$name markalı $brand, evcil hayvan sahipleri için güvenilir bir seçenektir.';
  }

  @override
  String get trustedBrand => 'Güvenilir marka';

  @override
  String get productDetectedStatus => 'Ürün algılandı';

  @override
  String get noProductFoundAnywhere => 'Hiçbir yerde ürün bulunamadı';

  @override
  String get enterProductNameFirst => 'Önce ürün adını girin';

  @override
  String smartDescriptionFood(Object brand, Object name, Object subCategory) {
    return '$name markalı $brand, evcil hayvanlar için pratik bir seçimdir. $subCategory kategorisine uyar ve günlük kullanım için uygundur.';
  }

  @override
  String smartDescriptionAccessories(Object brand, Object name, Object subCategory) {
    return '$name markalı $brand, $subCategory kategorisinde kullanışlı bir aksesuardır.';
  }

  @override
  String smartDescriptionHealth(Object brand, Object name, Object subCategory) {
    return '$name markalı $brand, $subCategory kategorisinde evcil hayvan sağlığı ve bakımı için tasarlanmıştır.';
  }

  @override
  String smartDescriptionToys(Object brand, Object name, Object subCategory) {
    return '$name markalı $brand, $subCategory kategorisinden eğlenceli bir oyuncaktır.';
  }

  @override
  String get descriptionSuggestionAdded => 'Açıklama önerisi eklendi';

  @override
  String get noPricingDataYet => 'Henüz fiyat verisi yok';

  @override
  String get smartPriceSuggestionTitle => 'Akıllı Fiyat Önerisi';

  @override
  String get waitingForPricingData => 'Fiyat verileri bekleniyor...';

  @override
  String get tapToApplySuggestedPrice => 'Önerilen fiyatı uygulamak için dokun';

  @override
  String get smartPricingEngineTitle => 'Akıllı Fiyatlandırma Motoru';

  @override
  String get modeLabel => 'Mod';

  @override
  String get noMarketDataLabel => 'Piyasa verisi yok';

  @override
  String get usingSmartEstimationLabel => 'Akıllı tahmin kullanılıyor 🧠';

  @override
  String get marketIntelligenceTitle => 'Piyasa Analizi';

  @override
  String get avgPriceLabel => 'Ortalama fiyat';

  @override
  String get medianPriceLabel => 'Medyan fiyat';

  @override
  String get sellerCountLabel => 'Satıcı sayısı';

  @override
  String get bestPriceLabel => 'En iyi fiyat';

  @override
  String get highestPriceLabel => 'En yüksek fiyat';

  @override
  String get yourGapVsMarketLabel => 'Piyasaya göre farkınız';

  @override
  String get positionLabel => 'Konum';

  @override
  String get profitMarginLabel => 'Kâr marjı';

  @override
  String get sourceLabel => 'Kaynak';

  @override
  String get searchingProductStatus => 'Ürün aranıyor...';

  @override
  String get productAlreadyExistsOpeningEditStatus => 'Ürün mevcut, düzenleyici açılıyor...';

  @override
  String get fetchingProductDataStatus => 'Ürün verileri alınıyor...';

  @override
  String get analyzingMarketStatus => 'Piyasa analiz ediliyor...';

  @override
  String get marketAvgLabel => 'Ortalama fiyat';

  @override
  String get marketMedianLabel => 'Medyan fiyat';

  @override
  String get marketSellersLabel => 'Satıcı sayısı';

  @override
  String emergencyFallbackLabel(Object currency, Object price) {
    return 'Acil yedek: $price $currency';
  }

  @override
  String get productReadyStatus => 'Ürün hazır ✅';

  @override
  String get failedToLoadProductStatus => 'Ürün yüklenemedi';

  @override
  String get barcodeLookupFailed => 'Barkod sorgusu başarısız';

  @override
  String get editProductTitle => 'Ürünü Düzenle';

  @override
  String get addProductTitle => 'Ürün Ekle';

  @override
  String get tapToReplaceOrAddMedia => 'Medya değiştirmek veya eklemek için dokun';

  @override
  String get tapToAddMedia => 'Medya eklemek için dokun';

  @override
  String get basicInfoSectionTitle => 'Temel bilgiler';

  @override
  String get productNameMinCharsLabel => 'Ürün adı *';

  @override
  String get brandLabel => 'Marka';

  @override
  String get barcodeFieldLabel => 'Barkod';

  @override
  String get enterBarcodeHint => 'Barkodu girin veya tarayın';

  @override
  String get noBarcodeSkuHint => 'Barkod isteğe bağlıdır. Boşsa SKU otomatik oluşturulur.';

  @override
  String get scanButtonLabel => 'Tara';

  @override
  String get skuCodeLabel => 'SKU Kodu';

  @override
  String get autoGeneratedSkuHint => 'Boşsa otomatik oluşturulur';

  @override
  String get shippingAndDeliverySectionTitle => 'Kargo ve teslimat';

  @override
  String get thisProductHasADiscount => 'Bu ürün indirimli';

  @override
  String get originalPriceLabel => 'Orijinal fiyat';

  @override
  String get priceLabel => 'Fiyat';

  @override
  String get appointmentDetailTitle => 'Randevu Detayı';

  @override
  String get appointmentNotFound => 'Randevu bulunamadı';

  @override
  String get petLabel => 'Evcil Hayvan';

  @override
  String get statusLabel => 'Durum';

  @override
  String get paymentLabel => 'Ödeme';

  @override
  String get goToPaymentButton => 'Ödemeye Git';

  @override
  String get markedAsCompletedSnack => 'Tamamlandı olarak işaretlendi';

  @override
  String get markAsCompletedButton => 'Tamamlandı Olarak İşaretle';

  @override
  String get wholesalePriceLabel => 'Toptan fiyat';

  @override
  String get minimumQuantityForWholesaleLabel => 'Toptan için minimum adet';

  @override
  String get wholesaleAppliesHint => 'Toptan indirimi bu adetten itibaren geçerlidir';

  @override
  String get visibleOnlyToBusinessAccountsHint => 'Sadece işletme hesaplarına görünür';

  @override
  String get usersWillSeeDiscountHint => 'Kullanıcılar indirim rozetini görecek';

  @override
  String get discountPriceLabel => 'İndirimli fiyat';

  @override
  String get kdvLabel => 'KDV';

  @override
  String get lengthLabel => 'Uzunluk';

  @override
  String get widthLabel => 'Genişlik';

  @override
  String get heightLabel => 'Yükseklik';

  @override
  String calculatedDesiLabel(Object value) {
    return 'Hesaplanan desi: $value';
  }

  @override
  String get manualDesiOverrideOptionalLabel => 'Manuel desi (isteğe bağlı)';

  @override
  String get shippingModeLabel => 'Kargo modu';

  @override
  String get carrierCalculatedLabel => 'Kargo hesaplı';

  @override
  String get fixedShippingFeeLabel => 'Sabit kargo ücreti';

  @override
  String get sellerPaysShippingLabel => 'Kargoyu satıcı öder';

  @override
  String get enableFreeShippingCampaignLabel => 'Ücretsiz kargo kampanyasını etkinleştir';

  @override
  String get freeShippingThresholdLabel => 'Ücretsiz kargo eşiği';

  @override
  String get preparationTimeDaysLabel => 'Hazırlık süresi (gün)';

  @override
  String get maxDeliveryTimeDaysLabel => 'Maksimum teslimat süresi (gün)';

  @override
  String get cargoCompaniesTitle => 'Kargo şirketleri';

  @override
  String get allowReturnsLabel => 'İade kabul et';

  @override
  String get returnWindowDaysLabel => 'İade süresi (gün)';

  @override
  String get returnShippingPayerLabel => 'İade kargosunu kim öder';

  @override
  String get sellerOptionLabel => 'Satıcı';

  @override
  String get buyerOptionLabel => 'Alıcı';

  @override
  String get sellerContractedCarrierOnlyLabel => 'Sadece anlaşmalı taşıyıcı varsa satıcı';

  @override
  String get inventoryTitle => 'Envanter';

  @override
  String get lowStockAlertLabel => 'Düşük stok uyarısı';

  @override
  String get mainCategoryLabel => 'Ana kategori';

  @override
  String get subCategoryLabel => 'Alt kategori';

  @override
  String get generatingLabel => 'Oluşturuluyor...';

  @override
  String get suggestLabel => 'Öner';

  @override
  String get updateProductTitle => 'Ürünü Güncelle';

  @override
  String get sellInstantlyButtonLabel => 'Hemen sat';

  @override
  String get shippingEstimateTitle => 'Kargo tahmini';

  @override
  String desiLabel(Object value) {
    return 'Desi: $value';
  }

  @override
  String billableLabel(Object value) {
    return 'Faturalandırılabilir: $value';
  }

  @override
  String basePriceLabel(Object currency, Object value) {
    return 'Temel: $value $currency';
  }

  @override
  String extraLabel(Object currency, Object value) {
    return 'Ek: $value $currency';
  }

  @override
  String totalPriceLabel(Object currency, Object value) {
    return 'Toplam: $value $currency';
  }

  @override
  String get returnRequestsTitle => 'İade Talepleri';

  @override
  String get returnAvailableAfterDeliveryMessage => 'İade talebi teslimattan sonra kullanılabilir.';

  @override
  String get noReturnsYet => 'Henüz iade talebi yok';

  @override
  String get requestReturnButton => 'İade Talep Et';

  @override
  String get returnRequestSubmitted => 'İade talebi gönderildi';

  @override
  String get selectReturnReasonLabel => 'Sebep seçin';

  @override
  String get returnDescriptionHint => 'Sorunu kısaca açıklayın...';

  @override
  String get selectReturnItemsLabel => 'İade edilecek ürünleri seçin';

  @override
  String returnRequestLabel(Object id) {
    return 'İade #$id';
  }

  @override
  String get reasonLabel => 'Sebep';

  @override
  String get refundAmountLabel => 'İade tutarı';

  @override
  String get returnAmountLabel => 'Tahmini iade';

  @override
  String get shippingResponsibilityLabel => 'İade kargosu';

  @override
  String get refundTypeLabel => 'İade türü';

  @override
  String get returnTimelineTitle => 'İade zaman çizelgesi';

  @override
  String get refundResultLabel => 'İade sonucu';

  @override
  String get returnActionCompleted => 'İade güncellendi';

  @override
  String get approveReturnButton => 'Onayla';

  @override
  String get rejectReturnButton => 'Reddet';

  @override
  String get cancelReturnButton => 'İadeyi iptal et';

  @override
  String get markShippedBackButton => 'Geri gönderildi olarak işaretle';

  @override
  String get markReceivedButton => 'Teslim alındı olarak işaretle';

  @override
  String get triggerRefundButton => 'İadeyi başlat';

  @override
  String get returnStatusPending => 'Beklemede';

  @override
  String get returnStatusApproved => 'Onaylandı';

  @override
  String get returnStatusRejected => 'Reddedildi';

  @override
  String get returnStatusShippedBack => 'Geri gönderildi';

  @override
  String get returnStatusReceivedBySeller => 'Satıcı tarafından alındı';

  @override
  String get returnStatusRefundPending => 'İade beklemede';

  @override
  String get returnStatusRefundFailed => 'İade başarısız';

  @override
  String get returnStatusRefunded => 'İade edildi';

  @override
  String get returnStatusCancelled => 'İptal edildi';

  @override
  String get returnReasonDamaged => 'Hasarlı';

  @override
  String get returnReasonWrongProduct => 'Yanlış ürün';

  @override
  String get returnReasonMissingParts => 'Eksik parçalar';

  @override
  String get returnReasonNotAsDescribed => 'Açıklamada belirtildiği gibi değil';

  @override
  String get returnReasonChangedMind => 'Fikrimi değiştirdim';

  @override
  String get returnReasonOther => 'Diğer';

  @override
  String get refundTypeFullLabel => 'Tam iade';

  @override
  String get refundTypePartialLabel => 'Kısmi iade';

  @override
  String get refundTypeShippingLabel => 'Kargo iadesi';

  @override
  String get shippingResponsibilitySellerLabel => 'Satıcı';

  @override
  String get shippingResponsibilityBuyerLabel => 'Alıcı';

  @override
  String get shippingResponsibilityContractCarrierLabel => 'Sadece anlaşmalı taşıyıcı varsa satıcı';

  @override
  String get returnCarrierLabel => 'İade Taşıyıcısı';

  @override
  String get returnImagesAdded => 'Görseller eklendi';

  @override
  String get refundRejectedStatusLabel => 'İade reddedildi';
}
