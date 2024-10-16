require_relative '../app/pdf_weaver'
require 'base64'
require 'tempfile'

RSpec.describe WeaverEngine do
  let(:pdf_file) { Tempfile.new(['file1', '.pdf']) }
  let(:image_file) { Tempfile.new(['image1', '.jpeg']) }
  let(:output_file) { Tempfile.new(['output', '.pdf']) }

  before do
    # Create a sample PDF and image file
    pdf = CombinePDF.new
    pdf << CombinePDF.parse(Prawn::Document.new.render)
    pdf.save(pdf_file.path)

    File.open(image_file.path, 'wb') do |file|
      file.write(Base64.decode64(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/wcAAwAB/ayPB9kAAAAASUVORK5CYII="
      ))
    end
  end

  after do
    # Clean up temp files
    pdf_file.close
    pdf_file.unlink
    image_file.close
    image_file.unlink
    output_file.close
    output_file.unlink
  end

  let(:weaver_engine) { WeaverEngine.new }
  
  let(:valid_pdf) { WeaverEngine::WeaverFile.new(true, 'file1.pdf', pdf_file.path) }
  let(:valid_image) { WeaverEngine::WeaverFile.new(true, 'image1.png', image_file.path) }
  let(:invalid_file) { WeaverEngine::WeaverFile.new(true, 'invalid.pdf', 'non_existent.pdf') }
  let(:unselected_file) { WeaverEngine::WeaverFile.new(false, 'file2.pdf', pdf_file.path) }

  describe '#merge_files' do
    context 'with valid PDF and image files' do
      it 'merges the files successfully' do
        status, missing_files = weaver_engine.merge_files([valid_pdf, valid_image], output_file.path)
        
        expect(status).to eq(0)
        expect(missing_files).to be_empty

        merged_pdf = CombinePDF.load(output_file.path)
        expect(merged_pdf.pages.count).to eq(2)
      end
    end

    context 'with an invalid file path' do
      it 'reports the missing file' do
        status, missing_files = weaver_engine.merge_files([invalid_file], output_file.path)

        expect(status).to eq(0)
        expect(missing_files).to include('non_existent.pdf')
      end
    end

    context 'when files are not selected' do
      it 'ignores unselected files' do
        status, missing_files = weaver_engine.merge_files([unselected_file], output_file.path)

        expect(status).to eq(0)
        expect(missing_files).to be_empty

        merged_pdf = CombinePDF.load(output_file.path)
        expect(merged_pdf.pages.count).to eq(0)
      end
    end

    context 'when an exception occurs during merging' do
      it 'logs the error' do
        allow(weaver_engine).to receive(:process_file).and_raise(RuntimeError, 'Simulated error')

        expect { 
          weaver_engine.merge_files([valid_pdf], output_file.path) 
        }.to output(/Exception occured during merge!/).to_stdout_from_any_process
      end
    end
  end

  describe '#process_image' do
    it 'converts the image to a PDF' do
      pdf = weaver_engine.send(:process_image, valid_image)
      expect(pdf.pages.count).to eq(1)
    end
  end
end
