import 'package:flutter/material.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_NotificationItem>[
      _NotificationItem(
          icon: Icons.favorite,
          title: 'Ayşe gönderini beğendi',
          time: '2 dk önce',
          color: Colors.redAccent),
      _NotificationItem(
          icon: Icons.mode_comment_outlined,
          title: 'Mehmet gönderine yorum yaptı: “Harika!”',
          time: '15 dk önce'),
      _NotificationItem(
          icon: Icons.reply,
          title: 'Elif, yorumuna yanıt verdi',
          time: '1 sa önce'),
      _NotificationItem(
          icon: Icons.alternate_email,
          title: 'Can seni bir gönderide etiketledi',
          time: 'Dün'),
      _NotificationItem(
          icon: Icons.favorite,
          title: 'Zeynep gönderini beğendi',
          time: '2 gün önce',
          color: Colors.redAccent),
      _NotificationItem(
          icon: Icons.mode_comment_outlined,
          title: 'Ali gönderine yorum yaptı: “+1”',
          time: '3 gün önce'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final it = items[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  (it.color ?? Theme.of(context).colorScheme.primary)
                      .withOpacity(0.15),
              child: Icon(it.icon,
                  color: it.color ?? Theme.of(context).colorScheme.primary),
            ),
            title: Text(it.title),
            subtitle: Text(it.time, style: const TextStyle(color: Colors.grey)),
            onTap: () {},
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final String title;
  final String time;
  final Color? color;
  const _NotificationItem(
      {required this.icon,
      required this.title,
      required this.time,
      this.color});
}
