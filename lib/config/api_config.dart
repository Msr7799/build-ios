class ApiConfig {
  // Vercel deployment URL - all API calls go through this
  // For local dev: use 'http://192.168.100.25:3000' or 'http://10.0.2.2:3000' (emulator)
  static const String baseUrl = 'https://psm-lite.vercel.app';

  // API endpoints
  static const String dashboard = '/api/dashboard';
  static const String units = '/api/units';
  static String unit(String id) => '/api/units/$id';
  static String unitPrimaryLink(String id) => '/api/units/$id/primary-link';
  static const String feeds = '/api/feeds';
  static String feed(String id) => '/api/feeds/$id';
  static String calendar(String unitId) => '/api/calendar/$unitId';
  static String calendarBlock(String unitId) => '/api/calendar/$unitId/block';
  static String content(String unitId) => '/api/content/$unitId';
  static const String contentParseHtml = '/api/content/parse-html';
  static const String bookings = '/api/bookings';
  static String booking(String id) => '/api/bookings/$id';
  static const String expenses = '/api/expenses';
  static String expense(String id) => '/api/expenses/$id';
  static const String reports = '/api/reports';
  static const String rates = '/api/rates';
  static String rate(String id) => '/api/rates/$id';
  static const String ratesPreview = '/api/rates/preview';
  static const String payouts = '/api/payouts';
  static String payout(String id) => '/api/payouts/$id';
  static String payoutAllocate(String id) => '/api/payouts/$id/allocate';
  static const String payoutsUnpaid = '/api/payouts/unpaid';
  static const String publishingStatus = '/api/publishing/status';
  static const String publishing = '/api/publishing';
  static const String sync = '/api/sync';
  static const String importUrl = '/api/units/import-url';
  static const String importFile = '/api/units/import-file';
  static const String notes = '/api/notes';
  static String note(String id) => '/api/notes/$id';
  static const String upload = '/api/upload';
}
