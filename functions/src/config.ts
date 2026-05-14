import { defineSecret } from 'firebase-functions/params';

export const REGION = 'asia-northeast3';
export const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
export const GEMINI_MODEL = 'gemini-3-pro-image-preview';

export const INVITE_TTL_MS = 24 * 60 * 60 * 1000;
export const OCR_DAILY_QUOTA = 20;
