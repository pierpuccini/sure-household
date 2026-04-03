import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "yearLabel", "monthButton", "panel", "toggle", "dateFields"];
  static values = {
    year: Number,
    selectedMonth: String,
  };

  connect() {
    this.render();
  }

  previousYear() {
    this.yearValue -= 1;
    this.render();
  }

  nextYear() {
    this.yearValue += 1;
    this.render();
  }

  selectMonth(event) {
    const month = String(event.currentTarget.dataset.month).padStart(2, "0");
    this.selectedMonthValue = `${this.yearValue}-${month}`;
    this.inputTarget.value = this.selectedMonthValue;
    this.render();
  }

  toggle() {
    this.render();
  }

  render() {
    const statementModeEnabled = this.toggleTarget.checked;

    this.yearLabelTarget.textContent = this.yearValue;
    this.panelTarget.classList.toggle("hidden", !statementModeEnabled);
    this.dateFieldsTarget.classList.toggle("hidden", statementModeEnabled);

    this.monthButtonTargets.forEach((button) => {
      const month = String(button.dataset.month).padStart(2, "0");
      const isSelected = this.selectedMonthValue === `${this.yearValue}-${month}`;
      button.dataset.selected = String(isSelected);
      button.setAttribute("aria-pressed", isSelected);
      button.classList.toggle("bg-surface", isSelected);
      button.classList.toggle("text-primary", isSelected);
      button.classList.toggle("border-secondary", isSelected);
      button.classList.toggle("shadow-border-xs", isSelected);
      button.classList.toggle("bg-transparent", !isSelected);
      button.classList.toggle("text-secondary", !isSelected);
      button.classList.toggle("border-transparent", !isSelected);
    });
  }
}
