// Backend address, set at run or build time with --dart-define=API_BASE_URL=
// Defaults to localhost for Chrome. The emulator uses http://10.0.2.2:5000.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue:'http://localhost:5000');

// Request wait duration until server timeout
const Duration apiTimeout = Duration(seconds: 10);
