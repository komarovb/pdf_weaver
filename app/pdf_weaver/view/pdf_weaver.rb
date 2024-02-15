require 'pdf_weaver/engine/weaver_engine'

class PdfWeaver
  module View

    ACCEPTED_IMAGES = %w(.png .jpeg .jpg)
    ACCEPTED_FILES = %w(.pdf)
    ACCEPTED_INPUT = ACCEPTED_FILES + ACCEPTED_IMAGES

    class PdfWeaver
      include Glimmer::LibUI::Application

      attr_accessor :weaver_files
    
      ## Add options like the following to configure CustomWindow by outside consumers
      #
      # options :title, :background_color
      # option :width, default: 320
      # option :height, default: 240
  
      ## Use before_body block to pre-initialize variables to use in body and
      #  to setup application menu
      #
      before_body do
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

          menu_options
      end
  
      ## Use after_body block to setup observers for controls in body
      #
      # after_body do
      #
      # end
  
      ## Add control content inside custom window body
      ## Top-most control must be a window or another custom window
      #
      body {
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
      }
  
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
          if File.exist?(file) && ACCEPTED_INPUT.include?(File.extname(file))
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
            search_pattern = ACCEPTED_INPUT.map{ |str| str.sub('.', '') }.join(',')
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
end
