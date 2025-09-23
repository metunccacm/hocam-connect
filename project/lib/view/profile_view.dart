import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'settings_view.dart';
import 'package:project/widgets/custom_appbar.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final supa = Supabase.instance.client;

  bool isEditing = false;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController dobController; // UI (DD/MM/YYYY)

  DateTime? _dob; // DB için gerçek tarih
  String? profileImageUrl; // public/signed url

  // Department dropdown için:
  static const List<String> _departments = <String>[
    // Burayı kendi bölümlerinizle doldurun
    'ASE',
    'BUS',
    'EEE',
    'ECO',
    'CNG',
    'CVE',
    'CYG',
    'CHME',
    'MECH',
    'PSIR',
    'PSY',
    'PGE',
    'SNG',
    'GPC',
    'TEFL',
    'Other'
  ];
  String? _selectedDepartment; // null ise hiç seçilmemiş demektir (hint görünsün)

  static const _bucket = 'profile'; // Supabase bucket to store avatars

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    dobController = TextEditingController();
    fetchProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    dobController.dispose();
    super.dispose();
  }

  String _fmtDateUI(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String? _fmtDateISO(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Çok-biçimli parser: ISO (YYYY-MM-DD[/T..]), DD/MM/YYYY, epoch (s/ms)
  DateTime? _parseDob(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    // ISO / timestamptz
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // dd/MM/yyyy
    final re = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
    final m = re.firstMatch(s);
    if (m != null) {
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final y = int.parse(m.group(3)!);
      return DateTime(y, mo, d);
    }

    // epoch
    if (RegExp(r'^\d+$').hasMatch(s)) {
      final n = int.parse(s);
      final ms = n > 20000000000 ? n : n * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    }
    return null;
  }

  Future<void> fetchProfile() async {
    final user = supa.auth.currentUser;
    if (user == null) return;

    // Sadece ihtiyacımız olan kolonları çekiyoruz (dob, department, avatar_url)
    final data = await supa
        .from('profiles')
        .select('dob, department, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      return;
    }

    final meta = user.userMetadata ?? {};
    final first = (meta['name'] ?? '').toString();
    final last = (meta['surname'] ?? '').toString();
    final fullName = '$first $last'.trim();

    final parsedDob = _parseDob(data['dob']);

    final dep = (data['department'] ?? '').toString().trim();
    // Veritabanından gelen değer listedeyse onu seç, değilse null bırak (hint gözüksün)
    final normalized = dep.isEmpty ? null : dep;
    final inList = _departments.contains(normalized);
    setState(() {
      nameController.text = fullName;
      emailController.text = user.email ?? '';
      _dob = parsedDob;

      // Parse başarılıysa formatlı göster; değilse ham stringi göster (boş kalmasın)
      final dobRaw = data['dob'];
      if (parsedDob != null) {
        dobController.text = _fmtDateUI(parsedDob);
      } else if (dobRaw != null && dobRaw.toString().trim().isNotEmpty) {
        dobController.text = dobRaw.toString();
      } else {
        dobController.text = '';
      }

      _selectedDepartment = inList ? normalized : normalized; // listedeyse de değilse de gösterelim; dropdown'da yoksa "Other" seçebilirsin
      profileImageUrl = (data['avatar_url'] ?? '').toString();
    });
  }

  Future<void> updateProfile() async {
    final user = supa.auth.currentUser;
    if (user == null) return;

    // Kullanıcı metin kutusuna manuel yazdıysa ve _dob null ise, kaydetmeden parse et.
    if (_dob == null && dobController.text.trim().isNotEmpty) {
      _dob = _parseDob(dobController.text.trim());
    }

    await supa.auth.updateUser(UserAttributes(data: {
      'display_name': nameController.text,
    }));

    final payload = <String, dynamic>{
      'avatar_url': profileImageUrl,
      'department': (_selectedDepartment ?? '').trim(),
    };

    // _dob yoksa DB’deki dob’u ezme
    final dobIso = _fmtDateISO(_dob);
    if (dobIso != null) payload['dob'] = dobIso;

    await supa.from('profiles').update(payload).eq('id', user.id);

    if (!mounted) return;
    setState(() => isEditing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final user = supa.auth.currentUser;
      if (user == null) return;

      final bytes = await picked.readAsBytes();

      // Derive extension + content type
      final ext = p.extension(picked.path).toLowerCase().replaceFirst('.', '');

      // Always include a filename
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final objectPath = 'avatars/${user.id}/$fileName';

      await supa.storage
          .from(_bucket) // 'profile'
          .uploadBinary(
            objectPath,
            bytes,
            fileOptions: const FileOptions(
              upsert: true, // requires UPDATE policy if key already exists
              contentType: 'image/jpeg', // isterseniz contentType değişkenini kullanın
            ),
          );

      // If bucket is PUBLIC:
      final publicUrl = supa.storage.from(_bucket).getPublicUrl(objectPath);
      final urlWithTs =
          '$publicUrl?ts=${DateTime.now().millisecondsSinceEpoch}';

      // If bucket is PRIVATE, use signed URL instead:
      // final signed = await supa.storage.from(_bucket).createSignedUrl(objectPath, 60 * 60 * 24 * 7); // 7 days
      // final urlWithTs = '${signed}?ts=${DateTime.now().millisecondsSinceEpoch}';

      setState(() {
        profileImageUrl = urlWithTs;
      });

      await supa.from('profiles').update({
        'avatar_url': urlWithTs, // (Tercihen DB'ye sadece objectPath yaz, okurken URL üret)
      }).eq('id', user.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed: $e')),
      );
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, 1, 1);
    final first = DateTime(1900);
    final last = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        dobController.text = _fmtDateUI(picked);
      });
    }
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => isEditing = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsView()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _departmentDisplay =>
      (_selectedDepartment == null || _selectedDepartment!.trim().isEmpty)
          ? 'Please add department'
          : _selectedDepartment!;

  //Builder
  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 60,
      backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
          ? NetworkImage(profileImageUrl!)
          : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
      child: isEditing
          ? const Align(
              alignment: Alignment.bottomRight,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white,
                child: Icon(Icons.camera_alt, size: 20),
              ),
            )
          : null,
    );

    return Scaffold(
      appBar: HCAppBar(
        title: 'Profile',
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _showMenu(context),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Profile',
              onPressed: updateProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            GestureDetector(
              onTap: isEditing ? pickImage : null,
              child: avatar,
            ),
            const SizedBox(height: 16),
            isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  )
                : Text(
                    nameController.text,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
            const SizedBox(height: 8),
            Text(
              emailController.text,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    ProfileInfoRow(
                      icon: Icons.mail,
                      label: 'E-mail',
                      value: emailController.text,
                    ),
                    const Divider(),
                    isEditing
                        ? TextField(
                            controller: dobController,
                            readOnly: true,
                            onTap: _pickDob,
                            decoration: const InputDecoration(
                              labelText: 'Date of Birth',
                              hintText: 'DD/MM/YYYY',
                              suffixIcon: Icon(Icons.date_range_rounded),
                            ),
                          )
                        : ProfileInfoRow(
                            icon: Icons.date_range_rounded,
                            label: 'Date of Birth',
                            value: dobController.text,
                          ),
                    const Divider(),
                    // Department: Edit modunda dropdown, görüntü modunda satır
                    isEditing
                        ? DropdownButtonFormField<String>(
                            value: _departments.contains(_selectedDepartment)
                                ? _selectedDepartment
                                : (_selectedDepartment == null ||
                                        _selectedDepartment!.isEmpty)
                                    ? null
                                    : _selectedDepartment, // listedeyse value, değilse serbest göster; yoksa null
                            items: _departments
                                .map((d) => DropdownMenuItem<String>(
                                      value: d,
                                      child: Text(d),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDepartment = val;
                              });
                            },
                            decoration: const InputDecoration(
                              labelText: 'Department',
                              hintText:
                                  'Please add department', // kullanıcıya hint, silmesi gerekmiyor
                            ),
                            isExpanded: true,
                          )
                        : ProfileInfoRow(
                            icon: Icons.school,
                            label: 'Department',
                            value: _departmentDisplay,
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  'All sensitive data is stored securely.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(width: 16),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
