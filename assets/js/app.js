import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/pgpeek"
import topbar from "../vendor/topbar"
import Chart from "../vendor/chart.min.js"

// Chart.js hook for LiveView
const ChartHook = {
  mounted() {
    const config = JSON.parse(this.el.dataset.chart)
    const ctx = this.el.getContext("2d")

    // Apply dark theme defaults
    Chart.defaults.color = "rgb(148, 163, 184)" // slate-400
    Chart.defaults.borderColor = "rgba(255, 255, 255, 0.06)"
    Chart.defaults.font.family = "'Inter', system-ui, sans-serif"
    Chart.defaults.font.size = 11

    this.chart = new Chart(ctx, config)

    this.handleEvent("chart-data", ({config: newConfig}) => {
      this.chart.destroy()
      this.chart = new Chart(ctx, newConfig)
    })
  },

  updated() {
    const config = JSON.parse(this.el.dataset.chart)
    this.chart.destroy()
    const ctx = this.el.getContext("2d")
    this.chart = new Chart(ctx, config)
  },

  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ChartHook},
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()

    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
