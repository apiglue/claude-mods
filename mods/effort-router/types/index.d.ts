export type Effort = 'low' | 'medium' | 'high'

export type Choice = { effort: Effort; reason: string }

declare module 'claude-code' {
  interface PluginState {
    'effort-router': { pinned: Effort | null; current: Choice | null }
  }
}
