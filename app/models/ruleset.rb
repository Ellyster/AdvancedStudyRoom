# == Schema Information
#
# Table name: rulesets
#
#  id                     :integer          not null, primary key
#  name                   :string(255)
#  overtime_required      :boolean
#  handicap_required      :boolean
#  j_ot_allowed           :boolean
#  c_ot_allowed           :boolean
#  main_time_min          :float
#  main_time_max          :float
#  j_ot_min_period_length :float
#  j_ot_max_period_length :float
#  c_ot_min_time          :float
#  c_ot_max_time          :float
#  points_per_win         :float
#  points_per_loss        :float
#  min_komi               :float
#  max_komi               :float
#  j_ot_max_periods       :integer
#  j_ot_min_periods       :integer
#  c_ot_min_stones        :integer
#  c_ot_max_stones        :integer
#  min_handicap           :integer
#  max_handicap           :integer
#  min_board_size         :integer
#  max_board_size         :integer
#  node_limit             :integer
#  matches_per_opponent   :integer
#  rulesetable_id         :integer
#  rulesetable_type       :string(255)
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#

class Ruleset < ActiveRecord::Base
  attr_protected

  belongs_to :rulesetable, polymorphic: true

  has_many :permissions, :class_name => 'Permission', :as => :parent

  RULES = [:allowed_rengo,
         :allowed_teaching,
         :allowed_review,
         :allowed_free,
         :allowed_rated,
         :allowed_simul,
         :allowed_demonstration,
         :allowed_no_time_settings]

  def rules
    non_rules = [:id, :updated_at, :created_at, :name, :rulesetable_id, :rulesetable_type]
    attributes.symbolize_keys.reject { |k,v| non_rules.include?(k) }
  end

  # TODO: add validation that prevents ruleset from being saved if
  # both jovertime and covertimer and false
  # and overtime stones/period settings or control settings are enabled

  # this hunky chunk of code checks the list of RULES above
  # and if a missing method matches one of those rules
  # either as method= or method?, it provides the appropriate logic

  def method_missing sym, *args
    mthd = sym.to_s[0..-2].to_sym
    name = sym.to_s

    super unless RULES.include?(mthd)

    if name =~ /\?$/
      !permissions.find_by_perm(mthd).nil?
    elsif name =~ /=$/
      raise TypeError, "Must be a boolean value." unless args[0] == true or args[0] == false

      if args[0] == true
        permissions.find_by_perm(mthd) || permissions.create(:perm => mthd, :parent_id => id)
      else
        permissions.find_by_perm(mthd).destroy unless permissions.find_by_perm(mthd).nil?
      end
    end

  end



end
