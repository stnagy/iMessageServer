require 'sqlite3'
require 'fileutils'

class MessageTools

  def initialize
    @osx_username = `id -un`.gsub("\n","") # osx command to get username
    @permanent_db_file = "/Users/#{@osx_username}/Library/Messages/chat.db"
    @temp_db_file_dir = Rails.root.to_s + "/tmp/storage/"
    @temp_db_file = Rails.root.to_s + "/tmp/storage/chat.db"
    @db = nil
  end

  def get_messages(n=100)
    # the difference between this method and "get_raw_messages"
    # is this method returns messages with more information obtained
    # by utilizing the join table information

    # pull all data needed
    raw_messages = get_raw_messages()
    handles = get_handles()
    chats = get_chats()
    chat_messages = get_chat_message_joins()
    chat_handles = get_chat_handle_joins()
    attachments = get_attachments()
    message_attachments = get_message_attachment_joins()

    # pull contacts
    contact_tools = ContactTools.new
    contact_numbers = contact_tools.get_phone_numbers
    contact_records = contact_tools.get_records

    # return variables
    filtered_messages = []

    # iterate over messages
    raw_messages.each do |message|

      # new variables to return
      sender_contact = nil
      sender_name = nil
      other_recipients = []

      # get message ID
      message_id = message["ROWID"]

      if message["is_from_me"] == 1

        sender_contact = @osx_username
        sender_name = @osx_username

      else

        # get sender information
        sender_handle_id = message["handle_id"]
        handles.each { |h| sender_contact = h["id"] if h["ROWID"] == sender_handle_id}
        message["sender_contact"] = sender_contact
        contact_id = nil
        contact_numbers.each do |cn|
          contact_id = cn["ZOWNER"] if cn["formatted_number"] == sender_contact
        end
        if contact_id
          contact_record = contact_records[contact_id - 1]
          sender_name = contact_record["ZFIRSTNAME"] + " " + contact_record["ZLASTNAME"]
        end

      end

      message["sender_contact"] = sender_contact
      message["sender_name"] = sender_name

      # get chat info and other recipients
      chat_id = nil
      other_handles = []
      chat_messages.each { |cm| chat_id = cm["chat_id"] if cm["message_id"] == message_id }
      if chat_id
        message["chat_id"] = chat_id
        chats.each { |c| message["chat_guid"] = c["guid"] if ( c["ROWID"] == chat_id ) }
        chat_handles.each { |ch| other_handles << ch["handle_id"] if ( (ch["chat_id"] == chat_id) && (ch["handle_id"] != sender_handle_id) ) }
        other_handles.each do |oh|
          handles.each do |h|
            if h["ROWID"] == oh
              contact_id = nil
              recipient_number = h["id"]
              contact_numbers.each do |cn|
                contact_id = cn["ZOWNER"] if cn["formatted_number"] == recipient_number
              end
              if contact_id
                contact_record = contact_records[contact_id - 1]
                recipient_name = contact_record["ZFIRSTNAME"] + " " + contact_record["ZLASTNAME"]
              end
              other_recipients << { "contact": recipient_number, "name": recipient_name }
            end
          end
        end
      end
      message["other_recipients"] = other_recipients

      # get any attachments
      has_attachment = false
      attachment_filetype = nil
      message_attachments.each do |ma|
        if ma["message_id"] == message_id
          has_attachment = true
          attachment_id = ma["attachment_id"]
          attachments.each do |a|
            attachment_filename = a["filename"] if a["ROWID"] == attachment_id
            if attachment_filename
              attachment_filetype = File.extname(attachment_filename)
              break
            end
          end
        end
      end
      message["has_attachment"] = has_attachment
      message["attachment_filetype"] = attachment_filetype

      # filter messages
      filtered_messages << message.slice("text", "sender_contact", "sender_name", "other_recipients", "has_attachment", "attachment_filetype")
    end

    return raw_messages
    #return filtered_messages

  end

  def get_table(table_name)

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from #{table_name}"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_all_tables

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select name from sqlite_master where type = 'table'"

    # create results hash
    results_array = cmd.map { |row| row }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_array

  end

  # private

  def get_raw_messages(n=100)

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from message order by date desc limit #{n} "

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_attachments

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from attachment"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_message_attachment_joins

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from message_attachment_join"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_handles

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from handle"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_chats

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from chat"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_chat_message_joins

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from chat_message_join"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_chat_handle_joins

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_imessage_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @db.prepare "select * from chat_handle_join"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_imessage_db()

    return results_hash_array

  end

  def get_db
    @db
  end

  def connect_to_imessage_db

    # Database must be copied to another location (db_filepath), e.g. a temp folder
    # because for some reason OS X will not let ruby open original DB file
    FileUtils.cp(@permanent_db_file, @temp_db_file_dir)
    FileUtils.cp(@permanent_db_file + "-shm", @temp_db_file_dir)
    FileUtils.cp(@permanent_db_file + "-wal", @temp_db_file_dir)

    # Connect to Database
    @db = SQLite3::Database.open @temp_db_file

  end

  def disconnect_from_imessage_db

    @db = nil

    # delete temp_db_file
    begin
      FileUtils.rm(@temp_db_file)
      FileUtils.rm(@temp_db_file + "-shm")
      FileUtils.rm(@temp_db_file + "-wal")
    rescue
      puts "INFO: Some DB related files could not be deleted because they were not found."
    end

    return

  end

end
