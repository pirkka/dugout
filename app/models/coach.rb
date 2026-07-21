class Coach < ApplicationRecord
  has_many :teams, dependent: :nullify

  def to_param
    slug
  end
end
