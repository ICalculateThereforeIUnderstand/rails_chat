module ApiHelper 
  def provjeri_token() 
      if !params.has_key?(:token)
        return {"value"=>{}, "error"=> true, "errorCode"=>"Ovo je zasticena stranica, a vi niste osigurali token"}
      end
      if params[:token] == ""
        return {"value"=>{}, "error"=> true, "errorCode"=>"Vas token je prazan string"}
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

      #return true
      return token[:user_id]
  end

  def procisti_bazu()
    # ovu funkciju pozivamo svakih n minuta prilikom refresh requesta
    # ona neaktivne usere brise iz soba, zatim tim sobama postavlja
    # timestamp na kolonu zadnja_promjena, i brise sve tokene koji su
    # revoked ili istekli. 
    # pretrazivanje tokena po vremenu isteka je vrlo efikasno zbog indexa,
    # pa ne moras birsati u u3 liniji tokene koji su istekli ili koji su revoked. to je opcionalno

    u1 = Kanali.connection.select_all("UPDATE kanalis SET zadnja_promjena = UTC_TIMESTAMP() WHERE id IN (SELECT id_sobe FROM vezes WHERE id_korisnika NOT IN (SELECT user_id FROM tokens WHERE revoked_at IS NULL AND unix_timestamp(UTC_TIMESTAMP()) < tokens.expires_at GROUP BY user_id) GROUP BY id_sobe)")
    u2 = Veze.connection.select_all("DELETE FROM vezes WHERE id_korisnika NOT IN (SELECT user_id FROM tokens WHERE revoked_at IS NULL AND unix_timestamp(UTC_TIMESTAMP()) < tokens.expires_at GROUP BY user_id)")
    
    #u3 = Token.connection.select_all("DELETE FROM tokens WHERE revoked_at IS NOT NULL OR unix_timestamp(UTC_TIMESTAMP()) - unix_timestamp(tokens.created_at) > expires_in");
    
    # ova tri querija ne moraju biti u transakciji. ako jedan ili vise njih
    # se ne provede, nema nikakve stete ni nekonzistentnosti baze.
    # treci brise neaktivne tokene, a prva dva querija ovise o aktivnim.
    # ukoliko prvi ne prode, uklonjeni useri ce ostati na listama korisnika
    # do sljedeceg input nove poruke. kada pokrenemo sljedeci put procisti_bazu,
    # sve ce biti ponisteno sto treba i postavljeno na ispravno novo stanje. 
  end

end

class ApiController < ApplicationController
  @@timer = 0;
  @@rokTrajanja = 60 * 15

  def pocetak
    return render json: {"value"=>{}, "error"=> false, "errorCode"=>"ovo je root stranica"}
  end

  def zasticena 
    userID = helpers.provjeri_token()
    #if (var != true)
    if (userID.class == Hash)
      render json: userID
    else
      # authentikacija je prosla 
      return render json: {"value"=>{"vrijeme": userID}, "error"=> false, "errorCode"=>"no error"}

    end
  end

  def provjeriToken
    userID = helpers.provjeri_token()
    
    if (userID.class == Hash)
      render json: userID
    else
      tim = Time.now.utc
      return render json: {"offset": Time.now.utc_offset, "value"=>{"vrijeme1":Time.now.utc.to_i, "vrijeme2":Time.now.to_i, "vrijeme3":Time.now.getutc.to_i}, "error"=> false, "errorCode"=>"no error"}
    end
  end

  def stanjeSobe
    userID = helpers.provjeri_token()
    #if (var != true)
    if (userID.class == Hash)
      render json: userID
    else
      # authentikacija je prosla 

      #@@timer += 1
      time = Time.now.utc.to_i
      time1 = time - @@timer
      if (time1 > 0 && true)
        @@timer = time + 300
        helpers.procisti_bazu()
      end
      
      #uvjet = Adrese.sanitize_sql_for_conditions(["?",s])
      #adrese = Adrese.connection.select_all("SELECT veze1.kodknjige FROM adrese INNER JOIN veze1 ON veze1.kodadrese = adrese.id WHERE adrese.adresa = " + uvjet)

      #@odabrani1 = params[:skladiste]
      #@uvjet5 = Skladista.sanitize_sql_for_conditions([" AND skladista.skladiste = ?",@odabrani1]);
      #strQuery = " INNER JOIN veze1 ON veze1.kodknjige = knjiges.id INNER JOIN adrese ON veze1.kodadrese = adrese.id INNER JOIN skladista ON skladista.id = adrese.kodskladista"
      #@adrese = Skladista.connection.select_all("SELECT adrese.adresa FROM adrese INNER JOIN skladista ON skladista.id = adrese.kodskladista WHERE TRUE" + @uvjet5);
      if (params[:akcija] == "refresh")
        time = Kanali.find(params["sobaID"])[:zadnja_promjena].to_i
        if (params[:timeStamp] > time)
          return render json: {"value"=>{"users": [], "poruke":[], "timeStamp": time, "updateSw": false}, "error"=> false, "errorCode"=>"no error"}
        else 
          sobaID = User.sanitize_sql_for_conditions(["?",params["sobaID"]])
          userIDs = User.sanitize_sql_for_conditions(["?",userID])
       
          users = User.connection.select_all("SELECT users.id as id, name, spol, godine, slogan, id_slike FROM users INNER JOIN vezes ON users.id = id_korisnika WHERE id_sobe = " + sobaID + " AND id_sobe IN (SELECT id_sobe FROM vezes WHERE id_korisnika = " + userIDs + ") ORDER BY name")
  
          #poruke = User.connection.select_all("SELECT porukes.id, poruka, id_materijala, id_korisnika, porukes.created_at, name, spol, users.id as userID, id_slike FROM porukes INNER JOIN users ON users.id = id_korisnika WHERE porukes.id > " + porukaID + " AND id_sobe = " + sobaID);
          if (params["zadnjaPoruka"] > 0)
            porukaID = User.sanitize_sql_for_conditions(["?",params["zadnjaPoruka"]])
            poruke = User.connection.select_all("SELECT porukes.id, poruka, id_materijala, porukes.id_korisnika, porukes.created_at, name, spol, users.id as userID, id_slike FROM porukes INNER JOIN users ON users.id = id_korisnika WHERE porukes.id > " + porukaID + " AND porukes.id_sobe = " + sobaID + " AND porukes.id_sobe IN (SELECT vezes.id_sobe FROM vezes WHERE vezes.id_korisnika = " + userIDs + ")");
          else 
            porukaID = (-1*params["zadnjaPoruka"]).to_s
            poruke = User.connection.select_all("(SELECT porukes.id, poruka, id_materijala, porukes.id_korisnika, porukes.created_at, name, spol, users.id as userID, id_slike FROM porukes INNER JOIN users ON users.id = id_korisnika WHERE porukes.id_sobe = " + sobaID + " AND porukes.id_sobe IN (SELECT vezes.id_sobe FROM vezes WHERE vezes.id_korisnika = " + userIDs + ") ORDER BY porukes.id DESC LIMIT " + porukaID + ") ORDER BY id");
          end
          #timeDifference = params[:trenutnoVrijeme].to_i - Time.now.utc.hour
          return render json: {"value"=>{"porukaID":porukaID, "users": users, "poruke":poruke, "timeStamp": time, "updateSw": true}, "error"=> false, "errorCode"=>"no error"}
        end
      elsif (params[:akcija] === "dodajPoruku")
        poruka = Poruke.new
        poruka[:id_sobe] = params[:sobaID]
        poruka[:poruka] = params[:poruka]
        poruka[:id_korisnika] = userID 
        if poruka.save 
          time = poruka[:created_at]
          kan = Kanali.find(params[:sobaID])
          protekloVrijeme = time.to_i - kan[:zadnja_promjena].to_i
          if (protekloVrijeme >= 0)
            kan[:zadnja_promjena] = time
            kan.save 
          end  
          sobaID = User.sanitize_sql_for_conditions(["?",params["sobaID"]])
          userIDs = User.sanitize_sql_for_conditions(["?",userID])
          users = User.connection.select_all("SELECT users.id as id, name, spol, godine, slogan, id_slike FROM users INNER JOIN vezes ON users.id = id_korisnika WHERE id_sobe = " + sobaID + " AND id_sobe IN (SELECT id_sobe FROM vezes WHERE id_korisnika = " + userIDs + ") ORDER BY name")
      
          porukaID = User.sanitize_sql_for_conditions(["?",params["zadnjaPoruka"]])
          poruke = User.connection.select_all("SELECT porukes.id, poruka, id_materijala, id_korisnika, porukes.created_at, name, spol, users.id as userID, id_slike FROM porukes INNER JOIN users ON users.id = id_korisnika WHERE porukes.id > " + porukaID + " AND id_sobe = " + sobaID);
          #timeDifference = params[:trenutnoVrijeme].to_i - Time.now.utc.hour
          return render json: {"value"=>{"users": users, "poruke":poruke, "timeStamp": time.to_i, "updateSw": true}, "error"=> false, "errorCode"=>"no error"}
        else 
          return render json: {"value"=>{}, "error"=> true, "errorCode"=>"primanje poruke nije uspijelo"}
        end
      end

    end
  end

  def predvorje 
    sleep(1)
    rez = Kanali.connection.select_all("SELECT ime, kanalis.id as sobaID, COUNT(id_korisnika) as count FROM kanalis LEFT OUTER JOIN vezes ON id_sobe = kanalis.id GROUP BY ime, sobaID ORDER BY count DESC");
    return render json: {"value"=>{"sobe": rez}, "error"=> false, "errorCode"=>"no error"}
  end

  def updateUser
    sleep(4)
    userID = helpers.provjeri_token()
    #if (var != true)
    if (userID.class == Hash)
      render json: userID
    else
      user = User.find(userID)
      if (params.has_key?(:spol))
        user[:spol] = params[:spol]
      end
      if (params.has_key?(:godine))
        user[:godine] = params[:godine]
      end
      if (params.has_key?(:slogan))
        user[:slogan] = params[:slogan]
      end

      if (user.save)
        return render json: {"value"=>{}, "error"=> false, "errorCode"=>"no error"}
      else 
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"snimanje u bazu podataka nije uspijelo"}
      end   
    end
  end

  def roomEnterExit 
    # ovaj kontroler nas ukljucuje / iskljucuje iz sobe
    userID = helpers.provjeri_token()
    #if (var != true)
    if (userID.class == Hash)
      render json: userID
    else
      if (params[:akcija] === "enter")
        veza = Veze.find_by(id_korisnika:userID, id_sobe:params[:sobaID])
        if (veza.nil?)
          veza = Veze.new
          veza[:id_korisnika] = userID 
          veza[:id_sobe] = params[:sobaID]
          if (veza.save)
            time = veza[:created_at]
            kan = Kanali.find(params[:sobaID])
            if (!kan.nil?)
              protekloVrijeme = time.to_i - kan[:zadnja_promjena].to_i
              if (protekloVrijeme >= 0)
                kan[:zadnja_promjena] = time
                if (kan.save)
                  return render json: {"value"=>{}, "error"=> false, "errorCode"=>"no error"}    
                end
              end  
            end
            veza.delete
            return render json: {"value"=>{}, "error"=> true, "errorCode"=>"snimanje nije uspijelo1. Korisnik nije u sobi."}
          else 
            return render json: {"value"=>{}, "error"=> true, "errorCode"=>"snimanje nije uspijelo. Korisnik nije u sobi."}
          end
        else
          return render json: {"value"=>{}, "error"=> true, "errorCode"=>"korisnik je vec u sobi"}
        end
      elsif (params[:akcija] === "exit") # izlazimo iz sobe
        veza = Veze.find_by(id_korisnika:userID, id_sobe:params[:sobaID])
        if (veza.nil?)
          return render json: {"value"=>{"userID":userID, "soba":params[:sobaID]}, "error"=> true, "errorCode"=>"Korisnik nije pronaden u sobi"}
        else 
          kan = Kanali.find_by(id:params[:sobaID])
          time = Time.now.utc
          protekloVrijeme = time.to_i - kan[:zadnja_promjena].to_i
          if (protekloVrijeme >= 0)
            kan[:zadnja_promjena] = time
            kan.save
          end
          veza.delete
          return render json: {"value"=>{}, "error"=> false, "errorCode"=>"no error"}
        end
      elsif (params[:akcija] === "exitAll")
        userIDs = Veze.sanitize_sql_for_conditions(["?",userID])
        rez = Veze.connection.select_all("DELETE FROM vezes WHERE id_korisnika = " + userIDs);
        return render json: {"value"=>{}, "error"=> false, "errorCode"=>"no error"}
      else 
        return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Invalidna akcija."}        
      end
    end
  end

  def slika
    id = Skladiste.sanitize_sql_like(params[:id])
    # ovdje provjeravamo da li je user cija je slika requestana u javnoj sobi
    a = Skladiste.connection.select_all("SELECT id_slike FROM users INNER JOIN vezes ON id_korisnika = users.id INNER JOIN kanalis ON id_sobe = kanalis.id WHERE kanalis.tip = 'javni' AND id_slike IS NOT NULL")
    b = a.map do |el|
      el["id_slike"]
    end
    if (!b.include? id.to_i)
      return render json: {"value"=>{"polje":b, "id_request":id}, "error"=> true, "errorCode"=>"User nije u javnoj sobi pa slika nije javna"}  
    end

    #var = Knjige.connection.select_all("SELECT slika, hash_kod FROM knjiges WHERE id = " + id);    

    var = Skladiste.find_by_id(id)
    if (var.nil?)
      return render json: {"value"=>{}, "error"=> true, "errorCode"=>"file nije pronaden u bazi podataka."}      
    end
    #render json: var
    file = Base64.decode64(var[:file])
    tip = var[:tip]

    send_data(file, :filename => "slika."+tip, :type=>"image/"+tip)

  end

  def updateUser1
    sleep(1)
    userID = helpers.provjeri_token()
    #if (var != true)
    if (userID.class == Hash)
      render json: userID
    else
      if (params[:akcija] === "ucitaj")
        user = User.find(userID)
        fileTip = nil
        file = nil

        if (!user[:id_slike].nil?)
          skl = Skladiste.find(user[:id_slike])
          if (!skl.nil?)
            fileTip = skl[:tip]
            file = skl[:file]
          end
        end

        return render json: {"value"=>{"name": user[:name], "email": user[:email], 
        "spol": user[:spol], "godine": user[:godine], "slogan": user[:slogan],
        "fileTip": fileTip, "file": file}, "error"=> false, "errorCode"=>"no error"}
      else
        user = User.find(userID)
        if (params.has_key?(:email))
          user[:email] = params[:email]
        end
        if (params.has_key?(:spol))
          user[:spol] = params[:spol]
        end
        if (params.has_key?(:godine))
          user[:godine] = params[:godine]
        end
        if (params.has_key?(:slogan))
          user[:slogan] = params[:slogan]
        end

        # pazi morat ces u postmanu dodati ove parametre file, fileTip, filePromjenjenSw
        if (params[:filePromjenjenSw])
          if (user[:id_slike].nil?)
            skl = Skladiste.new 
            skl[:ime] = userID 
            skl[:file] = params[:file]
            skl[:tip] = params[:fileTip]
            if (skl.save)
              user[:id_slike] = skl[:id]
              if user.save
                return render json: {"value"=>{"message":"updejtan je podatak i slika"}, "error"=> false, "errorCode"=>"no error"}
              else 
                skl.delete
              end
            end
            return render json: {"value"=>{}, "error"=> true, "errorCode"=>"snimanje slike u bazu podataka nije uspijelo"}
          else 
            if (params[:file].nil?)
              skl = Skladiste.find(user[:id_slike])
              skl.delete
              user[:id_slike] = nil
              if (user.save) 
                return render json: {"value"=>{"message":"updejtan je podatak i slika je obrisana"}, "error"=> false, "errorCode"=>"no error"}
              else 
                return render json: {"value"=>{}, "error"=> true, "errorCode"=>"brisanje slike u bazi podataka nije uspijelo"}
              end
            else 
              skl = Skladiste.find(user[:id_slike])
              skl[:ime] = userID 
              skl[:file] = params[:file]
              skl[:tip] = params[:fileTip]
              if (skl.save)
                return render json: {"value"=>{"message":"updejtan je podatak i slika je zamjenjena"}, "error"=> false, "errorCode"=>"no error"}
              else 
                return render json: {"value"=>{}, "error"=> true, "errorCode"=>"updejt slike u bazi podataka nije uspio"}
              end
            end
          end
        else
          if (user.save)
            return render json: {"value"=>{"message":"updejtan je podatak"}, "error"=> false, "errorCode"=>"no error"}
          else 
            return render json: {"value"=>{}, "error"=> true, "errorCode"=>"snimanje u bazu podataka nije uspijelo"}
          end
        end
      end  
    end
  end

  def refreshToken 
    #rokTrajanja = 7200
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
                expires_in: @@rokTrajanja, expires_at: Time.now.utc.to_i + @@rokTrajanja - Time.now.utc_offset)
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
    #rokTrajanja = 60 * 15
    sleep(2)

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
          return render json: {"value"=>{}, "error"=> true, "errorCode"=>"Username i password kombinacija nije ispravna"}
        end
    end

    token = SecureRandom.alphanumeric(40);
    refreshToken = SecureRandom.alphanumeric(40);
    id = user[:id]
    tok = Token.new(user_id:id, token:token, refresh_token:refreshToken, 
          expires_in: @@rokTrajanja, expires_at: Time.now.utc.to_i + @@rokTrajanja - Time.now.utc_offset)
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

      #ovaj dio je specificni dodatak za nase ponistenje korisnika u sobama
      # nema veze sa authentication 
      expires = token[:expires_in]
      protekloVrijeme = Time.now.to_i - token[:created_at].to_i
      if (protekloVrijeme <= expires)
        # brisemo korisnika iz soba u kojima je prijavljen
        userIDs = Kanali.sanitize_sql_for_conditions(["?",token[:user_id]])
        rez = Kanali.connection.select_all("UPDATE kanalis INNER JOIN vezes ON kanalis.id = id_sobe SET zadnja_promjena = UTC_TIMESTAMP() WHERE id_korisnika = " + userIDs);
        Veze.where(id_korisnika:token[:user_id]).delete_all
      end
      # kraj dodatka
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
    #rokTrajanja = 60 * 15

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
            expires_in: @@rokTrajanja, expires_at: Time.now.utc.to_i + @@rokTrajanja - Time.now.utc_offset)
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