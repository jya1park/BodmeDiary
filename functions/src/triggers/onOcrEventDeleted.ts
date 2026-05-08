import { onDocumentDeleted } from 'firebase-functions/v2/firestore';

import { REGION } from '../config';
import { storage } from '../lib/firestore';

/// OCR 로 생성된 이벤트 삭제 시 Storage 사진도 정리.
export const onOcrEventDeleted = onDocumentDeleted(
  {
    region: REGION,
    document: 'families/{familyId}/babies/{babyId}/events/{eventId}',
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.source !== 'ocr') return;
    const path = data.ocrPhotoPath as string | undefined;
    if (!path) return;
    try {
      await storage.bucket().file(path).delete();
    } catch (e) {
      console.warn('OCR photo delete failed', path, e);
    }
  }
);
