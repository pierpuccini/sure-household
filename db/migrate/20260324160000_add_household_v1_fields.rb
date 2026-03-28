class AddHouseholdV1Fields < ActiveRecord::Migration[7.2]
  def up
    add_column :credit_cards, :statement_cutoff_mode, :string, null: false, default: "fixed_day" unless column_exists?(:credit_cards, :statement_cutoff_mode)
    add_column :credit_cards, :statement_cutoff_day, :integer unless column_exists?(:credit_cards, :statement_cutoff_day)
    add_column :credit_cards, :statement_cutoff_week_of_month, :integer unless column_exists?(:credit_cards, :statement_cutoff_week_of_month)
    add_column :credit_cards, :statement_cutoff_weekday, :integer unless column_exists?(:credit_cards, :statement_cutoff_weekday)
    add_column :credit_cards, :statement_custom_start_day, :integer unless column_exists?(:credit_cards, :statement_custom_start_day)
    add_column :credit_cards, :statement_custom_end_day, :integer unless column_exists?(:credit_cards, :statement_custom_end_day)
    add_column :credit_cards, :statement_includes_cutoff_day, :boolean, null: false, default: false unless column_exists?(:credit_cards, :statement_includes_cutoff_day)

    add_column :credit_cards, :payment_due_mode, :string, null: false, default: "fixed_day" unless column_exists?(:credit_cards, :payment_due_mode)
    add_column :credit_cards, :payment_due_day, :integer unless column_exists?(:credit_cards, :payment_due_day)
    add_column :credit_cards, :payment_due_week_of_month, :integer unless column_exists?(:credit_cards, :payment_due_week_of_month)
    add_column :credit_cards, :payment_due_weekday, :integer unless column_exists?(:credit_cards, :payment_due_weekday)

    add_column :transactions, :owner, :string, null: false, default: "shared" unless column_exists?(:transactions, :owner)
    add_index :transactions, :owner unless index_exists?(:transactions, :owner)
  end

  def down
    remove_index :transactions, :owner if index_exists?(:transactions, :owner)
    remove_column :transactions, :owner if column_exists?(:transactions, :owner)

    remove_column :credit_cards, :payment_due_weekday if column_exists?(:credit_cards, :payment_due_weekday)
    remove_column :credit_cards, :payment_due_week_of_month if column_exists?(:credit_cards, :payment_due_week_of_month)
    remove_column :credit_cards, :payment_due_day if column_exists?(:credit_cards, :payment_due_day)
    remove_column :credit_cards, :payment_due_mode if column_exists?(:credit_cards, :payment_due_mode)

    remove_column :credit_cards, :statement_includes_cutoff_day if column_exists?(:credit_cards, :statement_includes_cutoff_day)
    remove_column :credit_cards, :statement_custom_end_day if column_exists?(:credit_cards, :statement_custom_end_day)
    remove_column :credit_cards, :statement_custom_start_day if column_exists?(:credit_cards, :statement_custom_start_day)
    remove_column :credit_cards, :statement_cutoff_weekday if column_exists?(:credit_cards, :statement_cutoff_weekday)
    remove_column :credit_cards, :statement_cutoff_week_of_month if column_exists?(:credit_cards, :statement_cutoff_week_of_month)
    remove_column :credit_cards, :statement_cutoff_day if column_exists?(:credit_cards, :statement_cutoff_day)
    remove_column :credit_cards, :statement_cutoff_mode if column_exists?(:credit_cards, :statement_cutoff_mode)
  end
end
