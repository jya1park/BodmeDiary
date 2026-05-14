import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { z } from 'zod';

import { GEMINI_API_KEY, OCR_DAILY_QUOTA, REGION } from '../config';
import { assertAuth, assertFamilyMember } from '../lib/auth';
import { db, FieldValue, Timestamp } from '../lib/firestore';
import { callGemini } from './geminiClient';

/// 클라이언트가 사진을 base64 로 인라인 전송. Storage 경유 없음.
const Input = z.object({
  familyId: z.string().min(1),
  babyId: z.string().min(1),
  imageBase64: z.string().min(1),
  mimeType: z.string().default('image/jpeg'),
  assumedDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .optional(),
});

const FeedingSchema = z
  .object({
    method: z.enum(['breast', 'formula']).nullable().optional(),
    amountMl: z.number().int().nonnegative().nullable().optional(),
    note: z.string().nullable().optional(),
  })
  .nullable()
  .optional();

const DiaperSchema = z
  .object({
    kind: z.enum(['pee', 'poop', 'both']).nullable().optional(),
    note: z.string().nullable().optional(),
  })
  .nullable()
  .optional();

const SleepSchema = z
  .object({ note: z.string().nullable().optional() })
  .nullable()
  .optional();

const EventSchema = z.object({
  type: z.enum(['feeding', 'diaper', 'sleep']),
  startTime: z.string().regex(/^\d{1,2}:\d{2}$/),
  endTime: z
    .string()
    .regex(/^\d{1,2}:\d{2}$/)
    .nullable()
    .optional(),
  count: z.number().int().positive().default(1),
  feeding: FeedingSchema,
  diaper: DiaperSchema,
  sleep: SleepSchema,
  confidence: z.number().min(0).max(1).default(0.5),
  warnings: z.array(z.string()).default([]),
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
  { region: REGION, secrets: [GEMINI_API_KEY] },
  async (req) => {
    const uid = assertAuth(req);
    const input = Input.parse(req.data);
    await assertFamilyMember(uid, input.familyId);
    await checkOcrQuota(uid);

    // base64 → Buffer (Storage 경유 없음 — 사진은 Function 메모리에서만 처리되고 폐기)
    let bytes: Buffer;
    try {
      bytes = Buffer.from(input.imageBase64, 'base64');
    } catch (e) {
      throw new HttpsError('invalid-argument', '이미지 데이터를 읽을 수 없습니다.');
    }
    if (bytes.length === 0) {
      throw new HttpsError('invalid-argument', '이미지 데이터가 비어있습니다.');
    }

    // Gemini 호출
    let text: string;
    try {
      const res = await callGemini(
        GEMINI_API_KEY.value(),
        bytes,
        input.mimeType
      );
      text = res.text;
    } catch (e) {
      throw new HttpsError('internal', `Gemini 호출 실패: ${(e as Error).message}`);
    }

    let parsed: z.infer<typeof ResponseSchema>;
    try {
      parsed = ResponseSchema.parse(JSON.parse(text));
    } catch (e) {
      logger.warn('OCR response parse failed', {
        uid,
        rawText: text.slice(0, 2000),
        error: (e as Error).message,
      });
      throw new HttpsError('internal', `OCR 응답 파싱 실패: ${(e as Error).message}`);
    }

    const date = parsed.date ?? input.assumedDate ?? null;

    // count 필드를 펼쳐 N개 이벤트로 변환 (서버 측 expansion — 클라이언트 변경 없음)
    const events: Array<Record<string, unknown>> = [];
    for (const e of parsed.events) {
      const n = Math.max(1, e.count ?? 1);
      const rest: Record<string, unknown> = { ...e };
      delete rest.count;
      for (let i = 0; i < n; i++) {
        events.push({
          ...rest,
          id: `e${events.length + 1}`,
          date,
        });
      }
    }

    logger.info('OCR parsed', {
      uid,
      babyId: input.babyId,
      date,
      compactCount: parsed.events.length,
      expandedCount: events.length,
      warnings: parsed.warnings,
      events: parsed.events, // 압축 형태로 로깅 (펼친 후는 N배 큼)
    });

    return {
      draftId: `${Date.now()}_${uid}`,
      events,
      warnings: parsed.warnings ?? [],
      rawText: parsed.rawText ?? null,
    };
  }
);
