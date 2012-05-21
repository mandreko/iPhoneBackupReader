require 'sqlite3'

@backup_path = "#{ENV['APPDATA']}\\Apple Computer\\MobileSync\\Backup\\"
@sms_filename = "3d0d7e5fb2ce288813306e4d4636395e047a3d28"
@local_dump_store = "C:\\dump\\"

def strip_phone_number(number)
  number.gsub(/[^a-zA-Z0-9]/, '')
end

def format_epoch_date(date)
  time = Time.at(date)
  time.to_s
end

def format_imessage_date(date)
  # For some reason, Apple decided that it'd be a good idea to start time at 2001-01-01 00:00:00
  time = Time.at(date) + 978_307_200 # Seconds difference between epoch and apple's epoch
  time.to_s
end

def get_recipient_numbers(db)
  recipients = []
  db.execute("select distinct address from message") do |row|
    recipients << row['address'] if !row['address'].nil?
  end

  db.execute("select distinct madrid_handle from message") do |row|
    recipients << row['madrid_handle'] if !row['madrid_handle'].nil?
  end

  recipients
end

def get_backup_folders
  backups = []
  Dir.foreach(@backup_path) do |f|
    next if f == '.' or f == '..'

    backups << f
  end
  backups
end

def get_sms_messages_for_number(db, number)
  messages = []

  db.execute("select date, text from message where is_madrid = 0 and (address = ? or madrid_handle = ?)", number, number) do |row|
    messages << {:date => format_epoch_date(row['date']), :text => row['text']}
  end

  db.execute("select date, text from message where is_madrid = 1 and (address = ? or madrid_handle = ?)", number, number) do |row|
    messages << {:date => format_imessage_date(row['date']), :text => row['text']}
  end

  # Re-sort them, since they may have a mix of sms + iMessage results
  messages.sort_by! {|obj| obj[:date]}
end

def dump_sms_messages(file_name)
  db = SQLite3::Database.new(file_name)
  db.results_as_hash = true

  # Get a unique list of recipients
  get_recipient_numbers(db).each do |number|
    # For each recipient, make an output file to dump the messages to
    Dir.mkdir(@local_dump_store) if !Dir.exists?(@local_dump_store)

    messages = get_sms_messages_for_number(db, number)

    # TODO: figure out how to tell who is the sender, and who is the recipient
    output_file_name = @local_dump_store + strip_phone_number(number)
    File.open(output_file_name, 'w') {|f|
      messages.each do |msg|
        f.write("#{msg[:date]}: #{msg[:text]}\n")
      end
    }

  end
end

# Iterate over all backup SMS files
get_backup_folders().each do |i|
  file_name = @backup_path + i + "\\" + @sms_filename
  next if !File.exists?(file_name)

  dump_sms_messages(file_name)
end

