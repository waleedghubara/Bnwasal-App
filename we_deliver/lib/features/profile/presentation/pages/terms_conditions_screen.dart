// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermSection {
  final String number;
  final String title;
  final String content;

  const _TermSection({
    required this.number,
    required this.title,
    required this.content,
  });
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_TermSection> _sections = const [
    _TermSection(
      number: '١',
      title: 'التعريفات',
      content:
          '• بنوصل: تشير إلى المنصة الإلكترونية التي تربط بين المندوبين والتجار والعملاء لتقديم خدمات الشحن والتوصيل.\n'
          '• المستخدم: أي شخص يستخدم المنصة، سواء كان مندوبًا، تاجرًا، أو عميلًا نهائيًا.\n'
          '• المندوب: الشخص المسؤول عن استلام الطلبات من التجار وتسليمها للعملاء النهائيين.\n'
          '• التاجر: الفرد أو الجهة التي تبيع المنتجات عبر المنصة وتختار المندوب المناسب لتوصيلها.\n'
          '• العميل النهائي: المستلم الأخير للطلب بعد إتمام عملية التوصيل.',
    ),
    _TermSection(
      number: '٢',
      title: 'الموافقة على الشروط',
      content:
          'يشكل هذا المستند اتفاقًا قانونيًا ملزمًا بين المستخدم ومنصة "بنوصل". ويُعد استخدام الخدمات على المنصة قبولًا كاملاً وغير مشروط لهذه الشروط.\n\n'
          'تحتفظ "بنوصل" بحق تعديل هذه الشروط في أي وقت، ويقع على عاتق المستخدم مراجعتها بانتظام. يُعد استمرار استخدام المنصة بعد إجراء أي تعديلات موافقة ضمنية على تلك التغييرات.',
    ),
    _TermSection(
      number: '٣',
      title: 'أهلية استخدام المنصة',
      content:
          'لاستخدام المنصة، يجب على المستخدم استيفاء الشروط التالية:\n'
          '• ألّا يكون منافسًا لمنصة بنوصل أو يعمل لدى خدمة مشابهة.\n'
          '• ألّا يكون لديه سجل جنائي أو مشكلات قانونية تمنعه من ممارسة الأعمال أو خدمات التوصيل.\n'
          '• تقديم معلومات دقيقة ومحدثة عند التسجيل، بما في ذلك بيانات الهوية الرسمية.\n'
          '• الالتزام بالقوانين واللوائح المعمول بها في جمهورية مصر العربية.',
    ),
    _TermSection(
      number: '٤',
      title: 'التزامات وسلوك المستخدم',
      content:
          'يقر المستخدم بالتالي:\n'
          '• استخدام المنصة لأغراض قانونية فقط، والامتناع عن أي أنشطة غير مشروعة.\n'
          '• الالتزام بكافة قوانين الشحن والتجارة الإلكترونية المعمول بها.\n'
          '• الحفاظ على سرية بيانات الحساب وعدم مشاركتها مع أي طرف ثالث.\n'
          '• الامتناع عن مضايقة أو إزعاج المستخدمين الآخرين أو إساءة استخدام الخدمة.\n'
          '• عدم محاولة التلاعب أو الإضرار بالمنصة أو أنظمتها بأي شكل.\n'
          '• التعاون مع المنصة في إجراءات التحقق من الهوية أو الالتزام بالسياسات الأمنية.',
    ),
    _TermSection(
      number: '٥',
      title: 'الترخيص واستخدام المنصة',
      content:
          'تمنح "بنوصل" المستخدم ترخيصًا محدودًا، غير حصري، وغير قابل للتحويل لاستخدام خدماتها وفقًا لهذه الشروط. لا يجوز للمستخدم بأي حال من الأحوال:\n'
          '• إعادة بيع أو تأجير الخدمات أو منحها للغير.\n'
          '• تعديل أو توزيع أو استغلال محتوى المنصة دون إذن.\n'
          '• السماح للآخرين باستخدام حسابه أو مشاركته.\n'
          '• استخدام برمجيات أو أدوات تقنية للتأثير على تشغيل المنصة أو التدخل بها.',
    ),
    _TermSection(
      number: '٦',
      title: 'سياسة الشحن والمواد المحظورة',
      content:
          'يُحظر على المستخدمين شحن أو استلام أو نقل المواد التالية:\n'
          '• المخدرات أو المنتجات غير القانونية.\n'
          '• الأسلحة والذخائر بكافة أنواعها.\n'
          '• المواد القابلة للاشتعال أو المتفجرات.\n'
          '• العملات المزيفة أو المستندات المزورة.\n'
          '• الحيوانات الحية، الأطعمة الفاسدة، أو أي منتجات غير مطابقة للمعايير الصحية.\n\n'
          'يحق للمندوب فحص الشحنات وقد يرفض توصيلها إذا اشتبه في مخالفتها للسياسات. كما يحق للمنصة اتخاذ إجراءات قانونية وإبلاغ السلطات المختصة.',
    ),
    _TermSection(
      number: '٧',
      title: 'انتهاك سياسة الشحن',
      content:
          'في حال انتهاك سياسة الشحن، يحق لمنصة "بنوصل":\n'
          '• تعليق أو حظر الحساب المخالف نهائيًا.\n'
          '• تحميل المستخدم المسؤولية القانونية الكاملة.\n'
          '• التعاون مع الجهات القانونية في حال وجود انتهاكات جسيمة.',
    ),
    _TermSection(
      number: '٨',
      title: 'سياسة الدفع والتسعير',
      content:
          '• يتحمل المندوب المسؤولية المالية الكاملة عن المنتجات المنقولة، ويجب عليه دفع قيمتها نقدًا عند الاستلام من التاجر.\n'
          '• يتم تحديد رسوم التوصيل عبر التفاوض بين المندوب والتاجر.\n'
          '• يجب أن يتم الدفع داخل مقر التاجر؛ لا يُسمح بأماكن دفع غير رسمية.\n'
          '• في حال حدوث احتيال مالي أو تلاعب، تحتفظ المنصة بحق حظر الحسابات المخالفة نهائيًا وإبلاغ السلطات المختصة.',
    ),
    _TermSection(
      number: '٩',
      title: 'مكافحة الاحتيال وسلامة المعاملات',
      content:
          '• يجب على التاجر تحديد قيمة المنتج بدقة داخل التطبيق؛ ويحظر تضخيم الأسعار.\n'
          '• إذا ثبت أن التاجر قدم طلبًا وهميًا بهدف الاحتيال، يتم حظر حسابه وإحالته للجهات المختصة.\n'
          '• يحق للمندوب فحص الشحنات ورفضها إذا لم تتطابق مع المتفق عليه من حيث القيمة أو المحتوى.',
    ),
    _TermSection(
      number: '١٠',
      title: 'سياسة إلغاء الطلبات',
      content:
          '• قبل تأكيد الطلب: لا تُفرض أي رسوم.\n'
          '• بعد تأكيد الطلب:\n'
          '  - يمكن لأي من الطرفين طلب الإلغاء مع سبب واضح.\n'
          '  - تراجع خدمة العملاء السبب وتقرر ما إذا كان يخصم من أحد الطرفين أو يتم رد المبلغ بالكامل.\n'
          '  - تُمنح الحماية للطرف المتضرر إذا ثبت سوء نية من الطرف الآخر.',
    ),
    _TermSection(
      number: '١١',
      title: 'سياسة المرتجعات',
      content:
          'إذا رفض العميل النهائي استلام الطلب، يجب على التاجر:\n'
          '• رد المبلغ الذي دفعه المندوب، شاملاً تكلفة الشحن.\n'
          '• إذا كانت تكلفة الشحن مدفوعة مسبقًا، يتم رد قيمة المنتج فقط دون تكلفة الشحن.\n'
          '• في حال تكرار الرفض غير المبرر، قد تفرض المنصة رسومًا إدارية أو حظرًا للحساب.',
    ),
    _TermSection(
      number: '١٢',
      title: 'آلية الخصم المؤقت – المحفظة الإلكترونية',
      content:
          '• عند الاتفاق بين التاجر والمندوب، يتم خصم نصف رسوم الشحن مؤقتًا من محفظة كل طرف.\n'
          '• يُجمَّد المبلغ ولا يُخصم فعليًا حتى استلام المندوب للطلب.\n'
          '• عند الاستلام، يُعاد المبلغ للطرفين مع خصم عمولة المنصة فقط.\n'
          '• في حال الإلغاء أو الاحتيال، تُتخذ قرارات الاسترداد بواسطة خدمة العملاء.',
    ),
    _TermSection(
      number: '١٣',
      title: 'رسوم المنصة (عمولة بنوصل)',
      content:
          '• تحتفظ "بنوصل" بنسبة ثابتة حاليًا قدرها 10% من رسوم الشحن والتوصيل لكل عملية ناجحة.\n'
          '• تُخصم هذه النسبة تلقائيًا من المحفظة الإلكترونية للطرف المعني بعد إتمام الخدمة.\n'
          '• يحق للمنصة تعديل نسبة العمولة في أي وقت دون إشعار مسبق، ويُعد الاستمرار في الاستخدام موافقة ضمنية.\n'
          '• يتم عرض النسبة الحالية دائمًا داخل التطبيق في صفحة الشروط أو مركز المساعدة.',
    ),
    _TermSection(
      number: '١٤',
      title: 'المسؤولية والتعويض',
      content:
          '• يوافق المستخدم على تعويض المنصة عن أي مطالبات قانونية ناجمة عن إساءة الاستخدام.\n'
          '• "بنوصل" غير مسؤولة عن النزاعات بين المستخدمين، مثل التأخير أو فقدان المنتجات؛ المسؤولية تقع على المندوب والتاجر.\n'
          '• لا تتحمل المنصة أي مسؤولية عن المعاملات التي تتم خارج التطبيق.',
    ),
    _TermSection(
      number: '١٥',
      title: 'تعديلات الخدمة',
      content:
          'تحتفظ "بنوصل" بحقها في:\n'
          '• تحديث أو تعديل الخدمات في أي وقت حسب تقديرها.\n'
          '• تعليق أو إيقاف بعض الميزات دون إشعار مسبق.',
    ),
    _TermSection(
      number: '١٦',
      title: 'أمان وخصوصية الحساب',
      content:
          '• يتحمل المستخدم المسؤولية الكاملة عن حماية بيانات حسابه.\n'
          '• في حال الاشتباه باستخدام غير مصرح به، يجب إبلاغ المنصة فورًا.\n'
          '• يحق للمنصة طلب مستندات إضافية للتحقق وضمان الأمان.',
    ),
    _TermSection(
      number: '١٧',
      title: 'إنهاء الحساب',
      content:
          '• يمكن للمستخدم حذف التطبيق وإنهاء حسابه في أي وقت.\n'
          '• تحتفظ المنصة بحق تعليق أو إنهاء الحسابات التي تنتهك الشروط دون إشعار مسبق.',
    ),
    _TermSection(
      number: '١٨',
      title: 'القانون وحل النزاعات',
      content:
          '• تخضع هذه الاتفاقية للقانون المصري.\n'
          '• يتم حل النزاعات عبر الجهات المختصة.\n'
          '• في حال تعذر الحل الودي، يكون للمحاكم المصرية الاختصاص القضائي.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredSections = _sections.where((section) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return section.title.toLowerCase().contains(query) ||
          section.content.toLowerCase().contains(query);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'الشروط والأحكام',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20.sp),
            onPressed: () => Navigator.pop(context),
          ),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Beautiful Header Card with Search
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF204CB3).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.gavel_rounded,
                      size: 40.sp,
                      color: const Color(0xFF204CB3),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'شروط وأحكام استخدام منصة بنوصل',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF204CB3),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'يرجى قراءة الشروط والأحكام بعناية قبل استخدام التطبيق.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: const Color(0xFF888888),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      style: TextStyle(fontSize: 14.sp),
                      decoration: InputDecoration(
                        hintText: 'البحث في الشروط والأحكام...',
                        hintStyle: TextStyle(
                          color: const Color(0xFFBDBDBD),
                          fontSize: 13.sp,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: const Color(0xFF9E9E9E),
                          size: 20.sp,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: const Color(0xFF9E9E9E),
                                  size: 18.sp,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 16.w,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            // Terms List
            Expanded(
              child: filteredSections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 60.sp,
                            color: const Color(0xFFBDBDBD),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'لم يتم العثور على نتائج للبحث',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFF888888),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 8.h,
                      ),
                      itemCount: filteredSections.length,
                      itemBuilder: (context, index) {
                        final section = filteredSections[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 12.h),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.01),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.white,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                iconColor: const Color(0xFF204CB3),
                                collapsedIconColor: const Color(0xFF9E9E9E),
                                title: Row(
                                  children: [
                                    Container(
                                      width: 28.w,
                                      height: 28.w,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF204CB3,
                                        ).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Center(
                                        child: Text(
                                          section.number,
                                          style: TextStyle(
                                            color: const Color(0xFF204CB3),
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        section.title,
                                        style: TextStyle(
                                          color: const Color(0xFF333333),
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20.w,
                                      0,
                                      20.w,
                                      16.h,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        section.content,
                                        style: TextStyle(
                                          color: const Color(0xFF666666),
                                          fontSize: 13.sp,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
