require 'ostruct'

describe Apache::ImageResizer do

  before :each do
    @base = '/base'
    @uri  = @base + '/prefix/%s/path'

    @handler = described_class.new(:verbosity => -1)
  end

  describe '#handler' do

    def self.it_should(type, what, expected_msg = what, &block)
      it "should #{type} #{what}" do
        mock_request(&block)

        actual_msg = nil

        @handler.handler(@request) { |msg|
          actual_msg = msg
          nil
        }.should == Apache.const_get(type == :pass ? :OK : :DECLINED)

        expected_msg = nil if type == :pass
        actual_msg.should == expected_msg
      end
    end

    it_should :decline, 'No URL' do
      @uri = nil
    end

    it_should :decline, 'Invalid Format' do
      @uri = '/'
    end

    it_should :decline, 'No Path' do
      @uri %= 'r100'
      @uri.sub!(/[^\/]+\z/, '')
    end

    it_should :decline, 'Invalid Directives' do
      @uri %= 'r10000'
    end

    it_should :decline, 'Zero width', 'Invalid Directives' do
      @uri %= 'r0x100'
    end

    it_should :decline, 'Zero height', 'Invalid Directives' do
      @uri %= 'r100x0'
    end

    it_should :decline, 'Zero width offset', 'Invalid Directives' do
      @uri %= 'o0x100p0p0'
    end

    it_should :decline, 'Zero height offset', 'Invalid Directives' do
      @uri %= 'o100x0p0p0'
    end

    it_should :decline, 'Read Error: Magick::ImageMagickError' do
      mock_uri(path = '/source-path')

      Magick::Image.should_receive(:read).with(path).once.and_raise(Magick::ImageMagickError)
      Magick::Image.should_receive(:read).with("jpeg:#{path}").once.and_raise(Magick::ImageMagickError)
    end

    it_should :decline, 'Write Error: Magick::ImageMagickError' do
      target = mock_uri(path = '/source-path')
      mock_image(path, target, format = 'jpeg', true)
    end

    it_should :decline, 'Resize Error: Magick::ImageMagickError' do
      target = mock_uri(path = '/source-path')
      mock_image(path, target, format = 'jpeg', true, true)
    end

    it_should :pass, 'resize' do
      target = mock_uri(path = '/source-path')
      mock_image(path, target, format = 'jpeg')

      @request.should_receive(:content_type=).with("image/#{format}").once.and_return(true)
      @request.should_receive(:status=).with(Apache::HTTP_OK).once.and_return(true)
      @request.should_receive(:send_fd).with(target).once.and_return(true)
    end

    def mock_request(&block)
      @request = double('Request')

      instance_eval(&block) if block

      @request.should_receive(:subprocess_env).once.and_return('REDIRECT_URL' => @uri)
      @request.should_receive(:add_common_vars).with(no_args).once.and_return(nil)
      @request.should_receive(:path_info).with(no_args).once.and_return(@base)
    end

    def mock_uri(path)
      mock_lookup_uri(:orig, path)
      mock_lookup_uri(:base, base = '/real-base')

      @uri %= 'r100'
      File.should_receive(:exist?).with(target = @uri.sub(@base, base)).once.and_return(false)

      target
    end

    def mock_lookup_uri(uri, path)
      @request.should_receive(:lookup_uri).with(case uri
        when :orig then @uri % 'original'
        when :base then @base
        else            uri
      end).once.and_return(OpenStruct.new(:status => Apache::HTTP_OK, :filename => path))
    end

    def mock_image(source, target, format, fail_write = false, fail_resize = false)
      img = double('Image')
      Magick::Image.should_receive(:read).with(source).once.and_return([img])

      img.should_receive(:columns).with(no_args).once.and_return(123)
      img.should_receive(:rows).with(no_args).once.and_return(456)
      img.should_not_receive(:crop!)

      if fail_resize
        img.should_receive(:resize_to_fit!).with(100.0, 456).once.and_raise(Magick::ImageMagickError)
        img.should_not_receive(:write)

        File.should_not_receive(:open)
        File.should_not_receive(:exist?).with(File.dirname(target))
        FileUtils.should_not_receive(:mkdir_p)
      else
        img.should_receive(:resize_to_fit!).with(100.0, 456).once.and_return(nil)

        File.should_receive(:exist?).with(File.dirname(target)).once.and_return(true)
        FileUtils.should_not_receive(:mkdir_p)

        if fail_write
          img.should_receive(:write).with(target).once.and_raise(Magick::ImageMagickError)
          img.should_receive(:write).with("jpeg:#{target}").once.and_raise(Magick::ImageMagickError)
          File.should_not_receive(:open)
        else
          img.should_receive(:format).with(no_args).once.and_return(format)
          img.should_receive(:write).with(target).once.and_return(img)
          File.should_receive(:open).with(target).once.and_yield(target)
        end
      end
    end

  end

end
