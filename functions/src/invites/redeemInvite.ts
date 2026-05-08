import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';

import { REGION } from '../config';
import { assertAuth } from '../lib/auth';
import { db, FieldValue } from '../lib/firestore';

const Input = z.object({ code: z.string().length(6) });

// 간단한 메모리 기반 rate-limit (10회/시간/uid).
// 프로덕션에서는 Firestore 또는 Redis 기반으로 교체 권장.
const recentRedeems = new Map<string, number[]>();
const RATE_WINDOW_MS = 60 * 60 * 1000;
const RATE_MAX = 10;

function checkRateLimit(uid: string) {
  const now = Date.now();
  const list = (recentRedeems.get(uid) ?? []).filter(
    (t) => now - t < RATE_WINDOW_MS
  );
  if (list.length >= RATE_MAX) {
    throw new HttpsError(
      'resource-exhausted',
      '시간당 합류 시도 한도를 초과했습니다.'
    );
  }
  list.push(now);
  recentRedeems.set(uid, list);
}

export const redeemInvite = onCall({ region: REGION }, async (req) => {
  const uid = assertAuth(req);
  const { code } = Input.parse(req.data);
  checkRateLimit(uid);

  const indexRef = db.doc(`inviteCodeIndex/${code}`);

  return db.runTransaction(async (tx) => {
    const indexSnap = await tx.get(indexRef);
    if (!indexSnap.exists) {
      throw new HttpsError('not-found', '유효하지 않은 코드입니다.');
    }
    const data = indexSnap.data()!;
    if (data.used) {
      throw new HttpsError('failed-precondition', '이미 사용된 코드입니다.');
    }
    const expiresAt = data.expiresAt?.toMillis?.() ?? 0;
    if (Date.now() > expiresAt) {
      throw new HttpsError('failed-precondition', '만료된 코드입니다.');
    }
    const familyId = data.familyId as string;

    const familyRef = db.doc(`families/${familyId}`);
    const familySnap = await tx.get(familyRef);
    if (!familySnap.exists) {
      throw new HttpsError('not-found', '가족이 존재하지 않습니다.');
    }
    const memberUids = (familySnap.data()?.memberUids ?? []) as string[];
    if (memberUids.includes(uid)) {
      // 이미 멤버 — idempotent
      return { familyId };
    }

    const userRef = db.doc(`users/${uid}`);
    const userSnap = await tx.get(userRef);
    if (userSnap.exists && userSnap.data()?.familyId) {
      throw new HttpsError(
        'failed-precondition',
        '이미 다른 가족에 속해 있습니다.'
      );
    }

    tx.update(familyRef, {
      memberUids: FieldValue.arrayUnion(uid),
    });
    tx.set(
      userRef,
      { familyId, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );

    const familyCodeRef = db.doc(
      `families/${familyId}/inviteCodes/${code}`
    );
    const usedPayload = {
      used: true,
      usedByUid: uid,
      usedAt: FieldValue.serverTimestamp(),
    };
    tx.update(indexRef, usedPayload);
    tx.set(familyCodeRef, usedPayload, { merge: true });

    return { familyId };
  });
});
