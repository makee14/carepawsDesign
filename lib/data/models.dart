import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

enum Species { dog, cat }

Species speciesFrom(String s) =>
    s.toLowerCase() == 'cat' ? Species.cat : Species.dog;

@immutable
class Vital {
  const Vital({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.note,
  });
  final String label;
  final String value;
  final String unit;
  final String icon;
  final String? note;
}

@immutable
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.petId,
    required this.date,
    required this.title,
    required this.detail,
    required this.role,
    required this.staffName,
  });
  final String id;
  final String petId;
  final DateTime date;
  final String title;
  final String detail;
  final StaffRole role;
  final String staffName;
}

@immutable
class PetDoc {
  const PetDoc({
    required this.name,
    required this.kind,
    required this.date,
    required this.size,
    this.previewAsset,
  });
  final String name;
  final String kind;
  final DateTime date;
  final int size;

  /// Bundled image asset shown as the real document preview (B18). Null for
  /// documents with no scanned copy — those keep the placeholder tile.
  final String? previewAsset;
}

@immutable
class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    required this.birthDate,
    required this.weightKg,
    this.heightCm,
    this.lengthCm,
    required this.color,
    required this.microchip,
    required this.allergies,
    required this.vitals,
    required this.timeline,
    required this.docs,
    this.photo,
  });

  final String id;
  final String name;
  final Species species;
  final String breed;
  final String sex;
  final DateTime birthDate;
  final double weightKg;

  /// Optional clinic measurements. Null means "never recorded" — the UI
  /// hides the tile instead of inventing a value.
  final double? heightCm;
  final double? lengthCm;

  final Color color;
  final String microchip;
  final List<String> allergies;
  final List<Vital> vitals;
  final List<TimelineEntry> timeline;
  final List<PetDoc> docs;

  /// Owner-chosen portrait. Null falls back to the generated art.
  final Uint8List? photo;

  bool get hasPhoto => photo != null && photo!.isNotEmpty;

  /// Deterministic portrait palette so pet cards read instantly.
  Color get tint => color;

  /// Stable, human-readable patient ID derived from the record id
  /// (e.g. CP-0002PT). A manual digit fold, not hashCode — String.hashCode
  /// is not guaranteed stable across runs, and this code is shown to the
  /// clinic as the pet's identity.
  String get petCode {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0xFFFFFF;
    }
    return 'CP-${h.toRadixString(36).toUpperCase().padLeft(6, '0')}';
  }

  String get ageLabel {
    final now = DateTime.now();
    int y = now.year - birthDate.year;
    int m = now.month - birthDate.month;
    if (now.day < birthDate.day) m--;
    if (m < 0) {
      y--;
      m += 12;
    }
    if (y <= 0) return '$m mo old';
    return '$y yr old';
  }
}

enum StaffRole { vet, vetAssistant, groomer }

extension StaffRoleX on StaffRole {
  String get label => switch (this) {
    StaffRole.vet => 'Veterinarian',
    StaffRole.vetAssistant => 'Vet Assistant',
    StaffRole.groomer => 'Groomer',
  };
  String get short => switch (this) {
    StaffRole.vet => 'Vet',
    StaffRole.vetAssistant => 'Assistant',
    StaffRole.groomer => 'Groomer',
  };
  String get chip => switch (this) {
    StaffRole.vet => 'vet',
    StaffRole.vetAssistant => 'vet assistant',
    StaffRole.groomer => 'groomer',
  };
}

@immutable
class Staff {
  const Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.years,
    required this.initials,
    required this.focus,
  });
  final String id;
  final String name;
  final StaffRole role;
  final int years;
  final String initials;
  final String focus;

  String get firstName => name.split(' ').first;
}

@immutable
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.blurb,
    required this.icon,
    required this.durationMinutes,
    required this.price,
    required this.role,
    this.priceNote,
    this.grooming = false,
    this.routine = true,
  });
  final String id;
  final String name;
  final String blurb;
  final String icon;
  final int durationMinutes;
  final double price;
  final StaffRole role;

  /// "estimated" / "starting from" — grooming uses estimated pricing.
  final String? priceNote;
  final bool grooming;
  final bool routine;

  String get durationLabel {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    if (h == 0) return '$m min';
    if (m == 0) return '$h hr';
    return '$h hr $m min';
  }
}

enum ApptStatus {
  confirmed,
  requestPending,
  booked,
  beingGroomed,
  readyForPickup,
  completed,
  cancelled,
}

extension ApptStatusX on ApptStatus {
  /// Text status — never colour-only.
  String get label => switch (this) {
    ApptStatus.confirmed => 'Confirmed',
    ApptStatus.requestPending => 'Request sent — awaiting clinic confirmation',
    ApptStatus.booked => 'Booked',
    ApptStatus.beingGroomed => 'Being groomed',
    ApptStatus.readyForPickup => 'Ready for pickup',
    ApptStatus.completed => 'Completed',
    ApptStatus.cancelled => 'Cancelled',
  };
  String get short => switch (this) {
    ApptStatus.requestPending => 'Request pending',
    _ => label,
  };
  bool get isActive => const {
    ApptStatus.confirmed,
    ApptStatus.requestPending,
    ApptStatus.booked,
    ApptStatus.beingGroomed,
    ApptStatus.readyForPickup,
  }.contains(this);
}

@immutable
class GroomingIntake {
  const GroomingIntake({
    required this.size,
    required this.coat,
    this.notes = '',
  });
  final String size;
  final String coat;
  final String notes;
}

@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.petId,
    required this.serviceId,
    required this.staffId,
    required this.start,
    required this.durationMinutes,
    required this.status,
    required this.price,
    this.sickPet = false,
    this.grooming,
    this.triageSummary,
  });
  final String id;
  final String petId;
  final String serviceId;
  final String staffId;
  final DateTime start;
  final int durationMinutes;
  final ApptStatus status;
  final double price;
  final bool sickPet;
  final GroomingIntake? grooming;
  final String? triageSummary;

  DateTime get end => start.add(Duration(minutes: durationMinutes));
}

enum PetNeed { all, food, medicine, grooming, toy, accessory }

extension PetNeedX on PetNeed {
  String get label => switch (this) {
    PetNeed.all => 'All',
    PetNeed.food => 'Food',
    PetNeed.medicine => 'Medicine',
    PetNeed.grooming => 'Grooming',
    PetNeed.toy => 'Toys',
    PetNeed.accessory => 'Accessories',
  };
}

@immutable
class Prescription {
  const Prescription({
    required this.id,
    required this.productId,
    required this.vetName,
    required this.issued,
    required this.expires,
    required this.refills,
  });
  final String id;
  final String productId;
  final String vetName;
  final DateTime issued;
  final DateTime expires;
  final int refills;
  bool activeAt(DateTime now) => now.isBefore(expires) && refills > 0;
}

@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.price,
    required this.stock,
    required this.species,
    required this.need,
    required this.icon,
    required this.art,
    this.restricted = false,
    this.gallery = const [],
  });
  final String id;
  final String name;
  final String tagline;
  final String description;
  final double price;
  final int stock;
  final List<Species> species;
  final PetNeed need;
  final String icon;
  final int art;
  final bool restricted;
  final List<int> gallery;
  bool get inStock => stock > 0;
}

@immutable
class CartLine {
  const CartLine(this.productId, this.qty);
  final String productId;
  final int qty;
  CartLine copyWith({int? qty}) => CartLine(productId, qty ?? this.qty);
}

enum OrderStatus { pendingPayment, paid, pickedUp, cancelled }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pendingPayment => 'Pending payment',
    OrderStatus.paid => 'Paid — ready for pickup',
    OrderStatus.pickedUp => 'Picked up',
    OrderStatus.cancelled => 'Cancelled',
  };
}

@immutable
class OrderLine {
  const OrderLine(this.productId, this.qty, this.unitPrice);
  final String productId;
  final int qty;
  final double unitPrice;
  double get total => qty * unitPrice;
}

@immutable
class Order {
  const Order({
    required this.id,
    required this.placedAt,
    required this.lines,
    required this.status,
    required this.pickupCode,
    required this.method,
    this.refunded = false,
  });
  final String id;
  final DateTime placedAt;
  final List<OrderLine> lines;
  final OrderStatus status;
  final String pickupCode;
  final String method;
  final bool refunded;
  double get total => lines.fold(0, (a, b) => a + b.total);
  Order copyWith({OrderStatus? status, bool? refunded}) => Order(
    id: id,
    placedAt: placedAt,
    lines: lines,
    status: status ?? this.status,
    pickupCode: pickupCode,
    method: method,
    refunded: refunded ?? this.refunded,
  );
}

@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.on,
    required this.kind,
  });
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final bool on;
  final ReminderKind kind;
  Reminder copyWith({bool? on}) => Reminder(
    id: id,
    title: title,
    subtitle: subtitle,
    icon: icon,
    on: on ?? this.on,
    kind: kind,
  );
}

enum ReminderKind { medication, vaccine, appointment, grooming }

enum ChatAuthor { ai, vetAssistant, vet, groomer }

@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.author,
    required this.text,
    required this.at,
    this.sentByMe = false,
    this.petId,
    this.kind = ChatKind.text,
    this.triageSummary,
    this.imageBytes,
  });
  final String id;
  final String threadId;
  final ChatAuthor author;
  final String text;
  final DateTime at;
  final bool sentByMe;
  final String? petId;
  final ChatKind kind;
  final String? triageSummary;

  /// Set for [ChatKind.image]: the downscaled photo bytes. Text stays empty.
  final Uint8List? imageBytes;
}

enum ChatKind { text, image, triageHandoff, system }

@immutable
class Thread {
  const Thread({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pinned,
    required this.isAi,
    this.badge,
    this.offline = false,
  });
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final bool pinned;
  final bool isAi;
  final String? badge;
  final bool offline;
}

enum TriageRoute { book, chat, homeCare, emergency }

@immutable
class TriageResult {
  const TriageResult({
    required this.route,
    required this.title,
    required this.summary,
    required this.urgency,
    this.bullets = const [],
    this.redFlags = const [],
    this.homeCare = const [],
    this.nextStep,
  });
  final TriageRoute route;
  final String title;
  final String summary;
  final int urgency; // 0 = mild, 1 = moderate, 2 = urgent
  final List<String> bullets;
  final List<String> redFlags;
  final List<String> homeCare;
  final String? nextStep;

  String get urgencyLabel => switch (urgency) {
    2 => 'Needs care soon',
    1 => 'Needs a visit',
    _ => 'Can be managed at home',
  };
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.icon,
    this.read = false,
  });
  final String id;
  final String title;
  final String body;
  final DateTime at;
  final String icon;
  final bool read;
  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    title: title,
    body: body,
    at: at,
    icon: icon,
    read: read ?? this.read,
  );
}

/// Promo/announcement for the Home carousel. Stream A.
///
/// Bundled seed data only — there is no ad backend (orchestrator ruling).
/// `route` is a destination id resolved by the Home screen ('book', 'shop',
/// 'triage', ...); `art` indexes the generated-art pattern (cf. Product.art).
@immutable
class Promo {
  const Promo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.art,
    required this.ctaLabel,
    required this.route,
  });
  final String id;
  final String title;
  final String subtitle;
  final int art;
  final String ctaLabel;
  final String route;
}
