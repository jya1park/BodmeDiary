import { HttpsError, CallableRequest } from 'firebase-functions/v2/https';

import { db } from './firestore';

export function assertAuth(req: CallableRequest): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', '로그인이 필요합니다.');
  return uid;
}

export async function assertFamilyMember(
  uid: string,
  familyId: string
): Promise<void> {
  const snap = await db.doc(`families/${familyId}`).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', '가족을 찾을 수 없습니다.');
  }
  const memberUids = (snap.data()?.memberUids ?? []) as string[];
  if (!memberUids.includes(uid)) {
    throw new HttpsError('permission-denied', '가족 구성원이 아닙니다.');
  }
}
