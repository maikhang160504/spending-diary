import 'package:flutter/widgets.dart';

/// O-02: Holds data collected across onboarding steps 2-5.
///
/// Usage — wrap the onboarding entry point with [OnboardingStateProvider]:
/// ```dart
/// OnboardingStateProvider(
///   state: OnboardingState(),
///   child: const OnboardingStep2(),
/// )
/// ```
/// Then read from any descendant widget:
/// ```dart
/// final state = OnboardingStateProvider.of(context);
/// state.monthlyIncome = 8000000;
/// ```
class OnboardingState extends ChangeNotifier {
  // ── Step 2: Income ────────────────────────────────────────────────
  String incomeType = 'fixed'; // 'fixed' | 'variable'
  double monthlyIncome = 8000000;

  // ── Step 3: Spending categories + limits ─────────────────────────
  Map<String, double> categoryLimits = {};

  // ── Step 4: Savings goal ─────────────────────────────────────────
  double? savingsGoal;
  String? savingsGoalName;

  // ── Step 5: Profile ──────────────────────────────────────────────
  String? ageGroup;
  String? jobType;

  // ── Helpers ───────────────────────────────────────────────────────
  void setIncome({required String type, required double amount}) {
    incomeType = type;
    monthlyIncome = amount;
    notifyListeners();
  }

  void setCategoryLimit(String code, double limit) {
    categoryLimits[code] = limit;
    notifyListeners();
  }

  void removeCategoryLimit(String code) {
    categoryLimits.remove(code);
    notifyListeners();
  }

  void setSavingsGoal({double? amount, String? name}) {
    savingsGoal = amount;
    savingsGoalName = name;
    notifyListeners();
  }

  void setProfile({String? age, String? job}) {
    ageGroup = age ?? ageGroup;
    jobType = job ?? jobType;
    notifyListeners();
  }

  /// Serialises collected data for PATCH /users/me/settings.
  Map<String, dynamic> toSettingsPayload() {
    return {
      'incomeType': incomeType,
      'monthlyIncome': monthlyIncome,
      if (savingsGoal != null) 'savingsGoal': savingsGoal,
      if (savingsGoalName != null) 'savingsGoalName': savingsGoalName,
      if (ageGroup != null) 'ageGroup': ageGroup,
      if (jobType != null) 'jobType': jobType,
      if (categoryLimits.isNotEmpty) 'categoryLimits': categoryLimits,
    };
  }
}

/// O-02: [InheritedNotifier] that makes [OnboardingState] available to the
/// widget subtree without requiring an external state-management package.
class OnboardingStateProvider extends InheritedNotifier<OnboardingState> {
  const OnboardingStateProvider({
    super.key,
    required OnboardingState state,
    required super.child,
  }) : super(notifier: state);

  /// Returns the nearest [OnboardingState] in the widget tree.
  ///
  /// Returns `null` if no [OnboardingStateProvider] ancestor is found.
  static OnboardingState? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<OnboardingStateProvider>()
        ?.notifier;
  }

  /// Like [maybeOf] but asserts that a provider exists.
  static OnboardingState of(BuildContext context) {
    final state = maybeOf(context);
    assert(state != null, 'No OnboardingStateProvider found in widget tree.');
    return state!;
  }
}
