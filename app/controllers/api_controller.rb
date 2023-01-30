module ApiHelper 
  def provjeri_token() 
      if !params.has_key?(:token)
        return {"value"=>{}, "error"=> true, "errorCode"=>"Ovo je zasticena stranica, a vi niste osigurali token"}
      end
      token = Token.find_by(token:params[:token])
      if token.nil?
          return {"value"=>{}, "error"=> true, "errorCode"=>"Vas token je nevazeci"}
      end
      if !token[:revoked_at].nil?
          return {"value"=>{}, "error"=> true, "errorCode"=>"Vas token je ponisten"}
      end
      expires = token[:expires_in]
      protekloVrijeme = Time.now.to_i - token[:created_at].to_i
      if (protekloVrijeme > expires)
          return {"value"=>{}, "error"=> true, "errorCode"=>"Vas token je istekao"}
      end

      return true
  end

end

class ApiController < ApplicationController
  def pocetak
    return render json: {"value"=>{}, "error"=> false, "errorCode"=>"ovo je root stranica"}
  end

  def zasticena 
    var = helpers.provjeri_token()
    if (var != true)
      render json: var
    else
    

      # authentikacija je prosla 
      return render json: {"value"=>{"vrijeme": 123}, "error"=> false, "errorCode"=>"no error"}

    end
  end

  def refreshToken 
    rokTrajanja = 7200
    if (!params.has_key?(:refreshToken))
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Morate osigurati refresh token"}
    end
    tok = Token.find_by(refresh_token:params[:refreshToken])
    if (tok.nil?)
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Refresh token nije vazeci"}
    end
    if !tok[:revoked_at].nil?
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Ovaj token je istekao"}
    end
    expires = tok[:expires_in]
    protekloVrijeme = Time.now.to_i - tok[:created_at].to_i
    if (protekloVrijeme > expires)
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Vas token je istekao"}
    end


    tok[:revoked_at] = Time.now()
    if tok.save 
      token = SecureRandom.alphanumeric(40);
      refreshToken = SecureRandom.alphanumeric(40);
      id = tok[:user_id]
      noviTok = Token.new(user_id:id, token:token, refresh_token:refreshToken, 
                expires_in: rokTrajanja)
      if noviTok.save
        return render json: {"value"=>{"token": token, "refreshToken": refreshToken}, "error"=> false, "errorCode"=>"no error"}
      else 
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"generiranje tokena nije uspijelo"}
      end
    else 
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Snimanje u bazu podataka nije uspijelo"}
    end
  end

  def signin 
    rokTrajanja = 7200

    if (!params.has_key?(:login) ||  !params.has_key?(:password))
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Morate osigurati login i password"}
    end
    user = User.find_by(name:params[:login])
    if user.nil?
      user = User.find_by(email:params[:login])
    end
    if (user.nil?)
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Username i password kombinacija nije ispravna"}
    else 
        pp = BCrypt::Password.new(user[:password_digest])  
        if (pp == params[:password])
            #return render json: {"value"=>{"baza":user[:password_digest]}, "error"=> false, "errorCode"=>"no error"}
        else 
          return render json: {"value"=>{"baza":user[:password_digest]}, "error"=> true, "errorCode"=>"Username i password kombinacija nije ispravna"}
        end
    end

    token = SecureRandom.alphanumeric(40);
    refreshToken = SecureRandom.alphanumeric(40);
    id = user[:id]
    tok = Token.new(user_id:id, token:token, refresh_token:refreshToken, 
          expires_in: rokTrajanja)
    if tok.save
      return render json: {"value"=>{"token": token, "refreshToken": refreshToken}, "error"=> false, "errorCode"=>"no error"}
    else 
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"generiranje tokena nije uspijelo"}
    end
    
  end

  def signout 
    if !params.has_key?(:token)
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Niste zadali token"}
    end
    token = Token.find_by(token:params[:token])
    if token.nil?
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Ovaj token ne postoji u bazi."}
    end
    if token[:revoked_at].nil?
      token[:revoked_at] = Time.now()
      if token.save 
        return render json: {"value"=>{"message":"Token je ponisten."}, "error"=> false, "errorCode"=>"no error"}
      else 
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Snimanje ponistenja tokena nije uspijelo."}
      end
    else 
      return render json: {"value"=>{"message":"ovaj token je vec bio ponisten"}, "error"=> false, "errorCode"=>"no error"}
    end
  end

  def signup
    rokTrajanja = 7200

    if (!User.find_by(name:params[:username]).nil?)
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Vec postoji korisnik sa ovim imenom."}
    end

    if (!User.find_by(email:params[:email]).nil?)
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Vec postoji korisnik sa ovim emailom."}
    end

    u = User.new
    u[:name] = params[:username]
    u[:email] = params[:email]
    u[:password_digest] = BCrypt::Password.create(params[:password])

    if u.save 
      token = SecureRandom.alphanumeric(40);
      refreshToken = SecureRandom.alphanumeric(40);
      id = u[:id]
      tok = Token.new(user_id:id, token:token, refresh_token:refreshToken, 
            expires_in: rokTrajanja)
      if tok.save
        return render json: {"value"=>{"token": token, "refreshToken": refreshToken}, "error"=> false, "errorCode"=>"no error"}
      else 
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"generiranje tokena nije uspijelo"}
      end
    else 
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"snimanje nije uspijelo"}
    end
  end  

end