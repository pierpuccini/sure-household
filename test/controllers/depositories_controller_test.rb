require "test_helper"

class DepositoriesControllerTest < ActionDispatch::IntegrationTest
  include AccountableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "updates account currency" do
    patch depository_path(@account), params: {
      account: {
        name: @account.name,
        currency: "EUR",
        balance: @account.balance.to_s
      }
    }

    assert_redirected_to account_path(@account)
    assert_equal "EUR", @account.reload.currency
  end
end
