require_relative 'lib/apache/image_resizer/version'

begin
  require 'hen'

  Hen.lay! {{
    gem: {
      name:         %q{apache_image_resizer},
      version:      Apache::ImageResizer::VERSION,
      summary:      %q{Apache module providing image resizing functionality.},
      author:       %q{Jens Wille},
      email:        %q{jens.wille@gmail.com},
      license:      %q{AGPL-3.0},
      homepage:     :blackwinter,
      dependencies: %w[rmagick ruby-filemagic nuggets apache_secure_download],

      required_ruby_version: '>= 1.9.3'
    }
  }}
rescue LoadError => err
  warn "Please install the `hen' gem. (#{err})"
end
