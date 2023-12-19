#!/usr/bin/env ruby
# frozen_string_literal: true

require 'logger'
require 'combine_pdf'
require 'prawn'
require 'glimmer-dsl-libui'

module PDFWeaver

  VERSION = '0.0.2'

  ACCEPTED_IMAGES = %w(.png .jpeg .jpg)
  ACCEPTED_FILES = %w(.pdf)
  ACCEPTED_INPUT = ACCEPTED_FILES + ACCEPTED_IMAGES

  class WeaverCLI
    def initialize(arguments)
      @arguments = parse_arguments(arguments)
      @weaver = nil
      @logger = Logger.new($stdout, progname: "CLI")
    end

    def parse_arguments(arguments)
      parsed_args = {output_file: "output.pdf", input_files: []}
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

    attr_accessor :weaver_files

    def initialize
      @logger = Logger.new($stdout, progname: 'GUI')
      @output_file = "output.pdf"
      @weaver_files = []
      @weaver_engine = WeaverEngine.new

      @running = false
      @worker = nil
      @instructions_header = %{How to use PDF Weaver\n\n}
      @instruction_steps = ["Add Files: Click 'Select File' or 'Select Folder' to add PDF/image files.",
        "Arrange Order: Rearrange files using 'Up' and 'Down' buttons.",
        "Merge: Hit 'Merge' to combine files into one document.",
        "Retrieve Result: Find the merged file in the chosen output path."]
    end
  
    def launch
      create_gui
      @main_window.show
    end

    def show_instructions
      @instruction_steps.each_with_index do |step, index|
        step_header, step_body = step.split(':')
        string {
          font weight: :bold
          "#{index+1}. #{step_header}:"
        }
        string {
          "#{step_body}\n\n"
        }
      end
    end

  
    def create_gui
      # TODO Add menu items
      menu_options

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
                  show_instructions
                }
              }
              form {
                stretchy false
                @entry = entry {
                  label "Output file path:"
                  stretchy false
                  text @output_file
                  
                  on_changed do
                    if !@entry.text.nil?
                      @output_file = @entry.text
                    end
                  end
                }
              }
              
              button("Select File") {
                stretchy false
                
                on_clicked do
                  select_file_dialog
                end
              }
              button("Select Folder") {
                stretchy false
                
                on_clicked do
                  select_folder_dialog
                end
              }
            }
          }
          horizontal_box {
            vertical_box {
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
                cell_rows <=> [self, :weaver_files] # explicit data-binding to self.weaver_files Model Array, auto-inferring model attribute names from underscored table column names by convention
                
                on_changed do |row, type, row_data|
                  $stdout.flush # for Windows
                end
              }
              @merge_button = button("Merge") {
                stretchy false
                
                on_clicked do
                  merge_operation
                end
              }      
            }
          }
        }
      }
    end

    # Generating menu items
    # Based on the official Glimmer DSL for LibUI examples
    def menu_options
      menu('File') {
      
        menu_item('Select File') {
          on_clicked do
            select_file_dialog
          end
        }

        menu_item('Select Folder') {
          on_clicked do
            select_folder_dialog
          end
        }

        menu_item('Merge') {
          on_clicked do
            merge_operation
          end
        }
        
        separator_menu_item
        
        menu_item('Exit') {
          on_clicked do
            exit(0)
          end
        }
        
        quit_menu_item if OS.mac?
      }

      menu('Help') {
        if OS.mac?
          about_menu_item {
            on_clicked do
              show_about_dialog
            end
          }
        end
      
        menu_item('About') {
          on_clicked do
            show_about_dialog
          end
        }
      }
    end

    def show_about_dialog
      Glimmer::LibUI.queue_main do
        msg_box('About PDF Weaver', "PDF Weaver - Simple GUI tool for all your PDF needs\nCopyright (c) 2023 Borys Komarov")
      end
    end

    def select_file_dialog
      file = open_file
      unless file.nil?
        @logger.info "Selected #{file}"
        if File.exist?(file) && PDFWeaver::ACCEPTED_INPUT.include?(File.extname(file))
          @weaver_files << WeaverEngine::WeaverFile.new(true, File.basename(file), file)
        else
          msg_box_error("Unsupported file format!")
        end
      end
      $stdout.flush # for Windows
    end

    def select_folder_dialog
      selected_folder = open_folder
      @logger.info "Selected folder: #{selected_folder}"
      unless selected_folder.nil?
        if(Dir.exist?(selected_folder))
          search_pattern = PDFWeaver::ACCEPTED_INPUT.map{ |str| str.sub('.', '') }.join(',')
          Dir.glob("#{selected_folder}/*.{#{search_pattern}}").each do |filepath|
            @weaver_files << WeaverEngine::WeaverFile.new(true, File.basename(filepath), filepath)
          end
        else
          msg_box_error("Selected folder: #{selected_folder} doesn't exist!")
        end
      end
      $stdout.flush # for Windows
    end

    def merge_operation
      if not @running
        @running = true
        @merge_button.enabled = false
        @merge_button.text = "Merging..."
        @worker = Thread.new do
          if(@weaver_files.length > 0)
            status, missing_files = @weaver_engine.merge_files(@weaver_files, @output_file)
            if missing_files.length > 0
              @logger.info "Found #{missing_files.length} missing files"
              Glimmer::LibUI.queue_main do
                msg_box_error("Found #{missing_files.length} missing files!", "#{missing_files.join('\n')}")
              end
            end

            if status != 0
              @logger.info "Merge operation failed"
              Glimmer::LibUI.queue_main do
                msg_box_error("Merge operation failed with status: #{status}")
              end
            else 
              Glimmer::LibUI.queue_main do
                msg_box("Merge finished successfully!", "The result was saved to #{@output_file}")
              end
            end
          else
            Glimmer::LibUI.queue_main do
              msg_box("No files selected", "Merge is not possible")
            end
          end
          @running = false
        end
        @merge_button.enabled = true
        @merge_button.text = "Merge"
      end
    end
  end
end

# This is a main class responsible for manipulations with files
# 
# Including:
# - Merging files into a single pdf document
# - Splitting files into separate pages - TODO
class WeaverEngine

  DEFAULT_PAGE_SIZE = "LETTER"
  IMAGE_MARGIN = 80

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

  def initialize
    @logger = Logger.new($stdout, progname: 'Engine')
  end

  def merge_files(files_to_merge, output_file)
    status = 0
    missing_files = []

    @logger.info "Loading and Merging PDF files"
    pdf_output = CombinePDF.new

    files_to_merge.select(&:selected).each do |weaver_file|
      if File.exist?(weaver_file.filepath)
        @logger.info "Merging #{weaver_file.filepath}"
        pdf_input = process_file(weaver_file)
        pdf_output << pdf_input
      else
        missing_files << weaver_file.filepath
      end
    end

    @logger.info "Saving the result into #{output_file}"
    pdf_output.save output_file

    return status, missing_files

    # TODO Implement proper exception handling
    rescue RuntimeError => e
      @logger.error("Exception occured during merge! #{e.message}")
      @logger.error("#{e.backtrace}")
  end

  private 
  
  def process_file(weaver_file)
    extension = File.extname(weaver_file.filename)
    if PDFWeaver::ACCEPTED_IMAGES.include?(extension)
      process_image(weaver_file)
    elsif PDFWeaver::ACCEPTED_FILES.include?(extension)
      CombinePDF.load(weaver_file.filepath)
    end

  end

  # Transforms image into a PDF file for further processing
  # Uses *prawn* gem, currenlty only supports .png and .jpg (.jpeg) images
  # The whole transformation happens in RAM without the need to save the temporary pdf file on disk
  def process_image(weaver_file)
    # TODO Implemet more advanced logic in transforming images -> pdf files based on the image dimension and other params
    image_size = PDF::Core::PageGeometry::SIZES[DEFAULT_PAGE_SIZE].map{|e| e -= IMAGE_MARGIN}
    pdf_from_image = Prawn::Document.new(page_size: DEFAULT_PAGE_SIZE)
    pdf_from_image.image weaver_file.filepath, position: :center, vposition: :center, fit: image_size
    image_in_pdf = pdf_from_image.render
    CombinePDF.parse(image_in_pdf)
  end

end

if __FILE__ == $0
  begin
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