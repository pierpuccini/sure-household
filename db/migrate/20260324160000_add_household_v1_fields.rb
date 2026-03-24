class AddHouseholdV1Fields < ActiveRecord::Migration[7.2]
  def change
    change_table :credit_cards, bulk: true do |t|
      t.string :statement_cutoff_mode, null: false, default: "fixed_day"
      t.integer :statement_cutoff_day
      t.integer :statement_cutoff_week_of_month
      t.integer :statement_cutoff_weekday
      t.integer :statement_custom_start_day
      t.integer :statement_custom_end_day
      t.boolean :statement_includes_cutoff_day, null: false, default: false

      t.string :payment_due_mode, null: false, default: "fixed_day"
      t.integer :payment_due_day
      t.integer :payment_due_week_of_month
      t.integer :payment_due_weekday
    end

    add_column :transactions, :owner, :string, null: false, default: "shared"
    add_index :transactions, :owner
  end
end
