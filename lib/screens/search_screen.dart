import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import 'appointments/book_flow.dart';
import 'pets/pet_profile_screen.dart';
import 'shop/product_detail_screen.dart';
import 'triage_screen.dart';

/// Search across pets, services and products. Every result is tappable.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final q = _query.trim().toLowerCase();

    bool hit(String s) => q.isEmpty || s.toLowerCase().contains(q);

    final pets = store.pets.where((x) => hit(x.name) || hit(x.breed)).toList();
    final services = store.servicesForSearch
        .where((s) => hit(s.name) || hit(s.blurb))
        .toList();
    final products = store.products
        .where((x) => hit(x.name) || hit(x.tagline) || hit(x.description))
        .toList();

    final total = pets.length + services.length + products.length;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: p.background.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: p.divider, width: 0.5)),
        automaticallyImplyLeading: false,
        leading: Semantics(
          button: true,
          label: 'Cancel search',
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 44),
            onPressed: () => dismissSheet(context),
            child: Text(
              'Cancel',
              style: Type.body(p).copyWith(color: p.accentText),
            ),
          ),
        ),
        middle: CupertinoSearchTextField(
          controller: _q,
          autofocus: true,
          placeholder: 'Pets, services, products',
          style: Type.body(p),
          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
          onChanged: (v) => setState(() => _query = v),
          backgroundColor: p.surface,
          itemColor: p.textSecondary,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
      ),
      child: SafeArea(
        child: total == 0
            ? EmptyState(
                icon: Ic.search,
                title: 'No results',
                body:
                    'Nothing matches “$_query”. Try a shorter word, or browse the shop catalog.',
                actionLabel: 'Browse products',
                onAction: () {
                  dismissSheet(context);
                  store.tab = 3;
                },
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  Text(
                    '$total result${total == 1 ? '' : 's'}',
                    style: Type.footnote(p),
                  ),
                  if (pets.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Pets',
                      icon: Ic.paw,
                      padding: const EdgeInsets.fromLTRB(0, T.s16, 0, T.s8),
                    ),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < pets.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: p.divider, indent: 58),
                            RowTile(
                              title: pets[i].name,
                              subtitle:
                                  '${pets[i].breed} · ${pets[i].ageLabel}',
                              leadingPath: pets[i].species == Species.dog
                                  ? Ic.dog
                                  : Ic.cat,
                              onTap: () => Navigator.of(context)
                                  .pushReplacement(
                                    appRoute(
                                      PetProfileScreen(petId: pets[i].id),
                                    ),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (services.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Services',
                      icon: Ic.calendar,
                      padding: const EdgeInsets.fromLTRB(0, T.s16, 0, T.s8),
                    ),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < services.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: p.divider, indent: 58),
                            RowTile(
                              title: services[i].name,
                              subtitle:
                                  '${services[i].durationLabel} · ${peso(services[i].price)}',
                              leadingPath: Ic.byName(services[i].icon),
                              onTap: () => Navigator.of(context)
                                  .pushReplacement(
                                    appRoute(
                                      BookFlow(
                                        initialPetId:
                                            store.pets.firstOrNull?.id,
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (products.isNotEmpty) ...[
                    SectionHeader(
                      title: 'Products',
                      icon: Ic.bag,
                      padding: const EdgeInsets.fromLTRB(0, T.s16, 0, T.s8),
                    ),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < products.length; i++) ...[
                            if (i > 0)
                              Divider(height: 1, color: p.divider, indent: 58),
                            RowTile(
                              title: products[i].name,
                              subtitle:
                                  '${peso(products[i].price)} · '
                                  '${products[i].inStock ? '${products[i].stock} in stock' : 'Out of stock'}',
                              leadingPath: Ic.bag,
                              onTap: () => Navigator.of(context)
                                  .pushReplacement(
                                    appRoute(
                                      ProductDetailScreen(
                                        productId: products[i].id,
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (pets.isEmpty && services.isEmpty && products.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: T.s16),
                      child: SecondaryButton(
                        label: 'Run an AI health check',
                        icon: Ic.sparkle,
                        onPressed: () => Navigator.of(context)
                            .pushReplacement(appRoute(const TriageScreen())),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
