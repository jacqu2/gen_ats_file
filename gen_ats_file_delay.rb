# ATS Table Generator
# Generates Table File to test ATS capability
# Author: Jacqueline Smedley
# Created :11/02/21
# Last Modified: 11/23/21
require 'date'
require 'io/console'
require 'tzinfo'

######################### converts time input string to unix timestamp integer ##################
# parameter is string execution date/time (MM/DD/YYYY HH:MM:SS)
def time_str_to_unix(input_time)
  calc_time = Time.new(input_time[6, 4].to_i, input_time[0, 2].to_i, input_time[3, 2].to_i, input_time[11, 2].to_i, input_time[14, 2].to_i, input_time[17, 2].to_i).to_i
  return calc_time
end
#################################################################################################

############################## calculates start time given current time and offset###############
def calc_start_time(time_delay)
  hours = time_delay[0, 2].to_i
  minutes = time_delay[3, 2].to_i
  seconds = time_delay[6, 2].to_i
  time_offset = Time.now + hours*60*60 + minutes*60 + seconds
  puts "The first ATS command will run at #{time_offset}"
  return time_offset
end
#################################################################################################

#################### converts input time to epoch time in 32-bit seconds#########################
# parameter is string execution date/time (MM/DD/YYYY HH:MM:SS)
def conv_epoch(input_time)
  # (input time in seconds since 1970 - 1980 unix timestamp), gives input time in seconds since 1980 epoch
  calc_time = input_time.to_i - 315532800
  puts "Unix timestamp decimal: #{input_time.to_i}"
  #use following line instead of other calc_time for unix epoch (1970)
  #calc_time = input_time.to_i

  puts "converted time in decimal: #{calc_time}"
  time_hex = calc_time.to_s(16)
  debug = Time.at(calc_time)
  puts "Readable Time (should be 10 years off and in utc): #{debug}, time_hex: #{time_hex}"
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
def gen_timestamps(num_timestamps, seconds_apart, start_timestamp)
  i = 1
  times_array = []
  puts "starting timestamp is #{start_timestamp}"
  # generate first timestamp
  times_array[0] = (start_timestamp.to_i + seconds_apart).to_s(16)

  # generate remaining timestamps
  while i < num_timestamps
    times_array[i] = (times_array[i - 1].to_i + seconds_apart).to_s(16)
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


file_out = file_in + "-r1"

# epoch and hex time conversion
time_converted = conv_epoch(input_time)
timestamps_array = gen_timestamps(4, 5, time_converted)


#save hex contents of file to string
str_data = hex_file_to_str(file_in)

#find time locations
i = 0
time_indx = []
str_data.each_char do |char|
  if char == "1" && str_data[i + 1, 3] == "898"
    if i - 8 >= 0
      time_indx << i - 8      
    end
  end
  i = i + 1
end

# replace times in string
time_indx.each do |index|
  str_data[index, 8] = time_converted.to_s
end

array = str_data.split("")
hex_str_to_bin(str_data, file_out)
