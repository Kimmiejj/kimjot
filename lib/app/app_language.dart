import 'package:flutter/material.dart';

enum AppLanguage {
  th(Locale('th'), 'ไทย'),
  en(Locale('en'), 'English');

  const AppLanguage(this.locale, this.label);

  final Locale locale;
  final String label;
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({AppLanguage initialLanguage = AppLanguage.en})
    : _language = initialLanguage;

  AppLanguage _language;

  AppLanguage get language => _language;

  Locale get locale => _language.locale;

  AppStrings get strings => AppStrings(_language);

  void setLanguage(AppLanguage language) {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    required AppLanguageController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static final AppLanguageController _fallbackController =
      AppLanguageController();

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    return scope?.notifier ?? _fallbackController;
  }

  static AppStrings stringsOf(BuildContext context) {
    return controllerOf(context).strings;
  }
}

extension AppLanguageContext on BuildContext {
  AppLanguageController get languageController =>
      AppLanguageScope.controllerOf(this);

  AppStrings get strings => AppLanguageScope.stringsOf(this);
}

class AppStrings {
  const AppStrings(this.currentLanguage);

  final AppLanguage currentLanguage;

  bool get isThai => currentLanguage == AppLanguage.th;

  String get startingKimjod =>
      isThai ? 'กำลังเริ่ม kimjod...' : 'Starting kimjod...';
  String get checkingSignIn =>
      isThai ? 'กำลังตรวจสอบการเข้าสู่ระบบ...' : 'Checking sign in...';

  String get loginHeadline =>
      isThai ? 'จัดเงินให้ชัด\nทุกวัน' : 'Keep money clear\nevery day';
  String get loginSubtitle => isThai
      ? 'บันทึกรายรับ รายจ่าย นำเข้าสลิป และรายการผ่อน โดยไม่ต้องอัปโหลดรูปสลิป'
      : 'Track income, expenses, slip imports, and installments without uploading slip images.';
  String get continueWithGoogle =>
      isThai ? 'เข้าสู่ระบบด้วย Google' : 'Continue with Google';
  String get signingIn => isThai ? 'กำลังเข้าสู่ระบบ...' : 'Signing in...';
  String get onDevice => isThai ? 'บนเครื่อง' : 'On-device';
  String get storage => isThai ? 'ที่เก็บรูป' : 'Storage';
  String get noSlipImage => isThai ? 'ไม่เก็บรูปสลิป' : 'No slip image';
  String get privacyNote => isThai
      ? 'รูปภาพใช้เพื่ออ่านข้อมูลเท่านั้น และไม่ถูกบันทึกลง Firebase Storage'
      : 'Images are used only for reading data. Slip images are not saved to Firebase Storage.';
  String get googleSignInFailed =>
      isThai ? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ' : 'Google sign in failed.';
  String get googleSetupFailed => isThai
      ? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาตรวจการตั้งค่า Firebase'
      : 'Google sign in failed. Check Firebase setup.';
  String get missingGoogleClientId => isThai
      ? 'ยังไม่มี Google Web client ID ให้เปิด Google sign-in ใน Firebase แล้วรันด้วย --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com'
      : 'Missing Google Web client ID. Enable Google sign-in in Firebase, then run with --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com';
  String get androidOauthFailed => isThai
      ? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาตรวจ Android OAuth ใน Firebase'
      : 'Google sign in failed. Check Android OAuth setup in Firebase.';

  String get transactionSaved =>
      isThai ? 'บันทึกรายการแล้ว' : 'Transaction saved.';
  String hello(String name) => isThai ? 'สวัสดี, $name' : 'Hello, $name';
  String get synced => isThai ? 'ซิงก์แล้ว' : 'SYNCED';
  String get thisMonth => isThai ? 'เดือนนี้' : 'This month';
  String get settings => isThai ? 'ตั้งค่า' : 'Settings';
  String get monthlyBalance =>
      isThai ? 'ยอดคงเหลือเดือนนี้' : 'Monthly balance';
  String get income => isThai ? 'รายรับ' : 'Income';
  String get expense => isThai ? 'รายจ่าย' : 'Expense';
  String get add => isThai ? 'เพิ่ม' : 'Add';
  String get scan => isThai ? 'สลิป' : 'Slip';
  String get scanSlip => isThai ? 'สลิป\nแกลเลอรี' : 'Slip\nGallery';
  String get graph => isThai ? 'กราฟ' : 'Graph';
  String get home => isThai ? 'หน้าแรก' : 'Home';
  String get budget => isThai ? 'งบประมาณ' : 'Budget';
  String get noBudget =>
      isThai ? 'ยังไม่ได้ตั้งงบประมาณ' : 'No budget has been created yet.';
  String get installments => isThai ? 'รายการผ่อน' : 'Installments';
  String get noDueInstallment =>
      isThai ? 'ยังไม่มีงวดที่ต้องจ่าย' : 'No due installment';
  String get installmentHint => isThai
      ? 'รายการผ่อนจะแสดงที่นี่หลังจากตั้งค่า'
      : 'Installment items will appear here after setup.';
  String get recentTransactions =>
      isThai ? 'รายการล่าสุด' : 'Recent transactions';
  String get noTransactionsYet =>
      isThai ? 'ยังไม่มีรายการ' : 'No transactions yet';
  String get savedTransactionsHint => isThai
      ? 'รายการที่บันทึกจะแสดงที่นี่'
      : 'Saved transactions will appear here.';
  String get seeMore => isThai ? 'ดูทั้งหมด' : 'See more';
  String get history => isThai ? 'ประวัติ' : 'History';
  String get allTransactions => isThai ? 'รายการทั้งหมด' : 'All transactions';
  String get searchPlaceholder =>
      isThai ? 'ค้นหา / เดือน / หมวดหมู่' : 'Search / month / category';
  String get noSavedTransactions =>
      isThai ? 'ยังไม่มีรายการที่บันทึก' : 'No saved transactions yet';

  String get addTransaction => isThai ? 'เพิ่มรายการ' : 'Add transaction';
  String get addTransactionTip => isThai
      ? 'ใส่จำนวนเงิน เลือกประเภท แล้ว kimjod จะจัดรายการให้อย่างเป็นระเบียบ'
      : 'Add an amount, choose a type, and kimjod will keep the list tidy.';
  String get amount => isThai ? 'จำนวนเงิน' : 'Amount';
  String get amountPrefix => isThai ? '฿' : 'THB ';
  String get amountValidation =>
      isThai ? 'กรอกจำนวนเงินมากกว่า 0' : 'Enter an amount greater than 0';
  String get date => isThai ? 'วันที่' : 'Date';
  String get note => isThai ? 'โน้ต' : 'Note';
  String get noteHint => isThai ? 'อาหารกลางวัน' : 'Lunch';
  String get details => isThai ? 'รายละเอียดเพิ่มเติม' : 'More details';
  String get detailsHint =>
      isThai ? 'ร้าน / source / merchant' : 'Shop / source / merchant';
  String get category => isThai ? 'หมวดหมู่' : 'Category';
  String get saving => isThai ? 'กำลังบันทึก...' : 'Saving...';
  String get saveTransaction => isThai ? 'บันทึกรายการ' : 'Save transaction';
  String get saveAsInstallment =>
      isThai ? 'บันทึกเป็นงวดผ่อน' : 'Save as installment';
  String get couldNotSaveTransaction =>
      isThai ? 'บันทึกรายการไม่สำเร็จ' : 'Could not save transaction.';
  String get back => isThai ? 'กลับ' : 'Back';

  String get scanHub => isThai ? 'นำเข้าสลิป' : 'Slip Import';
  String get scanHubTip => isThai
      ? 'เลือกรูปสลิปจากแกลเลอรี รูปภาพยังเป็นส่วนตัวและใช้เพื่ออ่านข้อมูลเท่านั้น'
      : 'Import a slip photo from gallery. Images stay private and are used only for reading.';
  String get importFromGallery =>
      isThai ? 'นำเข้าจากแกลเลอรี' : 'Import from gallery';
  String get comingNext => isThai
      ? 'จะเพิ่มหลังจาก flow บันทึกนิ่งแล้ว'
      : 'Coming next after the save flow is stable.';
  String get slipReview => isThai ? 'ตรวจสลิป' : 'Slip Review';
  String get reviewSlip => isThai ? 'ตรวจรายการสลิป' : 'Review slip';
  String get slipReviewTip => isThai
      ? 'ตรวจผลลัพธ์จากสลิปก่อนบันทึก รูปภาพจะไม่ถูกอัปโหลด'
      : 'Review the slip result before saving. The image is not uploaded.';
  String get slipReviewDescription => isThai
      ? 'หน้า 5 ระบบ OCR จะกรอกให้อัตโนมัติภายหลัง ตอนนี้ยืนยันจำนวนเงินด้วยตัวเองก่อน'
      : 'Page 5. OCR will prefill this later. For now, confirm the slip amount manually.';
  String get readingSlip => isThai ? 'กำลังอ่านสลิป...' : 'Reading slip...';
  String get slipSummary => isThai ? 'สรุปจากสลิป' : 'Slip summary';
  String get bank => isThai ? 'ธนาคาร' : 'Bank';
  String get recipient => isThai ? 'ผู้รับ' : 'Recipient';
  String get sender => isThai ? 'ผู้โอน' : 'Sender';
  String get reference => isThai ? 'เลขอ้างอิง' : 'Reference';
  String get time => isThai ? 'เวลา' : 'Time';
  String get noSlipDataFound => isThai
      ? 'อ่านสลิปได้ไม่ครบ กรุณาตรวจและกรอกข้อมูลเองก่อนบันทึก'
      : 'The slip could not be read fully. Please review and enter missing data before saving.';
  String get chooseSlipFromGallery =>
      isThai ? 'เลือกรูปสลิปจากเครื่อง' : 'Choose slip from gallery';
  String get syncAlbumTitle =>
      isThai ? 'ซิงก์จากโฟลเดอร์เก่า' : 'Sync old folder';
  String get syncAlbumSubtitle => isThai
      ? 'เลือกทั้งโฟลเดอร์ แล้ว kimjod จะข้ามรูปที่ไม่ใช่สลิปและสลิปที่เคยเพิ่มแล้ว'
      : 'Choose a whole folder. kimjod skips non-payment images and slips already added.';
  String get syncAlbum =>
      isThai ? 'อ่านและซิงก์โฟลเดอร์' : 'Read and sync folder';
  String get syncingAlbum =>
      isThai ? 'กำลังอ่านโฟลเดอร์...' : 'Syncing folder...';
  String selectedSlipCount(int count) =>
      isThai ? 'เลือกรูปสลิป $count รูป' : '$count slip photos selected';
  String moreSlipImages(int count) =>
      isThai ? 'และอีก $count รูป' : 'and $count more photos';
  String get waitingToSync => isThai ? 'รออ่าน' : 'Waiting';
  String get addedFromAlbum => isThai ? 'เพิ่มแล้ว' : 'Added';
  String get skippedDuplicateSlip => isThai ? 'ซ้ำ ข้าม' : 'Skipped';
  String get couldNotReadSlip => isThai ? 'อ่านไม่ได้' : 'Unreadable';
  String albumSyncComplete({
    required int added,
    required int skipped,
    required int failed,
  }) {
    return isThai
        ? 'ซิงก์เสร็จ เพิ่ม $added ข้ามซ้ำ $skipped อ่านไม่ได้ $failed'
        : 'Sync complete. Added $added, skipped $skipped, unreadable $failed.';
  }

  String get galleryPermissionDenied => isThai
      ? 'ต้องอนุญาตให้เข้าถึงรูปภาพก่อนเลือกสลิปจากเครื่อง'
      : 'Allow photo access before choosing a slip from gallery.';
  String get openSettings => isThai ? 'เปิดการตั้งค่า' : 'Open settings';

  String get food => isThai ? 'อาหาร' : 'Food';
  String get drink => isThai ? 'เครื่องดื่ม' : 'Drinks';
  String get groceries => isThai ? 'ของใช้/ซูเปอร์มาร์เก็ต' : 'Groceries';
  String get transport => isThai ? 'เดินทาง' : 'Transport';
  String get bills => isThai ? 'บิล' : 'Bills';
  String get shopping => isThai ? 'ช้อปปิ้ง' : 'Shopping';
  String get rent => isThai ? 'ค่าเช่า/บ้าน' : 'Rent / home';
  String get health => isThai ? 'สุขภาพ' : 'Health';
  String get education => isThai ? 'การศึกษา' : 'Education';
  String get entertainment => isThai ? 'บันเทิง' : 'Entertainment';
  String get travel => isThai ? 'ท่องเที่ยว' : 'Travel';
  String get family => isThai ? 'ครอบครัว' : 'Family';
  String get insurance => isThai ? 'ประกัน' : 'Insurance';
  String get tax => isThai ? 'ภาษี/ค่าธรรมเนียม' : 'Tax / fees';
  String get donation => isThai ? 'บริจาค' : 'Donation';
  String get transfer => isThai ? 'โอนเงิน' : 'Transfer';
  String get other => isThai ? 'อื่น ๆ' : 'Other';
  String get salary => isThai ? 'เงินเดือน' : 'Salary';
  String get sideJob => isThai ? 'งานเสริม' : 'Side Job';
  String get business => isThai ? 'ธุรกิจ/ค้าขาย' : 'Business';
  String get bonus => isThai ? 'โบนัส' : 'Bonus';
  String get investment => isThai ? 'การลงทุน' : 'Investment';
  String get interest => isThai ? 'ดอกเบี้ย/ปันผล' : 'Interest / dividend';
  String get sale => isThai ? 'ขายของ' : 'Sale';
  String get allowance => isThai ? 'เงินสนับสนุน' : 'Allowance';
  String get gift => isThai ? 'ของขวัญ' : 'Gift';
  String get refund => isThai ? 'คืนเงิน' : 'Refund';

  String get privateData => isThai ? 'ข้อมูลส่วนตัว' : 'PRIVATE DATA';
  String get settingsTip => isThai
      ? 'ตั้งค่าภาษา หมวดหมู่ งบประมาณ และรายการผ่อนของคุณได้ที่นี่'
      : 'Your settings, categories, budgets, and installments live here.';
  String get language => isThai ? 'ภาษา' : 'Language';
  String get thai => 'ไทย';
  String get english => 'English';
  String get fixedCustom => isThai ? 'พื้นฐาน + เพิ่มเอง' : 'fixed + custom';
  String get monthlyAndCategory =>
      isThai ? 'รายเดือนและแยกหมวด' : 'monthly + category';
  String get fixedInstallment => isThai ? 'งวดคงที่' : 'fixed payments';
  String get syncStatus => isThai ? 'สถานะ sync' : 'Sync status';
  String get firestoreOffline => isThai
      ? 'ใช้ Firestore offline persistence'
      : 'Uses Firestore offline persistence';
  String get signOut => isThai ? 'ออกจากระบบ' : 'Sign out';
  String get analytics => isThai ? 'วิเคราะห์' : 'Analytics';
  String get analyticsTitle =>
      isThai ? 'วิเคราะห์เดือนนี้' : 'This month analytics';
  String get fromSummary => isThai ? 'จากสรุป' : 'FROM SUMMARY';
  String get analyticsTip => isThai
      ? 'เมื่อเพิ่มรายการจริงมากขึ้น แนวโน้มจะอ่านง่ายขึ้น'
      : 'Trends will get friendlier as you add more real transactions.';
  String get noAnalyticsTitle =>
      isThai ? 'ยังไม่มีข้อมูลวิเคราะห์' : 'No analytics yet';
  String get noAnalyticsMessage => isThai
      ? 'บันทึกรายจ่ายก่อน แล้วกราฟและหมวดที่ใช้เยอะจะขึ้นที่นี่'
      : 'Save expenses first, then charts and top categories will appear here.';
  String get monthTrend => isThai ? 'แนวโน้มเดือนนี้' : 'This month trend';
  String get balance => isThai ? 'คงเหลือ' : 'Balance';
  String get topCategories => isThai ? 'หมวดที่ใช้เยอะสุด' : 'Top categories';
  String get realDataSoon => isThai
      ? 'ส่วนนี้จะใช้ข้อมูลจริงทันทีเมื่อคุณเพิ่มข้อมูล'
      : 'This section will use your real saved data as soon as you add it.';
  String get budgetControl => isThai ? 'คุมงบรายเดือน' : 'Monthly budget';
  String get noBudgetYet => isThai ? 'ยังไม่มีงบประมาณ' : 'No budget yet';
  String get budgetHeroMessage => isThai
      ? 'เมื่อสร้างงบรายเดือนหรือแยกหมวด ระบบจะแสดง progress จริงจาก Firestore ที่นี่'
      : 'When you create monthly or category budgets, real Firestore progress will appear here.';
  String get totalMonthlyBudget =>
      isThai ? 'งบรวมรายเดือน' : 'Total monthly budget';
  String get categoryBudget => isThai ? 'งบแยกหมวด' : 'Category budget';
  String get notSet => isThai ? 'ยังไม่ได้ตั้งค่า' : 'Not set';
  String get noInstallmentsYet =>
      isThai ? 'ยังไม่มีรายการผ่อน' : 'No installments yet';
  String get installmentsHeroMessage => isThai
      ? 'เมื่อเพิ่มแผนผ่อน ระบบจะแสดงงวดที่ต้องจ่ายและให้ผู้ใช้กดยืนยันเอง ไม่มีการสร้าง transaction อัตโนมัติ'
      : 'When you add installment plans, due payments will appear for manual confirmation. No automatic transactions are created.';
  String get activePlans => isThai ? 'แผนที่ใช้งาน' : 'Active plans';
  String get zeroItems => isThai ? '0 รายการ' : '0 items';
  String get markAsPaid => isThai ? 'ทำเครื่องหมายว่าจ่ายแล้ว' : 'Mark as paid';
  String get waitingInstallments =>
      isThai ? 'รอรายการผ่อนจริง' : 'Waiting for real installments';
  String get manageCategories => isThai ? 'จัดหมวดหมู่' : 'Manage categories';
  String get defaultCategoriesReady =>
      isThai ? 'หมวดเริ่มต้นพร้อมใช้' : 'Default categories ready';
  String get categoriesHeroMessage => isThai
      ? 'Food, Transport, Bills และ Other ถูกใช้กับ transaction จริงแล้ว ส่วน custom category จะต่อกับ Firestore ในขั้นถัดไป'
      : 'Food, Transport, Bills, and Other are already used by real transactions. Custom categories will connect to Firestore next.';
  String get defaultExpense => isThai ? 'รายจ่ายพื้นฐาน' : 'default expense';
  String get defaultCategory => isThai ? 'พื้นฐาน' : 'default';

  String formatDate(DateTime date) {
    final months = isThai
        ? const [
            'ม.ค.',
            'ก.พ.',
            'มี.ค.',
            'เม.ย.',
            'พ.ค.',
            'มิ.ย.',
            'ก.ค.',
            'ส.ค.',
            'ก.ย.',
            'ต.ค.',
            'พ.ย.',
            'ธ.ค.',
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
    final today = DateUtils.isSameDay(date, DateTime.now());
    final prefix = today ? (isThai ? 'วันนี้, ' : 'Today, ') : '';
    return '$prefix${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
