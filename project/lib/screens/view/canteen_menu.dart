import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CanteenMenuScreen extends StatefulWidget {
  const CanteenMenuScreen({super.key});

  @override
  State<CanteenMenuScreen> createState() => _CanteenMenuScreenState();
}

class _CanteenMenuScreenState extends State<CanteenMenuScreen> {
  int _selectedDayIndex = 0;
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

  @override
  void initState() {
    super.initState();
    final int todayIndex = DateTime.now().weekday - 1; // 1=Mon -> 0 index
    _selectedDayIndex = todayIndex < 0
        ? 0
        : (todayIndex >= _dayNames.length ? _dayNames.length - 1 : todayIndex);
    _chipKeys = List<GlobalKey>.generate(_dayNames.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedChip());
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

  // Örnek menü verisi - ileride backend'den gelecek
  final Map<String, Map<String, Map<String, List<String>>>> _weeklyMenus = {
    'Bu Hafta': {
      'Pazartesi': {
        'Öğle': ['Mercimek Çorbası', 'Tavuk Sote', 'Pilav', 'Salata', 'Meyve'],
        'Akşam': ['Ezogelin Çorbası', 'Kıyma Sote', 'Bulgur Pilavı', 'Turşu', 'Yoğurt'],
      },
      'Salı': {
        'Öğle': ['Domates Çorbası', 'Balık Izgara', 'Makarna', 'Salata', 'Tatlı'],
        'Akşam': ['Mantar Çorbası', 'Tavuk Şiş', 'Pilav', 'Cacık', 'Meyve'],
      },
      'Çarşamba': {
        'Öğle': ['Mercimek Çorbası', 'Et Sote', 'Pilav', 'Salata', 'Yoğurt'],
        'Akşam': ['Yayla Çorbası', 'Tavuk Pirzola', 'Bulgur', 'Turşu', 'Meyve'],
      },
      'Perşembe': {
        'Öğle': ['Domates Çorbası', 'Balık Tava', 'Makarna', 'Salata', 'Tatlı'],
        'Akşam': ['Ezogelin Çorbası', 'Kıyma Sote', 'Pilav', 'Cacık', 'Meyve'],
      },
      'Cuma': {
        'Öğle': ['Mercimek Çorbası', 'Tavuk Izgara', 'Pilav', 'Salata', 'Yoğurt'],
        'Akşam': ['Mantar Çorbası', 'Et Sote', 'Bulgur', 'Turşu', 'Tatlı'],
      },
    },
    'Gelecek Hafta': {
      'Pazartesi': {
        'Öğle': ['Yayla Çorbası', 'Tavuk Pirzola', 'Pilav', 'Salata', 'Meyve'],
        'Akşam': ['Domates Çorbası', 'Balık Izgara', 'Makarna', 'Cacık', 'Yoğurt'],
      },
      'Salı': {
        'Öğle': ['Ezogelin Çorbası', 'Kıyma Sote', 'Bulgur', 'Turşu', 'Tatlı'],
        'Akşam': ['Mercimek Çorbası', 'Tavuk Sote', 'Pilav', 'Salata', 'Meyve'],
      },
      'Çarşamba': {
        'Öğle': ['Mantar Çorbası', 'Et Sote', 'Pilav', 'Salata', 'Yoğurt'],
        'Akşam': ['Domates Çorbası', 'Balık Tava', 'Makarna', 'Cacık', 'Tatlı'],
      },
      'Perşembe': {
        'Öğle': ['Yayla Çorbası', 'Tavuk Izgara', 'Bulgur', 'Turşu', 'Meyve'],
        'Akşam': ['Mercimek Çorbası', 'Kıyma Sote', 'Pilav', 'Salata', 'Yoğurt'],
      },
      'Cuma': {
        'Öğle': ['Ezogelin Çorbası', 'Balık Izgara', 'Makarna', 'Salata', 'Tatlı'],
        'Akşam': ['Mantar Çorbası', 'Tavuk Pirzola', 'Pilav', 'Cacık', 'Meyve'],
      },
    },
    'Sonraki Hafta': {
      'Pazartesi': {
        'Öğle': ['Domates Çorbası', 'Et Sote', 'Pilav', 'Salata', 'Meyve'],
        'Akşam': ['Yayla Çorbası', 'Tavuk Izgara', 'Bulgur', 'Turşu', 'Yoğurt'],
      },
      'Salı': {
        'Öğle': ['Mercimek Çorbası', 'Balık Tava', 'Makarna', 'Cacık', 'Tatlı'],
        'Akşam': ['Ezogelin Çorbası', 'Kıyma Sote', 'Pilav', 'Salata', 'Meyve'],
      },
      'Çarşamba': {
        'Öğle': ['Mantar Çorbası', 'Tavuk Pirzola', 'Pilav', 'Salata', 'Yoğurt'],
        'Akşam': ['Domates Çorbası', 'Et Sote', 'Bulgur', 'Turşu', 'Tatlı'],
      },
      'Perşembe': {
        'Öğle': ['Yayla Çorbası', 'Balık Izgara', 'Makarna', 'Cacık', 'Meyve'],
        'Akşam': ['Mercimek Çorbası', 'Tavuk Sote', 'Pilav', 'Salata', 'Yoğurt'],
      },
      'Cuma': {
        'Öğle': ['Ezogelin Çorbası', 'Kıyma Sote', 'Pilav', 'Salata', 'Tatlı'],
        'Akşam': ['Mantar Çorbası', 'Balık Tava', 'Bulgur', 'Turşu', 'Meyve'],
      },
    },
  };

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
                          colors.primaryContainer.withAlpha((0.10 * 255).round()),
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
                                children: _dayNames.asMap().entries.map((entry) {
                                  final int index = entry.key;
                                  final String dayName = entry.value;
                                  final bool isSelected = _selectedDayIndex == index;
                                  final bool isToday = index == (DateTime.now().weekday - 1);

                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _DayPill(
                                      key: _chipKeys[index],
                                      label: dayName,
                                      isSelected: isSelected,
                                      isToday: isToday,
                                      onTap: () {
                                        setState(() => _selectedDayIndex = index);
                                        WidgetsBinding.instance.addPostFrameCallback(
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.surface.withAlpha((0.6 * 255).round()),
                                border: Border.all(color: colors.outline.withAlpha((0.5 * 255).round())),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _getSelectedDateString(),
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

          // Menü listesi (seçili gün)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              itemCount: 1,
              itemBuilder: (context, index) {
                String selectedDayName = _dayNames[_selectedDayIndex];
                final Map<String, List<String>>? maybeDayMenu =
                    _weeklyMenus['Bu Hafta']?[selectedDayName];
                final Map<String, List<String>> dayMenu =
                    maybeDayMenu ?? <String, List<String>>{};
                return _buildDayMenuCard(selectedDayName, dayMenu);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayMenuCard(String dayName, Map<String, List<String>> dayMenu) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<String> lunch = dayMenu['Öğle'] ?? const [];
    final List<String> dinner = dayMenu['Akşam'] ?? const [];

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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

            if (lunch.isEmpty && dinner.isEmpty) ...[
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
              ),
            ] else ...[
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
                            color: colors.primary.withAlpha((0.3 * 255).round()),
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

  String _getSelectedDateString() {
    // Seçili günün tarihi (mevcut haftadan)
    final DateTime now = DateTime.now();
    final DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final DateTime selectedDate = startOfWeek.add(Duration(days: _selectedDayIndex));
    final DateFormat formatter = DateFormat('dd MMM yyyy');
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
