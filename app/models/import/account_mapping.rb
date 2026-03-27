class Import::AccountMapping < Import::Mapping
  validates :mappable, presence: true, if: :requires_mapping?
  validates :value, presence: true, if: :requires_account_type?

  class << self
    def mappables_by_key(import)
      unique_values = import.rows.map(&:account).uniq
      accounts = import.family.accounts.where(name: unique_values).index_by(&:name)

      unique_values.index_with { |value| accounts[value] }
    end
  end

  def selectable_values
    accounts = import.family.accounts.manual.alphabetically.to_a
    accounts.unshift(mappable) if mappable.present? && accounts.exclude?(mappable)

    accounts.uniq(&:id).map { |account| [ account.name, account.id ] }
  end

  def requires_selection?
    true
  end

  def values_count
    import.rows.where(account: key).count
  end

  def mappable_class
    Account
  end

  def create_mappable!
    return unless creatable?

    account = import.family.accounts.create_or_find_by!(name: key) do |new_account|
      new_account.balance = 0
      new_account.import = import
      new_account.currency = import.family.currency
      new_account.accountable = account_type.new
    end

    self.mappable = account
    save!
  end

  private
    def account_type
      Accountable.from_type(value.presence || "Depository") || Depository
    end

    def create_new_option_label
      label = "Create new account"
      return label unless create_when_empty? && value.present?

      "#{label} (#{value.underscore.humanize})"
    end

    def requires_account_type?
      creatable?
    end

    def requires_mapping?
      (key.blank? || !create_when_empty) && import.account.nil?
    end

  public
    def new_account_button_label
      create_new_option_label
    end
end
