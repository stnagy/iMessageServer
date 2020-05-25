require 'sqlite3'
require 'fileutils'

class ContactTools

  def initialize
    @permanent_contact_db_file = `mdfind AddressBook-v22.abcddb | grep Sources | sort`.split("\n")
    @temp_contact_db_file_dir = Rails.root.to_s + "/tmp/storage"
    @temp_contact_db_file = Rails.root.to_s + "/tmp/storage/AddressBook-v22.abcddb"
    @contact_db = nil
  end

  def get_all_tables

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_contacts_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @contact_db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @contact_db.prepare "select name from sqlite_master where type = 'table'"

    # create results hash
    results_array = cmd.map { |row| row }

    # remove temp_db_file
    disconnect_from_contacts_db()

    return results_array

  end

  def get_table(table_name)

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_contacts_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @contact_db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @contact_db.prepare "select * from #{table_name}"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_contacts_db()

    return results_hash_array

  end

  def get_records

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_contacts_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @contact_db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @contact_db.prepare "select * from ZABCDRECORD"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_contacts_db()

    return results_hash_array

  end

  def get_contact_index

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_contacts_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @contact_db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @contact_db.prepare "select * from ZABCDCONTACTINDEX"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_contacts_db()

    return results_hash_array

  end

  def get_phone_numbers

    # this method actually creates a temporary copy and connects to it
    # this method also sets the module instance variable @db
    connect_to_contacts_db()

    # checkpoint the temp_db to make sure it is fully up to date
    # (the normal chat.db database checkpoints infrequently, resulting
    # in a fairly long delay in updating for new messages)
    @contact_db.execute "PRAGMA wal_checkpoint(2)"

    # prepare db command to grab last n messages
    # n is a parameter of this method
    cmd = @contact_db.prepare "select * from ZABCDPHONENUMBER"

    # get column names
    # will use column names to generate list of hashes corresponding to messages
    column_names_array = cmd.columns

    # create results hash
    results_hash_array = cmd.map { |row| Hash[column_names_array.zip (row)] }

    # remove temp_db_file
    disconnect_from_contacts_db()

    results_hash_array.each do |r|
      unformatted_phone_number = r["ZFULLNUMBER"]
      formatted_number = "+1" + unformatted_phone_number.scan(/\d/).join("")
      r["formatted_number"] = formatted_number
    end

    return results_hash_array

  end

  private

  def connect_to_contacts_db

    # Database must be copied to another location (db_filepath), e.g. a temp folder
    # because for some reason OS X will not let ruby open original DB file
    FileUtils.cp(@permanent_contact_db_file, @temp_contact_db_file_dir)
    #FileUtils.cp(@permanent_contact_db_file + "-shm", @temp_contact_db_file_dir)
    #FileUtils.cp(@permanent_contact_db_file + "-wal", @temp_contact_db_file_dir)

    # Connect to Database
    @contact_db = SQLite3::Database.open @temp_contact_db_file

  end

  def disconnect_from_contacts_db

    @db = nil

    # delete temp_db_file
    begin
      FileUtils.rm(@temp_contact_db_file)
      FileUtils.rm(@temp_contact_db_file + "-shm")
      FileUtils.rm(@temp_contact_db_file + "-wal")
    rescue
      puts "INFO: Some DB related files could not be deleted because they were not found."
    end

    return

  end

end
