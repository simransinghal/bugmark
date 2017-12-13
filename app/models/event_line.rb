require 'json'

class EventLine < ApplicationRecord

  before_validation :default_values

  validates :klas, presence: true

  jsonb_accessor   :jfields , :etherscan_url => :string

  class << self
    def for_user(user)
      user_id = user.to_i
      where("? = any(user_ids)", user_id)
    end
  end

  private

  def default_values
    prev = EventLine.last
    self.data        ||= {}
    self.uuref       ||= SecureRandom.uuid
    self.local_hash    = Digest::MD5.hexdigest([self.uuref, data].to_json)
    self.chain_hash    = Digest::MD5.hexdigest([prev&.chain_hash, self.local_hash].to_json)
    self.etherscan_url = "https://rinkeby.etherscan.io/tx/0xa48b56dedb63a0bef8572925411fc8a8c053d2d7#eventlog"
  end
end

# == Schema Information
#
# Table name: event_lines
#
#  id         :integer          not null, primary key
#  klas       :string
#  uuref      :string
#  local_hash :string
#  chain_hash :string
#  data       :jsonb            not null
#  jfields    :jsonb            not null
#  user_ids   :integer          default([]), is an Array
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
