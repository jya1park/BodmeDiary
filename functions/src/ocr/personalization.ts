import { db } from '../lib/firestore';

/// 사용자가 review 화면에서 저장한 이벤트 패턴 — 다음 호출의 few-shot 으로 재사용.
/// users/{uid} 문서의 ocrLearnings 필드에 누적 (Flutter 측에서 write, 함수가 read).
export interface OcrPattern {
  sourceText: string;
  type: 'feeding' | 'diaper' | 'sleep';
  method?: 'breast' | 'formula' | null;
  kind?: 'pee' | 'poop' | 'both' | null;
  amountMl?: number | null;
  note?: string | null;
  /// 같은 (sourceText + type + 서브필드) 가 확정된 횟수.
  confirmedCount: number;
  /// ISO 문자열 또는 epoch ms.
  lastSeenMs: number;
}

interface OcrLearnings {
  patterns?: OcrPattern[];
}

/// 사용자 문서를 읽어 가장 신뢰도 높은 패턴 상위 N개를 한국어 프롬프트 조각으로 변환.
/// 패턴이 없으면 빈 문자열을 돌려준다 (시스템 지침에 영향 없음).
export async function buildPersonalHints(uid: string): Promise<string> {
  let learnings: OcrLearnings | undefined;
  try {
    const snap = await db.doc(`users/${uid}`).get();
    learnings = snap.data()?.ocrLearnings as OcrLearnings | undefined;
  } catch {
    return '';
  }
  const patterns = learnings?.patterns;
  if (!patterns || patterns.length === 0) return '';

  // confirmedCount 내림차순으로 상위 10개만.
  const top = [...patterns]
    .sort((a, b) => (b.confirmedCount ?? 0) - (a.confirmedCount ?? 0))
    .slice(0, 10);

  const lines = top.map((p) => formatLine(p)).filter((s) => s.length > 0);
  if (lines.length === 0) return '';

  return `\n\n# 이 사용자의 일지 패턴 (이전 분석에서 사용자가 저장 확정한 항목)\n${lines.join('\n')}\n\n동일한 sourceText 가 또 나오면 위 매핑을 우선 적용하세요. 다른 셀에서도 같은 패턴이 보이면 그쪽도 동일하게.`;
}

function formatLine(p: OcrPattern): string {
  if (!p.sourceText) return '';
  const parts: string[] = [`"${p.sourceText}"`];
  if (p.type === 'feeding') {
    const method = p.method ?? 'breast';
    parts.push(`→ feeding (method=${method}`);
    if (p.amountMl != null) parts.push(`amountMl=${p.amountMl}`);
    if (p.note) parts.push(`note="${p.note}"`);
    parts[parts.length - 1] += ')';
  } else if (p.type === 'diaper') {
    parts.push(`→ diaper (kind=${p.kind ?? 'null'}`);
    if (p.note) parts.push(`note="${p.note}"`);
    parts[parts.length - 1] += ')';
  } else {
    parts.push('→ sleep');
  }
  parts.push(`[${p.confirmedCount}회 확정]`);
  return `- ${parts.join(' ')}`;
}
