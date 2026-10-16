import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'prefs.dart';

import '../data/models.dart';

/// Persists the user-owned datasets (pets, appointments, reminders, orders,
/// chat messages, notifications, prescriptions, cart, health checks) per
/// account, so everything the user saves survives backgrounding, process
/// death and cold starts. Each dataset is one JSON document under
/// `carepaws.data.<account>.<dataset>`.
///
/// Photos are NOT in here: binary portraits stay in [PhotoStore] (keyed by pet
/// id) and are re-attached by `AppStore.loadPhotos` after the pet list is
/// rehydrated. The clinic product catalog is also excluded — it is the
/// clinic's shared data and always comes from [Seed].
class DatasetStore {
  const DatasetStore._();

  static const _prefix = 'carepaws.data';

  static const pets = 'pets';
  static const appointments = 'appointments';
  static const reminders = 'reminders';
  static const orders = 'orders';
  static const messages = 'messages';
  static const notifications = 'notifications';
  static const prescriptions = 'prescriptions';
  static const cart = 'cart';
  static const healthChecks = 'healthChecks';

  static String _key(String account, String dataset) =>
      '$_prefix.$account.$dataset';

  static Future<String?> read(String account, String dataset) async {
    final p = await openPrefs();
    return p?.getString(_key(account, dataset));
  }

  static Future<void> write(String account, String dataset, String json) async {
    final p = await openPrefs();
    await p?.setString(_key(account, dataset), json);
  }

  // ------------------------------------------------------------ raw codecs
  static String _envelope(Iterable<Map<String, Object?>> items) =>
      jsonEncode({'v': 1, 'items': items.toList()});

  /// Decodes one dataset document. Returns null when nothing was stored or
  /// the document is corrupt (caller falls back to seeds/empty); drops only
  /// the individual items that fail to parse.
  static List<Map<String, dynamic>>? _items(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final doc = jsonDecode(raw);
      if (doc is! Map) return null;
      final items = doc['items'];
      if (items is! List) return null;
      return [
        for (final it in items)
          if (it is Map<String, dynamic>) it,
      ];
    } catch (_) {
      return null;
    }
  }

  static String _str(Map<String, dynamic> m, String k) =>
      m[k] is String ? m[k] as String : '';

  static String? _strOpt(Map<String, dynamic> m, String k) =>
      m[k] is String ? m[k] as String : null;

  static double _dbl(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toDouble() ?? 0;

  static int _int(Map<String, dynamic> m, String k) =>
      (m[k] as num?)?.toInt() ?? 0;

  static bool _bool(Map<String, dynamic> m, String k) => m[k] == true;

  static DateTime _date(Map<String, dynamic> m, String k) => m[k] is String
      ? DateTime.tryParse(m[k] as String) ??
            DateTime.fromMillisecondsSinceEpoch(0)
      : DateTime.fromMillisecondsSinceEpoch(0);

  static List<String> _strList(Map<String, dynamic> m, String k) => [
    for (final v in (m[k] as List? ?? const []))
      if (v is String) v,
  ];

  static T _enumByName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    if (name != null) {
      for (final v in values) {
        if (v.name == name) return v;
      }
    }
    return fallback;
  }

  /// Decodes one dataset document into models, dropping the individual
  /// entries that fail to parse. The nine public decode* wrappers keep
  /// their names and signatures — only the identical loops collapse here.
  static List<T>? _decode<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = _items(raw);
    if (items == null) return null;
    final out = <T>[];
    for (final m in items) {
      try {
        out.add(fromJson(m));
      } catch (_) {
        // Corrupt entry — drop it, keep the rest.
      }
    }
    return out;
  }

  // ------------------------------------------------------------------ pets
  static Map<String, Object?> _petJson(Pet p) => {
    'id': p.id,
    'name': p.name,
    'species': p.species.name,
    'breed': p.breed,
    'sex': p.sex,
    'birthDate': p.birthDate.toIso8601String(),
    'weightKg': p.weightKg,
    'color': p.color.toARGB32(),
    'microchip': p.microchip,
    'allergies': p.allergies,
    'vitals': [
      for (final v in p.vitals)
        {
          'label': v.label,
          'value': v.value,
          'unit': v.unit,
          'icon': v.icon,
          'note': v.note,
        },
    ],
    'timeline': [
      for (final t in p.timeline)
        {
          'id': t.id,
          'petId': t.petId,
          'date': t.date.toIso8601String(),
          'title': t.title,
          'detail': t.detail,
          'role': t.role.name,
          'staffName': t.staffName,
        },
    ],
    'docs': [
      for (final d in p.docs)
        {
          'name': d.name,
          'kind': d.kind,
          'date': d.date.toIso8601String(),
          'size': d.size,
          'previewAsset': d.previewAsset,
        },
    ],
  };

  static Pet _petFromJson(Map<String, dynamic> m) => Pet(
    id: _str(m, 'id'),
    name: _str(m, 'name'),
    species: _enumByName(Species.values, m['species'] as String?, Species.dog),
    breed: _str(m, 'breed'),
    sex: _str(m, 'sex'),
    birthDate: _date(m, 'birthDate'),
    weightKg: _dbl(m, 'weightKg'),
    color: Color(_int(m, 'color')),
    microchip: _str(m, 'microchip'),
    allergies: _strList(m, 'allergies'),
    vitals: [
      for (final v in (m['vitals'] as List? ?? const []))
        if (v is Map<String, dynamic>)
          Vital(
            label: _str(v, 'label'),
            value: _str(v, 'value'),
            unit: _str(v, 'unit'),
            icon: _str(v, 'icon'),
            note: _strOpt(v, 'note'),
          ),
    ],
    timeline: [
      for (final t in (m['timeline'] as List? ?? const []))
        if (t is Map<String, dynamic>)
          TimelineEntry(
            id: _str(t, 'id'),
            petId: _str(t, 'petId'),
            date: _date(t, 'date'),
            title: _str(t, 'title'),
            detail: _str(t, 'detail'),
            role: _enumByName(
              StaffRole.values,
              t['role'] as String?,
              StaffRole.vetAssistant,
            ),
            staffName: _str(t, 'staffName'),
          ),
    ],
    docs: [
      for (final d in (m['docs'] as List? ?? const []))
        if (d is Map<String, dynamic>)
          PetDoc(
            name: _str(d, 'name'),
            kind: _str(d, 'kind'),
            date: _date(d, 'date'),
            size: _int(d, 'size'),
            previewAsset: _strOpt(d, 'previewAsset'),
          ),
    ],
  );

  static String encodePets(List<Pet> items) => _envelope(items.map(_petJson));

  static List<Pet>? decodePets(String? raw) => _decode(raw, _petFromJson);

  static Future<List<Pet>?> readPets(String account) async =>
      decodePets(await read(account, pets));

  static Future<void> writePets(String account, List<Pet> items) =>
      write(account, pets, encodePets(items));

  // ---------------------------------------------------------- appointments
  static Map<String, Object?> _apptJson(Appointment a) => {
    'id': a.id,
    'petId': a.petId,
    'serviceId': a.serviceId,
    'staffId': a.staffId,
    'start': a.start.toIso8601String(),
    'durationMinutes': a.durationMinutes,
    'status': a.status.name,
    'price': a.price,
    'sickPet': a.sickPet,
    'grooming': a.grooming == null
        ? null
        : {
            'size': a.grooming!.size,
            'coat': a.grooming!.coat,
            'notes': a.grooming!.notes,
          },
    'triageSummary': a.triageSummary,
  };

  static Appointment _apptFromJson(Map<String, dynamic> m) {
    final g = m['grooming'];
    return Appointment(
      id: _str(m, 'id'),
      petId: _str(m, 'petId'),
      serviceId: _str(m, 'serviceId'),
      staffId: _str(m, 'staffId'),
      start: _date(m, 'start'),
      durationMinutes: _int(m, 'durationMinutes'),
      status: _enumByName(
        ApptStatus.values,
        m['status'] as String?,
        ApptStatus.booked,
      ),
      price: _dbl(m, 'price'),
      sickPet: _bool(m, 'sickPet'),
      grooming: g is Map<String, dynamic>
          ? GroomingIntake(
              size: _str(g, 'size'),
              coat: _str(g, 'coat'),
              notes: _str(g, 'notes'),
            )
          : null,
      triageSummary: _strOpt(m, 'triageSummary'),
    );
  }

  static String encodeAppointments(List<Appointment> items) =>
      _envelope(items.map(_apptJson));

  static List<Appointment>? decodeAppointments(String? raw) =>
      _decode(raw, _apptFromJson);

  static Future<List<Appointment>?> readAppointments(String account) async =>
      decodeAppointments(await read(account, appointments));

  static Future<void> writeAppointments(
    String account,
    List<Appointment> items,
  ) => write(account, appointments, encodeAppointments(items));

  // ------------------------------------------------------------- reminders
  static Map<String, Object?> _reminderJson(Reminder r) => {
    'id': r.id,
    'title': r.title,
    'subtitle': r.subtitle,
    'icon': r.icon,
    'on': r.on,
    'kind': r.kind.name,
  };

  static Reminder _reminderFromJson(Map<String, dynamic> m) => Reminder(
    id: _str(m, 'id'),
    title: _str(m, 'title'),
    subtitle: _str(m, 'subtitle'),
    icon: _str(m, 'icon'),
    on: _bool(m, 'on'),
    kind: _enumByName(
      ReminderKind.values,
      m['kind'] as String?,
      ReminderKind.medication,
    ),
  );

  static String encodeReminders(List<Reminder> items) =>
      _envelope(items.map(_reminderJson));

  static List<Reminder>? decodeReminders(String? raw) =>
      _decode(raw, _reminderFromJson);

  static Future<List<Reminder>?> readReminders(String account) async =>
      decodeReminders(await read(account, reminders));

  static Future<void> writeReminders(String account, List<Reminder> items) =>
      write(account, reminders, encodeReminders(items));

  // ---------------------------------------------------------------- orders
  static Map<String, Object?> _orderJson(Order o) => {
    'id': o.id,
    'placedAt': o.placedAt.toIso8601String(),
    'lines': [
      for (final l in o.lines)
        {'productId': l.productId, 'qty': l.qty, 'unitPrice': l.unitPrice},
    ],
    'status': o.status.name,
    'pickupCode': o.pickupCode,
    'method': o.method,
    'refunded': o.refunded,
  };

  static Order _orderFromJson(Map<String, dynamic> m) => Order(
    id: _str(m, 'id'),
    placedAt: _date(m, 'placedAt'),
    lines: [
      for (final l in (m['lines'] as List? ?? const []))
        if (l is Map<String, dynamic>)
          OrderLine(_str(l, 'productId'), _int(l, 'qty'), _dbl(l, 'unitPrice')),
    ],
    status: _enumByName(
      OrderStatus.values,
      m['status'] as String?,
      OrderStatus.pendingPayment,
    ),
    pickupCode: _str(m, 'pickupCode'),
    method: _str(m, 'method'),
    refunded: _bool(m, 'refunded'),
  );

  static String encodeOrders(List<Order> items) =>
      _envelope(items.map(_orderJson));

  static List<Order>? decodeOrders(String? raw) => _decode(raw, _orderFromJson);

  static Future<List<Order>?> readOrders(String account) async =>
      decodeOrders(await read(account, orders));

  static Future<void> writeOrders(String account, List<Order> items) =>
      write(account, orders, encodeOrders(items));

  // --------------------------------------------------------------- messages
  static Map<String, Object?> _messageJson(ChatMessage m) => {
    'id': m.id,
    'threadId': m.threadId,
    'author': m.author.name,
    'text': m.text,
    'at': m.at.toIso8601String(),
    'sentByMe': m.sentByMe,
    'petId': m.petId,
    'kind': m.kind.name,
    'triageSummary': m.triageSummary,
    'image': m.imageBytes == null ? null : base64Encode(m.imageBytes!),
  };

  static ChatMessage _messageFromJson(Map<String, dynamic> m) {
    final img = m['image'];
    Uint8List? imageBytes;
    if (img is String && img.isNotEmpty) {
      try {
        imageBytes = base64Decode(img);
      } catch (_) {
        imageBytes = null;
      }
    }
    return ChatMessage(
      id: _str(m, 'id'),
      threadId: _str(m, 'threadId'),
      author: _enumByName(
        ChatAuthor.values,
        m['author'] as String?,
        ChatAuthor.vetAssistant,
      ),
      text: _str(m, 'text'),
      at: _date(m, 'at'),
      sentByMe: _bool(m, 'sentByMe'),
      petId: _strOpt(m, 'petId'),
      kind: _enumByName(ChatKind.values, m['kind'] as String?, ChatKind.text),
      triageSummary: _strOpt(m, 'triageSummary'),
      imageBytes: imageBytes,
    );
  }

  static String encodeMessages(List<ChatMessage> items) =>
      _envelope(items.map(_messageJson));

  static List<ChatMessage>? decodeMessages(String? raw) =>
      _decode(raw, _messageFromJson);

  static Future<List<ChatMessage>?> readMessages(String account) async =>
      decodeMessages(await read(account, messages));

  static Future<void> writeMessages(String account, List<ChatMessage> items) =>
      write(account, messages, encodeMessages(items));

  // --------------------------------------------------------- notifications
  static Map<String, Object?> _notificationJson(AppNotification n) => {
    'id': n.id,
    'title': n.title,
    'body': n.body,
    'at': n.at.toIso8601String(),
    'icon': n.icon,
    'read': n.read,
  };

  static AppNotification _notificationFromJson(Map<String, dynamic> m) =>
      AppNotification(
        id: _str(m, 'id'),
        title: _str(m, 'title'),
        body: _str(m, 'body'),
        at: _date(m, 'at'),
        icon: _str(m, 'icon'),
        read: _bool(m, 'read'),
      );

  static String encodeNotifications(List<AppNotification> items) =>
      _envelope(items.map(_notificationJson));

  static List<AppNotification>? decodeNotifications(String? raw) =>
      _decode(raw, _notificationFromJson);

  static Future<List<AppNotification>?> readNotifications(
    String account,
  ) async => decodeNotifications(await read(account, notifications));

  static Future<void> writeNotifications(
    String account,
    List<AppNotification> items,
  ) => write(account, notifications, encodeNotifications(items));

  // --------------------------------------------------------- prescriptions
  static Map<String, Object?> _prescriptionJson(Prescription p) => {
    'id': p.id,
    'productId': p.productId,
    'vetName': p.vetName,
    'issued': p.issued.toIso8601String(),
    'expires': p.expires.toIso8601String(),
    'refills': p.refills,
  };

  static Prescription _prescriptionFromJson(Map<String, dynamic> m) =>
      Prescription(
        id: _str(m, 'id'),
        productId: _str(m, 'productId'),
        vetName: _str(m, 'vetName'),
        issued: _date(m, 'issued'),
        expires: _date(m, 'expires'),
        refills: _int(m, 'refills'),
      );

  static String encodePrescriptions(List<Prescription> items) =>
      _envelope(items.map(_prescriptionJson));

  static List<Prescription>? decodePrescriptions(String? raw) =>
      _decode(raw, _prescriptionFromJson);

  static Future<List<Prescription>?> readPrescriptions(String account) async =>
      decodePrescriptions(await read(account, prescriptions));

  static Future<void> writePrescriptions(
    String account,
    List<Prescription> items,
  ) => write(account, prescriptions, encodePrescriptions(items));

  // ------------------------------------------------------------------ cart
  static Map<String, Object?> _cartJson(CartLine c) => {
    'productId': c.productId,
    'qty': c.qty,
  };

  static CartLine _cartFromJson(Map<String, dynamic> m) =>
      CartLine(_str(m, 'productId'), _int(m, 'qty'));

  static String encodeCart(List<CartLine> items) =>
      _envelope(items.map(_cartJson));

  static List<CartLine>? decodeCart(String? raw) => _decode(raw, _cartFromJson);

  static Future<List<CartLine>?> readCart(String account) async =>
      decodeCart(await read(account, cart));

  static Future<void> writeCart(String account, List<CartLine> items) =>
      write(account, cart, encodeCart(items));

  // ---------------------------------------------------------- health checks
  static Map<String, Object?> _healthResultJson(HealthCheckResult r) => {
    'id': r.id,
    'petId': r.petId,
    'summary': r.summary,
    'urgency': r.urgency.name,
    'recommendation': r.recommendation,
    'route': r.route.name,
    'sections': [
      for (final s in r.sections) {'title': s.title, 'body': s.body},
    ],
    'answers': [
      for (final a in r.answers)
        {
          'questionId': a.questionId,
          'question': a.question,
          'answer': a.answer,
        },
    ],
    'createdAt': r.createdAt.toIso8601String(),
  };

  static HealthCheckResult _healthResultFromJson(Map<String, dynamic> m) {
    final sections = <HealthSection>[];
    for (final s in (m['sections'] as List? ?? const [])) {
      if (s is Map<String, dynamic>) {
        sections.add(
          HealthSection(title: _str(s, 'title'), body: _str(s, 'body')),
        );
      }
    }
    final answers = <HealthAnswer>[];
    for (final a in (m['answers'] as List? ?? const [])) {
      if (a is Map<String, dynamic>) {
        answers.add(
          HealthAnswer(
            questionId: _str(a, 'questionId'),
            question: _str(a, 'question'),
            answer: _str(a, 'answer'),
          ),
        );
      }
    }
    return HealthCheckResult(
      id: _str(m, 'id'),
      petId: _str(m, 'petId'),
      summary: _str(m, 'summary'),
      urgency: _enumByName(
        Urgency.values,
        m['urgency'] as String?,
        Urgency.low,
      ),
      recommendation: _str(m, 'recommendation'),
      route: _enumByName(
        TriageRoute.values,
        m['route'] as String?,
        TriageRoute.homeCare,
      ),
      sections: sections,
      answers: answers,
      createdAt: _date(m, 'createdAt'),
    );
  }

  static String encodeHealthChecks(List<HealthCheckResult> items) =>
      _envelope(items.map(_healthResultJson));

  static List<HealthCheckResult>? decodeHealthChecks(String? raw) =>
      _decode(raw, _healthResultFromJson);

  static Future<List<HealthCheckResult>?> readHealthChecks(
    String account,
  ) async => decodeHealthChecks(await read(account, healthChecks));

  static Future<void> writeHealthChecks(
    String account,
    List<HealthCheckResult> items,
  ) => write(account, healthChecks, encodeHealthChecks(items));
}
