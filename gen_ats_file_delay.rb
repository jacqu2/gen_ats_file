# ATS Table Generator
# Generates Table File to test ATS capability
# Author: Jacqueline Smedley
# Created :11/02/21
# Last Modified: 11/23/21
require 'date'
require 'io/console'

############################## calculates start time given current time and offset###############
def calc_start_time(time_delay)
  hours = time_delay[0, 2].to_i
  minutes = time_delay[3, 2].to_i
  seconds = time_delay[6, 2].to_i + 10
  # add 10s offset for user input entry delay
  time_offset = Time.now.to_i + hours*60*60 + minutes*60 + seconds
  puts "TIME_NOW is #{Time.now.to_i}"
  puts "The first ATS command will run at #{time_offset.to_i}"
  return time_offset
end
#################################################################################################

#################### converts input time to epoch time in 32-bit seconds#########################
# parameter is start time object
def conv_epoch(input_time)
  # (input time in seconds since 1970 - 1980 unix timestamp), gives input time in seconds since Jan 1st 1980 epoch
  epoch_year = 1980
  epoch_day = 01
  epoch_month = 01
  epoch_offset = Time.new(epoch_year, epoch_month, epoch_day).to_i
  calc_time = input_time.to_i - epoch_offset #time diff between telemetry and tool

  #use following line instead of other calc_time for unix epoch (1970)
  #calc_time = input_time.to_i

  time_hex = calc_time.to_s(16)
  debug = Time.at(calc_time)
  #puts "Readable Time (unix): #{debug}"
  puts "Unix start time in raw seconds: #{input_time.to_i}"
  #puts "Unix start time in hex: #{input_time.to_i.to_s(16)}"
  puts "Epoch start time in raw seconds: #{calc_time}"
  puts "Epoch start time in hex: #{time_hex}"
  return time_hex
end
#################################################################################################

#################### writes hex contents of file to string ######################################
def hex_file_to_str(fname)
  #read the binary
  file_in = File.binread(fname)

  #convert to hex
  hex_file = file_in.unpack('H*')[0]
  hex_file_scan = hex_file.scan /.{1,2}/

  #save to string
  i = 0
  data = ''
  hex_file_scan.each do |byte|
    data += byte
  end  
  return data
end
#################################################################################################

#################### writes hex string to binary file ######################################
def hex_str_to_bin(str_in, filename_out)
  packed = Array(str_in).pack('H*')
  File.binwrite("sc_ats1.tbl-r1", packed)
end
#################################################################################################

############# generates an array of n timestamps a given amount of seconds apart ################
# inputs are number of timestamps to be generated, interval between each timestamp, and the start
# timestamp (output of conv_epoch method)
def gen_timestamps(num_cmds, seconds_apart, start_time_object)
  i = 0
  times_array = []
  # generate timestamps
  while i < num_cmds
    times_array[i] = conv_epoch(start_time_object + seconds_apart*(i + 1))
    i = i + 1
  end
  puts times_array
  return times_array
end
#################################################################################################

time_invalid = 1
filename_invalid = 1

while filename_invalid == 1
  puts "please enter filename (.tbl file): "
  file_in = gets.chomp

  #check for valid time format
  if !File.exist?('sc_ats1.tbl')
    puts "ERROR: File does not exist, please try again"  
  else
    filename_invalid = 0
  end
end


while time_invalid == 1
  puts "How long would you like to wait for the first ATS command? (HH:MM:SS): "
  time_offset = gets.chomp

  #check for valid time format
  if (time_offset.length == "HH:MM:SS".length)
    input_time = calc_start_time(time_offset)
    time_invalid = 0
  else
    puts "INVALID FORMAT. Please try again (single digits should have leading zeros)"
  end
end

puts "How many seconds between each command?: "
time_btwn_cmds = gets.chomp

file_out = file_in + "-r2"

# epoch and hex time conversion
time_converted = conv_epoch(input_time)

#save hex contents of file to string
str_data = hex_file_to_str(file_in)

#find time locations and number of commands
i = 0
num_cmds = 0
time_indx = []
str_data.each_char do |char|
  if char == "1" && str_data[i + 1, 3] == "898"
    if i - 8 >= 0
      time_indx << i - 8   
      num_cmds = num_cmds + 1   
    end
  end
  i = i + 1
end

# generate timestamps
timestamps_array = gen_timestamps(num_cmds, time_btwn_cmds.to_i, input_time)

# replace times in string
array_indx = 0
time_indx.each do |index|
  str_data[index, 8] = timestamps_array[array_indx].to_s
  array_indx = array_indx + 1
end

#time_indx.each do |index|
#  str_data[index, 8] = time_converted.to_s
#end

array = str_data.split("")
hex_str_to_bin(str_data, file_out)
