import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool isEditing = false;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController dobController;
  late TextEditingController departmentController;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    emailController = TextEditingController();
    dobController = TextEditingController();
    departmentController = TextEditingController();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profileResponse = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user!.id)
        .single();

    setState(() {
      nameController.text = '${user.userMetadata?['name'] ?? ''} ${user.userMetadata?['surname'] ?? ''}'.trim();
      emailController.text = user.email ?? '';
      if (profileResponse['dob'] != null && profileResponse['dob'].toString().isNotEmpty) {
        final dob = DateTime.tryParse(profileResponse['dob']);
        dobController.text = dob != null
        ? '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}'
        : '';
      } else {
        dobController.text = '';
      }
      departmentController.text = (profileResponse['department'] == null || profileResponse['department'].toString().trim().isEmpty)
          ? 'Please add department'
          : profileResponse['department'];
      profileImageUrl = profileResponse['avatar_url'];
    });
  }

  Future<void> updateProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    await Supabase.instance.client.from('profiles').update({
      'dob': dobController.text,
      'avatar_url': profileImageUrl,
      'department': departmentController.text,
    }).eq('id', user!.id);

    await Supabase.instance.client.auth.updateUser(UserAttributes(
      data: {'display_name': nameController.text},
    ));

    setState(() {
      isEditing = false;
    });
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final user = Supabase.instance.client.auth.currentUser;
      final fileName = '${user?.id}.png';
      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
      final url = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(fileName);
      setState(() {
        profileImageUrl = url;
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
                // TODO: Navigate to settings page
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontSize: 17)),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _showMenu(context),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Profile',
              onPressed: () async {
                await updateProfile();
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            GestureDetector(
              onTap: isEditing ? pickImage : null,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: profileImageUrl != null
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
              ),
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
            const SizedBox(height: 8),
            isEditing
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                  )
                : Text(
                    emailController.text,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
            const SizedBox(height: 24),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                            decoration: const InputDecoration(labelText: 'Date of Birth'),
                          )
                        : ProfileInfoRow(
                            icon: Icons.date_range_rounded,
                            label: 'Date of Birth',
                            value: dobController.text,
                          ),
                    const Divider(),
                    isEditing
                        ? TextField(
                            controller: departmentController,
                            decoration: const InputDecoration(labelText: 'Department'),
                          )
                        : ProfileInfoRow(
                            icon: Icons.school,
                            label: 'Department',
                            value: departmentController.text,
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                const Text(
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
            value,
            style: const TextStyle(color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}