import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

// The hook only says when to hand over; /work:handover --auto decides how, by role.
const DEFAULT_PERCENT = 45
// After a nudge that did not lead to a handover, nudge again once context grows this much more.
const RENUDGE_STEP = 10

const lastNudge = atom({ plugin: 'work', key: 'lastNudgePercent' } as const, null as number | null)

const nudgeText = (percent: number) =>
  `Context is at ${percent}%. Hand this session over now: run /work:handover --auto.`

export const register: Register = on => {
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined) {
      return result
    }

    const setting = (await $.env.get('HANDOVER_PERCENT'))?.trim()
    if (setting === 'off') {
      return result
    }
    const configured = Number(setting)
    const threshold = configured > 0 ? configured : DEFAULT_PERCENT

    const percent = (await $.session.usage()).context.percent ?? 0
    const previous = await read($, lastNudge)
    const due = previous === null ? threshold : previous + RENUDGE_STEP
    if (percent < due) {
      return result
    }

    await update($, lastNudge, () => percent)
    // Not awaited: the prompt runs as the next turn. A failed submit re-arms the nudge.
    $.prompt.submit({ text: nudgeText(Math.round(percent)) }).catch(() => update($, lastNudge, () => previous))

    return result
  })
}
