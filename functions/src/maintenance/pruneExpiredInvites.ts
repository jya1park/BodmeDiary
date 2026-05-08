import { onSchedule } from 'firebase-functions/v2/scheduler';

import { REGION } from '../config';
import { db } from '../lib/firestore';

/// 만료/미사용 초대코드 정리 (일 1회).
export const pruneExpiredInvites = onSchedule(
  { region: REGION, schedule: '0 4 * * *', timeZone: 'Asia/Seoul' },
  async () => {
    const now = Date.now();
    const snap = await db
      .collection('inviteCodeIndex')
      .where('used', '==', false)
      .get();

    const batch = db.batch();
    let count = 0;
    for (const doc of snap.docs) {
      const expires = doc.data().expiresAt?.toMillis?.() ?? 0;
      if (expires < now) {
        batch.delete(doc.ref);
        const familyId = doc.data().familyId as string;
        batch.delete(db.doc(`families/${familyId}/inviteCodes/${doc.id}`));
        count += 1;
      }
    }
    if (count > 0) await batch.commit();
    console.log(`pruneExpiredInvites: removed ${count} codes`);
  }
);
