# مدل درآمدی Boost & Promotion Engine پت‌سوپو

**وضعیت سند:** آماده برای بررسی سرمایه‌گذاری؛ مبتنی بر ممیزی repository در ۱۰ اوت ۲۰۲۶

**دامنه:** مدل تجاری و قابلیت‌های درآمدی Promotion Engine؛ نه گزارش درآمد تحقق‌یافته یا مجوز rollout تولید

## ۱. خلاصه اجرایی

Boost & Promotion Engine پت‌سوپو زیرساختی برای تبدیل تقاضای موجود در marketplace به موجودی تبلیغاتی قابل فروش است. کسب‌وکار یا مالک واجد شرایط، برای نمایش برجسته‌تر یک هدف مشخص—مانند سرویس، محصول یا Pet—یک کمپین مدت‌دار خریداری می‌کند. پس از تأیید معتبر پرداخت، کمپین توسط backend فعال می‌شود، در placementهای واجد شرایط نمایش می‌گیرد و در پایان مدت تعیین‌شده منقضی می‌شود.

از دید تجاری، این موتور یک لایه درآمدی مکمل برای کمیسیون، اشتراک، marketplace و Business Services است. ارزش آن در این است که PetSupo برای فروش visibility به مالکیت یا اجرای خودِ خدمت نیاز ندارد؛ کافی است ترافیک، intent و inventory قابل‌کنترل در discovery داشته باشد. با این حال، وضعیت فعلی repository نشان‌دهنده پیاده‌سازی محلی و آمادگی rollout کنترل‌شده است، نه اثبات درآمد یا فعال‌بودن production. بنابراین این سند قابلیت درآمدزایی را توصیف می‌کند و اعداد عملکردی را ادعا نمی‌کند.

## ۲. مسئله بازار

در بازار خدمات حیوانات خانگی، کیفیت به‌تنهایی تضمین‌کننده discovery نیست. کلینیک‌ها، groomerها، فروشندگان و ارائه‌دهندگان خدمات محلی برای دیده‌شدن در لحظه‌ای که کاربر در حال جست‌وجو یا انتخاب است، به کانال توزیع نیاز دارند. کسب‌وکارهای جدید یا کم‌سابقه نیز معمولاً برای ساختن visibility اولیه با مشکل مواجه‌اند.

Marketplace به‌طور طبیعی رقابت برای attention ایجاد می‌کند. PetSupo می‌تواند این رقابت را به محصولی شفاف و محدود تبدیل کند: visibility پولی در کنار relevance ارگانیک، بدون آن‌که fulfillment خدمت را خود بر عهده بگیرد یا نتیجه فروش را تضمین کند.

## ۳. محصول درآمدزا چیست؟

محصول درآمدزا یک campaign برای promotion یک target مشخص است. مشتری هدف، plan مدت‌دار را انتخاب می‌کند؛ مبلغ و مدت در زمان خرید snapshot می‌شود؛ و placement فقط در صورت فعال‌بودن campaign، معتبر بودن target و قرار داشتن زمان فعلی در بازه کمپین در دسترس است.

### قابلیت‌های فعلی در معماری

- **Pet Boost:** مسیر جدید Pet Boost به Promotion Engine متصل است و برای PET planهای مدت‌دار طراحی شده؛ رکوردهای legacy صرفاً fallback سازگاری‌اند و منبع حقیقت خریدهای جدید نیستند.
- **Product Boost:** فروشنده می‌تواند محصول واجد شرایط و دارای stock مثبت را promote کند. discovery فعلی به محدوده Product فعلی متصل است، نه همه سطوح جست‌وجو.
- **Service Boost:** سرویس‌های Vet و Groomer/Groomy با هویت canonical سرویس قابل promotion هستند. شرایط عمومی کسب‌وکار، انتشار، فعال‌بودن و eligibility سرویس همچنان برقرار است.
- **Featured Deal:** سرویس‌های promoted واجد شرایط می‌توانند علاوه بر placement سرویس، در inventory محدود Featured Deal صفحه خانه قرار گیرند. این inventory توسط rotation و سقف تعداد مدیریت می‌شود.

### مواردی که در V1 محصول درآمدزا نیستند

Business Boost، promotion سرویس‌های Pet Hotel و Pet Taxi، auction/bidding، CPC، CPA، dynamic pricing و campaign budget در V1 فعال نیستند. `featured`های editorial یا domain-specific نیز خودبه‌خود معادل تبلیغ پولی محسوب نمی‌شوند.

## ۴. چه کسی پرداخت می‌کند؟

پرداخت‌کننده، مالک یا operator مجاز target است:

- کلینیک‌ها و ارائه‌دهندگان خدمات دامپزشکی؛
- Groomerها و کسب‌وکارهای grooming؛
- فروشندگان Pet Shop برای Productهای واجد شرایط؛
- مالکان Pet برای Pet Boost؛
- در آینده، در صورت ایجاد target و سطح discovery معتبر، Pet Hotel و Pet Taxi؛
- Businessهای عمومی فقط در صورت فعال‌شدن صریح Business plan و policy مربوطه؛ در وضعیت فعلی چنین محصول فعالی وجود ندارد.

در مسیر فعلی، payment proof از سوی provider باید با campaign، مبلغ مورد انتظار، currency و هویت تراکنش منطبق باشد. redirect موفق به‌تنهایی خرید یا activation محسوب نمی‌شود.

## ۵. برای چه چیزی پول می‌دهند؟

مشتری برای **visibility پولی و زمان‌محدود** پرداخت می‌کند، از جمله:

- lift محدود در discovery ranking؛
- placement اسپانسرشده برای Product یا Service؛
- حضور واجد شرایط در Featured Deal؛
- افزایش شانس دیده‌شدن در نقطه‌ای که کاربر intent خدماتی یا خرید دارد؛
- یک بازه مشخص ۲۴ساعته، ۳روزه یا ۷روزه.

این خرید، خریدِ exposure است؛ تضمین booking، فروش، کیفیت، رضایت کاربر یا ROI نیست. فرایندهای publication، availability، moderation و booking مستقل باقی می‌مانند.

## ۶. جریان درآمد

جریان تجاری فعلی چنین است:

```text
Merchant / Pet Owner
        ↓ انتخاب target و promotion plan
Checkout
        ↓ تأیید معتبر توسط payment provider و backend
Promotion Campaign فعال
        ↓ ایجاد active projection در بازه زمانی معتبر
Eligible placement / ranking / Featured Deal
        ↓ ثبت exposure و عملکرد
Expiry / deactivation
```

قیمت از client دریافت نمی‌شود؛ plan فعال از منبع server خوانده می‌شود و campaign مبلغ، currency، مدت و pricing version را snapshot می‌کند. activation و timestampهای شروع و پایان تحت اختیار backend هستند. این طراحی از duplicate checkout، activation بدون پرداخت معتبر و تغییر قیمت تاریخی جلوگیری می‌کند.

نکته مهم برای سرمایه‌گذار: repository مدرکی از درآمد production، تعداد خریداران یا volume پرداختی ارائه نمی‌کند؛ این بخش، طراحی و قابلیت عملیاتی revenue flow است.

## ۷. مدل قیمت‌گذاری

V1 از مدل **FIXED_DURATION** با currency برابر TRY استفاده می‌کند. قیمت‌های پیکربندی‌شده فعلی عبارت‌اند از:

| Target | ۲۴ ساعت | ۳ روز | ۷ روز |
|---|---:|---:|---:|
| Pet | ۲۹ TRY | ۶۹ TRY | ۱۲۹ TRY |
| Product | ۳۹ TRY | ۸۹ TRY | ۱۶۹ TRY |
| Service (Vet/Groomer) | ۴۹ TRY | ۱۱۹ TRY | ۲۱۹ TRY |

این اعداد **قیمت‌های فعلی پیکربندی V1** هستند، نه قیمت قطعی بازار، درآمد محقق‌شده یا forecast. Business planها در repository رزرو شده اما disabled هستند و قیمت فعال ندارند.

در معماری فعلی، مدت، target type، ranking lift محدود، plan version و concurrency cap قابل پیکربندی‌اند. تفاوت‌گذاری بر اساس شهر، تقاضای جغرافیایی، scarcity placement، فصل یا نوع campaign، در حال حاضر مدل فعال قیمت‌گذاری نیست و فرصت آینده محسوب می‌شود.

## ۸. اقتصاد واحد

این revenue stream از نظر ساختاری ویژگی‌های یک محصول نرم‌افزاری با gross margin بالقوه بالا را دارد: delivery به‌صورت projection و ranking انجام می‌شود، fulfillment کمپین به عملیات دستی وابسته نیست، و تکرار خرید پس از expiry ممکن است. هر campaign جدید روی traffic موجود سوار می‌شود و marginal delivery cost آن معمولاً پایین است.

این مزیت بالقوه با دو محدودیت همراه است: inventory تبلیغاتی باید محدود و مرتبط بماند؛ و هزینه‌های payment، support، reconciliation، fraud control و توسعه نباید نادیده گرفته شوند.

در حال حاضر داده کافی برای ارائه عدد معتبر وجود ندارد. repository شامل داده معتبر برای CAC، LTV، GMV، conversion rate، margin percentage، ROI یا درآمد Promotion نیست.

## ۹. کنترل موجودی تبلیغاتی

Promotion Engine برای جلوگیری از اشباع و pay-to-win طراحی شده است:

- Featured Deal به حداکثر ۶ deal در هر خروجی محدود شده و candidate window آن نیز bounded است.
- selection در Featured Deal با rotation زمان‌مند و رتبه‌بندی deterministic بر اساس campaign identity انجام می‌شود تا campaign جدید یا ترتیب الفبایی برای همیشه غالب نباشد.
- فقط campaign فعال، target معتبر، سرویس واجد شرایط و بازه زمانی معتبر اجازه نمایش دارد.
- برای owner و business محدودیت هم‌زمانی در plan تعریف شده و target دارای campaign فعال نمی‌تواند campaign هم‌پوشان جدید بسازد.
- در ranking، organic score پایه باقی می‌ماند و Promotion V1 حداکثر lift برابر ۴۰ دارد؛ وزن‌ها روی هم جمع نمی‌شوند.
- availability، location، publication، moderation و eligibility hard gate هستند و promotion نمی‌تواند target ناموجود یا نامعتبر را resurrect کند.

در برخی سطوح فعلی، saturation policy محصولی برای پنجره‌های بزرگ و pagination سراسری هنوز نهایی نشده است. بنابراین گسترش inventory پولی به directoryهای بزرگ باید پس از ایجاد ranking/projection سمت‌سرور و policy صریح انجام شود.

## ۱۰. تجربه کاربر و اعتماد

کاربر باید بداند visibility پولی با quality یا endorsement یکی نیست. معماری فعلی برای placementهای promoted label عمومی مانند `Promoted` را در projection نگه می‌دارد و editorial featured را از Promotion Engine جدا می‌کند. در تجربه نهایی، این تمایز باید در UI به‌وضوح قابل فهم باشد.

نتیجه ارگانیک حذف نمی‌شود، ranking ارگانیک امتیاز پایه است، و promotion زمان‌محدود است. بنابراین PetSupo می‌تواند درآمد attention را آزمایش کند بدون آن‌که discovery را به فهرستی تبدیل کند که صرفاً بالاترین پرداخت‌کننده در آن دیده می‌شود.

## ۱۱. اندازه‌گیری عملکرد

قابلیت‌های فعلی exposure شامل این موارد است:

- impressions؛
- clicks؛
- detail views؛
- CTR محاسبه‌شده در صورت وجود impression؛
- campaign status، spend snapshot، duration و start/end؛
- دسترسی read-only مالک به performance صفحه کمپین.

برای Product، Vet Service و Groomy Service، attribution مالی server-side در صورت وجود زنجیره معتبر same-flow و reconciliation قابل ارائه است؛ وضعیت آن می‌تواند `AVAILABLE` یا `PROVISIONAL` باشد. Pet عمداً financial revenue و ROAS ندارد و این موارد برای آن N/A هستند. اگر chain معتبر وجود نداشته باشد، سیستم ترجیح می‌دهد under-attribution داشته باشد تا revenue را نادرست به campaign نسبت دهد.

در وضعیت فعلی، time-series روزانه، attribution چندلمسی و نسبت‌دادن مالی عمومی به هر click پیاده‌سازی‌شده و قابل ادعا نیستند.

## ۱۲. چرایی مقیاس‌پذیری

مقیاس‌پذیری مدل از reuse یک engine مرکزی می‌آید: checkout، verification، campaign state، activation، active projection، expiry، ranking policy و analytics برای targetهای مختلف دوباره استفاده می‌شوند. افزودن یک placement جدید، در صورت وجود target و consumer معتبر، لازم نیست کل سیستم پرداخت را از نو بسازد.

همچنین delivery دیجیتال است، به فروش نیروی میدانی نیاز ندارد و می‌تواند با توسعه جغرافیایی marketplace به شهرها و sectors جدید گسترش یابد. شرط این گسترش، ساختن discovery surface معتبر، کنترل inventory و server-side ranking مناسب برای حجم‌های بزرگ است؛ نه صرفاً اضافه‌کردن plan جدید.

## ۱۳. موتور درآمدی چندلایه

اسناد business فعلی Petsupo منابع درآمدی کلی زیر را ثبت می‌کنند: Commission، Subscription، Marketplace و Business Services. Promotion/Boost می‌تواند لایه‌ای مکمل باشد که از attention و intent موجود درآمد می‌گیرد؛ کمیسیون از transaction، اشتراک از access/features، marketplace از commerce و promotion از visibility پولی.

این لایه‌ها الزاماً جایگزین هم نیستند. یک business می‌تواند از discovery پولی استفاده کند و در صورت انجام transaction، جریان کمیسیون یا marketplace نیز جداگانه وجود داشته باشد. سهم واقعی هر لایه هنوز در repository اندازه‌گیری نشده است.

## ۱۴. مزیت رقابتی

مزیت قابل دفاع این مدل از اتصال promotion به first-party marketplace intent می‌آید، نه از صرفِ داشتن یک ad slot:

- هدف promotion یک service یا product واقعی با owner و eligibility قابل بررسی است؛
- placement به surface تخصصی همان sector متصل می‌شود؛
- exposure، click، detail view و در برخی مسیرها transaction معتبر در یک زنجیره قابل اندازه‌گیری قرار می‌گیرند؛
- campaign lifecycle، پرداخت و expiry توسط یک authority مرکزی کنترل می‌شود؛
- PetSupo می‌تواند هم‌زمان برای کاربر B2C و business B2B ارزش ایجاد کند.

این مزیت فعلاً یک قابلیت معماری و محصولی است، نه ادعای market leadership یا اثبات برتری در بازار.

## ۱۵. مسیر توسعه درآمد

### Current — پیاده‌سازی‌شده در repository / آماده rollout کنترل‌شده

- Fixed-duration plans برای PET، PRODUCT و SERVICE؛
- Pet Boost جدید با activation پس از payment verification؛
- Product Boost در سطح Product؛
- Service Boost برای Vet و Groomer/Groomy؛
- Featured Deal محدود برای service projectionهای واجد شرایط؛
- bounded ranking lift، expiry، projection و owner performance read؛
- exposure analytics و attribution مالی محدود و مشروط برای targetهای پشتیبانی‌شده.

این موارد در repository پیاده‌سازی محلی دارند. سند rollout فعلی production را `PREPARED LOCALLY; PRODUCTION NO-GO` می‌داند؛ پس «Current» به معنی موجود در کد محلی است، نه درآمد فعال production.

### Near-term — فرصت‌های واقع‌بینانه و وابسته به تأیید محصول/عملیات

- campaign history/list و گزارش‌های کامل‌تر برای owner؛
- daily aggregates و chart پس از تأمین time-series معتبر؛
- تکمیل controlled rollout، provider configuration و عملیات reconciliation؛
- inventory یا discovery معتبر برای Pet Hotel؛
- تعریف target قابل promotion برای Pet Taxi؛
- سیاست روشن business/seller saturation و server-side ranking برای pagination بزرگ.

### Longer-term — فرصت‌های آینده، نه قابلیت فعلی

- geographic یا category-aware pricing؛
- premium inventory و seasonal campaigns؛
- self-service promotion dashboard؛
- budget-based campaigns و CPC/CPA پس از جمع‌آوری داده و policy معتبر؛
- campaign recommendations و آزمایش A/B؛
- bid/auction فقط با رعایت relevance، quality، diversity و trust، نه بالاترین bid به‌تنهایی.

## ۱۶. ریسک‌ها و کنترل‌ها

| ریسک | کنترل یا وضعیت فعلی |
|---|---|
| تجاری‌شدن بیش‌ازحد و افت trust | organic base، lift محدود، زمان‌مندی و جداسازی editorial/promotion |
| merchant کم‌کیفیت | eligibility، publication، moderation و availability gate؛ promotion کیفیت را تضمین نمی‌کند |
| fraud یا activation جعلی | payment verification سمت‌سرور، amount/currency/order matching و backend-owned activation |
| dispute، refund و reconciliation | وضعیت‌های bounded و attribution محافظه‌کارانه؛ rollout عملیاتی هنوز gate دارد |
| تبلیغ نامرتبط | target/sector identity، placement policy و hard candidate constraints |
| اشباع inventory | Featured Deal سقف‌دار، rotation و candidate window محدود |
| سلطه دائمی یک payer | expiry، concurrency cap، no stacking و rotation؛ saturation سراسری هنوز نیازمند policy است |
| disclosure تبلیغ | projection دارای public label است؛ متن و طراحی نهایی disclosure باید در محصول تثبیت شود |
| ادعاهای مالی نادرست | Pet revenue عمداً unavailable؛ ROAS فقط با financial truth کافی نمایش داده می‌شود |

## ۱۷. KPIهای پیشنهادی برای سرمایه‌گذار

KPIهای زیر باید به تفکیک target type، sector، city، placement و plan version پایش شوند؛ هیچ‌یک در این سند مقدار واقعی ندارد:

- تعداد promotion buyer و active promoted business؛
- نرخ خرید مجدد پس از expiry و campaign renewal rate؛
- revenue Promotion و سهم آن از کل revenue؛
- campaign fill rate و paid impression share؛
- impressions، CTR و detail-view rate؛
- booking/order conversion فقط در صورت attribution معتبر؛
- revenue per promoted business و spend per campaign؛
- net attributed revenue و ROAS فقط برای کمپین‌های `AVAILABLE`؛
- نسبت engagement ارگانیک به sponsored؛
- نرخ refund، reconciliation failure و campaignهای بدون activation؛
- inventory utilization، Featured Deal rotation fairness و organic ranking health.

## ۱۸. چرا این مدل برای PetSupo مهم است؟

Promotion Engine توجه marketplace را به inventory قابل‌فروش تبدیل می‌کند، اما نقش PetSupo را به‌عنوان intermediary حفظ می‌کند. کسب‌وکار برای دسترسی بهتر به تقاضای موجود هزینه می‌پردازد؛ کاربر همچنان به relevance، availability و انتخاب ارگانیک دسترسی دارد؛ و PetSupo از همان شبکه discovery، یک جریان درآمدی نرم‌افزاری و بالقوه تکرارشونده ایجاد می‌کند.

ارزش سرمایه‌گذاری این مدل در ترکیب سه عامل است: intent نزدیک به transaction، delivery کم‌هزینه و کنترل‌پذیری campaign. اعتبار این thesis باید با rollout کنترل‌شده، داده واقعی خرید و exposure، retention خریداران و سلامت organic discovery سنجیده شود—نه با فرض‌کردن این نتایج پیش از اندازه‌گیری.

## پیوست: شواهد اجرایی

ممیزی repository و مستندات Promotion نشان می‌دهد:

- checkout و payment verification server-authoritative هستند؛ client price و redirect موفق منبع activation نیستند؛
- campaign پس از تأیید پرداخت به‌صورت atomic با `promotion_active` projection فعال می‌شود؛
- شروع و پایان campaign توسط server تعیین می‌شود و eligibility در بازه `startsAt <= now < expiresAt` کنترل می‌شود؛
- ranking از projection نرمال‌شده و bounded lift استفاده می‌کند و weightها stack نمی‌شوند؛
- Featured Deal سرویس‌های Vet/Groomer سقف ۶ مورد، candidate window محدود و rotation زمان‌مند دارد؛
- analytics رویدادهای impression، click و detail view را پوشش می‌دهد؛
- owner performance view به‌صورت read-only در دسترس است و financial metrics را فقط با status مناسب نمایش می‌دهد؛
- attribution مالی Product/Vet/Groomy به same-flow و reconciliation معتبر محدود است و Pet مالی نیست؛
- Business، Hotel و Taxi در controlled rollout فعلی فعال نیستند و rollout production هنوز No-Go است.

