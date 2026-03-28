class AddOwnerFieldsToImports < ActiveRecord::Migration[7.2]
  def up
    add_column :imports, :owner_col_label, :string unless column_exists?(:imports, :owner_col_label)
    add_column :import_rows, :owner, :string unless column_exists?(:import_rows, :owner)
  end

  def down
    remove_column :import_rows, :owner if column_exists?(:import_rows, :owner)
    remove_column :imports, :owner_col_label if column_exists?(:imports, :owner_col_label)
  end
end
