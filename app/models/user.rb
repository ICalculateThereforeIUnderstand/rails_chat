#require 'bcrypt'

class User < ApplicationRecord
    validates :name, presence: true, length: { maximum: 80 }, uniqueness: {case_sensitive: false}
    VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    validates :email, presence: true, length: { maximum: 255 }, format: { with: VALID_EMAIL_REGEX }, uniqueness: {case_sensitive: false} 

    #include BCrypt

    #def password
    #  @password ||= Password.new(password_hash)
    #end

    #def password=(new_password)
    #  @password = Password.create(new_password)
    # self.password_hash = @password
    #end 
end