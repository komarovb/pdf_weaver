require 'combine_pdf'
require 'prawn'

# This is a main class responsible for merging files into a single pdf document
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
    if PdfWeaver::View::ACCEPTED_IMAGES.include?(extension)
      process_image(weaver_file)
    elsif PdfWeaver::View::ACCEPTED_FILES.include?(extension)
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