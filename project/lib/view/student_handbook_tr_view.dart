import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
                "Hoş geldiniz! Artık bizim bir parçamızsınız ve burada olduğunuz için çok mutluyuz. "
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
                "Akademik binalara yürüyerek yaklaşık 15 dakika sürer, diğer yurtlara kıyasla daha uzaktır ama yine de elverişlidir."
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
                  "Önünde İş Bankası ATM’leri, otobüs durağının yanında ise Ziraat Bankası ATM’si vardır."),
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
                "Alt katında restoran, üst katı ise oyun salonuna dönüştürülmüştür. "
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
                "Kampüs genelinde kablosuz internet vardır ancak cihazlarınızı Bilişim Teknolojileri (IT) binasında kaydettirmeniz gerekir. "
                "Bu bina Yemekhanenin arkasındadır. "
                "İki cihaza kadar kayıt yapabilirsiniz. Dikkatli seçin!"
              ),
              _linkTile(
                context,
                label: 'Ayrıntılar için doküman',
                url: 'https://ncc.metu.edu.tr/sites/default/files/RegistrationofElectronicDevices2022-23.pdf',
              ),
              _linkTile(
                context,
                label: 'IT web sitesi',
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
                "IT binasının yanında kampüsün en önemli parçası olan kütüphane yer almaktadır. "
                "Üç katlıdır; ortak çalışma alanları, grup odaları vardır. "
                "Ayrıca burada copycard kullanabilirsiniz."
                "Daha yakından bir bakış için kütüphane turu videosuna göz atabilirsiniz."
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
                "Kısacası çözemediğiniz bir sorun olursa Öğrenci İşleri sizin ilk durağınız olmalı"
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.school_rounded,
            title: 'Akademik Binalar ve Hazırlık Okulu',
            children: [
              const _Bullet(
                "Ana Yemekhane’nin yakınında, Hazırlık Okulu binasına inen merdivenleri göreceksiniz."
                "Eğer İngilizce hazırlık programında okuyorsanız, derslerinizin çoğu burada yapılacak."
                "Eğer doğrudan bölümünüze başlıyorsanız, zamanınızın çoğunu üç ana akademik binada geçireceksiniz: T, R ve S."
              ),
              const _Bullet(
                "T (Teaching - Eğitim) Binası, amfilerin ve küçük bir kafeteryanın bulunduğu yerdir."
                "R (Research - Araştırma) Binası, çeşitli laboratuvarlara sahiptir."
                "S Binası’nın üst katında güzel bir teras vardır."
                "Üçü de köprülerle birbirine bağlıdır, böylece dışarı çıkmadan aralarında geçiş yapabilirsiniz."
              ),
              const _Bullet(
                "Derslikler bina, kat ve oda numarası ile kodlanır."
                "Örneğin, TZ-111: T binası, zemin kat, 111 numaralı oda;"
                "R-103: R binası, birinci kat, 103 numaralı oda;"
                "S-201: S binası, ikinci kat, 201 numaralı oda demektir."
              ),
            ],
            footerLinks: [
							_FooterLink('Yabancı Diller Okulu hakkında daha fazla bilgi için tıklayın', 'https://ncc.metu.edu.tr/sfl/general-info'),
						],
          ),
          _section(
            context,
            icon: Icons.health_and_safety_rounded,
            title: 'Medico ve Spor Merkezi',
            children: [
              const _Bullet(
                "Otobüs durağından gelen yolu takip ederseniz, futbol sahasının karşısında yer alan kampüs sağlık merkezi Medico’yu göreceksiniz."
                "Burada temel sağlık hizmetleri verilir ve sistemde yer alması gereken sağlık raporları için de buraya gelirsiniz."
                "Aynı yoldan devam ederseniz Spor Merkezi’ne ulaşırsınız. İçinde tenis kortları, spor salonu, kapalı basketbol sahası ve masa tenisi alanı vardır."
                "Yakınında ayrıca tırmanma duvarı, yüzme havuzu, açık basketbol ve voleybol sahaları ile koşu pisti bulunur."
              ),
            ],
            footerLinks: [
							_FooterLink('Mediko hakkında daha fazla bilgi için tıklayın', 'https://www.youtube.com/embed/ek3Jh-1xt78?rel=0'),
							_FooterLink('Sporlar hakkında daha fazla bilgi için tıklayın', 'https://ncc.metu.edu.tr/campus-life/sports-mission'),
						],
          ),
          _section(
            context,
            icon: Icons.card_membership_rounded,
            title: 'Öğrenci Kartı ve Copycard',
            children: [
              _BulletInline([
                const TextSpan(text: "Kampüste ihtiyacınız olacak iki kart vardır: öğrenci kartı ve kopya kartı. "),
                const TextSpan(text: "Öğrenci kartı, otobüsleri kullanmak için gereklidir ve "),
                TextSpan(
                  text: 'cyppass.com',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () => _openUrl(context, 'https://www.cyppass.com/tr'),
                ),
                const TextSpan(text: " adresinden ya da otobüs durağı yakınındaki istasyondan kredi yüklenebilir. "),
                const TextSpan(text: "Kopya kartı ise yurtlarda ve kütüphanede çıktı almak için kullanılır. "),
                const TextSpan(text: "Bu kartı doğrudan Kütüphane’den alabilir ve orada bakiye yükleyebilirsiniz."),
              ]),
            ],
          ),
          _section(
            context,
            icon: Icons.directions_bus_rounded,
            title: 'Otobüs Sistemi',
            children: [
              const _Bullet(
                "Yerel otobüs sistemi kampüsü Kalkanlı ve Güzelyurt ile bağlar."
                "Otobüsler kampüsten her saat başı kalkar, önce Kalkanlı’ya uğrar ve Güzelyurt terminalinde son bulur."
                "Daha sonra aynı güzergâhtan kampüse geri dönerler."
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
                "Kampüsün iki ana kapısı vardır."
                "Üst kapı doğrudan Kalkanlı köyüne çıkar; burada restoranlar, Lombard kafe ve Kaş Market bulunur."
                "Kaş Market’e gitmek için kapıdan dümdüz yürüyün, yolun sonunda Lombard’a vardığınızda sola dönün; sağınızda Kaş tabelasını göreceksiniz."
                "Alt kapı ise VOY adlı başka bir kafeye çıkar."
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.event_rounded,
            title: 'Kampüsteki Kafeler',
            children: [
              const _Bullet(
                "En popüler yerlerden biri, otobüs durağının yanındaki Atatürk heykelinin hemen altında bulunan Segafredo Tchibo Kafe’dir."
                "Burada kahve, tatlı alabilir ve ders aralarında ya da akşamları arkadaşlarınızla vakit geçirebilirsiniz."    
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.business_center_rounded,
            title: 'CCC, Mühendislik Labları ve Kaltev',
            children: [
              const _Bullet(
                "Hazırlık Okulu’nun yanında, METU NCC heykelinin önünde bulunan CCC Binası, kampüsteki etkinliklerin ana mekânıdır."
                "Burada neler olduğunu öğrenmek için e-postalarınıza gelen veya HocamConnect uygulamasından “This Week On Campus” duyurularını takip edin."
                "CCC’nin arkasında mühendislik laboratuvar binaları vardır, bazı bölüm laboratuvarları burada yapılır."
                "Daha gerisinde ise girişimlerin, araştırma projelerinin ve inovasyon alanlarının bulunduğu Kaltev (Kalkanlı Teknoloji Vadisi) yer alır."
              ),
              const _Bullet(
                "Kaltev’in alt katında Root adında samimi ve geleceğe dönük bir restoran/kafe vardır."
                "Root, özgün dekorasyonuyla şık bir atari salonu görünümündedir."
                "Atari makineleri oynanabilir durumdadır ve ayrıca arkadaşlarınızla oynayabileceğiniz birçok masa oyunu da bulunur."
              ),
            ],
            footerLinks: [
              _FooterLink('Kaltev hakkında daha fazla bilgi için tıklayın', 'https://odtukaltev.com.tr/'),
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

class _BulletInline extends StatelessWidget {
  const _BulletInline(this.spans);
  final List<TextSpan> spans;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0, right: 8.0),
            child: Icon(Icons.circle, size: 8, color: Colors.grey),
          ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.merge(const TextStyle(height: 1.35, fontSize: 14)),
                  children: spans,
                ),
              ),
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
