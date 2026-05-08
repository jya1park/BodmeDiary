import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';

import { OCR_DAILY_QUOTA, OPENAI_API_KEY, REGION } from '../config';
import { assertAuth, assertFamilyMember } from '../lib/auth';
import { db, FieldValue, storage, Timestamp } from '../lib/firestore';
import { callOpenAi } from './openaiClient';

const Input = z.object({
  familyId: z.string().min(1),
  babyId: z.string().min(1),
  storagePath: z.string().min(1),
  assumedDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

const FeedingSchema = z
  .object({
    side: z
      .enum(['leftBreast', 'rightBreast', 'bottle', 'pump'])
      .nullable()
      .optional(),
    amountMl: z.number().int().nonnegative().nullable().optional(),
  })
  .nullable()
  .optional();

const DiaperSchema = z
  .object({
    kind: z.enum(['pee', 'poop', 'both']).nullable().optional(),
  })
  .nullable()
  .optional();

const SleepSchema = z
  .object({ note: z.string().nullable().optional() })
  .nullable()
  .optional();

const EventSchema = z.object({
  id: z.string().default(''),
  type: z.enum(['feeding', 'diaper', 'sleep']),
  startTime: z.string().regex(/^\d{1,2}:\d{2}$/),
  endTime: z
    .string()
    .regex(/^\d{1,2}:\d{2}$/)
    .nullable()
    .optional(),
  feeding: FeedingSchema,
  diaper: DiaperSchema,
  sleep: SleepSchema,
  confidence: z.number().min(0).max(1).default(0.5),
  sourceText: z.string().nullable().optional(),
});

const ResponseSchema = z.object({
  date: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable()
    .optional(),
  events: z.array(EventSchema).default([]),
  warnings: z.array(z.string()).default([]),
  rawText: z.string().nullable().optional(),
});

async function checkOcrQuota(uid: string): Promise<void> {
  const today = new Date();
  const key = `${today.getUTCFullYear()}-${String(
    today.getUTCMonth() + 1
  ).padStart(2, '0')}-${String(today.getUTCDate()).padStart(2, '0')}`;
  const ref = db.doc(`ocrQuotas/${uid}_${key}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = (snap.data()?.count ?? 0) as number;
    if (count >= OCR_DAILY_QUOTA) {
      throw new HttpsError(
        'resource-exhausted',
        `오늘의 OCR 분석 한도(${OCR_DAILY_QUOTA}회)를 초과했습니다.`
      );
    }
    tx.set(
      ref,
      {
        count: count + 1,
        updatedAt: FieldValue.serverTimestamp(),
        expiresAt: Timestamp.fromMillis(
          Date.now() + 7 * 24 * 60 * 60 * 1000
        ),
      },
      { merge: true }
    );
  });
}

export const parseHandwrittenLog = onCall(
  { region: REGION, secrets: [OPENAI_API_KEY] },
  async (req) => {
    const uid = assertAuth(req);
    const input = Input.parse(req.data);
    await assertFamilyMember(uid, input.familyId);
    await checkOcrQuota(uid);

    // Storage 에서 이미지 다운로드
    const bucket = storage.bucket();
    const file = bucket.file(input.storagePath);
    const [exists] = await file.exists();
    if (!exists) {
      throw new HttpsError('not-found', '업로드된 사진을 찾을 수 없습니다.');
    }
    const [bytes] = await file.download();
    const [meta] = await file.getMetadata();
    const mimeType = meta.contentType || 'image/jpeg';

    // OpenAI 호출
    let text: string;
    try {
      const res = await callOpenAi(OPENAI_API_KEY.value(), bytes, mimeType);
      text = res.text;
    } catch (e) {
      throw new HttpsError('internal', `OpenAI 호출 실패: ${(e as Error).message}`);
    }

    let parsed: z.infer<typeof ResponseSchema>;
    try {
      parsed = ResponseSchema.parse(JSON.parse(text));
    } catch (e) {
      throw new HttpsError('internal', `OCR 응답 파싱 실패: ${(e as Error).message}`);
    }

    const date = parsed.date ?? input.assumedDate ?? null;
    const events = parsed.events.map((e, i) => ({
      ...e,
      id: e.id || `e${i + 1}`,
      date,
    }));

    return {
      draftId: `${Date.now()}_${uid}`,
      events,
      warnings: parsed.warnings ?? [],
      rawText: parsed.rawText ?? null,
    };
  }
);
