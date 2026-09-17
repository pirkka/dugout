import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["data", "slider", "playoff", "position", "prob", "utility", "rowSum", "winpct"]

  EXACT_MAX_FIXTURES = 12
  MC_CHUNK = 5000
  MC_MAX = 50000
  CONVERGENCE_EPSILON = 0.001
  AI_TD_MARGIN = 2

  connect() {
    const payload = JSON.parse(this.dataTarget.textContent)
    this.teams = payload.teams
    this.fixtures = payload.fixtures
    this.cutoff = parseInt(this.element.dataset.predictorCutoff, 10) || null
    this.values = []
    for (const slider of this.sliderTargets) {
      this.values[parseInt(slider.dataset.index, 10)] = 1 - parseFloat(slider.value)
    }
    this.touched = new Set()
    for (const slider of this.sliderTargets) {
      this.updateSliderFill(slider)
      slider.addEventListener("input", (event) => {
        const index = parseInt(event.currentTarget.dataset.index, 10)
        this.values[index] = 1 - parseFloat(event.currentTarget.value)
        this.touched.add(index)
        this.updateSliderFill(event.currentTarget)
        this.scheduleRecompute()
      })
    }
    this.recompute()
  }

  updateSliderFill(slider) {
    slider.style.setProperty("--fill", `${parseFloat(slider.value) * 100}%`)
  }

  scheduleRecompute() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.recompute(), 50)
  }

  initialScores() {
    return this.teams.map((t) => ({ points: t.points, wins: t.wins, tdsMade: t.tdsMade, tdsSustained: t.tdsSustained }))
  }

  probs(index) {
    const v = this.values[index]
    if (v <= 0) return [0, 0, 1]
    if (v >= 1) return [1, 0, 0]
    if (v === 0.5 && this.touched.has(index)) return [0, 1, 0]
    const t = Math.abs(2 * v - 1)
    const d = 0.33 * Math.exp(-2.0 * t * t)
    return [v * (1 - d), d, (1 - v) * (1 - d)]
  }

  better(a, b) {
    if (a.points !== b.points) return a.points > b.points
    if (a.wins !== b.wins) return a.wins > b.wins
    if (a.tdsMade !== b.tdsMade) return a.tdsMade > b.tdsMade
    return (a.tdsMade - a.tdsSustained) > (b.tdsMade - b.tdsSustained)
  }

  positionsOf(scores) {
    const positions = new Array(scores.length).fill(1)
    for (let i = 0; i < scores.length; i++) {
      for (let j = 0; j < scores.length; j++) {
        if (i !== j && this.better(scores[j], scores[i])) positions[i]++
      }
    }
    return positions
  }

  recompute() {
    if (this.fixtures.length === 0) {
      this.renderBlank()
      return
    }
    const entries = this.fixtures.map((fixture, index) => ({
      fixture,
      probs: this.probs(index),
      human: fixture.ai ? (fixture.home === null ? fixture.away : fixture.home) : null,
    }))
    const stats = entries.length <= this.EXACT_MAX_FIXTURES
      ? this.solveExact(entries)
      : this.solveMonteCarlo(entries)
    this.render(stats)
  }

  renderBlank() {
    for (const el of this.playoffTargets) el.textContent = "—"
    for (const el of this.positionTargets) el.textContent = "—"
    for (const el of this.probTargets) el.textContent = "—"
    for (const el of this.utilityTargets) el.textContent = "—"
    for (const el of this.rowSumTargets) el.textContent = "—"
    for (const el of this.winpctTargets) el.textContent = ""
  }

  teamIndexFor(id) {
    return this.teams.findIndex((t) => t.id === id)
  }

  render(stats) {
    const total = stats.total
    for (const el of this.playoffTargets) {
      const idx = this.teamIndexFor(parseInt(el.dataset.team, 10))
      const count = idx >= 0 ? stats.playoff[idx] : 0
      el.textContent = total > 0 ? `${((count / total) * 100).toFixed(1)}%` : "—"
    }
    for (const el of this.positionTargets) {
      const idx = this.teamIndexFor(parseInt(el.dataset.team, 10))
      const pos = parseInt(el.dataset.position, 10)
      const count = idx >= 0 ? stats.positions[idx][pos - 1] : 0
      el.textContent = total > 0 ? `${((count / total) * 100).toFixed(1)}%` : "—"
    }
    for (const el of this.rowSumTargets) {
      const idx = this.teamIndexFor(parseInt(el.dataset.team, 10))
      if (idx >= 0) {
        const sum = stats.positions[idx].reduce((a, b) => a + b, 0)
        el.textContent = total > 0 ? `${((sum / total) * 100).toFixed(1)}%` : "—"
      }
    }
    for (const el of this.utilityTargets) {
      const col = el.dataset.col
      if (col === "playoff") {
        const sum = stats.playoff.reduce((a, b) => a + b, 0)
        el.textContent = total > 0 ? `${((sum / total) * 100).toFixed(1)}%` : "—"
      } else if (col.startsWith("pos-")) {
        const pos = parseInt(col.split("-")[1], 10)
        const sum = stats.positions.reduce((a, row) => a + row[pos - 1], 0)
        el.textContent = total > 0 ? `${((sum / total) * 100).toFixed(1)}%` : "—"
      }
    }
    for (let i = 0; i < this.sliderTargets.length; i++) {
      const el = this.probTargets.find((el) => parseInt(el.dataset.index, 10) === i)
      if (!el) continue
      const p = this.probs(i)
      el.textContent = `${Math.round(p[1] * 100)}% draw`
      for (const wp of this.winpctTargets.filter((wp) => parseInt(wp.dataset.index, 10) === i)) {
        const share = wp.dataset.side === "home" ? p[0] : p[2]
        wp.textContent = `${Math.round(share * 100)}% win`
      }
    }
  }

  solveExact(entries) {
    const size = this.teams.length
    const scores = this.initialScores()
    const playoff = new Array(size).fill(0)
    const positions = Array.from({ length: size }, () => new Array(size).fill(0))
    let total = 0

    const dfs = (i, prob) => {
      if (prob === 0) return
      if (i === entries.length) {
        total += prob
        const ranks = this.positionsOf(scores)
        for (let t = 0; t < size; t++) {
          positions[t][ranks[t] - 1] += prob
          if (this.cutoff && ranks[t] <= this.cutoff) playoff[t] += prob
        }
        return
      }
      const { fixture, probs, human } = entries[i]
      const [ph, pd, pa] = probs
      if (human !== null) {
        const winProb = fixture.home === null ? pa : ph
        const lossProb = fixture.home === null ? ph : pa
        if (winProb > 0) {
          scores[human].points += 3
          scores[human].wins += 1
          scores[human].tdsMade += this.AI_TD_MARGIN
          dfs(i + 1, prob * winProb)
          scores[human].points -= 3
          scores[human].wins -= 1
          scores[human].tdsMade -= this.AI_TD_MARGIN
        }
        if (pd > 0) {
          scores[human].points += 1
          scores[human].tdsMade += 1
          scores[human].tdsSustained += 1
          dfs(i + 1, prob * pd)
          scores[human].points -= 1
          scores[human].tdsMade -= 1
          scores[human].tdsSustained -= 1
        }
        if (lossProb > 0) dfs(i + 1, prob * lossProb)
        return
      }
      if (ph > 0) {
        scores[fixture.home].points += 3
        scores[fixture.home].wins += 1
        scores[fixture.home].tdsMade += 1
        scores[fixture.away].tdsSustained += 1
        dfs(i + 1, prob * ph)
        scores[fixture.home].points -= 3
        scores[fixture.home].wins -= 1
        scores[fixture.home].tdsMade -= 1
        scores[fixture.away].tdsSustained -= 1
      }
      if (pd > 0) {
        scores[fixture.home].points += 1
        scores[fixture.home].tdsMade += 1
        scores[fixture.home].tdsSustained += 1
        scores[fixture.away].points += 1
        scores[fixture.away].tdsMade += 1
        scores[fixture.away].tdsSustained += 1
        dfs(i + 1, prob * pd)
        scores[fixture.home].points -= 1
        scores[fixture.home].tdsMade -= 1
        scores[fixture.home].tdsSustained -= 1
        scores[fixture.away].points -= 1
        scores[fixture.away].tdsMade -= 1
        scores[fixture.away].tdsSustained -= 1
      }
      if (pa > 0) {
        scores[fixture.away].points += 3
        scores[fixture.away].wins += 1
        scores[fixture.away].tdsMade += 1
        scores[fixture.home].tdsSustained += 1
        dfs(i + 1, prob * pa)
        scores[fixture.away].points -= 3
        scores[fixture.away].wins -= 1
        scores[fixture.away].tdsMade -= 1
        scores[fixture.home].tdsSustained -= 1
      }
    }

    dfs(0, 1)
    return { playoff, positions, total }
  }

  solveMonteCarlo(entries) {
    const size = this.teams.length
    const playoff = new Array(size).fill(0)
    const positions = Array.from({ length: size }, () => new Array(size).fill(0))
    const base = this.initialScores()
    const scores = base.map((s) => ({ ...s }))
    let total = 0
    let previous = null

    for (let run = 0; run < this.MC_MAX; run += this.MC_CHUNK) {
      for (let n = 0; n < this.MC_CHUNK; n++) {
        for (let t = 0; t < size; t++) {
          scores[t].points = base[t].points
          scores[t].wins = base[t].wins
          scores[t].tdsMade = base[t].tdsMade
          scores[t].tdsSustained = base[t].tdsSustained
        }
        for (let i = 0; i < entries.length; i++) {
          const { fixture, probs, human } = entries[i]
          const [ph, pd, pa] = probs
          const r = Math.random()
          if (human !== null) {
            const winProb = fixture.home === null ? pa : ph
            if (r < winProb) {
              scores[human].points += 3
              scores[human].wins += 1
              scores[human].tdsMade += this.AI_TD_MARGIN
            } else if (r < winProb + pd) {
              scores[human].points += 1
              scores[human].tdsMade += 1
              scores[human].tdsSustained += 1
            }
            continue
          }
          if (r < ph) {
            scores[fixture.home].points += 3
            scores[fixture.home].wins += 1
            scores[fixture.home].tdsMade += 1
            scores[fixture.away].tdsSustained += 1
          } else if (r < ph + pd) {
            scores[fixture.home].points += 1
            scores[fixture.home].tdsMade += 1
            scores[fixture.home].tdsSustained += 1
            scores[fixture.away].points += 1
            scores[fixture.away].tdsMade += 1
            scores[fixture.away].tdsSustained += 1
          } else {
            scores[fixture.away].points += 3
            scores[fixture.away].wins += 1
            scores[fixture.away].tdsMade += 1
            scores[fixture.home].tdsSustained += 1
          }
        }
        const ranks = this.positionsOf(scores)
        for (let t = 0; t < size; t++) {
          positions[t][ranks[t] - 1]++
          if (this.cutoff && ranks[t] <= this.cutoff) playoff[t]++
        }
        total++
      }
      if (previous && this.converged(previous, playoff, positions, total)) break
      previous = {
        playoff: playoff.slice(),
        positions: positions.map((p) => p.slice()),
        total,
      }
    }

    return { playoff, positions, total }
  }

  converged(previous, playoff, positions, total) {
    const size = this.teams.length
    for (let t = 0; t < size; t++) {
      const playoffDelta = Math.abs(playoff[t] / total - previous.playoff[t] / previous.total)
      if (playoffDelta > this.CONVERGENCE_EPSILON) return false
      for (let p = 0; p < size; p++) {
        const delta = Math.abs(positions[t][p] / total - previous.positions[t][p] / previous.total)
        if (delta > this.CONVERGENCE_EPSILON) return false
      }
    }
    return true
  }
}
