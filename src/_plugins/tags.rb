require_relative 'helpers/image_helper'

module Jekyll
    class StripTag < Liquid::Block
        def render(context)
            super.gsub /\n/, ""
        end
    end

    class VersionTag < Liquid::Tag
        def render(context)
            Jekyll::VERSION
        end
    end

  class LinkTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super
      @url, @text = @markup.strip.split(/\s+/, 2)
    end

    def render(context)
      args = @markup.strip.split(/\s+/, 2)
      cur_url = context.environments.first["page"]["url"]
      if cur_url.downcase.gsub('index.html', '')  == @url.downcase.gsub('index.html', '')
        return "<span>#{@text}</span>"
      else
        return "<a href=\"#{@url}\">#{@text}</a>"
      end
    end
  end

    class LogTag < Liquid::Tag
      def initialize(tag_name, markup, tokens)
        super
        @text = @markup
      end

      def render(context)
          return "<script>console.log('#{@text}');</script>"
      end
    end

  class PostImage < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super
    end

    def render(context)
      post = context['post']
      image_url = "#{context['site']['url']}#{post['id']}/title.jpg"
      size = ImageHelper.instance.size(image_url, post['id'], 'title.jpg')
      height = 150
      if size
        height = size[1]
      else
        Jekyll.logger.warn "Image size unresolved: #{ image_url }"
      end

      "<img src='#{ image_url }' alt='#{ post['title'] }' width=320 height=#{ height }>"
    end
  end

  class OgImage < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      super
    end

    def render(context)
      site = context['site']
      page = context['page']
      "<meta content='#{ ImageHelper.instance.fb_image(page['url']) }' property='og:image'/>"
    end
  end

end


Liquid::Template.register_tag('link', Jekyll::LinkTag)
Liquid::Template.register_tag('log', Jekyll::LogTag)
Liquid::Template.register_tag('post_image', Jekyll::PostImage)
Liquid::Template.register_tag('og_image', Jekyll::OgImage)
Liquid::Template.register_tag('strip', Jekyll::StripTag)
Liquid::Template.register_tag('version', Jekyll::VersionTag)
