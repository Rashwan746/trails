import 'app_localizations.dart';

class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override String get appName => 'اكتشف مصر';
  @override String get home => 'الرئيسية';
  @override String get search => 'بحث';
  @override String get favorites => 'المفضلة';
  @override String get featured => 'الأماكن المميزة';
  @override String get nearby => 'أماكن قريبة';
  @override String get seeAll => 'عرض الكل';
  @override String get loading => 'جاري التحميل...';
  @override String get errorOccurred => 'حدث خطأ ما';
  @override String get retry => 'إعادة المحاولة';
}
