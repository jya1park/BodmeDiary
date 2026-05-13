import OpenAI from 'openai';

import { OPENAI_MODEL } from '../config';
import { SYSTEM_PROMPT } from './prompt';

export interface OcrCallResult {
  text: string;
}

/// OpenAI 비전 호출. JSON 모드로 강제. 파싱 실패 시 1회 재시도.
export async function callOpenAi(
  apiKey: string,
  imageBytes: Buffer,
  mimeType: string,
  retry = true
): Promise<OcrCallResult> {
  const client = new OpenAI({ apiKey });
  const dataUrl = `data:${mimeType};base64,${imageBytes.toString('base64')}`;

  const tryOnce = async (extra = ''): Promise<string> => {
    const res = await client.chat.completions.create({
      model: OPENAI_MODEL,
      response_format: { type: 'json_object' },
      temperature: 0,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT + extra },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Extract events from this handwritten diary photo. Respond with JSON only.',
            },
            { type: 'image_url', image_url: { url: dataUrl, detail: 'high' } },
          ],
        },
      ],
    });
    return res.choices[0]?.message?.content ?? '';
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
