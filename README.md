# Event Manager

## Description

Event Manager is a Ruby application designed to manage event attendees. It reads
attendee data from a CSV file, cleans and processes the data, retrieves
legislators based on zip codes, and generates personalized thank you letters.
Additionally, it logs registration times to determine peak registration hours
and weekdays.

## Prerequisites

- Ruby (version 2.5 or higher)
- Bundler (version 2.0 or higher)

## Installation

1. **Clone the repository:**
   ```sh
   git clone https://github.com/nanafox/event_manager.git
   cd event_manager
   ```

2. **Install the required gems:**
   ```sh
   bundle install
   ```

3. **Ensure the following files are present in the project directory:**
    - `event_attendees.csv` (CSV file containing attendee data)
    - `secret.key` (file containing the Google Civic Information API key)
    - `form_letter.erb` (ERB template for the thank you letter)

## How to use

1. **Run the Event Manager script:**
   ```sh
   ./lib/event_manager.rb
   ```

2. **Output:**
    - The script will generate thank you letters in the `output` directory.
    - It will also create a file named `peak_hours_and_weekdays.txt` containing
      the top 5 peak registration hours and the top 3 peak registration
      weekdays.

3. **Logs:**
    - The script logs registration times and determines peak hours and weekdays
      based on the data in the `event_attendees.csv` file.
