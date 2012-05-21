require 'sqlite3'

@backup_path = "#{ENV['APPDATA']}\\Apple Computer\\MobileSync\\Backup\\"
@sms_filename = "3d0d7e5fb2ce288813306e4d4636395e047a3d28"
@local_dump_store = "C:\\dump\\"

def strip_phone_number(number)
  return number.gsub(/[^a-zA-Z0-9]/, '')
end

def format_epoch_date(date)
  time = Time.at(date)
  return time.to_s
end

def get_recipient_numbers(db)
  recipients = []
  db.execute("select distinct address from message") do |row|
    # TODO: figure out why the first address is nil: madrid_handle is iMessage username
    recipients << row['address'] if !row['address'].nil?
  end

  return recipients
end

def get_backup_folders
  backups = []
  Dir.foreach(@backup_path) do |f|
    next if f == '.' or f == '..'

    backups << f
  end
  return backups
end

def get_sms_messages_for_number(db, number)
  messages = []

  db.execute("select date, text from message where address = ? order by date asc", number) do |row|
    messages << {:date => format_epoch_date(row['date']), :text => row['text']}
  end

  return messages
end

def dump_sms_messages(file_name)
  db = SQLite3::Database.new(file_name)
  db.results_as_hash = true

  # Get a unique list of recipients
  get_recipient_numbers(db).each do |number|
    # For each recipient, make an output file to dump the messages to
    Dir.mkdir(@local_dump_store) if !Dir.exists?(@local_dump_store)

    puts "Starting to process #{number}"
    messages = get_sms_messages_for_number(db, number)

    # TODO: figure out how to tell who is the sender, and who is the recipient
    File.open("#{@local_dump_store}#{strip_phone_number(number)}", 'w') {|f|
      messages.each do |msg|
        f.write("#{msg[:date]}: #{msg[:text]}\n")
      end
    }

  end
end

# Iterate over all backup SMS files
get_backup_folders().each do |i|
  file_name = "#{@backup_path}#{i}\\#{@sms_filename}"
  next if !File.exists?(file_name)

  dump_sms_messages(file_name)


end

