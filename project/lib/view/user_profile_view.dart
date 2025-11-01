import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';

class UserProfileView extends StatefulWidget {
  final String userId;
  final SocialRepository repository;

  const UserProfileView({
    super.key,
    required this.userId,
    required this.repository,
  });

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final supa = Supabase.instance.client;

  bool _loading = true;
  SocialUser? _user;
  String? _department;

  /// 'me' | 'none' | 'pending_outgoing' | 'pending_incoming' | 'friends'
  String _friendState = 'none';
  String? _friendshipId;

  String get meId => supa.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    setState(() => _loading = true);

    _user = await widget.repository.getUser(widget.userId);

    final profile = await supa
        .from('profiles')
        .select('department')
        .eq('id', widget.userId)
        .maybeSingle();
    _department = profile?['department'] as String?;

    if (widget.userId == meId) {
      _friendState = 'me';
      _friendshipId = null;
    } else {
      final outgoing = await supa
          .from('friendships')
          .select('id, status')
          .eq('requester_id', meId)
          .eq('addressee_id', widget.userId)
          .maybeSingle();

      final incoming = await supa
          .from('friendships')
          .select('id, status')
          .eq('requester_id', widget.userId)
          .eq('addressee_id', meId)
          .maybeSingle();

      if (outgoing != null) {
        final status = outgoing['status'] as String?;
        _friendshipId = outgoing['id'] as String?;
        if (status == 'accepted') _friendState = 'friends';
        else if (status == 'pending') _friendState = 'pending_outgoing';
        else _friendState = 'none';
      } else if (incoming != null) {
        final status = incoming['status'] as String?;
        _friendshipId = incoming['id'] as String?;
        if (status == 'accepted') _friendState = 'friends';
        else if (status == 'pending') _friendState = 'pending_incoming';
        else _friendState = 'none';
      } else {
        _friendState = 'none';
        _friendshipId = null;
      }
    }

    setState(() => _loading = false);
  }

  Future<void> _sendFriendRequest() async {
    try {
      await widget.repository.sendFriendRequest(
        fromUserId: meId,
        toUserId: widget.userId,
      );
      await _hydrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cancelOutgoingRequest() async {
    try {
      if (_friendshipId == null) return;
      await supa
          .from('friendships')
          .delete()
          .eq('id', _friendshipId!)
          .eq('requester_id', meId)
          .eq('addressee_id', widget.userId)
          .eq('status', 'pending');
      await _hydrate();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request cancelled')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _acceptIncoming() async {
    try {
      if (_friendshipId == null) return;
      await widget.repository.respondFriendRequest(
        requestId: _friendshipId!,
        accept: true,
      );
      await _hydrate();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Friend added')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _declineIncoming() async {
    try {
      if (_friendshipId == null) return;
      await widget.repository.respondFriendRequest(
        requestId: _friendshipId!,
        accept: false,
      );
      await _hydrate();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Request declined')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _unfriend() async {
    try {
      await supa.from('friendships').delete().or(
            'and(requester_id.eq.$meId,addressee_id.eq.${widget.userId},status.eq.accepted),'
            'and(requester_id.eq.${widget.userId},addressee_id.eq.$meId,status.eq.accepted)',
          );
      await _hydrate();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Unfriended')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final name = user?.displayName ?? 'User';
    final avatarUrl = user?.avatarUrl;

    return Scaffold(
      appBar: AppBar(title: Text(name), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      backgroundColor: Colors.blue.shade100,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Icon(Icons.person, size: 48, color: Colors.blue.shade700)
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (_department != null && _department!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(_department!,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                    
                    if (_friendState == 'me')
                      const Text('This is your profile',
                          style: TextStyle(color: Colors.grey)),
                    if (_friendState == 'none')
                      FilledButton.icon(
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Add Friend'),
                        onPressed: _sendFriendRequest,
                      ),
                    if (_friendState == 'pending_outgoing')
                      Column(
                        children: [
                          const Chip(label: Text('Request Pending')),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Cancel Request'),
                            onPressed: _cancelOutgoingRequest,
                          ),
                        ],
                      ),
                    if (_friendState == 'pending_incoming')
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            onPressed: _acceptIncoming,
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Decline'),
                            onPressed: _declineIncoming,
                          ),
                        ],
                      ),
                    if (_friendState == 'friends')
                      Column(
                        children: [
                          const Chip(label: Text('Friends')),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.person_remove_alt_1),
                            label: const Text('Unfriend'),
                            onPressed: _unfriend,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
