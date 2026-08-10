# 🚚 تطبيق بنوصل (We Deliver) 

[![Flutter](https://img.shields.io/badge/Flutter-3.44.0-blue.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12.0-blue.svg?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS-lightgrey.svg)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Clean%20Architecture-green.svg)](#)

تطبيق **بنوصل** هو تطبيق ذكي للهواتف المحمولة مبني باستخدام إطار العمل **Flutter** لتسهيل عمليات شحن وتوصيل الطرود والطلبات. يدعم التطبيق واجهتين أساسيتين: **العميل/التاجر** (لطلب وتتبع الشحنات) و**المندوب/الكابتن** (لقبول الشحنات وتوصيلها)، مع تتبع حي ومباشر للموقع عبر الخرائط وربط شبكي لحظي.

---

## 🌟 الميزات الرئيسية (Core Features)

* **👥 نظام حسابات مزدوج (Dual User Roles):**
  * **التاجر / العميل:** لإنشاء الشحنات وتحديد نقاط الاستلام والتسليم وتتبع المسار.
  * **المندوب / الكابتن:** لاستعراض الطلبات المتاحة، إضافتها إلى رحلاته، وتحديث حالة الطلب.
* **📍 التتبع اللحظي للشحنات (Real-Time GPS Tracking):**
  * عرض حي لموقع الكابتن وحركة المركبة على الخرائط أثناء التوصيل.
  * تكامل كامل مع **خرائط جوجل (Google Maps)** وحساب المسارات وأفضل الطرق للوصول.
* **💬 الربط اللحظي والمحادثات (Socket.io & Chat):**
  * تحديث حالات الطلبات بشكل فوري وسريع باستخدام الـ **Websockets (Socket.io)**.
  * نظام محادثة مدمج للتواصل مع الدعم الفني أو بين الأطراف.
* **🔔 الإشعارات الفورية (Push Notifications):**
  * استقبال إشعارات لحظية عبر **Firebase Cloud Messaging (FCM)** عند تحديث حالة الطلب.
  * تنبيهات محلية تفاعلية باستخدام **flutter_local_notifications**.
* **💳 المحفظة الرقمية والدفع (Digital Wallet & Payment):**
  * إدارة الرصيد والمدفوعات داخل التطبيق مع دعم بوابات الدفع الإلكتروني عبر واجهة WebView مدمجة.
* **🌐 دعم تعدد اللغات (Localization):**
  * واجهة كاملة باللغتين العربية والإنجليزية مدعومة بـ **easy_localization**.

---

## 🛠️ هيكلية المشروع والملفات (Folder Directory Structure)

يتبع المشروع معايير **البنية النظيفة (Clean Architecture)** مقسمة حسب **الميزات (Feature-First Structure)** لضمان مرونة الكود وسهولة صيانته وفصله عن منطق العمليات.

```text
lib/
│
├── core/                           # الملفات المشتركة والأساسية للتطبيق بالكامل
│   ├── api/                        # نقاط الاتصال بالخادم وإعدادات الـ HTTP Client (Dio)
│   ├── cache/                      # إدارة الكاش والتخزين المحلي المساعد (Preferences)
│   ├── components/                 # العناصر المرئية الثابتة والمشتركة للتصميم
│   ├── config/                     # إعدادات التطبيق العامة والروابط البرمجية الأساسية
│   ├── di/                         # نظام حقن الاعتماديات (Dependency Injection - GetIt)
│   ├── errors/                     # معالجة الأخطاء والاستثناءات البرمجية
│   ├── localization/               # لغات التطبيق وإعدادات الترجمة
│   ├── network/                    # التحقق من حالة الاتصال بالإنترنت
│   ├── notifications/              # إعدادات الإشعارات (Firebase FCM & Local Notifications)
│   ├── routes/                     # نظام التنقل والمسارات داخل التطبيق (App Router)
│   ├── services/                   # الخدمات البرمجية المساعدة والنظام
│   ├── theme/                      # الألوان والخطوط والأشكال للتصميم العام (AppTheme)
│   ├── tracking/                   # خدمات تتبع الموقع الحي
│   ├── usecases/                   # الفئات الأساسية للـ Use Cases
│   ├── utils/                      # الدوال والمثبتات المساعدة (Validators, Constants)
│   └── widgets/                    # الـ Widgets العامة المكررة في التطبيق
│
├── features/                       # الفيتشرز أو الوحدات الوظيفية للتطبيق
│   ├── auth/                       # نظام التسجيل، تسجيل الدخول وتوثيق الهوية
│   ├── onboarding/                 # شاشات التعريف والترحيب بالتطبيق
│   ├── splash/                     # شاشة البداية والتحقق من حالة المستخدم
│   ├── home/                       # الشاشة الرئيسية وعرض الإحصائيات أو الشحنات
│   ├── main_layout/                # التخطيط العام وشريط التنقل السفلي (Bottom Navigation)
│   ├── shipment/                   # إدارة الشحنات وتتبع الكابتن المباشر على الخريطة
│   ├── trips/                      # إدارة الرحلات وحالات الطرق للمندوبين
│   ├── order/                      # نظام الطلبات والعمليات المرتبطة بها
│   ├── wallet/                     # المحفظة والعمليات المالية والدفع الإلكتروني
│   └── profile/                    # الملف الشخصي وإعدادات المستخدم وعناوين الشحن
│
├── firebase_options.dart           # خيارات وإعدادات الفايربيس المولدة تلقائياً
└── main.dart                       # نقطة انطلاق التطبيق وإعداد الإطارات الأساسية
```

---

## 🏗️ تقسيم الميزات (Feature Layers Anatomy)

كل ميزة (Feature) داخل مجلد `features/` تنقسم داخلياً إلى أربعة طبقات أساسية لضمان فصل المهام (Separation of Concerns):

1. **`domain` (طبقة منطق العمل المستقل):**
   * **Entities:** الكائنات الأساسية للبيانات.
   * **Repositories:** العقود أو الـ Interfaces التي تحدد ما يمكن للبيانات فعله (دون تحديد طريقة جلبها).
   * **Use Cases:** العمليات الفردية التي يمكن للمستخدم القيام بها (مثل `CreateShipmentUseCase`).
2. **`data` (طبقة جلب البيانات):**
   * **Models:** كائنات البيانات التي تتعامل مع الـ JSON والتحويل.
   * **Data Sources:** مصدر جلب البيانات الفعلي سواء من الـ API (Remote) أو التخزين المحلي (Local).
   * **Repositories Implementations:** التطبيق الفعلي للعقود الموجودة في الـ Domain وتوجيه جلب البيانات.
3. **`logic` (طبقة إدارة الحالة - State Management):**
   * الـ **Cubits / Blocs** التي تتحكم في منطق الواجهات وعلاقة طلب البيانات بالـ UI.
4. **`presentation` (طبقة واجهة المستخدم - UI):**
   * **Pages / Screens:** الشاشات الكاملة.
   * **Widgets:** الأجزاء الصغيرة المكونة لكل شاشة لتسهيل القراءة وتجنب تكرار الكود.

---

## 🚀 التقنيات المستخدمة (Tech Stack)

* **State Management:** `flutter_bloc` / `bloc`
* **Dependency Injection:** `get_it`
* **Network & API:** `dio` & `socket_io_client`
* **Local Storage:** `shared_preferences` & `flutter_secure_storage`
* **Maps & Geo:** `google_maps_flutter` & `geolocator` & `flutter_polyline_points`
* **Notifications:** `firebase_core`, `firebase_messaging` & `flutter_local_notifications`
* **Localization:** `easy_localization`
* **UI Utilities:** `flutter_screenutil` (للتجاوب مع مقاسات الشاشات المختلفة) & `cached_network_image`

---

## ⚙️ البدء والتشغيل للمطورين (Setup Instructions)

### 📋 المتطلبات الأساسية
* مثبت Flutter SDK إصدار **3.44.0** أو أعلى.
* مثبت Dart SDK إصدار **3.12.0** أو أعلى.
* حساب مطور لدى آبل وجوجل لإعداد المفاتيح (مفاتيح الخرائط مدمجة ومهيأة بالفعل).

### 🛠️ خطوات التشغيل

1. **تحميل التبعيات والـ Packages:**
   ```bash
   flutter pub get
   ```

2. **تهيئة بيئة التشغيل للـ iOS (نظام macOS):**
   ملف الـ `Podfile` مهيأ مسبقاً لاستبعاد الصلاحيات التي لا يحتاجها التطبيق تلقائياً لمنع رفض متجر التطبيقات. لتثبيت المكتبات:
   ```bash
   cd ios
   pod install
   cd ..
   ```

3. **تشغيل التطبيق في وضع التطوير:**
   ```bash
   flutter run
   ```

4. **بناء النسخة النهائية للرفع (Production Release):**
   * **أندرويد (Android App Bundle):**
     ```bash
     flutter build appbundle
     ```
   * **آيفون (iOS IPA):**
     ```bash
     flutter build ipa
     ```
