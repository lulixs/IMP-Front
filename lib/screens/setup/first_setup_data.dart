/// Everything entered during first-time setup. Nothing is saved until it is
/// confirmed on the last step, so a setup abandoned halfway leaves nothing behind.
class FirstSetupData {
  final String masterEmail;
  final String masterPassword;
  final String tabletName;
  final String employeeName;
  final String employeePin;

  const FirstSetupData({
    required this.masterEmail,
    required this.masterPassword,
    required this.tabletName,
    required this.employeeName,
    required this.employeePin,
  });
}
