import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 41)
class Post extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String authorId;
  @HiveField(2)
  final String content;
  @HiveField(3)
  final List<String> imagePaths; // local file paths
  @HiveField(4)
  final DateTime createdAt;

  Post({
    required this.id,
    required this.authorId,
    required this.content,
    required this.imagePaths,
    required this.createdAt,
  });
}

class PostAdapter extends TypeAdapter<Post> {
  @override
  final int typeId = 41;
  @override
  Post read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Post(
      id: fields[0] as String,
      authorId: fields[1] as String,
      content: fields[2] as String,
      imagePaths: (fields[3] as List).cast<String>(),
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Post obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.authorId)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.imagePaths)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}

@HiveType(typeId: 42)
class Comment extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String postId;
  @HiveField(2)
  final String authorId;
  @HiveField(3)
  final String content;
  @HiveField(4)
  final DateTime createdAt;
  @HiveField(5)
  final String? parentCommentId; // null => root comment

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.parentCommentId,
  });
}

class CommentAdapter extends TypeAdapter<Comment> {
  @override
  final int typeId = 42;
  @override
  Comment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Comment(
      id: fields[0] as String,
      postId: fields[1] as String,
      authorId: fields[2] as String,
      content: fields[3] as String,
      createdAt: fields[4] as DateTime,
      parentCommentId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Comment obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.postId)
      ..writeByte(2)
      ..write(obj.authorId)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.parentCommentId);
  }
}

@HiveType(typeId: 43)
class Like extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String postId;
  @HiveField(2)
  final String userId;
  @HiveField(3)
  final DateTime createdAt;

  Like({
    required this.id,
    required this.postId,
    required this.userId,
    required this.createdAt,
  });
}

class LikeAdapter extends TypeAdapter<Like> {
  @override
  final int typeId = 43;
  @override
  Like read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Like(
      id: fields[0] as String,
      postId: fields[1] as String,
      userId: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Like obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.postId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}

@HiveType(typeId: 44)
class Friendship extends HiveObject {
  @HiveField(0)
  final String id; // request id
  @HiveField(1)
  final String requesterId;
  @HiveField(2)
  final String addresseeId;
  @HiveField(3)
  final FriendshipStatus status;
  @HiveField(4)
  final DateTime createdAt;

  Friendship({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
  });
}

@HiveType(typeId: 45)
enum FriendshipStatus {
  @HiveField(0)
  pending,
  @HiveField(1)
  accepted,
  @HiveField(2)
  rejected,
}

class FriendshipAdapter extends TypeAdapter<Friendship> {
  @override
  final int typeId = 44;
  @override
  Friendship read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Friendship(
      id: fields[0] as String,
      requesterId: fields[1] as String,
      addresseeId: fields[2] as String,
      status: fields[3] as FriendshipStatus,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Friendship obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.requesterId)
      ..writeByte(2)
      ..write(obj.addresseeId)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}

class FriendshipStatusAdapter extends TypeAdapter<FriendshipStatus> {
  @override
  final int typeId = 45;
  @override
  FriendshipStatus read(BinaryReader reader) {
    final index = reader.readByte();
    switch (index) {
      case 0:
        return FriendshipStatus.pending;
      case 1:
        return FriendshipStatus.accepted;
      case 2:
        return FriendshipStatus.rejected;
      default:
        return FriendshipStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, FriendshipStatus obj) {
    switch (obj) {
      case FriendshipStatus.pending:
        writer.writeByte(0);
        break;
      case FriendshipStatus.accepted:
        writer.writeByte(1);
        break;
      case FriendshipStatus.rejected:
        writer.writeByte(2);
        break;
    }
  }
}

@HiveType(typeId: 44)
class CommentLike extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String commentId;
  @HiveField(2)
  final String userId;
  @HiveField(3)
  final DateTime createdAt;

  CommentLike({
    required this.id,
    required this.commentId,
    required this.userId,
    required this.createdAt,
  });
}

class CommentLikeAdapter extends TypeAdapter<CommentLike> {
  @override
  final int typeId = 44;

  @override
  CommentLike read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return CommentLike(
      id: fields[0] as String,
      commentId: fields[1] as String,
      userId: fields[2] as String,
      createdAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CommentLike obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.commentId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}
