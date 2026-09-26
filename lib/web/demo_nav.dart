import 'package:flutter/widgets.dart';

/// Named routes used by the Chrome demo shell to pick side-panel copy.
abstract final class DemoRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const home = '/home';
  static const medications = '/medications';
  static const schedule = '/schedule';
  static const caregiver = '/caregiver';
  static const settings = '/settings';
  static const addMedication = '/add-medication';
  static const manualMedication = '/manual-medication';
  static const medicationDetail = '/medication-detail';
  static const voice = '/voice';
  static const visualVerify = '/visual-verify';
  static const alarm = '/alarm';
  static const careRecipient = '/care-recipient';
}

/// Tracks the top-most named route for the desktop Chrome guide panel.
class DemoNavTracker extends ChangeNotifier {
  DemoNavTracker._();
  static final DemoNavTracker instance = DemoNavTracker._();

  String? _overlayRoute;

  String? get overlayRoute => _overlayRoute;

  void setOverlay(String? name) {
    if (_overlayRoute == name) return;
    _overlayRoute = name;
    notifyListeners();
  }
}

/// Observes navigator pushes/pops so the guide can follow overlays.
class DemoNavObserver extends NavigatorObserver {
  final List<String?> _stack = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.add(route.settings.name);
    _emit();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _emit();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_stack.isNotEmpty) _stack.removeLast();
    _stack.add(newRoute?.settings.name);
    _emit();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    final index = _stack.lastIndexOf(name);
    if (index != -1) {
      _stack.removeAt(index);
    } else if (_stack.isNotEmpty) {
      _stack.removeLast();
    }
    _emit();
  }

  void _emit() {
    String? top;
    for (var i = _stack.length - 1; i >= 0; i--) {
      final name = _stack[i];
      if (name != null &&
          name.isNotEmpty &&
          name != Navigator.defaultRouteName) {
        top = name;
        break;
      }
    }
    DemoNavTracker.instance.setOverlay(top);
  }
}
