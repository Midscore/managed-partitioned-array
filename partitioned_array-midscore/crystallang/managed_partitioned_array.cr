#require_relative "partitioned_array"
# NOTE: ManagedPartitionedArray and PartitionedArray have different versions. PartitionedArray can work along but
# ManagedPartitionedArray, while being the superset, depends on PartitionedArray
# VERSION v2.0.0-mpa / v1.2.6-pa - added more arguments to the archive! methods, since file partition contexts don"t need to exactly meet with all the others
# VERSION v1.3.2-mpa / v1.2.5a-pa - save and load partition from disk now auto-saves all variables, since those always change often (10/21/2022 1:11PM)
# VERSION ManagedPartitionedArray/PartitionedArray - v1.3.1release(MPA)/v1.2.5a(PA) (MPA-v1.3.1-rel_PA-v1.2.5a-rel)
# - cleanup and release new version (10/19/2022 - 1:50PM)

# VERSION v1.3.0a - endless add implementation in ManagedPartitionedArray#endless_add
# Allows the database to continuously add and allocate, as if it were a plain PartitionedArray
# NOTE: consider the idea that adding a partition may mean that it saves all variables and everything to disk
# SUGGESTION: working this out by only saving by partition, and not by the whole database
# SUGGESTION: this would mean that the database would have to be loaded from the beginning, but that"s not a big deal
# VERSION v1.2.9 - fixes
# VERSION v1.2.8 - Regression and bug found and fixed; too many guard clauses at at_capacity? method (10/1/2022)
# VERSION v1.2.7 - fixed more bugs with dynamic allocation
# VERSION v1.2.6 - bug fix with array allocation given that you don"t want to create file partitions (9/27/2022 - 7:09AM)
# VERSION v1.2.5 - bug fixes
# VERSION: v1.1.4 - seemed to have sorted out the file issues... but still need to test it out
# VERSION: v1.1.3 
# many bug fixes; variables are now in sync with file i/o
# Stopped: problem with @latest_id not being set correctly
# working on load_from_archive! and how it will get the latest archive database and load up all the variables, only it seems
# that there is something wrong with that. 
# VERSION: v1.1.2 (9/13/2022 10:17 am)
# Prettified
# Added raise to ManagedPartitionedArray#at_capacity? if @has_capacity == false
# VERSION: v1.1.1a - got rid of class variables, and things seem to be fully working now
# VERSION: v1.1.0a - fully functional, but not yet tested--test in the real world
# VERSION: v1.0.2 - more bug fixes, added a few more tests
# VERSION: v1.0.1 - bug fixes
# VERSION: v1.0.0a - fully functional at a basic level; can load archives and the max id of the archive is always available
# VERSION: v0.1.3 - file saving and other methods properly working
# VERSION: v0.1.2 - added managed databases, but need to add more logic to make it work fully
# VERSION: v0.1.1
# UPDATE 8/31/2022: @latest_id increments correctly now
# Manages the @last_entry variable, which tracks where the latest entry is, since PartitionedArray is dynamically allocated.
class ManagedPartitionedArray < PartitionedArray 
  property :endless_add, :range_arr, :rel_arr, :db_size, :data_arr, :partition_amount_and_offset, :db_path, :db_name, :max_capacity, :has_capacity, :latest_id, :partition_archive_id, :max_partition_archive_id, :db_name_with_no_archive

  # DB_SIZE > PARTITION_AMOUNT
  PARTITION_AMOUNT = 9 # The initial, + 1
  OFFSET = 1 # This came with the math, but you can just state the PARTITION_AMOUNT in total and not worry about the offset in the end
  DB_SIZE = 20 # Caveat: The DB_SIZE is the total # of partitions, but you subtract it by one since the first partition is 0, in code. that is, it is from 0 to DB_SIZE-1, but DB_SIZE is then the max allocated DB size
  PARTITION_ARCHIVE_ID = 0
  DEFAULT_PATH = "./DB_TEST" # default fallback/write to current path
  DEBUGGING = false
  PAUSE_DEBUG = false
  DB_NAME = "partitioned_array_slice"
  PARTITION_ADDITION_AMOUNT = 1
  MAX_CAPACITY = "data_arr_size" # : :data_arr_size; a keyword to add to the array until its full with no buffer additions
  HAS_CAPACITY = true # if false, then the max_capacity is ignored and at_capacity? raises if @has_capacity == false
  DYNAMICALLY_ALLOCATES = true
  ENDLESS_ADD = false
  @original_db_name : String
  @db_name_with_archive : String
  #@partition_amount_and_offset : BigInt
  #@db_size : BigInt
  #@data_arr : Array(String)
  @partition_archive_id : BigInt | Int32
  @max_partition_archive_id : BigInt | Int32 | JSON::Any
  #@db_name_with_no_archive : String
  @max_capacity : BigInt | String
  @has_capacity : Bool
  @latest_id : BigInt | Int32
  @endless_add : Bool
  @range_arr : Array(BigInt)
  @rel_arr : Array(BigInt)
  @db_path : String
  @db_name : String

  #@partition_addition_amount : BigInt | Int32

  def initialize(endless_add = ENDLESS_ADD, dynamically_allocates = DYNAMICALLY_ALLOCATES, partition_addition_amount = PARTITION_ADDITION_AMOUNT, max_capacity = MAX_CAPACITY, has_capacity = HAS_CAPACITY, partition_archive_id = PARTITION_ARCHIVE_ID, db_size = DB_SIZE, partition_amount_and_offset = PARTITION_AMOUNT + OFFSET, db_path = DEFAULT_PATH, db_name = DB_NAME) 
    @db_path = db_path
    @partition_archive_id = partition_archive_id
    
    @original_db_name = strip_archived_db_name(db_name: db_name)
    @db_name_with_archive = db_name_with_archive(db_name: @original_db_name, partition_archive_id: @partition_archive_id)    
    @max_capacity = max_capacity
    @latest_id = 0 # last entry    
    # @max_capacity = max_capacity_setup! # => commented out on 10/4/2022 1:32am
    @has_capacity = has_capacity
    @max_partition_archive_id = initialize_max_partition_archive_id!
    @partition_addition_amount = partition_addition_amount
    @max_capacity = max_capacity_setup!
    @dynamically_allocates = dynamically_allocates  
    @endless_add = endless_add # add endlessly like a regular partitioned array
    super(@partition_addition_amount, @dynamically_allocates, db_size, partition_amount_and_offset, db_path, @db_name_with_archive)
  end

  # one keyword available: :data_arr_size
  def max_capacity_setup!
    #p "@max_capacity: #{@max_capacity}"#{@max_capacity} if DEBUGGING"
    if (@max_capacity == "data_arr_size")
      #@max_capacity = (0..(db_size * (partition_amount_and_offset))).to_a.size - 1
      #@partition_addition_amount = partition_addition_amount
      return "data_arr_size"
    else
      return max_capacity
    end
  end

  def save_data_arr_to_disk!
    # WIP
  end

  def dump_all_variables
    p "db_size: #{@db_size}"
    p "partition_amount_and_offset: #{@partition_amount_and_offset}"
    p "db_path: #{@db_path}"
    p "db_name: #{@db_name}"
    p "max_capacity: #{@max_capacity}"
    p "has_capacity: #{@has_capacity}"
    p "latest_id: #{@latest_id}"
    p "partition_archive_id: #{@partition_archive_id}"  
    p "db_name_with_no_archive: #{@db_name_with_no_archive}"
    p "db_name_with_archive: #{@db_name_with_archive}"
    p "max_partition_archive_id: #{@max_partition_archive_id}"
    p "partition_addition_amount: #{@partition_addition_amount}"
    p "dynamically_allocates: #{@dynamically_allocates}"
    p "endless_add: #{@endless_add}"
  end

  def archive_and_new_db!(auto_allocate = true, partition_addition_amount = @partition_addition_amount, max_capacity = @max_capacity, has_capacity = @has_capacity, partition_archive_id = @partition_archive_id, db_size = @db_size, partition_amount_and_offset = @partition_amount_and_offset, db_path = @db_path, db_name = @db_name_with_archive)
    save_everything_to_files!
    @partition_archive_id += 1
    increment_max_partition_archive_id!
    temp = ManagedPartitionedArray.new(max_capacity: @max_capacity, partition_archive_id: @partition_archive_id, db_size: @db_size, partition_amount_and_offset: @partition_amount_and_offset, db_path: @db_path, db_name: @db_name_with_archive)
    temp.allocate if auto_allocate
    return temp
  end

  ## ex ManagedPartitionedArray#load_archive_no_auto_allocate!(partition_archive_id: partition_archive_id, ...)
  def load_archive_no_auto_allocate!(has_capacity = @has_capacity, dynamically_allocates = @dynamically_allocates, endless_add = @endless_add, partition_archive_id = @max_partition_archive_id, db_size = @db_size, partition_amount_and_offset = @partition_amount_and_offset, db_path = @db_path, db_name = @db_name_with_archive, max_capacity = @max_capacity, partition_addition_amount = @partition_addition_amount)
    temp = ManagedPartitionedArray.new(dynamically_allocates, endless_add, max_capacity, partition_archive_id, db_size, partition_amount_and_offset, db_path, db_name_with_archive)
    return temp
  end

  # ex ManagedPartitionedArray#load_from_archive!(partition_archive_id: partition_archive_id, ...)
  def load_from_archive!(has_capacity = @has_capacity, dynamically_allocates = @dynamically_allocates, endless_add = @endless_add, partition_archive_id = @max_partition_archive_id, db_size = @db_size, partition_amount_and_offset = @partition_amount_and_offset, db_path = @db_path, db_name = @db_name_with_archive, max_capacity = @max_capacity, partition_addition_amount = @partition_addition_amount)
    temp = ManagedPartitionedArray.new(dynamically_allocates, endless_add, max_capacity, partition_archive_id, db_size, partition_amount_and_offset, db_path, db_name_with_archive)
    temp.load_everything_from_files!
    return temp
  end



  # ManagedPartitionedArray#at_capacity? checks to see if the partitioned array is at its capacity. It is imperative to use this when going through an iterator.
  def at_capacity?
    return false if @has_capacity == false
    case @max_capacity
      when "data_arr_size"
        if @latest_id >= @data_arr.size
          return true
        end
      when Integer
        if ((@latest_id >= @max_capacity) && @has_capacity)
          return true
        end
      else
        return false      
    end
  end


  def []=(index, value)
  end

  def add(&block : String -> String)
    # endless add addition here
    if @endless_add && @data_arr[@latest_id].nil?
      add_partition
      save_everything_to_files!
    elsif at_capacity?# && @max_capacity && @has_capacity #guards against adding any additional entries
      return false
    else 
      # PASS, additional code later is a possibility, but this code all takes place before super(), anyways
    end
    @latest_id += 1
    super(&block)
  end

  def load_everything_from_files!
    load_from_files! #PartitionedArray#load_from_files!
    load_last_entry_from_file!
    load_max_partition_archive_id_from_file!
    load_partition_archive_id_from_file!
    load_max_capacity_from_file!
    load_has_capacity_from_file!
    load_db_name_with_no_archive_from_file!
    load_partition_addition_amount_from_file!
    load_endless_add_from_file!
  end

  def load_partition_from_file!(partition_id, load_variables = true)
    load_variables_from_disk! if load_variables
    super(partition_id)
  end

  # save_variables: added 10/21/2022; all variables saved/loaded to disk by default, to work around an issue where I didn"t realize I needed to save variables
  def save_partition_to_file!(partition_id, save_variables = true)
    save_variables_to_disk! if save_variables
    super(partition_id)
  end


  def save_everything_to_files!
    save_all_to_files! #PartitionedArray#save_all_to_files!
    save_last_entry_to_file!
    save_partition_archive_id_to_file!
    save_max_partition_archive_id_to_file!
    save_max_capacity_to_file!
    save_has_capacity_to_file!
    save_db_name_with_no_archive_to_file!
    save_partition_addition_amount_to_file!
    save_endless_add_to_file!
  end

  def save_variables_to_disk!
    # Synchronize all known variables with their disk counterparts
    save_last_entry_to_file!
    save_partition_archive_id_to_file!
    save_max_partition_archive_id_to_file!
    save_max_capacity_to_file!
    save_has_capacity_to_file!
    save_db_name_with_no_archive_to_file!
    save_partition_addition_amount_to_file!
    save_endless_add_to_file!
  end

  def load_variables_from_disk!
    # Synchronize all known variables with their disk counterparts
    load_last_entry_from_file! 
    load_partition_archive_id_from_file!
    load_max_partition_archive_id_from_file!
    load_max_capacity_from_file!
    load_has_capacity_from_file!
    load_db_name_with_no_archive_from_file!
    load_partition_addition_amount_from_file!
    load_endless_add_from_file!
  end

  def increment_max_partition_archive_id!
    @max_partition_archive_id += 1
    File.open(@db_path + "/" + "max_partition_archive_id.json", "w") do |f|
      f.write(@max_partition_archive_id)
    end
  end

  def save_db_name_with_no_archive_to_file!
    File.open(File.join("#{@db_path}", "db_name_with_no_archive.json"), "w") do |f|
      f.write(@original_db_name.to_json)
    end
  end

  def load_db_name_with_no_archive_from_file!
    File.open(File.join("#{@db_path}", "db_name_with_no_archive.json"), "r") do |f|
      @original_db_name = JSON.parse(f.read)
    end
  end

  def save_has_capacity_to_file!
    File.open(File.join("#{@db_path}/#{@db_name}", "has_capacity.json"), "w") do |f|
      f.write(@has_capacity.to_json)
    end
  end

  def save_endless_add_to_file!
    File.open(File.join("#{@db_path}/#{@db_name}", "endless_add.json"), "w") do |f|
      f.write(@endless_add.to_json)
    end
  end

  def load_endless_add_from_file!
    File.open(File.join("#{@db_path}/#{@db_name}", "endless_add.json"), "r") do |f|
      @endless_add = JSON.parse(f.read)
    end
  end

  def load_has_capacity_from_file!
    File.open(File.join("#{@db_path}/#{@db_name}", "has_capacity.json"), "r") do |f|
      @has_capacity = JSON.parse(f.read)
    end
  end

  def save_last_entry_to_file!
    if @partition_archive_id == 0      
      File.open(File.join("#{@db_path}/#{db_name_with_archive(db_name: @original_db_name)}", "last_entry.json"), "w") do |file|
        file.write((@latest_id).to_json)
      end
    else      
      File.open(File.join("#{@db_path}/#{db_name_with_archive(db_name: @original_db_name)}", "last_entry.json"), "w") do |file|
        file.write((@latest_id).to_json)
      end
    end
  end

  def load_last_entry_from_file!
    File.open(File.join("#{@db_path}/#{db_name_with_archive(db_name: @original_db_name)}", "last_entry.json"), "r") do |file|
      @latest_id = JSON.parse(file.read)
    end
  end

  def save_partition_archive_id_to_file!
    File.open(File.join("#{@db_path}/#{db_name_with_archive(db_name: @original_db_name)}", "partition_archive_id.json"), "w") do |file|
      file.write(@partition_archive_id.to_json)
    end
  end

  def load_partition_archive_id_from_file!
    File.open(File.join("#{@db_path}/#{db_name_with_archive(db_name: @original_db_name)}", "partition_archive_id.json"), "r") do |file|
      @partition_archive_id = JSON.parse(file.read)
    end
  end

  def save_max_partition_archive_id_to_file!
    File.open(File.join(@db_path, "max_partition_archive_id.json"), "w") do |file|
      file.write(@max_partition_archive_id.to_json)
    end
  end

def initialize_max_partition_archive_id!
  # if the max_partition_archive_id.json file does not exist, create it and set it to 0
  if !File.exists?(File.join("#{@db_path}", "max_partition_archive_id.json"))
    FileUtils.mkdir_p(@db_path)
    File.open(File.join("#{@db_path}", "max_partition_archive_id.json"), "w") do |f|
      f.print(0)
    end
    @max_partition_archive_id = 0
  else
  # if the max_partition_archive_id.json file does exist, load it
  File.open(File.join("#{@db_path}", "max_partition_archive_id.json"), "r") do |f|
    temp_file = File.read_lines(f.path)
    @max_partition_archive_id = JSON.parse(temp_file.join)
  end
  end
end


  def load_max_partition_archive_id_from_file!
    # puts "1 @db_path: #{@db_path}"
    if File.exist?(File.join(@db_path, "max_partition_archive_id.json"))
      File.open(File.join(@db_path, "max_partition_archive_id.json"), "r") do |file|
        temp_file = File.read_lines(file.path)
        @max_partition_archive_id = Json.parse(temp_file)#JSON.parse(file.readlines)
      end
    else
      FileUtils.touch(File.join(@db_path, "max_partition_archive_id.json"))
      File.open(File.join(@db_path, db_name_with_archive(db_name: @db_name, partition_archive_id: @partition_archive_id)), "w") do |file|
        file.write(0)
      end      
      return 0
    end
  end

  def save_max_capacity_to_file!
    File.open(File.join(@db_path, "max_capacity.json"), "w") do |file|
      file.write(@max_capacity.to_json)
    end
  end

  def load_max_capacity_from_file!
    File.open(File.join(@db_path, "max_capacity.json"), "r") do |file|
      @max_capacity = JSON.parse(file.read)
    end
  end

  

  def save_partition_addition_amount_to_file!
    File.open(File.join("#{@db_path}/#{@db_name}", "partition_addition_amount.json"), "w") do |file|
      file.write(@partition_addition_amount.to_json)
    end
  end

  def load_partition_addition_amount_from_file!
    File.open(File.join("#{@db_path}/#{@db_name}", "partition_addition_amount.json"), "r") do |file|
      @partition_addition_amount = JSON.parse(file.read)
    end
  end



  def db_name_with_archive(db_name =  @original_db_name, partition_archive_id = @partition_archive_id)
    return "#{db_name}[#{partition_archive_id}]"
  end

  def strip_archived_db_name(db_name = @original_db_name)
    return db_name.sub(/\[.+\]/, "").to_json

  end
end