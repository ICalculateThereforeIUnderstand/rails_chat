class Token < ApplicationRecord
  validates :token, presence: true, uniqueness: {case_sensitive: true} 
  validates :refresh_token, presence: true, uniqueness: {case_sensitive: true} 
end