import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Effort } from '../types'
import { classify } from './classify'

const pinned = atom({ plugin: 'effort-router', key: 'pinned' } as const, null)
const current = atom({ plugin: 'effort-router', key: 'current' } as const, null)

const EFFORTS: readonly Effort[] = ['low', 'medium', 'high']
const isEffort = (word: string): word is Effort =>
  (EFFORTS as readonly string[]).includes(word)

// The status line script reads the turn's choice from here, by session id.
const CHOICE_DIR = '/tmp/claude-effort-router'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'route',
      description: 'Pin reasoning effort (low, medium, high), or "auto" to route by prompt',
    })

    return next(e)
  })

  on('command.run', { command: 'route' }, async ($, e) => {
    const word = e.args.trim().toLowerCase()

    if (word === '') {
      const pin = await read($, pinned)
      return { text: pin ? `Effort pinned at ${pin}.` : 'Effort routed by prompt.' }
    }
    if (word === 'auto') {
      await update($, pinned, () => null)
      return { text: 'Effort routed by prompt again.' }
    }
    if (isEffort(word)) {
      await update($, pinned, () => word)
      return { text: `Effort pinned at ${word} until /route auto.` }
    }

    return { text: `Unknown "${word}". Use low, medium, high or auto.` }
  })

  // Decide once per prompt, so every step of the turn runs at the same effort.
  on('prompt.submit', async ($, e, next) => {
    if (e.command || e.isMeta) {
      return next(e)
    }

    const pin = await read($, pinned)
    const choice = pin ? { effort: pin, reason: 'pinned' } : classify(e.text)
    await update($, current, () => choice)
    await $.fs.write(`${CHOICE_DIR}/${await $.session.id()}`, choice.effort)

    return next(e)
  }).catch(($, e, next) => next(e))

  // Main loop only: a subagent keeps the effort its definition asks for, and a
  // model that takes no effort (e.effort absent) is left alone.
  on('turn.step', async function* ($, e, next) {
    const choice = e.agentId === undefined && e.effort !== undefined
      ? await read($, current)
      : null

    return yield* next(choice ? { ...e, effort: choice.effort } : e)
  })
}
