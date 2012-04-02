#--
###############################################################################
#                                                                             #
# A component of apache_image_resizer.                                        #
#                                                                             #
# Copyright (C) 2011 University of Cologne,                                   #
#                    Albertus-Magnus-Platz,                                   #
#                    50923 Cologne, Germany                                   #
#                                                                             #
# Authors:                                                                    #
#     Jens Wille <jens.wille@uni-koeln.de>                                    #
#                                                                             #
# apache_image_resizer is free software: you can redistribute it and/or       #
# modify it under the terms of the GNU Affero General Public License as       #
# published by the Free Software Foundation, either version 3 of the          #
# License, or (at your option) any later version.                             #
#                                                                             #
# apache_image_resizer is distributed in the hope that it will be             #
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty         #
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU         #
# Affero General Public License for more details.                             #
#                                                                             #
# You should have received a copy of the GNU Affero General Public License    #
# along with apache_image_resizer. If not, see http://www.gnu.org/licenses/.  #
#                                                                             #
###############################################################################
#++

require 'RMagick'
require 'fileutils'
require 'filemagic/ext'
require 'nuggets/uri/redirect'
require 'apache/secure_download/util'

unless RUBY_VERSION > '1.8.5'

  class String  # :nodoc:
    def start_with?(prefix)
      index(prefix) == 0
    end
  end

  module Net  # :nodoc:
    class BufferedIO  # :nodoc:
      private

      def rbuf_fill
        timeout(@read_timeout) {
          @rbuf << @io.readpartial(1024)
        }
      end
    end
  end

end

module Apache

  class ImageResizer

    module Util

      extend self

      DEFAULT_VERBOSITY   = 0
      DEFAULT_MAX_DIM     = 8192
      DEFAULT_HEIGHT      = 999999
      DEFAULT_PREFIX_RE   = %r{[^/]+/}
      DEFAULT_SOURCE_DIR  = 'original'
      DEFAULT_PROXY_CACHE = 'proxy_cache'
      DEFAULT_FORMAT      = 'jpeg:'

      MIME_RE = %r{\Aimage/}i

      dimension_pattern = %q{\d+(?:\.\d+)?}

      DIRECTIVES_RE = %r{
        \A
        (?:
          (?:
            r                              # resize
            ( #{dimension_pattern} )       # width
            (?:
              x
              ( #{dimension_pattern} )     # height (optional)
            )?
          )
          |
          (?:
            o                              # offset
            ( #{dimension_pattern} )       # width
            x
            ( #{dimension_pattern} )       # height
            ( [pm] #{dimension_pattern} )  # x
            ( [pm] #{dimension_pattern} )  # y
          )
        ){1,2}
        /
      }x

      PROXY_RE = %r{\Aproxy:}

      REPLACE = %w[? $@$]

      def secure_resize_url(secret, args = [], options = {})
        url_for(resize_url(*args), secret, options)
      end

      def resize_url(size = DEFAULT_SOURCE_DIR, *path)
        case size
          when String  then nil
          when Numeric then size = "r#{size}"
          when Array   then size = "r#{size.join('x')}"
          when Hash    then size = size.map { |k, v| case k.to_s
            when /\A[rs]/
              "r#{Array(v).join('x')}" if v
            when /\Ao/
              x, y, w, h = v
              "o#{w}x#{h}#{x < 0 ? 'm' : 'p'}#{x.abs}#{y < 0 ? 'm' : 'p'}#{y.abs}"
          end }.compact.join
        end

        if path.empty?
          size
        else
          file = path.pop.sub(*REPLACE)
          File.join(path << size << file)
        end
      end

      def parse_url(url, base, prefix_re, &block)
        block ||= lambda { |*| }

        return block['No URL'] unless url

        path = Apache::SecureDownload::Util.real_path(url)
        return block['Invalid Format'] unless path.sub!(
          %r{\A#{Regexp.escape(base)}/(#{prefix_re})}, ''
        )

        prefix, directives, dir = $1 || '', *extract_directives(path)
        return block['Invalid Directives'] unless directives
        return block['No Path'] if path.empty?
        return block['No File'] if path =~ %r{/\z}

        [path, prefix, directives, dir]
      end

      def extract_directives(path)
        return unless path.sub!(DIRECTIVES_RE, '')
        match, directives, max = Regexp.last_match, {}, @max_dim

        if o = match[3]
          wh = [o.to_f, match[4].to_f]
          xy = match.values_at(5, 6)

          if wh.all? { |i| 0 < i && i <= max }
            directives[:offset] = xy.map! { |i| i.tr!('pm', '+-').to_f }.concat(wh)
          else
            return
          end
        end

        if w = match[1]
          h = match[2]

          wh = [w.to_f]
          wh << h.to_f if h

          max *= 2 if o

          if wh.all? { |i| 0 < i && i <= max }
            directives[:resize] = wh
          else
            return
          end
        end

        [directives, match[0]]
      end

      def get_paths(request, path, base, prefix, source_dir, target_dir, proxy_cache, secret)
        real_base = request.lookup_uri(base).filename.untaint
        target    = File.join(real_base, prefix, target_dir, path).untaint
        return [nil, target] if File.exist?(target)

        source = request.lookup_uri(url_for(File.join(base, prefix,
          source_dir, path.sub(*REPLACE.reverse)), secret)).filename.untaint
        return [source, target] unless source.sub!(PROXY_RE, '') && proxy_cache

        cache = File.join(real_base, prefix, proxy_cache, path).untaint
        return [cache, target] if File.exist?(cache)

        begin
          URI.get_redirect(source) { |res|
            if res.is_a?(Net::HTTPSuccess) && res.content_type =~ MIME_RE
              content = res.body.untaint

              mkdir_for(cache)
              File.open(cache, 'w') { |f| f.write(content) }

              return [cache, target]
            end
          }
        rescue => err
          log_err(err, "#{source} => #{cache}")
        end

        [source, target]
      end

      def resize(source, target, directives, enlarge, &block)
        img = do_magick('Read', source, block) { |value|
          Magick::Image.read(value).first
        } or return

        resize, offset = directives.values_at(:resize, :offset)
        link = !offset

        if resize
          c, r = img.columns, img.rows

          w, h = resize
          h  ||= DEFAULT_HEIGHT

          unless enlarge || offset
            w = [w, c].min
            h = [h, r].min
          end

          img.resize_to_fit!(w, h)

          link &&= img.columns == c && img.rows == r
        end

        if offset
          img.crop!(*offset)
        end

        mkdir_for(target)

        if link
          if system('ln', source, target)
            return img
          elsif block
            block['Link error: %s' % $?.exitstatus]
          end
        end

        do_magick('Write', target, block) { |value|
          img.write(value) or raise Magick::ImageMagickError
        }
      rescue => err
        log_err(err)
        block['Resize Error: %s' % err] if block
      end

      def send_image(request, target, img = nil)
        File.open(target) { |f|
          request.content_type = (t = img && img.format) ?
            "image/#{t.downcase}" : f.content_type

          request.status = HTTP_OK
          request.send_fd(f)
        }
      rescue IOError => err
        request.log_reason(err.message, target)
        yield('Send Error') if block_given?
      end

      private

      def do_magick(what, value, block)
        yield value
      rescue Magick::ImageMagickError => err
        unless value.start_with?(DEFAULT_FORMAT)
          value = "#{DEFAULT_FORMAT}#{value}"
          retry
        else
          block['%s Error: %s' % [what, err]] if block
        end
      end

      def mkdir_for(path)
        dir = File.dirname(path).untaint
        FileUtils.mkdir_p(dir) unless File.exist?(dir)
      end

      def url_for(url, sec = nil, opt = {})
        sec ? Apache::SecureDownload::Util.secure_url(sec, url, opt) : url
      end

      def log_err(err, msg = nil)
        log(0, 1, err.backtrace) {
          "[ERROR] #{"#{msg}: " if msg}#{err} (#{err.class})"
        }
      end

      def log(level = 1, loc = 0, trace = nil)
        return if @verbosity < level

        case msg = yield
          when Array then msg = msg.shift % msg
          when Hash  then msg = msg.map { |k, v|
            "#{k} = #{v.inspect}"
          }.join(', ')
        end

        warn "#{caller[loc]}: #{msg}#{" [#{trace.join(', ')}]" if trace}"
      end

    end

  end

end
