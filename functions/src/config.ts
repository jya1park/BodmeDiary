import { defineSecret } from 'firebase-functions/params';

export const REGION = 'asia-northeast3';
export const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
export const OPENAI_MODEL = 'gpt-4o-mini';

export const INVITE_TTL_MS = 24 * 60 * 60 * 1000;
export const OCR_DAILY_QUOTA = 20;
