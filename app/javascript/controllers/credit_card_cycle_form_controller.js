import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="credit-card-cycle-form"
export default class extends Controller {
  static targets = [
    "statementModeSelect",
    "statementFixedFields",
    "statementNthWeekdayFields",
    "statementCustomRangeFields",
    "paymentModeSelect",
    "paymentFixedFields",
    "paymentNthWeekdayFields"
  ]

  connect() {
    this.toggle()
  }

  toggle() {
    this.#toggleStatementFields()
    this.#togglePaymentFields()
  }

  #toggleStatementFields() {
    const mode = this.statementModeSelectTarget.value

    this.#setVisible(this.statementFixedFieldsTarget, mode === "fixed_day")
    this.#setVisible(this.statementNthWeekdayFieldsTarget, mode === "nth_weekday")
    this.#setVisible(this.statementCustomRangeFieldsTarget, mode === "custom_range")
  }

  #togglePaymentFields() {
    const mode = this.paymentModeSelectTarget.value

    this.#setVisible(this.paymentFixedFieldsTarget, mode === "fixed_day")
    this.#setVisible(this.paymentNthWeekdayFieldsTarget, mode === "nth_weekday")
  }

  #setVisible(element, visible) {
    element.classList.toggle("hidden", !visible)
  }
}
