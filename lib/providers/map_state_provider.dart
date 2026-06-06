import 'package:flutter/foundation.dart';

class MapStateProvider extends ChangeNotifier {
  bool _placeSelected = false;

  bool get placeSelected => _placeSelected;

  void selectPlace() {
    if (_placeSelected) return;
    _placeSelected = true;
    notifyListeners();
  }

  void deselectPlace() {
    if (!_placeSelected) return;
    _placeSelected = false;
    notifyListeners();
  }
}
