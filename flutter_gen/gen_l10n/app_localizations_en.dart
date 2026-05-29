import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override String get appName => 'Discover Egypt';
  @override String get home => 'Home';
  @override String get search => 'Search';
  @override String get favorites => 'Favorites';
  @override String get featured => 'Featured Places';
  @override String get nearby => 'Nearby Gems';
  @override String get seeAll => 'See All';
  @override String get loading => 'Loading...';
  @override String get errorOccurred => 'Something went wrong';
  @override String get retry => 'Retry';
}
