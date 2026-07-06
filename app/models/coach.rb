class Coach < ApplicationRecord
  has_many :teams, dependent: :nullify
end
