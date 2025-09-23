// lib/e2ee/e2ee_key_manager.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class E2EEKeyManager {
  static const _privKeyKey = 'lt_priv_x25519_b64';
  static const _pubKeyKey  = 'lt_pub_x25519_b64';

  static const String _wrapInfo = 'cek-wrap-v1';
  static const String _wrapAad  = 'cek-wrap';

  final _storage = const FlutterSecureStorage();
  final AesGcm _aead = AesGcm.with256bits();

  KeyPair? _myKeyPair; // uzun vadeli X25519
  String? _myPubB64;

  // ---------- LIFECYCLE ----------

  Future<void> loadKeyPairFromStorage() async {
    final privB64 = await _storage.read(key: _privKeyKey);
    final pubB64  = await _storage.read(key: _pubKeyKey);

    if (privB64 != null && pubB64 != null) {
      final privBytes = base64Decode(privB64);
      final pubBytes  = base64Decode(pubB64);
      _myKeyPair = SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      _myPubB64 = pubB64;
    } else {
      final kp  = await X25519().newKeyPair();
      final pk  = await kp.extractPublicKey();
      final pub = base64Encode(pk.bytes);
      final prv = base64Encode(await kp.extractPrivateKeyBytes());

      await _storage.write(key: _privKeyKey, value: prv);
      await _storage.write(key: _pubKeyKey,  value: pub);

      _myKeyPair = kp;
      _myPubB64  = pub;
    }

    final uid = Supabase.instance.client.auth.currentUser!.id;
    await Supabase.instance.client.from('user_keys').upsert({
      'user_id': uid,
      'public_key_base64': _myPubB64,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> getUserPublicKey(String userId) async {
    final me = Supabase.instance.client.auth.currentUser!.id;
    if (userId == me) {
      if (_myPubB64 == null) {
        await loadKeyPairFromStorage();
      }
      return _myPubB64!;
    }
    final row = await Supabase.instance.client
        .from('user_keys')
        .select('public_key_base64')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null || (row['public_key_base64'] as String?)?.isNotEmpty != true) {
      throw Exception('Public key not found for user $userId');
    }
    return row['public_key_base64'] as String;
  }

  // ---------- CEK SARMA / AÇMA ----------

  Future<Map<String, String>> wrapCekForUser({
    required List<int> cekBytes32,
    required String recipientPub,
  }) async {
    if (cekBytes32.length != 32) {
      throw ArgumentError('CEK must be 32 bytes, got ${cekBytes32.length}');
    }

    final recipPub = SimplePublicKey(
      base64Decode(recipientPub.trim()),
      type: KeyPairType.x25519,
    );

    final eph = await X25519().newKeyPair();

    final shared = await X25519()
        .sharedSecretKey(keyPair: eph, remotePublicKey: recipPub);
    final sharedBytes = await shared.extractBytes();

    final wrapBytes = _hkdfSha256(
      ikm: sharedBytes,
      info: utf8.encode(_wrapInfo),
      length: 32,
    );

    final wrapKey = await _aead.newSecretKeyFromBytes(wrapBytes);

    final nonce = _randomBytes(12);
    final box = await _aead.encrypt(
      cekBytes32,
      secretKey: wrapKey,
      nonce: nonce,
      aad: utf8.encode(_wrapAad),
    );

    final ephPub = await eph.extractPublicKey();

    return {
      'wrapped_ct_b64': base64Encode(box.cipherText + box.mac.bytes),
      'wrapped_nonce_b64': base64Encode(nonce),
      'eph_pub_b64': base64Encode(ephPub.bytes),
    };
  }

  Future<List<int>> unwrapCekForMe({
    required String wrappedCtB64,
    required String wrappedNonceB64,
    required String ephPubB64,
  }) async {
    final kp = _myKeyPair!;
    final ephPub = SimplePublicKey(
      base64Decode(ephPubB64.trim()),
      type: KeyPairType.x25519,
    );

    final shared = await X25519()
        .sharedSecretKey(keyPair: kp, remotePublicKey: ephPub);
    final sharedBytes = await shared.extractBytes();

    final wrapBytes = _hkdfSha256(
      ikm: sharedBytes,
      info: utf8.encode(_wrapInfo),
      length: 32,
    );
    final wrapKey = await _aead.newSecretKeyFromBytes(wrapBytes);

    final nonce = base64Decode(wrappedNonceB64);
    final data  = base64Decode(wrappedCtB64);

    final mac = Mac(data.sublist(data.length - 16));
    final ct  = data.sublist(0, data.length - 16);

    final plain = await _aead.decrypt(
      SecretBox(ct, nonce: nonce, mac: mac),
      secretKey: wrapKey,
      aad: utf8.encode(_wrapAad),
    );
    return plain; // 32B CEK
  }

  // ---------- MESAJ ŞİFRELEME ----------

  static List<int> _aadForConv(String conversationId) =>
      utf8.encode('conv:$conversationId');

  Future<Map<String, String>> encryptMessage({
    required List<int> cekBytes32,
    required String plaintext,
    required String conversationId,
  }) async {
    if (cekBytes32.length != 32) {
      throw ArgumentError('CEK must be 32 bytes, got ${cekBytes32.length}');
    }
    final key   = await _aead.newSecretKeyFromBytes(
      Uint8List.fromList(cekBytes32),
    );
    final nonce = _randomBytes(12);

    final box = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
      aad: _aadForConv(conversationId),
    );

    return {
      'ct_b64': base64Encode(box.cipherText),
      'nonce_b64': base64Encode(nonce),
      'mac_b64': base64Encode(box.mac.bytes),
    };
  }

  Future<String> decryptMessage({
    required List<int> cekBytes32,
    required String ctB64,
    required String nonceB64,
    required String macB64,
    required String conversationId,
  }) async {
    final key = await _aead.newSecretKeyFromBytes(
      Uint8List.fromList(cekBytes32),
    );
    final pt = await _aead.decrypt(
      SecretBox(
        base64Decode(ctB64),
        nonce: base64Decode(nonceB64),
        mac: Mac(base64Decode(macB64)),
      ),
      secretKey: key,
      aad: _aadForConv(conversationId),
    );
    return utf8.decode(pt);
  }

  // ---------- UTIL ----------

  List<int> _randomBytes(int n) =>
      List<int>.generate(n, (_) => Random.secure().nextInt(256));

  Uint8List _hkdfSha256({
    required List<int> ikm,
    List<int>? salt,
    List<int>? info,
    int length = 32,
  }) {
    final hashLen = 32;
    final _salt = (salt == null || salt.isEmpty)
        ? Uint8List(hashLen) // zeros
        : Uint8List.fromList(salt);

    final prk = crypto.Hmac(crypto.sha256, _salt).convert(ikm).bytes;

    final List<int> okm = [];
    List<int> t = <int>[];
    int counter = 1;

    while (okm.length < length) {
      final hmac = crypto.Hmac(crypto.sha256, prk);
      final input = <int>[]
        ..addAll(t)
        ..addAll(info ?? const <int>[])
        ..add(counter);
      t = hmac.convert(input).bytes;
      okm.addAll(t);
      counter++;
    }
    return Uint8List.fromList(okm.sublist(0, length));
  }
}
