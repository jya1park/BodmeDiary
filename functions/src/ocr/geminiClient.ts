import { GoogleGenAI, Type } from '@google/genai';

import { GEMINI_MODEL } from '../config';
import { SYSTEM_PROMPT } from './prompt';

export interface OcrCallResult {
  text: string;
}

/// 모델 출력을 강제하기 위한 responseSchema. zod 검증과 동치.
const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    date: { type: Type.STRING, nullable: true },
    events: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          type: { type: Type.STRING, enum: ['feeding', 'diaper', 'sleep'] },
          startTime: { type: Type.STRING },
          endTime: { type: Type.STRING, nullable: true },
          count: { type: Type.INTEGER, nullable: true },
          feeding: {
            type: Type.OBJECT,
            nullable: true,
            properties: {
              method: {
                type: Type.STRING,
                enum: ['breast', 'formula'],
                nullable: true,
              },
              amountMl: { type: Type.INTEGER, nullable: true },
              note: { type: Type.STRING, nullable: true },
            },
          },
          diaper: {
            type: Type.OBJECT,
            nullable: true,
            properties: {
              kind: {
                type: Type.STRING,
                enum: ['pee', 'poop', 'both'],
                nullable: true,
              },
              note: { type: Type.STRING, nullable: true },
            },
          },
          sleep: {
            type: Type.OBJECT,
            nullable: true,
            properties: {
              note: { type: Type.STRING, nullable: true },
            },
          },
          confidence: { type: Type.NUMBER, nullable: true },
          warnings: { type: Type.ARRAY, items: { type: Type.STRING } },
          sourceText: { type: Type.STRING, nullable: true },
        },
        required: ['type', 'startTime'],
      },
    },
    warnings: { type: Type.ARRAY, items: { type: Type.STRING } },
    rawText: { type: Type.STRING, nullable: true },
  },
  required: ['events'],
};

/// Gemini 비전 호출. responseSchema 로 출력 형식 강제. 파싱 실패 시 1회 재시도.
export async function callGemini(
  apiKey: string,
  imageBytes: Buffer,
  mimeType: string,
  retry = true
): Promise<OcrCallResult> {
  const ai = new GoogleGenAI({ apiKey });
  const base64 = imageBytes.toString('base64');

  const tryOnce = async (extra = ''): Promise<string> => {
    const res = await ai.models.generateContent({
      model: GEMINI_MODEL,
      contents: [
        {
          role: 'user',
          parts: [
            {
              text:
                'Extract events from this handwritten diary photo. ' +
                'Respond with JSON matching the schema. ' +
                'Aggressively use the "count" field to compress repeated tally events.',
            },
            { inlineData: { mimeType, data: base64 } },
          ],
        },
      ],
      config: {
        systemInstruction: SYSTEM_PROMPT + extra,
        responseMimeType: 'application/json',
        responseSchema: RESPONSE_SCHEMA,
        temperature: 0,
      },
    });
    return stripJsonFence(res.text ?? '');
  };

  try {
    const text = await tryOnce();
    JSON.parse(text);
    return { text };
  } catch (e) {
    if (!retry) throw e;
    const text = await tryOnce(
      '\n\nIMPORTANT: Your previous response was not valid JSON. ' +
        'Respond with ONLY a valid JSON object matching the schema.'
    );
    JSON.parse(text);
    return { text };
  }
}

// Gemini 가 responseMimeType 을 무시하고 ```json 펜스로 감싸는 드문 케이스 방어.
function stripJsonFence(text: string): string {
  const trimmed = text.trim();
  if (trimmed.startsWith('```')) {
    return trimmed
      .replace(/^```(?:json)?\s*/i, '')
      .replace(/```\s*$/i, '')
      .trim();
  }
  return trimmed;
}
