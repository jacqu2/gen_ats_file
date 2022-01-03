# ATS Table Generator
# Generates Table File to test ATS capability, calculates and replaces checksum
# Author: Jacqueline Smedley
# Created :11/02/21
# Last Modified: 12/10/21
require 'date'
require 'io/console'
############ calculates start time given current time and offset##############
def calc_start_time(time_delay)
  hours = time_delay[0, 2].to_i
  minutes = time_delay[3, 2].to_i
  seconds = time_delay[6, 2].to_i + 10
  time_offset = Time.now.to_i + hours*60*60 + minutes*60 + seconds
  # puts "TIME_NOW is #{Time.now.to_i}"
  puts "The first ATS command will run at #{Time.at(time_offset).utc}"
  return time_offset
end
##############################################################################
############ converts input time to epoch time in 32-bit seconds #############
# parameter is start time object
def conv_epoch(input_time)
  # (input time in seconds since 1970 - 1980 unix timestamp), gives input time 
  # in seconds since Jan 1st 1980 epoch
  epoch_year = 1980
  epoch_day = 01
  epoch_month = 01
  epoch_offset = Time.new(epoch_year, epoch_month, epoch_day).to_i
  gmt_offset = 18000
  calc_time = input_time.to_i - epoch_offset + gmt_offset 
  time_hex = calc_time.to_s(16)
  debug = Time.at(calc_time)
  # puts "Readable Time (unix): #{debug}"
  # puts "Unix start time in raw seconds: #{input_time.to_i}"
  # puts "Unix start time in hex: #{input_time.to_i.to_s(16)}"
  # puts "Epoch start time in raw seconds: #{calc_time}"
  # puts "Epoch start time in hex: #{time_hex}"
  return time_hex
end
##############################################################################
################# writes hex contents of file to string ######################
def hex_file_to_str(fname)
  #read the binary
  file_in = File.binread(fname)
  #convert to hex
  hex_file = file_in.unpack('H*')[0]
  bin_str = file_in.unpack('B*')[0]
  hex_file_scan = hex_file.scan /.{1,2}/
  #save to string
  i = 0
  data = ''
  hex_file_scan.each do |byte|
    data += byte
  end  
  return data
end
##############################################################################
#################### writes hex string to binary file ########################
def hex_str_to_bin(str_in, filename_out)
  packed = Array(str_in).pack('H*')
  File.binwrite(filename_out, packed)
end
##############################################################################
##### generates an array of n timestamps a given amount of seconds apart #####
# inputs are number of timestamps to be generated, interval between each time
# stamp, and the start timestamp (output of conv_epoch method)
def gen_timestamps(num_cmds, seconds_apart, start_time_object)
  i = 0
  times_array = []
  # generate timestamps
  while i < num_cmds
    times_array[i] = conv_epoch(start_time_object + seconds_apart*(i + 1))
    i = i + 1
  end
  puts "Command execution times: #{times_array}"
  return times_array
end
##############################################################################
time_invalid = 1
filename_invalid = 1
while filename_invalid == 1
  puts "please enter filename (.tbl file): "
  file_in = gets.chomp
  #check for valid time format
  if !File.exist?(file_in)
    puts "ERROR: File does not exist, please try again"  
  else
    filename_invalid = 0
  end
end
#save hex contents of file to string
str_data = hex_file_to_str(file_in)
file_out = file_in + "-r1"
while time_invalid == 1
  puts "How long would you like to wait for the first ATS command? (HH:MM:SS): "
  time_offset = gets.chomp
  #check for valid time format
  if (time_offset.length == "HH:MM:SS".length)
    #parse input and convert to timestamp
    input_time = calc_start_time(time_offset)
    # epoch and hex time conversion
    time_converted = conv_epoch(input_time)
    time_invalid = 0
  else
    puts "INVALID FORMAT. Please try again (single digits should have leading 
    zeros)"
  end
end
# find location of each cmd
time_indx = []
xsum_indx = []
len_indx = []
lengths = []
next_cmd_num = "01"
num_cmds = 0
next_cmd_indx = 234
i = 0
if str_data[next_cmd_indx, 2] != "01"
  puts "First command not in expected location, other data will be incorrect."
end  

while(1)
  if str_data[next_cmd_indx, 2].hex.to_i == next_cmd_num.to_i
    time_indx[i] = next_cmd_indx + 2
    len_indx[i] = next_cmd_indx + 18
    lengths[i] = str_data[len_indx[i], 4]
    len = str_data[len_indx[i], 4].hex + 1
    xsum_indx[i] = len_indx[i] + 6
    next_cmd_indx = len_indx[i] + ((len * 2) - 2) + 8
    next_cmd_num = (next_cmd_num.hex + 1).to_s
    puts "next cmd in file: #{str_data[next_cmd_indx, 2]} at indx #{next_cmd_indx}"
    i = i + 1
    num_cmds = num_cmds + 1
  else
    break
  end
end
puts "How many seconds between each command?: "
time_btwn_cmds = gets.chomp
# generate timestamps
timestamps_array = gen_timestamps(num_cmds, time_btwn_cmds.to_i, input_time)
# replace times in string, calculate each checksum
array_indx = 0
time_indx.each do |index|
  i = 0
  str_data[index, 8] = timestamps_array[array_indx].to_s
end
# calculate checksum for each command
i_cmd = 0
while i_cmd < num_cmds
  i = 0
  xsum = "FF"
  # 2 bytes ID, 2 bytes c0 00, 2 bytes length, n bytes data, 1 byte xsum
  numel_xsum = 12 + lengths[i_cmd].hex
  # xor all bits from ID to checksum
  while i <= numel_xsum
    # puts "xor-ing #{xsum} and #{str_data[(time_indx[i_cmd] + 8 + i), 2]}"
    xsum = (xsum.to_i(16) ^ str_data[(time_indx[i_cmd] + 8 + i), 2].to_i(16)).to_s(16) 
    i = i + 2
  end
  # puts "xsum for cmd #{i_cmd} is #{xsum}"
  str_data[xsum_indx[i_cmd], 2] = xsum
  i_cmd = i_cmd + 1
  puts "checksum #{i_cmd}: #{xsum}"
end
array = str_data.split("")
hex_str_to_bin(str_data, file_out)
puts "ATS file saved under filename #{file_out}"
