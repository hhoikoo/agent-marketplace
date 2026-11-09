export type NudgeState = { lastNudgePercent: number | null }

declare module 'claude-code' {
  interface PluginState {
    'work': NudgeState
  }
}
