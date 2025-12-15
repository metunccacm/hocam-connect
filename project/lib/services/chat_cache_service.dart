import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service for caching chat-related data to improve performance
/// Caches profile data (names, avatars) and conversation metadata
/// Uses both in-memory and persistent storage for instant access
class ChatCacheService {
  static final ChatCacheService _instance = ChatCacheService._internal();
  factory ChatCacheService() => _instance;
  ChatCacheService._internal();

  // Cache keys
  static const String _profileCacheKey = 'chat_profile_cache';
  static const String _conversationCacheKey = 'chat_conversation_cache';
  static const String _avatarCacheKey = 'chat_avatar_cache';
  
  // Cache expiry duration (24 hours)
  static const Duration _cacheExpiry = Duration(hours: 24);
  
  // In-memory cache for instant access (survives navigation)
  final Map<String, Map<String, dynamic>> _memoryProfileCache = {};
  final Map<String, Map<String, dynamic>> _memoryConversationCache = {};
  final Map<String, String> _memoryAvatarCache = {};
  
  // Cache for entire conversation list state (instant restore)
  List<String>? _cachedConversationIds;
  Map<String, String>? _cachedTitles;
  Map<String, String?>? _cachedAvatars;
  Map<String, String>? _cachedSnippets;
  Map<String, DateTime?>? _cachedLastTimes;
  Map<String, bool>? _cachedIsDm;
  Map<String, bool>? _cachedIBlocked;
  Map<String, bool>? _cachedBlockedMe;
  DateTime? _conversationListCachedAt;
  
  // Cache for individual chat messages (per conversation)
  final Map<String, dynamic> _cachedChatMessages = {};

  /// Cache a user profile (name, surname, avatar_url)
  Future<void> cacheUserProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? avatarUrl,
  }) async {
    try {
      final profileData = {
        'first_name': firstName,
        'last_name': lastName,
        'avatar_url': avatarUrl,
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      // Cache in memory first (instant access)
      _memoryProfileCache[userId] = profileData;
      
      // Then persist to disk
      final prefs = await SharedPreferences.getInstance();
      final cacheData = _loadProfileCache(prefs);
      cacheData[userId] = profileData;
      await prefs.setString(_profileCacheKey, json.encode(cacheData));
    } catch (e) {
      print('Error caching user profile: $e');
    }
  }

  /// Get cached user profile (checks memory first, then disk)
  Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    try {
      // Check memory cache first (instant)
      if (_memoryProfileCache.containsKey(userId)) {
        final profile = _memoryProfileCache[userId]!;
        final cachedAt = DateTime.parse(profile['cached_at'] as String);
        if (DateTime.now().difference(cachedAt) <= _cacheExpiry) {
          return profile;
        } else {
          // Remove expired entry from memory
          _memoryProfileCache.remove(userId);
        }
      }
      
      // Check disk cache
      final prefs = await SharedPreferences.getInstance();
      final cacheData = _loadProfileCache(prefs);
      final profile = cacheData[userId];
      
      if (profile == null) return null;
      
      // Check if cache is expired
      final cachedAt = DateTime.parse(profile['cached_at'] as String);
      if (DateTime.now().difference(cachedAt) > _cacheExpiry) {
        return null;
      }
      
      // Load into memory for next time
      _memoryProfileCache[userId] = profile;
      
      return profile;
    } catch (e) {
      print('Error getting cached user profile: $e');
      return null;
    }
  }

  /// Cache conversation metadata (title, avatar, members)
  Future<void> cacheConversationMeta({
    required String conversationId,
    required String title,
    String? avatarUrl,
    required List<String> memberIds,
  }) async {
    try {
      final metaData = {
        'title': title,
        'avatar_url': avatarUrl,
        'member_ids': memberIds,
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      // Cache in memory first (instant access)
      _memoryConversationCache[conversationId] = metaData;
      
      // Then persist to disk
      final prefs = await SharedPreferences.getInstance();
      final cacheData = _loadConversationCache(prefs);
      cacheData[conversationId] = metaData;
      await prefs.setString(_conversationCacheKey, json.encode(cacheData));
    } catch (e) {
      print('Error caching conversation meta: $e');
    }
  }

  /// Get cached conversation metadata (checks memory first, then disk)
  Future<Map<String, dynamic>?> getCachedConversationMeta(String conversationId) async {
    try {
      // Check memory cache first (instant)
      if (_memoryConversationCache.containsKey(conversationId)) {
        final conversation = _memoryConversationCache[conversationId]!;
        final cachedAt = DateTime.parse(conversation['cached_at'] as String);
        if (DateTime.now().difference(cachedAt) <= _cacheExpiry) {
          return conversation;
        } else {
          // Remove expired entry from memory
          _memoryConversationCache.remove(conversationId);
        }
      }
      
      // Check disk cache
      final prefs = await SharedPreferences.getInstance();
      final cacheData = _loadConversationCache(prefs);
      final conversation = cacheData[conversationId];
      
      if (conversation == null) return null;
      
      // Check if cache is expired
      final cachedAt = DateTime.parse(conversation['cached_at'] as String);
      if (DateTime.now().difference(cachedAt) > _cacheExpiry) {
        return null;
      }
      
      // Load into memory for next time
      _memoryConversationCache[conversationId] = conversation;
      
      return conversation;
    } catch (e) {
      print('Error getting cached conversation meta: $e');
      return null;
    }
  }

  /// Cache avatar URL for quick access
  Future<void> cacheAvatarUrl(String userId, String? avatarUrl) async {
    try {
      // Cache in memory first
      if (avatarUrl != null) {
        _memoryAvatarCache[userId] = avatarUrl;
      }
      
      // Then persist to disk
      final prefs = await SharedPreferences.getInstance();
      final cacheData = _loadAvatarCache(prefs);
      
      cacheData[userId] = {
        'url': avatarUrl,
        'cached_at': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(_avatarCacheKey, json.encode(cacheData));
    } catch (e) {
      print('Error caching avatar URL: $e');
    }
  }

  /// Get cached avatar URL (checks memory first, then disk)
  Future<String?> getCachedAvatarUrl(String userId) async {
    try {
      // Check memory cache first (instant)
      if (_memoryAvatarCache.containsKey(userId)) {
        return _memoryAvatarCache[userId];
      }
      
      // Check disk cache
      final prefs = await SharedPreferences.getInstance();
      final cacheData = _loadAvatarCache(prefs);
      final avatarData = cacheData[userId];
      
      if (avatarData == null) return null;
      
      // Check if cache is expired
      final cachedAt = DateTime.parse(avatarData['cached_at'] as String);
      if (DateTime.now().difference(cachedAt) > _cacheExpiry) {
        return null;
      }
      
      final url = avatarData['url'] as String?;
      
      // Load into memory for next time
      if (url != null) {
        _memoryAvatarCache[userId] = url;
      }
      
      return url;
    } catch (e) {
      print('Error getting cached avatar URL: $e');
      return null;
    }
  }

  /// Cache entire conversation list state for instant restore
  void cacheConversationListState({
    required List<String> conversationIds,
    required Map<String, String> titles,
    required Map<String, String?> avatars,
    required Map<String, String> snippets,
    required Map<String, DateTime?> lastTimes,
    Map<String, bool>? isDm,
    Map<String, bool>? iBlocked,
    Map<String, bool>? blockedMe,
  }) {
    _cachedConversationIds = List.from(conversationIds);
    _cachedTitles = Map.from(titles);
    _cachedAvatars = Map.from(avatars);
    _cachedSnippets = Map.from(snippets);
    _cachedLastTimes = Map.from(lastTimes);
    if (isDm != null) _cachedIsDm = Map.from(isDm);
    if (iBlocked != null) _cachedIBlocked = Map.from(iBlocked);
    if (blockedMe != null) _cachedBlockedMe = Map.from(blockedMe);
    _conversationListCachedAt = DateTime.now();
  }
  
  /// Get cached conversation list state (returns null if not cached or expired)
  Map<String, dynamic>? getCachedConversationListState() {
    if (_cachedConversationIds == null || _conversationListCachedAt == null) {
      return null;
    }
    
    // Check if cache is still valid (5 minutes for list state)
    final cacheAge = DateTime.now().difference(_conversationListCachedAt!);
    if (cacheAge > const Duration(minutes: 5)) {
      // Cache expired, clear it
      _cachedConversationIds = null;
      _cachedTitles = null;
      _cachedAvatars = null;
      _cachedSnippets = null;
      _cachedLastTimes = null;
      _cachedIsDm = null;
      _cachedIBlocked = null;
      _cachedBlockedMe = null;
      _conversationListCachedAt = null;
      return null;
    }
    
    return {
      'conversationIds': _cachedConversationIds!,
      'titles': _cachedTitles!,
      'avatars': _cachedAvatars!,
      'snippets': _cachedSnippets!,
      'lastTimes': _cachedLastTimes!,
      'isDm': _cachedIsDm ?? {},
      'iBlocked': _cachedIBlocked ?? {},
      'blockedMe': _cachedBlockedMe ?? {},
    };
  }
  
  /// Cache chat messages for a conversation
  void cacheChatMessages({
    required String conversationId,
    required dynamic messages,
    required Map<String, String> decryptedMessages,
    String? otherDisplayName,
    String? otherAvatarUrl,
  }) {
    _cachedChatMessages[conversationId] = {
      'messages': messages,
      'decryptedMessages': Map<String, String>.from(decryptedMessages),
      'otherDisplayName': otherDisplayName,
      'otherAvatarUrl': otherAvatarUrl,
      'cachedAt': DateTime.now(),
    };
  }
  
  /// Get cached chat messages for a conversation
  Map<String, dynamic>? getCachedChatMessages(String conversationId) {
    final cached = _cachedChatMessages[conversationId];
    if (cached == null) return null;
    
    // Check if cache is still valid (5 minutes for messages)
    final cachedAt = cached['cachedAt'] as DateTime;
    final cacheAge = DateTime.now().difference(cachedAt);
    if (cacheAge > const Duration(minutes: 5)) {
      _cachedChatMessages.remove(conversationId);
      return null;
    }
    
    return cached;
  }

  /// Clear all caches (both memory and disk)
  Future<void> clearAllCaches() async {
    try {
      // Clear memory caches
      _memoryProfileCache.clear();
      _memoryConversationCache.clear();
      _memoryAvatarCache.clear();
      
      // Clear conversation list cache
      _cachedConversationIds = null;
      _cachedTitles = null;
      _cachedAvatars = null;
      _cachedSnippets = null;
      _cachedLastTimes = null;
      _cachedIsDm = null;
      _cachedIBlocked = null;
      _cachedBlockedMe = null;
      _conversationListCachedAt = null;
      
      // Clear chat messages cache
      _cachedChatMessages.clear();
      
      // Clear disk caches
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_profileCacheKey);
      await prefs.remove(_conversationCacheKey);
      await prefs.remove(_avatarCacheKey);
    } catch (e) {
      print('Error clearing caches: $e');
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear expired profiles
      final profiles = _loadProfileCache(prefs);
      profiles.removeWhere((key, value) {
        try {
          final cachedAt = DateTime.parse(value['cached_at'] as String);
          return DateTime.now().difference(cachedAt) > _cacheExpiry;
        } catch (e) {
          return true; // Remove if can't parse
        }
      });
      await prefs.setString(_profileCacheKey, json.encode(profiles));
      
      // Clear expired conversations
      final conversations = _loadConversationCache(prefs);
      conversations.removeWhere((key, value) {
        try {
          final cachedAt = DateTime.parse(value['cached_at'] as String);
          return DateTime.now().difference(cachedAt) > _cacheExpiry;
        } catch (e) {
          return true;
        }
      });
      await prefs.setString(_conversationCacheKey, json.encode(conversations));
      
      // Clear expired avatars
      final avatars = _loadAvatarCache(prefs);
      avatars.removeWhere((key, value) {
        try {
          final cachedAt = DateTime.parse(value['cached_at'] as String);
          return DateTime.now().difference(cachedAt) > _cacheExpiry;
        } catch (e) {
          return true;
        }
      });
      await prefs.setString(_avatarCacheKey, json.encode(avatars));
    } catch (e) {
      print('Error clearing expired caches: $e');
    }
  }

  // Helper methods to load cache data
  Map<String, dynamic> _loadProfileCache(SharedPreferences prefs) {
    try {
      final String? cacheStr = prefs.getString(_profileCacheKey);
      if (cacheStr == null) return {};
      return Map<String, dynamic>.from(json.decode(cacheStr));
    } catch (e) {
      return {};
    }
  }

  Map<String, dynamic> _loadConversationCache(SharedPreferences prefs) {
    try {
      final String? cacheStr = prefs.getString(_conversationCacheKey);
      if (cacheStr == null) return {};
      return Map<String, dynamic>.from(json.decode(cacheStr));
    } catch (e) {
      return {};
    }
  }

  Map<String, dynamic> _loadAvatarCache(SharedPreferences prefs) {
    try {
      final String? cacheStr = prefs.getString(_avatarCacheKey);
      if (cacheStr == null) return {};
      return Map<String, dynamic>.from(json.decode(cacheStr));
    } catch (e) {
      return {};
    }
  }
}
