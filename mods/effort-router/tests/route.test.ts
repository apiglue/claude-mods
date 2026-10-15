import type { On } from 'claude-code'
import { describe, expect, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import { classify } from '../hooks/classify'

describe('classify', () => {
  test('a short question is low', async () => {
    expect(classify('what is a "turn"?').effort).toBe('low')
    expect(classify('look at issue #110. what\'s left?').effort).toBe('low')
  })

  test('work words are high, even phrased as a question', async () => {
    expect(classify('can you refactor the gateway config?').effort).toBe('high')
    expect(classify('go ahead and build the first version').effort).toBe('high')
  })

  test('a long prompt is high', async () => {
    expect(classify('x '.repeat(500)).effort).toBe('high')
  })

  test('anything else is medium', async () => {
    expect(classify('merge it').effort).toBe('medium')
  })
})

// Stands in for the engine beneath the plugin: records each step's effort.
const engine = (on: On) => {
  const seen = { efforts: [] as unknown[] }
  on('turn.step', async function* (_, e) {
    seen.efforts.push(e.effort)
    return {
      turnId: e.turnId,
      index: e.index,
      answer: '',
      toolUses: [],
      stopReason: 'end_turn' as const,
      usage: null,
    }
  })
  on('prompt.submit', (_, e) => ({ text: e.text }))
  return seen
}

const submit = ($: Engine, text: string) =>
  $.prompt.submit({ text, wait: false, origin: { kind: 'composer' } })

const route = ($: Engine, args: string) =>
  $.command.run({
    command: 'route',
    args,
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })

const step = async ($: Engine, agentId?: string) => {
  const stream = $.turn.step({
    turnId: 't1',
    index: 0,
    model: 'claude-opus-5-5',
    effort: 'max',
    messageCount: 1,
    ...(agentId ? { agentId } : {}),
  })
  for await (const _ of stream) {
  }
  return stream.result
}

describe('routing', () => {
  test('the main loop runs at the effort the prompt chose', async ($, on) => {
    const seen = engine(on)

    await submit($, 'what is a turn?')
    await step($)
    await step($, 'agent-1')

    expect(seen.efforts).toEqual(['low', 'max'])
  })

  test('/route pins the effort until /route auto', async ($, on) => {
    const seen = engine(on)

    await route($, 'high')
    await submit($, 'what is a turn?')
    await step($)

    await route($, 'auto')
    await submit($, 'what is a turn?')
    await step($)

    expect(seen.efforts).toEqual(['high', 'low'])
  })
})
