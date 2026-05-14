import { GoogleGenAI } from '@google/genai';

import { GEMINI_MODEL } from '../config';
import { SYSTEM_PROMPT } from './prompt';

export interface OcrCallResult {
  text: string;
}

/// Gemini 비전 호출. JSON 모드로 강제. 파싱 실패 시 1회 재시도.
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
                'Extract events from this handwritten diary photo. Respond with JSON only.',
            },
            { inlineData: { mimeType, data: base64 } },
          ],
        },
      ],
      config: {
        systemInstruction: SYSTEM_PROMPT + extra,
        responseMimeType: 'application/json',
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
