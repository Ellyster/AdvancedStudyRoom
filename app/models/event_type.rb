# == Schema Information
#
# Table name: event_types
#
#  id          :integer          not null, primary key
#  name        :string(100)
#  description :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class EventType < ActiveRecord::Base
  attr_accessible :description, :name

  validates :name, presence: true
end