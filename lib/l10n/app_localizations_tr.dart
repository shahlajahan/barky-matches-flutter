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
  String get marketplaceDisclaimerTitle => 'Devam etmeden önce';

  @override
  String get marketplaceDisclaimerMessage => 'PetSupo, sizi bağımsız işletmeler ve hizmet sağlayıcılarla buluşturan bir platformdur. Seçtiğiniz hizmet, gösterilen işletme veya sağlayıcı tarafından sunulur. PetSupo, bu bağımsız hizmetin kalitesini veya gerçekleştirilmesini garanti etmez ve bundan sorumlu değildir. Lütfen devam etmeden önce işletme veya sağlayıcı bilgilerini inceleyin.';

  @override
  String get marketplaceDisclaimerAccept => 'Kabul Et ve Devam Et';

  @override
  String get marketplaceDisclaimerCancel => 'İptal';

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
  String get checkoutPhoneHint => '5XXXXXXXXX biçiminde telefon';

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
  String get checkoutSmsOption => 'Kısa mesaj (SMS)';

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
  String get checkoutMultiSellerInfoTitle => 'Tek ödeme, ayrı siparişler';

  @override
  String get checkoutMultiSellerInfoBody => 'Tek bir ödeme yapacaksınız. Her satıcı için ayrı bir sipariş oluşturulacak.';

  @override
  String checkoutSellerSection(Object sellerName) {
    return '$sellerName';
  }

  @override
  String checkoutSellerFallback(int number) {
    return 'Satıcı $number';
  }

  @override
  String get checkoutSellerSubtotal => 'Satıcı ara toplamı';

  @override
  String get checkoutProductsTotal => 'Ürünler toplamı';

  @override
  String get checkoutShippingMethod => 'Kargo yöntemi';

  @override
  String get checkoutShippingCost => 'Kargo ücreti';

  @override
  String get checkoutShippingTotal => 'Toplam kargo';

  @override
  String get checkoutEstimatedDelivery => 'Tahmini teslimat';

  @override
  String get checkoutSellerTotal => 'Satıcı toplamı';

  @override
  String get checkoutMultiOrderSuccessTitle => 'Ödeme başarılı';

  @override
  String get checkoutMultiOrderSuccessBody => 'Ödemeniz tamamlandı ve her satıcı için ayrı sipariş oluşturuldu.';

  @override
  String checkoutSellerOrderLabel(int number) {
    return 'Satıcı siparişi $number';
  }

  @override
  String get checkoutOpenOrder => 'Siparişi görüntüle';

  @override
  String get checkoutMultiOrderExit => 'Ana sayfaya dön';

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
  String get selectDate => 'Tarih Seç';

  @override
  String get selectTime => 'Saat Seçin';

  @override
  String get appointmentNoteHint => 'Klinik için bir not ekleyin...';

  @override
  String get requestAppointment => 'Randevu İste';

  @override
  String get requestSentTitle => 'İstek Gönderildi 🐾';

  @override
  String get requestSentMessage => 'Randevu talebiniz kliniğe gönderildi.';

  @override
  String get okButton => 'Tamam';

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
  String get instagramTitle => 'Instagram Sayfası';

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
  String get noServicesAvailable => 'Kullanılabilir hizmet yok';

  @override
  String errorLoadingServices(Object error) {
    return 'Hizmetler yüklenirken hata: $error';
  }

  @override
  String get noServicesProvided => 'Hizmet belirtilmedi.';

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
  String get myDogs => 'Evcil Hayvanlarım';

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
  String get appTitle => 'PetSupo Uygulaması';

  @override
  String get loadingUserData => 'Kullanıcı verileri yükleniyor...';

  @override
  String get welcomeToPetSopu => 'PetSupo\'e hoş geldiniz!';

  @override
  String get welcomeTo => 'Hoş geldiniz';

  @override
  String get petSopu => 'PetSupo';

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
  String get passwordValidation => 'En az 8 karakter; bir harf ve bir rakam kullanın.';

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
  String get invalidVerificationCode => 'Geçersiz doğrulama kodu. Lütfen tekrar deneyin.';

  @override
  String get verificationCodeExpired => 'Bu kodun süresi doldu. Yeni bir kod isteyin.';

  @override
  String get unableToVerifyEmail => 'Şu anda doğrulama yapılamıyor. Lütfen tekrar deneyin.';

  @override
  String get unableToSendVerificationCode => 'Yeni kod şu anda gönderilemiyor. Lütfen tekrar deneyin.';

  @override
  String verificationCodeSentTo(Object email) {
    return 'Kod şu adrese gönderildi: $email';
  }

  @override
  String get verificationCodeSentToLabel => 'Doğrulama kodu şu adrese gönderildi';

  @override
  String get sendingVerificationCode => 'Gönderiliyor...';

  @override
  String resendCodeAvailableIn(Object seconds) {
    return 'Kod gönderme $seconds saniye sonra kullanılabilir';
  }

  @override
  String get changeEmail => 'E-postayı değiştir';

  @override
  String verificationCodeSent(Object email) {
    return '$email adresine bir doğrulama kodu gönderildi';
  }

  @override
  String get enterCodeLabel => '6 haneli kodu girin';

  @override
  String get verifyButton => 'Doğrula';

  @override
  String get authWelcomeBackSubtitle => 'PetSupo\'a tekrar hoş geldiniz';

  @override
  String get authCreateAccountSubtitle => 'PetSupo hesabınızı oluşturun';

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
  String get addYourPetTitle => 'Evcil Hayvanınızı Ekleyin';

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
  String get ageUnit => 'Birim';

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
  String get editDog => 'Evcil Hayvan Profilini Düzenle';

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
    return '\"$name\" isimli köpek zaten mevcut';
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
  String get addDogButton => 'Evcil Hayvan Ekle';

  @override
  String get dogDetailsAddTitle => 'Köpek Ekle';

  @override
  String get dogDetailsEditTitle => 'Evcil Hayvan Profilini Düzenle';

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
  String get breedPersian => 'İran Kedisi';

  @override
  String get breedSiamese => 'Siyam';

  @override
  String get breedMaineCoon => 'Maine Coon Kedisi';

  @override
  String get breedBritishShorthair => 'Britanya Kısa Tüylüsü';

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
  String get breedMustang => 'Mustang Atı';

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
  String get parkA => 'A Parkı';

  @override
  String get parkB => 'B Parkı';

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
  String get playmateBreedPremiumHint => 'Irk (PetSupo Partner)';

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
  String get dogParkPremiumBadge => '🔒 Ayrıcalıklı';

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
  String get dogViewDislikeTooltip => 'Beğenme';

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
  String get boostPrice29 => '29 ₺';

  @override
  String get boost3DaysTitle => '3 Günlük Boost';

  @override
  String get boostBetterExposureSubtitle => 'Aktif keşif için daha iyi görünürlük';

  @override
  String get boostPrice69 => '69 ₺';

  @override
  String get boost7DaysTitle => '7 Günlük Boost';

  @override
  String get boostBestValueSubtitle => 'Maksimum erişim için en iyi değer';

  @override
  String get boostPrice129 => '129 ₺';

  @override
  String get boostActivated => 'Boost etkinleştirildi 🚀';

  @override
  String boostFailed(Object error) {
    return 'Boost başarısız: $error';
  }

  @override
  String get errorOpeningEdit => 'Düzenleme açılırken hata oluştu';

  @override
  String get boostBadge => 'ÖNE ÇIKARILDI';

  @override
  String get boostButton => 'Öne Çıkar';

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
  String get dogInfoDislikeTooltip => 'Beğenme';

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
  String dogInfoLiked(Object name) {
    return '$name adlı köpeği beğendiniz';
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
  String get breedAiredaleTerrier => 'Airedale Teriyeri';

  @override
  String get breedAkita => 'Akita Köpeği';

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
  String get breedBassetHound => 'Basset Tazısı';

  @override
  String get breedBeagle => 'Bigıl';

  @override
  String get breedBelgianMalinois => 'Belçika Malinois';

  @override
  String get breedBerneseMountainDog => 'Bernese Dağ Köpeği';

  @override
  String get breedBichonFrise => 'Bişon Frize';

  @override
  String get breedBloodhound => 'Kan Tazısı';

  @override
  String get breedBorderCollie => 'Sınır Kolisi';

  @override
  String get breedBostonTerrier => 'Boston Teriyeri';

  @override
  String get breedBoxer => 'Boksör';

  @override
  String get breedBulldog => 'Buldozer Köpeği';

  @override
  String get breedBullmastiff => 'Bullmastif';

  @override
  String get breedCairnTerrier => 'Cairn Teriyeri';

  @override
  String get breedCaneCorso => 'İtalyan Cane Corso';

  @override
  String get breedCavalierKingCharlesSpaniel => 'Cavalier King Charles Spanyeli';

  @override
  String get breedChihuahua => 'Şivava';

  @override
  String get breedChowChow => 'Çov Çov';

  @override
  String get breedCockerSpaniel => 'Cocker Spanyel';

  @override
  String get breedCollie => 'Koli Çoban Köpeği';

  @override
  String get breedDachshund => 'Dakhund';

  @override
  String get breedDalmatian => 'Dalmaçyalı';

  @override
  String get breedDobermanPinscher => 'Doberman Pinşer';

  @override
  String get breedEnglishSpringerSpaniel => 'İngiliz Springer Spaniel';

  @override
  String get breedFrenchBulldog => 'Fransız Bulldog';

  @override
  String get breedGermanShepherd => 'Alman Çoban Köpeği';

  @override
  String get breedGermanShorthairedPointer => 'Alman Kısasakal Pointer';

  @override
  String get breedGoldenRetriever => 'Golden Getirici';

  @override
  String get breedGreatDane => 'Büyük Dane';

  @override
  String get breedGreatPyrenees => 'Büyük Pirene';

  @override
  String get breedHavanese => 'Havana Bişonu';

  @override
  String get breedIrishSetter => 'İrlanda Setter';

  @override
  String get breedIrishWolfhound => 'İrlanda Kurt Köpeği';

  @override
  String get breedJackRussellTerrier => 'Jack Russell Teriyeri';

  @override
  String get breedLabradorRetriever => 'Labrador Getirici';

  @override
  String get breedLhasaApso => 'Lhasa Apso Köpeği';

  @override
  String get breedMaltese => 'Malta Köpeği';

  @override
  String get breedMastiff => 'Mastif';

  @override
  String get breedMiniatureSchnauzer => 'Minik Schnauzer';

  @override
  String get breedNewfoundland => 'Newfoundland Köpeği';

  @override
  String get breedPapillon => 'Papillon Köpeği';

  @override
  String get breedPekingese => 'Pekinez';

  @override
  String get breedPomeranian => 'Pomeranya Köpeği';

  @override
  String get breedPoodle => 'Kaniş';

  @override
  String get breedPug => 'Mops';

  @override
  String get breedRottweiler => 'Rotvayler';

  @override
  String get breedSaintBernard => 'Sen Bernar';

  @override
  String get breedSamoyed => 'Samoyed Köpeği';

  @override
  String get breedShetlandSheepdog => 'Shetland Çoban Köpeği';

  @override
  String get breedShihTzu => 'Şih Tzu';

  @override
  String get breedSiberianHusky => 'Sibirya Kurdu';

  @override
  String get breedStaffordshireBullTerrier => 'Staffordshire Bull Teriyeri';

  @override
  String get breedVizsla => 'Macar Vizslası';

  @override
  String get breedWeimaraner => 'Weimar Av Köpeği';

  @override
  String get breedWestHighlandWhiteTerrier => 'Batı Highland Beyaz Terrier';

  @override
  String get breedYorkshireTerrier => 'Yorkshire Teriyeri';

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
  String get months => 'ay';

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
  String get dislike => 'Beğenme';

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
  String get offerPremiumBadge => 'Ayrıcalıklı';

  @override
  String get offerFallbackTitle => 'PetSupo kullanıcılarına özel teklif';

  @override
  String get offerFallbackProvider => 'Partner marka';

  @override
  String get offerUnlock => 'Kilidi aç';

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
  String get offerInstagram => 'Instagram\'da Aç';

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
  String get petShopTitle => 'Evcil Hayvan Mağazası';

  @override
  String get shopNearYou => 'Yakındaki ürünleri keşfet';

  @override
  String get featuredDeal => 'Öne Çıkan Fırsat';

  @override
  String get featuredDealsEmptyTitle => 'Öne Çıkan Fırsatlar';

  @override
  String get featuredDealsEmptyDescription => 'PetSupo iş ortaklarının özel teklifleri burada görünecek.';

  @override
  String get premiumLabel => 'Ayrıcalıklı';

  @override
  String get goldLabel => 'PetSupo Partner';

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
  String get comingSoon => 'Yakında';

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
  String get petShopDealName => 'Pet Shop A Fırsatı';

  @override
  String get petShopDealDesc => 'Tüm mamalarda %15 indirim';

  @override
  String get groomyDealName => 'Groomy Stüdyosu';

  @override
  String get groomyDealDesc => 'Bu hafta bakımda %20 indirim';

  @override
  String get vetDealName => 'VetPlus Fırsatı';

  @override
  String get vetDealDesc => 'PetSupo Partner üyelerine ücretsiz kontrol';

  @override
  String get offerWhatsApp => 'WhatsApp\'ta Aç';

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
  String get businessRegisterTradeRegistryGazette => 'Ticaret Sicili Gazetesi';

  @override
  String get businessRegisterAuthorizedSignatureDocument => 'Yetkili İmza Evrakı';

  @override
  String get businessRegisterCompanyTypeQuestion => 'İşletme türünüz nedir?';

  @override
  String get businessRegisterCompanyTypeHelper => 'Yüklemeniz gereken belgeler işletme türünüze göre belirlenecektir.';

  @override
  String get businessRegisterCompanyTypeSoleProprietorship => 'Şahıs İşletmesi';

  @override
  String get businessRegisterCompanyTypeLimitedCompany => 'Limited Şirket';

  @override
  String get businessRegisterCompanyTypeJointStockCompany => 'Anonim Şirket';

  @override
  String get businessRegisterCompanyTypeRequired => '• İşletme türünü seçmelisiniz.';

  @override
  String get businessRegisterCompanyTypeLabel => 'İşletme Türü';

  @override
  String get businessRegisterCompanyTypeLegacyUnspecified => 'Belirtilmemiş / Legacy';

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
  String get businessRegisterGroomy => 'Groomy Kuaför';

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
  String get userProfileAdmin => 'Yönetici';

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
  String get userProfileUpgradeBusinessDescription => 'İşletmenizi kaydetmek ve müşteri almaya başlamak için PetSupo Partner\'a yükseltin.';

  @override
  String get userProfileUpgradeToGold => 'PetSupo Partner\'a Yükselt';

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
  String get userProfileUpgradeToGoldToContinue => 'Devam etmek için PetSupo Partner\'a yükseltin';

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
    return 'Stok kodu: $sku';
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
  String get myOrdersUnknownProduct => 'Ürün';

  @override
  String get myOrdersUnknownSeller => 'Satıcı';

  @override
  String myOrdersProductAndMore(Object product, int count) {
    return '$product + $count ürün daha';
  }

  @override
  String get myOrdersOrderNumberUnavailable => 'Mevcut değil';

  @override
  String get myOrdersDateUnavailable => 'Tarih bilgisi yok';

  @override
  String get myOrdersSortNewest => 'Tarih: en yeni';

  @override
  String get myOrdersSortOldest => 'Tarih: en eski';

  @override
  String get myOrdersSortProductAz => 'Ürün: A–Z';

  @override
  String get myOrdersSortProductZa => 'Ürün: Z–A';

  @override
  String get myOrdersSortSellerAz => 'Satıcı: A–Z';

  @override
  String get myOrdersSortSellerZa => 'Satıcı: Z–A';

  @override
  String get myOrdersSortAmountHigh => 'Tutar: yüksekten düşüğe';

  @override
  String get myOrdersSortAmountLow => 'Tutar: düşükten yükseğe';

  @override
  String get myOrdersProcessingStatus => 'İşleniyor';

  @override
  String get myOrdersRefundedStatus => 'İade edildi';

  @override
  String get myOrdersReturnedStatus => 'Geri gönderildi';

  @override
  String get myOrdersRefundedOrReturnedStatus => 'İade / Geri gönderim';

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
  String get goldPlanSubtitle => 'Evcil hayvan bakım uzmanları ve işletmeleri için';

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
  String get mobileSubscriptionVerificationFailed => 'Abonelik henüz doğrulanamadı. Lütfen Satın Alımları Geri Yükle seçeneğini tekrar deneyin.';

  @override
  String get mobileSubscriptionOwnershipConflict => 'Bu abonelik başka bir Petsupo hesabına bağlı. Lütfen bu abonelik için daha önce kullandığınız hesaba giriş yapın.';

  @override
  String get deleteAccountStoreSubscriptionNotice => 'PetSupo hesabınızı silmek Apple App Store veya Google Play aboneliğinizi iptal etmez. Hesabınızı silmeden önce mağaza faturalandırmasını ayrıca iptal edin.';

  @override
  String get manageStoreSubscription => 'Mağaza aboneliğini yönet';

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
    return '• Köpek: $dogName';
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
  String get adoptionHousingVilla => 'Müstakil Villa';

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
  String get adoptionYearsOfExperienceHint => '0 ile 60 arası';

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
  String get discountRate1Label => '%1 indirim';

  @override
  String get discountRate10Label => '%10 indirim';

  @override
  String get discountRate20Label => '%20 indirim';

  @override
  String get carrierYurticiKargo => 'Yurtiçi Kargo ile gönderim';

  @override
  String get carrierArasKargo => 'Aras Kargo ile gönderim';

  @override
  String get carrierMngKargo => 'MNG Kargo ile gönderim';

  @override
  String get carrierSuratKargo => 'Sürat Kargo ile gönderim';

  @override
  String get carrierPttKargo => 'PTT Kargo ile gönderim';

  @override
  String get carrierHepsiJet => 'HepsiJET ile gönderim';

  @override
  String get carrierKolayGelsin => 'Kolay Gelsin ile gönderim';

  @override
  String get carrierUpsTurkiye => 'UPS Türkiye ile gönderim';

  @override
  String get carrierDhlExpress => 'DHL Express ile gönderim';

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
  String get productSubmittedForReviewStatus => 'Ürün incelemeye gönderildi. Onaylanana kadar yayında olmayacak.';

  @override
  String get veterinaryProductsNotSupported => 'Veteriner tıbbi ürünlerin internet üzerinden satışı ve tanıtımı desteklenmemektedir.';

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
  String get petLabel => 'Pet';

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
    return 'Hacimsel ağırlık: $value';
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
  String get returnShippingTitle => 'İade Kargosu';

  @override
  String get returnShippingBuyerMessage => 'İade kargo ücretinden siz sorumlusunuz.\n\nKargo ücreti ürün iadesinden ayrıdır ve geri ödenmeyebilir.';

  @override
  String get returnShippingSellerMessage => 'İade kargo ücretinden satıcı sorumludur.';

  @override
  String get returnShippingContractedCarrierMessage => 'Satıcının anlaşmalı iade kargo firmasını kullanın.';

  @override
  String get returnShippingBuyerShipBackMessage => 'Kargo ücreti sizin sorumluluğunuzdadır ve ürün iadesinden ayrıdır.';

  @override
  String get returnShippingSellerShipBackMessage => 'İade kargo ücretini satıcı karşılar.';

  @override
  String get returnShippingAcknowledgement => 'İade kargo politikasını anlıyorum.';

  @override
  String get returnShippingPolicyLoading => 'İade kargo politikası yükleniyor…';

  @override
  String returnShippingCarrierValue(Object carrier) {
    return 'Kargo firması: $carrier';
  }

  @override
  String get returnShippingVerifiedCarrierHelper => 'Doğrulanmış anlaşmalı iade kargo firmasını kullanın.';

  @override
  String get returnCarrierEnterHelperText => 'Bu iade gönderisinde kullandığınız kargo firmasını girin.';

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

  @override
  String get refundDecisionTitle => 'Geri ödeme kararı';

  @override
  String get refundDecisionFullTitle => 'Tam Geri Ödeme';

  @override
  String get refundDecisionFullDescription => 'Uygun tutarın tamamını geri ödeyin.';

  @override
  String get refundDecisionFullRecommended => 'Hasarlı veya kusurlu ürünler, yanlış ürün, satıcı hatası ya da teslim edilmeyen ürünler için önerilir.';

  @override
  String get refundDecisionPartialTitle => 'Kısmi Geri Ödeme';

  @override
  String get refundDecisionPartialDescription => 'Uygun tutarın yalnızca bir bölümünü geri ödeyin. Gerekçe zorunludur.';

  @override
  String get refundDecisionRejectTitle => 'Geri Ödemeyi Reddet';

  @override
  String get refundDecisionRejectDescription => 'Geri ödeme talebini reddedin. Açık bir açıklama zorunludur.';

  @override
  String get refundPartialAmountLabel => 'Kısmi geri ödeme tutarı';

  @override
  String refundMaximumEligible(Object amount) {
    return 'En yüksek uygun tutar: $amount';
  }

  @override
  String get refundAmountValidationError => 'Sıfırdan büyük ve uygun geri ödeme tutarını aşmayan bir tutar girin.';

  @override
  String get refundDecisionReasonLabel => 'Gerekçe';

  @override
  String get refundReasonNotSelected => 'Bir gerekçe seçin';

  @override
  String get refundSellerNotesLabel => 'Satıcı notları';

  @override
  String get refundNotesOptional => 'İsteğe bağlı';

  @override
  String get refundNotesRequired => 'Zorunlu';

  @override
  String get refundBuyerExplanationLabel => 'Alıcının göreceği açıklama';

  @override
  String get refundBuyerExplanationHelper => 'Geri ödemenin neden reddedildiğini açıkça belirtin.';

  @override
  String get refundOriginalOrderLabel => 'Orijinal Sipariş';

  @override
  String get refundSummaryRefundLabel => 'Geri Ödeme';

  @override
  String get refundDifferenceLabel => 'Fark';

  @override
  String get refundDecisionBuyerTitle => 'Geri ödeme kararı';

  @override
  String get refundDecisionLabel => 'Karar';

  @override
  String get refundSellerExplanationLabel => 'Satıcı açıklaması';

  @override
  String get refundReasonItemReturnedDamaged => 'Ürün hasarlı iade edildi';

  @override
  String get refundReasonMissingAccessories => 'Aksesuarlar eksik';

  @override
  String get refundReasonCustomerCausedDamage => 'Müşterinin neden olduğu hasar';

  @override
  String get refundReasonRestockingFee => 'Yeniden stoklama ücreti';

  @override
  String get refundReasonPartialReturn => 'Kısmi iade';

  @override
  String get refundReasonSellerMistake => 'Satıcı hatası';

  @override
  String get refundReasonWrongItem => 'Yanlış ürün';

  @override
  String get refundReasonDefectiveProduct => 'Kusurlu ürün';

  @override
  String get refundReasonItemNeverDelivered => 'Ürün teslim edilmedi';

  @override
  String get refundReasonOther => 'Diğer';

  @override
  String get returnStatusWaitingSellerConfirmation => 'Satıcı onayı bekleniyor';

  @override
  String get returnStatusAutoReceived => 'Otomatik teslim alındı';

  @override
  String get returnStatusDispute => 'İade anlaşmazlığı';

  @override
  String get waitingForSellerInspectionTitle => 'Satıcı incelemesi bekleniyor';

  @override
  String waitingForSellerInspectionMessage(Object date) {
    return 'Satıcının iade paketini incelemek için $date tarihine kadar süresi var. İşlem yapılmazsa iade otomatik olarak devam eder.';
  }

  @override
  String get inspectionDeadlineTitle => 'İnceleme son tarihi';

  @override
  String inspectionDaysRemaining(int days) {
    return '$days gün kaldı';
  }

  @override
  String get inspectionDeadlinePassed => 'Süre doldu. Otomatik tamamlama bekleniyor.';

  @override
  String get reportReturnProblemTitle => 'İade sorunu bildir';

  @override
  String get reportProblemButton => 'Sorun bildir';

  @override
  String get disputeReasonLabel => 'Sorun nedeni';

  @override
  String get disputeReasonPackageNotReceived => 'Paket ulaşmadı';

  @override
  String get disputeReasonWrongItemReturned => 'Yanlış ürün iade edildi';

  @override
  String get disputeReasonEmptyPackage => 'Boş paket';

  @override
  String get disputeReasonDamagedDuringReturn => 'İade sırasında hasar gördü';

  @override
  String get disputeReasonTrackingIssue => 'Takip sorunu';

  @override
  String get adminReturnDisputesTitle => 'İade anlaşmazlıkları';

  @override
  String get adminReturnDisputesSubtitle => 'Anlaşmazlığa düşen pazar yeri iadelerini inceleyin';

  @override
  String get noReturnDisputes => 'Anlaşmazlıklı iade yok';

  @override
  String get locationUpdatedSuccessfully => 'Konum başarıyla güncellendi';

  @override
  String get centersLoadError => 'Merkezler yüklenemedi';

  @override
  String get noAppointments => 'Randevu bulunamadı.';

  @override
  String get noAppointmentsFound => 'Randevu bulunamadı.';

  @override
  String appointmentsCount(Object count) {
    return '$count randevu';
  }

  @override
  String get any => 'Fark etmez';

  @override
  String get search => 'Ara...';

  @override
  String get accessDenied => 'Erişim Reddedildi';

  @override
  String get skip => 'Atla';

  @override
  String searchService(Object service) {
    return '$service ara...';
  }

  @override
  String get petHotels => 'Pet Otelleri';

  @override
  String noItemsYet(Object title) {
    return 'Henüz $title yok';
  }

  @override
  String get noSavedPostsYet => 'Henüz kaydedilmiş gönderi yok';

  @override
  String uploadedAt(Object date) {
    return 'Yüklenme: $date';
  }

  @override
  String get productDetails => 'Ürün Detayları';

  @override
  String get servicesCouldNotBeLoaded => 'Hizmetler yüklenemedi';

  @override
  String get veterinaryClinics => 'Veteriner klinikleri';

  @override
  String get noVeterinaryClinicsFound => 'Veteriner kliniği bulunamadı.';

  @override
  String get securePayment => 'Güvenli Ödeme';

  @override
  String get liveDriver => 'Canlı Sürücü';

  @override
  String get driver => 'Sürücü';

  @override
  String get myRides => 'Yolculuklarım';

  @override
  String get clientMessages => 'Müşteri Mesajları';

  @override
  String get preVisitForm => 'Muayene Öncesi Formu';

  @override
  String get vetRevenueTitle => 'Gelir';

  @override
  String get vetRevenueDescription => 'Tamamlanan veteriner işlemlerine ait doğrulanmış ödeme ve mutabakat verileri.';

  @override
  String get vetRevenueRange7Days => '7 gün';

  @override
  String get vetRevenueRange30Days => '30 gün';

  @override
  String get vetRevenueRange90Days => '90 gün';

  @override
  String get vetRevenueRangeThisYear => 'Bu yıl';

  @override
  String get vetRevenueRangeAllTime => 'Tüm zamanlar';

  @override
  String get vetRevenueGrossRevenue => 'Brüt Gelir';

  @override
  String get vetRevenuePetsupoCommission => 'PetSupo Komisyonu';

  @override
  String get vetRevenueNetRevenue => 'Net Gelir';

  @override
  String get vetRevenuePendingSettlement => 'Bekleyen Mutabakat';

  @override
  String get vetRevenuePaidTransactions => 'Ödenen İşlemler';

  @override
  String get vetRevenuePendingPayments => 'Bekleyen Ödemeler';

  @override
  String get vetRevenueRefunded => 'İade Edilen';

  @override
  String get vetRevenueExpiredOpportunities => 'Süresi Dolan Fırsatlar';

  @override
  String get vetRevenueMissingFinancialData => 'Eksik Finansal Veri';

  @override
  String vetRevenueMissingFinancialWarning(int count) {
    return '$count ödenmiş kaydın finansal verisi eksik veya hatalı olduğundan toplamlara dahil edilmedi.';
  }

  @override
  String get vetRevenueMixedCurrencyWarning => 'Birden fazla para birimi mevcut. Tutarlar ayrı gösterilir; dönüştürülmez veya birleştirilmez.';

  @override
  String get vetRevenueNoAppointmentsTitle => 'Henüz randevu yok';

  @override
  String get vetRevenueNoAppointmentsMessage => 'Veteriner randevuları oluşturulduğunda gelir analizi burada görünür.';

  @override
  String get vetRevenueNoRangeTitle => 'Bu dönemde kayıt yok';

  @override
  String get vetRevenueNoRangeMessage => 'Daha eski işlemler için daha geniş bir tarih aralığı seçin.';

  @override
  String get vetRevenueLoadErrorTitle => 'Gelir verisi kullanılamıyor';

  @override
  String get vetRevenueLoadErrorMessage => 'Bağlantıyı kontrol edip tekrar deneyin. Mevcut ödeme kayıtları değiştirilmedi.';

  @override
  String get vetRevenueRetry => 'Tekrar dene';

  @override
  String get vetRevenueTrendTitle => 'Gelir Eğilimi';

  @override
  String get vetRevenueMixedCurrencyChartHidden => 'Seçilen dönemde birden fazla para birimi olduğundan birleşik grafik gizlendi.';

  @override
  String get vetRevenueNoRecognizedRevenue => 'Bu dönemde doğrulanmış ödenmiş gelir yok.';

  @override
  String get vetRevenueTopServices => 'Brüt Gelire Göre En İyi Hizmetler';

  @override
  String get vetRevenueTransactions => 'İşlemler';

  @override
  String get vetRevenueUncategorized => 'Kategorisiz';

  @override
  String get vetRevenueSearchHint => 'Müşteri, evcil hayvan, hizmet veya işlem ara';

  @override
  String get vetRevenueAllPayments => 'Tüm ödemeler';

  @override
  String get vetRevenuePaid => 'Ödendi';

  @override
  String get vetRevenuePending => 'Bekliyor';

  @override
  String get vetRevenueExpired => 'Süresi doldu';

  @override
  String get vetRevenueMissingFinancial => 'Finansal veri eksik';

  @override
  String get vetRevenueSortDate => 'Tarihe göre sırala';

  @override
  String get vetRevenueSortDirection => 'Sıralama yönünü değiştir';

  @override
  String get vetRevenueDate => 'Tarih';

  @override
  String get vetRevenueCustomer => 'Müşteri';

  @override
  String get vetRevenuePet => 'Evcil Hayvan';

  @override
  String get vetRevenueService => 'Hizmet';

  @override
  String get vetRevenueGross => 'Brüt';

  @override
  String get vetRevenueCommission => 'Komisyon';

  @override
  String get vetRevenueNet => 'Net Tutar';

  @override
  String get vetRevenuePayment => 'Ödeme';

  @override
  String get vetRevenueSettlement => 'Mutabakat';

  @override
  String get vetRevenueInvoice => 'Fatura';

  @override
  String get vetRevenueTransactionReference => 'İşlem referansı';

  @override
  String get vetRevenueNoMatchingTransactions => 'Arama ve filtreyle eşleşen işlem yok.';

  @override
  String vetRevenuePageOf(int page, int total) {
    return 'Sayfa $page / $total';
  }

  @override
  String get vetWebOverviewSubtitle => 'Klinik performansı ve operasyon özeti';

  @override
  String get vetWebAppointmentsSubtitle => 'Veteriner randevularını inceleyin ve yönetin';

  @override
  String get vetWebRevenueSubtitle => 'Doğrulanmış ödeme, komisyon ve mutabakat analizi';

  @override
  String get vetWebVeterinaryLabel => 'Veteriner';

  @override
  String get petShopsTitle => 'Evcil Hayvan Mağazaları';

  @override
  String get searchPetShopsHint => 'Evcil hayvan mağazalarında ara';

  @override
  String get noPetShopsFound => 'Evcil hayvan mağazası bulunamadı';

  @override
  String get noPetShopsFoundDescription => 'Başka bir arama deneyin veya daha sonra tekrar kontrol edin.';

  @override
  String get loadingPetShops => 'Yakınınızdaki mağazalar bulunuyor…';

  @override
  String get petShopsLoadError => 'Mağazalar yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get retryButton => 'Tekrar dene';

  @override
  String get shopInformationTitle => 'Mağaza bilgileri';

  @override
  String get noShopDescriptionAvailable => 'Mağaza açıklaması bulunmuyor.';

  @override
  String get locationNotAvailable => 'Konum bilgisi yok';

  @override
  String get getDirectionsLabel => 'Yol tarifi al';

  @override
  String get connectLabel => 'İletişime geç';

  @override
  String get callLabel => 'Ara';

  @override
  String get whatsappLabel => 'WhatsApp';

  @override
  String get websiteLabel => 'Web sitesi';

  @override
  String get signInToContactShop => 'Bu mağazayla iletişim kurmak için giriş yapın.';

  @override
  String get petShopUnavailable => 'Mağaza kullanılamıyor';

  @override
  String get petShopUnavailableDescription => 'Bu evcil hayvan mağazası artık kullanılamıyor.';

  @override
  String get reviewsCouldNotBeLoaded => 'Yorumlar yüklenemedi.';

  @override
  String get noProductsAvailableFromShop => 'Bu mağazada kullanılabilir ürün yok';

  @override
  String get petShopLocationNeededMessage => 'Yakındaki evcil hayvan mağazalarını göstermek için konumunuzu kullanıyoruz';

  @override
  String get infoTitle => 'Bilgi';

  @override
  String get processTitle => 'Süreç';

  @override
  String get categoriesTitle => 'Kategoriler';

  @override
  String get contactTitle => 'İletişim';

  @override
  String get openFullProfile => 'Tam profili aç';

  @override
  String get noShopCategoriesAvailable => 'Mağaza kategorisi bulunmuyor.';

  @override
  String get browseShopProductsDescription => 'Bu evcil hayvan mağazasındaki ürünlere göz atın.';

  @override
  String get viewAllProducts => 'Tüm ürünleri görüntüle';

  @override
  String get continueWithGoogle => 'Google ile devam et';

  @override
  String get continueWithApple => 'Apple ile devam et';

  @override
  String get connectAppleAccount => 'Apple hesabını bağla';

  @override
  String get appleAccountConnected => 'Apple hesabı bağlandı';

  @override
  String get orContinueWith => 'veya şununla devam et';

  @override
  String get authenticationCancelled => 'Kimlik doğrulama iptal edildi';

  @override
  String get unableToSignIn => 'Giriş yapılamadı';

  @override
  String get emailRegisteredWithAnotherProvider => 'Bu e-posta başka bir giriş yöntemiyle kayıtlı';

  @override
  String get completeYourProfile => 'Profilini tamamla';

  @override
  String get cityLabel => 'Şehir';

  @override
  String get districtLabel => 'İlçe';

  @override
  String get cityRequired => 'Lütfen şehrinizi girin';

  @override
  String get districtRequired => 'Lütfen ilçenizi girin';

  @override
  String get continueLabel => 'Devam et';

  @override
  String get petTaxiRequestRideTab => 'Yolculuk İste';

  @override
  String get petTaxiRidesSubtitle => 'Yaklaşan ve geçmiş Pet Taxi yolculuklarınız';

  @override
  String get petTaxiFilterActive => 'Aktif ve Yaklaşan';

  @override
  String get petTaxiFilterCompleted => 'Tamamlanan';

  @override
  String get petTaxiFilterCancelled => 'İptal Edilen';

  @override
  String get petTaxiNoRidesTitle => 'Henüz Pet Taxi yolculuğunuz yok';

  @override
  String get petTaxiNoRidesDescription => 'Yolculuk istediğinizde Pet Taxi rezervasyonlarınız burada görünecek.';

  @override
  String get petTaxiNoRidesInFilter => 'Bu kategoride yolculuk yok';

  @override
  String get petTaxiTryAnotherFilter => 'Diğer yolculuklarınızı görmek için başka bir kategori seçin.';

  @override
  String get petTaxiRidesLoading => 'Pet Taxi yolculuklarınız yükleniyor';

  @override
  String get petTaxiRidesLoadErrorTitle => 'Yolculuklarınız yüklenemedi';

  @override
  String get petTaxiRidesLoadErrorDescription => 'Bağlantınızı kontrol edip yeniden deneyin. Rezervasyonlarınızda değişiklik yapılmadı.';

  @override
  String get petTaxiSignInRequiredTitle => 'Yolculuklarınızı görmek için giriş yapın';

  @override
  String get petTaxiSignInRequiredDescription => 'Pet Taxi rezervasyonlarınıza giriş yaptıktan sonra ulaşabilirsiniz.';

  @override
  String get petTaxiProviderLabel => 'Hizmet sağlayıcı';

  @override
  String get petTaxiProviderFallback => 'Pet Taxi hizmet sağlayıcısı';

  @override
  String get petTaxiDestinationLabel => 'Varış noktası';

  @override
  String get petTaxiScheduleUnavailable => 'Program bilgisi yok';

  @override
  String get petTaxiPriceUnavailable => 'Fiyat bekleniyor';

  @override
  String get petTaxiStatusPending => 'Talep beklemede';

  @override
  String get petTaxiStatusAwaitingPayment => 'Ödeme bekleniyor';

  @override
  String get petTaxiStatusConfirmedPaid => 'Onaylandı ve ödendi';

  @override
  String get petTaxiStatusPaymentFailed => 'Ödeme başarısız';

  @override
  String get petTaxiStatusRefundPending => 'İade bekleniyor';

  @override
  String get petTaxiStatusRefunded => 'İade edildi';

  @override
  String get petTaxiStatusDriverOnTheWay => 'Sürücü yolda';

  @override
  String get petTaxiStatusArrived => 'Sürücü geldi';

  @override
  String get petTaxiStatusPetPickedUp => 'Evcil hayvan alındı';

  @override
  String get petTaxiStatusOnTrip => 'Yolculukta';

  @override
  String get petTaxiStatusCompleted => 'Tamamlandı';

  @override
  String get petTaxiStatusCancelledByUser => 'Sizin tarafınızdan iptal edildi';

  @override
  String get petTaxiStatusCancelledByProvider => 'Hizmet sağlayıcı tarafından iptal edildi';

  @override
  String get petTaxiStatusUnknown => 'Durum bilgisi yok';

  @override
  String get petTaxiPaymentPaid => 'Ödendi';

  @override
  String get petTaxiPaymentPending => 'Ödeme işleniyor';

  @override
  String get petTaxiPaymentFailed => 'Ödeme başarısız';

  @override
  String get petTaxiPaymentRefunded => 'İade edildi';

  @override
  String get petTaxiPaymentUnpaid => 'Ödenmedi';

  @override
  String get webSubscriptionPaymentUnavailable => 'Ödeme geçici olarak kullanılamıyor';

  @override
  String get webSubscriptionCatalogLoadFailed => 'Güvenli ödeme fiyatları yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get webSubscriptionCatalogUnauthenticated => 'Abonelik fiyatlarını yüklemek ve güvenle devam etmek için giriş yapın.';

  @override
  String get webSubscriptionCatalogFunctionNotFound => 'Güvenli ödeme hizmeti bu uygulama sürümünde kullanılamıyor. Sayfayı yenileyip tekrar deneyin.';

  @override
  String get webSubscriptionCatalogConfigurationMissing => 'Güvenli ödeme yapılandırması geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';

  @override
  String get webSubscriptionCatalogNetworkFailed => 'Güvenli ödeme hizmetine ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get webSubscriptionCatalogMalformed => 'Güvenli ödeme hizmeti geçersiz bir yanıt verdi. Lütfen tekrar deneyin.';

  @override
  String get webSubscriptionThirtyDayAccess => '30 günlük abonelik erişimi';

  @override
  String get webSubscriptionContinueSecurePayment => 'Güvenli ödemeye devam et';

  @override
  String get webSubscriptionPaymentTerms => '30 günlük erişim için tek seferlik ödeme. Otomatik kart yenilemesi yoktur.';

  @override
  String get webSubscriptionIsbankSecurePayment => 'İş Bankası ile güvenli ödeme • 30 günlük erişim • Otomatik yenileme yok';

  @override
  String get webSubscriptionCheckoutFailed => 'Güvenli ödeme başlatılamadı. Lütfen tekrar deneyin.';

  @override
  String get webSubscriptionVerifyingTitle => 'Ödemeniz doğrulanıyor';

  @override
  String get webSubscriptionVerifyingMessage => 'Banka ödemesi güvenli şekilde doğrulanırken lütfen bekleyin.';

  @override
  String get webSubscriptionSuccessTitle => 'Abonelik etkinleştirildi';

  @override
  String get webSubscriptionSuccessMessage => 'Ödemeniz doğrulandı ve 30 günlük abonelik erişiminiz etkin.';

  @override
  String get webSubscriptionFailedTitle => 'Ödeme doğrulanamadı';

  @override
  String get webSubscriptionFailedMessage => 'Aboneliğiniz etkinleştirilmedi. Doğrulanmamış ödemeler erişim sağlamaz.';

  @override
  String get webSubscriptionCancelledTitle => 'Ödeme iptal edildi';

  @override
  String get webSubscriptionCancelledMessage => 'Ödeme iptal edildi ve aboneliğiniz değiştirilmedi.';

  @override
  String get webSubscriptionPendingTitle => 'Ödeme hâlâ işleniyor';

  @override
  String get webSubscriptionPendingMessage => 'Banka doğrulamayı henüz tamamlamadı. Bu sayfa otomatik olarak yeniden kontrol edecek.';

  @override
  String chatError(Object error) {
    return 'Sohbet hatası: $error';
  }

  @override
  String get bankAccountSettingsTitle => 'Banka Hesabı';

  @override
  String get bankAccountSettingsSubtitle => 'Bu hesap, PetSupo işletme kazançlarınızı gönderdiğinde kullanılacaktır.';

  @override
  String get bankAccountInfoNotice => 'Lütfen hesap sahibi adının ve IBAN\'ın resmi banka hesabınızla birebir eşleştiğinden emin olun. Hatalı bilgi ödemelerinizin gecikmesine neden olabilir.';

  @override
  String get bankAccountSectionTitle => 'Hesap Bilgileri';

  @override
  String get bankAccountHolderLabel => 'Hesap Sahibi';

  @override
  String get bankAccountBankNameLabel => 'Banka Adı';

  @override
  String get bankAccountIbanLabel => 'IBAN';

  @override
  String get bankAccountBillingInfoLabel => 'Fatura Bilgileri (opsiyonel)';

  @override
  String get bankAccountIbanInvalid => 'IBAN, TR ile başlamalı ve ardından 24 rakam içermelidir.';

  @override
  String get bankAccountSaveSuccess => 'Banka hesabı bilgileri kaydedildi.';

  @override
  String get diagnosticsSectionTitle => 'Tanılama';

  @override
  String get diagnosticsSectionDescription => 'Kuyruk inceleme ve yükleme testleri için dahili tanılama araçları.';

  @override
  String get diagnosticsThrowButton => 'Hata oluştur';

  @override
  String get diagnosticsTestButton => 'Test et';

  @override
  String get diagnosticsUploadButton => 'Yükle';

  @override
  String get diagnosticsRefreshButton => 'Yenile';

  @override
  String get diagnosticsClearButton => 'Temizle';

  @override
  String dogCardAgeWithBreed(Object age, Object breed) {
    return '$age yaş • $breed';
  }

  @override
  String dogCardAgeYears(Object age) {
    return '$age yaş';
  }

  @override
  String dogCardVaccines(int count) {
    return '$count aşı';
  }

  @override
  String get dogParkPremiumMembersOnly => 'Bu park yalnızca Premium üyeler tarafından kullanılabilir.';

  @override
  String get favoritesExplorePlaymates => 'Oyun arkadaşlarını keşfet 💛';

  @override
  String get vetServicesAvailableAfterLogin => 'Veteriner hizmetleri giriş yaptıktan sonra kullanılabilir';

  @override
  String get loadingAccount => 'Hesap yükleniyor...';

  @override
  String get noNotificationsForGuest => 'Misafirler için bildirim yok';

  @override
  String get loginForNotifications => 'Güncellemeleri ve uyarıları almak için giriş yapın';

  @override
  String get offerDetailsTitle => 'Teklif';

  @override
  String get offerDiscountOffLabel => 'İNDİRİM';

  @override
  String get offerUseCodeLabel => 'Kodu kullan:';

  @override
  String get offerUseThisOffer => 'Bu Teklifi Kullan';

  @override
  String get playdateScheduledAtLabel => 'Oyun buluşması şurada planlanacak:';

  @override
  String get continueToScheduling => 'Planlamaya devam et';

  @override
  String get orderCancellationTitle => 'Sipariş İptali';

  @override
  String get preShipmentCancellationAvailable => 'Bu sipariş henüz kargoya verilmedi ve iptal edilebilir.';

  @override
  String get cancelOrderButton => 'Siparişi İptal Et';

  @override
  String get cancelOrderTitle => 'Sipariş İptal Edilsin mi?';

  @override
  String get cancelOrderConfirmation => 'Bu siparişi iptal etmek istediğinizden emin misiniz? Sipariş henüz kargoya verilmedi.';

  @override
  String get cancelOrderRefundNotice => 'İptalden sonra ödemeniz iade edilecektir.';

  @override
  String get cancellationReasonLabel => 'İptal nedeni';

  @override
  String get cancelReasonOrderedByMistake => 'Yanlışlıkla sipariş verdim';

  @override
  String get cancelReasonChangedMind => 'Fikrimi değiştirdim';

  @override
  String get cancelReasonDuplicateOrder => 'Mükerrer sipariş';

  @override
  String get cancelReasonOther => 'Diğer';

  @override
  String get cancellationReasonDetailsLabel => 'İptal nedeni açıklaması';

  @override
  String get cancellationRefundProcessing => 'Sipariş iptal edildi. Para iadeniz işleniyor.';

  @override
  String get cancellationShipmentAlreadyStarted => 'Kargo süreci başladığı için bu sipariş artık iptal edilemez.';

  @override
  String get cancelOrderFailed => 'Sipariş iptal edilemedi. Lütfen tekrar deneyin.';

  @override
  String get cancellationRefundProcessingStatus => 'İptal talebi alındı · Para iadesi işleniyor';

  @override
  String get cancellationRefundFailedStatus => 'İptal iadesi kontrol gerektiriyor';

  @override
  String get orderCancelledRefundCompleted => 'Sipariş iptal edildi · Para iadesi tamamlandı';

  @override
  String get foundPetDetailsTitle => 'Bulunan Evcil Hayvan Detayları';

  @override
  String get viewOnMap => 'Haritada Gör';

  @override
  String get contactReporter => 'Bildiren Kişiyle İletişime Geç';

  @override
  String get foundPetReportedSuccess => 'Bulunan evcil hayvan başarıyla bildirildi!';

  @override
  String errorSubmittingReport(Object error) {
    return 'Bildirim gönderilirken hata oluştu: $error';
  }

  @override
  String get tapToSelectImage => 'Görsel seçmek için dokunun';

  @override
  String get foundPetsSubtitle => 'Bulunan evcil hayvanların güvenle evlerine dönmesine yardımcı olun';

  @override
  String get searchByNameHint => 'Ada göre ara...';

  @override
  String get noFoundPetsReportedYet => 'Henüz bulunan evcil hayvan bildirilmedi';

  @override
  String get reportedFoundPetsAppearHere => 'Bildirilen bulunan evcil hayvanlar burada görünür';

  @override
  String get lostPetDetailsTitle => 'Kayıp Evcil Hayvan Detayları';

  @override
  String get havePetInformationPrompt => 'Bu evcil hayvan hakkında bilginiz var mı?';

  @override
  String get callOwner => 'Sahibini Ara';

  @override
  String get emailOwner => 'Sahibine E-posta Gönder';

  @override
  String get lostPetReportedSuccess => 'Kayıp evcil hayvan başarıyla bildirildi!';

  @override
  String get lostPetsSubtitle => 'Kayıp evcil hayvanların evlerine dönmesine yardımcı olun';

  @override
  String get noLostPetsReportedYet => 'Henüz kayıp evcil hayvan bildirilmedi';

  @override
  String get reportedLostPetsAppearHere => 'Bildirilen kayıp evcil hayvanlar burada görünür';

  @override
  String get searchUsersHint => 'Kullanıcı ara...';

  @override
  String get noUsersFound => 'Kullanıcı bulunamadı';

  @override
  String get searchPetsAndUsers => 'Evcil hayvan ve kullanıcı ara';

  @override
  String get findPetLoversNearby => 'Yakınınızdaki hayvanseverleri bulun';

  @override
  String get selectAtLeastOnePhotoOrVideo => 'Lütfen en az bir fotoğraf/video seçin';

  @override
  String errorCreatingPost(Object error) {
    return 'Gönderi oluşturulurken hata oluştu: $error';
  }

  @override
  String get createPostTitle => 'Gönderi Oluştur';

  @override
  String get share => 'Paylaş';

  @override
  String get addPhotosOrVideos => 'Fotoğraf/video ekle';

  @override
  String get writeSomethingHint => 'Bir şeyler yazın...';

  @override
  String get replyHint => 'Yanıtla...';

  @override
  String get replySent => 'Yanıt gönderildi';

  @override
  String get close => 'Kapat';

  @override
  String get videoStoriesComingSoon => 'Video hikâyeler yakında geliyor';

  @override
  String get petploreTitle => 'Petplore';

  @override
  String get explorePetMoments => 'Evcil hayvan anlarını keşfedin';

  @override
  String followersCount(int count) {
    return '$count Takipçi';
  }

  @override
  String followingCount(int count) {
    return '$count Takip';
  }

  @override
  String get feed => 'Akış';

  @override
  String get saved => 'Kaydedilenler';

  @override
  String get myPosts => 'Gönderilerim';

  @override
  String get loginRequired => 'Giriş gerekli';

  @override
  String genericError(Object error) {
    return 'Hata: $error';
  }

  @override
  String get noPostsYet => 'Henüz gönderi yok';

  @override
  String get noResults => 'Sonuç bulunamadı';

  @override
  String get commentsTitle => 'Yorumlar';

  @override
  String commentsError(Object error) {
    return 'Yorum hatası: $error';
  }

  @override
  String get noCommentsYet => 'Henüz yorum yok';

  @override
  String get writeCommentHint => 'Yorum yazın...';

  @override
  String get postsTitle => 'Gönderiler';

  @override
  String get storyUploaded => 'Hikâye yüklendi';

  @override
  String storyUploadFailed(Object error) {
    return 'Hikâye yüklenemedi: $error';
  }

  @override
  String get addStory => 'Hikâye Ekle';

  @override
  String get storyDurationPrompt => '24 saat sürecek bir evcil hayvan anı paylaşın';

  @override
  String get seeWhosNearby => 'Yakında kim var görün 👀!';

  @override
  String get telegramLab => 'Telegram Laboratuvarı';

  @override
  String get telegramBotApiTest => 'Telegram Bot API Testi';

  @override
  String get telegramTestInstructions => 'Test mesajı göndermek için aşağıdaki düğmeye basın.';

  @override
  String get sendTelegramMessage => 'Telegram Mesajı Gönder';

  @override
  String get telegramUsers => 'Telegram Kullanıcıları';

  @override
  String get termsLastUpdated => 'Son güncelleme: 09 Mayıs 2025';

  @override
  String get termsIntroductionTitle => '1. Giriş';

  @override
  String get termsIntroductionBody => 'PetSupo\'ya hoş geldiniz! Kaydolarak bu Şartlar ve Koşulları kabul edersiniz. Uygulama, köpeklerinize oyun arkadaşları bulmanıza, diğer evcil hayvan sahipleriyle bağlantı kurmanıza ve evcil hayvan hizmetlerine erişmenize yardımcı olur. Bu şartlar PetSupo uygulaması ve hizmetlerini kullanımınızı düzenler.';

  @override
  String get termsResponsibilitiesTitle => '2. Kullanıcı Sorumlulukları';

  @override
  String get termsResponsibilitiesBody => '- Bu uygulamayı kullanmak için en az 13 yaşında olmalısınız.\n- Hesabınızın ve parolanızın gizliliğinden siz sorumlusunuz.\n- Uygulamayı yasa dışı veya yasak faaliyetler için kullanmamayı kabul edersiniz.\n- Kayıt sırasında doğru ve güncel bilgiler sağlamalısınız.';

  @override
  String get termsPrivacyTitle => '3. Veri Toplama ve Gizlilik';

  @override
  String get termsPrivacyBody => 'Hizmetlerimizi sunmak için kullanıcı adı, e-posta, konum ve evcil hayvan bilgileri gibi kişisel verileri toplarız. KVKK No. 6698 ve GDPR gibi uluslararası yasalar uyarınca verilerinizi işlemeden önce açık rıza alır, yalnızca belirtilen amaçlarla kullanır, koruyucu güvenlik önlemleri uygular ve erişim, düzeltme veya silme taleplerinizi karşılarız. Haklarınız için info@petsupo.com adresine başvurun.';

  @override
  String get termsUserContentTitle => '4. Kullanıcı İçeriği';

  @override
  String get termsUserContentBody => '- Yüklediğiniz içeriğin mülkiyeti sizde kalır.\n- İçerik yükleyerek PetSupo\'ya içeriği uygulama içinde kullanma, gösterme ve dağıtma konusunda münhasır olmayan, telifsiz bir lisans verirsiniz.\n- Yasa dışı, saldırgan veya başkalarının haklarını ihlal eden içerik yükleyemezsiniz.';

  @override
  String get termsLiabilityTitle => '5. Sorumluluğun Sınırlandırılması';

  @override
  String get termsLiabilityBody => 'PetSupo, diğer kullanıcılar veya evcil hayvanlarla etkileşimler dahil uygulama kullanımınızdan doğan zararlardan sorumlu değildir. Diğer kullanıcıların sağladığı bilgilerin doğruluğunu garanti etmeyiz.';

  @override
  String get termsGoverningLawTitle => '6. Uygulanacak Hukuk';

  @override
  String get termsGoverningLawBody => 'Bu Şartlar ve Koşullar Türkiye Cumhuriyeti yasalarına tabidir. Uluslararası hukuk aksini gerektirmedikçe uyuşmazlıklar İstanbul mahkemelerinde çözümlenir.';

  @override
  String get termsChangesTitle => '7. Şartlardaki Değişiklikler';

  @override
  String get termsChangesBody => 'Bu Şartlar ve Koşullar zaman zaman güncellenebilir. Önemli değişiklikler e-posta veya uygulama içi bildirimle duyurulur. Değişikliklerden sonra uygulamayı kullanmaya devam etmeniz yeni şartları kabul ettiğiniz anlamına gelir.';

  @override
  String get termsContactTitle => '7. İletişim';

  @override
  String get termsContactBody => 'Bu Şartlar ve Koşullar hakkında sorularınız için info@petsupo.com adresinden bize ulaşın.';

  @override
  String get pendingBusinessApprovals => 'Bekleyen İşletme Onayları';

  @override
  String get invalidRequest => 'Geçersiz istek';

  @override
  String get noPendingBusinessRequests => 'Bekleyen işletme isteği yok';

  @override
  String riskCount(Object count) {
    return '$count RİSK';
  }

  @override
  String get verifiedLabel => 'DOĞRULANDI';

  @override
  String get approve => 'Onayla';

  @override
  String get suspend => 'Askıya Al';

  @override
  String get restore => 'Geri Yükle';

  @override
  String get businessApproved => 'İşletme onaylandı';

  @override
  String get businessRejected => 'İşletme reddedildi';

  @override
  String get businessSuspended => 'İşletme askıya alındı';

  @override
  String get businessRestored => 'İşletme geri yüklendi';

  @override
  String actionFailed(Object error) {
    return 'İşlem başarısız: $error';
  }

  @override
  String get adminDashboard => 'Yönetici Paneli';

  @override
  String dashboardError(Object error) {
    return 'Panel Hatası:\n$error';
  }

  @override
  String get platformOverview => 'Platform Özeti';

  @override
  String get adminActivity => 'Yönetici Etkinliği';

  @override
  String get developerTools => 'Geliştirici Araçları';

  @override
  String get testTelegramBotApi => 'Telegram Bot API\'yi Test Et';

  @override
  String get diagnostics => 'Tanılama';

  @override
  String get diagnosticsDescription => 'Çökme raporları ve başlangıç tanılaması';

  @override
  String get telegramUsersDescription => 'Bağlı Telegram kullanıcılarını görüntüle';

  @override
  String adminActivityError(Object error) {
    return 'Etkinlik hatası:\n$error';
  }

  @override
  String get noAdminActivity => 'Henüz yönetici etkinliği yok';

  @override
  String get diagnosticReport => 'Tanılama Raporu';

  @override
  String get diagnosticReportNotFound => 'Tanılama raporu bulunamadı';

  @override
  String get reopen => 'Yeniden Aç';

  @override
  String get resolve => 'Çöz';

  @override
  String get ignore => 'Yoksay';

  @override
  String get stackTrace => 'Yığın İzleme';

  @override
  String get breadcrumbsLogs => 'Gezinme İzleri / Günlükler';

  @override
  String get noLogs => 'Günlük yok';

  @override
  String get rawJson => 'Ham JSON';

  @override
  String get diagnosticReports => 'Tanılama Raporları';

  @override
  String get filters => 'Filtreler';

  @override
  String get noDiagnosticReports => 'Tanılama raporu yok';

  @override
  String reasonValue(Object value) {
    return 'Neden: $value';
  }

  @override
  String featureValue(Object value) {
    return 'Özellik: $value';
  }

  @override
  String platformValue(Object value) {
    return 'Platform: $value';
  }

  @override
  String versionValue(Object value) {
    return 'Sürüm: $value';
  }

  @override
  String receivedValue(Object value) {
    return 'Alındı: $value';
  }

  @override
  String messageValue(Object value) {
    return 'Mesaj: $value';
  }

  @override
  String createdValue(Object value) {
    return 'Oluşturulma: $value';
  }

  @override
  String get adminActions => 'Yönetici İşlemleri';

  @override
  String get moderationCase => 'Moderasyon Vakası';

  @override
  String targetValue(Object value) {
    return 'Hedef: $value';
  }

  @override
  String reportsCount(Object count) {
    return 'Bildirimler: $count';
  }

  @override
  String riskScoreValue(Object value) {
    return 'Risk Puanı: $value';
  }

  @override
  String priorityValue(Object value) {
    return 'Öncelik: $value';
  }

  @override
  String firestoreError(Object error) {
    return 'Firestore hatası: $error';
  }

  @override
  String get refundReview => 'İade İncelemesi';

  @override
  String appointmentIdValue(Object value) {
    return 'Randevu Kimliği: $value';
  }

  @override
  String paymentStatusValue(Object value) {
    return 'Ödeme Durumu: $value';
  }

  @override
  String refundStatusValue(Object value) {
    return 'İade Durumu: $value';
  }

  @override
  String appointmentTimeValue(Object value) {
    return 'Randevu Saati: $value';
  }

  @override
  String cancellationTimeValue(Object value) {
    return 'İptal Saati: $value';
  }

  @override
  String hoursBeforeAppointmentValue(Object value) {
    return 'Randevudan Önceki Saat: $value';
  }

  @override
  String businessValue(Object value) {
    return 'İşletme: $value';
  }

  @override
  String userValue(Object value) {
    return 'Kullanıcı: $value';
  }

  @override
  String petValue(Object value) {
    return 'Evcil Hayvan: $value';
  }

  @override
  String amountPaidValue(Object value) {
    return 'Ödenen Tutar: $value';
  }

  @override
  String refundReasonValue(Object value) {
    return 'İade Nedeni: $value';
  }

  @override
  String refundErrorValue(Object value) {
    return 'İade Hatası: $value';
  }

  @override
  String get approveRefund => 'İadeyi Onayla';

  @override
  String get rejectRefund => 'İadeyi Reddet';

  @override
  String refundReviewFailed(Object error) {
    return 'İade incelemesi başarısız: $error';
  }

  @override
  String get note => 'Not';

  @override
  String refundQueueError(Object error) {
    return 'İade kuyruğu hatası: $error';
  }

  @override
  String get refundRequests => 'İade İstekleri';

  @override
  String get noPendingRefundRequests => 'Bekleyen iade isteği yok';

  @override
  String get reportsTitle => 'Bildirimler';

  @override
  String appointmentValue(Object value) {
    return 'Randevu: $value';
  }

  @override
  String cancelledValue(Object value) {
    return 'İptal: $value';
  }

  @override
  String amountValue(Object value) {
    return 'Tutar: $value';
  }

  @override
  String statusValue(Object value) {
    return 'Durum: $value';
  }

  @override
  String get confirmViolation => 'İhlali Onayla';

  @override
  String get markClean => 'Temiz Olarak İşaretle';

  @override
  String get businessMetrics => 'İşletme Metrikleri';

  @override
  String get businessSearch => 'İşletme Arama';

  @override
  String get searchBusinessNameHint => 'İşletme adı ara...';

  @override
  String get suspendedLabel => 'Askıya alındı';

  @override
  String get filterByStatus => 'Duruma göre filtrele';

  @override
  String get complaintCenter => 'Şikâyet Merkezi';

  @override
  String get noData => 'Veri yok';

  @override
  String get noComplaintsFound => 'Şikâyet bulunamadı';

  @override
  String categoryValue(Object value) {
    return 'Kategori: $value';
  }

  @override
  String get complaintDetail => 'Şikâyet Detayı';

  @override
  String severityValue(Object value) {
    return 'Önem Derecesi: $value';
  }

  @override
  String get evidence => 'Kanıt';

  @override
  String get dismiss => 'Kapat';

  @override
  String get fraudAnalytics => 'Dolandırıcılık Analizi';

  @override
  String get errorLoadingAnalytics => 'Analizler yüklenirken hata oluştu';

  @override
  String get adminMapMonitor => 'Yönetici Harita İzleme';

  @override
  String get platformMetrics => 'Platform Metrikleri';

  @override
  String get noMetricsData => 'Metrik verisi yok';

  @override
  String lastUpdatedValue(Object value) {
    return 'Son güncelleme: $value';
  }

  @override
  String get revenueTitle => 'Gelir';

  @override
  String get noRevenueData => 'Gelir verisi yok';

  @override
  String get auditLogs => 'Denetim Günlükleri';

  @override
  String verifiedValue(Object value) {
    return 'Doğrulandı: $value';
  }

  @override
  String documentNumberValue(Object value) {
    return 'Belge no: $value';
  }

  @override
  String get open => 'Aç';

  @override
  String get petTaxiDocument => 'Evcil Hayvan Taksi Belgesi';

  @override
  String get openPdf => 'PDF\'yi Aç';

  @override
  String get suspendedBusinesses => 'Askıya Alınan İşletmeler';

  @override
  String get noDataReceived => 'Veri alınmadı';

  @override
  String get noSuspendedBusinesses => 'Askıya alınan işletme yok';

  @override
  String get subscriptionDetails => 'Abonelik Detayları';

  @override
  String planValue(Object value) {
    return 'Plan: $value';
  }

  @override
  String priceValue(Object value) {
    return 'Fiyat: $value';
  }

  @override
  String get cancelSubscription => 'Aboneliği İptal Et';

  @override
  String get expireNow => 'Şimdi Süresi Dolmuş Yap';

  @override
  String get makePremium => '⭐ Premium Yap';

  @override
  String get upgradeToPartner => '👑 PetSupo Partner\'a Yükselt';

  @override
  String get downgradeToPremium => '⬇ Premium\'a Düşür';

  @override
  String get extendThirtyDays => '30 Gün Uzat';

  @override
  String get subscriptionManagement => 'Abonelik Yönetimi';

  @override
  String get searchUserIdHint => 'Kullanıcı kimliği ara...';

  @override
  String get loadingSubscription => 'Abonelik yükleniyor...';

  @override
  String get feedbackDetail => 'Geri Bildirim Detayı';

  @override
  String ratingValue(Object value) {
    return 'Puan: $value';
  }

  @override
  String contextValue(Object value) {
    return 'Bağlam: $value';
  }

  @override
  String get messageLabel => 'Mesaj';

  @override
  String get userFeedback => 'Kullanıcı Geri Bildirimi';

  @override
  String get noPayoutsFound => 'Ödeme bulunamadı';

  @override
  String get payoutManagement => 'Ödeme Yönetimi';

  @override
  String get readyLabel => 'Hazır';

  @override
  String get searchPayoutsHint => 'Sipariş, satıcı, alıcı veya referans ara...';

  @override
  String get payoutMarkedReady => 'Ödeme hazır olarak işaretlendi';

  @override
  String get confirmPayout => 'Ödemeyi Onayla';

  @override
  String get bankTransferReference => 'Banka Transfer Referansı';

  @override
  String get bankReferenceHint => 'EFT / FAST / Banka Referansı';

  @override
  String get payoutMarkedPaid => 'Ödeme ödendi olarak işaretlendi';

  @override
  String sellerValue(Object value) {
    return 'Satıcı: $value';
  }

  @override
  String buyerValue(Object value) {
    return 'Alıcı: $value';
  }

  @override
  String referenceValue(Object value) {
    return 'Referans: $value';
  }

  @override
  String get markReady => 'Hazır İşaretle';

  @override
  String get markPaid => 'Ödendi İşaretle';

  @override
  String openEntity(Object id, Object type) {
    return '$type aç: $id';
  }

  @override
  String get globalAdminSearchHint => 'Kullanıcı, köpek, işletme, bildirim veya şikâyet ara...';

  @override
  String get globalAdminSearch => 'Genel Yönetici Araması';

  @override
  String get notAuthenticated => 'Kimlik doğrulanmadı';

  @override
  String get adoptionRequestNotFound => 'Sahiplendirme isteği bulunamadı';

  @override
  String get backToRequests => 'İsteklere dön';

  @override
  String get messageApplicant => 'Başvuru Sahibine Mesaj Gönder';

  @override
  String get unknownPet => 'Bilinmeyen Evcil Hayvan';

  @override
  String get adoptionRequest => 'Sahiplendirme İsteği';

  @override
  String get waitingForOwnerResponse => 'Sahibin yanıtı bekleniyor';

  @override
  String get doneWithIcon => '✅ Tamamlandı';

  @override
  String failedWithIcon(Object error) {
    return '❌ Başarısız: $error';
  }

  @override
  String get availablePets => 'Uygun Evcil Hayvanlar';

  @override
  String get petsCouldNotBeLoaded => 'Evcil hayvanlar yüklenemedi.';

  @override
  String get noPetsAvailable => 'Uygun evcil hayvan yok';

  @override
  String get noImages => 'Görsel yok';

  @override
  String get viewAvailablePets => 'Uygun Evcil Hayvanları Gör';

  @override
  String get signInToContinue => 'Devam etmek için giriş yapın';

  @override
  String get writeReviewFirst => 'Lütfen önce bir değerlendirme yazın';

  @override
  String get reviewSubmitted => 'Değerlendirme gönderildi';

  @override
  String get reviewExperienceHint => 'Deneyiminizi başkalarıyla paylaşın';

  @override
  String get submitReview => 'Değerlendirmeyi Gönder';

  @override
  String get adoptionCenterDetails => 'Sahiplendirme Merkezi Detayları';

  @override
  String get adoptionServices => 'Sahiplendirme Hizmetleri';

  @override
  String get petTypes => 'Evcil Hayvan Türleri';

  @override
  String get workingDays => 'Çalışma Günleri';

  @override
  String get vetCheckIncluded => 'Veteriner Kontrolü Dahil';

  @override
  String get homeVisitAvailable => 'Ev Ziyareti Mevcut';

  @override
  String get transportSupport => 'Ulaşım Desteği';

  @override
  String get fosterSupport => 'Geçici Yuva Desteği';

  @override
  String get media => 'Medya';

  @override
  String get logo => 'Logo';

  @override
  String get approvedBusinesses => 'Onaylı İşletmeler';

  @override
  String get searchBusinessesHint => 'İşletme ara...';

  @override
  String get noApprovedBusinesses => 'Onaylı işletme yok';

  @override
  String get basic => 'Temel';

  @override
  String get disclaimerAccepted => 'Sorumluluk reddi kabul edildi';

  @override
  String get mismatchDetected => '⚠ Uyumsuzluk tespit edildi';

  @override
  String get languageCodeTr => 'TR';

  @override
  String get languageCodeEn => 'EN';

  @override
  String get riskFlags => 'Risk İşaretleri';

  @override
  String get noRiskFlags => 'Risk işareti yok';

  @override
  String get adminNotes => 'Yönetici Notları';

  @override
  String get adminNotesHint => 'Dahili moderasyon notları ekleyin...';

  @override
  String get saveNotes => 'Notları Kaydet';

  @override
  String get adminNotesSaved => 'Yönetici notları kaydedildi ✅';

  @override
  String saveFailed(Object error) {
    return 'Kaydetme başarısız: $error';
  }

  @override
  String get noQuickRepliesFound => 'Hızlı yanıt bulunamadı';

  @override
  String get quickReplies => 'Hızlı Yanıtlar';

  @override
  String get chatFailedToLoad => 'Sohbet yüklenemedi';

  @override
  String get noMessagesYet => 'Henüz mesaj yok';

  @override
  String get typeMessageHint => 'Bir mesaj yazın...';

  @override
  String get noRequests => 'İstek yok';

  @override
  String phoneValue(Object value) {
    return 'Telefon: $value';
  }

  @override
  String genderValue(Object value) {
    return 'Cinsiyet: $value';
  }

  @override
  String petStatusUpdated(Object name) {
    return '$name durumu güncellendi';
  }

  @override
  String statusUpdateFailed(Object error) {
    return 'Durum güncellenemedi: $error';
  }

  @override
  String get deletePetQuestion => 'Evcil hayvan silinsin mi?';

  @override
  String deletePetConfirmation(Object name) {
    return '$name adlı evcil hayvanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.';
  }

  @override
  String petDeleted(Object name) {
    return '$name silindi';
  }

  @override
  String deleteFailedWithError(Object error) {
    return 'Silme başarısız: $error';
  }

  @override
  String get searchPetsHint => 'Evcil hayvan ara';

  @override
  String get noAdoptablePetsYet => 'Henüz sahiplendirilebilir evcil hayvan yok';

  @override
  String get addAdoptablePetsDescription => 'Sahiplendirilebilir evcil hayvanları ekleyin ve durumlarını burada yönetin.';

  @override
  String failedToLoadPets(Object error) {
    return 'Evcil hayvanlar yüklenemedi:\n$error';
  }

  @override
  String breedValue(Object value) {
    return 'Irk: $value';
  }

  @override
  String ageValue(Object value) {
    return 'Yaş: $value';
  }

  @override
  String get edit => 'Düzenle';

  @override
  String get noAdoptionPetsYet => 'Henüz Sahiplendirme Hayvanı Yok';

  @override
  String get addPetsForAdoption => 'Sahiplendirilebilir evcil hayvanlar ekleyin.';

  @override
  String get editAdoptionCenter => 'Sahiplendirme Merkezini Düzenle';

  @override
  String get pleaseAddCoverImage => 'Lütfen bir kapak görseli ekleyin';

  @override
  String get addGalleryImages => 'Galeri Görselleri Ekle';

  @override
  String get petNameLabel => 'Evcil Hayvan Adı';

  @override
  String get ageMonthsLabel => 'Yaş (ay)';

  @override
  String get visible => 'Görünür';

  @override
  String failedToSetCover(Object error) {
    return 'Kapak ayarlanamadı: $error';
  }

  @override
  String get uploadPetMedia => 'Evcil Hayvan Medyası Yükle';

  @override
  String uploadedPercent(Object percent) {
    return '%$percent yüklendi';
  }

  @override
  String get noMediaYet => 'Henüz medya yok';

  @override
  String get cover => 'Kapak';

  @override
  String get adoptionCenterInfo => 'Sahiplendirme Merkezi Bilgileri';

  @override
  String get centerNameLabel => 'Merkez adı';

  @override
  String get instagram => 'Instagram';

  @override
  String get address => 'Adres';

  @override
  String get saveCenterInfo => 'Merkez Bilgilerini Kaydet';

  @override
  String get latestAdoptionApplications => 'Son sahiplendirme başvuruları';

  @override
  String get viewAll => 'Tümünü Gör';

  @override
  String get tapForMoreDetails => 'Daha fazla ayrıntı için dokunun';

  @override
  String get setAvailable => 'Uygun Olarak Ayarla';

  @override
  String get setReserved => 'Rezerve Olarak Ayarla';

  @override
  String get setAdopted => 'Sahiplendirildi Olarak Ayarla';

  @override
  String get setPaused => 'Duraklatılmış Olarak Ayarla';

  @override
  String get clients => 'Müşteriler';

  @override
  String get searchPetOrOwnerHint => 'Evcil hayvan veya sahip adına göre ara';

  @override
  String get couldNotLoadClients => 'Müşteriler yüklenemedi.';

  @override
  String get addClient => 'Müşteri Ekle';

  @override
  String get ownerNameLabel => 'Sahibinin Adı';

  @override
  String get notes => 'Notlar';

  @override
  String get price => 'Fiyat';

  @override
  String get saveClient => 'Müşteriyi Kaydet';

  @override
  String get petOwnerNamesRequired => 'Evcil hayvan ve sahip adı gereklidir';

  @override
  String get clientSaved => 'Müşteri kaydedildi';

  @override
  String lastGrooming(Object date) {
    return 'Son bakım: $date';
  }

  @override
  String get noClientsYet => 'Henüz müşteri yok';

  @override
  String get addFirstGroomingClient => 'Ziyaretleri takip etmeye başlamak için ilk bakım müşterinizi ekleyin.';

  @override
  String get clientProfile => 'Müşteri Profili';

  @override
  String get openAppointmentBooking => 'Randevu rezervasyonunu işletme sayfasından açın';

  @override
  String get groomingHistory => 'Bakım Geçmişi';

  @override
  String get ownerNotFound => 'Sahip bulunamadı';

  @override
  String get signInRequired => 'Oturum açmanız gerekiyor';

  @override
  String get addGroomingVisit => 'Bakım Ziyareti Ekle';

  @override
  String get serviceVisitTitle => 'Hizmet / Ziyaret Başlığı';

  @override
  String get saveVisit => 'Ziyareti Kaydet';

  @override
  String get visitSaved => 'Ziyaret kaydedildi';

  @override
  String get editClient => 'Müşteriyi Düzenle';

  @override
  String get salonSchedule => 'Salon Takvimi';

  @override
  String get manageGroomingAppointments => 'Bakım randevularını yönetin';

  @override
  String amountTry(Object amount) {
    return '$amount TRY';
  }

  @override
  String get uploadGroomingMedia => 'Bakım Medyası Yükle';

  @override
  String get add => 'Ekle';

  @override
  String get afterPlatformCommission => 'Platform komisyonu sonrası';

  @override
  String get recentAppointments => 'Son Randevular';

  @override
  String get latestGroomingRequests => 'Son bakım talepleri ve seansları';

  @override
  String appointmentError(Object error) {
    return 'Randevu hatası: $error';
  }

  @override
  String get noGroomingAppointmentsYet => 'Henüz bakım randevusu yok';

  @override
  String get deleteService => 'Hizmeti Sil';

  @override
  String get deleteServiceConfirmation => 'Bu hizmeti silmek istediğinizden emin misiniz?';

  @override
  String get serviceDeleted => 'Hizmet silindi';

  @override
  String get deleteFailed => 'Silme başarısız';

  @override
  String get availabilityUpdated => 'Müsaitlik güncellendi';

  @override
  String updateFailed(Object error) {
    return 'Güncelleme başarısız: $error';
  }

  @override
  String get availability => 'Müsaitlik';

  @override
  String get capacityBookingExplanation => 'Kapasite, müsait oda sayısını aşan çakışan konaklamaları önlemek için kullanılır.';

  @override
  String get roomCapacity => 'Oda Kapasitesi';

  @override
  String get maximumPetsRooms => 'Azami evcil hayvan / oda';

  @override
  String currentCapacity(int count) {
    return 'Mevcut kapasite: $count';
  }

  @override
  String get saveAvailability => 'Müsaitliği Kaydet';

  @override
  String get checkIn => 'Giriş Yap';

  @override
  String get completeStay => 'Konaklamayı Tamamla';

  @override
  String alreadyStatus(Object status) {
    return 'Zaten $status';
  }

  @override
  String bookingUpdated(Object status) {
    return 'Rezervasyon güncellendi: $status';
  }

  @override
  String bookingError(Object error) {
    return 'Rezervasyon hatası: $error';
  }

  @override
  String get hotelProfile => 'Otel Profili';

  @override
  String get hotelOverview => 'Otel Genel Bakışı';

  @override
  String get pendingRequests => 'Bekleyen Talepler';

  @override
  String get uploadHotelMedia => 'Otel Medyası Yükle';

  @override
  String get proposeFinalPrice => 'Nihai Fiyat Öner';

  @override
  String get editProposedPrice => 'Önerilen Fiyatı Düzenle';

  @override
  String get notifyCustomerConfirmation => 'Bu işlem müşteriye bildirim gönderecek.';

  @override
  String get finalPrice => 'Nihai fiyat';

  @override
  String get customerMustPayBeforeTrip => 'Yolculuk başlamadan önce müşteri bu tutarı uygulamada ödemelidir.';

  @override
  String get sendPrice => 'Fiyatı Gönder';

  @override
  String get petTaxiOverview => 'Pet Taksi Genel Bakışı';

  @override
  String get driverOnline => 'Sürücü Çevrimiçi';

  @override
  String get petTaxiAwaitingActivation => 'Pet Taksi etkinleştirme bekliyor.';

  @override
  String get petTaxiAvailabilityUpdateFailed => 'Sürücü çevrimiçi durumu güncellenemedi. Lütfen tekrar deneyin.';

  @override
  String get serviceDetailsSaveFailed => 'Hizmet ayrıntıları kaydedilemedi.';

  @override
  String get priceDeterminedAfterExamination => 'Nihai fiyat muayeneden sonra belirlenecekse boş bırakın.';

  @override
  String get editing => 'Düzenleniyor';

  @override
  String get setPriceDurationDescription => 'Evcil hayvan sahiplerine gösterilecek fiyatı ve tahmini süreyi belirleyin.';

  @override
  String get serviceDetailsBeforeBooking => 'Bu ayrıntılar, evcil hayvan sahiplerinin rezervasyondan önce hizmeti anlamasına yardımcı olur.';

  @override
  String get addCustomService => 'Özel hizmet ekle';

  @override
  String get create => 'Oluştur';

  @override
  String get paymentSuccessful => 'Ödeme başarılı';

  @override
  String get paymentCancelled => 'Ödeme iptal edildi';

  @override
  String paymentFailedWithError(Object error) {
    return 'Ödeme başarısız: $error';
  }

  @override
  String get appointmentPayment => 'Randevu Ödemesi';

  @override
  String get done => 'Tamam';

  @override
  String get payNow => 'Şimdi Öde';

  @override
  String get titleLabel => 'Başlık';

  @override
  String get noQuickRepliesYet => 'Henüz hızlı yanıt yok';

  @override
  String get quickRepliesDescription => 'Yaygın müşteri soruları için yeniden kullanılabilir yanıtlar oluşturun.';

  @override
  String get inbox => 'Gelen Kutusu';

  @override
  String inboxError(Object error) {
    return 'Gelen kutusu hatası:\n$error';
  }

  @override
  String get emergency => 'Acil';

  @override
  String get noClientMessagesYet => 'Henüz müşteri mesajı yok';

  @override
  String get clientMessagesDescription => 'Evcil hayvan sahipleri kliniğinizle iletişime geçtiğinde konuşmalar burada görünür.';

  @override
  String get passportNumberFormat => 'Pasaport numarası yalnızca büyük harf, sayı, - veya / içermelidir';

  @override
  String get medicalProfileUpdated => 'Tıbbi profil güncellendi';

  @override
  String profileUpdateFailed(Object error) {
    return 'Profil güncellenemedi: $error';
  }

  @override
  String get confirmMicrochipNumber => 'Mikroçip Numarasını Onayla';

  @override
  String get review => 'Gözden Geçir';

  @override
  String get saveAnyway => 'Yine de Kaydet';

  @override
  String get medicalProfile => 'Tıbbi Profil';

  @override
  String get saveMedicalProfile => 'Tıbbi Profili Kaydet';

  @override
  String get ownerProfileUpdated => 'Sahip profili güncellendi';

  @override
  String get ownerProfile => 'Sahip Profili';

  @override
  String couldNotSaveVisit(Object error) {
    return 'Ziyaret kaydedilemedi: $error';
  }

  @override
  String get deleteVisit => 'Ziyareti Sil';

  @override
  String get deleteVisitConfirmation => 'Bu ziyaret tıbbi kayıttan silinsin mi?';

  @override
  String couldNotDeleteVisit(Object error) {
    return 'Ziyaret silinemedi: $error';
  }

  @override
  String get deleteVisitTooltip => 'Ziyareti sil';

  @override
  String get addVaccine => 'Aşı Ekle';

  @override
  String get vaccine => 'Aşı';

  @override
  String get reminder => 'Hatırlatıcı';

  @override
  String get notifyBeforeNextDueDate => 'Sonraki doz tarihinden önce bildir';

  @override
  String get saveVaccine => 'Aşıyı Kaydet';

  @override
  String get patientNotFound => 'Hasta bulunamadı';

  @override
  String get editOwnerProfile => 'Sahip Profilini Düzenle';

  @override
  String get ownerEmergencyContactDetails => 'Sahip ve acil durum iletişim bilgileri';

  @override
  String get editMedicalProfile => 'Tıbbi Profili Düzenle';

  @override
  String get clinicalVeterinaryInformation => 'Klinik ve veteriner bilgileri';

  @override
  String get visits => 'Ziyaretler';

  @override
  String get vaccines => 'Aşılar';

  @override
  String get ownerInformation => 'Sahip Bilgileri';

  @override
  String get visitsUnavailable => 'Ziyaretler kullanılamıyor';

  @override
  String visitsError(Object error) {
    return 'Ziyaret hatası: $error';
  }

  @override
  String get followUp => 'Takip';

  @override
  String get editVisitTooltip => 'Ziyareti düzenle';

  @override
  String get editMedicalNotes => 'Tıbbi Notları Düzenle';

  @override
  String get medicalNotes => 'Tıbbi notlar';

  @override
  String get editVaccineTooltip => 'Aşıyı düzenle';

  @override
  String get deleteVaccineTooltip => 'Aşıyı sil';

  @override
  String get deleteVaccine => 'Aşıyı Sil';

  @override
  String get deleteVaccineConfirmation => 'Bu aşı kaydını silmek istediğinizden emin misiniz?';

  @override
  String get editVaccine => 'Aşıyı Düzenle';

  @override
  String get vaccineName => 'Aşı adı';

  @override
  String get updateVaccine => 'Aşıyı Güncelle';

  @override
  String get completeVaccine => 'Aşıyı Tamamla';

  @override
  String get clientNote => 'Müşteri notu';

  @override
  String get businessInfo => 'İşletme Bilgileri';

  @override
  String get clinicName => 'Klinik adı';

  @override
  String get emergencyServiceEnabled => 'Acil servis etkin';

  @override
  String get saveBusinessInfo => 'İşletme Bilgilerini Kaydet';

  @override
  String get openAppointmentsTab => 'Randevular sekmesini üstten açın';

  @override
  String get viewAllAppointments => 'Tüm randevuları gör';

  @override
  String get checkConnectionTryAgain => 'Lütfen bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get editServiceTooltip => 'Hizmeti düzenle';

  @override
  String get deleteServiceTooltip => 'Hizmeti sil';

  @override
  String get noServicesAddedYet => 'Henüz hizmet eklenmedi';

  @override
  String get addFirstServiceDescription => 'Evcil hayvan sahiplerinin erişebilmesi için ilk hizmetinizi ekleyin.';

  @override
  String get servicesPricing => 'Hizmetler ve Fiyatlandırma';

  @override
  String get addService => 'Hizmet Ekle';

  @override
  String get noServicesYet => 'Henüz hizmet yok.';

  @override
  String servicePriceDuration(Object price, Object currency, Object duration) {
    return '$price $currency • $duration dk';
  }

  @override
  String get serviceTitle => 'Hizmet başlığı';

  @override
  String get durationMinutes => 'Süre (dk)';

  @override
  String get requireDeposit => 'Depozito iste';

  @override
  String get depositAmount => 'Depozito tutarı (₺)';

  @override
  String get featured => 'Öne çıkan';

  @override
  String get active => 'Aktif';

  @override
  String get photoUploadedSuccessfully => 'Fotoğraf başarıyla yüklendi';

  @override
  String get photoDeleted => 'Fotoğraf silindi';

  @override
  String get coverImageUpdated => 'Kapak görseli güncellendi';

  @override
  String get galleryManagement => 'Galeri Yönetimi';

  @override
  String get coverImage => 'Kapak Görseli';

  @override
  String get tapToChangeCover => 'Kapağı değiştirmek için dokunun';

  @override
  String get uploadCoverImage => 'Kapak görseli yükle';

  @override
  String get tapToUploadClinicCover => 'Klinik kapak fotoğrafı yüklemek için dokunun';

  @override
  String get galleryPhotos => 'Galeri Fotoğrafları';

  @override
  String get noGalleryPhotosYet => 'Henüz galeri fotoğrafı yok';

  @override
  String get uploadClinicPhotosDescription => 'Güveni ve görünürlüğü artırmak için klinik fotoğrafları yükleyin.';

  @override
  String get uploadFirstPhoto => 'İlk Fotoğrafı Yükle';

  @override
  String get dragToReorderGallery => 'Galeri fotoğraflarını sıralamak için sürükleyin';

  @override
  String get patients => 'Hastalar';

  @override
  String get back => 'Geri';

  @override
  String get patientRecords => 'Hasta Kayıtları';

  @override
  String shownCount(int count) {
    return '$count gösteriliyor';
  }

  @override
  String get searchPetOwnerBreed => 'Evcil hayvan, sahip veya ırk ara';

  @override
  String get clear => 'Temizle';

  @override
  String preVisitSettingsLoadFailed(Object error) {
    return 'Ön ziyaret ayarları yüklenemedi: $error';
  }

  @override
  String get preVisitSettingsSaved => 'Ön ziyaret formu ayarları kaydedildi';

  @override
  String settingsSaveFailed(Object error) {
    return 'Ayarlar kaydedilemedi: $error';
  }

  @override
  String get preVisitForms => 'Ön ziyaret formları';

  @override
  String get servicePreVisitForms => 'Hizmet ön ziyaret formları';

  @override
  String get serviceMedicalIntakeDescription => 'Her hizmetin kendi tıbbi kabul soruları olabilir.';

  @override
  String get servicesCouldNotBeLoadedPeriod => 'Hizmetler yüklenemedi.';

  @override
  String get noActiveServicesForForms => 'Henüz aktif hizmet yok. Form oluşturmadan önce hizmet ekleyin.';

  @override
  String get enableForService => 'Bu hizmet için etkinleştir';

  @override
  String get onlyServiceAsksQuestions => 'Bu soruları yalnızca bu hizmet soracak.';

  @override
  String get noQuestionsForService => 'Bu hizmet için henüz soru yok.';

  @override
  String get question => 'Soru';

  @override
  String get questionExample => 'örn. Evcil hayvanınız bugün yemek yedi mi?';

  @override
  String get remove => 'Kaldır';

  @override
  String get questionType => 'Soru türü';

  @override
  String get textType => 'Metin';

  @override
  String get longTextType => 'Uzun metin';

  @override
  String get yesNoType => 'Evet / Hayır';

  @override
  String get singleChoice => 'Tek seçim';

  @override
  String get multipleChoice => 'Çoklu seçim';

  @override
  String get numberType => 'Sayı';

  @override
  String get requiredLabel => 'Required';

  @override
  String get options => 'Seçenekler';

  @override
  String optionNumber(int number) {
    return 'Seçenek $number';
  }

  @override
  String get addOption => 'Seçenek ekle';

  @override
  String get clinicSchedule => 'Klinik Takvimi';

  @override
  String get appointments => 'Randevular';

  @override
  String totalCount(int count) {
    return 'Toplam $count';
  }

  @override
  String get services => 'Hizmetler';

  @override
  String get addServiceFlowComingNext => 'Hizmet ekleme akışı yakında';

  @override
  String get clinicServices => 'Klinik Hizmetleri';

  @override
  String get manageVisibleVetServices => 'Görünür veteriner hizmetlerini yönetin';

  @override
  String get clinicSettings => 'Klinik Ayarları';

  @override
  String get emergencyAvailabilitySaveFailed => 'Acil durum müsaitliği kaydedilemedi';

  @override
  String managementNotAvailable(Object label) {
    return '$label yönetimi henüz kullanılamıyor';
  }

  @override
  String loadError(Object error) {
    return 'Yükleme hatası: $error';
  }

  @override
  String get workingHoursSaved => 'Çalışma saatleri kaydedildi';

  @override
  String saveError(Object error) {
    return 'Kaydetme hatası: $error';
  }

  @override
  String get workingHours => 'Çalışma Saatleri';

  @override
  String get clinicWorkingHours => 'Klinik Çalışma Saatleri';

  @override
  String get manageOpeningDays => 'Açık günleri ve randevu müsaitliğini yönetin';

  @override
  String get editGroomyProfile => 'Groomy Profilini Düzenle';

  @override
  String get groomyDetails => 'Groomy Ayrıntıları';

  @override
  String get homeService => 'Evde Hizmet';

  @override
  String get pickupService => 'Alım Hizmeti';

  @override
  String get photos => 'Fotoğraflar';

  @override
  String get complete => 'Tamamla';

  @override
  String get awaitingPayment => 'Ödeme bekleniyor';

  @override
  String appointmentUpdated(Object status) {
    return 'Randevu güncellendi: $status';
  }

  @override
  String get galleryComingSoon => 'Galeri yakında';

  @override
  String get editHotelProfile => 'Otel Profilini Düzenle';

  @override
  String pricePerNight(Object price) {
    return 'Gecelik $price₺';
  }

  @override
  String bookStayAt(Object hotel) {
    return 'Konaklama rezervasyonu • $hotel';
  }

  @override
  String get hotelCareNotesHint => 'Beslenme, ilaç veya bakım notları';

  @override
  String get requestBooking => 'Rezervasyon İste';

  @override
  String get checkoutAfterCheckin => 'Çıkış tarihi giriş tarihinden sonra olmalıdır';

  @override
  String get hotelBookingRequestSent => 'Otel rezervasyon talebiniz gönderildi.';

  @override
  String get noGalleryImagesYet => 'Henüz galeri görseli yok';

  @override
  String get petHotelDetails => 'Evcil Hayvan Oteli Ayrıntıları';

  @override
  String get amenities => 'Olanaklar';

  @override
  String get petTaxiDetails => 'Pet Taksi Ayrıntıları';

  @override
  String get petTaxiManualReviewNotice => 'Pet Taksi başvurunuz, belgeler manuel olarak incelenip onaylanana kadar yayımlanmaz.';

  @override
  String get petTaxiReplacementExpiryDateDriverLicense => 'Yeni sürücü belgesi son kullanma tarihi';

  @override
  String get petTaxiReplacementExpiryDateTrafficInsurance => 'Yeni trafik sigortası son kullanma tarihi';

  @override
  String get petTaxiReplacementExpiryRequired => 'Bu değişimi göndermeden önce geçerli bir gelecek tarihi seçin.';

  @override
  String get petTaxiReplacementSubmitted => 'Değişim inceleme için gönderildi.';

  @override
  String get petTaxiDocumentsRequiringReplacement => 'Değiştirilmesi gereken belgeler';

  @override
  String get petTaxiRejected => 'Reddedildi';

  @override
  String get petTaxiReplaceDocument => 'Değiştir';

  @override
  String get transportationLawNotice => 'Ulaşım yasaları şehre veya ülkeye göre değişebilir. İşletmeler yerel ulaşım, sigorta ve vergi düzenlemelerine uymakla sorumludur.';

  @override
  String get legalDocumentsPrivacyNotice => 'Yasal belgeler yalnızca işletme sahibi ve yönetici incelemesi için saklanır. Kamuya açık kullanıcılara gösterilmez.';

  @override
  String get savePetTaxiDetails => 'Pet Taksi Ayrıntılarını Kaydet';

  @override
  String get driverVehicle => 'Sürücü ve Araç';

  @override
  String get vehicleType => 'Araç türü';

  @override
  String get preview => 'Önizleme';

  @override
  String get editPetShopProfile => 'PetShop Profilini Düzenle';

  @override
  String get petShopDetails => 'PetShop Ayrıntıları';

  @override
  String get shopTypes => 'Mağaza Türleri';

  @override
  String get priceLevel => 'Fiyat Seviyesi';

  @override
  String get low => 'Düşük';

  @override
  String get mid => 'Orta';

  @override
  String get high => 'Yüksek';

  @override
  String get delivery => 'Teslimat';

  @override
  String get hasDelivery => 'Teslimat Var';

  @override
  String get offers => 'Teklifler';

  @override
  String get hasOffers => 'Teklif Var';

  @override
  String get rejectedBusinesses => 'Reddedilen İşletmeler';

  @override
  String get noRejectedBusinesses => 'Reddedilen işletme yok';

  @override
  String get inheritedFromRegistration => 'Temel kayıttan devralındı';

  @override
  String get veterinaryDetails => 'Veterinerlik Ayrıntıları';

  @override
  String get licenseReviewNotice => 'Bu numara doğrulama sırasında incelenecektir.';

  @override
  String get licenseExpiryDateNumbered => '12. Lisans Son Kullanma Tarihi';

  @override
  String get workingDaysNumbered => '20. Çalışma Günleri';

  @override
  String get acceptedAnimalTypesNumbered => '24. Kabul Edilen Hayvan Türleri';

  @override
  String get confirmInformationAccurate => '41. Verilen bilgilerin doğru olduğunu onaylıyorum';

  @override
  String get agreeDisplayInformation => '42. Bilgilerimin uygulamada gösterilmesini kabul ediyorum';

  @override
  String get agreeDisplayReviews => '43. Kullanıcı yorumlarının gösterilmesini kabul ediyorum';

  @override
  String get acceptPartnershipTerms => '44. PetSupo ortaklık koşullarını kabul ediyorum';

  @override
  String get submitVeterinaryDetails => 'Veterinerlik Ayrıntılarını Gönder';

  @override
  String get adoptionCenterTemporary => 'Sahiplendirme Merkezi (GEÇİCİ)';

  @override
  String reviewsCountParenthesized(Object count) {
    return ' ($count yorum)';
  }

  @override
  String get messageSendingTimedOut => 'Mesaj gönderme zaman aşımına uğradı';

  @override
  String messageFailed(Object error) {
    return 'Mesaj başarısız: $error';
  }

  @override
  String get chatCreating => 'Sohbet oluşturuluyor...';

  @override
  String get startChatting => 'Sohbete başlayın 👋';

  @override
  String get writeMessageHint => 'Mesaj yazın...';

  @override
  String get noChatsYet => 'Henüz sohbet yok';

  @override
  String get startChattingWithPetOwners => 'Evcil hayvan sahipleriyle sohbet edin ve evcil hayvanınıza yeni arkadaşlar bulun 👋';

  @override
  String get failedToLoadChats => 'Sohbetler yüklenemedi';

  @override
  String get personalChatsCouldNotLoad => 'Kişisel sohbetler yüklenemedi.';

  @override
  String get businessConversations => 'İşletme Konuşmaları';

  @override
  String get signInToUseChats => 'Sohbetleri kullanmak için oturum açın';

  @override
  String get chats => 'Sohbetler';

  @override
  String get connectWithPetOwners => 'Evcil hayvan sahipleriyle bağlantı kurun';

  @override
  String get noChatsFound => 'Sohbet bulunamadı';

  @override
  String get tryAnotherKeyword => 'Başka bir anahtar kelime veya kullanıcı adı deneyin.';

  @override
  String get messages => 'Mesajlar';

  @override
  String get failedToLoadMessages => 'Mesajlar yüklenemedi';

  @override
  String get noConversationsYet => 'Henüz konuşma yok';

  @override
  String get userInboxEmptyDescription => 'Bir işletmeyle iletişim kurduğunuzda,\nkonuşmalarınız burada görünür.';

  @override
  String get medicalRecords => 'Tıbbi Kayıtlar';

  @override
  String get vaccinesVisitsAndTreatments => 'Aşılar, muayeneler ve tedaviler';

  @override
  String amountInTry(Object amount) {
    return '$amount TL';
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
  String get payoutEligibleTab => 'Uygun';

  @override
  String get payoutBatchesTab => 'Ödeme paketleri';

  @override
  String get payoutExceptionsTab => 'İstisnalar';

  @override
  String get payoutSelectAllEligible => 'Tüm uygun satıcıları seç';

  @override
  String get payoutCreateBatch => 'Ödeme paketi oluştur';

  @override
  String payoutBatchCreated(Object batchNumber) {
    return '$batchNumber paketi oluşturuldu';
  }

  @override
  String payoutOperationFailed(Object details) {
    return 'Ödeme işlemi başarısız. $details';
  }

  @override
  String get payoutLoadFailed => 'Ödeme verileri yüklenemedi.';

  @override
  String get payoutNoExceptions => 'Ödeme istisnası yok';

  @override
  String get payoutDateFilter => 'Ödeme dönemi';

  @override
  String get payoutToday => 'Bugün';

  @override
  String get payoutYesterday => 'Dün';

  @override
  String get payoutThisWeek => 'Bu hafta';

  @override
  String get payoutLastWeek => 'Geçen hafta';

  @override
  String get payoutThisMonth => 'Bu ay';

  @override
  String get payoutValidBankOnly => 'Geçerli banka hesabı';

  @override
  String get payoutUnknownSeller => 'Satıcı bilgisi mevcut değil';

  @override
  String get payoutBankMissing => 'Banka eksik';

  @override
  String get payoutIncludedOrders => 'Dahil edilen siparişler';

  @override
  String get payoutPeriod => 'Dönem';

  @override
  String get payoutGrossTotal => 'Brüt toplam';

  @override
  String get payoutCommissionTotal => 'Komisyon toplamı';

  @override
  String get payoutNetPayable => 'Net ödenecek';

  @override
  String get payoutNoBatches => 'Ödeme paketi yok';

  @override
  String get payoutSellers => 'satıcı';

  @override
  String get payoutExportXlsx => 'XLSX dışa aktar';

  @override
  String get payoutValid => 'Geçerli';

  @override
  String get payoutBlocked => 'Engelli';

  @override
  String get payoutMissingBusiness => 'İşletme eksik';

  @override
  String get payoutMissingAccountHolder => 'Hesap sahibi eksik';

  @override
  String get payoutMissingIban => 'IBAN eksik';

  @override
  String get payoutInvalidIban => 'Geçersiz IBAN';

  @override
  String get payoutMissingBankName => 'Banka adı eksik';

  @override
  String get payoutNonPositiveAmount => 'Net tutar pozitif olmalıdır';

  @override
  String get payoutSettlementIncomplete => 'Mutabakat tamamlanmadı';

  @override
  String get payoutCommissionUnknown => 'Komisyon inceleme bekliyor';

  @override
  String get payoutCustomerPaid => 'Müşteri ödemesi';

  @override
  String get payoutSellerNetNotCalculated => 'Satıcı neti: hesaplanmadı';

  @override
  String get payoutExcludedFromPayout => 'Ödeme dışında';

  @override
  String get payoutRefundedOrCancelled => 'İade veya iptal edilmiş sipariş';

  @override
  String get payoutAlreadyBatched => 'Zaten bir pakete atanmış';

  @override
  String get payoutAlreadyPaid => 'Zaten ödendi';

  @override
  String get payoutUnsupportedCurrency => 'Desteklenmeyen para birimi';

  @override
  String get payoutIneligible => 'Ödeme için uygun değil';

  @override
  String get payoutStatusFilter => 'Ödeme durumu';

  @override
  String get payoutSettlementFilter => 'Mutabakat durumu';

  @override
  String get payoutBatchFilter => 'Paket ataması';

  @override
  String get payoutIncludedInBatch => 'Pakete dahil';

  @override
  String get payoutNotIncludedInBatch => 'Pakete dahil değil';

  @override
  String get payoutSellerFilter => 'Satıcı / işletme';

  @override
  String get payoutBankFilter => 'Banka';

  @override
  String get payoutMinimumAmount => 'Minimum ödeme';

  @override
  String get payoutMaximumAmount => 'Maksimum ödeme';

  @override
  String get payoutCustomRange => 'Özel tarih aralığı';

  @override
  String get financeOverviewTab => 'Genel Bakış';

  @override
  String get financeWaitingTab => 'Bekleyen';

  @override
  String get financeEligibleSellers => 'Uygun satıcılar';

  @override
  String get financeEligibleRecords => 'Uygun kayıtlar';

  @override
  String get financeWaitingSellers => 'Bekleyen satıcılar';

  @override
  String get financeWaitingRecords => 'Bekleyen kayıtlar';

  @override
  String get financeWaitingAmount => 'Bekleyen tutar';

  @override
  String get financeBlockedRecords => 'Engellenen kayıtlar';

  @override
  String get financeExceptionCount => 'İstisnalar';

  @override
  String get financeTodaySales => 'Bugünkü satışlar';

  @override
  String get financeTodayCommission => 'Bugünkü komisyon';

  @override
  String get financeTodayRefunds => 'Bugünkü iadeler';

  @override
  String get financeTodayEligible => 'Bugün uygun olan';

  @override
  String get financeTodayPaid => 'Bugün ödenen';

  @override
  String get financeOutstandingLiability => 'Ödenmemiş yükümlülük';

  @override
  String get financeMonthlyPlatformRevenue => 'Aylık platform geliri';

  @override
  String get financeNextEligibilityDate => 'Sonraki uygunluk tarihi';

  @override
  String get financeDaysRemaining => 'Kalan gün';

  @override
  String get financeOldestWaitingRecord => 'En eski bekleyen kayıt';

  @override
  String get financeAmountEligibleNext => 'Sonraki uygun olacak tutar';

  @override
  String get financeSendForReview => 'İncelemeye gönder';

  @override
  String get financeApproveBatch => 'Onayla';

  @override
  String get financeRejectBatch => 'Paketi reddet';

  @override
  String get sellerFinanceTitle => 'Finans ve Kazançlar';

  @override
  String get sellerFinanceDetails => 'Detaylar';

  @override
  String get sellerFinanceAvailable => 'Kullanılabilir bakiye';

  @override
  String get sellerFinanceWaiting => 'Bekleyen bakiye';

  @override
  String get sellerFinanceProcessing => 'Paketlenmiş / işleniyor';

  @override
  String get sellerFinancePaidThisMonth => 'Bu ay ödenen';

  @override
  String get sellerFinanceTotalEarnings => 'Toplam kazanç';

  @override
  String get sellerFinanceBlocked => 'Engellenen tutar';

  @override
  String get sellerFinanceBankBlocked => 'Banka hesap bilgileriniz eksik olduğu için ödemeniz engellendi.';

  @override
  String get sellerFinanceBankReady => 'Banka hesabı ödemeler için hazır';

  @override
  String get sellerFinanceUpdateBank => 'Banka hesabını güncelle';

  @override
  String get sellerFinanceWaitingExplanation => 'Kazançlar başarılı ödemeden 21 gün sonra uygun hale gelir.';

  @override
  String get sellerFinanceWaitingSchedule => 'Bekleme takvimi';

  @override
  String get sellerFinanceLastPayout => 'Son ödeme';

  @override
  String get sellerFinanceOrders => 'sipariş';

  @override
  String get sellerFinanceAppointments => 'randevu';

  @override
  String get sellerFinanceBookings => 'rezervasyon';

  @override
  String get sellerFinanceRides => 'yolculuk';

  @override
  String get sellerFinanceRequests => 'talep';

  @override
  String get financeRecommendedAction => 'Önerilen işlem';

  @override
  String get financeOpenSeller => 'Satıcıyı aç';

  @override
  String get financeTomorrowEligible => 'Yarın uygun olacak';

  @override
  String get financeNext7Days => 'Sonraki 7 gün';

  @override
  String get financeNext30Days => 'Sonraki 30 gün';

  @override
  String get financeEstimatedPayable => 'Tahmini ödenecek';

  @override
  String get financeStartProcessing => 'İşlemeyi başlat';

  @override
  String get sellerFinanceEstimatedNext => 'Tahmini sonraki ödeme';

  @override
  String get sellerFinanceTimeline => 'Ödeme zaman çizelgesi';

  @override
  String get sellerFinanceTimelineValue => 'Ödendi → Bekleme (21 gün) → Uygun → Pakete dahil → Aktarıldı → Tamamlandı';

  @override
  String get sellerFinanceEligibleRecords => 'Uygun kayıtlar';

  @override
  String get sellerFinancePayoutHistory => 'Ödeme geçmişi';

  @override
  String get sellerFinanceExceptions => 'İstisnalar';

  @override
  String get financeMarkFailed => 'Başarısız işaretle';

  @override
  String get financeFailureReason => 'Başarısızlık nedeni';

  @override
  String get userProfileCreatorProgram => 'Creator Programı';

  @override
  String get userProfileOpenCreatorDashboard => 'Creator Paneli';

  @override
  String get creatorDashboardTitle => 'Creator Paneli';

  @override
  String get creatorWelcomeBack => 'Tekrar hoş geldin';

  @override
  String get creatorLevelLabel => 'Creator Seviyesi';

  @override
  String get creatorCurrentCampaign => 'Güncel kampanya';

  @override
  String get creatorReferralCodeLabel => 'Referans Kodu';

  @override
  String get creatorReferralLinkLabel => 'Referans Bağlantısı';

  @override
  String get creatorCopyCode => 'Kodu Kopyala';

  @override
  String get creatorCopyLink => 'Bağlantıyı Kopyala';

  @override
  String get creatorReferralCodeCopied => 'Referans kodu kopyalandı';

  @override
  String get creatorReferralLinkCopied => 'Referans bağlantısı kopyalandı';

  @override
  String get creatorQualifiedUsers => 'Nitelikli Kullanıcılar';

  @override
  String get creatorVerifiedPartners => 'Onaylı İşletmeler';

  @override
  String get creatorPendingRewards => 'Bekleyen Ödüller';

  @override
  String get creatorPaidRewards => 'Ödenen Ödüller';

  @override
  String get creatorRecentActivity => 'Son Etkinlikler';

  @override
  String get creatorNoActivityYet => 'Henüz etkinlik yok';

  @override
  String get creatorNoActivityMessage => 'Biri referans bağlantınızı kullandığında etkinlik burada görünecek.';

  @override
  String get creatorUpcomingPayout => 'Yaklaşan Ödeme';

  @override
  String get creatorEstimatedPayout => 'Tahmini ödeme';

  @override
  String get creatorPayoutDate => 'Ödeme tarihi';

  @override
  String get creatorPayoutMethod => 'Ödeme yöntemi';

  @override
  String get creatorOpenFullDashboard => 'Tam Paneli Aç';

  @override
  String get creatorOpenFullDashboardHint => 'Web\'de ayrıntılı grafikleri, analitiği ve tam raporlamayı görün';

  @override
  String get creatorPerformanceOverview => 'Performans Özeti';

  @override
  String get creatorTotalClicks => 'Toplam Tıklama';

  @override
  String get creatorRegistrations => 'Kayıtlar';

  @override
  String get creatorConversionRate => 'Dönüşüm Oranı';

  @override
  String get creatorRewardBreakdown => 'Ödül Dağılımı';

  @override
  String get creatorPayoutHistory => 'Ödeme Geçmişi';

  @override
  String get creatorAnalytics => 'Analitik';

  @override
  String get creatorReferralsTab => 'Referanslar';

  @override
  String get creatorRewardsTab => 'Ödüller';

  @override
  String get creatorFilters => 'Filtreler';

  @override
  String get creatorExport => 'Dışa Aktar';

  @override
  String get creatorTimeframe7d => '7 gün';

  @override
  String get creatorTimeframe30d => '30 gün';

  @override
  String get creatorTimeframe90d => '90 gün';

  @override
  String get creatorTimeframe12m => '12 ay';

  @override
  String get creatorSignInRequiredTitle => 'Giriş gerekli';

  @override
  String get creatorSignInRequiredMessage => 'Creator Panelinizi görmek için giriş yapın';

  @override
  String get creatorAccessDeniedTitle => 'Creator erişimi gerekli';

  @override
  String get creatorAccessDeniedMessage => 'Bu panel yalnızca onaylı PetSupo creator\'ları için kullanılabilir.';

  @override
  String get creatorGoToSignIn => 'Girişe git';

  @override
  String get creatorBadgesAchievements => 'Rozetler ve Başarımlar';

  @override
  String get creatorProgressToNextLevelPrefix => 'Şu seviyeye ilerleme:';

  @override
  String get creatorTotalEarned => 'Toplam kazanç';

  @override
  String get creatorShareYourLink => 'Referans Bağlantınızı Paylaşın';

  @override
  String get creatorStatusPaid => 'Ödendi';

  @override
  String get creatorStatusScheduled => 'Planlandı';

  @override
  String get creatorExportComingSoon => 'Dışa aktarma yakında geliyor';

  @override
  String get creatorFiltersComingSoon => 'Gelişmiş filtreler yakında geliyor';

  @override
  String get creatorStatusLabel => 'Durum';

  @override
  String get creatorStatusActive => 'Aktif';

  @override
  String get creatorStatusInactive => 'Pasif';

  @override
  String get creatorSampleData => 'Örnek veri';

  @override
  String get creatorOpenDashboardFailed => 'Panel açılamadı. Lütfen tekrar deneyin.';

  @override
  String get referralCodeOptionalLabel => 'Referans kodu (isteğe bağlı)';

  @override
  String get referralCodeInvalid => 'Bu referans kodu kullanılamıyor. Onsuz devam edebilirsiniz.';

  @override
  String get moderationNoHistory => 'Henüz moderasyon geçmişi yok';

  @override
  String get complaintNoMessages => 'Henüz mesaj yok.';

  @override
  String get generatedFinanceReports => 'Oluşturulan Finans Raporları';

  @override
  String get noReportFilesGenerated => 'Hiçbir rapor dosyası oluşturulmadı.';

  @override
  String get noEligibleSellers => 'Şu anda uygun satıcı yok';

  @override
  String get viewWaitingSellers => 'Bekleyen Satıcıları Görüntüle';

  @override
  String get clearSearch => 'Aramayı temizle';

  @override
  String get exportFinanceReport => 'Finans Raporunu Dışa Aktar';

  @override
  String exportOperationFailed(Object error) {
    return 'Dışa aktarma işlemi başarısız: $error';
  }

  @override
  String get generatedXlsx => 'Oluşturulan XLSX';

  @override
  String get batchExportedReady => 'Toplu işlem dışa aktarıldı ve işleme hazır.';

  @override
  String get regenerate => 'Yeniden oluştur';

  @override
  String get downloadXlsx => 'XLSX\'i indir';

  @override
  String previewBatch(Object batch) {
    return 'Önizleme $batch';
  }

  @override
  String get auditHistory => 'Denetim Geçmişi';

  @override
  String get noAuditEvents => 'Denetim olayı bulunamadı.';

  @override
  String get settlementRetryRequested => 'Mutabakat yeniden denemesi istendi.';

  @override
  String get financialSnapshot => 'Finansal Özet';

  @override
  String get openOrder => 'Siparişi Aç';

  @override
  String get openSeller => 'Satıcıyı Aç';

  @override
  String get openFinancialSnapshot => 'Finansal Özeti Aç';

  @override
  String get retrySettlement => 'Mutabakatı Yeniden Dene';

  @override
  String get dateRange => 'Tarih aralığı';

  @override
  String get allRecords => 'Tüm kayıtlar';

  @override
  String get today => 'Bugün';

  @override
  String get thisWeek => 'Bu hafta';

  @override
  String get thisMonth => 'Bu ay';

  @override
  String get customRange => 'Özel aralık';

  @override
  String get statuses => 'Durumlar';

  @override
  String get sector => 'Sektör';

  @override
  String get allSectors => 'Tüm sektörler';

  @override
  String get petShop => 'Pet Shop';

  @override
  String get vet => 'Veteriner';

  @override
  String get groomy => 'Groomy';

  @override
  String get hotel => 'Otel';

  @override
  String get taxi => 'Taksi';

  @override
  String get sellerBusinessIdOptional => 'Satıcı işletme ID\'si (isteğe bağlı)';

  @override
  String get currency => 'Para birimi';

  @override
  String get allCurrencies => 'Tüm para birimleri';

  @override
  String get tryCurrency => 'TRY';

  @override
  String get reportLanguage => 'Rapor dili';

  @override
  String get turkish => 'Türkçe';

  @override
  String get english => 'İngilizce';

  @override
  String get both => 'Her ikisi';

  @override
  String get documentType => 'Belge türü';

  @override
  String get accountantCopy => 'Muhasebeci Kopyası';

  @override
  String get internalRecordsCopy => 'Dahili Kayıt Kopyası';

  @override
  String get generateReports => 'Raporları Oluştur';

  @override
  String get download => 'İndir';

  @override
  String get adoptionImpactOverview => 'Etki Özeti';

  @override
  String get adoptionPerformanceShelterActivity => 'Sahiplendirme performansı ve barınak etkinliği';

  @override
  String get noAnimalsAvailableAdoption => 'Şu anda sahiplendirilebilecek hayvan yok.\nBaşvuruları kabul etmeye başlamak için ilk hayvanınızı ekleyin.';

  @override
  String get adoptionTrend => 'Sahiplendirme Trendi';

  @override
  String get noAdoptionsYet => 'Henüz sahiplendirme yok.';

  @override
  String get speciesBreakdown => 'Tür Dağılımı';

  @override
  String get speciesUnavailable => 'Tür bilgisi yok';

  @override
  String get adopted => 'Sahiplendirildi';

  @override
  String get revenueTrend => 'Gelir trendi';

  @override
  String get noRevenueTrendYet => 'Henüz gelir trendi yok';

  @override
  String paymentsCount(Object count) {
    return '$count ödeme';
  }

  @override
  String get revenueBreakdown => 'Gelir dağılımı';

  @override
  String get noRevenueActivityYet => 'Henüz gelir etkinliği yok';

  @override
  String get settlementTimeline => 'Mutabakat zaman çizelgesi';

  @override
  String waitingCount(Object count) {
    return '$count bekliyor';
  }

  @override
  String get noPayoutsYet => 'Henüz ödeme yok';

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
  String get petTaxiRouteUnavailable => 'Seçilen konumlar arasında araçla gidilebilen bir rota bulunamadı. Lütfen alım ve varış konumlarını kontrol edin.';

  @override
  String get routeEstimateUnavailable => 'Rota tahmini şu anda kullanılamıyor. Lütfen seçilen konumları kontrol edip tekrar deneyin.';

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
  String get helpCenterTitle => 'Yardım Merkezi';

  @override
  String get helpCenterIntro => 'PetSupo hakkında yardıma mı ihtiyacınız var? Yanıtları bulun ve desteğe kolayca ulaşın.';

  @override
  String get frequentlyAskedQuestions => 'Sıkça Sorulan Sorular';

  @override
  String get emailAppUnavailable => 'E-posta uygulaması açılamadı';

  @override
  String get emailCopied => 'E-posta kopyalandı';

  @override
  String get privacyPolicyContent => 'PetSupo gizliliğinize saygı duyar ve kişisel verilerinizi korumaya kararlıdır.\n\n1. Topladığımız Veriler\nKişisel bilgiler, konum, evcil hayvan bilgileri, medya ve cihaz bildirim verilerini toplayabiliriz.\n\n2. Verilerin Kullanımı\nVerileriniz hizmetlerimizi sunmak, eşleşmeyi sağlamak, uygulamayı geliştirmek ve izninizle bildirim göndermek için kullanılır.\n\n3. Veri Paylaşımı\nKişisel verilerinizi satmayız. Veriler yalnızca güvenilir hizmet sağlayıcılarla veya yasal zorunluluk halinde paylaşılabilir.\n\n4. Saklama ve Güvenlik\nVerileriniz Avrupa\'daki sunucularda güvenli şekilde saklanır.\n\n5. Saklama Süresi\nVerileri yalnızca gerekli olduğu sürece saklarız.\n\n6. Haklarınız\nVerilerinize erişebilir, düzeltilmesini veya silinmesini isteyebilir ve onayınızı geri çekebilirsiniz.\n\n7. Hesap Silme\nHesabınızı silmek için bizimle iletişime geçin.\n\n8. Çocukların Gizliliği\nPetSupo 13 yaş altı çocuklara yönelik değildir.\n\n9. Değişiklikler\nBu politikayı güncelleyebiliriz.\n\n10. İletişim\nSorularınız için bizimle iletişime geçin:';

  @override
  String get privacyContactTitle => '7. İletişim';

  @override
  String get privacyContactPrompt => 'Bu Gizlilik Politikası veya verileriniz hakkında sorularınız varsa bizimle iletişime geçin:';

  @override
  String get privacyResponseTime => 'En kısa sürede yanıt vereceğiz.';

  @override
  String get termsEmailCopied => 'E-posta kopyalandı';

  @override
  String get termsOfServiceTitle => 'Hizmet Şartları';

  @override
  String get termsIntro => 'PetSupo\'yu kullanarak aşağıdaki şartları kabul etmiş olursunuz:';

  @override
  String get termsResponseTime => 'Makul bir süre içinde yanıt vermeyi hedefliyoruz.';

  @override
  String get invoiceNumberDateRequired => 'Fatura numarası ve tarihi gerekli';

  @override
  String invoiceUploadFailed(Object error) {
    return 'Fatura yüklenemedi: $error';
  }

  @override
  String invoiceStatusMessage(Object status) {
    return 'Fatura $status';
  }

  @override
  String invoiceReviewFailed(Object error) {
    return 'Fatura incelemesi başarısız: $error';
  }

  @override
  String get openInvoice => 'Faturayı aç';

  @override
  String get invoiceNumber => 'Fatura numarası';

  @override
  String get invoiceDate => 'Fatura tarihi';

  @override
  String get invoiceType => 'Fatura türü';

  @override
  String get individual => 'Bireysel';

  @override
  String get company => 'Şirket';

  @override
  String get noteOptional => 'Not (isteğe bağlı)';

  @override
  String get rejectionReasonOptional => 'Red nedeni (isteğe bağlı)';

  @override
  String get paymentSuccessTitle => 'Ödeme Başarılı';

  @override
  String get paymentSuccessMessage => 'Ödeme başarıyla tamamlandı ✅';

  @override
  String get paymentFailedTitle => 'Ödeme Başarısız';

  @override
  String get paymentFailedMessage => 'Ödeme doğrulaması başarısız oldu ❌';

  @override
  String get paymentCancelledTitle => 'Ödeme İptal Edildi';

  @override
  String get paymentCancelledMessage => 'Ödeme iptal edildi ⚠️';

  @override
  String get submitComplaintTitle => 'Şikayet Gönder';

  @override
  String get submitComplaintConfirmation => 'Bu şikayeti göndermek istediğinizden emin misiniz?';

  @override
  String get complaintSubmittedSuccessfully => 'Şikayet başarıyla gönderildi';

  @override
  String get unexpectedError => 'Beklenmeyen hata';

  @override
  String get complaintCategory => 'Kategori';

  @override
  String get pleaseSelectRating => 'Lütfen puan seçin';

  @override
  String get feedbackSubmittedSuccessfully => 'Geri bildirim başarıyla gönderildi';

  @override
  String feedbackSubmissionFailed(Object error) {
    return 'Gönderim başarısız: $error';
  }

  @override
  String get sendFeedback => 'Geri Bildirim Gönder';

  @override
  String get feedbackIntro => 'Geri bildirimleriniz, fikirleriniz ve önerilerinizle PetSupo\'yu geliştirmemize yardımcı olun.';

  @override
  String get rateYourExperience => 'Deneyiminizi puanlayın';

  @override
  String get feedbackCategory => 'Geri Bildirim Kategorisi';

  @override
  String get generalFeedback => 'Genel Geri Bildirim';

  @override
  String get bugReport => 'Hata Bildirimi';

  @override
  String get featureRequest => 'Özellik Talebi';

  @override
  String get yourMessage => 'Mesajınız';

  @override
  String get submitFeedback => 'Geri Bildirimi Gönder';

  @override
  String get memorialImageLoadFailed => 'Bu resim yüklenemedi. Lütfen başka bir fotoğraf deneyin.';

  @override
  String get createMemorial => 'Anı Oluştur';

  @override
  String get memorialTitle => 'Anı başlığı';

  @override
  String get storyMessage => 'Hikaye / mesaj';

  @override
  String get city => 'Şehir';

  @override
  String get country => 'Ülke';

  @override
  String get memorialHeaderMessage => 'Doğayla bir anı oluşturarak sevgili dostunuzu onurlandırın.';

  @override
  String get addPetBeforeMemorial => 'Anı oluşturmadan önce bir evcil hayvan ekleyin.';

  @override
  String get addPetFirst => 'Önce Evcil Hayvan Ekle';

  @override
  String get choosePhoto => 'Fotoğraf Seç';

  @override
  String get memorialPhotoPreviewMessage => 'Fotoğraf yükleme daha sonra bağlanacak. Önizleme şimdilik yereldir.';

  @override
  String get memorialCreated => 'Anı oluşturuldu.';

  @override
  String get greenMemorial => 'Yeşil Anı';

  @override
  String get greenMemorialIntro => 'Sevgili dostunuzun anısına bir ağaç dikin.';

  @override
  String memorialInMemoryOf(Object petName) {
    return '$petName anısına 🌱';
  }

  @override
  String memorialByOwner(Object ownerName) {
    return '$ownerName tarafından';
  }

  @override
  String get favoriteProductsTitle => 'Favori Ürünler';

  @override
  String get productNotFound => 'Ürün bulunamadı';

  @override
  String get sellerRatingLabel => 'Satıcı puanı';

  @override
  String get aboutSellerTitle => 'Satıcı Hakkında';

  @override
  String get newestFirst => 'Önce en yeniler';

  @override
  String sellerProductsLoadError(Object error) {
    return 'Satıcı ürünleri yüklenirken hata oluştu: $error';
  }

  @override
  String get sellerNoActiveProducts => 'Bu satıcının aktif ürünü yok';

  @override
  String get sellerInitials => 'KP';

  @override
  String get passwordUpdatedSuccessfully => 'Şifre başarıyla güncellendi';

  @override
  String get passwordStrengthLabel => 'Şifre Gücü:';

  @override
  String get changePasswordTitle => 'Şifreyi Değiştir';

  @override
  String get changePasswordDescription => 'Şifrenizi düzenli olarak güncelleyerek PetSupo hesabınızı güvende tutun.';

  @override
  String get currentPasswordLabel => 'Mevcut Şifre';

  @override
  String get enterCurrentPassword => 'Mevcut şifreyi girin';

  @override
  String get newPasswordLabel => 'Yeni Şifre';

  @override
  String get enterNewPassword => 'Yeni şifreyi girin';

  @override
  String get enterConfirmPassword => 'Yeni şifreyi onaylayın';

  @override
  String get updatePasswordLabel => 'Şifreyi Güncelle';

  @override
  String get savedParksTitle => 'Kayıtlı Parklar';

  @override
  String get noSavedParksYet => 'Henüz kayıtlı park yok';

  @override
  String get adoptionFirstAnimal => 'İlk Hayvanınızı Ekleyin';

  @override
  String get completedAdoptionsEmpty => 'Tamamlanan sahiplendirmeler burada görünecek.';

  @override
  String get recentlyAddedAnimals => 'Yeni Eklenen Hayvanlar';

  @override
  String get noAnimalsAdded => 'Henüz hayvan eklenmedi.';

  @override
  String get speciesStatisticsEmpty => 'Tür istatistikleri, ilk başarılı sahiplendirmeden sonra görünecek.';

  @override
  String get petTaxiEstimateDisclaimer => 'Tahmin, İstanbul taksi tarifesi ve evcil hayvan taşıma hizmet bedeline göre hesaplanmıştır. Köprü, otoyol, bekleme ve sağlayıcıya özel ücretler eklenebilir. Kesin fiyat sağlayıcı tarafından onaylanacaktır.';

  @override
  String get unblockUserTitle => 'Kullanıcı engelini kaldır';

  @override
  String unblockConfirmation(Object name) {
    return '$name kullanıcısının engelini kaldırmak istediğinizden emin misiniz?';
  }

  @override
  String unblockSuccess(Object name) {
    return '$name kullanıcısının engeli kaldırıldı';
  }

  @override
  String get unblockFailed => 'Kullanıcının engeli kaldırılamadı';

  @override
  String get blockedUsersTitle => 'Engellenen Kullanıcılar';

  @override
  String get mustBeSignedIn => 'Oturum açmış olmalısınız';

  @override
  String blockedUserCount(Object count) {
    return '$count engellenen kullanıcı';
  }

  @override
  String blockedUsersCount(Object count) {
    return '$count engellenen kullanıcı';
  }

  @override
  String get blockedUsersDescription => 'Etkileşim kurmasını engellediğiniz kullanıcıları yönetin.';

  @override
  String get noBlockedUsers => 'Engellenen kullanıcı yok';

  @override
  String get blockedUsersEmptyDescription => 'Engellediğiniz kullanıcılar burada görünür. İstediğiniz zaman engellerini kaldırabilirsiniz.';

  @override
  String blockedOn(Object date) {
    return 'Engelleme tarihi: $date';
  }

  @override
  String get unblockButton => 'Engeli Kaldır';

  @override
  String get deleteAccountFailed => 'Hesap silinemedi. Lütfen tekrar deneyin.';

  @override
  String get deleteActionPermanent => 'Bu işlem kalıcıdır.\n\nTüm köpekleriniz, sohbetleriniz, favorileriniz ve etkinlikleriniz kalıcı olarak silinecektir.';

  @override
  String get deleteConfirmationCodeHint => 'Onaylamak için DELETE yazın';

  @override
  String get deleteConfirmationCode => 'DELETE';

  @override
  String get deleteAccountPermanentNotice => 'Bu işlem kalıcıdır ve geri alınamaz.';

  @override
  String get whatWillBeDeleted => 'Neler silinecek';

  @override
  String get confirmation => 'Onay';

  @override
  String get privacySettingsUpdated => 'Gizlilik ayarları güncellendi';

  @override
  String get privacySecurityTitle => 'Gizlilik ve Güvenlik';

  @override
  String get privacySecurityDescription => 'Görünürlüğünüzü, veri paylaşımını ve hesap gizliliği ayarlarınızı yönetin.';

  @override
  String get dataExportRequestSubmitted => 'Veri dışa aktarma isteği gönderildi';

  @override
  String get deleteAccountDataNotice => 'Bu işlem geri alınamaz ve tüm verileriniz kalıcı olarak silinir.';

  @override
  String get exitAppTitle => 'Uygulamadan çıkılsın mı?';

  @override
  String get exitAppMessage => 'PetSupo\'yu kapatmak istiyor musunuz?';

  @override
  String get exitButton => 'Çıkış';

  @override
  String get petSupoBrand => 'PetSupo';

  @override
  String get aboutUsTitle => 'Hakkımızda';

  @override
  String get aboutUsContent => 'PetSupo, evcil hayvan sahiplerini birbirine bağlamak ve hayvanların sosyal yaşamını geliştirmek için tasarlanmış dijital bir platformdur.\n\nUygulama, kullanıcıların köpekleri için uygun oyun arkadaşları bulmasını, yakındaki veteriner hizmetlerini keşfetmesini ve petshop, kuaför ve pet oteli gibi evcil hayvan işletmelerine erişmesini sağlar.\n\nPetSupo bir hizmet sağlayıcı olarak hareket etmez; kullanıcılar ile üçüncü taraf hizmetler arasında kolaylaştırıcıdır. Kullanıcılar platform üzerinden gerçekleştirdikleri etkileşimlerden ve kararlardan sorumludur.\n\nMisyonumuz, dünyanın dört bir yanındaki evcil hayvan sahipleri için güvenli, verimli ve kullanıcı dostu bir ortam sunmaktır.';

  @override
  String get faqDescription => 'PetSupo özellikleri, gizlilik, abonelikler ve güvenlik hakkında hızlı yanıtlar bulun.';

  @override
  String get reportTitleRequired => 'Lütfen bir başlık girin';

  @override
  String get reportSubmittedSuccessfully => 'Bildirim başarıyla gönderildi';

  @override
  String reportSendFailed(Object error) {
    return 'Bildirim gönderilemedi: $error';
  }

  @override
  String get attachScreenshot => 'Ekran görüntüsü ekle';

  @override
  String get screenshotOptionalHint => 'İsteğe bağlıdır; sorunu daha hızlı anlamamıza yardımcı olur.';

  @override
  String get reportProblemTitle => 'Sorun Bildir';

  @override
  String get reportProblemDescription => 'Neyin yanlış gittiğini anlatın. Bildiriminiz PetSupo\'yu geliştirmemize yardımcı olur.';

  @override
  String get reportIncorrectInformation => 'Yanlış bilgi';

  @override
  String get reportPaymentIssue => 'Ödeme sorunu';

  @override
  String get submitReport => 'Bildirimi Gönder';

  @override
  String vetProfileLoadError(Object error) {
    return 'Yükleme hatası: $error';
  }

  @override
  String get vetProfileUpdatedSuccessfully => 'Veteriner profili başarıyla güncellendi';

  @override
  String vetProfileSaveError(Object error) {
    return 'Kaydetme hatası: $error';
  }

  @override
  String get editVetProfileTitle => 'Veteriner Profilini Düzenle';

  @override
  String get suggestClinicTitle => 'PetSupo\'nun büyümesine yardım edin';

  @override
  String suggestClinicDescription(Object vetName) {
    return '$vetName kliniğini PetSupo\'ya katılmaya ve evcil hayvan sahiplerinin daha kolay randevu almasına yardımcı olmaya davet edin.';
  }

  @override
  String get shareInvitation => 'Daveti Paylaş';

  @override
  String get maybeLater => 'Belki Daha Sonra';

  @override
  String get vaccineDetailsTitle => 'Aşı Detayları';

  @override
  String get clinicCouldNotBeLoaded => 'Klinik yüklenemedi';

  @override
  String get relatedRecords => 'İlgili kayıtlar';

  @override
  String get selectAnOption => 'Bir seçenek belirleyin';

  @override
  String get enterDetails => 'Detayları girin';

  @override
  String get futureDateRequired => 'Lütfen gelecekte bir tarih ve saat seçin.';

  @override
  String get preVisitQuestionsRequired => 'Lütfen zorunlu ziyaret öncesi soruları tamamlayın.';

  @override
  String get noDetailedServicesProvided => 'Ayrıntılı hizmet sunulmadı.';

  @override
  String get noDogsYetMatching => 'Henüz köpek yok — kendi köpeğinizi ekleyip eşleşmeye başlayın! 🐾';

  @override
  String get createProfileToConnect => 'Bağlanmak için profil oluşturun 🐾';

  @override
  String unknownBusinessType(Object sectors) {
    return 'Bilinmeyen işletme türü → $sectors';
  }

  @override
  String get persianLanguage => 'فارسی';

  @override
  String get russianLanguage => 'Русский';

  @override
  String phoneAuthDebugError(Object code, Object details, Object message) {
    return 'Kod: $code\n\nMesaj:\n$message\n\n$details';
  }

  @override
  String get phoneVerificationFailed => 'Telefon doğrulaması tamamlanamadı.';

  @override
  String get changeNumber => 'Numarayı Değiştir';

  @override
  String get verifyPhoneTitle => 'Telefonu Doğrula';

  @override
  String enterCodeSentTo(Object phone) {
    return 'Şu numaraya gönderilen kodu girin\n$phone';
  }

  @override
  String get codeLabel => 'Kod';

  @override
  String get newCodeSent => 'Yeni kod gönderildi';

  @override
  String get resendCode => 'Kodu Yeniden Gönder';

  @override
  String get searchVeterinaryClinics => 'Veteriner kliniklerinde ara...';

  @override
  String get howWouldYouLikeToStart => 'Nasıl başlamak istersiniz?';

  @override
  String get welcomeToPetSopuWithWave => 'PetSupo\'ya hoş geldiniz 👋';

  @override
  String get moreThanAnApp => 'Bir uygulamadan fazlası.\nEvcil hayvanlar ve sahipleri için bir yuva.';

  @override
  String get viewPremiumPlans => 'Premium Planları Görüntüle';

  @override
  String get promotionPerformanceTitle => 'Promosyon performansı';

  @override
  String get promotionCampaignStatus => 'Kampanya durumu';

  @override
  String get promotionCampaignActive => 'Aktif';

  @override
  String get promotionCampaignExpired => 'Süresi doldu';

  @override
  String get promotionCampaignProcessing => 'İşleniyor';

  @override
  String get promotionCampaignNeedsReconciliation => 'Mutabakat gerekiyor';

  @override
  String get promotionSpend => 'Harcama';

  @override
  String get promotionImpressions => 'Gösterimler';

  @override
  String get promotionClicks => 'Tıklamalar';

  @override
  String get promotionCtr => 'TO';

  @override
  String get promotionDetailViews => 'Detay görüntülemeleri';

  @override
  String get promotionFinancialConversions => 'Finansal dönüşümler';

  @override
  String get promotionNetRevenue => 'Atfedilen net gelir';

  @override
  String get promotionRoas => 'ROAS';

  @override
  String get promotionStarts => 'Başlangıç';

  @override
  String get promotionEnds => 'Bitiş';

  @override
  String promotionDurationHours(Object hours) {
    return '$hours saat';
  }

  @override
  String get promotionFinancialSection => 'Finansal performans';

  @override
  String get promotionFinancialAvailable => 'Finansal metrikler güncel.';

  @override
  String get promotionFinancialProvisional => 'Finansal metrikler hâlâ mutabakat aşamasında.';

  @override
  String get promotionFinancialUnavailable => 'Finansal metrikler kullanılamıyor veya uygulanamaz.';

  @override
  String get promotionPetFinancialNotApplicable => 'Pet Boost için finansal metrikler uygulanamaz.';

  @override
  String get promotionNoPerformanceData => 'Promosyonunuz aktif. Kullanıcılar gördükçe ve etkileştikçe performans verileri burada görünecek.';

  @override
  String get promotionRetry => 'Tekrar dene';

  @override
  String get promotionLoadError => 'Performans yüklenemedi.';

  @override
  String get promotionUpToDate => 'Güncel';

  @override
  String get promotionReconciliationStatus => 'Mutabakat';

  @override
  String get promotionNa => 'Uygulanamaz';

  @override
  String get promotionTargetPet => 'Pet';

  @override
  String get promotionTargetProduct => 'Ürün';

  @override
  String get promotionTargetVetService => 'Veteriner hizmeti';

  @override
  String get promotionTargetGroomyService => 'Groomy hizmeti';

  @override
  String get petTaxiDocumentTaxPlate => 'Vergi levhası';

  @override
  String get petTaxiDocumentBusinessRegistration => 'İşletme kayıt belgesi';

  @override
  String get petTaxiDocumentVehicleRegistration => 'Araç ruhsatı';

  @override
  String get petTaxiDocumentDriverLicense => 'Sürücü belgesi';

  @override
  String get petTaxiDocumentTrafficInsurance => 'Trafik sigortası';

  @override
  String get petTaxiDocumentStatusPendingReview => 'İnceleme bekliyor';

  @override
  String get petTaxiDocumentStatusApproved => 'Onaylandı';

  @override
  String get petTaxiDocumentStatusRejected => 'Reddedildi';

  @override
  String get petTaxiDocumentStatusMissing => 'Eksik';

  @override
  String get petTaxiDocumentExpired => 'Süresi dolmuş';

  @override
  String petTaxiDocumentExpiryDate(Object date) {
    return 'Son kullanma tarihi: $date';
  }

  @override
  String get petTaxiDocumentExpiredMessage => 'Bu belgenin süresi dolmuş. Belgeyi reddedin ve işletmeden geçerli yeni bir belge yüklemesini isteyin.';

  @override
  String petTaxiRejectDocumentTitle(Object document) {
    return '$document belgesini reddet';
  }

  @override
  String get petTaxiAdminErrorPermissionDenied => 'Bu işlemi gerçekleştirme izniniz yok.';

  @override
  String get petTaxiAdminErrorUnauthenticated => 'Oturumunuzun süresi dolmuş. Lütfen tekrar giriş yapın.';

  @override
  String get petTaxiAdminErrorNotFound => 'İşletme veya belge bulunamadı.';

  @override
  String get petTaxiAdminErrorInvalidArgument => 'Belge ayrıntılarını kontrol edip tekrar deneyin.';

  @override
  String get petTaxiAdminErrorAlreadyExists => 'Bu işlem zaten tamamlanmış.';

  @override
  String get petTaxiAdminErrorFailedPrecondition => 'Bu işlem mevcut belge durumunda tamamlanamaz.';

  @override
  String get petTaxiAdminErrorGeneric => 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';

  @override
  String get petTaxiAdminActionCompleted => 'Belge güncellendi';

  @override
  String get petTaxiUploadDocument => 'Belge yükle';

  @override
  String get petTaxiTakePhoto => 'Fotoğraf çek';

  @override
  String get petTaxiChoosePhoto => 'Fotoğraf seç';

  @override
  String get petTaxiChoosePdf => 'PDF seç';

  @override
  String get petTaxiSupportedDocumentFormats => 'PDF, JPG veya PNG (en fazla 25 MB)';

  @override
  String get petTaxiUnsupportedDocumentFormat => 'PDF, JPG veya PNG formatında bir belge seçin.';

  @override
  String get petTaxiDocumentTooLarge => 'Bu belge 25 MB boyut sınırını aşıyor.';

  @override
  String get petTaxiDocumentUploadFailed => 'Belge yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get petTaxiOpenDocumentFailed => 'Bu belge açılamadı.';

  @override
  String get businessRegisterOptional => 'İsteğe bağlı';

  @override
  String get businessRegisterTaxPlateRequired => 'Vergi levhası yüklenmelidir.';

  @override
  String get businessRegisterMersisNumberRequired => 'MERSİS numarası gereklidir.';

  @override
  String get businessRegisterPhoneOptional => 'Telefon (isteğe bağlı)';

  @override
  String get businessRegisterWhatsApp => 'WhatsApp';

  @override
  String get businessRegisterDetectLocationTitle => 'İşletme konumunuzu algılayın';

  @override
  String get businessRegisterDetectLocationMessage => 'Şehrinizi ve ilçenizi algılamak için konumunuzu kullanırız.';

  @override
  String get petTaxiDocumentPermissionDenied => 'Kamera veya fotoğraf erişimine izin verilmedi. Bunun yerine fotoğraf ya da PDF seçebilirsiniz.';

  @override
  String get petTaxiRequiredDocuments => 'Gerekli belgeler';

  @override
  String get petTaxiRequiredDocumentsSubtitle => 'Yönetici incelemesi için gerekli belgeler';

  @override
  String get petTaxiOptionalDocuments => 'İsteğe bağlı / koşullu belgeler';

  @override
  String get petTaxiOptionalDocumentsSubtitle => 'Hizmetiniz için geçerliyse yükleyin';

  @override
  String get petTaxiComplianceTitle => 'Uygunluk ve yasal onaylar';

  @override
  String get petTaxiComplianceSubtitle => 'Göndermeden önce gerekli onaylar';

  @override
  String get petTaxiPetSafetyEquipmentConfirmation => 'Araçta evcil hayvan güvenlik ekipmanının bulunduğunu onaylıyorum.';

  @override
  String get petTaxiHygieneConfirmation => 'Hijyen ve sanitasyon gerekliliklerinin karşılandığını onaylıyorum.';

  @override
  String get petTaxiDriverLicenseConfirmation => 'Sürücü belgesinin geçerli olduğunu onaylıyorum.';

  @override
  String get petTaxiVehicleRegistrationConfirmation => 'Araç ruhsatının hizmet aracına ait olduğunu onaylıyorum.';

  @override
  String get petTaxiTrafficInsuranceConfirmation => 'Trafik sigortasının aktif olduğunu onaylıyorum.';

  @override
  String get petTaxiTaxResponsibilityConfirmation => 'Vergi ve fatura veya fiş sorumluluğunun işletmeme ait olduğunu onaylıyorum.';

  @override
  String get petTaxiTransportRulesConfirmation => 'Şehir ve ülke ulaşım kurallarına uyduğumu onaylıyorum.';

  @override
  String get petTaxiComplianceNotes => 'Yönetici incelemesi için uygunluk notları';

  @override
  String get petTaxiOptionalIfApplicable => 'İsteğe bağlı / geçerliyse';

  @override
  String petTaxiDocumentRequired(Object document) {
    return '$document gereklidir';
  }

  @override
  String petTaxiDateRequired(Object date) {
    return '$date gereklidir';
  }

  @override
  String petTaxiDateCannotBePast(Object date) {
    return '$date geçmişte olamaz';
  }

  @override
  String get petTaxiDocumentNumber => 'Belge numarası';

  @override
  String get petTaxiDocumentNumberOptional => 'Belge numarası (isteğe bağlı)';

  @override
  String get petTaxiDocumentNumberRequired => 'Belge numarası gereklidir';

  @override
  String get petTaxiVehicleRegistrationIssueDate => 'Araç ruhsatı düzenlenme tarihi';

  @override
  String get petTaxiDriverLicenseExpiryDate => 'Sürücü belgesi son geçerlilik tarihi';

  @override
  String get petTaxiTrafficInsuranceExpiryDate => 'Trafik sigortası son geçerlilik tarihi';

  @override
  String get petTaxiSrcCertificateExpiryDate => 'SRC belgesi son geçerlilik tarihi';

  @override
  String get petTaxiPsychotechnicalExpiryDate => 'Psikoteknik raporu son geçerlilik tarihi';

  @override
  String get petTaxiKaskoExpiryDate => 'Kasko son geçerlilik tarihi';

  @override
  String get petTaxiValidTurkishPlate => 'Geçerli bir Türk araç plakası girin.';

  @override
  String get petTaxiRequiredDocumentsMissing => 'Gerekli Pet Taksi belgelerini yükleyin.';

  @override
  String get petTaxiComplianceConfirmationsMissing => 'Gerekli tüm uygunluk onaylarını işaretleyin.';

  @override
  String get petTaxiValidPhoneNumber => 'Geçerli bir telefon numarası girin.';

  @override
  String get petTaxiValidCapacity => 'Geçerli bir araç kapasitesi girin.';

  @override
  String get petTaxiCapacityMinimum => 'Araç kapasitesi en az 1 olmalıdır.';

  @override
  String get petTaxiCapacityMaximum => 'Araç kapasitesi 15\'ten fazla olamaz.';

  @override
  String get petTaxiSelectVehicleType => 'Bir araç türü seçin.';

  @override
  String get petTaxiDriverFullName => 'Sürücü adı soyadı';

  @override
  String get petTaxiDriverPhoneNumber => 'Sürücü telefon numarası';

  @override
  String get petTaxiVehiclePlateNumber => 'Araç plaka numarası';

  @override
  String get petTaxiVehicleCapacity => 'Araç kapasitesi';

  @override
  String get petTaxiVehicleSedan => 'Sedan';

  @override
  String get petTaxiVehicleHatchback => 'Hatchback';

  @override
  String get petTaxiVehicleSuv => 'SUV';

  @override
  String get petTaxiVehicleVan => 'Panelvan';

  @override
  String get petTaxiVehiclePetTransportVan => 'Evcil hayvan taşıma aracı';

  @override
  String get petTaxiVehicleLargeAnimalTransport => 'Büyük hayvan taşıma aracı';
}
