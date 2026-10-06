/// A business that pays the agency every month.
enum ClientStatus {
  active('Active'),
  paused('Paused'),
  ended('Ended');

  const ClientStatus(this.label);
  final String label;
}

/// One month's payment.
class Payment {
  const Payment({required this.month, required this.amount, required this.paidOn, this.note = ''});

  /// The billing month it pays for, "YYYY-MM".
  final String month;
  final double amount;
  final DateTime paidOn;
  final String note;

  Map<String, dynamic> toJson() => {
        'month': month,
        'amount': amount,
        'paidOn': paidOn.toIso8601String(),
        'note': note,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        month: (j['month'] as String?) ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        paidOn: DateTime.tryParse((j['paidOn'] as String?) ?? '') ?? DateTime.now(),
        note: (j['note'] as String?) ?? '',
      );
}

class Client {
  const Client({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.services = const [],
    this.monthlyFee = 0,
    this.currency = 'BDT',
    this.billingDay = 1,
    required this.startDate,
    this.status = ClientStatus.active,
    this.notes = '',
    this.payments = const [],
    this.leadId = '',
  });

  final String id;
  final String name;
  final String contactPerson;

  /// WhatsApp number with country code.
  final String phone;
  final String email;

  /// Service names, e.g. "Website Design", "Facebook Ads".
  final List<String> services;
  final double monthlyFee;
  final String currency;

  /// Day of the month the fee is due (1–28; 31 means the last day).
  final int billingDay;
  final DateTime startDate;
  final ClientStatus status;
  final String notes;
  final List<Payment> payments;

  /// The lead it came from, if any.
  final String leadId;

  bool isPaid(String month) => payments.any((p) => p.month == month);

  Client copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    List<String>? services,
    double? monthlyFee,
    String? currency,
    int? billingDay,
    DateTime? startDate,
    ClientStatus? status,
    String? notes,
    List<Payment>? payments,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        services: services ?? this.services,
        monthlyFee: monthlyFee ?? this.monthlyFee,
        currency: currency ?? this.currency,
        billingDay: billingDay ?? this.billingDay,
        startDate: startDate ?? this.startDate,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        payments: payments ?? this.payments,
        leadId: leadId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'services': services,
        'monthlyFee': monthlyFee,
        'currency': currency,
        'billingDay': billingDay,
        'startDate': startDate.toIso8601String(),
        'status': status.name,
        'notes': notes,
        'payments': payments.map((p) => p.toJson()).toList(),
        'leadId': leadId,
      };

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        contactPerson: (j['contactPerson'] as String?) ?? '',
        phone: (j['phone'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        services: (j['services'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        monthlyFee: (j['monthlyFee'] as num?)?.toDouble() ?? 0,
        currency: (j['currency'] as String?) ?? 'BDT',
        billingDay: (j['billingDay'] as num?)?.toInt() ?? 1,
        startDate: DateTime.tryParse((j['startDate'] as String?) ?? '') ?? DateTime.now(),
        status: ClientStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => ClientStatus.active),
        notes: (j['notes'] as String?) ?? '',
        payments: (j['payments'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Payment.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        leadId: (j['leadId'] as String?) ?? '',
      );
}
