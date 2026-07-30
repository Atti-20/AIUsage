import Foundation

enum DisplayPreferenceKeys {
    static let showClaudeUsage = "display.showClaudeUsage"
    static let showCodexUsage = "display.showCodexUsage"
    static let showOfficialLimitWarnings = "display.showOfficialLimitWarnings"
    static let showCodexResetPrediction = "display.showCodexResetPrediction"
}

extension DailyStat {
    func visibleCost(showClaude: Bool, showCodex: Bool) -> Double {
        (showClaude ? claude.costUSD : 0) + (showCodex ? codex.costUSD : 0)
    }
}

extension UsageSnapshot {
    func visibleProjects(showClaude: Bool, showCodex: Bool) -> [ProjectStat] {
        projects
            .filter {
                isSourceVisible(
                    $0.source,
                    showClaude: showClaude,
                    showCodex: showCodex
                )
            }
            .sorted {
                if $0.tally.costUSD != $1.tally.costUSD {
                    return $0.tally.costUSD > $1.tally.costUSD
                }
                return $0.tally.totalTokens > $1.tally.totalTokens
            }
    }

    func visibleMonthCost(showClaude: Bool, showCodex: Bool) -> Double {
        let prefix = String(Self.todayKey.prefix(7))
        return days
            .filter { $0.day.hasPrefix(prefix) }
            .reduce(0) { $0 + $1.visibleCost(showClaude: showClaude, showCodex: showCodex) }
    }

    func visibleTotalCost(showClaude: Bool, showCodex: Bool) -> Double {
        days.reduce(0) {
            $0 + $1.visibleCost(showClaude: showClaude, showCodex: showCodex)
        }
    }

    func isSourceVisible(_ source: UsageSource, showClaude: Bool, showCodex: Bool) -> Bool {
        source == .claude ? showClaude : showCodex
    }
}
