class League < ApplicationRecord
  has_many :competitions

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }

  def refresh_from_api
    client = Bb3Api::Client.new
    data = client.league(id: api_id)
    update!(
      name: data['league']['name'],
      slug: data['league']['name'].parameterize,
      api_id: data['league']['id'] || api_id,
      api_data: data
    )
  rescue Bb3Api::NotFoundError
    errors.add(:base, "League not found on API")
    false
  rescue Bb3Api::Error => e
    errors.add(:base, e.message)
    false
  end
end
