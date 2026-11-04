// Base API, where backend is running --> temporary address: localhost
// Changes depending on where the backend runs: localhost, Mac IP, or Lightsail IP 
const String apiBaseUrl = 'http://localhost:5000';

// Request wait duration until server timeout
const Duration apiTimeout = Duration(seconds: 10);