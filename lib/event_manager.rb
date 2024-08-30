#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

FILENAME = 'event_attendees.csv'
SECRET_FILE = 'secret.key'
TEMPLATE_LETTER = 'form_letter.erb'

required_files = [FILENAME, SECRET_FILE, TEMPLATE_LETTER]

missing_files = required_files.reject { |file| File.exist?(file) }

unless missing_files.empty?
  warn "Missing File#{'s' if missing_files.length > 1}"
  exit 1
end

# Clean up the zipcode and handle missing zipcode values
#
# Zipcodes lesser than five characters are padded with '0' in front and
# zipcode with a length greater than 5 are truncated to become five.
# The special case is when the +zipcode+ provided as an argument is nil. For
# this case, '00000' (five zeros) are returned as the default zip code
def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

# Cleans up a phone number by removing non-digit characters and validating its length.
#
# @param phone_number [String] the phone number to be cleaned
# @return [String] the cleaned phone number if valid, otherwise 'Bad number'
def clean_phone_number(phone_number)
  # Remove all non-digit characters from the phone number
  phone_number.to_s.delete!('^0-9')

  case phone_number.length
  when 10
    phone_number
  when 11
    phone_number[0] == '1' ? phone_number[1..] : 'Bad number'
  else
    'Bad number'
  end
end

# Retrieves the legislators for a given zipcode using the Google Civic
# Information API.
#
# @param zipcode [String] the zipcode to search for legislators
# @return [Array, String] an array of officials if successful,
# otherwise an error message
def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read(SECRET_FILE).strip

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting ' \
      'www.commoncause.org/take-action/find-elected-officials'
  end
end

# Saves a thank you letter to a file in the output directory.
#
# @param id [Integer] the ID of the attendee
# @param name [String] the name of the attendee
# @param form_letter [String] the content of the thank you letter
def save_thank_you_letter(id:, name:, form_letter:)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks-#{id}-#{name.to_s.gsub(' ', '-').downcase}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

# Parses a date and time string into a Time object.
#
# @param date_time_string [String] the date and time string to parse
# @param format [String] the format of the date and time string
# @return [Time, String] the parsed Time object if successful, otherwise
# 'Invalid date information'
def datetime(date_time_string, format)
  Time.strptime(date_time_string, format)
rescue ArgumentError
  'Invalid date information'
end

# Logs the registration time by hour and weekday.
#
# @param date_time_string [String] the date and time string of the
# registration
# @param format [String] the format of the date and time string
# @param registration_hours [Hash] the hash to store registration
# counts by hour
# @param registration_weekdays [Hash] the hash to store registration
# counts by weekday
def log_registration_time(
  date_time_string, format, registration_hours, registration_weekdays
)
  time = datetime(date_time_string, format)

  return unless time.is_a? Time

  hour_key = time.hour.to_s
  weekday_key = time.strftime('%A')

  registration_hours[hour_key] = registration_hours.fetch(hour_key, 0) + 1
  registration_weekdays[weekday_key] = registration_weekdays.fetch(
    weekday_key, 0
  ) + 1
end

# Finds the top 5 peak registration hours.
#
# @param registration_hours [Hash] the hash containing registration counts
# by hour
# @return [Array] an array of the top 5 peak registration hours and
# their counts
def peak_registration_hours(registration_hours)
  registration_hours.max_by(5) { |_key, value| value }
end

# Finds the top 3 peak registration weekdays.
#
# @param registration_weekdays [Hash] the hash containing registration counts
# by weekday
# @return [Array] an array of the top 3 peak registration weekdays and
# their counts
def peak_registration_weekdays(registration_weekdays)
  registration_weekdays.max_by(3) { |_key, value| value }
end

# Records the peak registration hours and weekdays to a file.
#
# @param registration_hours [Hash] the hash containing registration counts
# by hour
# @param registration_weekdays [Hash] the hash containing registration counts
# by weekday
def record_peak_hours_and_weekdays(registration_hours:, registration_weekdays:)
  File.open('peak_hours_and_weekdays.txt', 'w+') do |file|
    file.puts 'TOP 5 Peak Hours'.center(35, '*')
    peak_registration_hours(registration_hours).each do |peak_hour|
      file.puts "Hour: #{peak_hour[0]}, " \
                  "Number of registrations: #{peak_hour[1]}"
    end

    file.puts "\n"
    file.puts 'TOP 3 Peak Weekdays'.center(35, '*')
    peak_registration_weekdays(registration_weekdays).each do |peak_weekday|
      file.puts "Weekday: #{peak_weekday[0]}, " \
                  "Number of registrations:#{peak_weekday[1]}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  registration_hours = {}
  registration_weekdays = {}

  puts "Event Manager Initialized!\n\n"

  contents = CSV.open(FILENAME, headers: true, header_converters: :symbol)
  template_letter = File.read('form_letter.erb')
  erb_template = ERB.new template_letter

  contents.each do |row|
    id = row[0]
    name = row[:first_name].to_s.capitalize
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zipcode(zipcode)

    log_registration_time(
      row[:regdate], '%m/%d/%y %H:%M',
      registration_hours,
      registration_weekdays
    )

    form_letter = erb_template.result(binding)
    save_thank_you_letter(id:, name:, form_letter:)
  end

  record_peak_hours_and_weekdays(registration_hours:, registration_weekdays:)
end
