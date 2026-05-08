import { GoogleGenerativeAI } from '@google/generative-ai';

import { SYSTEM_PROMPT } from './prompt';

export interface GeminiResult {
  text: string;
}

export async function callGemini(
  apiKey: string,
  imageBytes: Buffer,
  mimeType: string,
  retry = true
): Promise<GeminiResult> {
  const ai = new GoogleGenerativeAI(apiKey);
  const model = ai.getGenerativeModel({
    model: 'gemini-1.5-pro',
    generationConfig: { responseMimeType: 'application/json' },
  });

  const tryOnce = async (extraPrompt = ''): Promise<string> => {
    const result = await model.generateContent([
      { text: SYSTEM_PROMPT + extraPrompt },
      {
        inlineData: {
          data: imageBytes.toString('base64'),
          mimeType,
        },
      },
    ]);
    return result.response.text();
  };

  try {
    const text = await tryOnce();
    JSON.parse(text); // 파싱 가능 검증
    return { text };
  } catch (e) {
    if (!retry) throw e;
    const text = await tryOnce(
      '\n\nIMPORTANT: Your previous response was not valid JSON. ' +
        'Respond with ONLY a valid JSON object, no markdown.'
    );
    JSON.parse(text);
    return { text };
  }
}
