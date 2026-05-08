import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 클라이언트에서 생성하는 안정 ID (오프라인 안전).
String newId() => _uuid.v4();
