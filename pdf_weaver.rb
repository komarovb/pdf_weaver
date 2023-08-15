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
  
    def initialize
      @arguments = {output_file: "./output.pdf", input_files: []}
      @running = false
      @worker = nil
    end
  
    def launch
      create_gui
      @main_window.show
    end
  
    def create_gui
      @main_window = window('PDF Weaver', 600, 400, true) {
        margined true
  
        vertical_box {
          horizontal_box {
            label("PDF Weaver")
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
  resque => ex
    puts "Failing with an exception! #{ex.message}"
    exit(1)
  end
end