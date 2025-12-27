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
  String adoptionRequestSent(Object dogName) {
    return '$dogName için sahiplenme talebi gönderildi!';
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
  String get username => 'Kullanıcı Adı';

  @override
  String get email => 'E-posta';

  @override
  String get phoneNumber => 'Telefon Numarası';

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
  String get welcomeToBarkyMatches => 'Barky Matches\'e hoş geldiniz!';

  @override
  String get welcomeTo => 'Hoş geldiniz';

  @override
  String get barkyMatches => 'Barky Matches!';

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
  String get emailLabel => 'E-posta';

  @override
  String get usernameLabel => 'Kullanıcı Adı';

  @override
  String get phoneLabel => 'Telefon Numarası';

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
  String get noAccountSignUp => 'Hesabınız yok mu? Kayıt Ol';

  @override
  String get haveAccountSignIn => 'Zaten hesabınız var mı? Giriş Yap';

  @override
  String get userNotFound => 'Bu e-posta ile kullanıcı bulunamadı. Lütfen kayıt olun.';

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
  String verificationCodeSent(Object email) {
    return '$email adresine bir doğrulama kodu gönderildi';
  }

  @override
  String get enterCodeLabel => '6 haneli kodu girin';

  @override
  String get verifyButton => 'Doğrula';

  @override
  String get signInToAccessPlaymate => 'Playmate\'e erişmek için lütfen giriş yapın';

  @override
  String get signInToFindFriends => 'Arkadaş bulmak için lütfen giriş yapın';

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
  String get save => 'Kaydet';

  @override
  String dogNameExists(Object name) {
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
  String dogDetailsNameExistsError(Object name) {
    return '$name adında bir köpek zaten mevcut!';
  }

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
  String get moreFiltersButton => 'Daha Fazla Filtre';

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
  String playdateRequestMessage(Object requesterDog, Object requestedDog) {
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
  String get newPlaydateRequest => 'Yeni Oyun Randevusu Talebi!';

  @override
  String playdateRequestBody(Object requesterDog, Object requestedDog) {
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
  String get newPlayDateRequestTitle => 'Yeni Oyun Randevusu Talebi!';

  @override
  String newPlayDateRequestBody(Object dogName) {
    return '$dogName adlı köpekten yeni bir oyun randevusu talebiniz var.';
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
}
