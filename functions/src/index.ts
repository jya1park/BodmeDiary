// Firebase Cloud Functions entry — 모든 함수를 여기서 export.
//
// 리전: asia-northeast3 (서울)
// 함수 목록:
//   - createInvite (callable)        가족 초대코드 생성
//   - redeemInvite (callable)        초대코드로 가족 합류
//   - parseHandwrittenLog (callable) OpenAI Vision (gpt-4o-mini) 으로 손글씨 일지 분석
//   - pruneExpiredInvites (schedule) 만료 코드 정리 (일 1회)
//   - onOcrEventDeleted (firestore)  OCR 이벤트 삭제 시 Storage 정리

export { createInvite } from './invites/createInvite';
export { redeemInvite } from './invites/redeemInvite';
export { parseHandwrittenLog } from './ocr/parseHandwrittenLog';
export { pruneExpiredInvites } from './maintenance/pruneExpiredInvites';
export { onOcrEventDeleted } from './triggers/onOcrEventDeleted';
