require "./crometheus/*"

module Crometheus
  def self.valid_labels?(label_set : Hash(Symbol, String))
    label_set.each_key do |key|
      return false if [:job, :instance].includes?(key)
      ss = key.to_s
      puts ss
      return false if ss !~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
      return false if ss.starts_with?("__")
    end
    return true
  end
end
