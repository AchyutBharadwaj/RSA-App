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

function init_settings(input)
  println(input)
  settings = Dict{String, Any}()
  current_dict = settings
  prev_dict = [Dict{String, Any}()]
  for x in input
    new_dict = Dict{String, Any}()
    y = split(x)
    y = map(z->replace(z, r"(^ *)|( *$)"=>""), y)
    println("y = $y")
    println("Current Dict = $current_dict")
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

settings = init_settings(filter(!isempty,readlines("config.act")))
println(settings)
if length(ARGS) == 1
  name = ARGS[1]
else
  name = settings["key_access"]["default"]
end

to = name
to_id = settings["key_access"][to]["to"]
from = settings["key_access"]["me"]
from_id = settings["key_access"][to]["me"]

println(settings)
println(keys(settings))
println(keys(settings["path"]))
println(keys(settings["key_access"]))

@time (public_key, private_key) = generate_key(parse(BigInt, settings["default"]["generate"]["bits"]), parse(Int64, settings["default"]["generate"]["cycles"])) 
println(public_key)
fp1 = open(settings["path"]["private key"], "w")
fp2 = open(settings["path"]["public key"], "w")
write(fp1, string(private_key[1]), ", ", string(private_key[2]))
write(fp2, string(public_key[1]), ", ", string(public_key[2]))
close(fp1)
close(fp2)
println("We have updated the private key to $(settings["path"]["private key"]) and the public key to $(settings["path"]["public key"])")
drive.edit(from_id, settings["path"]["public key"], join(readlines(settings["path"]["public key"]), '\n'))
#fp = open(settings["path"]["cipher text"], "w")
#write(fp, "")
#close(fp)
#drive.edit(settings["key_access"]["me"], settings["path"]["cipher text"], join(readlines(settings["path"]["cipher text"]), '\n'))
drive.edit(from_id, settings["path"]["cipher text"], "")
println("Uploaded public key")
#fp = open(settings["path"]["status"], "w")
#write(fp, "0")
#close(fp)
drive.edit(from_id, settings["path"]["status"], "0")
