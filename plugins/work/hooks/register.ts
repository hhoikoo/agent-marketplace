import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Role } from '../types'

const DEFAULT_PERCENT = 45

const role = atom({ plugin: 'work', key: 'role' } as const, null as Role | null)
const hasNudged = atom({ plugin: 'work', key: 'hasNudged' } as const, false)

const NUDGE: Record<Role, (percent: number) => string> = {
  master: percent =>
    `Context is at ${percent}%. Start the master handover now, following the orchestrate skill's "Handover → Master (this session)" steps.`,
  worker: percent =>
    `Context is at ${percent}%. Finish the current step and stop at a safe point. Then run /work:handover and send its path to your master by SendMessage.`,
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const fromEnv = await $.env.get('ORCH_ROLE')
    if (fromEnv === 'master' || fromEnv === 'worker') {
      await update($, role, () => fromEnv)
    }

    return next(e)
  })

  on('skill.prompt', async ($, e, next) => {
    if (e.skill.split(':').pop() === 'orchestrate') {
      await update($, role, () => 'master')
    }

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    const current = await read($, role)
    if (e.agentId !== undefined || current === null || (await read($, hasNudged))) {
      return result
    }

    const configured = Number(await $.env.get('ORCH_HANDOVER_PERCENT'))
    const threshold = configured > 0 ? configured : DEFAULT_PERCENT
    const { context } = await $.session.usage()
    if ((context.percent ?? 0) < threshold) {
      return result
    }

    await update($, hasNudged, () => true)
    // Not awaited: the prompt runs as the next turn. A failed submit re-arms the nudge.
    $.prompt.submit({ text: NUDGE[current](context.percent ?? threshold) }).catch(() =>
      update($, hasNudged, () => false),
    )

    return result
  })
}
