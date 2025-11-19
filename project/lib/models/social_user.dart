import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 40)
class SocialUser extends HiveObject {
  @HiveField(0)
  final String id; // Supabase user id or locally generated id

  @HiveField(1)
  final String displayName;

  @HiveField(2)
  final String? avatarUrl;

  SocialUser({required this.id, required this.displayName, this.avatarUrl});
}

class SocialUserAdapter extends TypeAdapter<SocialUser> {
  @override
  final int typeId = 40;

  @override
  SocialUser read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return SocialUser(
      id: fields[0] as String,
      displayName: fields[1] as String,
      avatarUrl: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SocialUser obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.avatarUrl);
  }
}
