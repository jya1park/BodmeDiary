import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';

import { REGION, INVITE_TTL_MS } from '../config';
import { assertAuth, assertFamilyMember } from '../lib/auth';
import { db, FieldValue, Timestamp } from '../lib/firestore';
import { generateCode } from './code';

const Input = z.object({ familyId: z.string().min(1) });

export const createInvite = onCall({ region: REGION }, async (req) => {
  const uid = assertAuth(req);
  const { familyId } = Input.parse(req.data);
  await assertFamilyMember(uid, familyId);

  const expiresAt = Timestamp.fromMillis(Date.now() + INVITE_TTL_MS);

  // 충돌 방지: 최대 5회 시도
  for (let i = 0; i < 5; i++) {
    const code = generateCode();
    const indexRef = db.doc(`inviteCodeIndex/${code}`);
    const familyCodeRef = db.doc(`families/${familyId}/inviteCodes/${code}`);

    try {
      await db.runTransaction(async (tx) => {
        const existing = await tx.get(indexRef);
        if (existing.exists) {
          throw new Error('collision');
        }
        const payload = {
          familyId,
          createdByUid: uid,
          createdAt: FieldValue.serverTimestamp(),
          expiresAt,
          used: false,
        };
        tx.set(indexRef, payload);
        tx.set(familyCodeRef, payload);
      });
      return { code, expiresAt: expiresAt.toMillis() };
    } catch (e) {
      if ((e as Error).message === 'collision') continue;
      throw e;
    }
  }
  throw new HttpsError('internal', '코드 생성 실패. 잠시 후 다시 시도해 주세요.');
});
