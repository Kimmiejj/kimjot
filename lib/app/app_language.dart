import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const _preferenceKey = 'app.language';

  AppLanguage _language;

  AppLanguage get language => _language;

  Locale get locale => _language.locale;

  AppStrings get strings => AppStrings(_language);

  static Future<AppLanguage> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return _languageFromCode(prefs.getString(_preferenceKey)) ?? AppLanguage.en;
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }

    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, language.name);
  }

  static AppLanguage? _languageFromCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return null;
    }

    for (final language in AppLanguage.values) {
      if (language.name == code || language.locale.languageCode == code) {
        return language;
      }
    }

    return null;
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
  String get ocrLabel => isThai ? 'อ่านสลิป' : 'OCR';
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
  String get otherMonth => isThai ? 'เดือนอื่น' : 'Other month';
  String get previousMonth => isThai ? 'เดือนก่อนหน้า' : 'Previous month';
  String get nextMonth => isThai ? 'เดือนถัดไป' : 'Next month';
  String get settings => isThai ? 'ตั้งค่า' : 'Settings';
  String get monthlyBalance =>
      isThai ? 'ยอดคงเหลือเดือนนี้' : 'Monthly balance';
  String get income => isThai ? 'รายรับ' : 'Income';
  String get expense => isThai ? 'รายจ่าย' : 'Expense';
  String get internalTransfer =>
      isThai ? 'โอนย้ายระหว่างบัญชี' : 'Internal Transfer';
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
  String get searchPlaceholder => isThai
      ? 'ค้นหา / จำนวนเงิน / เดือน / หมวดหมู่'
      : 'Search / amount / month / category';
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

  String get firebaseSetupRequired =>
      isThai ? 'ต้องตั้งค่า Firebase' : 'Firebase setup required';
  String get firebaseSetupInstructions => isThai
      ? 'เพิ่มไฟล์ google-services.json สำหรับแพ็กเกจ com.kimjot.project เพิ่ม SHA-1/SHA-256 ใน Firebase Console และเปิดใช้การเข้าสู่ระบบด้วย Google'
      : 'Add google-services.json for package com.kimjot.project, add SHA-1/SHA-256 in Firebase Console, and enable Google sign-in.';
  String get localSettings => isThai ? 'การตั้งค่าในเครื่อง' : 'LOCAL SETTINGS';
  String get current => isThai ? 'ปัจจุบัน' : 'Current';
  String get categories => isThai ? 'หมวดหมู่' : 'Categories';
  String get active => isThai ? 'ใช้งานอยู่' : 'Active';
  String get remaining => isThai ? 'คงเหลือ' : 'Remaining';
  String get total => isThai ? 'ทั้งหมด' : 'Total';
  String get ready => isThai ? 'พร้อม' : 'Ready';
  String get duplicate => isThai ? 'ซ้ำ' : 'Duplicate';
  String get failed => isThai ? 'ไม่สำเร็จ' : 'Failed';
  String get stopped => isThai ? 'หยุดแล้ว' : 'Stopped';
  String get done => isThai ? 'เสร็จแล้ว' : 'Done';
  String get slip => isThai ? 'สลิป' : 'Slip';
  String get set => isThai ? 'ตั้งค่า' : 'Set';
  String get clearSearch => isThai ? 'ล้างการค้นหา' : 'Clear search';
  String get editTransaction => isThai ? 'แก้ไขรายการ' : 'Edit transaction';
  String get edit => isThai ? 'แก้ไข' : 'Edit';
  String get saveChanges => isThai ? 'บันทึกการแก้ไข' : 'Save changes';
  String get deleteTransaction => isThai ? 'ลบรายการ' : 'Delete transaction';
  String get googleAccount => isThai ? 'บัญชี Google' : 'Google account';
  String get kimjodUser => isThai ? 'ผู้ใช้ Kimjod' : 'Kimjod user';
  String get unknownBank => isThai ? 'ไม่ทราบธนาคาร' : 'Unknown bank';
  String get manualSource => isThai ? 'เพิ่มเอง' : 'Manual';
  String get gallerySlipSource => isThai ? 'สลิปจากแกลเลอรี' : 'Gallery slip';

  String get budgetSaved => isThai ? 'บันทึกงบประมาณแล้ว' : 'Budget saved.';
  String get budgetHomeComparison => isThai
      ? 'หน้าแรกจะเปรียบเทียบงบนี้กับรายจ่ายรวมของเดือนที่เลือก'
      : 'Home will compare this budget with the selected month expense total.';
  String categoriesReady(int count) =>
      isThai ? 'พร้อม $count หมวดหมู่' : '$count ready';
  String get monthlyBudgetSetup => isThai ? 'ตั้งงบรายเดือน' : 'Monthly budget';
  String get monthlyBudgetDescription => isThai
      ? 'กำหนดวงเงินรวมที่นี่ งบแยกหมวดหมู่จะแยกจากแผนรายการผ่อน'
      : 'Set the total limit here. Category budgets stay separate from installment plans.';
  String get saveBudget => isThai ? 'บันทึกงบประมาณ' : 'Save budget';
  String get clearBudget => isThai ? 'ล้างงบประมาณ' : 'Clear budget';
  String get categoryBudgetView =>
      isThai ? 'งบประมาณแยกหมวดหมู่' : 'Category budget view';
  String get categoryBudgetDescription => isThai
      ? 'หมวดหมู่รายจ่ายพร้อมใช้สำหรับจัดกลุ่มงบประมาณ ส่วนรายการผ่อนจัดการแยกในหน้าของตัวเอง'
      : 'Expense categories are ready for budget-level grouping. Installments are managed on their own page.';
  String get availableForBudgetGrouping => isThai
      ? 'พร้อมใช้จัดกลุ่มงบประมาณและติดตามรายจ่าย'
      : 'Available for budget grouping and expense tracking';
  String get installmentsStaySeparate =>
      isThai ? 'รายการผ่อนจัดการแยกกัน' : 'Installments stay separate';
  String get installmentsSeparateDescription => isThai
      ? 'เมื่อทำเครื่องหมายว่าจ่ายค่างวดแล้ว ระบบจะสร้างรายการรายจ่ายแยกต่างหาก และจะไม่เขียนทับงบรายเดือนในหน้านี้'
      : 'Marking an installment as paid creates its own tracked expense flow. It does not overwrite the monthly budget value here.';
  String get installmentHomeDescription => isThai
      ? 'หน้าแรกจะแสดงแผนที่ใช้งานในเดือนที่เลือก เมื่อทำเครื่องหมายว่าจ่ายแล้ว จำนวนงวดคงเหลือจะอัปเดตตาม'
      : 'Home shows active plans for the selected month. Marking paid updates the next due count.';
  String get monthlyLoad => isThai ? 'ยอดผ่อนต่อเดือน' : 'Monthly load';
  String get installmentPlans => isThai ? 'แผนรายการผ่อน' : 'Installment plans';
  String get installmentPlansDescription => isThai
      ? 'แผนเหล่านี้ติดตามแยกจากการตั้งงบรายเดือน'
      : 'These plans are tracked separately from monthly budget setup.';
  String get addInstallment => isThai ? 'เพิ่มรายการผ่อน' : 'Add installment';
  String get editInstallment => isThai ? 'แก้ไขรายการผ่อน' : 'Edit installment';
  String get name => isThai ? 'ชื่อ' : 'Name';
  String get installmentNameHint =>
      isThai ? 'โทรศัพท์ แล็ปท็อป หรือแผนผ่อนบัตร' : 'Phone, laptop, card plan';
  String get requiredField => isThai ? 'จำเป็นต้องกรอก' : 'Required';
  String get paid => isThai ? 'จ่ายแล้ว' : 'Paid';
  String monthsCount(int count) => isThai ? '$count เดือน' : '$count months';
  String yearsCount(int count) => isThai ? '$count ปี' : '$count years';
  String get start => isThai ? 'เริ่มต้น' : 'Start';
  String get dueDay => isThai ? 'วันครบกำหนด' : 'Due day';
  String dayNumber(int day) => isThai ? 'วันที่ $day' : 'Day $day';
  String get progress => isThai ? 'ความคืบหน้า' : 'Progress';
  String amountPerCycle(String amount) =>
      isThai ? '$amount ต่องวด' : '$amount per cycle';
  String get editInstallmentTooltip =>
      isThai ? 'แก้ไขรายการผ่อน' : 'Edit installment';
  String get markInstallmentPaidTooltip =>
      isThai ? 'ทำเครื่องหมายว่าจ่ายแล้ว' : 'Mark installment as paid';
  String get deleteInstallmentTooltip =>
      isThai ? 'ลบรายการผ่อน' : 'Delete installment';
  String overBy(String amount) => isThai ? 'เกินงบ $amount' : 'Over by $amount';
  String amountLeft(String amount) => isThai ? 'เหลือ $amount' : '$amount left';
  String get editBudget => isThai ? 'แก้ไขงบประมาณ' : 'Edit budget';
  String spentOf({required String spent, required String budget}) =>
      isThai ? 'ใช้ไป $spent จาก $budget' : '$spent spent of $budget';
  String dueAcrossPlans({required String amount, required int count}) => isThai
      ? 'ครบกำหนด $amount จาก $count แผน'
      : '$amount due across $count plans';
  String dueThisMonth(String amount) =>
      isThai ? 'ครบกำหนด $amount เดือนนี้' : '$amount due this month';
  String get manageInstallments =>
      isThai ? 'จัดการรายการผ่อน' : 'Manage installments';
  String invalidNumber(String value) =>
      isThai ? 'ตัวเลขไม่ถูกต้อง: $value' : 'Invalid number: $value';
  String get trainingComplete =>
      isThai ? 'ฝึกตัวอ่านเสร็จแล้ว' : 'Training complete';
  String get albumScanComplete =>
      isThai ? 'อ่านสลิปเสร็จแล้ว' : 'Scan complete';
  String get albumScanCompleteDescription => isThai
      ? 'อ่านอัลบั้มเสร็จแล้ว ตรวจสอบรายการหรือบันทึกทั้งหมดได้ทันที'
      : 'Album scan complete. Review it or save everything now.';
  String get albumSyncProgressChannel =>
      isThai ? 'ความคืบหน้าการซิงก์อัลบั้ม' : 'Album sync progress';
  String get albumSyncProgressDescription => isThai
      ? 'แสดงความคืบหน้าระหว่างอ่านสลิปจากอัลบั้ม'
      : 'Shows album sync progress while slips are being read.';
  String get albumSyncCompleteChannel =>
      isThai ? 'ซิงก์อัลบั้มเสร็จแล้ว' : 'Album sync complete';
  String get albumSyncCompleteDescription => isThai
      ? 'แจ้งเมื่ออ่านสลิปจากอัลบั้มเสร็จแล้ว'
      : 'Shows when album sync has finished reading slips.';
  String get preparingSlipScan =>
      isThai ? 'กำลังเตรียมอ่านสลิป...' : 'Preparing slip scan...';
  String albumSyncProgressBody({required int completed, required int total}) =>
      isThai
      ? 'กำลังอ่าน $completed/$total สลิป แตะเพื่อตรวจสอบ'
      : 'Reading $completed/$total slips. Tap to review.';
  String albumSyncCompleteBody({
    required int ready,
    required int skipped,
    required int unreadable,
  }) => isThai
      ? 'พร้อม $ready ข้ามรายการซ้ำ $skipped อ่านไม่ได้ $unreadable แตะเพื่อตรวจสอบ'
      : 'Ready $ready, skipped $skipped, unreadable $unreadable. Tap to review.';
  String get albumSyncStopped =>
      isThai ? 'หยุดการซิงก์อัลบั้ม' : 'Album sync stopped';
  String albumSyncStoppedBody(int total) => isThai
      ? 'อ่านสลิป $total รายการไม่สำเร็จ แตะเพื่อตรวจสอบ'
      : 'Could not finish reading $total slips. Tap to review.';

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
  String get chooseSlipFromGallery => isThai
      ? 'เลือกรูปสลิปหลายรูปจากเครื่อง'
      : 'Choose one or more slips from gallery';
  String get syncAlbumTitle => isThai ? 'ซิงก์จากอัลบัม' : 'Sync album';
  String get syncAlbumSubtitle => isThai
      ? 'เลือกได้หลายอัลบั้ม Kimjod จะตรวจรูปใหม่จากทุกอัลบั้มอัตโนมัติ'
      : 'Choose multiple folders. Kimjod automatically detects new slips from every selected album.';
  String get addAnotherAlbum =>
      isThai ? 'เพิ่มอัลบั้มอื่นอีกไหม?' : 'Add another album?';
  String get addAnotherAlbumDescription => isThai
      ? 'อัลบั้มนี้ถูกเพิ่มแล้ว คุณเลือกเพิ่มได้อีก และ Auto-sync จะตรวจทุกอัลบั้มที่เคยเพิ่มไว้'
      : 'This album was added. You can select another, and auto-sync will keep watching every album you add.';
  String get chooseAnotherAlbum =>
      isThai ? 'เลือกอัลบั้มอื่น' : 'Choose another';
  String get continueToReview => isThai ? 'ไปตรวจสลิป' : 'Review slips';
  String get syncAlbum =>
      isThai ? 'อ่านและซิงก์โฟลเดอร์' : 'Read and sync folder';
  String get syncingAlbum =>
      isThai ? 'กำลังอ่านโฟลเดอร์...' : 'Syncing folder...';
  String get cancelAlbumSync => isThai
      ? '\u0E22\u0E01\u0E40\u0E25\u0E34\u0E01\u0E01\u0E32\u0E23\u0E0B\u0E34\u0E07\u0E01\u0E4C'
      : 'Cancel sync';
  String get albumSyncCancelled => isThai
      ? '\u0E22\u0E01\u0E40\u0E25\u0E34\u0E01\u0E01\u0E32\u0E23\u0E0B\u0E34\u0E07\u0E01\u0E4C\u0E41\u0E25\u0E49\u0E27'
      : 'Sync cancelled';
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
      isThai ? 'วิเคราะห์การรายจ่าย' : 'Expense Analysis';
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
      ? 'หมวดหมู่พื้นฐานและหมวดที่เพิ่มเองใช้กับรายการจริงได้ทันที'
      : 'Default and custom categories are available for real transactions immediately.';
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
    final year = isThai ? date.year + 543 : date.year;
    return '$prefix${date.day} ${months[date.month - 1]} $year';
  }

  String formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String formatDateTime(DateTime date) {
    return '${formatDate(date)} · ${formatTime(date)}';
  }

  String formatMonthYear(DateTime date) {
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
            'January',
            'February',
            'March',
            'April',
            'May',
            'June',
            'July',
            'August',
            'September',
            'October',
            'November',
            'December',
          ];
    final year = isThai ? date.year + 543 : date.year;
    return '${months[date.month - 1]} $year';
  }
}
