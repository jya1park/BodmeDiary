/** 6자리 숫자 코드 생성 (앞자리 0 허용). */
export function generateCode(): string {
  const n = Math.floor(Math.random() * 1_000_000);
  return n.toString().padStart(6, '0');
}
