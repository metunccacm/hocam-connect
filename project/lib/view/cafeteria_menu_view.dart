import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:project/viewmodel/cafeteria_menu_viewmodel.dart';
import '../utils/network_error_handler.dart';

class CafeteriaMenuView extends StatefulWidget {
  const CafeteriaMenuView({super.key});

  @override
  State<CafeteriaMenuView> createState() => _CafeteriaMenuViewState();
}

class _CafeteriaMenuViewState extends State<CafeteriaMenuView> {
  int _selectedDayIndex = 0; // 0=Mon
  final List<String> _dayNames = const [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
  final ScrollController _chipScrollController = ScrollController();
  late final List<GlobalKey> _chipKeys;

  late final CafeteriaMenuViewModel vm;

  @override
  void initState() {
    super.initState();

    // Initialize Turkish locale data for date formatting
    initializeDateFormatting('tr_TR');

    final int todayIndex = DateTime.now().weekday - 1;
    _selectedDayIndex = todayIndex.clamp(0, _dayNames.length - 1);
    _chipKeys = List<GlobalKey>.generate(_dayNames.length, (_) => GlobalKey());

    vm = CafeteriaMenuViewModel();
    vm.addListener(_onVmChanged);
    // initial load (current week)
    vm.loadCurrentWeek();

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToSelectedChip());
  }

  @override
  void dispose() {
    vm.removeListener(_onVmChanged);
    vm.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _scrollToSelectedChip() {
    if (_selectedDayIndex < 0 || _selectedDayIndex >= _chipKeys.length) return;
    final BuildContext? ctx = _chipKeys[_selectedDayIndex].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.onSurface),
        title: Text(
          'Yemekhane Menüsü',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Fiyat Listesi',
            onPressed: () {
              final raw = (vm.pricingInfo ?? '').trim();
              showDialog(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Fiyat Bilgisi'),
                    content: _PricingDialogContent(text: raw),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Kapat'),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: vm.isLoading ? null : vm.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Gün seçici header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // hafif degrade arka plan
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withAlpha((0.14 * 255).round()),
                          colors.primaryContainer
                              .withAlpha((0.10 * 255).round()),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: colors.outline.withAlpha((0.35 * 255).round()),
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  // frosted blur
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // gün segmentleri
                          SizedBox(
                            height: 56,
                            child: SingleChildScrollView(
                              controller: _chipScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children:
                                    _dayNames.asMap().entries.map((entry) {
                                  final int index = entry.key;
                                  final String dayName = entry.value;
                                  final bool isSelected =
                                      _selectedDayIndex == index;
                                  final bool isToday =
                                      index == (DateTime.now().weekday - 1);

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _DayPill(
                                      key: _chipKeys[index],
                                      label: dayName,
                                      isSelected: isSelected,
                                      isToday: isToday,
                                      onTap: () {
                                        setState(
                                            () => _selectedDayIndex = index);
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                          (_) => _scrollToSelectedChip(),
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // tarih yongası
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.surface
                                    .withAlpha((0.6 * 255).round()),
                                border: Border.all(
                                    color: colors.outline
                                        .withAlpha((0.5 * 255).round())),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getSelectedDateString(vm.weekStart),
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body – loading / error / content
          if (vm.isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vm.hasNetworkError)
            Expanded(
              child: NetworkErrorView(
                message: vm.errorMessage ?? 'Unable to load cafeteria menu',
                onRetry: () => vm.refresh(),
              ),
            )
          else if (vm.errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Hata: ${vm.errorMessage}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => vm.refresh(),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                itemCount: 1,
                itemBuilder: (context, index) {
                  final String selectedDayName = _dayNames[_selectedDayIndex];

                  final lunch = vm.lunchFor(_selectedDayIndex);
                  final dinner = vm.dinnerFor(_selectedDayIndex);

                  // Build from live data
                  return _buildDayMenuCard(
                    selectedDayName,
                    lunch: lunch,
                    dinner: dinner,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayMenuCard(
    String dayName, {
    required List<String> lunch,
    required List<String> dinner,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shadowColor: Colors.black.withAlpha((0.1 * 255).round()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gün başlığı
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha((0.3 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    dayName,
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (lunch.isEmpty && dinner.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    'Bu gün için menü bulunamadı',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else ...[
              _buildMealSection('Öğle Yemeği', lunch),
              const SizedBox(height: 20),
              _buildMealSection('Akşam Yemeği', dinner),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(String mealTitle, List<String> menuItems) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              mealTitle.contains('Öğle') ? Icons.wb_sunny : Icons.nightlight,
              color: colors.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              mealTitle,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.05 * 255).round()),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: menuItems.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                colors.primary.withAlpha((0.3 * 255).round()),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        item,
                        style: textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _getSelectedDateString(DateTime weekStartMonday) {
    final DateTime selectedDate =
        weekStartMonday.add(Duration(days: _selectedDayIndex));
    final DateFormat formatter = DateFormat('yyyy MM dd', 'tr_TR');
    return formatter.format(selectedDate);
  }
}

/// Modern/minimal gün butonu
class _DayPill extends StatelessWidget {
  const _DayPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.outline.withAlpha((0.6 * 255).round()),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withAlpha((0.28 * 255).round()),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? colors.onPrimary : colors.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.onPrimary.withAlpha((0.15 * 255).round())
                      : colors.primary.withAlpha((0.10 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? colors.onPrimary : colors.primary,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Bugün',
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? colors.onPrimary : colors.primary,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fiyat listesi için düzenli, başlık + satır formatlı içerik
class _PricingDialogContent extends StatelessWidget {
  const _PricingDialogContent({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const Text('Bilgi bulunamadı');
    }

    final lines = text.split('\n').map((e) => e.trimRight()).toList();

    // Bölümleri boş satırlara göre ayır
    final List<List<String>> sections = [];
    List<String> current = [];
    for (final l in lines) {
      if (l.isEmpty) {
        if (current.isNotEmpty) {
          sections.add(current);
          current = [];
        }
      } else {
        current.add(l);
      }
    }
    if (current.isNotEmpty) sections.add(current);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < sections.length; i++) ...[
            _SectionWidget(lines: sections[i]),
            if (i != sections.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1),
              ),
          ]
        ],
      ),
    );
  }
}

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (lines.isEmpty) return const SizedBox.shrink();

    // İlk satırı başlık, kalan satırları madde/kalem olarak işleyelim
    final String header = lines.first;
    final List<String> items = lines.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _iconForHeader(header),
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                header,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((l) => _PriceRow(line: l)),
      ],
    );
  }

  IconData _iconForHeader(String header) {
    final h = header.toLowerCase();
    if (h.contains('alakart')) return Icons.restaurant_menu;
    if (h.contains('parça')) return Icons.list_alt;
    if (h.contains('tabldot')) return Icons.dinner_dining;
    if (h.contains('kola') ||
        h.contains('ayran') ||
        h.contains('su') ||
        h.contains('soda')) {
      return Icons.local_drink;
    }
    return Icons.info_outline;
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Satırları sağdaki son fiyatı yakalayacak şekilde bölmeye çalış
    // Ör: "ÇORBA 50,00 TL" → left: "ÇORBA", right: "50,00 TL"
    String left = line;
    String right = '';

    final priceMatch =
        RegExp(r'(\d{1,3}(?:\.\d{3})*,\d{2}\s*TL)$').firstMatch(line);
    if (priceMatch != null) {
      right = priceMatch.group(0) ?? '';
      left = line.substring(0, priceMatch.start).trimRight();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              left,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (right.isNotEmpty)
            Text(
              right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}
