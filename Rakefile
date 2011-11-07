require File.expand_path(%q{../lib/apache/image_resizer/version}, __FILE__)

begin
  require 'hen'

  Hen.lay! {{
    :gem => {
      :name     => %q{apache_image_resizer},
      :version  => Apache::ImageResizer::VERSION,
      :summary  => %q{Apache module providing image resizing functionality.},
      :author   => %q{Jens Wille},
      :email    => %q{jens.wille@uni-koeln.de},
      :homepage => :blackwinter
    }
  }}
rescue LoadError => err
  warn "Please install the `hen' gem. (#{err})"
end
