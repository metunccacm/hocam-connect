import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CanteenMenuScreen extends StatefulWidget {
  const CanteenMenuScreen({super.key});

  @override
  State<CanteenMenuScreen> createState() => _CanteenMenuScreenState();
}

class _CanteenMenuScreenState extends State<CanteenMenuScreen> {
  int _selectedWeekIndex = 0;
  final List<String> _weekNames = [
    'Bu Hafta',
    'Gelecek Hafta',
    'Sonraki Hafta',
  ];

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Yemekhane Menüsü',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF007BFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
      ),
      body: Column(
        children: [
          // Hafta seçici
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF007BFF),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Hafta seçici butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _weekNames.asMap().entries.map((entry) {
                    int index = entry.key;
                    String weekName = entry.value;
                    bool isSelected = _selectedWeekIndex == index;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedWeekIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ] : null,
                        ),
                        child: Text(
                          weekName,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF007BFF) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Tarih bilgisi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _getWeekDateRange(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Menü listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _weeklyMenus[_weekNames[_selectedWeekIndex]]!.length,
              itemBuilder: (context, index) {
                String dayName = _weeklyMenus[_weekNames[_selectedWeekIndex]]!.keys.elementAt(index);
                Map<String, List<String>> dayMenu = _weeklyMenus[_weekNames[_selectedWeekIndex]]![dayName]!;
                
                return _buildDayMenuCard(dayName, dayMenu);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayMenuCard(String dayName, Map<String, List<String>> dayMenu) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
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
                    color: const Color(0xFF007BFF),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF007BFF).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    dayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: const Color(0xFF007BFF),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Öğle yemeği
            _buildMealSection('Öğle Yemeği', dayMenu['Öğle']!),
            const SizedBox(height: 20),
            
            // Akşam yemeği
            _buildMealSection('Akşam Yemeği', dayMenu['Akşam']!),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(String mealTitle, List<String> menuItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              mealTitle.contains('Öğle') ? Icons.wb_sunny : Icons.nightlight,
              color: const Color(0xFF007BFF),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              mealTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE9ECEF),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
                      child: Column(
              children: menuItems.asMap().entries.map((entry) {
                int index = entry.key;
                String item = entry.value;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007BFF),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007BFF).withOpacity(0.3),
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
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
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

  String _getWeekDateRange() {
    // Basit tarih hesaplama - gerçek uygulamada daha gelişmiş olabilir
    DateTime now = DateTime.now();
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    if (_selectedWeekIndex == 1) {
      startOfWeek = startOfWeek.add(const Duration(days: 7));
    } else if (_selectedWeekIndex == 2) {
      startOfWeek = startOfWeek.add(const Duration(days: 14));
    }
    
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 4)); // Cuma'ya kadar
    
    DateFormat formatter = DateFormat('dd MMM yyyy');
    return '${formatter.format(startOfWeek)} - ${formatter.format(endOfWeek)}';
  }
} 