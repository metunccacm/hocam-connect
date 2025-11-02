import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import '../theme_controller.dart';

class CreditsView extends StatelessWidget {
  const CreditsView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isDark;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const HCAppBar(
        title: 'Emeği Geçenler',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.scaffoldBackgroundColor,
                    theme.scaffoldBackgroundColor.withOpacity(0.95),
                  ],
                )
              : null,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Development Section
              _buildSectionHeader(
                icon: Icons.code_rounded,
                title: 'Development',
                color: Colors.blue,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildNameCard('Buğra Çetinkaya', Icons.person, Colors.blue, isDark, showArrow: true),
              const SizedBox(height: 12),
              _buildNameCard('Karpat Güzel', Icons.person, Colors.blue, isDark, showArrow: true),
              const SizedBox(height: 12),
              _buildNameCard('Kamil Barış Gökmen', Icons.person, Colors.blue, isDark, showArrow: true),
              const SizedBox(height: 12),
              _buildNameCard('İrem Dede', Icons.person, Colors.blue, isDark, showArrow: true),
              const SizedBox(height: 12),
              _buildNameCard('Fethi Eren Başata', Icons.person, Colors.blue, isDark, showArrow: true),
              const SizedBox(height: 12),
              _buildNameCard('Mert Yıldırım', Icons.person, Colors.blue, isDark, showArrow: true),
              
              const SizedBox(height: 32),

              // Special Thanks Section
              _buildSectionHeader(
                icon: Icons.favorite_rounded,
                title: 'Özel Teşekkür',
                color: Colors.red,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildNameCard(
                'Prof. YELİZ YEŞİLADA YILMAZ',
                Icons.school,
                Colors.red,
                isDark,
                showArrow: false,
                imagePath: 'assets/images/ozel_tesekkur_image/profileImage_100247',
              ),
              const SizedBox(height: 12),
              _buildNameCard(
                'Prof. ENVER EVER',
                Icons.school,
                Colors.red,
                isDark,
                showArrow: false,
                imagePath: 'assets/images/ozel_tesekkur_image/enver-ever_1_1_1_1_0_0_1_1_1_1_0_1_0_1_1_0_0.jpeg',
              ),
              const SizedBox(height: 12),
              _buildNameCard(
                'Asst. Prof. ŞÜKRÜ ERASLAN',
                Icons.school,
                Colors.red,
                isDark,
                showArrow: false,
                imagePath: 'assets/images/ozel_tesekkur_image/profileImage_100248',
              ),
              const SizedBox(height: 12),
              _buildNameCard(
                'Assoc. Prof. Dr. Yöney Kırsal Ever',
                Icons.school,
                Colors.red,
                isDark,
                showArrow: false,
                imagePath: 'assets/images/ozel_tesekkur_image/582580a030f470248b259d3abcdbc07d.jpg',
              ),
              const SizedBox(height: 12),
              _buildNameCard('ODTÜ KKK KALTEV', Icons.business, Colors.red, isDark, showArrow: false),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? color.withOpacity(0.15)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.3 : 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameCard(
    String name,
    IconData icon,
    Color color,
    bool isDark, {
    bool showArrow = true,
    String? imagePath,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.shade800.withOpacity(0.6)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.grey.shade700.withOpacity(0.5)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          imagePath != null
              ? Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color,
                                color.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 24,
                          ),
                        );
                      },
                    ),
                  ),
                )
              : Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (showArrow)
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade400,
            ),
        ],
      ),
    );
  }
}

