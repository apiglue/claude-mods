import type { Choice } from '../types'

const HEAVY =
  /\b(refactor|migrat|implement|build|design|architect|debug|diagnos|investigat|fix|rewrite|review|optimi[sz]|plan)\w*/i
const QUESTION =
  /^(what|where|who|when|why|how|is|are|does|do|can|explain|show|list|look at)\b/i
const LONG = 800
const SHORT = 200

// Words over cleverness: a wrong guess costs one turn, and /route overrides it.
export const classify = (text: string): Choice => {
  const prompt = text.trim()
  const heavy = HEAVY.exec(prompt)

  if (heavy) {
    return { effort: 'high', reason: `"${heavy[0].toLowerCase()}"` }
  }
  if (prompt.length > LONG) {
    return { effort: 'high', reason: 'long prompt' }
  }
  if (prompt.length < SHORT && (prompt.endsWith('?') || QUESTION.test(prompt))) {
    return { effort: 'low', reason: 'question' }
  }

  return { effort: 'medium', reason: 'default' }
}
