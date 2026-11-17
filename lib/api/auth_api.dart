import 'api_client.dart';
import 'token_store.dart';
import '../models/employee.dart';

// The sign-in endpoints from IMP-Back docs/api/auth.md, each sending the token auth.md asks for.
// Every call that gets a token back saves it (and the signed-in employee) before returning, so no screen can forget to
class AuthApi {
  final ApiClient _api;
  final TokenStore _tokens;

  // Uses the provided token store, or the tablet's real one
  AuthApi(this._api, {TokenStore? tokens}) : _tokens = tokens ?? TokenStore();

  // GET /api/setup/status, no token. True once the store has been set up
  Future<bool> isSetUp() async {
    final json = await _api.get('/api/setup/status', screen: 'Setup', token: TokenType.none);
    return json['isSetUp'] as bool;
  }

  // POST /api/setup, no token. First-time setup: creates the Master account, this tablet, and the first employee
  Future<({String deviceToken, String sessionToken, Employee employee})> setUp(
    String masterEmail,
    String masterPassword,
    String tabletName,
    String employeeName,
    String employeePin,
  ) async {
    final json = await _api.post(
      '/api/setup',
      screen: 'Setup',
      body: {
        'masterEmail': masterEmail,
        'masterPassword': masterPassword,
        'tabletName': tabletName,
        'employeeName': employeeName,
        'employeePin': employeePin,
      },
      token: TokenType.none,
    );

    final result = (
      deviceToken: json['deviceToken'] as String,
      sessionToken: json['sessionToken'] as String,
      employee: Employee.fromJson(json['employee']),
    );
    await _tokens.saveDeviceToken(result.deviceToken);
    await _tokens.saveSessionToken(result.sessionToken);
    await _tokens.saveEmployee(result.employee);
    return result;
  }

  // POST /api/devices, no token. Sets up another tablet and returns its device token
  Future<String> addTablet(String tabletName, String email, String password) async {
    final json = await _api.post(
      '/api/devices',
      screen: 'Tablet setup',
      body: {'tabletName': tabletName, 'email': email, 'password': password},
      token: TokenType.none,
    );
    final deviceToken = json['deviceToken'] as String;
    await _tokens.saveDeviceToken(deviceToken);
    return deviceToken;
  }

  // POST /api/devices/renew, device token (expired is fine). Gives the tablet a new 90 days
  Future<String> renewTablet(String email, String password) async {
    final json = await _api.post(
      '/api/devices/renew',
      screen: 'Sign back in',
      body: {'email': email, 'password': password},
      token: TokenType.device,
    );
    // Replaces the old device token
    final deviceToken = json['deviceToken'] as String;
    await _tokens.saveDeviceToken(deviceToken);
    return deviceToken;
  }

  // GET /api/employees/active, device token. The names on the employee sign-in screen
  Future<List<Employee>> activeEmployees() async {
    final json = await _api.get('/api/employees/active', screen: 'Employee sign-in', token: TokenType.device);
    return (json['employees'] as List).map((e) => Employee.fromJson(e)).toList();
  }

  // POST /api/sessions, device token. Signs an employee in on this tablet
  Future<({String sessionToken, Employee employee})> signIn(int employeeId, String pin) async {
    final json = await _api.post(
      '/api/sessions',
      screen: 'Employee sign-in',
      body: {'employeeId': employeeId, 'pin': pin},
      token: TokenType.device,
    );

    final result = (sessionToken: json['sessionToken'] as String, employee: Employee.fromJson(json['employee']));
    await _tokens.saveSessionToken(result.sessionToken);
    await _tokens.saveEmployee(result.employee);
    return result;
  }

  // DELETE /api/sessions/current, session token. Signs the employee out, then forgets the session here too
  Future<void> signOut() async {
    await _api.delete('/api/sessions/current', screen: 'Switch user', token: TokenType.session);
    await _tokens.deleteSessionToken();
  }

  // POST /api/master-mode, session token. Turns on Master mode with the Master email and password
  Future<void> masterModeOn(String email, String password) async {
    await _api.post(
      '/api/master-mode',
      screen: 'Master mode',
      body: {'email': email, 'password': password},
      token: TokenType.session,
    );
  }

  // DELETE /api/master-mode, session token. Turns off Master mode. The employee stays signed in
  Future<void> masterModeOff() async {
    await _api.delete('/api/master-mode', screen: 'Master mode', token: TokenType.session);
  }
}
