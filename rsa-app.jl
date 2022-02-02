#!/usr/bin/env julia 
push!(LOAD_PATH, pwd())
using Crypt
using Base64
using PyCall
using SMTPClient
using Dates
using Mail
using PyCall

pushfirst!(PyVector(pyimport("sys")["path"]), "")
drive = pyimport("drive")
notiff = pyimport("notiff")


#function funcs(input, vars, settings, DEBUG) #Call function as in input
#  eval(Expr(:call, Symbol(input[1]), input[2:end], vars, settings, DEBUG))
#end
#
#function generate(args, vars, settings, DEBUG)
#  @time (public_key, private_key) = generate_key(parse(BigInt,args[1]), parse(Int, args[2])) 
#  push!(vars, "private key"=>private_key)
#  push!(vars, "public key"=>public_key)
#  println(public_key)
#  fp1 = open(settings["path"]["private key"], "w")
#  fp2 = open(settings["path"]["public key"], "w")
#  write(fp1, string(vars["private key"][1]), ", ", string(vars["private key"][2]))
#  write(fp2, string(vars["public key"][1]), ", ", string(vars["public key"][2]))
#  close(fp1)
#  close(fp2)
#  println("We have updated the private key to $(settings["path"]["private key"]) and the public key to $(settings["path"]["public key"])")
#  #drive.trash(settings["key_access"]["me"])
#  #drive.upload(settings["key_access"]["me"], [settings["path"]["public key"]])
#end

#function usekey(args, vars, DEBUG)
#  push!(vars, "reciever key"=>(parse(BigInt,args[1]), parse(BigInt,args[2])))
#end

function Encrypt(args, vars, settings, to, to_id, from, from_id, DEBUG)
  #drive.download(settings["key_access"][settings["key_access"]["default"]], [settings["path"]["public key"]])
  fp = open(settings["path"]["cipher text"], "w")
  #t = split(filter(!isempty, drive.read(settings["key_access"][settings["key_access"]["default"]], settings["path"]["public key"])), ',')
  t = split(filter(!isempty, drive.read(to_id, settings["path"]["public key"])), ',')
  rec_key = map(x->parse(BigInt, x), t)
  receiver_key = (rec_key[1], rec_key[2])
  push!(vars, "receiver key"=>receiver_key)
  @time cipher = Crypt.encrypt(args[1], vars["receiver key"], parse(Int64,args[2]))
  DEBUG && println(cipher)
  t = unpack_cipher.(cipher)
  cipher_text = join(t, ' ')
  push!(vars, "message"=>args[1])
  push!(vars, "cipher text"=>cipher_text)
  printstyled("$cipher_text\n", color = :yellow)
  write(fp, cipher_text, "\n", args[2])
  close(fp)
  println("We have updated the encrypted message to $(settings["path"]["cipher text"])")
  drive.edit(from_id, settings["path"]["cipher text"], join(readlines(settings["path"]["cipher text"]), '\n'))
  fp = open(settings["path"]["status"], "w")
  write(fp, "1")
  close(fp)
  println("Wrote to file")
  drive.edit(from_id, settings["path"]["status"], join(readlines(settings["path"]["status"]), '\n'))
  history = readlines(settings["path"]["history"])
  fp = open(settings["path"]["history"], "w")
  write(fp, "$(join(history, '\n'))\n$(from): $(vars["message"])")
  close(fp)
end

function Decrypt(args, vars, settings, to, to_id, from, from_id, DEBUG=false)
  status = drive.read(to_id, settings["path"]["status"])
  if parse(Int64, status) != 1
    while parse(Int64, status) != 1
      status = drive.read(to_id, settings["path"]["status"])
      println(status)
      sleep(1)
    end
    println(status)
  end
  input = split(drive.read(to_id, settings["path"]["cipher text"]), '\n')
  println(input,length(input))
  cipher_text = input[1]
  println("Cipher Text = $cipher_text")
  println("Block size = $(input[2])")
  #cipher_text = split(drive.read(settings["key_access"][settings["key_access"]["default"]], settings["path"]["cipher text"]), '\n')[1]
  println("Read cipher text. Read as $cipher_text")
  t = split(filter(!isempty, readlines(settings["path"]["private key"]))[1], ',')
  priv_key = map(x->parse(BigInt, x), t)
  private_key = (priv_key[1], priv_key[2])
  push!(vars, "private key"=>private_key)
  #t = split(filter(!isempty, readlines(settings["path"]["public key"]))[1], ',')
  #pub_key = map(x->parse(BigInt, x), t)
  #public_key = (pub_key[1], pub_key[2])
  #push!(vars, "public key"=>public_key)
  #input = filter(!isempty, readlines(settings["path"]["cipher text"]))
  #cipher_text = input[1]
  println("Checkpoint 1")
  DEBUG && println("Length of args: $(length(args))")
  t = filter(!isempty,split(cipher_text, ' '))
  if t[end] == "\r"
    pop!(t)
  end
  println("Things = $t")
  cipher = pack_cipher.(t)
  println("Checkpoint 3")
  DEBUG && println(cipher)
  @time message = decrypt(cipher, vars["private key"], parse(Int64, input[2]))
  println("Checkpoint 4")
  printstyled("$message\n", color = :yellow)
  push!(vars, "message"=>message)
  println("Checkpoint 5")
  #fp = open(settings["path"]["status"], "w")
  #write(fp, "0")
  #close(fp)
  #drive.edit(settings["key_access"][settings["key_access"]["default"]], settings["path"]["status"], join(readlines(settings["path"]["status"])))
  drive.edit(to_id, settings["path"]["status"], "0")
  history = readlines(settings["path"]["history"])
  fp = open(settings["path"]["history"], "w")
  write(fp, "$(join(history, '\n'))\n$(to): $(vars["message"])")
  close(fp)
  drive.edit(to_id, settings["path"]["cipher text"], "")
  notiff.notify(to, vars["message"])
end

function status(args, vars, settings, DEBUG)
  for x in vars
    printstyled("$(x[1])", color = :blue)
    print(" : ")
    printstyled("$(x[2])\n", color = :green)
  end
end

function unpack_cipher(x::BigInt, DEBUG=false)
  group = Vector{UInt8}()
  while x != 0
    y = x & 0xff
    push!(group, y)
    x = x>>8
  end
  return base64encode(reverse(group))
end

function pack_cipher(message, DEBUG=false)
  x::BigInt = 0
  a = base64decode(message)
  x = a[1]
  for i in 2:length(a)
    x = x<<8
    x = x | a[i]
  end
  return x
end

#function unpack_cipher(x::BigInt, DEBUG=false)
#  y = string(x)
#  return base64encode(y)
#end
#
#function pack_cipher(message, DEBUG=false)
#  x = base64decode(message)
#  y = map(a->Char(a), x)
#  z = foldl(*, y)
#  return parse(BigInt,z)
#end

function debug(args, vars, settings, DEBUG)
  push!(vars, "debug"=>!(vars["debug"]))
  println("debug set to $(vars["debug"]).")
end

function pushkey(args, vars, DEBUG)
  push!(vars, "private key"=>(parse(BigInt, args[1]), parse(BigInt, args[2])))
end

function exit(args, vars, settings, DEBUG)
  Base.exit()
end

function init_settings(input)
  settings = Dict{String, Any}()
  current_dict = settings
  prev_dict = [Dict{String, Any}()]
  for x in input
    new_dict = Dict{String, Any}()
    y = split(x)
    y = map(z->replace(z, r"(^ *)|( *$)"=>""), y)
    if y[1] == "set"
      push!(current_dict, split(x)[2]=>new_dict)
      push!(prev_dict , current_dict)
      current_dict = new_dict
    elseif y[1] == "end"
      current_dict = pop!(prev_dict)
    else
      x = split(x, '=')
      x = map(z->replace(z, r"(^ *)|( *$)"=>""), x)
      push!(current_dict, x[1]=>x[2])
    end
  end
  return settings
end

function compile(input, settings, DEBUG=false)
  if input[1] in keys(settings["functions"])
    if length(input) - 1 != parse(Int64, settings["functions"][input[1]])
      DEBUG && println(length(input))
      printstyled("ERROR: ", color = :red, bold = true)
      println("Function \"$(input[1])\" takes $(settings["functions"][input[1]]) arguments")
      return 0
    else
      return 1
    end
  else
    printstyled("ERROR: ", color = :red, bold = true)
    println("No function with name \"$(input[1])\"")
    return 0
  end
end

function mail(args, vars, settings, DEBUG)
  sender = settings["emails"]["sender"]
  attachement_names = filter(!isempty, split(args[1], ','))
  file_groups = join(map(x->x in keys(settings["alias"]) ? settings["alias"][x] : x, attachement_names), ',')
  file_att = filter(!isempty, split(file_groups, ','))
  attachfiles = map(x->x in keys(settings["alias"]) ? (attachfiles=settings["path"][settings["alias"][x]]) : (attachfiles=settings["path"][x]), file_att)
  from = (name=settings["emails"][sender], mail=sender)
  to = split(args[2], ',')
  groups = join(map(x->x in keys(settings["nicknames"]) ? settings["nicknames"][x] : x, to), ',')
  receivers = filter(!isempty, split(groups, ','))
  tolist = map(x->x in keys(settings["nicknames"]) ? (name=settings["emails"][settings["nicknames"][x]], mail=settings["nicknames"][x]) : (name=settings["emails"][x],mail=x), receivers)
  message = "Namaste \$receiver,<br><br>Please find attached \$subject. <br><br>Regards,<br>$(from.name)"
  DEBUG && println(tolist)
  ret = 0
  pattempts = 1
  while ret != 1 && pattempts <= parse(Int64, settings["pass_attempts"])
    ret = sendmail(from=from, tolist=tolist, subject=titlecase(args[1]), attachfiles=attachfiles, message=message)
    pattempts += 1
  end
end

function request(args, vars, settings, DEBUG)
  req = args[1]
  sender = settings["emails"]["sender"]
  from = (name=settings["emails"][sender], mail=sender)
  to = split(args[2], ',')
  groups = join(map(x->x in keys(settings["nicknames"]) ? settings["nicknames"][x] : x, to), ',')
  receivers = filter(!isempty, split(groups, ','))
  tolist = map(x->x in keys(settings["nicknames"]) ? (name=settings["emails"][settings["nicknames"][x]], mail=settings["nicknames"][x]) : (name=settings["emails"][x],mail=x), receivers)
  subject = "Request for $(titlecase(req))"
  message = "Namaste \$receiver,<br><br>$(from.name) is requesting you for your $req. Please send your $req to $(from.mail) as an attachment with name \"$(settings["path"][req])\". <br><br>Regards,<br>$(from.name)"
  ret = 0
  while ret != 1
    ret = sendmail(from=from, tolist=tolist, subject=subject, message=message)
  end
end  

function run(args, vars, settings, DEBUG)
  Base.run(`$(args[1])`)
end

function c(args, vars, settings, DEBUG)
  Base.run(`clear`)
end

function update(args, vars, settings, DEBUG)
  Base.run(`./rsa.jl`)
  Base.exit()
end


#Base.run(`./get_key.jl`)

settings = init_settings(filter(!isempty,readlines("config.act")))

#fp = open(settings["path"]["status"], "w")
#write(fp, "1")
#close(fp)
#drive.upload(settings["key_access"]["me"], [settings["path"]["status"]])
#drive.download(settings["key_access"][settings["key_access"]["default"]])
#if  parse.(Int64, readlines(settings["path"]["status"])) != [1]
#  while parse.(Int64, readlines(settings["path"]["status"])) != [1]
#    drive.download(settings["key_access"][settings["key_access"]["default"]])
#    sleep(10)
#  end
#end
#println(settings)

vars = Dict{String, Any}()
push!(vars, "debug"=>false)

if length(ARGS) == 2
  name = ARGS[2]
else
  name = settings["key_access"]["default"]
end

to = name
println(settings["key_access"])
to_id = settings["key_access"][to]["to"]
from = settings["key_access"]["me"]
from_id = settings["key_access"][to]["me"]
while true
  global vars
  if ARGS[1] == "--encrypt"
    print("@>>> ")
    t = readline()
    t = replace(t, r"(^ *)|( *$)"=>"")
    input = filter(!isempty,split(t, ';'))
    input = map(z->replace(z, r"(^ *)|( *$)"=>""), input)
    #Decrypt([], vars, settings, vars["debug"])
    Encrypt([join(input, ';'), "10"], vars, settings, to, to_id, from, from_id, vars["debug"])
    #funcs(input, vars, settings, vars["debug"])
  elseif ARGS[1] == "--decrypt"
    Decrypt([], vars, settings, to, to_id, from, from_id, vars["debug"]) 
  end
end
