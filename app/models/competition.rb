class Competition < ApplicationRecord
  belongs_to :league

  enum :platform, { pc: 0, playstation: 1, xbox: 2 }
  enum :format, { round_robin: 0, single_elimination: 1, ladder: 2, swiss: 3 }
end
