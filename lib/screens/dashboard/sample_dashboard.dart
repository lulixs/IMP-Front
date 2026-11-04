/// Sample response for GET /api/dashboard, in the shape from the backend repo's
/// docs/api/dashboard.md. It has one category so the dashboard can be built before
/// the endpoint exists. Delete this file once the dashboard loads from the API.
const sampleDashboardJson = '''
{
  "alertThresholdDays": 180,
  "categories": [
    { "id": 1, "name": "Sample category", "symbol": "📦", "full": 3, "half": 2, "empty": 1, "storedTooLong": 2 }
  ]
}
''';
