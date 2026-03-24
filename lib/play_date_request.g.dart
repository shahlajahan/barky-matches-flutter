// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'play_date_request.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayDateRequestAdapter extends TypeAdapter<PlayDateRequest> {
  @override
  final int typeId = 2;

  @override
  PlayDateRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayDateRequest(
      requestId: fields[0] as String,
      requesterUserId: fields[1] as String,
      requestedUserId: fields[2] as String?,
      requesterDog: fields[3] as Dog,
      requestedDog: fields[4] as Dog,
      status: fields[5] as String,
      requestDate: fields[6] as DateTime?,
      scheduledDateTime: fields[7] as DateTime?,
      requesterName: fields[8] as String?,
      message: fields[9] as String?,
      location: fields[10] as String?,
      requesterDogId: fields[11] as String,
      requestedDogId: fields[12] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PlayDateRequest obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.requestId)
      ..writeByte(1)
      ..write(obj.requesterUserId)
      ..writeByte(2)
      ..write(obj.requestedUserId)
      ..writeByte(3)
      ..write(obj.requesterDog)
      ..writeByte(4)
      ..write(obj.requestedDog)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.requestDate)
      ..writeByte(7)
      ..write(obj.scheduledDateTime)
      ..writeByte(8)
      ..write(obj.requesterName)
      ..writeByte(9)
      ..write(obj.message)
      ..writeByte(10)
      ..write(obj.location)
      ..writeByte(11)
      ..write(obj.requesterDogId)
      ..writeByte(12)
      ..write(obj.requestedDogId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayDateRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
