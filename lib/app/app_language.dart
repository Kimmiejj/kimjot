import 'package:flutter/material.dart';

enum AppLanguage {
  th(Locale('th'), 'ไทย'),
  en(Locale('en'), 'English');

  const AppLanguage(this.locale, this.label);

  final Locale locale;
  final String label;
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({AppLanguage initialLanguage = AppLanguage.th})
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

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope was not found in the widget tree.');
    return scope!.notifier!;
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
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isThai => language == AppLanguage.th;

  String get startingKimjod => isThai ? 'กำลังเริ่ม kimjod...' : 'Starting kimjod...';
  String get checkingSignIn => isThai ? 'กำลังตรวจสอบการเข้าสู่ระบบ...' : 'Checking sign in...';

  String get loginHeadline => isThai ? 'จัดเงินให้ชัด\nทุกวัน' : 'Keep money clear\nevery day';
  String get loginSubtitle => isThai
      ? 'บันทึกรายรับ รายจ่าย สแกนสลิป และรายการผ่อน โดยไม่ต้องอัปโหลดรูปสลิป'
      : 'Track income, expenses, slip scans, and installments without uploading slip images.';
  String get continueWithGoogle => isThai ? 'เข้าสู่ระบบด้วย Google' : 'Continue with Google';
  String get signingIn => isThai ? 'กำลังเข้าสู่ระบบ...' : 'Signing in...';
  String get onDevice => isThai ? 'บนเครื่อง' : 'On-device';
  String get storage => isThai ? 'ที่เก็บรูป' : 'Storage';
  String get noSlipImage => isThai ? 'ไม่เก็บรูปสลิป' : 'No slip image';
  String get privacyNote => isThai
      ? 'รูปภาพใช้เพื่ออ่านข้อมูลเท่านั้น และไม่ถูกบันทึกลง Firebase Storage'
      : 'Images are used only for reading data. Slip images are not saved to Firebase Storage.';
  String get googleSignInFailed => isThai
      ? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ'
      : 'Google sign in failed.';
  String get googleSetupFailed => isThai
      ? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาตรวจการตั้งค่า Firebase'
      : 'Google sign in failed. Check Firebase setup.';
  String get missingGoogleClientId => isThai
      ? 'ยังไม่มี Google Web client ID ให้เปิด Google sign-in ใน Firebase แล้วรันด้วย --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com'
      : 'Missing Google Web client ID. Enable Google sign-in in Firebase, then run with --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com';
  String get androidOauthFailed => isThai
      ? 'เข้าสู่ระบบด้วย Google ไม่สำเร็จ กรุณาตรวจ Android OAuth ใน Firebase'
      : 'Google sign in failed. Check Android OAuth setup in Firebase.';

  String get transactionSaved => isThai ? 'บันทึกรายการแล้ว' : 'Transaction saved.';
  String hello(String name) => isThai ? 'สวัสดี, $name' : 'Hello, $name';
  String get synced => isThai ? 'ซิงก์แล้ว' : 'SYNCED';
  String get thisMonth => isThai ? 'เดือนนี้' : 'This month';
  String get settings => isThai ? 'ตั้งค่า' : 'Settings';
  String get monthlyBalance => isThai ? 'ยอดคงเหลือเดือนนี้' : 'Monthly balance';
  String get income => isThai ? 'รายรับ' : 'Income';
  String get expense => isThai ? 'รายจ่าย' : 'Expense';
  String get add => isThai ? 'เพิ่ม' : 'Add';
  String get scan => isThai ? 'สแกน' : 'Scan';
  String get scanSlip => isThai ? 'สแกน\nสลิป' : 'SCAN\nSlip';
  String get qrBank => isThai ? 'QR\nธนาคาร' : 'QR\nBank';
  String get graph => isThai ? 'กราฟ' : 'Graph';
  String get home => isThai ? 'หน้าแรก' : 'Home';
  String get budget => isThai ? 'งบประมาณ' : 'Budget';
  String get noBudget => isThai ? 'ยังไม่ได้ตั้งงบประมาณ' : 'No budget has been created yet.';
  String get installments => isThai ? 'รายการผ่อน' : 'Installments';
  String get noDueInstallment => isThai ? 'ยังไม่มีงวดที่ต้องจ่าย' : 'No due installment';
  String get installmentHint => isThai
      ? 'รายการผ่อนจะแสดงที่นี่หลังจากตั้งค่า'
      : 'Installment items will appear here after setup.';
  String get recentTransactions => isThai ? 'รายการล่าสุด' : 'Recent transactions';
  String get noTransactionsYet => isThai ? 'ยังไม่มีรายการ' : 'No transactions yet';
  String get savedTransactionsHint => isThai
      ? 'รายการที่บันทึกจะแสดงที่นี่'
      : 'Saved transactions will appear here.';
  String get seeMore => isThai ? 'ดูทั้งหมด' : 'See more';

  String get addTransaction => isThai ? 'เพิ่มรายการ' : 'Add transaction';
  String get addTransactionTip => isThai
      ? 'ใส่จำนวนเงิน เลือกประเภท แล้ว kimjod จะจัดรายการให้อย่างเป็นระเบียบ'
      : 'Add an amount, choose a type, and kimjod will keep the list tidy.';
  String get amount => isThai ? 'จำนวนเงิน' : 'Amount';
  String get amountPrefix => isThai ? '฿' : 'THB ';
  String get amountValidation => isThai ? 'กรอกจำนวนเงินมากกว่า 0' : 'Enter an amount greater than 0';
  String get date => isThai ? 'วันที่' : 'Date';
  String get note => isThai ? 'โน้ต' : 'Note';
  String get noteHint => isThai ? 'อาหารกลางวัน' : 'Lunch';
  String get details => isThai ? 'รายละเอียดเพิ่มเติม' : 'More details';
  String get detailsHint => isThai ? 'ร้าน / source / merchant' : 'Shop / source / merchant';
  String get category => isThai ? 'หมวดหมู่' : 'Category';
  String get saving => isThai ? 'กำลังบันทึก...' : 'Saving...';
  String get saveTransaction => isThai ? 'บันทึกรายการ' : 'Save transaction';
  String get saveAsInstallment => isThai ? 'บันทึกเป็นงวดผ่อน' : 'Save as installment';
  String get couldNotSaveTransaction => isThai
      ? 'บันทึกรายการไม่สำเร็จ'
      : 'Could not save transaction.';
  String get back => isThai ? 'กลับ' : 'Back';

  String get food => isThai ? 'อาหาร' : 'Food';
  String get transport => isThai ? 'เดินทาง' : 'Transport';
  String get bills => isThai ? 'บิล' : 'Bills';
  String get other => isThai ? 'อื่น ๆ' : 'Other';
  String get salary => isThai ? 'เงินเดือน' : 'Salary';
  String get sideJob => isThai ? 'งานเสริม' : 'Side Job';
  String get refund => isThai ? 'คืนเงิน' : 'Refund';

  String get privateData => isThai ? 'ข้อมูลส่วนตัว' : 'PRIVATE DATA';
  String get settingsTip => isThai
      ? 'ตั้งค่าภาษา หมวดหมู่ งบประมาณ และรายการผ่อนของคุณได้ที่นี่'
      : 'Your settings, categories, budgets, and installments live here.';
  String get language => isThai ? 'ภาษา' : 'Language';
  String get thai => 'ไทย';
  String get english => 'English';
  String get fixedCustom => isThai ? 'พื้นฐาน + เพิ่มเอง' : 'fixed + custom';
  String get monthlyAndCategory => isThai ? 'รายเดือนและแยกหมวด' : 'monthly + category';
  String get fixedInstallment => isThai ? 'งวดคงที่' : 'fixed payments';
  String get syncStatus => isThai ? 'สถานะ sync' : 'Sync status';
  String get firestoreOffline => isThai
      ? 'ใช้ Firestore offline persistence'
      : 'Uses Firestore offline persistence';
  String get signOut => isThai ? 'ออกจากระบบ' : 'Sign out';

  String formatDate(DateTime date) {
    final months = isThai
        ? const ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.']
        : const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final today = DateUtils.isSameDay(date, DateTime.now());
    final prefix = today ? (isThai ? 'วันนี้, ' : 'Today, ') : '';
    return '$prefix${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
