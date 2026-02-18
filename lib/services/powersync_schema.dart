import 'package:powersync/powersync.dart';

/// PowerSync schema matching Neon database structure
const schema = Schema([
  // ─── Unit Table ───
  Table('Unit', [
    Column.text('id'), // PRIMARY KEY - REQUIRED!
    Column.text('name'),
    Column.text('code'),
    Column.integer('isActive'), // 1 = true, 0 = false
    Column.text('currency'),
    Column.text('defaultRate'), // Decimal as text
    Column.text('createdAt'),
    Column.text('updatedAt')
  ]),

  // ─── Booking Table ───
  Table('Booking', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'), // Foreign Key
    Column.text('channel'), // ENUM: BOOKING, AIRBNB, etc.
    Column.text('externalUid'),
    Column.text('summary'),
    Column.text('startDate'),
    Column.text('endDate'),
    Column.text('lastSeenAt'),
    Column.integer('isCancelled'),
    Column.text('currency'),
    Column.text('grossAmount'),
    Column.text('commissionAmount'),
    Column.text('taxAmount'),
    Column.text('otherFeesAmount'),
    Column.text('netAmount'),
    Column.text('paymentStatus'),
    Column.text('notes'),
    Column.text('createdAt'),
    Column.text('updatedAt')
  ], indexes: [
    // Add indexes for better query performance
    Index('booking_unitId', [IndexedColumn('unitId')]),
    Index('booking_dates', [IndexedColumn('startDate'), IndexedColumn('endDate')])
  ]),

  // ─── DateBlock Table ───
  Table('DateBlock', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'),
    Column.text('date'),
    Column.text('source'),
    Column.text('reason'),
    Column.text('createdAt')
  ], indexes: [
    Index('dateblock_unit_date', [IndexedColumn('unitId'), IndexedColumn('date')])
  ]),

  // ─── RateRule Table ───
  Table('RateRule', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'),
    Column.text('channel'),
    Column.text('name'),
    Column.text('startDate'),
    Column.text('endDate'),
    Column.text('baseRate'),
    Column.text('weekendRate'),
    Column.integer('minNights'),
    Column.integer('maxNights'),
    Column.integer('stopSell'),
    Column.text('daysOfWeek'), // JSON array
    Column.integer('priority'),
    Column.text('createdAt'),
    Column.text('updatedAt')
  ]),

  // ─── Expense Table ───
  Table('Expense', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'),
    Column.text('category'),
    Column.text('amount'),
    Column.text('currency'),
    Column.text('spentAt'),
    Column.text('note'),
    Column.text('createdAt')
  ]),

  // ─── Payout Table ───
  Table('Payout', [
    Column.text('id'), // PRIMARY KEY
    Column.text('channel'),
    Column.text('payoutDate'),
    Column.text('currency'),
    Column.text('amount'),
    Column.text('providerRef'),
    Column.text('status'),
    Column.text('note'),
    Column.text('createdAt')
  ]),

  // ─── PayoutLine Table ───
  Table('PayoutLine', [
    Column.text('id'), // PRIMARY KEY
    Column.text('payoutId'), // Foreign Key
    Column.text('bookingId'), // Foreign Key
    Column.text('amount'),
    Column.text('note'),
    Column.text('createdAt')
  ]),

  // ─── ChannelListing Table ───
  Table('ChannelListing', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'),
    Column.text('channel'),
    Column.text('externalId'),
    Column.text('publicUrl'),
    Column.text('editUrl'),
    Column.text('createdAt'),
    Column.text('updatedAt')
  ]),

  // ─── IcalFeed Table ───
  Table('IcalFeed', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'),
    Column.text('channel'),
    Column.text('type'),
    Column.text('name'),
    Column.text('url'),
    Column.text('icsText'),
    Column.text('lastSyncAt'),
    Column.text('lastEtag'),
    Column.text('lastModified'),
    Column.text('lastError'),
    Column.text('createdAt'),
    Column.text('updatedAt')
  ]),

  // ─── UnitContent Table (for Content screen) ───
  Table('UnitContent', [
    Column.text('id'), // PRIMARY KEY
    Column.text('unitId'), // Foreign Key - UNIQUE
    Column.text('title'),
    Column.text('description'),
    Column.text('houseRules'),
    Column.text('checkInInfo'),
    Column.text('checkOutInfo'),
    Column.text('amenities'), // JSON array
    Column.text('images'), // JSON array
    Column.text('locationNote'),
    Column.text('address'),
    Column.text('guestCapacity'),
    Column.text('propertyHighlights'),
    Column.text('nearbyPlaces'),
    Column.text('damageDeposit'),
    Column.text('cancellationPolicy'),
    Column.text('createdAt'),
    Column.text('updatedAt')
  ])
]);
