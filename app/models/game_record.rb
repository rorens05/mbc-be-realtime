class GameRecord < ApplicationRecord
  validates :game_id, presence: true, uniqueness: true
  validates :number_of_winners, presence: true
  validates :start_time, presence: true
  enum status: ["Ongoing", "Ended"]

  def self.lobby_time
    10
  end

  def remaining_time
    (start_time.to_time - DateTime.now.to_time)
  end
end