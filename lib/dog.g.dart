// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dog.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DogAdapter extends TypeAdapter<Dog> {
  @override
  final int typeId = 0;

  @override
  Dog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dog(
      id: fields[0] as String,
      name: fields[1] as String,
      breed: fields[2] as String,
      age: fields[3] as int,
      gender: fields[4] as String,
      healthStatus: fields[5] as String,
      isNeutered: fields[6] as bool,
      description: fields[7] as String?,
      traits: (fields[8] as List).cast<String>(),
      ownerGender: fields[9] as String?,
      imagePaths: (fields[10] as List).cast<String>(),
      isAvailableForAdoption: fields[11] as bool,
      isOwner: fields[12] as bool,
      ownerId: fields[13] as String?,
      latitude: fields[14] as double?,
      longitude: fields[15] as double?,
      reportCount: fields[16] as int,
      isHidden: fields[17] as bool,
      moderationStatus: fields[18] as String,
      ownerProfileVisible: fields[19] as bool,
      dogProfileVisible: fields[20] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Dog obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.breed)
      ..writeByte(3)
      ..write(obj.age)
      ..writeByte(4)
      ..write(obj.gender)
      ..writeByte(5)
      ..write(obj.healthStatus)
      ..writeByte(6)
      ..write(obj.isNeutered)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.traits)
      ..writeByte(9)
      ..write(obj.ownerGender)
      ..writeByte(10)
      ..write(obj.imagePaths)
      ..writeByte(11)
      ..write(obj.isAvailableForAdoption)
      ..writeByte(12)
      ..write(obj.isOwner)
      ..writeByte(13)
      ..write(obj.ownerId)
      ..writeByte(14)
      ..write(obj.latitude)
      ..writeByte(15)
      ..write(obj.longitude)
      ..writeByte(16)
      ..write(obj.reportCount)
      ..writeByte(17)
      ..write(obj.isHidden)
      ..writeByte(18)
      ..write(obj.moderationStatus)
      ..writeByte(19)
      ..write(obj.ownerProfileVisible)
      ..writeByte(20)
      ..write(obj.dogProfileVisible);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
