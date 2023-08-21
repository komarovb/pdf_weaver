require 'combine_pdf'
require 'glimmer-dsl-libui'

module PDFWeaver
  class WeaverCLI
    def initialize(arguments)
      @arguments = parse_arguments(arguments)
      @weaver = nil
    end

    def parse_arguments(arguments)
      parsed_args = {output_file: "./output.pdf", input_files: []}
      if arguments.length < 3
        raise "At least 2 input files are needed for the program to run in command line mode. Eg: ruby pdf_weaver.rb -i <input_file_1> -i <input_file_2>."
      end

      for i in 0..arguments.length
        if arguments[i] == "-i"
          parsed_args[:input_files] << arguments[i+1]
          i+=1
        end
    
        if arguments[i] == "-o"
          parsed_args[:output_file] = arguments[i+1]
          i+=1
        end
      end
    
      if parsed_args[:input_files].length < 2
        raise "Minimum 2 input files are required!"
      end

      return parsed_args
    end

    def do_work
      status = 0
      merge_files
      return status
    end

    private 

    def merge_files
      puts "Loading and Merging PDF files"
      pdf = CombinePDF.new
      @arguments[:input_files].each do |file_path|
        pdf << CombinePDF.load(file_path)
      end

      puts "Saving the result into #{@arguments[:output_file]}"
      pdf.save @arguments[:output_file]
    end

    # TODO Implement splitting PDF files through command line
    def split_files
    end
  end

  class WeaverGUI
    include Glimmer
  
    WeaverFile = Struct.new(:selected, :filename, :filepath) do
      def action
        'Remove'
      end

      def up
        'Up'
      end

      def down
        'Down'
      end
    end

    attr_accessor :weaver_files

    def initialize
      @arguments = {output_file: "./output.pdf"}
      @running = false
      @worker = nil
      @file_selection_element = nil
      @weaver_files = []

      @instructions_header = %{How to use PDF Weaver\n\n}
      @instructions = %{1. Use "Select file" and "Select folder" buttons to pick pdf/image files\n   
2. The selected files will appear in the table below\n
3. Rearrange the files using the "Up" and "Down" buttons\n
4. Click the Merge button\n
5. The resulting document can be found under the output path\n}
    end
  
    def launch
      create_gui
      @main_window.show
    end
  
    def create_gui
      @main_window = window('PDF Weaver', 600, 600, true) {
        on_closing do
          @worker.exit if !@worker.nil?
        end

        margined true
  
        vertical_box {
          horizontal_box {
            vertical_box {
              # Instructions text
              area {
                stretchy true
                text {
                  align :center
                  default_font family: 'Courier New', size: 14, weight: :regular, stretch: :normal
                  string {
                    font family: 'Courier New', size: 22, weight: :bold, stretch: :normal
                    @instructions_header
                  }
                  string {
                    @instructions
                  }
                }
              }
              @entry = entry {
                stretchy false
                text @arguments[:output_file]
                
                on_changed do
                  if !@entry.text.nil?
                    @arguments[:output_file] = @entry.text
                  end
                end
              }
            }
          }
          horizontal_box {
            vertical_box {
              button("Select file") {
                stretchy false
                
                on_clicked do
                  file = open_file
                  unless file.nil?
                    puts "Selected #{file}"
                    if File.exist?(file)
                      @weaver_files << WeaverFile.new(true, File.basename(file), file)
                    end
                  end
                  $stdout.flush # for Windows

                end
              }
              button("Select folder") {
                stretchy false
                
                on_clicked do
                  selected_folder = open_folder
                  puts "Selected folder: #{selected_folder}"
                  unless selected_folder.nil?
                    if(Dir.exist?(selected_folder))
                      Dir.glob("#{selected_folder}/*.pdf").each do |filepath|
                        @weaver_files << WeaverFile.new(true, File.basename(filepath), filepath)
                      end
                    end
                  end
                  $stdout.flush # for Windows
                end
              }
              table {
                checkbox_column('Selected') {
                  editable true
                }
                text_column('Filename')
                button_column('Action') {
                  on_clicked do |row_id|
                    @weaver_files.delete_at(row_id)
                  end
                }
                button_column('Up') {
                  on_clicked do |row_id|
                    @weaver_files[row_id], @weaver_files[row_id - 1] = @weaver_files[row_id - 1], @weaver_files[row_id]
                  end
                }
                button_column('Down') {
                  on_clicked do |row_id|
                    @weaver_files[row_id], @weaver_files[row_id + 1] = @weaver_files[row_id + 1], @weaver_files[row_id]
                  end
                }
          
                editable false
                cell_rows <=> [self, :weaver_files] # explicit data-binding to self.contacts Model Array, auto-inferring model attribute names from underscored table column names by convention
                
                on_changed do |row, type, row_data|
                  puts "Row #{row} #{type}: #{row_data}"
                  $stdout.flush # for Windows
                end
              }
              @merge_button = button("Merge selected files") {
                stretchy false
                
                on_clicked do
                  if not @running
                    @running = true
                    @merge_button.enabled = false
                    @merge_button.text = "Merging..."
                    @worker = Thread.new do
                      
                      puts "Loading and Merging PDF files"
                      missing_files = []
                      pdf = CombinePDF.new
                      @weaver_files.select(&:selected).each do |weaver_file|
                        if File.exist?(weaver_file.filepath)
                          puts "Merging #{weaver_file.filepath}"
                          pdf << CombinePDF.load(weaver_file.filepath)
                        else
                          missing_files << weaver_file.filepath
                        end
                      end

                      puts "Saving the result into #{@arguments[:output_file]}"
                      pdf.save @arguments[:output_file]

                      if missing_files.length > 0
                        puts "Found #{missing_files.length} missing files"
                        Glimmer::LibUI.queue_main do
                          msg_box("Found #{missing_files.length} missing files!", "#{missing_files.join('\n')}")
                        end
                      end

                      Glimmer::LibUI.queue_main do
                        msg_box("Merge finished successfully!", "The result was saved to #{@arguments[:output_file]}")
                      end
                      @running = false
                    end
                    @merge_button.enabled = true
                    @merge_button.text = "Merge selected files"
                  end
                end
              }      
            }
          }
        }
      }
    end
  end
end

if __FILE__ == $0
  begin
    puts "Number of arguments: #{ARGV.length}, #{ARGV[1]}"
    if ARGV.length > 0 && (ARGV[0] == "--cli" || ARGV[0] == "-cli")
      cli_interface = PDFWeaver::WeaverCLI.new(ARGV)
      status = cli_interface.do_work
      exit(status)
    else
      PDFWeaver::WeaverGUI.new.launch
    end
  rescue => ex
    puts "Failing with an exception! #{ex.message}"
    exit(1)
  end
end