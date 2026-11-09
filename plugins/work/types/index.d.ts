export type Role = 'master' | 'worker'

declare module 'claude-code' {
  interface PluginState {
    'work': { role: Role | null; hasNudged: boolean }
  }
}
