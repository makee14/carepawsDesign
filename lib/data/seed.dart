import 'package:flutter/widgets.dart';

import 'clinic.dart';
import 'models.dart';

/// All sample content. No lorem ipsum, no placeholder copy.
class Seed {
  const Seed._();

  static final DateTime now = DateTime(2026, 10, 13, 9, 40);
  static DateTime at(int d, int h, [int m = 0]) =>
      DateTime(2026, 10, 13 + d, h, m);

  // ------------------------------------------------------------------ pets
  static final biscuit = Pet(
    id: 'p1',
    name: 'Biscuit',
    species: Species.dog,
    breed: 'Golden Retriever',
    sex: 'Male',
    birthDate: DateTime(2021, 4, 18),
    weightKg: 31.4,
    color: Color(0xFFE4843E),
    microchip: 'PH-1184-20773',
    allergies: ['Chicken'],
    vitals: [
      Vital(label: 'Weight', value: '31.4', unit: 'kg', icon: 'scale'),
      Vital(label: 'Temperature', value: '38.4', unit: '°C', icon: 'fire'),
      Vital(label: 'Heart rate', value: '84', unit: 'bpm', icon: 'heartPulse'),
      Vital(label: 'Weight trend', value: '+0.4', unit: 'kg', icon: 'arrowUp'),
    ],
    timeline: [
      TimelineEntry(
        id: 't1',
        petId: 'p1',
        date: DateTime(2026, 9, 25),
        title: 'Annual health check',
        detail:
            'Weight holding steady. Heart and lungs clear. Continue current food and keep the weekly joint walk.',
        role: StaffRole.vet,
        staffName: 'Dr. Rafael Alvarez',
      ),
      TimelineEntry(
        id: 't2',
        petId: 'p1',
        date: DateTime(2026, 9, 12),
        title: 'Nail trim and paw pads checked',
        detail:
            'Paw pads healthy, nails trimmed short. No cracks or tenderness reported.',
        role: StaffRole.groomer,
        staffName: 'Ana Reyes',
      ),
      TimelineEntry(
        id: 't3',
        petId: 'p1',
        date: DateTime(2026, 8, 30),
        title: 'Anti-tick drops applied',
        detail:
            'Spot-on applied between the shoulder blades. Next dose due in 4 weeks.',
        role: StaffRole.vetAssistant,
        staffName: 'Miguel Cruz',
      ),
    ],
    docs: [
      PetDoc(
        name: 'Rabies certificate',
        kind: 'Certificate',
        date: DateTime(2026, 3, 2),
        size: 284,
      ),
      PetDoc(
        name: 'Vaccination record 2026',
        kind: 'Record',
        date: DateTime(2026, 3, 2),
        size: 412,
      ),
      PetDoc(
        name: 'Health plan summary',
        kind: 'PDF',
        date: DateTime(2026, 9, 25),
        size: 198,
      ),
    ],
  );

  static final mochi = Pet(
    id: 'p2',
    name: 'Mochi',
    species: Species.cat,
    breed: 'British Shorthair',
    sex: 'Female',
    birthDate: DateTime(2023, 1, 9),
    weightKg: 4.6,
    color: Color(0xFF9B8A76),
    microchip: 'PH-9920-44118',
    allergies: [],
    vitals: [
      Vital(label: 'Weight', value: '4.6', unit: 'kg', icon: 'scale'),
      Vital(label: 'Temperature', value: '38.8', unit: '°C', icon: 'fire'),
      Vital(label: 'Heart rate', value: '172', unit: 'bpm', icon: 'heartPulse'),
      Vital(label: 'Weight trend', value: '-0.1', unit: 'kg', icon: 'arrowUp'),
    ],
    timeline: [
      TimelineEntry(
        id: 't4',
        petId: 'p2',
        date: DateTime(2026, 10, 1),
        title: 'Fur matting removed',
        detail:
            'Light matting behind the ears. Suggested weekly brushing and a grooming slot before coat thickens.',
        role: StaffRole.groomer,
        staffName: 'Ana Reyes',
      ),
      TimelineEntry(
        id: 't5',
        petId: 'p2',
        date: DateTime(2026, 7, 19),
        title: 'Vaccination booster',
        detail: 'Triose vaccine given. Next booster due July 2027.',
        role: StaffRole.vet,
        staffName: 'Dr. Rafael Alvarez',
      ),
    ],
    docs: [
      PetDoc(
        name: 'Vaccination record 2026',
        kind: 'Record',
        date: DateTime(2026, 7, 19),
        size: 336,
      ),
      PetDoc(name: 'Spay record', kind: 'Certificate', date: DateTime(2024, 5, 3), size: 210),
    ],
  );

  static List<Pet> get pets => [biscuit, mochi];

  // ----------------------------------------------------------------- staff
  static final vet = Staff(
    id: 's1',
    name: 'Dr. Rafael Alvarez',
    role: StaffRole.vet,
    years: 14,
    initials: 'RA',
    focus: 'Internal medicine, dermatology',
  );
  static final assistant = Staff(
    id: 's2',
    name: 'Miguel Cruz',
    role: StaffRole.vetAssistant,
    years: 6,
    initials: 'MC',
    focus: 'Vaccinations, microchipping, client care',
  );
  static final groomer = Staff(
    id: 's3',
    name: 'Ana Reyes',
    role: StaffRole.groomer,
    years: 9,
    initials: 'AR',
    focus: 'Breed-standard cuts, desensitising',
  );
  static List<Staff> get staff => [vet, assistant, groomer];

  // -------------------------------------------------------------- services
  static const services = [
    Service(
      id: 'sv1',
      name: 'Vet Consultation',
      blurb: 'Full physical exam with the veterinarian',
      icon: 'stethoscope',
      durationMinutes: 30,
      price: 850,
      role: StaffRole.vet,
    ),
    Service(
      id: 'sv2',
      name: 'Vaccination',
      blurb: 'Booster or first dose, with a signed certificate',
      icon: 'syringe',
      durationMinutes: 20,
      price: 700,
      role: StaffRole.vetAssistant,
    ),
    Service(
      id: 'sv3',
      name: 'Health Checkup',
      blurb: 'Weight, vitals and review of ongoing conditions',
      icon: 'heartPulse',
      durationMinutes: 30,
      price: 650,
      role: StaffRole.vet,
    ),
    Service(
      id: 'sv4',
      name: 'Full Grooming',
      blurb: 'Bath, blow dry, haircut, nails and ears',
      icon: 'scissors',
      durationMinutes: 120,
      price: 1450,
      priceNote: 'estimated',
      role: StaffRole.groomer,
      grooming: true,
    ),
    Service(
      id: 'sv5',
      name: 'Bath & Brush',
      blurb: 'Deep clean and blow dry for double coats',
      icon: 'droplet',
      durationMinutes: 60,
      price: 750,
      priceNote: 'starting from',
      role: StaffRole.groomer,
      grooming: true,
    ),
    Service(
      id: 'sv6',
      name: 'Nail Trim & Ears',
      blurb: 'Quick maintenance visit, no sedation needed',
      icon: 'tooth',
      durationMinutes: 20,
      price: 350,
      role: StaffRole.groomer,
    ),
    Service(
      id: 'sv7',
      name: 'Microchipping',
      blurb: 'ISO chip and registry activation',
      icon: 'barcode',
      durationMinutes: 15,
      price: 1200,
      role: StaffRole.vetAssistant,
    ),
  ];

  static Service service(String id) => services.firstWhere((s) => s.id == id);

  // ----------------------------------------------------------- appointments
  static List<Appointment> get appointments => [
    Appointment(
      id: 'a1',
      petId: 'p1',
      serviceId: 'sv1',
      staffId: 's1',
      start: at(3, 10, 0),
      durationMinutes: 30,
      status: ApptStatus.confirmed,
      price: 850,
    ),
    Appointment(
      id: 'a2',
      petId: 'p2',
      serviceId: 'sv4',
      staffId: 's3',
      start: at(6, 9, 0),
      durationMinutes: 120,
      status: ApptStatus.booked,
      price: 1450,
      grooming: GroomingIntake(
        size: 'Medium (4.6 kg)',
        coat: 'Short, dense, healthy',
        notes: 'Please trim the fur behind the ears — mild matting last time.',
      ),
    ),
    Appointment(
      id: 'a3',
      petId: 'p1',
      serviceId: 'sv5',
      staffId: 's3',
      start: at(-1, 11, 0),
      durationMinutes: 60,
      status: ApptStatus.completed,
      price: 750,
      grooming: GroomingIntake(size: 'Large (31.4 kg)', coat: 'Double coat, shedding'),
    ),
    Appointment(
      id: 'a4',
      petId: 'p2',
      serviceId: 'sv6',
      staffId: 's3',
      start: at(-16, 15, 30),
      durationMinutes: 20,
      status: ApptStatus.completed,
      price: 350,
    ),
    Appointment(
      id: 'a5',
      petId: 'p1',
      serviceId: 'sv2',
      staffId: 's2',
      start: at(-40, 9, 0),
      durationMinutes: 20,
      status: ApptStatus.completed,
      price: 700,
    ),
  ];

  // --------------------------------------------------------------- products
  static final products = [
    Product(
      id: 'pr1',
      name: 'Grass-fed Lamb & Oat Adult Dog Food',
      tagline: '2 kg · chicken free',
      description:
          'Single-protein lamb recipe with oats for sensitive stomachs. No chicken, no fillers, and formulated for large-breed adults. Transition over seven days when switching from another food.',
      price: 1240,
      stock: 18,
      species: [Species.dog],
      need: PetNeed.food,
      icon: 'bag',
      art: 0,
      gallery: [0, 1, 2, 4],
    ),
    Product(
      id: 'pr2',
      name: 'Salmon & Sweet Potato Kitten Food',
      tagline: '400 g pouch',
      description:
          'Wet pouch for kittens and small breeds. High in protein with taurine for heart and eye health. Serve at room temperature or slightly warmed.',
      price: 285,
      stock: 40,
      species: [Species.cat],
      need: PetNeed.food,
      icon: 'bag',
      art: 1,
      gallery: [1, 2, 0],
    ),
    Product(
      id: 'pr3',
      name: 'Freeze-dried Chicken Treats',
      tagline: '100 g · 8 ingredients',
      description:
          'Single-ingredient treats you can break into small pieces for training. Freeze-dried with nothing added, so it also works as a high-value reward during nail trims.',
      price: 320,
      stock: 24,
      species: [Species.dog, Species.cat],
      need: PetNeed.food,
      icon: 'bone',
      art: 2,
    ),
    Product(
      id: 'pr4',
      name: 'Oatmeal & Honey Pet Shampoo',
      tagline: '400 ml · tear free',
      description:
          'Gentle pH-balanced wash for dogs and cats. Colloidal oatmeal calms itchy skin and the honey complex helps restore the coat barrier after grooming.',
      price: 390,
      stock: 0,
      species: [Species.dog, Species.cat],
      need: PetNeed.grooming,
      icon: 'droplet',
      art: 3,
      gallery: [3, 4, 1],
    ),
    Product(
      id: 'pr5',
      name: 'Claw & Whisker Grooming Clippers',
      tagline: 'Low noise · 5 guards',
      description:
          'A quiet, low-vibration clipper that suits pets who are sensitive to grooming noise. Comes with five guide combs and a USB-C charging base.',
      price: 2190,
      stock: 6,
      species: [Species.dog, Species.cat],
      need: PetNeed.grooming,
      icon: 'scissors',
      art: 4,
    ),
    Product(
      id: 'pr6',
      name: 'Flea & Tick Spot-On (3 doses)',
      tagline: 'Prescription required',
      description:
          'Monthly spot-on for dogs over 20 kg. Needs an active prescription signed by the veterinarian — the clinic can issue one at your next visit.',
      price: 1150,
      stock: 9,
      species: [Species.dog],
      need: PetNeed.medicine,
      icon: 'pill',
      art: 5,
      restricted: true,
      gallery: [5, 2, 3],
    ),
    Product(
      id: 'pr7',
      name: 'Rope Knot Chew Toy',
      tagline: 'Medium · dishwasher safe',
      description:
          'Durable cotton-rope toy with a knot at each end for tugging games. Supervise play and replace the toy once the fibres start to loosen.',
      price: 295,
      stock: 31,
      species: [Species.dog],
      need: PetNeed.toy,
      icon: 'bone',
      art: 6,
    ),
    Product(
      id: 'pr8',
      name: 'Reflective Walking Harness',
      tagline: 'S–XL · adjustable fit',
      description:
          'Padded harness with a reflective stripe for night walks and a quick-release buckle. Machine washable on a gentle cycle.',
      price: 760,
      stock: 12,
      species: [Species.dog, Species.cat],
      need: PetNeed.accessory,
      icon: 'shield',
      art: 7,
      gallery: [7, 6, 0],
    ),
  ];

  static Product product(String id) => products.firstWhere((p) => p.id == id);

  static final prescriptions = [
    Prescription(
      id: 'rx1',
      productId: 'pr6',
      vetName: 'Dr. Rafael Alvarez',
      issued: DateTime(2026, 9, 25),
      expires: DateTime(2027, 9, 25),
      refills: 2,
    ),
  ];

  static final orders = [
    Order(
      id: 'o1',
      placedAt: DateTime(2026, 10, 6, 14, 12),
      lines: [
        OrderLine('pr3', 2, 320),
        OrderLine('pr2', 3, 285),
      ],
      status: OrderStatus.paid,
      pickupCode: 'PC-4820',
      method: 'GCash',
    ),
  ];

  // -------------------------------------------------------------- reminders
  static List<Reminder> get reminders => [
    const Reminder(
      id: 'r1',
      title: 'Medications',
      subtitle: 'Biscuit — joint supplement, 8:00 AM',
      icon: 'pill',
      on: true,
      kind: ReminderKind.medication,
    ),
    const Reminder(
      id: 'r2',
      title: 'Vaccine due dates',
      subtitle: 'Mochi — booster due July 2027',
      icon: 'syringe',
      on: true,
      kind: ReminderKind.vaccine,
    ),
    const Reminder(
      id: 'r3',
      title: 'Appointments 24h + 2h',
      subtitle: 'Biscuit — vet consult on 16 Oct',
      icon: 'calendar',
      on: true,
      kind: ReminderKind.appointment,
    ),
    const Reminder(
      id: 'r4',
      title: 'Grooming rebook',
      subtitle: 'Suggest rebooking every 8 weeks',
      icon: 'scissors',
      on: false,
      kind: ReminderKind.grooming,
    ),
  ];

  static List<AppNotification> get notifications => [
    AppNotification(
      id: 'n1',
      title: 'Appointment confirmed',
      body: 'Biscuit · Vet Consultation · Thu 16 Oct, 10:00 AM with Dr. Alvarez.',
      at: DateTime(2026, 10, 12, 9, 2),
      icon: 'calendar',
    ),
    AppNotification(
      id: 'n2',
      title: 'Grooming intake saved',
      body: 'Mochi · Full Grooming on Tue 20 Oct. Ana Reyes has your intake notes.',
      at: DateTime(2026, 10, 11, 18, 30),
      icon: 'scissors',
    ),
    AppNotification(
      id: 'n3',
      title: 'Prescription renewed',
      body: 'Flea & Tick Spot-On is active for Biscuit until 25 Sep 2027.',
      at: DateTime(2026, 10, 9, 11, 15),
      icon: 'shield',
    ),
  ];

  // ------------------------------------------------------------------ chat
  static const aiThread = Thread(
    id: 'th_ai',
    title: 'CarePaws AI',
    subtitle: 'Always available · answers general pet-care questions',
    icon: 'sparkle',
    pinned: true,
    isAi: true,
    badge: 'Always available',
  );
  static const clinicThread = Thread(
    id: 'th_clinic',
    title: 'Clinic team',
    subtitle: 'Miguel, Ana and Dr. Alvarez',
    icon: 'chat',
    pinned: false,
    isAi: false,
    badge: 'Usually replies in ~10 min',
  );
  static List<Thread> get threads => [aiThread, clinicThread];

  static List<ChatMessage> get messages => [
    ChatMessage(
      id: 'm1',
      threadId: 'th_ai',
      author: ChatAuthor.ai,
      text:
          'Hi there. I can answer questions about feeding, grooming, vaccines and general care. For anything that needs a physical exam, run a health check and I will point you to the right next step.',
      at: DateTime(2026, 10, 12, 20, 5),
    ),
    ChatMessage(
      id: 'm2',
      threadId: 'th_clinic',
      author: ChatAuthor.vetAssistant,
      text:
          'Good morning, Marco! Miguel here. Mochi has her grooming slot on Tuesday at 9:00 AM — is the intake note about the matting behind her ears still current?',
      at: DateTime(2026, 10, 13, 8, 14),
      petId: 'p2',
    ),
    ChatMessage(
      id: 'm3',
      threadId: 'th_clinic',
      author: ChatAuthor.ai,
      text:
          'Auto-reply: the clinic team is offline until 9:00 AM. Your message is queued and Miguel will see it first thing.',
      at: DateTime(2026, 10, 12, 21, 40),
      kind: ChatKind.system,
    ),
  ];

  // ----------------------------------------------------------------- clinic
  // Single source of truth lives in [Clinic] (lib/data/clinic.dart); these
  // aliases keep existing call sites compiling without duplicating values.
  static const clinicName = Clinic.name;
  static const clinicAddress = Clinic.address;
  static const clinicPhone = Clinic.phone;
  static const clinicHours = Clinic.hoursLabel;
  static const afterHoursName = Clinic.afterHoursName;
  static const afterHoursPhone = Clinic.afterHoursPhone;
  static const ownerName = 'Marco Dela Cruz';
  static const ownerContact = '0917 555 0142 · marco.delacruz@carepaws.ph';
  static const appVersion = '1.4.0 (204)';
}