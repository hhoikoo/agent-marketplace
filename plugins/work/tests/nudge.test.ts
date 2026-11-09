import { describe, expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

type World = { role?: string; threshold?: string; percent: number; submitted: string[] }

const world = (on: On, w: World) => {
  on('env.get', ($, e) => ({
    value: e.name === 'ORCH_ROLE' ? w.role : e.name === 'ORCH_HANDOVER_PERCENT' ? w.threshold : undefined,
  }))
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
  on('session.start', ($, e) => ({ cwd: e.cwd }))
}

const START = { cwd: '/tmp', surface: 'terminal', isInteractive: true } as const
const turn = { answer: 'ok', durationMs: 1, isAborted: false, turnId: 't', reason: 'answer' } as const

describe('handover-nudge', () => {
  test('worker over threshold is nudged once', async ($, on) => {
    const w: World = { role: 'worker', percent: 50, submitted: [] }
    world(on, w)
    await $.session.start(START)
    await $.turn.complete(turn)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(1)
    expect(w.submitted[0]).toContain('/work:handover')
  })

  test('worker under threshold is not nudged', async ($, on) => {
    const w: World = { role: 'worker', percent: 30, submitted: [] }
    world(on, w)
    await $.session.start(START)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(0)
  })

  test('session without a role is never nudged', async ($, on) => {
    const w: World = { percent: 90, submitted: [] }
    world(on, w)
    await $.session.start(START)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(0)
  })

  test('ORCH_HANDOVER_PERCENT overrides the default', async ($, on) => {
    const w: World = { role: 'worker', threshold: '60', percent: 50, submitted: [] }
    world(on, w)
    await $.session.start(START)
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(0)
  })

  test('running /work:orchestrate makes the session a master', async ($, on) => {
    const w: World = { percent: 50, submitted: [] }
    world(on, w)
    on('skill.prompt', ($, e) => ({ text: e.text }))
    await $.session.start(START)
    await $.skill.prompt({ skill: 'work:orchestrate', text: '' })
    await $.turn.complete(turn)
    expect(w.submitted.length).toBe(1)
    expect(w.submitted[0]).toContain('master handover')
  })

  test('subagent turns are ignored', async ($, on) => {
    const w: World = { role: 'worker', percent: 90, submitted: [] }
    world(on, w)
    await $.session.start(START)
    await $.turn.complete({ ...turn, agentId: 'a1' })
    expect(w.submitted.length).toBe(0)
  })
})
