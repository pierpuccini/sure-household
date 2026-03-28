require "test_helper"

class TransactionOwnerTest < ActiveSupport::TestCase
  test "defaults owner to shared" do
    transaction = Transaction.new

    assert_equal "shared", transaction.owner
  end

  test "accepts owner enum values" do
    transaction = Transaction.new(owner: "partner")

    assert_equal "partner", transaction.owner
    assert transaction.partner?
  end
end
