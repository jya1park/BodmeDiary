/// Firestore 경로를 한 곳에서 관리. 컬렉션명을 절대 문자열로 흩뿌리지 말 것.
class FirestorePaths {
  FirestorePaths._();

  static String users = 'users';
  static String user(String uid) => 'users/$uid';

  static String families = 'families';
  static String family(String familyId) => 'families/$familyId';

  static String babies(String familyId) => 'families/$familyId/babies';
  static String baby(String familyId, String babyId) =>
      'families/$familyId/babies/$babyId';

  static String events(String familyId, String babyId) =>
      'families/$familyId/babies/$babyId/events';
  static String event(String familyId, String babyId, String eventId) =>
      'families/$familyId/babies/$babyId/events/$eventId';

  static String activeTimers(String familyId, String babyId) =>
      'families/$familyId/babies/$babyId/activeTimers';
  static String activeTimer(
    String familyId,
    String babyId,
    String timerType,
  ) =>
      'families/$familyId/babies/$babyId/activeTimers/$timerType';

  static String inviteCodes(String familyId) =>
      'families/$familyId/inviteCodes';
  static String inviteCode(String familyId, String code) =>
      'families/$familyId/inviteCodes/$code';

  static String inviteCodeIndex = 'inviteCodeIndex';
}
