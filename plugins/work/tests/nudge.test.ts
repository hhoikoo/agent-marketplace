import { describe, expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

type World = { threshold?: string; percent: number; submitted: string[] }

const world = (on: On, w: World) => {
  on('env.get', ($, e) => ({ value: e.name === 'HANDOVER_PERCENT' ? w.threshold : undefined }))
  on('session.usage', () => ({
    value: {
      startedAt: 0,
      context: { tokens: w.percent * 10_000, window: 1_000_000, percent: w.percent },
      rateLimits: [],
    },
  }))
  on('prompt.submit', ($, e) => {
    w.submitted.push(e.text)
    return { text: e.text }
  })
  on('turn.complete', ($, e) => ({ text: e.answer }))
}

const turn = { answer: 'ok', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' } as const

describe('handover-nudge', () => {
  test('any session over the threshold is nudged once', async ($, on) => {
    const w: World = { percent: 50, submitted: [] }
    world(on, w)
    await $.turn.complete(turn)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(1)
    expect(w.submitted[0]).toContain('/work:handover --auto')
  })

  test('under the threshold is not nudged', async ($, on) => {
    const w: World = { percent: 30, submitted: [] }
    world(on, w)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(0)
  })

  test('HANDOVER_PERCENT overrides the default', async ($, on) => {
    const w: World = { threshold: '60', percent: 50, submitted: [] }
    world(on, w)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(0)
  })

  test('HANDOVER_PERCENT=off disables the nudge', async ($, on) => {
    const w: World = { threshold: 'off', percent: 95, submitted: [] }
    world(on, w)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(0)
  })

  test('an ignored nudge repeats after 10 more points', async ($, on) => {
    const w: World = { percent: 50, submitted: [] }
    world(on, w)
    await $.turn.complete(turn)
    w.percent = 59
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(1)
    w.percent = 60
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(2)
  })

  test('subagent turns are ignored', async ($, on) => {
    const w: World = { percent: 90, submitted: [] }
    world(on, w)
    await $.turn.complete({ ...turn, agentId: 'a1' })
    expect(w.submitted.length).toBe(0)
  })
})
