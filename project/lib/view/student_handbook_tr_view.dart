import 'package:flutter/material.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'student_handbook_eng_view.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentHandbookTrView extends StatelessWidget {
  const StudentHandbookTrView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Öğrenci El Kitabı',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _LanguageMenu(
            current: 'TR',
            onSelect: (code) {
              if (code == 'EN') {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const StudentHandbookEngView()),
                );
              }
            },
          ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _section(
            context,
            icon: Icons.emoji_people_rounded,
            title: 'Hoş Geldiniz',
            children: [
              _Bullet(
                "Hoş geldiniz! Artık bizim bir parçamızsınız ve burada olduğunuz için mutluyuz. "
                "Bu rehber, ilk günlerinizi kolaylaştırmak ve kampüsü daha hızlı tanımanıza yardımcı olmak için hazırlandı. "
                "Başlamadan önce kampüs hakkında görsel bir fikir edinmek için kısa bir kampüs turu videosuna göz atabilirsiniz:",
              ),
              _linkTile(
                context,
                label: '2 Dakikalık Kampüs Turu',
                url: 'https://www.youtube.com/embed/zmGS52SPeJ0?rel=0',
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.airport_shuttle_rounded,
            title: 'Ulaşım (Ercan → Kampüs)',
            children: [
              const _Bullet(
                "Ercan Havalimanı’na indiğinizde kampüse nasıl gideceğinizi düşünmenize gerek yok. "
                "Hemen çıkışta sol tarafınızda KIBHAS ofisini göreceksiniz. "
                "KIBHAS, adanın farklı bölgelerini birbirine bağlayan otobüs şirketidir ve üniversitemize direkt hattı vardır. "
                "Biletinizi alın, ODTÜ’ye gideceğinizi söyleyin ve koltuğunuza oturun. "
                "Otobüs sizi doğrudan kampüse getirir—çok kolay.",
              ),
              _linkTile(
                context,
                label: 'Ulaşım detayları (Kampüs Yaşamı)',
                url: 'https://ncc.metu.edu.tr/tr/kampusta-yasam',
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.home_rounded,
            title: 'Yurtlar',
            children: [
              const _Bullet(
                "Yurt 2, otobüs durağının hemen önünde göreceğiniz ilk yurttur. "
                "Her ünitede üç oda bulunur, ortak mutfak ve banyo vardır. "
                "Eğer buraya yerleştirildiyseniz, içeri girip yurt görevlilerinden odanıza yönlendirilmeyi isteyin. "
                "Yurt 2’nin içinde Noshi adında bir kafe de bulunur; tatlı ve içecek seçenekleri vardır. "
              ),
              const _Bullet(
                "Yurt 3, Yurt 2’nin sol tarafında bulunur. "
                "Odalar iki veya dört kişilik olarak tasarlanmıştır ve ortada ortak bir çalışma alanı vardır. "
                "İki kişilik odalarda herkesin kendine ait alanı vardır, dört kişiliklerde ise odalar ikişer yataklı bölümlere ayrılmıştır. "
                "Mutfak ve banyolar kat bazında ortaktır."
              ),
              const _Bullet(
                "Yurt 1, Yurt 3’ün karşısındaki beyaz binadır. "
                "Yurt 3’e benzer şekilde düzenlenmiştir, ancak önemli bir fark vardır: "
                "Odaların kendi banyosu vardır ve yataklar bölümlere ayrılmadan tek bir alanda bulunur."
              ),
              const _Bullet(
                "EBI, kampüsteki en yeni yurttur ve Yurt 2 ile Yurt 3’ün arkasında bulunur. "
                "İki bina arasından yürüyerek yeni yapıyı göreceksiniz. "
                "Diğerleri gibi burada da yurt görevlileri size yardımcı olur."
              ),
              const _Bullet(
                "Yurt 4, kampüsün üst kapısına yakın bir noktadadır. "
                "Akademik binalara yürüyerek yaklaşık 15 dakika sürer, biraz uzaktır ama yine de elverişlidir."
              ),
              const _Bullet("Yurt personeli giriş işlemlerinde her zaman yardımcı olur—güvenliğe danışabilirsiniz."),
            ],
          ),
          _section(
            context,
            icon: Icons.shopping_basket_rounded,
            title: 'Kampüsü Keşfetmek',
            children: [
              const _Bullet("Otobüs durağının orada merdivenlerden çıktığınızda Macro marketi göreceksiniz. "
                  "Macro, adada bilinen bir süpermarket zinciridir ve kampüs içinde şubesi vardır. "
                  "Günlük ihtiyaçlarınız için ideal bir yerdir."),
              const _Bullet("Macro’nun yanında İş Bankası bulunur. "
                  "Henüz banka hesabınız yoksa burada açmanızı tavsiye ederiz çünkü her yerde uluslararası kart kabul edilmeyebilir. "
                  "Önünde İş Bankası ATM’leri, otobüs durağına yakın ise Ziraat Bankası ATM’si vardır."),
              const _Bullet("Yürümeye devam ettiğinizde berber ve kuaförün bulunduğu küçük bir sokak göreceksiniz. "
                  "Sokağın sonunda Deniz Plaza vardır, burada kırtasiye, defter, kalem ve bazı ders kitaplarını bulabilirsiniz."),
              const _Bullet("Deniz Plaza’nın yanında terzi ve KKTCELL ofisi bulunur. "
                  "Telefon kayıt işlemleri için belirli günlerde ekipler kampüse gelir. "
                  "Öğrenci e-postalarınızı takip ederek tarihi öğrenebilirsiniz."),
            ],
          ),
          _section(
            context,
            icon: Icons.group_rounded,
            title: 'Öğrenci Kulüpleri',
            children: [
              const _Bullet(
                "ISA (Uluslararası Öğrenciler Derneği), "
                "PSS (Problem Solving Society), Women In Engineering, Animal Welfare Society, ACM ve daha birçok öğrenci kulübü bulunmaktadır. "
                "Bazı kulüp odalarını Deniz Plaza ve Macro marketin üst katlarında bulabilirsiniz."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.restaurant_menu_rounded,
            title: 'Yemek ve Kafeler',
            children: [
              const _Bullet(
                "Bankanın ilerisinde Ana Yemekhane bulunmaktadır. "
                "Alt katı oyun salonuna dönüştürülmüş, üst katında ise restoran vardır. "
                "Günlük ev yemekleri ve zaman zaman farklı mutfaklardan yemekler sunulur. "
                "Yanında Pastane bulunur; döner, burger ve hamur işleri alabilirsiniz. "
                "Üst katta ise Teras Cafe vardır, buradan dağ manzarasını izleyebilirsiniz."
              )
            ],
          ),
          _section(
            context,
            icon: Icons.shield_moon_rounded,
            title: "Güvenlik Ofisi",
            children: [
              const _Bullet("Eşyanızı kaybederseniz veya güvenlikle iletişim kurmanız gerekirse, ofisleri Yemekhane ile Pastane arasında bulunur."),
            ],
          ),
          _section(
            context,
            icon: Icons.wifi_rounded,
            title: 'İnternet ve Bilişim',
            children: [
              const _Bullet(
                "Kampüs genelinde kablosuz internet vardır ancak cihazlarınızı Bilişim Teknolojileri (BT) binasında kaydettirmeniz gerekir. "
                "Bu bina Yemekhanenin arkasındadır. "
                "İki cihaz kaydı yapabilirsiniz."
              ),
              _linkTile(
                context,
                label: 'Ayrıntılar için doküman',
                url: 'https://ncc.metu.edu.tr/sites/default/files/RegistrationofElectronicDevices2022-23.pdf',
              ),
              _linkTile(
                context,
                label: 'BT web sitesi',
                url: 'https://ncc.metu.edu.tr/tr/btm',
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.local_library_rounded,
            title: 'Kütüphane',
            children: [
              const _Bullet(
                "BT binasının yanında kütüphane vardır. "
                "Üç katlıdır; ortak çalışma alanları, grup odaları vardır. "
                "Ayrıca copycard kullanabilirsiniz."
              ),
              _linkTile(
                context,
                label: 'Kütüphane turu (YouTube)',
                url: 'https://www.youtube.com/embed/6th5JCPMfq0?rel=0',
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.account_balance_rounded,
            title: 'Rektörlük ve Öğrenci İşleri',
            children: [
              const _Bullet(
                "Kütüphanenin yanında Rektörlük binası vardır. "
                "Aynı zamanda Öğrenci İşleri de buradadır. "
                "Transkript, öğrenci kartı ve dersle ilgili birçok konuda buradan yardım alabilirsiniz."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.school_rounded,
            title: 'Akademik Binalar ve Hazırlık Okulu',
            children: [
              const _Bullet(
                "Hazırlık Okulu Yemekhane’nin arkasındadır. "
                "Bölüm öğrencileri çoğunlukla T, R ve S binalarında ders görür."
              ),
              const _Bullet(
                "T (Teaching) binasında derslikler, R (Research) binasında laboratuvarlar, S binasında ise teraslı sınıflar bulunur."
              ),
              const _Bullet(
                "Sınıf kodları: TZ-111 (T binası, zemin kat, oda 111), R-103, S-201 gibi."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.health_and_safety_rounded,
            title: 'Medico ve Spor Merkezi',
            children: [
              const _Bullet(
                "Otobüs durağının ilerisinde Medico bulunur. "
                "Temel sağlık hizmetleri verir. "
                "Devamında Spor Merkezi vardır; tenis kortları, basketbol sahası, tırmanma duvarı ve yüzme havuzu bulunur."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.card_membership_rounded,
            title: 'Öğrenci Kartı ve Copycard',
            children: [
              const _Bullet(
                "Öğrenci kartı otobüslerde ve bazı işlemlerde gereklidir, bakiye yüklemeleri cyppass.com üzerinden yapılabilir. "
                "Copycard ise kütüphane ve yurtlarda yazıcı kullanmak için gereklidir, kütüphaneden alabilirsiniz."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.directions_bus_rounded,
            title: 'Otobüs Sistemi',
            children: [
              const _Bullet(
                "Yerel otobüsler kampüsü Kalkanlı ve Güzelyurt’a bağlar. "
                "Her saat hareket eder, dönüşte aynı güzergahı kullanır."
              ),
              _linkTile(
                context,
                label: 'Bakiye yükle: cyppass.com',
                url: 'https://www.cyppass.com/tr',
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.map_rounded,
            title: 'Kampüs Kapıları',
            children: [
              const _Bullet(
                "Kampüsün iki ana kapısı vardır. "
                "Üst kapı Kalkanlı köyüne çıkar (restoran, Lombard kafe, Kaş Market). "
                "Alt kapıdan ise VOY kafeye gidilir."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.event_rounded,
            title: 'Kampüsteki Kafeler',
            children: [
              const _Bullet(
                "En popüler yerlerden biri Segafredo Tchibo kafedir. "
                "Atatürk heykelinin altındadır, ders aralarında veya akşamları vakit geçirmek için idealdir."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.business_center_rounded,
            title: 'CCC, Mühendislik Labları ve Kaltev',
            children: [
              const _Bullet(
                "Hazırlık Okulu’nun yanında CCC binası vardır. "
                "Kampüs etkinlikleri burada yapılır, e-postalarınızı kontrol ederek etkinlikleri takip edebilirsiniz."
              ),
              const _Bullet(
                "CCC’nin arkasında mühendislik laboratuvarları, daha ilerisinde ise girişimcilik merkezi Kaltev bulunur."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.timeline_rounded,
            title: 'Ders Kaydı ve ODTUClass',
            children: [
              _linkTile(
                context,
                label: 'Ders ekleme (YouTube)',
                url: 'https://www.youtube.com/embed/bi12NWyXwSg?rel=0',
              ),
              _linkTile(
                context,
                label: 'Program planlama (CET)',
                url: 'https://cet.ncc.metu.edu.tr/',
              ),
              _linkTile(
                context,
                label: 'ODTUClass temelleri (YouTube)',
                url: 'https://www.youtube.com/embed/pn5FaG8KNVU?rel=0',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'İpucu: Sık kullandığınız linkleri tarayıcı veya ana ekrana kaydedin.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// --- UI helpers ---
Widget _section(
  BuildContext context, {
  required IconData icon,
  required String title,
  required List<Widget> children,
  List<_FooterLink> footerLinks = const [],
}) {
  final linkStyle = TextStyle(
    color: Colors.lightBlue.shade700,
    decoration: TextDecoration.underline,
    fontWeight: FontWeight.w600,
  );
  return Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1.5,
      child: ExpansionTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          const SizedBox(height: 8),
          ...children,
          if (footerLinks.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: footerLinks
                  .map((f) => TextButton.icon(
                        onPressed: () => _openUrl(context, f.url),
                        icon: Icon(Icons.open_in_new_rounded,
                            size: 18, color: Colors.lightBlue.shade400),
                        label: Text(f.label, style: linkStyle),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: Colors.black54),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.url);
  final String label;
  final String url;
}

Widget _linkTile(BuildContext context,
    {required String label, required String url}) {
  final linkStyle = TextStyle(
    color: Colors.lightBlue.shade700,
    decoration: TextDecoration.underline,
    fontWeight: FontWeight.w600,
  );
  return ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label, style: linkStyle),
    trailing:
        Icon(Icons.open_in_new_rounded, color: Colors.lightBlue.shade400),
    onTap: () => _openUrl(context, url),
  );
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link açılamadı')),
      );
    }
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.current, required this.onSelect});
  final String current;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Dil değiştir',
      position: PopupMenuPosition.under,
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'EN',
          child: Text('English (EN)'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'TR',
          child: Row(
            children: const [
              Icon(Icons.check, size: 16, color: Colors.green),
              SizedBox(width: 8),
              Text('Türkçe (TR)'),
            ],
          ),
        ),
      ],
      onSelected: onSelect,
      child: Row(
        children: [
          const Icon(Icons.language),
          const SizedBox(width: 4),
          Text(current, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }
}
