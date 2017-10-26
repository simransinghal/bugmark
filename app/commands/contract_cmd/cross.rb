# integration_test:  commands/contract_cmd/cross/expand
# integration_test:  commands/contract_cmd/cross/transfer
# integration_test:  commands/contract_cmd/cross/reduce

require 'ext/array'

module ContractCmd
  class Cross < ApplicationCommand

    attr_subobjects :offer
    attr_reader     :counters, :type, :bundle, :commit

    validate :cross_integrity

    def initialize(offer, commit_type)
      @type        = commit_type
      @offer       = Offer.find(offer.to_i)
      @counters    = @offer.qualified_counteroffers(commit_type)
    end

    def transact_before_project
      @bundle = Bundle.new(type, offer, counters).generate
      @commit = Commit.new(bundle).generate
    end

    private

    def cross_integrity
      if offer.nil?
        errors.add :base, "no offer found"
        return false
      end

      unless %i(expand transfer reduce).include?(type)
        errors.add :base, "invalid commit type (#{type})"
        return false
      end

      if counters.nil? || counters.blank?
        errors.add :base, "no qualified counteroffers found"
        return false
      end

      # ----- compatible volumes -----

      if offer.aon? && offer.volume > counters.pluck(:volume).sum
        errors.add :base, "Err1: not enough counteroffer volume (AON)"
        return false
      end

      counter_pool = counters.where(aon: false).pluck(:volume).sum
      counter_aon  = counters.where(aon: true).pluck(:volume)
      allsums      = counter_aon.allsums

      if offer.aon? && ! allsums.include?(([0, offer.volume - counter_pool].max))
        errors.add :base, "Err2: no volume match"
        return false
      end

      # if allsums == [0]
      #   binding.pry
      #   errors.add :base, "Err3: counteroffer volume sums to zero"
      #   return false
      # end

      # if counter_pool == 0 && allsums[1..-1].min > offer.volume
      #   errors.add :base, "Err4: no volume match (counteroffer AON)"
      #   return false
      # end
    end
  end
end
