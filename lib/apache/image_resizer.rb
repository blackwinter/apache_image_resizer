#--
###############################################################################
#                                                                             #
# apache_image_resizer -- Apache module providing upload merging              #
#                         functionality                                       #
#                                                                             #
# Copyright (C) 2011-2012 University of Cologne,                              #
#                         Albertus-Magnus-Platz,                              #
#                         50923 Cologne, Germany                              #
#                                                                             #
# Copyright (C) 2013 Jens Wille                                               #
#                                                                             #
# Authors:                                                                    #
#     Jens Wille <jens.wille@gmail.com>                                       #
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

require 'apache/image_resizer/util'

module Apache

  class ImageResizer

    include Util

    # Creates a new RubyHandler instance for the Apache web server. It
    # is to be installed as a custom 404 ErrorDocument handler.
    def initialize(options = {})
      @verbosity   = options[:verbosity]   || DEFAULT_VERBOSITY
      @max_dim     = options[:max_dim]     || DEFAULT_MAX_DIM
      @prefix_re   = options[:prefix_re]   || DEFAULT_PREFIX_RE
      @source_dir  = options[:source_dir]  || DEFAULT_SOURCE_DIR
      @proxy_cache = options[:proxy_cache] || DEFAULT_PROXY_CACHE
      @enlarge     = options[:enlarge]
      @secret      = options[:secret]
    end

    # If the current +request+ asked for a resource that's not there,
    # it will be checked for resize directives and treated accordingly.
    # If no matching resource could be found, the original error will be
    # thrown.
    def handler(request, &block)
      request.add_common_vars  # REDIRECT_URL, REDIRECT_QUERY_STRING
      env = request.subprocess_env

      url   = env['REDIRECT_URL']
      query = env['REDIRECT_QUERY_STRING']
      url  += "?#{query}" unless query.nil? || query.empty?

      block ||= lambda { |msg|
        log(2) { "#{url} - Elapsed #{Time.now - request.request_time} [#{msg}]" }
      }

      path, prefix, directives, dir = parse_url(url,
        base = request.path_info, @prefix_re, &block)

      return DECLINED unless path

      log(2) {{ Base: base, Prefix: prefix, Dir: dir, Path: path }}

      source, target = get_paths(request, path, base,
        prefix, @source_dir, dir, @proxy_cache, @secret)

      if source
        log(2) {{ Source: source, Target: target, Directives: directives }}
        return DECLINED unless img = resize(source, target, directives, @enlarge, &block)
      end

      return DECLINED unless send_image(request, target, img, &block)

      log { "#{url} - Elapsed #{Time.now - request.request_time}" }

      OK
    end

  end

end
