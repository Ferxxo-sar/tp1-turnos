import { Controller } from "@hotwired/stimulus"

// Formulario de reserva: carga los horarios libres desde la API y arma el resumen.
export default class extends Controller {
  static targets = [ "service", "stylist", "date", "slots", "stylistName", "when", "duration", "serviceList", "total" ]
  static values = { availabilityUrl: String }

  connect() {
    this.updateSummary()
  }

  async loadSlots() {
    const stylistId = this.stylistTarget.value
    const date = this.dateTarget.value
    this.updateSummary()

    if (!stylistId || !date) {
      this.slotsTarget.innerHTML = this.#empty("Elegí un profesional y una fecha para ver los horarios libres.")
      return
    }

    this.slotsTarget.innerHTML = this.#empty("Buscando horarios…")
    const url = `${this.availabilityUrlValue.replace(":id", stylistId)}?date=${encodeURIComponent(date)}`

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(response.statusText)
      const { slots } = await response.json()
      this.#renderSlots(slots)
    } catch {
      this.slotsTarget.innerHTML = this.#empty("No pudimos cargar los horarios. Intentá de nuevo.")
    }
  }

  updateSummary() {
    const selected = this.serviceTargets.filter((input) => input.checked)
    const total = selected.reduce((sum, input) => sum + Number(input.dataset.price), 0)
    const minutes = selected.reduce((sum, input) => sum + Number(input.dataset.minutes), 0)

    this.totalTarget.textContent = this.#money(total)
    this.durationTarget.textContent = minutes ? this.#duration(minutes) : "—"
    this.serviceListTarget.innerHTML = selected
      .map((input) => `<li><span>${this.#escape(input.dataset.name)}</span><span class="price">${this.#money(Number(input.dataset.price))}</span></li>`)
      .join("")

    const option = this.stylistTarget.selectedOptions[0]
    this.stylistNameTarget.textContent = this.stylistTarget.value ? option.textContent : "—"

    const time = this.element.querySelector("input[name='appointment[time]']:checked")?.value
    this.whenTarget.textContent = this.#when(this.dateTarget.value, time)
  }

  #renderSlots(slots) {
    if (slots.length === 0) {
      this.slotsTarget.innerHTML = this.#empty("No hay horarios disponibles para ese día.")
      return
    }

    const items = slots.map((slot) => `
      <label class="slot">
        <input type="radio" name="appointment[time]" value="${slot}" required data-action="booking#updateSummary">
        <span>${slot}</span>
      </label>`).join("")
    this.slotsTarget.innerHTML = `<div class="slots">${items}</div>`
  }

  #when(date, time) {
    if (!date) return "—"
    const [ y, m, d ] = date.split("-").map(Number)
    const label = new Date(y, m - 1, d).toLocaleDateString("es-AR", { weekday: "short", day: "numeric", month: "short" })
    return time ? `${label}, ${time} hs` : label
  }

  #duration(minutes) {
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    if (!h) return `${m} min`
    return m ? `${h} h ${m} min` : `${h} h`
  }

  #money(amount) {
    return amount.toLocaleString("es-AR", { style: "currency", currency: "ARS" })
  }

  #empty(message) {
    return `<div class="empty-slots">${message}</div>`
  }

  #escape(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
