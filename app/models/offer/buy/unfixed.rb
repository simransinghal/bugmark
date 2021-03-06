require 'ext/hash'

class Offer::Buy::Unfixed < Offer::Buy

  before_validation :default_values

  def side()     "unfixed" end
  def cmd_type() :offer_bu end
  alias_method :xtag, :side

  def qualified_counteroffers(cross_type = :expand)
    return Offer.none unless self.is_open?
    base = match.open.overlaps(self)
    case cross_type
      when :expand   then base.is_buy_fixed.align_complement(self)
      when :transfer then base.is_sell_unfixed.align_lte(self)
      else Offer.none
    end
  end
  alias_method :counters, :qualified_counteroffers

  # ----- for building counteroffers
  #
  # counter = OfferCmd::CreateBuy.new(offer.counter_type, offer.counter_args(current_user))
  # cross   = ContractCmd::Cross.new(counter, offer.cross_operation)

  def counter_type()    :offer_bf  end
  def cross_operation() :expand    end
  def counter_args(user = self.user)
    args = {
      user:             user                   ,
      maturation_range: self.maturation_range  ,
      price:            1.0 - self.price
    }
    self.match_attrs.merge(args).without_blanks
  end

  private

  def default_values
    self.type              ||= 'Bid::GitHub'
    self.stm_status        ||= 'closed'
    self.price             ||= 0.10
    self.maturation_range  ||= BugmTime.now+1.minute..BugmTime.now+1.week
  end
end

# == Schema Information
#
# Table name: offers
#
#  id                    :integer          not null, primary key
#  uuid                  :string
#  exid                  :string
#  type                  :string
#  repo_type             :string
#  user_uuid             :string
#  prototype_uuid        :string
#  amendment_uuid        :string
#  salable_position_uuid :string
#  volume                :integer
#  price                 :float
#  value                 :float
#  poolable              :boolean          default(FALSE)
#  aon                   :boolean          default(FALSE)
#  status                :string
#  expiration            :datetime
#  maturation_range      :tsrange
#  xfields               :hstore           not null
#  jfields               :jsonb            not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  stm_issue_uuid        :string
#  stm_repo_uuid         :string
#  stm_title             :string
#  stm_status            :string
#  stm_labels            :string
#  stm_xfields           :hstore           not null
#  stm_jfields           :jsonb            not null
#
