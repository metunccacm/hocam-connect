import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'settings_view.dart';
import 'package:project/widgets/custom_appbar.dart';
import '../utils/network_error_handler.dart';

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

  final TextEditingController _bugDetailsCtrl = TextEditingController();
  static const List<String> _bugReasons = [
    'Crash',
    'UI issue',
    'Performance',
    'Wrong data',
    'Other',
  ];

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
    'INE',
    'PGE',
    'SNG',
    'GPC',
    'TEFL'
  ];
  String?
      _selectedDepartment; // null ise hiç seçilmemiş demektir (hint görünsün)

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
    _bugDetailsCtrl.dispose();
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

// For bug metadata
  Future<Map<String, dynamic>> _collectBugMeta() async {
    final meta = <String, dynamic>{};

    // app info
    Map<String, dynamic> app = {
      'name': 'Hocam Connect',
      'version': 'unknown',
      'build': 'unknown',
    };
    try {
      final p = await PackageInfo.fromPlatform();
      app = {'name': p.appName, 'version': p.version, 'build': p.buildNumber};
    } catch (_) {
      // keep defaults
    }
    meta['app'] = app;

    // platform/device
    final deviceInfo = DeviceInfoPlugin();
    String platform = kIsWeb ? 'Web' : Platform.operatingSystem;
    Map<String, dynamic> device = {'info': 'generic'};

    try {
      if (!kIsWeb && Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        platform = 'iOS';
        device = {
          'name': ios.name,
          'model': ios.model,
          'machine': ios.utsname.machine, // x86_64/arm64 on simulator
          'systemName': ios.systemName,
          'systemVersion': ios.systemVersion,
          'isPhysicalDevice': ios.isPhysicalDevice,
        };
      } else if (!kIsWeb && Platform.isAndroid) {
        final and = await deviceInfo.androidInfo;
        platform = 'Android';
        device = {
          'brand': and.brand,
          'model': and.model,
          'device': and.device,
          'version': and.version.release,
          'sdkInt': and.version.sdkInt,
          'isPhysicalDevice': and.isPhysicalDevice,
        };
      }
    } catch (_) {/* keep generic */}

    meta['platform'] = platform;
    meta['device'] = device;

    // locale + timestamp
    try {
      meta['locale'] =
          WidgetsBinding.instance.platformDispatcher.locale.toString();
    } catch (_) {}
    meta['ts'] = DateTime.now().toIso8601String();

    return meta;
  }

  Future<void> fetchProfile() async {
    final user = supa.auth.currentUser;
    if (user == null) return;

    try {
      // Fetch name, surname from profiles table along with other data
      final data = await NetworkErrorHandler.handleNetworkCall(
        () => supa
            .from('profiles')
            .select('name, surname, dob, department, avatar_url')
            .eq('id', user.id)
            .maybeSingle(),
        context: 'Failed to load profile',
      );

      if (data == null) {
        return;
      }

      // Get name and surname from profiles table (preferred source)
      final first = (data['name'] ?? '').toString().trim();
      final last = (data['surname'] ?? '').toString().trim();

      // If profiles doesn't have name/surname, fallback to user metadata
      String firstName = first;
      String lastName = last;

      if (firstName.isEmpty || lastName.isEmpty) {
        final meta = user.userMetadata ?? {};
        firstName = firstName.isEmpty
            ? (meta['name'] ?? '').toString().trim()
            : firstName;
        lastName = lastName.isEmpty
            ? (meta['surname'] ?? '').toString().trim()
            : lastName;
      }

      final fullName = '$firstName $lastName'.trim();

      final parsedDob = _parseDob(data['dob']);

      final dep = (data['department'] ?? '').toString().trim();
      // Veritabanından gelen değer listedeyse onu seç, değilse null bırak (hint gözüksün)
      final normalized = dep.isEmpty ? null : dep;
      final inList = _departments.contains(normalized);

      if (!mounted) return;
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

        _selectedDepartment = inList
            ? normalized
            : normalized; // listedeyse de değilse de gösterelim; dropdown'da yoksa "Other" seçebilirsin
        profileImageUrl = (data['avatar_url'] ?? '').toString();
      });
    } on HC50Exception catch (e) {
      if (!mounted) return;
      NetworkErrorHandler.showErrorSnackBar(context, message: e.message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

// Report a bug
  Future<void> _reportBug() async {
    final me = supa.auth.currentUser?.id;
    final meta = await _collectBugMeta();
    if (me == null) return;

    String selected = _bugReasons.first;
    _bugDetailsCtrl.clear();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report a bug'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selected,
              items: _bugReasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => selected = v ?? selected,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bugDetailsCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'What happened? Steps to reproduce?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await supa.from('bug_reports').insert({
        'reporter_id': me,
        'screen': 'profile',
        'reason': selected,
        'details': _bugDetailsCtrl.text.trim().isEmpty
            ? null
            : _bugDetailsCtrl.text.trim(),
        'meta': meta,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Thanks! Bug reported.')));
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    await Supabase.instance.client.auth.signOut();

    // Navigate to login and remove all previous routes
    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
    messenger.showSnackBar(
      const SnackBar(content: Text('Logged out')),
    );
  }

  Future<void> updateProfile() async {
    final user = supa.auth.currentUser;
    if (user == null) return;

    try {
      // Kullanıcı metin kutusuna manuel yazdıysa ve _dob null ise, kaydetmeden parse et.
      if (_dob == null && dobController.text.trim().isNotEmpty) {
        _dob = _parseDob(dobController.text.trim());
      }

      final fullName = nameController.text.trim();
      final nameParts = fullName.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts.first.trim() : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ').trim() : '';

      // Update Auth metadata (this updates raw_user_meta_data which is displayed as Display Name)
      final authResponse = await NetworkErrorHandler.handleNetworkCall(
        () async {
          return await supa.auth.updateUser(
            UserAttributes(
              data: {
                'full_name': fullName,
                'name': firstName,
                'surname': lastName,
              },
            ),
          );
        },
        context: 'Failed to update authentication profile',
      );

      // Log for debugging
      debugPrint('Auth update response: ${authResponse.user?.userMetadata}');

      // Force refresh the session to get updated user data
      await supa.auth.refreshSession();

      // Update profiles table with separate name and surname
      final payload = <String, dynamic>{
        'name': firstName,
        'surname': lastName,
        'avatar_url': profileImageUrl,
        'department': (_selectedDepartment ?? '').trim(),
      };

      // _dob yoksa DB’deki dob’u ezme
      final dobIso = _fmtDateISO(_dob);
      if (dobIso != null) payload['dob'] = dobIso;

      await NetworkErrorHandler.handleNetworkCall(
        () => supa.from('profiles').update(payload).eq('id', user.id),
        context: 'Failed to update profile information',
      );

      if (!mounted) return;
      setState(() => isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } on HC50Exception catch (e) {
      if (!mounted) return;
      NetworkErrorHandler.showErrorSnackBar(context, message: e.message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
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
              contentType:
                  'image/jpeg', // isterseniz contentType değişkenini kullanın
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
        'avatar_url':
            urlWithTs, // (Tercihen DB'ye sadece objectPath yaz, okurken URL üret)
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Profile',
              onPressed: updateProfile,
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
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
            const SizedBox(height: 16),
            // Çiplerin "onPressed"lerini state'e bağlayabilmek için Builder kullan:
            Builder(
              builder: (ctx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Profile'),
                        onPressed: () => setState(() => isEditing = true),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.settings, size: 18),
                        label: const Text('Settings'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsView()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            // ⬇️ EKLE: Report a bug (tam genişlik, unobtrusive)
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.bug_report_outlined),
                  label: const Text('Report a bug'),
                  onPressed: _reportBug, // <-- yeni fonksiyon
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
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
