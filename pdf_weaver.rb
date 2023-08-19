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
        raise "At least 2 input files are needed for the program to run. Eg: ruby pdf_weave.rb -i <input_file_1> -i <input_file_2>."
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
  
    BasicWeaverFile = Struct.new(:selected, :filename, :filepath)
    class WeaverFile < BasicWeaverFile
      def action
        'Remove'
      end
    end

    attr_accessor :weaver_files

    def initialize
      @arguments = {output_file: "./output.pdf", input_files: []}
      @running = false
      @worker = nil
      @file_selection_element = nil
      @weaver_files = [
        WeaverFile.new(true, "file1.pdf", "/home/borys/file1.pdf")
      ]
      @instructions_header = %{How to use PDF Weaver\n\n}
      @instructions = %{Use the following instructions to merge multiple PDF files\n
1. Click the "Select files" button on the right side\n   
2. Pick files that you would like to merge\n
3. Confirm your choice and / or add more files int the next step\n
4. Click Merge to merge or Cancel to clear the list of files\n
5. Find merged file in the specified output directory\n}
    end
  
    def launch
      create_gui
      @main_window.show
    end
  
    def create_gui
      @main_window = window('PDF Weaver', 600, 500, true) {
        margined true
  
        vertical_box {
          horizontal_box {
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
          }
          horizontal_box {
            vertical_box {
              button("Select files") {
                stretchy false
                
                on_clicked do
                  file = open_file
                  unless file.nil?
                    puts "Selected #{file}"
                    if File.exist?(file)
                      @weaver_files << WeaverFile.new(true, File.basename(file), File.dirname(file))
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
                        @weaver_files << WeaverFile.new(true, File.basename(filepath), File.dirname(filepath))
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
          
                editable false
                cell_rows <=> [self, :weaver_files] # explicit data-binding to self.contacts Model Array, auto-inferring model attribute names from underscored table column names by convention
                
                on_changed do |row, type, row_data|
                  puts "Row #{row} #{type}: #{row_data}"
                  $stdout.flush # for Windows
                end
              }
              button("Merge selected files") {
                stretchy false
                
                on_clicked do
                  puts "Merging!"
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
    # cli_interface = PDFWeaver::WeaverCLI.new(ARGV)
    # status = cli_interface.do_work
    # exit(status)
    PDFWeaver::WeaverGUI.new.launch
  rescue => ex
    puts "Failing with an exception! #{ex.message}"
    exit(1)
  end
end