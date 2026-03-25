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
end
