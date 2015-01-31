require_relative 'ooob/bot'

module Ooob
  def self.start
    Ooob::Bot.listen
  end
end

