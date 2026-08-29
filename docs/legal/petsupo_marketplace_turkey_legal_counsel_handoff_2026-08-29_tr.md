# Petsupo Pazaryeri — Türkiye Hukuku Mevzuat ve Lisanslama Görüş Talebi

**Hazırlayan şirket:** Pharos Teknoloji Ticaret Ltd. Şti.
**Platform:** Petsupo
**Belge tarihi:** 29 Ağustos 2026
**Belge türü:** Hukuki görüş talebi / çalışma taslağı
**Durum:** Hukuk danışmanı incelemesi bekleniyor
**Gizlilik:** Şirket içi ve yetkili hukuk danışmanıyla sınırlı
**Hukuki durum:** Bu belge hukuki görüş veya onay değildir
**Teknik durum:** İlgili yeni pazaryeri uyum sistemi production ortamında aktif değildir

---

## 1. Amaç ve talep edilen çıktı

Pharos Teknoloji Ticaret Ltd. Şti., "Petsupo" markası altında, evcil hayvan sahiplerini işletme niteliğindeki satıcılarla buluşturan çok-satıcılı ("multi-seller") bir dijital pazaryeri hazırlamaktadır. Bu belge, düzenlemeye tabi ürün kategorilerinin desteklenmesinden veya platformun production (canlı) ortamda etkinleştirilmesinden önce, yazılı bir hukuki görüş talep etmek amacıyla hazırlanmıştır.

Şirket içi teknik ve hukuki ön çalışma, "Revizyon 21" olarak anılan ve şirketin sürüm kontrol sisteminde kayıtlı bulunan bir planlama belgesinde toplanmıştır. Bu belge, o çalışmanın avukat/danışman tarafından okunabilir, teknik altyapıya erişim gerektirmeyen bir özetidir. Bu belgede yer alan hiçbir ifade, nihai bir hukuki sonuç olarak değil, doğrulanması, düzeltilmesi veya onaylanması istenen bir çalışma varsayımı olarak okunmalıdır.

Hukuk danışmanından aşağıdaki çıktıları sağlaması talep edilmektedir:

1. Yazılı bir hukuki görüş.
2. Yürürlükteki güncel mevzuatın ve ilgili maddelerin tam olarak belirtilmesi.
3. Kategori bazında satış statüsünün (izinli / şartlı / yasak / belirsiz) tespiti.
4. Satıcı, işletme ve ürün düzeyinde gerekli izin/ruhsat/bildirim koşullarının belirtilmesi.
5. Çevrimiçi satış ve reklam/iddia kısıtlamalarının tespiti.
6. Platform/aracı hizmet sağlayıcı yükümlülüklerinin tespiti.
7. Aşağıda sunulan taslak kategori matrisinde gerekli görülen düzeltmelerin belirtilmesi.
8. Bulguların "engelleyici (blocking)" ve "engelleyici olmayan (non-blocking)" olarak sınıflandırılması.
9. Teknik gereksinim dokümanlarına doğrudan aktarılabilecek somut, uygulanabilir ifadeler.
10. Doğrudan ilgili regülatöre (bakanlık/kurum) sorulması gereken hususların listesi.
11. Görüşün tarihi ve dayandığı mevzuatın güncellik tarihinin açıkça belirtilmesi.
12. Dayanılan her kaynağın resmî nüshası veya resmî bağlantısının belge ekinde sunulması.

---

## 2. Platform iş modeli ve teknik sınır

Bu bölüm yalnızca hukuki değerlendirme için gerekli olan işlevsel gerçekleri açıklamaktadır; iç yazılım mimarisine ilişkin ayrıntılar bilinçli olarak dışarıda bırakılmıştır.

- Petsupo, işletme niteliğindeki satıcılarla müşterileri buluşturmayı amaçlayan dijital bir platform olarak tasarlanmaktadır.
- Satıcıların, kimliği belirli işletmeler olması öngörülmektedir; anonim/bireysel tüketici satışı modeli değildir.
- Ürünler, platformun kendi veri tabanında "pazaryeri ürün kaydı" olarak saklanır.
- Bir ürünün herkese açık şekilde yayımlanması; içerik denetimi (moderasyon), uyumluluk (compliance) kontrolü ve — bu belgenin konusu olan — hukuki politika kapılarından geçmesine bağlı olacaktır.
- Satıcının seçtiği kategori adı, hukuki sınıflandırma açısından **belirleyici kabul edilmeyecektir**.
- Bir ürünün bileşimi, kullanım amacı, etkin maddesi, etki mekanizması, etiketi ve öne sürülen iddialar (tedavi edici, önleyici, teşhis edici vb.), o ürünün hukuki sınıflandırmasını etkileyebilir.
- Sınıflandırması belirsiz kalan ürünler, varsayılan olarak **yayımlanamaz** ("fail closed") ilkesiyle ele alınacaktır.
- Bu politikanın yürürlüğe girmesinden önce sisteme girilmiş ürünler otomatik olarak onaylanmış sayılmayacaktır ("no grandfathering").
- Production aktivasyonundan önce mevcut ürünlerin yeniden değerlendirilmesi (envanter/inceleme) planlanmaktadır.
- Reçete işleme veya sağlık kaydı yükleme işlevi bu aşamada **yetkilendirilmemiştir ve tasarlanmamıştır**.
- Düzenlemeye tabi hiçbir kategori için şu ana kadar üretim ortamında etkinleştirme yapılmamıştır.
- Canlı hayvan satışı, Petsupo'nun kendi iş politikası gereği hiçbir koşulda izin verilmemektedir.

**Önemli açıklama:** Yukarıda sayılan hukuki kapılar ve kontroller şu an için **planlanmış** olup, henüz üretim sisteminde tam olarak uygulanmamıştır. Aşağıdaki dört durum kesin biçimde birbirinden ayrılmalıdır:

| Durum | Açıklama |
|---|---|
| Şu an uygulanmış olan teknik güvenlik temelleri | Örn. ürün kimliğinin (SKU) değiştirilemezliği, yetkisiz doğrudan silme işlemlerinin engellenmesi gibi, bu belgenin konusu olmayan, ayrı bir teknik güvenlik çalışmasının parçası olarak tamamlanmış, ancak henüz üretime dağıtılmamış (deploy edilmemiş) unsurlar. |
| Planlanan hukuki uygulama (enforcement) | Bu belgede açıklanan kategori sınıflandırması, belge doğrulama, otomatik yayın engelleme gibi mekanizmalar — **henüz kodlanmamıştır**. |
| Mevcut geçici B2B operasyonel kısıtlama | Bölüm 4'te açıklanan, insan onaylı, düşük riskli ürün kabulüyle sınırlı geçici iş süreci. |
| Production aktivasyonu | Pazaryerinin genel kullanıcıya açık, canlı olarak çalıştığı nihai durum — bu belge bu duruma **izin vermemektedir**. |

---

## 3. Kesin şirket politikaları

Aşağıdaki maddeler, Türk hukukunun asgari gerekliliği ne olursa olsun uygulanacak olan, **Petsupo'nun kendi iş kararlarıdır**; bu maddeler yasal asgari koşulun ne olduğuna dair bir iddia değildir.

### A. Canlı hayvan satışı

Petsupo Pazaryeri, istisnasız olarak **her türlü canlı hayvan satışını yasaklamaktadır**. Bu yasak aşağıdaki durumların hiçbirinde geçerliliğini yitirmez:

- Hayvanın türü veya yaşı ne olursa olsun;
- Satıcının resmî bir üretim yeri/satış izni bulunsa dahi;
- Ödemenin "depozito," "rezervasyon," "bakım ücreti" veya benzer bir ad altında sunulması;
- İşlemin "ücretsiz devir" veya "sahiplendirme" olarak adlandırılması;
- Ödemenin platform dışında yapılması;
- İlanın ekipman, hizmet, nakliye veya başka bir kategori altında gizlenerek sunulması ("disguised sale");
- Herhangi bir yönetici (admin) onayının bu yasağı geçersiz kılabileceği bir istisna mekanizması — böyle bir mekanizma bilinçli olarak tasarlanmamıştır ve tasarlanmayacaktır.

**Danışmandan talep:** Bu maddenin ifade biçiminin, meşru sahiplendirme/yeniden yuva bulma (adoption/re-homing) faaliyetiyle herhangi bir çelişki yaratıp yaratmadığının değerlendirilmesi rica olunur.

### B. Sahiplendirme/yeniden yuva bulma sınırı

Petsupo bünyesinde, ticari olmayan, ayrı bir sahiplendirme/yeniden yuva bulma iş akışının bulunması öngörülmektedir. Bu iş akışı, gizlenmiş bir ticari satış kanalına dönüşmemelidir.

**Danışmandan talep:** Aşağıdaki durumları birbirinden ayırmaya yarayacak, hukuken anlamlı göstergelerin (kriterlerin) tanımlanması rica olunur:

- Ticari olmayan gerçek sahiplendirme;
- Makul/gerçek masrafların (bakım, aşı, mikroçip vb.) karşılanması;
- Yetiştiricilik (breeder) veya ticari faaliyet;
- Gizlenmiş satış;
- Bu ayrımda platformun/aracının olası sorumluluğu.

### C. Veteriner tıbbi ürünleri

Petsupo'nun **geçici** iş kararı, reçeteli olsun olmasın, satıcı lisansı veya yönetici onayı bulunsa dahi, tüm veteriner tıbbi ürünlerinin satışını, hukuk danışmanı tam çerçeveyi doğrulayana kadar yasaklamaktır.

### D. Belirsiz düzenlemeye tabi ürünler

Sınıflandırması belirsiz kalan herhangi bir ürün, bu belirsizlik giderilene kadar sisteme kabul edilmez veya yayımlanmaz — "geçici olarak kabul" diye bir ara durum bilinçli olarak tasarlanmamıştır.

---

## 4. Geçici B2B ürün kabul politikası

Aşağıdaki liste, taahhüt edilmiş (committed) Revizyon 21 planının §21.11 bölümünde donmuş biçimde yer alan **operasyonel** duruşu birebir yansıtmaktadır.

**Şu an için yalnızca aşağıdaki düşük riskli ürünler, B2B ekibi tarafından sisteme kabul edilebilir aday olarak değerlendirilebilir:**

- Tasma ve gezdirme kayışları;
- Mama/su kapları;
- Yataklar;
- Sıradan oyuncaklar;
- Kıyafetler;
- Taşıma çantaları/kafesleri;
- Fırça, tarak ve basit bakım araçları;
- Dışkı toplama aksesuarları.

**Açıkça belirtilmelidir ki:**

- Bu liste bir **hukuki güvenli liman (safe harbor)** değildir;
- Bir ürünün kabul edilmesi, o ürünün yayımlanmaya onaylandığı anlamına **gelmez**;
- Her ürün, ileride yapılacak yeniden değerlendirmeye (revalidation) tabi olmaya devam edecektir.

**Aşağıdaki kategoriler, sınıflandırma ve uygulama tamamlanana kadar sisteme kabul edilmemektedir (geçici hariç tutma):**

- Canlı hayvanlar;
- Veteriner tıbbi ürünleri;
- Aşılar;
- Antibiyotikler;
- Enjekte edilebilir ürünler;
- Sakinleştiriciler, hormonlar ve kontrole tabi ürünler;
- Etkin madde içeren pire/kene ürünleri;
- Biyosidal, dezenfektan veya haşere kontrol ürünleri;
- Takviye ürünleri ve vitaminler;
- Tedavi edici, önleyici, teşhis edici veya hastalık iddiası taşıyan ürünler;
- Yara bakımı veya tıbbi cihaz benzeri ürünler;
- Soğuk zincir gerektiren ürünler;
- Hukuki sınıflandırması belirsiz olan her ürün.

**Danışmandan talep:** Bu geçici, temkinli duruşun yeterli olup olmadığının ve geçici olarak hariç tutulması gereken başka bir kategori bulunup bulunmadığının değerlendirilmesi rica olunur.

---

## 5. İncelenmesi istenen ürün kategorileri

Aşağıdaki tablo, iç teknik çalışmada tespit edilen geçici Petsupo yaklaşımını ve avukattan beklenen sınıflandırma çıktısını göstermektedir.

| Kategori | Petsupo geçici yaklaşımı | Hukuki sınıflandırma sorusu | Beklenen avukat çıktısı | Çözülene kadar durum |
|---|---|---|---|---|
| 1. Sıradan aksesuarlar (tasma, kap, yatak, oyuncak, kıyafet, taşıma çantası, bakım aracı) | İzinli (Petsupo değerlendirmesi) | Ürüne özgü bir lisans/izin şartı var mı? | Onay veya düzeltme | Kabul edilebilir aday (Bölüm 4) |
| 2. Standart paketlenmiş mama (tam/tamamlayıcı/yem maddesi) | Şartlı izinli | 5996 sayılı Kanun kapsamındaki "yem" mevzuatının uygulanma biçimi; satıcı (yeniden satıcı) düzeyindeki belge yükü | Kesin sınıflandırma ve belge listesi | Geçici hariç tutma listesinde değil, ancak belge doğrulaması gerekli |
| 3. Tam/tamamlayıcı yem | Şartlı izinli | Aynı yukarıdaki gibi | Aynı yukarıdaki gibi | Aynı yukarıdaki gibi |
| 4. Ödüller (treats) ve yem maddeleri | Şartlı izinli | Aynı yukarıdaki gibi; özel amaçlı/diyetetik ürünler için ek bildirim yükümlülüğü olabilir | Kesin sınıflandırma | Aynı yukarıdaki gibi |
| 5. Hayvan takviye ürünleri/vitamin/probiyotik/yağlar | Belirsiz — hukuki ev sahibi rejim netleştirilmeli; iddia taşıyanlar zorunlu manuel inceleme | Bu ürünler "yem katkı maddesi" mi, ayrı bir kategori mi, insan takviye edici gıda mevzuatı analoji yoluyla uygulanabilir mi? | Kesin rejim tespiti | Geçici hariç tutma listesinde |
| 6. Hijyen ve bakım ürünleri (şampuan, mendil, göz/kulak temizleyici) | Şartlı izinli | "Tıbbi Olmayan Veteriner Sağlık Ürünü" kapsamı ve satıcı düzeyinde bildirim yükü | Kesin sınıflandırma ve belge listesi | Geçici hariç tutma listesinde değil, ancak belge doğrulaması gerekli |
| 7. Biyosidal/dezenfektan/haşere kontrol ürünleri | Belge/lisans doğrulaması gerekli | Ruhsat/tescil şartı; kayıt sisteminin mekanik olarak sorgulanabilir olup olmadığı | Kesin doğrulama yöntemi | Geçici hariç tutma listesinde |
| 8. Pire/kene ürünleri | Belirsiz — biyosidal mi, veteriner tıbbi ürünü mü olduğu ürüne göre değişebilir | Sınır kriterleri: kullanım amacı, etkin madde, bileşim, etki mekanizması, etiket, iddia | Kesin sınır tanımı | Geçici hariç tutma listesinde; hiçbiri tek bir kategoriye varsayılan olarak atanmamaktadır |
| 9. Veteriner tıbbi ürünleri (genel) | Petsupo politikası gereği yasak | Çevrimiçi satışın hukuki dayanağı (bkz. Bölüm 7, Soru 5) | Kesin hukuki dayanak ve kanal tespiti | Petsupo politikası gereği NO-GO |
| 10. Aşılar ve reçeteli ürünler | Petsupo politikası gereği yasak | Aynı yukarıdaki gibi | Aynı yukarıdaki gibi | Petsupo politikası gereği NO-GO |
| 11. Tıbbi yem (medicated feed) | Petsupo politikası gereği yasak | Aynı yukarıdaki gibi | Aynı yukarıdaki gibi | Petsupo politikası gereği NO-GO |
| 12. Teşhis/tıbbi cihaz benzeri ürünler | Manuel inceleme gerekli; iddia taşımayan sıradan araçlar izinli sayılabilir | "Tıbbi cihaz" tanımına giren evcil hayvan ürünü sınırı | Kesin sınır tanımı | Geçici hariç tutma listesinde (iddia taşıyanlar) |
| 13. Yara bakım ürünleri | Manuel inceleme gerekli | Aynı yukarıdaki gibi | Aynı yukarıdaki gibi | Geçici hariç tutma listesinde |
| 14. Soğuk zincir ürünleri | Petsupo politikası gereği yasak (şimdilik) | Uygulanabilir mevzuat ve operasyonel gereklilik | Kesin tespit | Geçici hariç tutma listesinde |
| 15. Kontrole tabi/yüksek riskli ürünler (enjekte edilebilir, antibiyotik, hormon, sakinleştirici) | Petsupo politikası gereği yasak | Bu maddenin gevşetilmesi düşünülmemektedir; teyit yalnızca ileride gerekirse istenecektir | — | Petsupo politikası gereği NO-GO |
| 16. Bitişik hizmetler (veterinerlik, kuaförlük, pansiyon, nakliye, eğitim) | Pazaryeri ürünü kapsamı dışında | Bu hizmetler ayrı bir özellik olarak inşa edilirse kendi hukuki incelemesini gerektirir | — | Şu an inşa edilmemiştir |
| 17. Sahiplendirme/yeniden yuva bulma | Ticari olmayan modül olarak izinli; ticari/ürün yolu olarak yasak | Bölüm 3.B'deki sınır kriterleri | Sınır kriterlerinin onayı | Ayrı, ticari olmayan modül |
| 18. Canlı hayvanlar | Petsupo politikası gereği mutlak surette yasak | Yalnızca bağlam bilgisi olarak: Türk hukukunun asgari düzenlemesi | Bilgilendirme amaçlı, politika değişmeyecektir | Petsupo politikası gereği kesin NO-GO |

**Her kategori için avukattan istenen sınıflandırma seçenekleri:** hukuken izinli; şartlı izinli; lisans/belge doğrulaması gerekli; yalnızca profesyonele özgü; yalnızca reçeteli; çevrimiçi satışı yasak; reklamı kısıtlı; manuel inceleme gerekli; Petsupo politikası gereği yasak; belirsiz/regülatör teyidi gerekli.

---

## 6. Satıcı, işletme ve ürün belgeleri

| Seviye | Olası belge/veri | Hukuki zorunluluk mu? | Kim düzenler/doğrular? | Geçerlilik/yenileme | Petsupo nasıl doğrulamalı? |
|---|---|---|---|---|---|
| Satıcı/işletme kimliği | Vergi levhası, ticaret sicil kaydı | Değerlendirilecek | İlgili resmî kurum | Değerlendirilecek | Belge yükleme + görsel kontrol (mevcut mekanizma) |
| İşletme yeri onayı | Tesis/işletme onay belgesi (uygulanabildiği ölçüde) | Değerlendirilecek | Tarım ve Orman Bakanlığı / ilgili kurum | Değerlendirilecek | Şu an sistemde modellenmemiştir |
| Yem işletmesi kaydı/onayı | Yem işletmecisi onay numarası | Değerlendirilecek | Tarım ve Orman Bakanlığı | Değerlendirilecek | Belge yükleme; onay numarasının biçim kontrolü |
| Üretici/ithalatçı/distribütör statüsü | Yetki belgesi | Değerlendirilecek | İlgili resmî kurum | Değerlendirilecek | Belge yükleme |
| Ürün ruhsatı/tescili/onay numarası | Ruhsat/tescil numarası | Değerlendirilecek | Sağlık Bakanlığı / Halk Sağlığı Genel Müdürlüğü / TİTCK (ürüne göre) | Değerlendirilecek | Numara biçim kontrolü; resmî sicil sorgulanabilir mi belirsiz |
| Yeniden satıcı (reseller) yetkisi | Üreticiden/ithalatçıdan yetki belgesi | Değerlendirilecek | Üretici/ithalatçı | Değerlendirilecek | Belge yükleme |
| Eczane/veteriner satış yetkisi | Yetki belgesi | Uygulanabilirse değerlendirilecek | İlgili meslek odası/kurum | Değerlendirilecek | Şu an bu kategori Petsupo politikası gereği yasak |
| Etiket/ambalaj bilgisi | Etiket görseli/metni | Değerlendirilecek | Üretici | Sürekli | Görsel kontrol |
| İçerik/bileşim bilgisi | Bileşim/etkin madde listesi | Değerlendirilecek | Üretici | Sürekli | Beyan + manuel inceleme |
| Parti/lot numarası | Lot/parti numarası | Değerlendirilecek | Üretici | Parti bazlı | Beyan |
| Son kullanma tarihi | Son kullanma tarihi | Değerlendirilecek | Üretici | Parti bazlı | Mekanik karşılaştırma (mevcut benzer mekanizma) |
| Soğuk zincir/depolama koşulu | Depolama kapasitesi beyanı | Değerlendirilecek | Satıcı | Sürekli | Şu an sistemde modellenmemiştir |
| Fatura/izlenebilirlik bilgisi | Fatura, tedarik zinciri kaydı | Değerlendirilecek | Satıcı | İşlem bazlı | Operasyonel olarak saklanır (Bölüm 4) |
| Geri çağırma (recall) iletişim bilgisi | İletişim kişisi/prosedürü | Değerlendirilecek | Satıcı | Sürekli | Şu an sistemde modellenmemiştir |
| Reklam/iddia kanıtı | Bilimsel/klinik kanıt (varsa) | Değerlendirilecek | Satıcı | Ürün bazlı | Manuel inceleme |

**Danışmandan talep:** Aşağıdaki ayrımların netleştirilmesi rica olunur:

- Satıcının elinde bulundurması gereken belgeler;
- Petsupo'nun toplaması gereken belgeler;
- Petsupo'nun bağımsız olarak doğrulaması gereken bilgiler;
- Resmî bir sicilden mekanik olarak sorgulanabilecek bilgiler;
- Regülatör teyidi gerektiren bilgiler;
- Veri minimizasyonu ilkesi gereği **Petsupo'nun toplamaması gereken** bilgiler.

---

## 7. Zorunlu hukuki sorular

**Soru 1 — Hayvan takviye ürünleri sınıflandırması.** Evcil hayvanlara yönelik vitamin/mineral/probiyotik/takviye ürünleri, 5996 sayılı Kanun kapsamındaki "yem katkı maddesi"/"özel amaçlı yem" rejimine mi tabidir, yoksa ayrı, henüz tespit edilememiş bir kategoriye mi girer? İnsan "Takviye Edici Gıda" mevzuatının hayvan ürünlerine kıyasen uygulanması mümkün müdür?
*Neden önemli:* Bu kategori şu an tamamen belirsiz bırakılmıştır. *Geçici Petsupo varsayımı:* "Yem" rejimi kapsamında, yalnızca manuel inceleme sonrası ve iddia içermeyen ürünler için. *Engelleyici mi?* Evet. *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 2 ve 11. *İstenen atıf:* İlgili kanun/yönetmelik ve madde numarası.

**Soru 2 — Hijyen/bakım ürünü ile tıbbi olmayan veteriner sağlık ürünü sınıflandırması.** Şampuan, kulak/göz temizleyici gibi ürünler, insan kozmetik mevzuatından ayrı, "Tıbbi Olmayan Veteriner Sağlık Ürünü" rejimine mi tabidir? Bir yeniden satıcının (üretici/ithalatçı olmayan) elinde bulundurması gereken bildirim/kayıt kanıtı tam olarak nedir?
*Neden önemli:* Bu kategorinin belge yükü henüz kesinleşmemiştir. *Geçici Petsupo varsayımı:* Belge doğrulaması gerekli; doğrulama sağlanamazsa yayımlanamaz. *Engelleyici mi?* Evet. *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 4. *İstenen atıf:* İlgili yönetmeliğin tam adı, Resmî Gazete sayı/tarihi ve ilgili maddesi.

**Soru 3 — Biyosidal ürün, veteriner tıbbi ürünü ve sıradan hijyen ürünü arasındaki sınır (pire/kene ürünleri dahil).** Bir pire/kene ürününün biyosidal mi (haşere kontrol ürün tipi), veteriner tıbbi ürünü mü, yoksa sıradan hijyen ürünü mü sayılacağını belirleyen kesin kriterler nelerdir? Bu değerlendirmede şu unsurların her birinin rolü nedir: kullanım amacı; etkin madde; bileşim; etki mekanizması; etiketleme; öne sürülen iddialar? Halk Sağlığı Genel Müdürlüğü'nün ruhsat/tescil kaydını mekanik olarak (herkese açık bir sorgu arayüzü ile) sorgulamak mümkün müdür, yoksa doğrulama zorunlu olarak manuel midir?
*Neden önemli:* İç araştırmada, ilgili yönetmeliğin erişilen metninde pire/kene ürünlerinin açıkça adı geçmemektedir; kapsam yalnızca genel haşere kontrol ürün tipi sınıflandırmasından çıkarılmaktadır. *Geçici Petsupo varsayımı:* Sınıflandırması netleşmeyen her pire/kene ürünü için, ne Kategori 7 (biyosidal) ne de Kategori 9 (veteriner tıbbi ürünü) altında otomatik yayın yapılmaz; manuel hukuki sınıflandırma zorunludur. *Engelleyici mi?* Evet. *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 3 (madde 5(1) metni ikincil kaynak — profesyonel hukuk veri tabanı — üzerinden okunmuştur, resmî orijinal metin bu iç çalışmada doğrudan doğrulanamamıştır). *İstenen atıf:* İlgili yönetmeliğin tam adı, madde numarası ve Ek listesi (varsa) referansı.

**Soru 4 — Tıbbi cihaz benzeri evcil hayvan ürünlerinin hukuki sınırı.** Bir yara spreyi veya terapötik ışık/lazer cihazı gibi ürünler ne zaman "sıradan aksesuar" olmaktan çıkıp "veteriner tıbbi cihazı" sayılır ve TİTCK tescili gerektirir?
*Neden önemli:* Bu sınır iç çalışmada tespit edilememiştir. *Geçici Petsupo varsayımı:* Teşhis/tedavi iddiası taşıyan veya cihaz benzeri her ürün, otomatik yayından çıkarılıp manuel incelemeye alınır. *Engelleyici mi?* Evet. *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 6 (bu kaynak iç çalışmada doğrudan doğrulanamamıştır). *İstenen atıf:* İlgili yönetmelik ve madde numarası.

**Soru 5 — Veteriner tıbbi ürünlerinin çevrimiçi satışının hukuki dayanağı.** (a) Veteriner tıbbi ürünlerinin internet üzerinden satışını düzenleyen güncel, kesin hukuki hüküm nedir? (b) Veteriner Tıbbi Ürünler Hakkında Yönetmelik'in 34. maddesi, internet satışı bakımından belirleyici hüküm müdür ve bu maddenin güncel tam metni nedir? (c) 5996 sayılı Kanun'un 13. maddesinin bu konudaki gerçek rolü nedir — iç çalışmada bu madde, yalnızca genel toptan/perakende satış kanalı yapısını düzenlediği, internet satışına doğrudan değinmediği ve kendi bünyesinde lisanslı pet shop'lara ilişkin sınırlı bir istisna içerdiği sonucuna varılmıştır; bu değerlendirmenin doğrulanması veya düzeltilmesi rica olunur. (d) 13. maddedeki bu lisanslı pet shop/kanal istisnasının kapsamı ve anlamı nedir? (e) Bu istisnanın, doğrudan veya dolaylı olarak çevrimiçi satışa herhangi bir etkisi var mıdır? (f) Cevap; reçeteli ürünler, reçetesiz ürünler, antiparaziter veteriner ilaçları, aşılar ve diğer profesyonel kullanıma özgü ürünler arasında farklılık göstermekte midir?
*Neden önemli:* Bu, tüm veteriner tıbbi ürün kategorisinin dayandığı en kritik sorudur. *Geçici Petsupo varsayımı:* Sorunun cevabından bağımsız olarak, tüm veteriner tıbbi ürünleri (reçeteli, reçetesiz, antiparaziter, aşı, profesyonel kullanıma özgü) Petsupo'da **bağımsız bir platform politikası olarak yasaktır**; hiçbir satıcı belgesi, izni veya yönetici kararı bu yasağı geçersiz kılamaz. *Engelleyici mi?* Evet. *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 1 (34. madde — yalnızca varlığı, Resmî Gazete sayısı ve güncellik durumu ikincil kaynaktan doğrulanmıştır, tam metni bu iç çalışmada doğrudan okunamamıştır) ve kaynak sırası 2 (13. madde — tam metni profesyonel bir hukuk veri tabanı üzerinden okunmuştur, resmî orijinal metinle karşılaştırılmamıştır). *İstenen atıf:* Her iki maddenin güncel, konsolide tam metni.

**Soru 6 — Platform/aracı hizmet sağlayıcı sorumluluğu ve bildirim/kaldırma yükümlülükleri.** Petsupo'nun mevcut işlem hacmi ölçeğinde, 6563 sayılı Kanun ve ilgili yönetmelik kapsamındaki tam aracı hizmet sağlayıcı yükümlülükleri nelerdir?
*Neden önemli:* Büyük ölçekli pazaryerlerine ilişkin ek yükümlülükler tespit edilmiştir; Petsupo'nun bu eşiklere yakın olup olmadığı değerlendirilmelidir. *Geçici Petsupo varsayımı:* Temel bildirim/48 saat içinde kaldırma yükümlülüğüne uyulacaktır. *Engelleyici mi?* Hayır (engelleyici değil, ancak teyit istenmektedir). *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 8. *İstenen atıf:* İlgili kanun/yönetmelik maddeleri.

**Soru 7 — Mama/yem satıcısı, tesis ve ürün kanıt gereklilikleri.** Standart paketlenmiş mama kategorisinde, üretici/ithalatçıdan farklı olarak bir **yeniden satıcının (reseller)** tam olarak hangi izin/belgeyi elinde bulundurması gerekir?
*Neden önemli:* Bu belge yükü henüz kesinleşmemiştir. *Geçici Petsupo varsayımı:* Üretici/ithalatçı düzeyindeki belgeyle aynı sınıf kanıt istenecektir, daha dar bir gereklilik teyit edilene kadar. *Engelleyici mi?* Evet — bu kategorinin belge doğrulama süreci işlerlik kazanabilmesi için gereklidir. *Kanıt seviyesi:* Bkz. Bölüm 12, kaynak sırası 2 ve 11. *İstenen atıf:* İlgili mevzuat ve madde numarası.

**Soru 8 — Reklam ve tedavi edici/hastalık iddiası kısıtlamaları.** Yukarıda sayılan kategori bazlı çerçevelerin ötesinde, evcil hayvan ürünlerine yönelik sağlık iddialı reklamları ayrıca kısıtlayan genel bir reklam kurulu/sektörel kural var mıdır?
*Neden önemli:* İç çalışmada tek, konsolide bir "pazaryeri reklamı" kanunu tespit edilememiştir. *Geçici Petsupo varsayımı:* Her iddia, kaynağı ne olursa olsun manuel incelemeye yönlendirilecektir. *Engelleyici mi?* Hayır. *Kanıt seviyesi:* Değerlendirilmedi. *İstenen atıf:* Varsa ilgili düzenleme.

**Soru 9 — Sahiplendirme/yeniden yuva bulma ile ticari satış sınırı.** Petsupo'nun sahiplendirme/yeniden yuva bulma modülü tasarımı (henüz belirlenmemiştir) tamamlandığında, Bölüm 3.B'de tarif edilen sınırı karşılayıp karşılamadığı; modülün herhangi bir unsurunun gizlenmiş satış olarak yorumlanma riski taşıyıp taşımadığı.
*Neden önemli:* Bu sınır, modül inşa edilmeden önce netleştirilmelidir. *Geçici Petsupo varsayımı:* Modül inşa edilmeden önce bu sınıra karşı ayrı bir inceleme yapılacaktır. *Engelleyici mi?* Modül inşa edilmeden önce evet; bu belge için değil. *Kanıt seviyesi:* Değerlendirilmedi (Petsupo'nun kendi politika kararı). *İstenen atıf:* Uygulanabilirse.

**Soru 10 — KVKK ve reçete/sağlıkla ilgili kanıt.** Petsupo'nun ileride toplamayı düşünebileceği herhangi bir reçete, teşhis veya sağlıkla ilgili kanıt, KVKK madde 6 anlamında özel nitelikli kişisel veri işleme yükümlülüğü doğurur mu ve hangi hukuki dayanak ile güvenlik önlemleri gerekir?
*Neden önemli:* Bu, veteriner tıbbi ürün kategorisinin yeniden değerlendirilmesi için bir ön koşuldur. *Geçici Petsupo varsayımı:* Böyle bir özellik şu an tasarlanmamıştır ve tasarlanmayacaktır; hukuki dayanak netleşmeden hiçbir reçete/sağlık kanıtı işlevi geliştirilmeyecektir. *Engelleyici mi?* Yalnızca böyle bir özellik ileride önerilirse. *Kanıt seviyesi:* KVKK madde 6'nın özel nitelikli veri tanımı doğrudan tespit edilmiştir; bu maddenin somut uygulaması değerlendirilmemiştir. *İstenen atıf:* KVKK madde 6 ve ilgili Kurul kararları (varsa).

**Soru 11 — Geri çağırma, kaldırma, denetim kaydı ve saklama yükümlülükleri.** Ürün geri çağırma, güvensiz ürün bildirimi, denetim kaydı tutma ve kayıt saklama sürelerine ilişkin Petsupo'nun tam yükümlülükleri nelerdir?
*Neden önemli:* İç çalışmada yalnızca genel 48 saatlik bildirim/kaldırma yükümlülüğü tespit edilmiştir; sektörel geri çağırma yükümlülükleri (ör. biyosidal veya yem katkı maddesi ürünleri için) ayrı bir regülatörden kaynaklanabilir. *Geçici Petsupo varsayımı:* Genel ticari defter saklama normları (yaklaşık 10 yıl, teyit edilmemiştir) temkinli biçimde uygulanacaktır. *Engelleyici mi?* Hayır. *Kanıt seviyesi:* Değerlendirilmedi. *İstenen atıf:* İlgili mevzuat.

---

## 8. Mesafeli satış ve tüketici hukuku

Danışmandan, aşağıdaki hususların Petsupo'ya uygulanma biçiminin teyit edilmesi rica olunur:

- Satıcı kimliğinin ifşası;
- Sözleşme öncesi bilgilendirme yükümlülüğü;
- Toplam fiyat, KDV/vergiler, kargo ve teslimat bilgilendirmesi;
- Cayma hakkı;
- Çabuk bozulabilen/son kullanma tarihi riski taşıyan mallara ilişkin istisna;
- Hijyen nedeniyle mühürlü ambalajı açılan mallara ilişkin istisna;
- Ayıplı/güvensiz ürün işlemleri;
- İade/geri ödeme süreçleri;
- Pazaryeri aracı hizmet sağlayıcı yükümlülükleri;
- Hukuka aykırı içeriğe ilişkin 48 saatlik müdahale yükümlülüğü;
- Ürün geri çağırma;
- Kayıt saklama;
- Yanıltıcı sağlık iddiaları;
- Reklam sorumluluğu.

**Önemli açıklama:** Mesafeli Sözleşmeler Yönetmeliği 15. madde (c)/(ç) bentlerinin metni, iç çalışmada yalnızca **ikincil kaynak (profesyonel hukuk veri tabanı) üzerinden doğrulanmıştır** ("SECONDARY-CORROBORATED"); resmî Resmî Gazete/mevzuat.gov.tr metniyle doğrudan karşılaştırılmamıştır. Danışmandan bu metnin güncel, resmî nüshasının teyit edilmesi rica olunur.

**Danışmandan ayrıca talep:** Hijyen nedeniyle mühürlü ambalaj istisnasının, "hijyen ürünü" olarak etiketlenen **her** ürüne otomatik olarak genelleştirilmemesi; her ürün ve iade süreci için ayrı değerlendirme yapılması gerektiğinin teyit edilmesi.

---

## 9. KVKK ve veri minimizasyonu

Danışmandan aşağıdaki hususların teyit edilmesi rica olunur:

- Önerilen satıcı/ürün kanıtlarından herhangi birinin kişisel veri içerip içermediği;
- Sağlık/reçete verisinin hangi koşullarda özel nitelikli kişisel veri haline geldiği;
- Petsupo'nun reçete toplama işlevinden tamamen kaçınması gerekip gerekmediği;
- Hukuki dayanak (açık rıza veya kanuni istisna);
- Açık rızanın sınırları;
- Güvenlik yükümlülükleri (erişim kontrolü, şifreleme, kayıt tutma);
- Saklama/imha süreleri;
- Erişim kontrolü gereklilikleri;
- Veri sorumlusu/veri işleyen rollerinin belirlenmesi;
- İlgili kişiye yapılacak aydınlatma bildirimleri;
- Regülatör veya sır saklama yükümlülüğü altındaki kişilere ilişkin istisnalar.

**Mevcut Petsupo varsayılan politikası:**

- Reçete yükleme/işleme işlevi yoktur;
- Gereksiz sağlık verisi toplanmamaktadır;
- Hukuki dayanak netleşmeden bu alanda hiçbir geliştirme yapılmayacaktır (NO-GO).

---

## 10. Mevcut ürünler ve geçiş dönemi

- Nihai hukuki uygulama devreye alınmadan önce sisteme ürün girilebilir.
- **Hiçbir ürün otomatik olarak onaylanmış (grandfathered) sayılmaz.**
- Bir ürünün sistemde kayıtlı olması, yayımlanma izni anlamına gelmez.
- İleride yapılacak envanter (inceleme) süreci, ilk aşamada **yalnızca okuma amaçlı** olacaktır.
- Bu süreç hiçbir ürünü otomatik olarak silmeyecek, kısaltmayacak, yeniden yazmayacak veya onaylamayacaktır.
- Kavramsal (henüz teknik olarak uygulanmamış) durum kategorileri şunlardır:
  - `eligible_candidate` (aday olarak uygun)
  - `needs_documents` (belge gerekli)
  - `manual_legal_review` (manuel hukuki inceleme gerekli)
  - `prohibited` (yasak)
  - `unknown` (bilinmiyor)
  - `data_incompatible` (veri uyumsuz)
- `eligible_candidate` durumu dahi, tek başına yayımlanma anlamına **gelmez**.
- Düzeltme/iyileştirme (remediation) işlemleri, ayrı bir yetkilendirme gerektirir.
- Mevcut sipariş/ödeme kayıtları korunacaktır.
- Sipariş geçmişi, bir ürünü hukuka uygun hale getirmez.
- Mevcut yerine getirme/iade/iptal kararları, her olaya özgü olarak ayrıca değerlendirilir.

**Danışmandan talep:** Aktivasyon öncesinde var olan ürünler/siparişler için ek bir hukuki koruma, bildirim, askıya alma veya saklama kuralına ihtiyaç olup olmadığının değerlendirilmesi rica olunur.

---

## 11. Aktivasyon için hukuki GO/NO-GO kriterleri

Aşağıdaki taslak kontrol listesi, danışmanın onayına veya düzeltmesine sunulmaktadır:

- Yetkili kategori matrisi onaylanmış olmalı;
- Engelleyici sorular yanıtlanmış olmalı;
- Gerekli satıcı/ürün belgeleri tanımlanmış olmalı;
- Doğrulama iş akışı tanımlanmış olmalı;
- Son kullanma/iptal (expiry/revocation) iş akışı tanımlanmış olmalı;
- Geri çağırma/kaldırma prosedürü tanımlanmış olmalı;
- Tüketici bilgilendirmeleri tamamlanmış olmalı;
- KVKK incelemesi tamamlanmış olmalı;
- Otomatik onaylama içermeyen envanter süreci tamamlanmış olmalı;
- Düzeltme (remediation) süreci ayrıca yetkilendirilmiş olmalı;
- İzleme/denetim kayıtları mevcut olmalı;
- Kısıtlı kategoriler teknik olarak engellenmiş olmalı;
- Hukuki metnin sürümü/tarihi kayıt altına alınmış olmalı;
- Danışman onayının kapsamı ve geçerlilik tarihi kayıt altına alınmış olmalı.

**Açıkça belirtilmelidir ki:**

- Kod geliştirmenin tamamlanması, hukuki onay anlamına **gelmez**.
- Testlerin başarıyla geçmesi, hukuki onay anlamına **gelmez**.
- Üretime dağıtım (deployment), aktivasyon yetkisi anlamına **gelmez**.
- **Bu görüş talebi belgesinin kendisi de hukuki onay değildir.**

---

## 12. Kaynak envanteri ve kanıt seviyesi

Aşağıdaki tablo, iç teknik plandaki (Revizyon 21, §21.10) 11 kaynağı, dahili kanıt seviyeleriyle birlikte birebir yansıtmaktadır. **Hiçbir kaynağın kanıt seviyesi bu belgede yükseltilmemiştir.**

Toplam: **11 kaynak** — **0 PRIMARY** (mevcut iç teknik araçlarla doğrudan resmî kaynaktan doğrulanabilen kaynak sayısı); **5 SECONDARY-CORROBORATED** (profesyonel ikincil hukuk veri tabanı üzerinden metni okunmuş); **2 METADATA-ONLY** (yalnızca varlığı/Resmî Gazete sayısı doğrulanmış, madde metni okunmamış); **4 UNRESOLVED** (yalnızca arama sonucu özetiyle tespit edilmiş, bağımsız olarak doğrulanmamış).

| # | Kaynak | Kurum | Madde/Kapsam | Dahili kanıt seviyesi | Ne destekliyor? | Avukattan istenen doğrulama | Resmî bağlantı |
|---|---|---|---|---|---|---|---|
| 1 | Veteriner Tıbbi Ürünler Hakkında Yönetmelik | Tarım ve Orman Bakanlığı / TİTCK | Madde 34, fıkra 1 | METADATA-ONLY (varlık/RG sayısı/güncellik ikincil kaynaktan teyit edilmiş; madde metni okunmamış) | Veteriner tıbbi ürünlerin internet üzerinden satışının belirtilen kanallar dışında yasak olduğu iddiası | Maddenin güncel tam metninin resmî kaynaktan teyidi | mevzuat.gov.tr (RG 24.12.2011/28152) |
| 2 | 5996 sayılı Veteriner Hizmetleri, Bitki Sağlığı, Gıda ve Yem Kanunu | TBMM / Tarım ve Orman Bakanlığı | Madde 13 | SECONDARY-CORROBORATED (tam metin profesyonel hukuk veri tabanı üzerinden okunmuştur) | Toptan/perakende satış kanalı yapısı ve lisanslı pet shop istisnası; internet satışına doğrudan değinmemektedir | Resmî orijinal metinle karşılaştırma | mevzuat.gov.tr/MevzuatMetin/1.5.5996.pdf |
| 3 | Biyosidal Ürünler Yönetmeliği | Sağlık Bakanlığı / Halk Sağlığı Genel Müdürlüğü | Madde 5(1) | SECONDARY-CORROBORATED (tam metin profesyonel hukuk veri tabanı üzerinden okunmuştur) | Biyosidal ürünlerin piyasaya arzından önce ruhsatlandırma/tescil zorunluluğu; pire/kene ürünleri metinde açıkça adı geçmemektedir | Resmî orijinal metinle karşılaştırma; pire/kene sınırının teyidi | mevzuat.gov.tr; hsgm.saglik.gov.tr |
| 4 | Tıbbi Olmayan Veteriner Sağlık Ürünleri Yönetmeliği | Tarım ve Orman Bakanlığı | Genel kapsam | METADATA-ONLY (varlık ve RG sayıları teyit edilmiş, işlevsel madde metni okunmamış) | Hijyen/bakım ürünlerinin ayrı, bildirim temelli bir kategori olduğu | Bildirim koşulunun tam metninin resmî kaynaktan teyidi | RG 17.12.2011/28145; değişiklik RG 18.02.2020/31043 |
| 5 | 5199 sayılı Hayvanları Koruma Kanunu (değişik) | TBMM | Madde 9 | SECONDARY-CORROBORATED (Madde 9'un içeriği LEXPERA kaynaklı bir arama özeti üzerinden okunmuş ve iki bağımsız haber/hukuk bülteni kaynağıyla teyit edilmiştir; resmî konsolide metin bu iç çalışmada doğrudan doğrulanmamıştır.) | Kedi/köpeklerin vitrin satışının kaldırılıp onaylı üretim yeri kanallarına (çevrimiçi dahil) taşınması | Resmî orijinal metinle karşılaştırma | mevzuat.gov.tr |
| 6 | Tıbbi Cihaz Yönetmeliği | Sağlık Bakanlığı / TİTCK | Madde 2 (kapsam istisnaları) | UNRESOLVED (yalnızca arama özetiyle tespit edilmiştir) | AB 2017/745 ile uyum; 5996 kapsamındaki gıda/yem ürünlerinin kapsam dışı bırakılması | Bağımsız doğrulama gereklidir | mevzuat.gov.tr; titck.gov.tr |
| 7 | 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) | KVKK Kurumu | Madde 6 | UNRESOLVED (yalnızca arama özetiyle tespit edilmiştir) | Sağlık verisinin özel nitelikli kişisel veri sayılması | Bağımsız doğrulama gereklidir | kvkk.gov.tr |
| 8 | 6563 sayılı Elektronik Ticaretin Düzenlenmesi Hakkında Kanun (değişik) | Ticaret Bakanlığı / TBMM | Genel; büyük ölçekli pazaryeri hükümleri | UNRESOLVED (yalnızca arama özetiyle tespit edilmiştir) | Aracı hizmet sağlayıcı yükümlülükleri | Bağımsız doğrulama gereklidir | mevzuat.gov.tr |
| 9 | Elektronik Ticaret Aracı Hizmet Sağlayıcı ve Elektronik Ticaret Hizmet Sağlayıcılar Hakkında Yönetmelik | Ticaret Bakanlığı | 48 saatlik hukuka aykırı içerik kaldırma hükmü | SECONDARY-CORROBORATED (belirli hüküm profesyonel hukuk veri tabanı arama sonucu üzerinden teyit edilmiştir, tam madde metni okunmamıştır) | Bildirim üzerine 48 saat içinde içerik kaldırma yükümlülüğü | Tam madde metninin resmî kaynaktan teyidi | Resmî Gazete (tam bağlantı doğrulanmamıştır) |
| 10 | Mesafeli Sözleşmeler Yönetmeliği | Ticaret Bakanlığı | Madde 15(c)/(ç) | SECONDARY-CORROBORATED (tam metin profesyonel hukuk veri tabanı üzerinden okunmuş ve alıntılanmıştır) | Çabuk bozulabilen mal istisnası; hijyen nedeniyle mühürlü ambalaj istisnası | Resmî orijinal metinle karşılaştırma; her ürün için ayrı uygulanabilirlik değerlendirmesi | mevzuat.gov.tr |
| 11 | Hayvan Beslemede Kullanılan Yem Katkı Maddeleri Hakkında Yönetmelikte Değişiklik Yapılmasına Dair Yönetmelik | Tarım ve Orman Bakanlığı | Genel etiketleme hükümleri | UNRESOLVED (yalnızca arama özetiyle tespit edilmiştir) | Ev/süs hayvanı yemlerine ilişkin bazı zorunlu etiketleme alanlarından muafiyet | Bağımsız doğrulama gereklidir | RG 18 Şubat 2022 |

**Açıkça belirtilmelidir ki:**

- LEXPERA (kullanılan profesyonel hukuk veri tabanı), **resmî bir devlet kaynağı değildir**; yalnızca konsolide metin sunan özel, abonelik temelli bir hizmettir.
- İç çalışmada kullanılan araçlarla, `.gov.tr` ve Resmî Gazete alan adlarına **doğrudan erişim sağlanamamıştır** (bağlantı/sertifika sorunları nedeniyle).
- Danışmanın, her kaynağın güncel, resmî konsolide metnini bağımsız olarak doğrulaması gerekmektedir.
- Belgelerin güncelliği, hukuki görüşün verildiği tarih itibarıyla ayrıca kontrol edilmelidir.

---

## 13. Avukattan beklenen cevap formatı

Danışmandan, aşağıdaki yapılandırılmış tabloyu doldurması rica olunur:

| Soru/Kategori | Hukuki sonuç | Dayanak mevzuat ve madde | İzin/ruhsat/belge | Online satış durumu | Reklam kısıtı | Platform yükümlülüğü | Blocking? | Önerilen teknik kural |
|---|---|---|---|---|---|---|---|---|
| *(her kategori/soru için bir satır)* | | | | | | | | |

Her cevap için aşağıdaki etiketlerden birinin kullanılması rica olunur:

- **Confirmed** (Onaylandı);
- **Confirmed with conditions** (Şartlı onaylandı);
- **Prohibited** (Yasak);
- **Regulator confirmation required** (Regülatör teyidi gerekli);
- **Outside scope** (Kapsam dışı);
- **Further facts required** (Ek bilgi gerekli).

Danışmandan ayrıca aşağıdakileri açıkça belirtmesi rica olunur:

- Yetki alanı (jurisdiction);
- Görüş tarihi;
- Dayanılan mevzuatın güncellik tarihi;
- Varsayımlar;
- Sınırlamalar;
- Regülatöre doğrudan başvuru önerilip önerilmediği;
- Hangi sonuçların ileride değişebileceği.

---

## 14. Karar ve imza alanı

*(Bu bölüm, hukuk danışmanı/danışman bürosu tarafından doldurulmak üzere boş bırakılmıştır. Aşağıdaki hiçbir alan önceden doldurulmamış veya bir sonuç önceden seçilmemiştir.)*

- **Hukuk danışmanı / hukuk bürosu:** _______________________
- **İnceleyen avukat:** _______________________
- **Baro / sicil bilgisi:** _______________________
- **Görüş tarihi:** _______________________
- **Mevzuat güncellik tarihi:** _______________________
- **Görüş kapsamı:** _______________________
- **Onaylanan maddeler:** _______________________
- **Değişiklik istenen maddeler:** _______________________
- **Regülatör teyidi gereken maddeler:** _______________________
- **Production aktivasyonuna ilişkin sonuç:**
  - [ ] GO
  - [ ] Şartlı GO
  - [ ] NO-GO
- **İmza / kaşe:** _______________________

---

## 15. Danışman cevaplarının iç sisteme aktarılması (yalnızca bilgi amaçlı)

Bu bölüm, danışmanın vereceği cevapların Petsupo tarafından ileride nasıl kullanılacağını açıklamak amacıyla eklenmiştir; danışmandan bir işlem talep etmemektedir.

Danışman cevapları alındıktan sonra, bunların aşağıdaki teknik ve operasyonel unsurlara dönüştürülmesi planlanmaktadır:

- Yetkili politika sürümü;
- Kategori karar tablosu;
- Satıcı belge şeması;
- Ürün kanıt şeması;
- Sunucu tarafı uygulama (enforcement) mantığı;
- Erişim/güvenlik kuralları (Rules);
- Moderasyon arayüzü;
- Herkese açık ilan listeleme kapısı;
- Son kullanma/iptal (expiry/revocation) işleyişi;
- Geri çağırma/kaldırma işlevi;
- Hazırlık envanteri (readiness inventory);
- Düzeltme (remediation) planı;
- Test senaryoları;
- Devreye alma (rollout) kapısı.

**Açıkça belirtilmelidir ki:** Bu görüş-talebi belgesinin hazırlanması görevi, yukarıda sayılan hiçbir teknik veya operasyonel unsurun geliştirilmesini, uygulanmasını veya devreye alınmasını yetkilendirmemektedir. Bu unsurların her biri, danışman görüşü alındıktan sonra ayrı, açıkça yetkilendirilmiş bir uygulama görevi kapsamında ele alınacaktır.
