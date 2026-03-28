require "test_helper"

class Import::AccountMappingTest < ActiveSupport::TestCase
  test "create_mappable! uses selected account type for newly created accounts" do
    import = imports(:transaction)
    mapping = Import::AccountMapping.create!(
      import: import,
      key: "Imported Credit Card",
      create_when_empty: true,
      value: "CreditCard"
    )

    assert_difference -> { Account.count } => 1 do
      mapping.create_mappable!
    end

    account = mapping.reload.mappable

    assert_equal "CreditCard", account.accountable_type
    assert_equal "Imported Credit Card", account.name
  end

  test "selectable_values includes mapped account even when it is not manual" do
    import = imports(:transaction)
    linked_account = accounts(:loan)
    mapping = Import::AccountMapping.new(
      import: import,
      key: "Imported Loan",
      mappable: linked_account
    )

    assert_includes mapping.selectable_values, [ linked_account.name, linked_account.id ]
  end
end
